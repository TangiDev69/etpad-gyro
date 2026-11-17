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
    private(set) var actionTitle = ""
    private let symbolView=UIImageView(),caption=UILabel()
    private var primary=false,utility=false
    override var isHighlighted: Bool { didSet { updateFace() } }
    func configure(title:String,symbol:String,primary:Bool,utility:Bool) {
        actionTitle=title;self.primary=primary;self.utility=utility
        let symbolSize:CGFloat=primary ? 26:(utility ? 15:21)
        symbolView.image=UIImage(systemName:symbol,withConfiguration:UIImage.SymbolConfiguration(pointSize:symbolSize,weight:.semibold))
        caption.text=title;caption.font = .roundedBold(size:primary ? 12:(utility ? 9:10))
        accessibilityLabel=title
    }
    func updateFace() {
        // Opacity controls the face, keeping symbols and captions readable.
        let pressed=isHighlighted && !editingLayout
        backgroundColor=pressed ? accent.withAlphaComponent(0.82):UIColor.black.withAlphaComponent(0.18+opacity*0.46)
        layer.borderColor=UIColor.white.withAlphaComponent(editingLayout ? 0.65:(pressed ? 0.75:0.28)).cgColor
        layer.borderWidth=primary ? 1.3:0.8
        symbolView.tintColor = .white;caption.textColor = .white
        alpha=1
    }
    override init(frame:CGRect) {
        super.init(frame:frame)
        isMultipleTouchEnabled=false;isExclusiveTouch=false
        symbolView.contentMode = .scaleAspectFit
        caption.textAlignment = .center;caption.adjustsFontSizeToFitWidth=true;caption.minimumScaleFactor=0.8
        symbolView.isUserInteractionEnabled=false;caption.isUserInteractionEnabled=false
        addSubview(symbolView);addSubview(caption)
        layer.shadowColor=UIColor.black.cgColor;layer.shadowOpacity=0.16
        layer.shadowRadius=3;layer.shadowOffset=CGSize(width:0,height:1)
        addTarget(self,action:#selector(down),for:.touchDown)
        addTarget(self,action:#selector(up),for:[.touchUpInside,.touchUpOutside,.touchCancel])
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let iconSide:CGFloat=primary ? min(28,max(20,bounds.height*0.35)):(utility ? 17:23)
        let gap:CGFloat=utility ? 2:4
        let captionHeight:CGFloat=primary ? 15:(utility ? 11:13)
        let top=(bounds.height-iconSide-gap-captionHeight)/2
        symbolView.frame=CGRect(x:(bounds.width-iconSide)/2,y:top,width:iconSide,height:iconSide)
        caption.frame=CGRect(x:2,y:top+iconSide+gap,width:bounds.width-4,height:captionHeight)
        layer.shadowPath=UIBezierPath(roundedRect:bounds,cornerRadius:bounds.height/2).cgPath
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
        let title:String,command:String,symbol:String
        // Aiming controls are inset from the lower-right safe corner. Utility
        // offsets are relative to the center of the separate compact diamond.
        let x:CGFloat,y:CGFloat,diameter:CGFloat
        let tint:UIColor
        var utility:Bool { ["SCORE","PREV","NEXT","USE"].contains(title) }
    }
    static let actions:[Action] = [
        .init(title:"FIRE",command:"+attack",symbol:"scope",x:82,y:190,diameter:84,tint:.systemRed),
        .init(title:"ALT",command:"weapalt",symbol:"arrow.triangle.2.circlepath",x:84,y:282,diameter:62,tint:.systemOrange),
        .init(title:"JUMP",command:"+moveup",symbol:"arrow.up",x:88,y:100,diameter:64,tint:.systemBlue),
        .init(title:"CROUCH",command:"+movedown",symbol:"arrow.down",x:171,y:126,diameter:62,tint:.systemTeal),
        .init(title:"PRONE",command:"+prone",symbol:"arrow.down.to.line",x:250,y:111,diameter:60,tint:.systemPurple),
        .init(title:"RELOAD",command:"+reload",symbol:"arrow.clockwise",x:172,y:263,diameter:64,tint:.systemYellow),
        .init(title:"SCORE",command:"+scores",symbol:"list.number",x:0,y:-56,diameter:48,tint:.systemGray),
        .init(title:"PREV",command:"weapprev",symbol:"chevron.left",x:-56,y:0,diameter:48,tint:.systemGray),
        .init(title:"NEXT",command:"weapnext",symbol:"chevron.right",x:56,y:0,diameter:48,tint:.systemGray),
        .init(title:"USE",command:"+activate",symbol:"hand.tap",x:0,y:56,diameter:48,tint:.systemGreen),
        .init(title:"MENU",command:"togglemenu",symbol:"line.3.horizontal",x:0,y:0,diameter:64,tint:.systemGray)]
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
            let button=TouchActionButton(frame:.zero)
            button.configure(title:action.title,symbol:action.symbol,primary:action.title=="FIRE",utility:action.utility || action.title=="MENU")
            button.accent=action.tint
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
        let responsive=min(1,min(safe.width/1100,safe.height/720))
        let spacing=max(0.85,responsive)*max(1,configuration.size)
        let utilityCenter=CGPoint(x:safe.minX+safe.width*0.33,y:safe.maxY-185*spacing)
        for action in Self.actions {
            guard let button=buttons[action.title] else { continue }
            let defaultCenter:CGPoint
            if action.title=="MENU" {
                // Bottom-align inside the safe area, below ET's spectator label.
                let menuHeight=max(44,44*configuration.size)
                defaultCenter=CGPoint(x:safe.midX,y:safe.maxY-menuHeight/2-4)
            } else if action.utility {
                defaultCenter=CGPoint(x:utilityCenter.x+action.x*spacing,y:utilityCenter.y+action.y*spacing)
            } else {
                defaultCenter=CGPoint(x:safe.maxX-action.x*spacing,y:safe.maxY-action.y*spacing)
            }
            let custom=configuration.centers[action.title]
            let x=custom.map { CGFloat($0[0]) } ?? (defaultCenter.x-safe.minX)/safe.width
            let y=custom.map { CGFloat($0[1]) } ?? (defaultCenter.y-safe.minY)/safe.height
            let center=CGPoint(x:safe.minX+(configuration.leftHanded ? 1-x:x)*safe.width,y:safe.minY+y*safe.height)
            let width=max(44,action.diameter*responsive*configuration.size)
            let height=action.title=="MENU" ? max(44,44*configuration.size):width
            button.bounds=CGRect(x:0,y:0,width:width,height:height)
            button.center=CGPoint(x:max(safe.minX+width/2,min(safe.maxX-width/2,center.x)),y:max(safe.minY+height/2,min(safe.maxY-height/2,center.y)))
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
        guard arranging,let button=recognizer.view as? TouchActionButton else { return }
        let title=button.actionTitle
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
