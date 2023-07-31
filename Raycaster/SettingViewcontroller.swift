//
//  SettingViewcontroller.swift
//  Raycaster
//
//  Created by H.Kim on 2023/07/31.
//

import UIKit

enum LatticeType : Int, CaseIterable {
    case LT_CC = 0
    case LT_FCC = 1
    func toString() -> String {
        return LatticeType.listStr()[self.rawValue]
    }
    static func listStr() -> [String] {
        return ["CC", "FCC"]
    }
}
enum SettingSection : Int, CaseIterable {
    case SS_VOLUME_DATA=0
    case SS_SHADER_TYPE
    case SS_KERNEL_TYPE
    case SS_CAMERA
    func toString() -> String {
        return SettingSection.listStr()[self.rawValue]
    }
    static func listStr() -> [String] {
        return ["Volume Data", "Shader Type", "Kernel Type", "Camera"]
    }

}

class SettingSwitchCell : UITableViewCell {
    var switchBtn : UISwitch!
    var title : UILabel!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.title = UILabel()
        self.switchBtn = UISwitch()
        self.contentView.addSubview(self.title!)
        self.contentView.addSubview(self.switchBtn!)
        self.switchBtn?.addTarget(self,
                               action: #selector(self.didChangeSwitchValue(_:)),
                               for: .valueChanged)
        // auto layout
        // for subview constraints
        let margin = self.contentView.layoutMarginsGuide
        
        self.title?.translatesAutoresizingMaskIntoConstraints = false
        self.switchBtn?.translatesAutoresizingMaskIntoConstraints = false
        
        // horizontal layout constraints
        self.title?.leadingAnchor.constraint(equalTo: margin.leadingAnchor).isActive = true
        self.switchBtn?.leadingAnchor.constraint(equalToSystemSpacingAfter: self.title.trailingAnchor,
                                                 multiplier: 1).isActive = true
        self.switchBtn?.trailingAnchor.constraint(equalTo: margin.trailingAnchor).isActive = true
        
        // vertical layout constraints
        self.title?.topAnchor.constraint(equalTo: margin.topAnchor).isActive = true
        self.switchBtn?.topAnchor.constraint(equalTo: margin.topAnchor).isActive = true
        
        self.title?.bottomAnchor.constraint(equalTo: margin.bottomAnchor).isActive = true
        self.switchBtn?.bottomAnchor.constraint(equalTo: margin.bottomAnchor).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    @objc func didChangeSwitchValue(_ sender : UISwitch) {}
}

class SettingSliderCell : UITableViewCell {
    var slider : UISlider?
    var title : UILabel?
    var value : UILabel?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.title = UILabel()
        self.value = UILabel()
        self.slider = UISlider()
        self.contentView.addSubview(self.title!)
        self.contentView.addSubview(self.value!)
        self.contentView.addSubview(self.slider!)
        self.slider?.addTarget(self,
                               action: #selector(self.didChangeSliderValue(_:)),
                               for: .valueChanged)
        // auto layout
        // for subview constraints
        let margin = self.contentView.layoutMarginsGuide
        
        self.title?.translatesAutoresizingMaskIntoConstraints = false
        self.value?.translatesAutoresizingMaskIntoConstraints = false
        self.slider?.translatesAutoresizingMaskIntoConstraints = false
        
        // horizontal layout constraints
        self.title?.leadingAnchor.constraint(equalTo: margin.leadingAnchor).isActive = true
        self.value?.leadingAnchor.constraint(equalToSystemSpacingAfter: self.title!.trailingAnchor, multiplier: 1).isActive = true
        self.value?.trailingAnchor.constraint(equalTo: margin.trailingAnchor).isActive = true
        
        self.slider?.leadingAnchor.constraint(equalTo: margin.leadingAnchor).isActive = true
        self.slider?.trailingAnchor.constraint(equalTo: margin.trailingAnchor).isActive = true
        
        // vertical layout constraints
        self.title?.topAnchor.constraint(equalTo: margin.topAnchor).isActive = true
        self.value?.topAnchor.constraint(equalTo: margin.topAnchor).isActive = true
        
        self.slider?.topAnchor.constraint(equalToSystemSpacingBelow: title!.bottomAnchor, multiplier: 1).isActive = true
        self.slider?.bottomAnchor.constraint(equalTo: margin.bottomAnchor).isActive = true

        self.title?.heightAnchor.constraint(equalTo: self.slider!.heightAnchor).isActive = true
        self.value?.heightAnchor.constraint(equalTo: self.slider!.heightAnchor).isActive = true
        //self.title?.widthAnchor.constraint(equalTo:self.value!.widthAnchor).isActive = true
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    @objc func didChangeSliderValue(_ sender : UISlider) {}
}

class SettingLatticeCell : UITableViewCell {
    var segment : UISegmentedControl?
    var title : UILabel?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        self.title = UILabel()
        self.segment = UISegmentedControl()
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        
        for lattice in LatticeType.allCases {
            self.segment?.insertSegment(withTitle: lattice.toString(), at: lattice.rawValue, animated: true)
        }
        self.title?.text = "Sampling Lattice"
        self.contentView.addSubview(self.title!)
        self.contentView.addSubview(self.segment!)
        
        
        // auto layout
        let margin = self.contentView.layoutMarginsGuide
        self.title?.translatesAutoresizingMaskIntoConstraints = false
        self.segment?.translatesAutoresizingMaskIntoConstraints = false
        
        // horizontal layout constraints
        self.title?.leadingAnchor.constraint(equalTo: margin.leadingAnchor).isActive = true
        self.title?.trailingAnchor.constraint(equalTo:margin.trailingAnchor).isActive = true
        self.segment?.leadingAnchor.constraint(equalTo: margin.leadingAnchor).isActive = true
        self.segment?.trailingAnchor.constraint(equalTo:margin.trailingAnchor).isActive = true
        
        //vertical layout constraints
        self.title?.topAnchor.constraint(equalTo: margin.topAnchor).isActive = true
        self.segment?.topAnchor.constraint(equalToSystemSpacingBelow: self.title!.bottomAnchor,
                                          multiplier: 1).isActive = true
        self.segment?.bottomAnchor.constraint(equalTo: margin.bottomAnchor).isActive = true
        
        // width constraints
        self.title?.heightAnchor.constraint(equalTo: self.segment!.heightAnchor).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SettingViewController: UITableViewController {
    var setting:Settings?
    var prevSetting : Settings?
    
    init(setting: inout Settings?)
    {
        //super.init(nibName: nil, bundle: nil)
        super.init(style: .insetGrouped)
        self.setting = setting

        self.tableView.register(SettingLatticeCell.classForCoder(),
                                forCellReuseIdentifier: "IDS_LATTICE")
        self.tableView.register(SettingSliderCell.classForCoder(),
                                forCellReuseIdentifier: "IDS_RESOLUTION")
        self.tableView.register(SettingSliderCell.classForCoder(),
                                forCellReuseIdentifier: "IDS_LEVEL")
        self.tableView.register(SettingSwitchCell.classForCoder(),
                                forCellReuseIdentifier: "IDS_QUASI")
        self.tableView.register(UITableViewCell.classForCoder(),
                                forCellReuseIdentifier: "IDS_SHADER_TYPE")
        self.tableView.register(UITableViewCell.classForCoder(),
                                forCellReuseIdentifier: "IDS_KERNEL_TYPE")
        self.tableView.register(SettingSliderCell.classForCoder(),
                                forCellReuseIdentifier: "IDS_FOV")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Callback functions
    func changeResolution(_ sender:UISlider?, Label label:UILabel?)
    {
        guard let value = sender?.value.rounded() else {return}
        sender?.value = value
        
        // update text
        switch setting?.lattice {
            case .LT_CC  : label?.text = String(Int(value)) + "\u{00B3}"
            case .LT_FCC : label?.text = String(Int(value)) + "\u{00B3}⨉4"
            default : break
        }

        if setting?.resolution != Int(value) {
            self.setting?.resolution = Int(value)
            self.setting?.didUpdateVolumeDataSettings()
        }
    }
    
    func changeLevel(_ sender:UISlider?, Label label:UILabel?)
    {
        guard var value = sender?.value else {return}
        if abs(value-0.5)<0.05 {
            value = 0.5
            sender?.value = value
            
        }
        //sender.value = Float(Int(sender.value*200))/200
        var sval = String(format:"%.4f", value)
        while sval.last == "0" {
            sval.removeLast()
        }
        if sval.last == "." {
            sval.removeLast()
        }
        label?.text = sval
        
        if setting?.level != value {
            self.setting?.level = value
            self.setting?.didUpdateVolumeDataSettings()
        }
    }
    
    func changeFov(_ sender:UISlider?, title : UILabel?, value : UILabel?)
    {
        guard let val = sender?.value.rounded() else {return}
        sender?.value = val
        
        if val == 0 {
            title?.text = "Orthogonal Projection"
            value?.text = ""
        } else {
            title?.text = "FOV"
            value?.text = String(Int(val)) + "°"
        }
        self.setting?.fov = val
        self.setting?.didUpdateCameraSettings()
    }
    
    func changeQI(_ sender:UISwitch?)
    {
        guard let state = sender?.isOn else {return}
        self.setting?.useQI = state
        self.setting?.didUpdateVolumeDataSettings()
    }
    
    func changeLattice(_ sender : UISegmentedControl?)//, LatticeType lattice : LatticeType)
    {
        guard let lattice = LatticeType(rawValue: sender!.selectedSegmentIndex),
                  lattice != setting?.lattice else {return}
        
        if self.prevSetting == nil {
            self.prevSetting = self.setting
            self.setting?.lattice = lattice
            switch self.setting?.lattice {
                case .LT_CC :
                    self.setting?.kernel = KT_CC6
                case .LT_FCC :
                    self.setting?.kernel = KT_FCCV2
                default : break;
            }
        } else {
            swap(&self.setting, &self.prevSetting)
        }
        
        self.setting?.didUpdateVolumeDataSettings()
        self.setting?.didUpdateKernelTypeSettings()
        self.setting?.didUpdateShaderTypeSettings()
        self.tableView.reloadData()
    }
    
    @objc func dismiss( _ sender:Any?)
    {
        self.splitViewController?.show(.secondary)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if (UIDevice.current.userInterfaceIdiom == .phone) {
           self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(dismiss(_:)))
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Settings"
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        //return SettingSection.listStr().count
        return 4
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        let nr_kernels = self.setting?.lattice == .LT_CC ? 1 : 2
        let cnt = [4, 2, nr_kernels, 1]
        return cnt[section]
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        var cell:UITableViewCell?
        
        switch indexPath.section {
            case 0 :
                switch indexPath.row {
                    case 0 :
                        cell = tableView.dequeueReusableCell(withIdentifier: "IDS_LATTICE",
                                                             for: indexPath)
                        
                        let cellLattice = cell as? SettingLatticeCell
                        cellLattice?.segment?.selectedSegmentIndex = self.setting!.lattice.rawValue
                        let action = UIAction(handler: {_ in self.changeLattice(cellLattice?.segment)})
                        cellLattice?.segment?.addAction(action, for: .valueChanged)
                        
                    case 1 :
                        cell = tableView.dequeueReusableCell(withIdentifier: "IDS_RESOLUTION",
                                                             for: indexPath)
                        
                        let cellResolution = cell as? SettingSliderCell
                        cellResolution?.title?.text = "Resolution"
                        switch setting!.lattice {
                            case .LT_CC :
                                cellResolution?.slider?.minimumValue = 16
                                cellResolution?.slider?.maximumValue = 256
                                
                            case .LT_FCC :
                                cellResolution?.slider?.minimumValue = 8
                                cellResolution?.slider?.maximumValue = 128
                        }
                        cellResolution?.slider?.value = Float(setting!.resolution)

                        self.changeResolution(cellResolution?.slider, Label: cellResolution?.value)
                        let action = UIAction(handler: {_ in self.changeResolution(cellResolution?.slider,
                                                                                   Label: cellResolution?.value)})
                        cellResolution?.slider?.addAction(action, for: .valueChanged)
                        
                    case 2 :
                        cell = tableView.dequeueReusableCell(withIdentifier: "IDS_LEVEL",
                                                             for: indexPath)
                        let cellLevel = cell as? SettingSliderCell
              
                        cellLevel?.title?.text = "Isolevel"
                        cellLevel?.slider?.minimumValue = 0
                        cellLevel?.slider?.maximumValue = 1
                        cellLevel?.slider?.value = Float(self.setting!.level)
                        
                        self.changeLevel(cellLevel?.slider, Label: cellLevel?.value)
                        let action = UIAction(handler: {_ in self.changeLevel(cellLevel?.slider,
                                                                              Label: cellLevel?.value)})
                        cellLevel?.slider?.addAction(action, for: .valueChanged)
              
                    case 3 :
                        cell = tableView.dequeueReusableCell(withIdentifier: "IDS_QUASI",
                                                             for: indexPath)
                        let cellQI  = cell as? SettingSwitchCell
                        cellQI?.title.text = "Quasi Interpolation"
                        cellQI?.switchBtn.isOn = setting!.useQI
                        let action = UIAction(handler: {_ in self.changeQI(cellQI?.switchBtn)})
                        cellQI?.switchBtn?.addAction(action, for: .valueChanged)
                        
                    default : break
                }
            //Shader
            case 1 :
                cell = tableView.dequeueReusableCell(withIdentifier: "IDS_SHADER_TYPE",
                                                     for: indexPath)
                var config = cell?.defaultContentConfiguration()
                config?.text = ShaderType(rawValue: UInt32(indexPath.row)).toString()
                cell?.contentConfiguration = config
                if indexPath.row == setting!.shader.rawValue {
                    cell?.accessoryType = .checkmark
                } else {
                    cell?.accessoryType = .none
                }

            //Kernel
            case 2 :
                cell = tableView.dequeueReusableCell(withIdentifier: "IDS_KERNEL_TYPE",
                                                     for: indexPath)
                var config = cell?.defaultContentConfiguration()
                let kernelTypeIndex = UInt32(setting?.lattice == .LT_FCC ? indexPath.row: indexPath.row+2)
                config?.text = KernelType(rawValue: kernelTypeIndex).toString()
                cell?.contentConfiguration = config
                if kernelTypeIndex == setting!.kernel.rawValue {
                    cell?.accessoryType = .checkmark
                } else {
                    cell?.accessoryType = .none
                }

            //Camera
            case 3 :
                cell = tableView.dequeueReusableCell(withIdentifier: "IDS_FOV",
                                                     for: indexPath)
                let cellFov = cell as? SettingSliderCell
                cellFov?.slider?.minimumValue = 0
                cellFov?.slider?.maximumValue = 120
                cellFov?.slider?.value = Float(self.setting!.fov)
                cellFov?.didChangeSliderValue(cellFov!.slider!)
                self.changeFov(cellFov?.slider, title: cellFov?.title, value: cellFov?.value)
                let action = UIAction(handler: { _ in self.changeFov(cellFov?.slider,
                                                                     title: cellFov?.title,
                                                                     value: cellFov?.value)})
                cellFov?.slider?.addAction(action, for: .valueChanged)

            default : break
        }
        return cell!
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return SettingSection(rawValue: section)?.toString()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
            case 1 :
                self.setting?.shader = ShaderType(rawValue: UInt32(indexPath.row))
                self.setting?.didUpdateShaderTypeSettings()
            case 2 :
                switch self.setting?.lattice {
                    case .LT_CC :
                        self.setting?.kernel = KernelType(rawValue: UInt32(indexPath.row+2))
                    case .LT_FCC :
                        self.setting?.kernel = KernelType(rawValue: UInt32(indexPath.row))
                        self.setting?.didUpdateKernelTypeSettings()
                    default :
                        break
                }
            default : break
        }
        tableView.reloadData()
    }
    
    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
