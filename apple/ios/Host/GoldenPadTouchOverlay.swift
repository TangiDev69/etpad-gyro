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
    var lookSpeed:Double = 1
    var sprintByPush = true
    var centers:[String:[Double]] = [:]
    var buttonSizes:[String:Double] = [:]
    var buttonOpacities:[String:Double] = [:]
    init() {}
    // Older saves lack newer keys; decode each one optionally so a saved
    // configuration or named layout is never discarded by an update.
    init(from decoder:Decoder) throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        opacity=try c.decodeIfPresent(Double.self,forKey:.opacity) ?? 0.72
        size=try c.decodeIfPresent(Double.self,forKey:.size) ?? 1
        leftHanded=try c.decodeIfPresent(Bool.self,forKey:.leftHanded) ?? false
        hideWithController=try c.decodeIfPresent(Bool.self,forKey:.hideWithController) ?? true
        lookSpeed=try c.decodeIfPresent(Double.self,forKey:.lookSpeed) ?? 1
        sprintByPush=try c.decodeIfPresent(Bool.self,forKey:.sprintByPush) ?? true
        centers=try c.decodeIfPresent([String:[Double]].self,forKey:.centers) ?? [:]
        buttonSizes=try c.decodeIfPresent([String:Double].self,forKey:.buttonSizes) ?? [:]
        buttonOpacities=try c.decodeIfPresent([String:Double].self,forKey:.buttonOpacities) ?? [:]
    }
    mutating func sanitize() {
        opacity = max(0.25,min(1,opacity));size=max(0.7,min(1.3,size));lookSpeed=max(0.4,min(8.0,lookSpeed))
        centers=centers.filter { $0.value.count == 2 && $0.value.allSatisfy(\.isFinite) }.mapValues { [max(0.04,min(0.96,$0[0])),max(0.08,min(0.92,$0[1]))] }
        buttonSizes=buttonSizes.filter { $0.value.isFinite }.mapValues { max(0.55,min(1.8,$0)) }
        buttonOpacities=buttonOpacities.filter { $0.value.isFinite }.mapValues { max(0.15,min(1,$0)) }
    }
}

// Wartime poster palette shared with the launcher.
enum ETPadTheme {
    static let cream=UIColor(red:0.96,green:0.91,blue:0.80,alpha:1)
    static let oxblood=UIColor(red:0.72,green:0.13,blue:0.10,alpha:1)
    static let brass=UIColor(red:0.93,green:0.68,blue:0.30,alpha:1)
    static let olive=UIColor(red:0.36,green:0.38,blue:0.22,alpha:1)
    static let ink=UIColor(red:0.07,green:0.06,blue:0.05,alpha:1)
    static func stencil(_ size:CGFloat,_ weight:UIFont.Weight = .heavy)->UIFont { UIFont.systemFont(ofSize:size,weight:weight,width:.condensed) }
}

private final class TouchActionButton: UIButton {
    var edge:((Bool)->Void)?
    var drag:((CGPoint)->Void)?
    var editingLayout = false
    var opacity:CGFloat = 0.72
    private(set) var actionTitle = ""
    private let symbolView=UIImageView(),caption=UILabel()
    private var primary=false,compact=false,lastDrag:CGPoint?
    override var isHighlighted: Bool { didSet { if isHighlighted != oldValue { updateFace() } } }
    func configure(title:String,symbol:String,primary:Bool,compact:Bool) {
        actionTitle=title;self.primary=primary;self.compact=compact
        symbolView.image=UIImage(systemName:symbol,withConfiguration:UIImage.SymbolConfiguration(pointSize:primary ? 30:(compact ? 15:20),weight:.bold))
        caption.attributedText=NSAttributedString(string:title,attributes:[.kern:primary ? 1.4:0.9,.font:ETPadTheme.stencil(primary ? 13:(compact ? 9:10))])
        caption.isHidden=compact && title.count<2
        accessibilityLabel=title.capitalized
    }
    func updateFace() {
        // Opacity changes the face only; icons and captions stay readable.
        let pressed=isHighlighted && !editingLayout
        let resting=ETPadTheme.ink.withAlphaComponent(0.16+opacity*0.46)
        backgroundColor=pressed ? (primary ? ETPadTheme.oxblood:ETPadTheme.brass).withAlphaComponent(0.9):resting
        let ring=primary ? ETPadTheme.oxblood.withAlphaComponent(0.95):ETPadTheme.cream.withAlphaComponent(editingLayout ? 0.8:0.42)
        layer.borderColor=(pressed ? ETPadTheme.cream:ring).cgColor
        layer.borderWidth=primary ? 3:1.2
        let ink=pressed && !primary ? ETPadTheme.ink:ETPadTheme.cream
        symbolView.tintColor=ink;caption.textColor=ink
        transform=pressed ? CGAffineTransform(scaleX:0.94,y:0.94):.identity
    }
    override init(frame:CGRect) {
        super.init(frame:frame)
        isMultipleTouchEnabled=false;isExclusiveTouch=false
        symbolView.contentMode = .scaleAspectFit
        caption.textAlignment = .center;caption.adjustsFontSizeToFitWidth=true;caption.minimumScaleFactor=0.7
        symbolView.isUserInteractionEnabled=false;caption.isUserInteractionEnabled=false
        addSubview(symbolView);addSubview(caption)
        layer.shadowColor=UIColor.black.cgColor;layer.shadowOpacity=0.35
        layer.shadowRadius=4;layer.shadowOffset=CGSize(width:0,height:2)
        addTarget(self,action:#selector(down),for:.touchDown)
        addTarget(self,action:#selector(up),for:[.touchUpInside,.touchUpOutside,.touchCancel])
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let hasCaption = !caption.isHidden
        let iconSide:CGFloat=primary ? min(34,bounds.height*0.36):(compact ? 16:min(24,bounds.height*0.36))
        let gap:CGFloat=hasCaption ? (compact ? 1:3):0
        let captionHeight:CGFloat=hasCaption ? (primary ? 15:(compact ? 10:12)):0
        let top=(bounds.height-iconSide-gap-captionHeight)/2
        symbolView.frame=CGRect(x:(bounds.width-iconSide)/2,y:top,width:iconSide,height:iconSide)
        caption.frame=CGRect(x:3,y:top+iconSide+gap,width:bounds.width-6,height:captionHeight)
        layer.shadowPath=UIBezierPath(roundedRect:bounds,cornerRadius:layer.cornerRadius).cgPath
    }
    required init?(coder:NSCoder) { fatalError("init(coder:)") }
    @objc private func down(){ if !editingLayout { edge?(true) } }
    @objc private func up(){ lastDrag=nil;edge?(false) }
    // FIRE also aims: dragging the finger turns the view while firing.
    override func touchesBegan(_ touches:Set<UITouch>,with event:UIEvent?) {
        lastDrag=touches.first?.location(in:window);super.touchesBegan(touches,with:event)
    }
    override func touchesMoved(_ touches:Set<UITouch>,with event:UIEvent?) {
        if let drag=drag,!editingLayout,let p=touches.first?.location(in:window) {
            if let last=lastDrag { drag(CGPoint(x:p.x-last.x,y:p.y-last.y)) };lastDrag=p
        }
        super.touchesMoved(touches,with:event)
    }
    override func accessibilityActivate()->Bool {
        guard !editingLayout else { return false };edge?(true);isHighlighted=true
        Timer.scheduledTimer(withTimeInterval:0.12,repeats:false) { [weak self] _ in self?.edge?(false);self?.isHighlighted=false }
        return true
    }
}

// Resting movement stick. It shows where the left thumb belongs, follows the
// finger while moving and turns brass while push-to-sprint is engaged.
private final class StickView: UIView {
    let knob=UIView(),label=UILabel()
    var sprinting=false { didSet { if sprinting != oldValue { refresh() } } }
    var active=false { didSet { if active != oldValue { refresh() } } }
    override init(frame:CGRect) {
        super.init(frame:frame);isUserInteractionEnabled=false
        layer.borderWidth=1.5;addSubview(knob);addSubview(label)
        knob.layer.borderWidth=1.5
        label.attributedText=NSAttributedString(string:"SPRINT",attributes:[.kern:1.6,.font:ETPadTheme.stencil(10),.foregroundColor:ETPadTheme.ink])
        label.textAlignment = .center;label.backgroundColor=ETPadTheme.brass;label.layer.cornerRadius=8;label.clipsToBounds=true
        refresh()
    }
    required init?(coder:NSCoder){fatalError("init(coder:)")}
    func refresh() {
        let accent=sprinting ? ETPadTheme.brass:ETPadTheme.cream
        backgroundColor=ETPadTheme.ink.withAlphaComponent(active ? 0.32:0.16)
        layer.borderColor=accent.withAlphaComponent(active ? 0.7:0.32).cgColor
        knob.backgroundColor=accent.withAlphaComponent(active ? 0.55:0.22)
        knob.layer.borderColor=accent.withAlphaComponent(0.8).cgColor
        label.isHidden = !sprinting
    }
    func place(center:CGPoint,diameter:CGFloat) {
        bounds=CGRect(x:0,y:0,width:diameter,height:diameter);self.center=center;layer.cornerRadius=diameter/2
        let k=diameter*0.42;knob.bounds=CGRect(x:0,y:0,width:k,height:k);knob.layer.cornerRadius=k/2
        label.frame=CGRect(x:(diameter-64)/2,y:-26,width:64,height:18)
        setKnob(.zero)
    }
    func setKnob(_ offset:CGPoint) { knob.center=CGPoint(x:bounds.midX+offset.x,y:bounds.midY+offset.y) }
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
        // Gameplay centers are insets from the lower-right safe corner, chosen
        // to clear ET's ammo/weapon/stamina HUD (about 155 points square).
        // SCORE and MENU occupy the left HUD gutter by default.
        let x:CGFloat,y:CGFloat,diameter:CGFloat
        var compact:Bool { false }
        var gutter:Bool { title=="SCORE" || title=="MENU" || title=="CHAT" }
    }
    // Two even rings around FIRE. The inner ring holds the four actions used
    // constantly; the outer ring holds occasional ones. Angles run
    // counter-clockwise from the right, so every gap is identical.
    static let fire=CGPoint(x:248,y:112)
    static func ring(_ title:String,_ command:String,_ symbol:String,radius:CGFloat,angle:CGFloat,diameter:CGFloat)->Action {
        let a=angle * .pi/180
        return Action(title:title,command:command,symbol:symbol,x:fire.x-radius*cos(a),y:fire.y+radius*sin(a),diameter:diameter)
    }
    static let actions:[Action] = [
        .init(title:"FIRE",command:"+attack",symbol:"scope",x:fire.x,y:fire.y,diameter:104),
        ring("JUMP",  "+moveup",  "chevron.up.2",       radius:98, angle:62, diameter:62),
        ring("RELOAD","+reload",  "arrow.clockwise",    radius:98, angle:106,diameter:62),
        ring("ALT",   "weapalt",  "plus.viewfinder",    radius:98, angle:150,diameter:62),
        ring("CROUCH","+movedown","chevron.down.2",     radius:98, angle:194,diameter:62),
        ring("USE",   "+activate","hand.point.up.left.fill",radius:172,angle:76, diameter:52),
        ring("NEXT",  "weapnext", "chevron.right",      radius:172,angle:117,diameter:52),
        ring("PREV",  "weapprev", "chevron.left",       radius:172,angle:158,diameter:52),
        ring("PRONE", "+prone",   "arrow.down.to.line", radius:172,angle:199,diameter:52),
        .init(title:"SCORE",command:"etpad_scores",symbol:"list.number",x:0,y:88,diameter:64),
        .init(title:"MENU",command:"togglemenu",symbol:"line.3.horizontal",x:0,y:142,diameter:64)]
        + [.init(title:"CHAT",command:"etpad_comms",symbol:"bubble.left.and.bubble.right.fill",x:0,y:196,diameter:64)]
    var onAction:((String,Bool)->Void)?
    var onMove:((CGPoint)->Void)?
    var onLook:((CGPoint)->Void)?
    var onTouch:(()->Void)?
    var onConfigurationChanged:(()->Void)?
    var onExitArrange:(()->Void)?
    private let arrangeDone=UIButton(type:.system)
    var configuration:TouchConfiguration { didSet { configuration.sanitize();persist();setNeedsLayout() } }
    var arranging=false {
        didSet {
            if scoreboardVisible { releaseCombatActions() } else { releaseAll() }
            updateButtonVisibility();setNeedsLayout()
        }
    }
    // Supplied by the engine's actual scoreboard state, including keyboard and
    // controller activation. Never synthesize -scores when that state changes.
    var scoreboardVisible=false {
        didSet {
            guard scoreboardVisible != oldValue else { return }
            if scoreboardVisible { releaseCombatActions() }
            updateButtonVisibility();setNeedsLayout()
        }
    }
    private var buttons:[String:TouchActionButton]=[:]
    // Commands currently held by touch. Releasing only these keeps a hide
    // caused by controller or keyboard input from cancelling that input.
    private var held=Set<String>()
    private let stick=StickView(frame:.zero),lookGuide=UIView()
    private weak var moveTouch:UITouch?,lookTouch:UITouch?
    private var moveOrigin=CGPoint.zero,lastLook=CGPoint.zero,stickHome=CGPoint.zero,sprinting=false
    private let stickDiameter:CGFloat=136
    override init(frame:CGRect) {
        configuration=(UserDefaults.standard.data(forKey:"etpad.touch.configuration").flatMap { try? JSONDecoder().decode(TouchConfiguration.self,from:$0) }) ?? TouchConfiguration()
        configuration.sanitize();super.init(frame:frame)
        isMultipleTouchEnabled=true;backgroundColor = .clear;isOpaque=false
        addSubview(stick)
        lookGuide.backgroundColor=ETPadTheme.ink.withAlphaComponent(0.2);lookGuide.layer.borderColor=ETPadTheme.cream.withAlphaComponent(0.4).cgColor
        lookGuide.layer.borderWidth=1;lookGuide.isHidden=true;lookGuide.isUserInteractionEnabled=false;addSubview(lookGuide)
        arrangeDone.setTitle("Done",for:.normal);arrangeDone.setImage(UIImage(systemName:"checkmark.circle.fill"),for:.normal);arrangeDone.tintColor=ETPadTheme.cream;arrangeDone.backgroundColor=ETPadTheme.ink.withAlphaComponent(0.82);arrangeDone.layer.cornerRadius=16;arrangeDone.layer.borderWidth=1;arrangeDone.layer.borderColor=ETPadTheme.brass.cgColor;arrangeDone.titleLabel?.font=ETPadTheme.stencil(15);arrangeDone.addTarget(self,action:#selector(exitArrange),for:.touchUpInside);arrangeDone.isHidden=true;addSubview(arrangeDone)
        for action in Self.actions {
            let button=TouchActionButton(frame:.zero)
            button.configure(title:action.title,symbol:action.symbol,primary:action.title=="FIRE",compact:action.compact || action.gutter)
            button.edge = { [weak self] pressed in
                guard let self=self else { return }
                if pressed { self.onTouch?() }
                if pressed && self.scoreboardVisible && !self.arranging && !action.gutter { return }
                if pressed { self.held.insert(action.command) } else if self.held.remove(action.command) == nil { return }
                self.onAction?(action.command,pressed)
            }
            if action.title=="FIRE" { button.drag = { [weak self] delta in self?.look(delta) } }
            button.addGestureRecognizer(UIPanGestureRecognizer(target:self,action:#selector(arrange(_:))))
            buttons[action.title]=button;addSubview(button)
        }
    }
    required init?(coder:NSCoder){fatalError("init(coder:)")}
    private func persist(){if let data=try? JSONEncoder().encode(configuration){UserDefaults.standard.set(data,forKey:"etpad.touch.configuration")}}
    private func look(_ delta:CGPoint){ onLook?(CGPoint(x:delta.x*configuration.lookSpeed,y:delta.y*configuration.lookSpeed)) }
    override func layoutSubviews() {
        super.layoutSubviews()
        let safe=bounds.inset(by:safeAreaInsets)
        // ET draws its HUD in 640x480 units scaled to the screen height, so
        // controls follow the same scale: larger on 12.9-inch, smaller on mini.
        let responsive=max(0.75,min(1.25,min(safe.height/800,safe.width/1150)))
        let spacing=responsive*max(1,configuration.size)
        arrangeDone.frame=CGRect(x:safe.maxX-100,y:safe.minY+10,width:90,height:40);arrangeDone.isHidden = !arranging
        for action in Self.actions {
            guard let button=buttons[action.title] else { continue }
            let defaultCenter:CGPoint
            if action.gutter {
                defaultCenter=CGPoint(x:safe.minX+44,y:safe.minY+action.y)
            } else {
                defaultCenter=CGPoint(x:safe.maxX-action.x*spacing,y:safe.maxY-action.y*spacing)
            }
            let custom=configuration.centers[action.title]
            let x=custom.map { CGFloat($0[0]) } ?? (defaultCenter.x-safe.minX)/safe.width
            // ET's health/class HUD and killfeed stay at bottom left when
            // controls mirror. Lift only default combat positions above them;
            // explicit saved layouts retain their chosen vertical coordinates.
            let leftHUDLift:CGFloat=configuration.leftHanded && !action.gutter && custom == nil ? 150:0
            let y=custom.map { CGFloat($0[1]) } ?? (defaultCenter.y-leftHUDLift-safe.minY)/safe.height
            let mirror=configuration.leftHanded && (!action.gutter || custom != nil)
            let center=CGPoint(x:safe.minX+(mirror ? 1-x:x)*safe.width,y:safe.minY+y*safe.height)
            // Keep occasional controls inside the narrow scoreboard gutter even
            // at large Size settings. Gameplay targets still follow Size.
            let individualSize=CGFloat(configuration.buttonSizes[action.title] ?? 1)
            let width=action.gutter ? max(44,64*individualSize):max(36,action.diameter*responsive*configuration.size*individualSize)
            let height=action.gutter ? 44:width
            button.bounds=CGRect(x:0,y:0,width:width,height:height)
            button.center=CGPoint(x:max(safe.minX+width/2,min(safe.maxX-width/2,center.x)),y:max(safe.minY+height/2,min(safe.maxY-height/2,center.y)))
            // An open scoreboard fills the screen; SCORE moves to the free
            // bottom-left corner to close it again.
            if scoreboardVisible && !arranging && action.title=="SCORE" { button.center=CGPoint(x:safe.minX+44,y:safe.maxY-34) }
            button.layer.cornerRadius=button.bounds.height/2
            button.isHidden=scoreboardVisible && !arranging && action.title != "SCORE"
            button.editingLayout=arranging;button.opacity=configuration.opacity;button.alpha=CGFloat(configuration.buttonOpacities[action.title] ?? 1);button.updateFace()
            button.gestureRecognizers?.forEach { $0.isEnabled=arranging }
        }
        // The resting stick sits beside ET's health/portrait HUD.
        let stickSide=stickDiameter*responsive*configuration.size
        // Right of ET's portrait and slot HUD, at a resting left-thumb height.
        let homeX=safe.minX+360*spacing
        stickHome=CGPoint(x:configuration.leftHanded ? safe.maxX-(homeX-safe.minX):homeX,y:safe.maxY-140*spacing)
        // The stick is invisible at rest and appears under the thumb. While
        // arranging, its home position shows where a thumb usually starts.
        if moveTouch==nil { stick.place(center:stickHome,diameter:stickSide) }
        stick.isHidden=arranging ? false:(scoreboardVisible || moveTouch==nil)
        stick.alpha=CGFloat(0.55+configuration.opacity*0.45)
        if !arranging && lookTouch==nil { lookGuide.isHidden=true }
    }
    @objc private func exitArrange(){onExitArrange?()}
    @objc private func arrange(_ recognizer:UIPanGestureRecognizer) {
        guard arranging,let button=recognizer.view as? TouchActionButton else { return }
        let title=button.actionTitle
        let location=recognizer.location(in:self),safe=bounds.inset(by:safeAreaInsets)
        var x=(location.x-safe.minX)/safe.width;if configuration.leftHanded { x=1-x }
        configuration.centers[title]=[Double(x),Double((location.y-safe.minY)/safe.height)]
        if recognizer.state == .ended { onConfigurationChanged?() }
    }
    override func touchesBegan(_ touches:Set<UITouch>,with event:UIEvent?) {
        guard !arranging && !scoreboardVisible else { return }
        if touches.contains(where:{ $0.type == .direct }) { onTouch?() }
        for touch in touches {
            let p=touch.location(in:self),left=p.x<bounds.midX
            if left != configuration.leftHanded && moveTouch==nil {
                moveTouch=touch;moveOrigin=p;stick.active=true;stick.place(center:p,diameter:stick.bounds.width);stick.isHidden=false
            } else if lookTouch==nil {
                lookTouch=touch;lastLook=p
                lookGuide.bounds=CGRect(x:0,y:0,width:60,height:60);lookGuide.layer.cornerRadius=30;lookGuide.center=p;lookGuide.isHidden=false
            }
        }
    }
    override func touchesMoved(_ touches:Set<UITouch>,with event:UIEvent?) {
        guard !arranging && !scoreboardVisible else { return }
        for touch in touches {
            let p=touch.location(in:self)
            if touch===moveTouch {
                let radius=stick.bounds.width/2
                var raw=CGPoint(x:p.x-moveOrigin.x,y:p.y-moveOrigin.y)
                let distance=hypot(raw.x,raw.y)
                // Push well past the rim while mostly forward to sprint.
                let sprint=configuration.sprintByPush && distance>radius*1.45 && -raw.y>distance*0.7
                setSprint(sprint)
                if distance>radius { raw.x*=radius/distance;raw.y*=radius/distance }
                stick.setKnob(raw)
                var delta=CGPoint(x:raw.x/(radius*0.9),y:-raw.y/(radius*0.9))
                let length=hypot(delta.x,delta.y)
                if length<0.12 { delta = .zero } else if length>1 { delta.x/=length;delta.y/=length }
                onMove?(delta)
            } else if touch===lookTouch {
                look(CGPoint(x:p.x-lastLook.x,y:p.y-lastLook.y));lastLook=p;lookGuide.center=p
            }
        }
    }
    override func touchesEnded(_ touches:Set<UITouch>,with event:UIEvent?) {
        for touch in touches {
            if touch===moveTouch { endMove() }
            if touch===lookTouch { lookTouch=nil;lookGuide.isHidden=true }
        }
    }
    override func touchesCancelled(_ touches:Set<UITouch>,with event:UIEvent?){ touchesEnded(touches,with:event) }
    private func setSprint(_ on:Bool) {
        guard on != sprinting else { return }
        sprinting=on;stick.sprinting=on;onAction?("+sprint",on)
    }
    private func endMove() {
        moveTouch=nil;setSprint(false);stick.active=false;stick.isHidden = !arranging;stick.place(center:stickHome,diameter:stick.bounds.width);onMove?(.zero)
    }
    private func updateButtonVisibility() {
        for action in Self.actions {
            buttons[action.title]?.isHidden=scoreboardVisible && !arranging && action.title != "SCORE"
        }
        stick.isHidden=arranging ? false:(scoreboardVisible || moveTouch==nil)
    }
    private func releaseCombatActions() {
        for action in Self.actions where !action.gutter {
            if held.remove(action.command) != nil { onAction?(action.command,false) }
            buttons[action.title]?.isHighlighted=false
        }
        lookTouch=nil;lookGuide.isHidden=true
        if moveTouch != nil { endMove() } else { setSprint(false) } // a controller stick shares the move axes
        onLook?(.zero)
    }
    func releaseAll() {
        for command in held { onAction?(command,false) };held.removeAll()
        for action in Self.actions { buttons[action.title]?.isHighlighted=false }
        lookTouch=nil;lookGuide.isHidden=true
        if moveTouch != nil { endMove() } else { setSprint(false) } // a controller stick shares the move axes
    }
    func restoreDefault(){configuration=TouchConfiguration();onConfigurationChanged?()}
    func setButtonSize(_ title:String,_ value:Double){configuration.buttonSizes[title]=value}
    func setButtonOpacity(_ title:String,_ value:Double){configuration.buttonOpacities[title]=value}
}
