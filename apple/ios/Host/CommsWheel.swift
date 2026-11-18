// Quick-chat wheel: hold RB and point the right stick, or tap CHAT and tap a
// message. Sends ET's own voice chats (vsay / vsay_team). GPL-3.0-or-later.
import UIKit

final class CommsWheel: UIView {
    struct Message { let title:String,command:String,symbol:String }
    // Clockwise from the top. Team calls first, then general responses.
    static let messages:[Message]=[
        .init(title:"Medic!",command:"vsay_team Medic",symbol:"cross.case.fill"),
        .init(title:"Need Ammo",command:"vsay_team NeedAmmo",symbol:"shippingbox.fill"),
        .init(title:"Need Backup",command:"vsay_team NeedBackup",symbol:"person.2.fill"),
        .init(title:"Need Engineer",command:"vsay_team NeedEngineer",symbol:"wrench.and.screwdriver.fill"),
        .init(title:"Negative",command:"vsay_team Negative",symbol:"xmark"),
        .init(title:"Thanks",command:"vsay Thanks",symbol:"hand.thumbsup.fill"),
        .init(title:"Cover Me",command:"vsay_team CoverMe",symbol:"shield.lefthalf.filled"),
        .init(title:"Affirmative",command:"vsay_team Affirmative",symbol:"checkmark")]
    var onSend:((String)->Void)?
    var onClose:(()->Void)?
    private(set) var selected:Int?
    private var slots:[UIView]=[]
    private let hint=UILabel(),ring=UIView()
    var tapMode=false { didSet { hint.text=tapMode ? "Tap a message · tap outside to cancel":"Point the right stick · release RB to send" } }
    override init(frame:CGRect) {
        super.init(frame:frame)
        backgroundColor=ETPadTheme.ink.withAlphaComponent(0.35);isHidden=true;accessibilityViewIsModal=true
        ring.backgroundColor=ETPadTheme.ink.withAlphaComponent(0.55);ring.layer.borderColor=ETPadTheme.cream.withAlphaComponent(0.3).cgColor;ring.layer.borderWidth=1;addSubview(ring)
        for (index,message) in Self.messages.enumerated() {
            let slot=UIView();slot.layer.cornerRadius=14;slot.layer.borderWidth=1.2;slot.tag=index
            let icon=UIImageView(image:UIImage(systemName:message.symbol));icon.contentMode = .scaleAspectFit;icon.tag=1
            let label=UILabel();label.text=message.title;label.font=ETPadTheme.stencil(15,.bold);label.textAlignment = .center;label.tag=2
            label.adjustsFontSizeToFitWidth=true;label.minimumScaleFactor=0.7
            slot.addSubview(icon);slot.addSubview(label);slot.isAccessibilityElement=true;slot.accessibilityLabel=message.title;slot.accessibilityTraits = .button
            slot.addGestureRecognizer(UITapGestureRecognizer(target:self,action:#selector(tapped(_:))))
            slots.append(slot);addSubview(slot)
        }
        hint.font=UIFont.systemFont(ofSize:14,weight:.semibold);hint.textColor=ETPadTheme.cream;hint.textAlignment = .center;addSubview(hint)
        addGestureRecognizer(UITapGestureRecognizer(target:self,action:#selector(cancelTap(_:))))
        tapMode=false;refresh()
    }
    required init?(coder:NSCoder){fatalError("init(coder:)")}
    override func layoutSubviews() {
        super.layoutSubviews()
        let center=CGPoint(x:bounds.midX,y:bounds.midY),radius=min(bounds.height*0.33,250)
        ring.bounds=CGRect(x:0,y:0,width:radius*2+170,height:radius*2+90);ring.center=center;ring.layer.cornerRadius=ring.bounds.height/2
        for (index,slot) in slots.enumerated() {
            let angle=CGFloat(index)*(.pi/4) - .pi/2
            slot.bounds=CGRect(x:0,y:0,width:150,height:64)
            slot.center=CGPoint(x:center.x+cos(angle)*radius*1.25,y:center.y+sin(angle)*radius)
            slot.viewWithTag(1)?.frame=CGRect(x:12,y:20,width:24,height:24)
            slot.viewWithTag(2)?.frame=CGRect(x:40,y:0,width:104,height:64)
        }
        hint.frame=CGRect(x:center.x-200,y:center.y-12,width:400,height:24)
    }
    func show(tap:Bool) { tapMode=tap;selected=nil;refresh();isHidden=false;superview?.bringSubviewToFront(self) }
    func hide() { isHidden=true;selected=nil;onClose?() }
    // Stick direction (x right, y up). Small deflections keep the selection.
    func point(x:Float,y:Float) {
        guard hypot(x,y)>0.5 else { return }
        var angle=atan2(Double(x),Double(y)) // 0 at top, clockwise
        if angle<0 { angle += 2 * .pi }
        let index=Int((angle/(2 * .pi)*8).rounded())%8
        if index != selected { selected=index;refresh();UISelectionFeedbackGenerator().selectionChanged() }
    }
    func commit() { if let index=selected { onSend?(Self.messages[index].command) };hide() }
    private func refresh() {
        for (index,slot) in slots.enumerated() {
            let on=index==selected
            slot.backgroundColor=on ? ETPadTheme.brass:ETPadTheme.ink.withAlphaComponent(0.8)
            slot.layer.borderColor=(on ? ETPadTheme.cream:ETPadTheme.cream.withAlphaComponent(0.35)).cgColor
            let tint=on ? ETPadTheme.ink:ETPadTheme.cream
            (slot.viewWithTag(1) as? UIImageView)?.tintColor=tint;(slot.viewWithTag(2) as? UILabel)?.textColor=tint
            slot.transform=on ? CGAffineTransform(scaleX:1.08,y:1.08):.identity
        }
    }
    @objc private func tapped(_ gesture:UITapGestureRecognizer) { if let index=gesture.view?.tag { selected=index;commit() } }
    @objc private func cancelTap(_ gesture:UITapGestureRecognizer) { if tapMode { hide() } }
}
