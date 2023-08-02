//
//  Renderer.swift
//  Raycaster
//
//  Created by H.Kim on 2023/07/31.
//

import Foundation
import MetalKit
import simd

struct half4 {
    var x : Float16
    var y : Float16
    var z : Float16
    var w : Float16
    
    init(_ x: Float16, _ y: Float16, _ z: Float16, _ w: Float16) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }
}

class Renderer {
    var currentShader = 0;
    var _PSO_render : [MTLRenderPipelineState?] = []
    var d_colormap : MTLTexture?
    var light : Light?
    var material : [Material?] = []
    
    let quadVertices = [
        // 2D positions,    RGBA colors
        Vertex(position: vector_float2(-1, -1), texCoordinate: vector_float2(0,0)),
        Vertex(position: vector_float2( 1, -1), texCoordinate: vector_float2(1,0)),
        Vertex(position: vector_float2(-1,  1), texCoordinate: vector_float2(0,1)),
        Vertex(position: vector_float2( 1,  1), texCoordinate: vector_float2(1,1))
    ]
    
    init(_ mtkview: MTKView?) {
        // make Render PSO
        let device = mtkview?.device
        let library = device?.makeDefaultLibrary()

        for shaderType in 0..<ST_NR_SHADERS.rawValue {
            let constantValue = MTLFunctionConstantValues()
            var value = shaderType
            constantValue.setConstantValue(&value,
                                           type: MTLDataType.int,
                                           index: Int(FC_SHADER_TYPE.rawValue))
            
            let vertexFunction = try? library?.makeFunction(name: "vertexShader", constantValues: constantValue)
            let fragmentFunction = try? library?.makeFunction(name: "fragmentShader", constantValues: constantValue)
            
            let piplineStateDescriptor = MTLRenderPipelineDescriptor()
            piplineStateDescriptor.label = "Raycaster "+ShaderType(rawValue: shaderType).toString()
            piplineStateDescriptor.vertexFunction = vertexFunction
            piplineStateDescriptor.fragmentFunction = fragmentFunction
            piplineStateDescriptor.colorAttachments[0].pixelFormat = mtkview!.colorPixelFormat
            self._PSO_render.append(try? device?.makeRenderPipelineState(descriptor: piplineStateDescriptor))
            
        }
        
        let colormap = [half4(1.0, 0.0, 0.0, 1.0), half4(1.0, 1.0, 0.0, 1.0), half4(0.0, 1.0, 0.0, 1.0),
                        half4(0.5, 0.5, 0.5, 1.0), half4(0.5, 0.5, 0.5, 1.0), half4(0.0, 1.0, 1.0, 1.0),
                        half4(0.5, 0.5, 0.5, 1.0), half4(0.5, 0.5, 0.5, 1.0), half4(0.0, 0.0, 1.0, 1.0)];
        
        let tex_descr = MTLTextureDescriptor()
        tex_descr.textureType = MTLTextureType.type2D
        tex_descr.pixelFormat = MTLPixelFormat.rgba16Float
        tex_descr.width = 3
        tex_descr.height = 3
        tex_descr.storageMode = .shared
        tex_descr.usage = [.shaderRead]
        self.d_colormap = device?.makeTexture(descriptor: tex_descr)
        let region = MTLRegion(origin: MTLOriginMake(0, 0, 0), size: MTLSizeMake(3, 3, 1))
        self.d_colormap?.replace(region: region, mipmapLevel: 0, withBytes: colormap, bytesPerRow: 3*MemoryLayout<half4>.size)
        
        
        /* http://devernay.free.fr/cours/opengl/materials.html
        let emerald = Material(ambient: simd_float3(0.0215, 0.1745, 0.0215), diffuse: simd_float3(0.07568, 0.61424, 0.07568), specular: simd_float3(0.633, 0.727811, 0.633), shininess: 0.6*128)
        let jade = Material(ambient: simd_float3(0.135, 0.2225, 0.1575), diffuse: simd_float3(0.54, 0.89, 0.63), specular: simd_float3(0.316228, 0.316228, 0.316228), shininess: 0.1*128)
        let obsidian = Material(ambient: simd_float3(0.05375, 0.05, 0.06625), diffuse: simd_float3(0.18275, 0.17, 0.22525), specular: simd_float3(0.332741, 0.328634, 0.346435), shininess: 0.3*128)
        let pearl = Material(ambient: simd_float3(0.25, 0.20725, 0.20725), diffuse: simd_float3(1, 0.829, 0.829), specular: simd_float3(0.296648, 0.296648, 0.296648), shininess: 0.088*128)
        let ruby = Material(ambient: simd_float3(0.1745, 0.01175, 0.01175), diffuse: simd_float3(0.61424, 0.04136, 0.04136), specular: simd_float3(0.727811, 0.626959, 0.626959), shininess: 0.6*128)
        let turquoise = Material(ambient: simd_float3(0.1, 0.18725, 0.1745), diffuse: simd_float3(0.396, 0.74151, 0.69102), specular: simd_float3(0.297254, 0.30829, 0.306678), shininess: 0.1*128)
        let brass = Material(ambient: simd_float3(0.329412, 0.223529, 0.027451), diffuse: simd_float3(0.780392, 0.568627, 0.113725), specular: simd_float3(0.992157, 0.941176, 0.807843), shininess: 0.21794872*128)
        let bronze = Material(ambient: simd_float3(0.2125, 0.1275, 0.054), diffuse: simd_float3(0.714, 0.4284, 0.18144), specular: simd_float3(0.393548, 0.271906, 0.166721), shininess: 0.2*128)
        let chrome = Material(ambient: simd_float3(0.25, 0.25, 0.25), diffuse: simd_float3(0.4, 0.4, 0.4), specular: simd_float3(0.774597, 0.774597, 0.774597), shininess: 0.6*128)
        let copper = Material(ambient: simd_float3(0.19125, 0.0735, 0.0225), diffuse: simd_float3(0.7038, 0.27048, 0.0828), specular: simd_float3(0.256777, 0.137622, 0.086014), shininess: 0.1*128)
        let gold = Material(ambient: simd_float3(0.24725, 0.1995, 0.0745), diffuse: simd_float3(0.75164, 0.60648, 0.22648), specular: simd_float3(0.628281, 0.555802, 0.366065), shininess: 0.4*128)
        let silver = Material(ambient: simd_float3(0.19225, 0.19225, 0.19225), diffuse: simd_float3(0.50754, 0.50754, 0.50754), specular: simd_float3(0.508273, 0.508273, 0.508273), shininess: 0.4*128)
        let black_plastic = Material(ambient: simd_float3(0.0, 0.0, 0.0), diffuse: simd_float3(0.01, 0.01, 0.01), specular: simd_float3(0.50, 0.50, 0.50), shininess: .25*128)
        let cyan_plastic = Material(ambient: simd_float3(0.0, 0.1, 0.06), diffuse: simd_float3(0.0, 0.50980392, 0.50980392), specular: simd_float3(0.50196078, 0.50196078, 0.50196078), shininess: .25*128)
        let green_plastic = Material(ambient: simd_float3(0.0, 0.0, 0.0), diffuse: simd_float3(0.1, 0.35, 0.1), specular: simd_float3(0.45, 0.55, 0.45), shininess: .25*128)
        let red_plastic = Material(ambient: simd_float3(0.0, 0.0, 0.0), diffuse: simd_float3(0.5, 0.0, 0.0), specular: simd_float3(0.7, 0.6, 0.6), shininess: .25*128)
        let white_plastic = Material(ambient: simd_float3(0.0, 0.0, 0.0), diffuse: simd_float3(0.55, 0.55, 0.55), specular: simd_float3(0.70, 0.70, 0.70), shininess: .25*128)
        let yellow_plastic = Material(ambient: simd_float3(0.0, 0.0, 0.0), diffuse: simd_float3(0.5, 0.5, 0.0), specular: simd_float3(0.60, 0.60, 0.50), shininess: .25*128)
        let black_rubber = Material(ambient: simd_float3(0.02, 0.02, 0.02), diffuse: simd_float3(0.01, 0.01, 0.01), specular: simd_float3(0.4, 0.4, 0.4), shininess: .078125*128)
        let cyan_rubber = Material(ambient: simd_float3(0.0, 0.05, 0.05), diffuse: simd_float3(0.4, 0.5, 0.5), specular: simd_float3(0.04, 0.7, 0.7), shininess: .078125*128)
        let green_rubber = Material(ambient: simd_float3(0.0, 0.05, 0.0), diffuse: simd_float3(0.4, 0.5, 0.4), specular: simd_float3(0.04, 0.7, 0.04), shininess: .078125*128)
        let red_rubber = Material(ambient: simd_float3(0.05, 0.0, 0.0), diffuse: simd_float3(0.5, 0.4, 0.4), specular: simd_float3(0.7, 0.04, 0.04), shininess: .078125*128)
        let white_rubber = Material(ambient: simd_float3(0.05, 0.05, 0.05), diffuse: simd_float3(0.5, 0.5, 0.5), specular: simd_float3(0.7, 0.7, 0.7), shininess: .078125*128)
        let yellow_rubber = Material(ambient: simd_float3(0.05, 0.05, 0.0), diffuse: simd_float3(0.5, 0.5, 0.4), specular: simd_float3(0.7, 0.7, 0.04), shininess: .078125*128))
        */
        
        let jade = Material(ambient: simd_float3(0.135, 0.2225, 0.1575), diffuse: simd_float3(0.54, 0.89, 0.63), specular: simd_float3(0.316228, 0.316228, 0.316228), shininess: 0.1*128)
        let ruby = Material(ambient: simd_float3(0.1745, 0.01175, 0.01175), diffuse: simd_float3(0.61424, 0.04136, 0.04136), specular: simd_float3(0.727811, 0.626959, 0.626959), shininess: 0.6*128)
        self.light = Light(
            position: simd_float4(-10, 10, 10, 0),
            ambient: simd_float3(repeating: 1),
            diffuse: simd_float3(repeating: 1),
            specular: simd_float3(repeating: 1)
        )
        // front face color
        self.material.append(jade)
        // back face color
        self.material.append(ruby)
    }
    
    func draw(in view: MTKView!, commandBuffer cmdBuffer:MTLCommandBuffer?, buffer : [MTLTexture?], MV : inout simd_float4x4, level:Float)
    {
        let viewport = MTLViewport(originX: 0.0,
                                   originY: 0.0,
                                     width: view.drawableSize.width,
                                    height: view.drawableSize.height,
                                     znear: 0.0,
                                      zfar: 1.0)
        
        if let renderPassDescriptor = view.currentRenderPassDescriptor {
            let renderEncoder = cmdBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            renderEncoder?.label = "RenderEncoder"
            renderEncoder?.setViewport(viewport)
            renderEncoder?.setRenderPipelineState(self._PSO_render[self.currentShader]!)
            renderEncoder?.setVertexBytes(quadVertices,
                                          length: MemoryLayout<Vertex>.size*quadVertices.count,
                                          index: Int(VertexInputIndexVertices.rawValue))
            renderEncoder?.setFragmentTexture(buffer[0], index: 0)
            renderEncoder?.setFragmentTexture(buffer[1], index: 1)
            
            
            if currentShader == ST_ERROR.rawValue {
                var lvl = level
                renderEncoder?.setFragmentBytes(&lvl, length: 4, index: 4)
                renderEncoder?.setFragmentTexture(d_colormap, index: 4)
            }
            if currentShader == ST_CURVATURE.rawValue {
                renderEncoder?.setFragmentTexture(buffer[2], index: 2)
                renderEncoder?.setFragmentTexture(buffer[3], index: 3)
                renderEncoder?.setFragmentTexture(d_colormap, index: 4)
            }
            renderEncoder?.setFragmentBytes(&MV,
                                            length: MemoryLayout<simd_float4x4>.size,
                                            index: 0);
            renderEncoder?.setFragmentBytes(&self.light,
                                            length: MemoryLayout<Light>.size,
                                            index: 1)
            renderEncoder?.setFragmentBytes(&self.material[0],
                                            length: MemoryLayout<Material>.size,
                                            index: 2)
            renderEncoder?.setFragmentBytes(&self.material[1],
                                            length: MemoryLayout<Material>.size,
                                            index: 3)
            renderEncoder?.drawPrimitives(type: .triangleStrip,
                                          vertexStart: 0,
                                          vertexCount: 4)
            
            renderEncoder?.endEncoding()
            
            cmdBuffer?.present(view.currentDrawable!)
        }
    }
    
}
