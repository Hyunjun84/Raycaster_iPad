//
//  RenderingViewController.swift
//  Raycaster
//
//  Created by H.Kim on 2023/07/31.
//

import UIKit
import MetalKit

class RenderingViewController: UIViewController, MTKViewDelegate, SettingDelegate {
    var renderer: Renderer?
    var raycaster: Raycaster?
    var data: VolumeData?
    var cmdQueue : MTLCommandQueue?
    
    var camera = Camera()
    var needUpdate:UInt32 = 64
    
    var aspectRatio:Float = 1.0
    let tileScale = simd_uint2(8, 8)
    var tileOffset:[simd_uint2] = []

    init(setting : inout Settings) {
        super.init(nibName: nil, bundle: nil)
        
        let device = MTLCreateSystemDefaultDevice()
        
        // make MTLView
        let _mtkView = MTKView()
        _mtkView.device = device
        _mtkView.clearColor = MTLClearColorMake(1, 1, 1, 1.0)
        _mtkView.delegate = self
        self.view = _mtkView
        
        // make renderer
        self.renderer = Renderer(_mtkView)
        self.camera.setFov(FOV: self.aspectRatio, aspectRatio: Float(_mtkView.drawableSize.height/_mtkView.drawableSize.width))
      
        // make common library and queue
        let library = device?.makeDefaultLibrary()
        self.cmdQueue = device?.makeCommandQueue()
        
        // make Raycaster
        let raySpaceBound = MTLSizeMake(setting.rayBounds.0, setting.rayBounds.1, 1)
        self.raycaster = Raycaster(device: device, library: library, raySpaceBound: raySpaceBound)
        self.raycaster?.currentkernel = Int(setting.kernel.rawValue)
        let coef = self.raycaster?.getQICoeff()
        
        // load ML data
        self.data = VolumeData(with: device!, library: library!)
        self.data?.level = setting.level
        self.data?.genMLData(with: MTLSizeMake(setting.resolution, setting.resolution, setting.resolution),
                             queue: self.cmdQueue, lattice:setting.lattice)
        self.data?.applyQuasi(coefficents: coef!, queue: cmdQueue, lattice: setting.lattice)
        
        // register delegate
        setting.addDelegate(delegate: self)
        
        let offset = [simd_uint2(1,0), simd_uint2(0,1), simd_uint2(1,1), simd_uint2(0,0)]
        
        for i in offset {
            for j in offset {
                for k in offset {
                    tileOffset.append(i &+ j&*2 &+ k&*4)
                }
            }
        }
        
        // register gesture recognizer
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(self.pan(_:)))
        self.view.addGestureRecognizer(panGesture)
        
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(self.pinch(_:)))
        self.view.addGestureRecognizer(pinchGesture)
        
        let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(self.rotation(_:)))
        self.view.addGestureRecognizer(rotationGesture)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setNeedUpdate() {
        self.needUpdate = 64
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.aspectRatio = Float(self.view.bounds.height/self.view.bounds.width)
        self.setNeedUpdate()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        self.aspectRatio = Float(size.height/size.width)
        self.camera.setFov(FOV: nil, aspectRatio: self.aspectRatio)
        self.setNeedUpdate()
    }
    
    func didChangeVolmeDataSettings(Settings setting: Settings) {
        self.data?.genMLData(with: MTLSizeMake(setting.resolution, setting.resolution, setting.resolution),
                             queue: self.cmdQueue, lattice:setting.lattice)
        let coef = self.raycaster?.getQICoeff()
        self.data?.applyQuasi(coefficents: coef!, queue: self.cmdQueue, lattice: setting.lattice)
        self.data?.QI = setting.useQI
        self.data?.level = setting.level
        self.setNeedUpdate()
    }
    
    func didChangeCameraSettings(Settings setting: Settings) {
        self.camera.setFov(FOV: setting.fov, aspectRatio: self.aspectRatio)
        self.setNeedUpdate()
    }

    func didChangeKernelTypeSettings(Settings setting: Settings) {
        self.raycaster?.currentkernel = Int(setting.kernel.rawValue)
        let coef = self.raycaster?.getQICoeff()
        self.data?.applyQuasi(coefficents: coef!, queue: self.cmdQueue, lattice:setting.lattice)
        self.setNeedUpdate()
    }

    func didChangeShaderTypeSettings(Settings setting: Settings) {
        self.renderer?.currentShader = Int(setting.shader.rawValue)
        self.setNeedUpdate()
    }

    func draw(in view: MTKView) {
        let cmdBuffer = self.cmdQueue?.makeCommandBuffer()
        
        if needUpdate>0 {
            #if true
            needUpdate = needUpdate - 1
            self.raycaster?.raycastingTiled(commanBuffer: cmdBuffer,
                                            data: self.data,
                                            camera: self.camera,
                                            tileOffset: self.tileOffset[Int(needUpdate)],
                                            tileScale: tileScale,
                                            isUpdate : needUpdate != 63)
            #else
            needUpdate = 0
            self.raycaster?.raycasting(queue: self.cmdQueue,
                                       data: self.data,
                                       camera: self.camera)
            #endif
        }
        
        var MV = simd_mul(camera.V, data!.M)
        let buffer = self.raycaster!.getDefferedBuffer()
        self.renderer!.draw(in: view, commandBuffer: cmdBuffer, buffer: buffer, MV: &MV)
        
        cmdBuffer?.commit()
    }
    
    // for scaling
    @objc func pinch(_ gestureRecognizer : UIPinchGestureRecognizer)
    {
        guard gestureRecognizer.view != nil else { return }

        switch gestureRecognizer.state {
            case .changed :
                let s = gestureRecognizer.scale
                self.data?.applyMap(map: scale(simd_float3(repeating: Float(s))))
                self.setNeedUpdate()
                gestureRecognizer.scale = 1
                
            default :
                break
        }
    }
    
    @objc func pan(_ gestureRecognizer : UIPanGestureRecognizer)
    {
        guard gestureRecognizer.view != nil || gestureRecognizer.view != self.view else {return}
        let view = gestureRecognizer.view
        
        switch gestureRecognizer.state {
            case .changed :
                switch gestureRecognizer.numberOfTouches {
                    // Rotation
                    case 1 :
                        let szViewport = max(view!.bounds.width, view!.bounds.height)
                        
                        let curPos = gestureRecognizer.location(in: view)
                        let delta = gestureRecognizer.translation(in: view)
                        let oldPos = CGPoint(x: curPos.x-delta.x, y: curPos.y-delta.y)
                        
                        // window space coordinate to normalized space coordiante(ray space)
                        var a = simd_float3(x:Float(oldPos.x*2/szViewport-1), y:-Float(oldPos.y*2/szViewport-1), z:0)
                        var b = simd_float3(x:Float(curPos.x*2/szViewport-1), y:-Float(curPos.y*2/szViewport-1), z:0)
                        
                        let radius:Float = Float(2.squareRoot())
                        a.z = sqrtf(radius-a.x*a.x+a.y*a.y)
                        b.z = sqrtf(radius-b.x*b.x+b.y*b.y)
                        
                        // compute rotation axis and angle
                        let axis = normalize(cross(a,b))
                        let th = acos(simd_dot(a,b)/(simd_length(a)*simd_length(b)))
                        
                        if !simd_any(isnan(axis)) && !th.isNaN {
                            let R = rotate(axis:axis, angle:th)
                            
                            self.data?.applyMap(map: R)
                            
                            gestureRecognizer.setTranslation(.zero, in: self.view)
                            self.setNeedUpdate()
                        }
                    
                    // Translation
                    case 2 :
                        let delta = gestureRecognizer.translation(in: view)
                        let szViewport = min(view!.bounds.width, view!.bounds.height)
                        
                        let dir = simd_float3(Float(delta.x*2/szViewport), -Float(delta.y*2/szViewport), 0)
                        
                        let t = translate(direction: dir)
                        self.data?.applyMap(map: t)
                        
                        gestureRecognizer.setTranslation(.zero, in: view)
                        self.setNeedUpdate()
                        
                    default :
                        break
                }
                
            default : break
        }
    }
    
    @objc func rotation(_ gestureRecognizer : UIRotationGestureRecognizer)
    {
        let axis = simd_float3(x:0,y:0,z:-1)
        let th = gestureRecognizer.rotation
        if !simd_any(isnan(axis)) && !th.isNaN {
            let R = rotate(axis: axis, angle: Float(th))
            self.data?.applyMap(map: R)
            gestureRecognizer.rotation = 0
            self.setNeedUpdate()
        }
    }
}

