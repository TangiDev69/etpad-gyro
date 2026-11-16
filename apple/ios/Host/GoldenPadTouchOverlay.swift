// Adapted from UTP Sources/UT99Host/GoldenPadTouchOverlay.swift and
// UT99TouchConfiguration.swift at a9313911efcf044fd66f9a679af53e55e255a8b4.
// Tablet thumb-arc positions follow GoldenPad Sources/TouchLayout.swift at
// 54474a40e93b77259d10c7594919e6a05f5e276d. GPL-3.0-or-later.
import UIKit

struct TouchConfiguration: Codable {
    var opacity:Double = 0.72
    var size:Double = 1
    var leftHanded = false
    var hideWithController = true
    var centers:[String:[Double]] = [:]
    mutating func sanitize() {
        opacity = max(0.25,min(1,opacity));size=max(0.7,min(1.3,size))
        centers=centers.filter { $0.value.count == 2 && $0.value.allSatisfy(\.isFinite) }.mapValues { [max(0.04,min(0.96,$0[0])),max(0.08,min(0.92,$0[1]))] }
    }
}
private final class TouchActionButton: UIButton {
    var edge:((Bool)->Void)?
    var accent = UIColor.white
    var editingLayout = false
    var opacity:CGFloat = 0.72
    override var isHighlighted: Bool { didSet { updateFace() } }
    func updateFace() {
        backgroundColor=(isHighlighted && !editingLayout ? accent.withAlphaComponent(0.8):UIColor.black.withAlphaComponent(0.46))
        layer.borderColor=UIColor.white.withAlphaComponent(0.34).cgColor;layer.borderWidth=1
        alpha=opacity
    }
    override init(frame:CGRect) {
        super.init(frame:frame)
        isMultipleTouchEnabled=false;isExclusiveTouch=false
        titleLabel?.font = .roundedBold(size:13)
        setTitleColor(.white,for:.normal)
        addTarget(self,action:#selector(down),for:.touchDown)
        addTarget(self,action:#selector(up),for:[.touchUpInside,.touchUpOutside,.touchCancel])
    }
    required init?(coder:NSCoder) { fatalError("init(coder:)") }
    @objc private func down(){ if !editingLayout { edge?(true) } }
    @objc private func up(){ edge?(false) }
    override func accessibilityActivate()->Bool {
        guard !editingLayout else { return false };edge?(true);isHighlighted=true
        Timer.scheduledTimer(withTimeInterval:0.12,repeats:false) { [weak self] _ in self?.edge?(false);self?.isHighlighted=false }
        return true
    }
}
private extension UIFont {
    static func roundedBold(size:CGFloat)->UIFont {
        let font=UIFont.systemFont(ofSize:size,weight:.bold)
        return font.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor:$0,size:size) } ?? font
    }
}
final class GoldenPadTouchOverlay: UIView {
    struct Action {
        let title:String, command:String
        let x:CGFloat,y:CGFloat,scale:CGFloat
        let tint:UIColor
    }
    // GoldenPad tablet FIRE/ALT/JUMP thumb arc; ET's additional aiming actions
    // occupy the inner/lower arc. The utility diamond stays separate.
    static let actions:[Action] = [
        .init(title:"FIRE",command:"+attack",x:0.91,y:0.71,scale:1.16,tint:.systemRed),
        .init(title:"ALT",command:"weapalt",x:0.91,y:0.56,scale:1,tint:.systemOrange),
        .init(title:"JUMP",command:"+moveup",x:0.91,y:0.86,scale:0.94,tint:.systemBlue),
        .init(title:"CROUCH",command:"+movedown",x:0.81,y:0.89,scale:0.82,tint:.systemTeal),
        .init(title:"PRONE",command:"+prone",x:0.71,y:0.89,scale:0.82,tint:.systemPurple),
        .init(title:"RELOAD",command:"+reload",x:0.78,y:0.58,scale:0.9,tint:.systemYellow),
        .init(title:"SCORE",command:"+scores",x:0.36,y:0.64,scale:0.72,tint:.systemGray),
        .init(title:"PREV",command:"weapprev",x:0.30,y:0.74,scale:0.72,tint:.systemGray),
        .init(title:"NEXT",command:"weapnext",x:0.42,y:0.74,scale:0.72,tint:.systemGray),
        .init(title:"USE",command:"+activate",x:0.36,y:0.84,scale:0.72,tint:.systemGreen),
        .init(title:"MENU",command:"togglemenu",x:0.50,y:0.92,scale:0.72,tint:.systemGray)]
    var onAction:((String,Bool)->Void)?
    var onMove:((CGPoint)->Void)?
    var onLook:((CGPoint)->Void)?
    var onConfigurationChanged:(()->Void)?
    var configuration:TouchConfiguration { didSet { configuration.sanitize();persist();setNeedsLayout() } }
    var arranging=false { didSet { releaseAll();setNeedsLayout() } }
    private var buttons:[String:TouchActionButton]=[:]
    private let moveGuide=UIView(),lookGuide=UIView()
    private weak var moveTouch:UITouch?,lookTouch:UITouch?
    private var moveOrigin=CGPoint.zero,lastLook=CGPoint.zero
    override init(frame:CGRect) {
        configuration=(UserDefaults.standard.data(forKey:"etpad.touch.configuration").flatMap { try? JSONDecoder().decode(TouchConfiguration.self,from:$0) }) ?? TouchConfiguration()
        configuration.sanitize();super.init(frame:frame)
        isMultipleTouchEnabled=true;backgroundColor = .clear;isOpaque=false
        for guide in [moveGuide,lookGuide] {
            guide.backgroundColor=UIColor.black.withAlphaComponent(0.25);guide.layer.borderColor=UIColor.white.withAlphaComponent(0.4).cgColor;guide.layer.borderWidth=1;guide.isHidden=true;guide.isUserInteractionEnabled=false;addSubview(guide)
        }
        for action in Self.actions {
            let button=TouchActionButton(frame:.zero);button.setTitle(action.title,for:.normal)
            button.accessibilityLabel=action.title;button.accent=action.tint
            button.edge = { [weak self] pressed in self?.onAction?(action.command,pressed) }
            button.addGestureRecognizer(UIPanGestureRecognizer(target:self,action:#selector(arrange(_:))))
            buttons[action.title]=button;addSubview(button)
        }
    }
    required init?(coder:NSCoder){fatalError("init(coder:)")}
    private func persist(){if let data=try? JSONEncoder().encode(configuration){UserDefaults.standard.set(data,forKey:"etpad.touch.configuration")}}
    override func layoutSubviews() {
        super.layoutSubviews()
        let safe=bounds.inset(by:safeAreaInsets)
        let base=min(min(94,max(62,safe.width*0.075))*configuration.size,max(44,(safe.height*0.15-12)*2/(1.16+1)))
        for action in Self.actions {
            guard let button=buttons[action.title] else { continue }
            let custom=configuration.centers[action.title]
            let x=custom.map { CGFloat($0[0]) } ?? action.x,y=custom.map { CGFloat($0[1]) } ?? action.y
            let center=CGPoint(x:safe.minX+(configuration.leftHanded ? 1-x:x)*safe.width,y:safe.minY+y*safe.height)
            let side=base*action.scale
            button.bounds=CGRect(x:0,y:0,width:side,height:action.title=="MENU" ? side*0.54:side)
            button.center=CGPoint(x:max(safe.minX+side/2,min(safe.maxX-side/2,center.x)),y:max(safe.minY+side/2,min(safe.maxY-side/2,center.y)))
            button.layer.cornerRadius=button.bounds.height/2
            button.editingLayout=arranging;button.opacity=configuration.opacity;button.updateFace()
            button.gestureRecognizers?.forEach { $0.isEnabled=arranging }
        }
        if arranging {
            showGuide(moveGuide,at:CGPoint(x:safe.minX+safe.width*(configuration.leftHanded ? 0.87:0.13),y:safe.minY+safe.height*0.82),diameter:130)
            showGuide(lookGuide,at:CGPoint(x:safe.minX+safe.width*(configuration.leftHanded ? 0.22:0.78),y:safe.minY+safe.height*0.72),diameter:110)
        } else if moveTouch==nil && lookTouch==nil { moveGuide.isHidden=true;lookGuide.isHidden=true }
    }
    @objc private func arrange(_ recognizer:UIPanGestureRecognizer) {
        guard arranging,let button=recognizer.view as? TouchActionButton,let title=button.title(for:.normal) else { return }
        let location=recognizer.location(in:self),safe=bounds.inset(by:safeAreaInsets)
        var x=(location.x-safe.minX)/safe.width;if configuration.leftHanded { x=1-x }
        configuration.centers[title]=[Double(x),Double((location.y-safe.minY)/safe.height)]
        if recognizer.state == .ended { onConfigurationChanged?() }
    }
    private func showGuide(_ guide:UIView,at point:CGPoint,diameter:CGFloat) {
        guide.bounds=CGRect(x:0,y:0,width:diameter,height:diameter);guide.center=point;guide.layer.cornerRadius=diameter/2;guide.isHidden=false
    }
    override func touchesBegan(_ touches:Set<UITouch>,with event:UIEvent?) {
        guard !arranging else { return }
        for touch in touches {
            let p=touch.location(in:self),left=p.x<bounds.midX
            if left != configuration.leftHanded && moveTouch==nil { moveTouch=touch;moveOrigin=p;showGuide(moveGuide,at:p,diameter:130) }
            else if lookTouch==nil { lookTouch=touch;lastLook=p;showGuide(lookGuide,at:p,diameter:64) }
        }
    }
    override func touchesMoved(_ touches:Set<UITouch>,with event:UIEvent?) {
        for touch in touches {
            let p=touch.location(in:self)
            if touch===moveTouch {
                var delta=CGPoint(x:(p.x-moveOrigin.x)/65,y:(moveOrigin.y-p.y)/65)
                let length=hypot(delta.x,delta.y)
                if length<0.15 { delta = .zero } else if length>1 { delta.x/=length;delta.y/=length }
                onMove?(delta)
            } else if touch===lookTouch { onLook?(CGPoint(x:p.x-lastLook.x,y:p.y-lastLook.y));lastLook=p;lookGuide.center=p }
        }
    }
    override func touchesEnded(_ touches:Set<UITouch>,with event:UIEvent?) {
        for touch in touches {
            if touch===moveTouch { moveTouch=nil;moveGuide.isHidden=true;onMove?(.zero) }
            if touch===lookTouch { lookTouch=nil;lookGuide.isHidden=true }
        }
    }
    override func touchesCancelled(_ touches:Set<UITouch>,with event:UIEvent?){ touchesEnded(touches,with:event) }
    func releaseAll() {
        for action in Self.actions { onAction?(action.command,false);buttons[action.title]?.isHighlighted=false }
        moveTouch=nil;lookTouch=nil;moveGuide.isHidden=true;lookGuide.isHidden=true;onMove?(.zero)
    }
    func restoreDefault(){configuration=TouchConfiguration();onConfigurationChanged?()}
}
