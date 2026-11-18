// Native ETPad settings controls. GPL-3.0-or-later.
import UIKit
private final class PreferenceSlider:UISlider {
    var changed:((Float)->Void)?
    private var delivered:Float?
    private func notify(){guard delivered != value else{return};delivered=value;changed?(value)}
    override var value:Float { didSet { notify() } }
    override func setValue(_ value:Float,animated:Bool){super.setValue(value,animated:animated);notify()}
    func publish(){notify()}
}
final class HostSettingsViewController: UITableViewController {
    enum Row {
        case toggle(String,Bool,(Bool)->Void)
        case slider(String,Float,Float,Float,(Float)->Void)
        case button(String,()->Void)
        case segment(String,[String],Int,(Int)->Void)
        case destructive(String,()->Void)
    }
    struct Section { let title:String?; let footer:String?; let rows:[Row] }
    let sections:[Section]
    init(title:String,sections:[Section]){self.sections=sections;super.init(style:.insetGrouped);self.title=title}
    convenience init(title:String,rows:[Row]){self.init(title:title,sections:[Section(title:nil,footer:nil,rows:rows)])}
    required init?(coder:NSCoder){fatalError("init(coder:)")}
    override var supportedInterfaceOrientations:UIInterfaceOrientationMask { .landscape }
    override func viewDidLoad(){
        super.viewDidLoad();overrideUserInterfaceStyle = .dark
        navigationItem.rightBarButtonItem=UIBarButtonItem(barButtonSystemItem:.done,target:self,action:#selector(done))
    }
    @objc private func done(){dismiss(animated:true)}
    override func numberOfSections(in tableView:UITableView)->Int { sections.count }
    override func tableView(_ tableView:UITableView,numberOfRowsInSection section:Int)->Int { sections[section].rows.count }
    override func tableView(_ tableView:UITableView,titleForHeaderInSection section:Int)->String? { sections[section].title }
    override func tableView(_ tableView:UITableView,titleForFooterInSection section:Int)->String? { sections[section].footer }
    override func tableView(_ tableView:UITableView,heightForRowAt indexPath:IndexPath)->CGFloat {
        switch sections[indexPath.section].rows[indexPath.row] { case .slider,.segment:return 94;default:return 52 }
    }
    override func tableView(_ tableView:UITableView,cellForRowAt indexPath:IndexPath)->UITableViewCell {
        let cell=UITableViewCell(style:.default,reuseIdentifier:nil)
        switch sections[indexPath.section].rows[indexPath.row] {
        case let .toggle(title,value,change):
            cell.textLabel?.text=title;let toggle=UISwitch();toggle.isOn=value;toggle.accessibilityLabel=title;toggle.accessibilityIdentifier="etpad.setting."+title
            cell.isAccessibilityElement=false;cell.textLabel?.isAccessibilityElement=false;cell.accessibilityElements=[toggle];cell.selectionStyle = .none
            toggle.addAction(UIAction { [weak toggle] _ in if let toggle=toggle { change(toggle.isOn) } },for:.valueChanged);cell.accessoryView=toggle
        case let .slider(title,minimum,maximum,value,change):
            let label=UILabel();label.text=String(format:"%@  %.2g",title,value);cell.selectionStyle = .none
            let slider=PreferenceSlider();slider.minimumValue=minimum;slider.maximumValue=maximum;slider.value=value;slider.accessibilityLabel=title
            slider.changed = { value in label.text=String(format:"%@  %.2g",title,value);change(value) }
            slider.addAction(UIAction { [weak slider] _ in slider?.publish() },for:.valueChanged)
            stack(cell,[label,slider])
        case let .segment(title,options,selected,change):
            let label=UILabel();label.text=title;cell.selectionStyle = .none
            let control=UISegmentedControl(items:options);control.selectedSegmentIndex=selected;control.accessibilityLabel=title
            control.addAction(UIAction { [weak control] _ in if let control=control { change(control.selectedSegmentIndex) } },for:.valueChanged)
            stack(cell,[label,control])
        case let .button(title,_):cell.textLabel?.text=title;cell.textLabel?.textColor = .systemBlue;cell.accessoryType = .disclosureIndicator
        case let .destructive(title,_):cell.textLabel?.text=title;cell.textLabel?.textColor = .systemRed
        }
        return cell
    }
    private func stack(_ cell:UITableViewCell,_ views:[UIView]){
        let stack=UIStackView(arrangedSubviews:views);stack.axis = .vertical;stack.spacing=10;stack.translatesAutoresizingMaskIntoConstraints=false
        cell.contentView.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:cell.contentView.leadingAnchor,constant:18),stack.trailingAnchor.constraint(equalTo:cell.contentView.trailingAnchor,constant:-18),stack.topAnchor.constraint(equalTo:cell.contentView.topAnchor,constant:12),stack.bottomAnchor.constraint(equalTo:cell.contentView.bottomAnchor,constant:-12)])
    }
    override func tableView(_ tableView:UITableView,didSelectRowAt indexPath:IndexPath){
        tableView.deselectRow(at:indexPath,animated:true)
        switch sections[indexPath.section].rows[indexPath.row] {
        case let .button(_,action),let .destructive(_,action):dismiss(animated:true,completion:action)
        default:break
        }
    }
}
