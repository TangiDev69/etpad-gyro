// Quick-chat wheel: hold RB and point the right stick, or tap CHAT and tap a
// wedge. Sends ET's own voice chats (vsay / vsay_team). GPL-3.0-or-later.
import UIKit

final class CommsWheel: UIView {
    struct Message { let title:String,command:String,symbol:String; var team:Bool { command.hasPrefix("vsay_team") } }
    // Clockwise from the top: calls for help, then responses.
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
    private let disc=UIView(),ringLayer=CAShapeLayer(),highlight=CAShapeLayer(),dividers=CAShapeLayer(),hub=CAShapeLayer()
    private let centerTitle=UILabel(),centerDetail=UILabel()
    private var icons:[UIImageView]=[],labels:[UILabel]=[]
    private var outer:CGFloat=200,inner:CGFloat=86
    var tapMode=false
    override init(frame:CGRect) {
        super.init(frame:frame)
        backgroundColor=ETPadTheme.ink.withAlphaComponent(0.28);isHidden=true;accessibilityViewIsModal=true
        disc.isUserInteractionEnabled=false;addSubview(disc)
        ringLayer.fillColor=ETPadTheme.ink.withAlphaComponent(0.82).cgColor;ringLayer.fillRule = .evenOdd
        ringLayer.strokeColor=ETPadTheme.cream.withAlphaComponent(0.28).cgColor;ringLayer.lineWidth=1.5
        highlight.fillColor=ETPadTheme.brass.cgColor
        dividers.strokeColor=ETPadTheme.cream.withAlphaComponent(0.16).cgColor;dividers.lineWidth=1
        hub.fillColor=ETPadTheme.ink.cgColor;hub.strokeColor=ETPadTheme.brass.withAlphaComponent(0.6).cgColor;hub.lineWidth=2
        for layer in [ringLayer,highlight,dividers,hub] { disc.layer.addSublayer(layer) }
        for message in Self.messages {
            let icon=UIImageView(image:UIImage(systemName:message.symbol,withConfiguration:UIImage.SymbolConfiguration(pointSize:22,weight:.bold)))
            icon.contentMode = .scaleAspectFit;disc.addSubview(icon);icons.append(icon)
            let label=UILabel();label.text=message.title.uppercased();label.font=ETPadTheme.stencil(12,.heavy);label.textAlignment = .center
            label.adjustsFontSizeToFitWidth=true;label.minimumScaleFactor=0.7;disc.addSubview(label);labels.append(label)
        }
        centerTitle.font=ETPadTheme.stencil(22,.black);centerTitle.textAlignment = .center;centerTitle.textColor=ETPadTheme.cream
        centerTitle.adjustsFontSizeToFitWidth=true;centerTitle.minimumScaleFactor=0.6
        centerDetail.font=UIFont.systemFont(ofSize:11,weight:.semibold);centerDetail.textAlignment = .center;centerDetail.numberOfLines=2
        centerDetail.textColor=ETPadTheme.cream.withAlphaComponent(0.7)
        disc.addSubview(centerTitle);disc.addSubview(centerDetail)
        addGestureRecognizer(UITapGestureRecognizer(target:self,action:#selector(tapped(_:))))
        isAccessibilityElement=false;refresh()
    }
    required init?(coder:NSCoder){fatalError("init(coder:)")}
    override func layoutSubviews() {
        super.layoutSubviews()
        outer=min(bounds.height*0.34,240);inner=outer*0.42
        disc.frame=CGRect(x:bounds.midX-outer,y:bounds.midY-outer,width:outer*2,height:outer*2)
        let c=CGPoint(x:outer,y:outer)
        let ring=UIBezierPath(arcCenter:c,radius:outer,startAngle:0,endAngle:.pi*2,clockwise:true)
        ring.append(UIBezierPath(arcCenter:c,radius:inner,startAngle:0,endAngle:.pi*2,clockwise:true))
        ringLayer.path=ring.cgPath
        hub.path=UIBezierPath(arcCenter:c,radius:inner-6,startAngle:0,endAngle:.pi*2,clockwise:true).cgPath
        let lines=UIBezierPath()
        for i in 0..<8 {
            let a=angle(boundaryOf:i)
            lines.move(to:point(c,inner,a));lines.addLine(to:point(c,outer,a))
        }
        dividers.path=lines.cgPath
        let mid=(outer+inner)/2
        for i in 0..<8 {
            let a=angle(centerOf:i),p=point(c,mid,a)
            icons[i].frame=CGRect(x:p.x-14,y:p.y-24,width:28,height:28)
            labels[i].frame=CGRect(x:p.x-48,y:p.y+8,width:96,height:16)
        }
        centerTitle.frame=CGRect(x:c.x-inner+12,y:c.y-26,width:(inner-12)*2,height:28)
        centerDetail.frame=CGRect(x:c.x-inner+14,y:c.y+4,width:(inner-14)*2,height:30)
        refresh()
    }
    // Wedge i spans 45°, centered on i*45° clockwise from the top.
    private func angle(centerOf i:Int)->CGFloat { CGFloat(i)*(.pi/4) - .pi/2 }
    private func angle(boundaryOf i:Int)->CGFloat { angle(centerOf:i) - .pi/8 }
    private func point(_ c:CGPoint,_ r:CGFloat,_ a:CGFloat)->CGPoint { CGPoint(x:c.x+cos(a)*r,y:c.y+sin(a)*r) }
    func show(tap:Bool) { tapMode=tap;selected=nil;refresh();isHidden=false;superview?.bringSubviewToFront(self) }
    func hide() { isHidden=true;selected=nil;onClose?() }
    // Stick direction (x right, y up). Returning to center keeps the choice.
    func point(x:Float,y:Float) {
        guard hypot(x,y)>0.45 else { return }
        var a=atan2(Double(x),Double(y));if a<0 { a += 2 * .pi }
        select(Int((a/(2 * .pi)*8).rounded())%8)
    }
    private func select(_ index:Int) {
        guard index != selected else { return }
        selected=index;refresh();UISelectionFeedbackGenerator().selectionChanged()
    }
    func commit() { if let index=selected { onSend?(Self.messages[index].command) };hide() }
    private func refresh() {
        let c=CGPoint(x:outer,y:outer)
        if let i=selected {
            let path=UIBezierPath(arcCenter:c,radius:outer-3,startAngle:angle(boundaryOf:i),endAngle:angle(boundaryOf:i) + .pi/4,clockwise:true)
            path.addArc(withCenter:c,radius:inner+3,startAngle:angle(boundaryOf:i) + .pi/4,endAngle:angle(boundaryOf:i),clockwise:false)
            path.close();highlight.path=path.cgPath
            let message=Self.messages[i]
            centerTitle.text=message.title.uppercased()
            centerDetail.text=(message.team ? "To your team":"To everyone")+"\n"+"Release RB to send"
        } else {
            highlight.path=nil;centerTitle.text="QUICK CHAT"
            centerDetail.text=tapMode ? "Tap a message\nTap outside to cancel":"Point the right stick\nRelease RB to send"
        }
        for i in 0..<8 {
            let on=i==selected
            icons[i].tintColor=on ? ETPadTheme.ink:ETPadTheme.cream;labels[i].textColor=on ? ETPadTheme.ink:ETPadTheme.cream.withAlphaComponent(0.85)
        }
    }
    @objc private func tapped(_ gesture:UITapGestureRecognizer) {
        guard tapMode else { return }
        let p=gesture.location(in:disc),c=CGPoint(x:outer,y:outer)
        let d=hypot(p.x-c.x,p.y-c.y)
        if d<inner { if selected != nil { commit() };return }
        guard d<=outer+20 else { hide();return }
        var a=atan2(Double(p.x-c.x),Double(c.y-p.y));if a<0 { a += 2 * .pi }
        // One tap sends: touch players should not need two taps mid-fight.
        selected=Int((a/(2 * .pi)*8).rounded())%8;commit()
    }
}
