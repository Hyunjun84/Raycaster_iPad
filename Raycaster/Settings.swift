//
//  Settings.swift
//  Raycaster
//
//  Created by H.Kim on 2023/07/31.
//

import Foundation

extension KernelType {
    func toString() -> String {
        return KernelType.listStr()[Int(self.rawValue)]
    }
    static func listStr() ->[String] {
        return ["2nd Order Voronoi-Spline", "3rd Order Voronoi-Spline", "Six Direction Box-Spline"]
    }
}

extension ShaderType {
    func toString() -> String {
        return ShaderType.listStr()[Int(self.rawValue)]
    }
    static func listStr() -> [String] {
        return ["Blinn-Phong Shading", "Curvature Rendering"]
    }
}

protocol SettingDelegate {
    func didChangeVolmeDataSettings(Settings setting:Settings)
    func didChangeCameraSettings(Settings setting:Settings)
    func didChangeKernelTypeSettings(Settings setting:Settings)
    func didChangeShaderTypeSettings(Settings setting:Settings)
}

struct Settings {
    var lattice : LatticeType
    var useQI : Bool
    var resolution : Int
    var shader : ShaderType
    var kernel : KernelType
    var fov : Float
    var level : Float
    var rayBounds : (Int, Int)
    var delegates : [SettingDelegate?] = []
    
    init(lattice: LatticeType, useQI: Bool, resolution: Int, shader: ShaderType, kernel: KernelType, fov: Float, level: Float, rayBounds bounds:(Int, Int) ) {
        self.lattice = lattice
        self.useQI = useQI
        self.resolution = resolution
        self.shader = shader
        self.kernel = kernel
        self.fov = fov
        self.level = level
        self.rayBounds = bounds
    }
    
    mutating func addDelegate(delegate d : SettingDelegate?)
    {
        self.delegates.append(d)
    }
    
    func didUpdateCameraSettings()
    {
        for delegate in delegates {
            delegate?.didChangeCameraSettings(Settings: self)
        }
    }

    func didUpdateVolumeDataSettings()
    {
        for delegate in delegates {
            delegate?.didChangeVolmeDataSettings(Settings: self)
        }
    }
    
    func didUpdateKernelTypeSettings()
    {
        for delegate in delegates {
            delegate?.didChangeKernelTypeSettings(Settings: self)
        }
    }
    
    func didUpdateShaderTypeSettings()
    {
        for delegate in delegates {
            delegate?.didChangeShaderTypeSettings(Settings: self)
        }
    }

}
