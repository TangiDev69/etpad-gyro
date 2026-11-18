// ETPad launcher: wartime poster art, data setup and the three ways to play.
// Layout follows SquirrelPad's launcher hierarchy. GPL-3.0-or-later.
import UIKit

final class LauncherView: UIView {
    enum State: Equatable { case checking,missing,busy(String),ready,starting }
    var onPlayOnline:(()->Void)?
    var onMainMenu:(()->Void)?
    var onDownload:(()->Void)?
    var onImport:(()->Void)?
    var onHelp:(()->Void)?
    var onQuickPractice:(()->Void)?
    var practiceMenu:UIMenu? { didSet { practice.menu=practiceMenu } }
    private(set) var state:State = .checking
    private var focus:Int?
    private let art=UIImageView(image:UIImage(named:"LauncherArt"))
    private let shade=CAGradientLayer(),floor=CAGradientLayer()
    private let eyebrow=UILabel(),kicker=UILabel(),wordmark=UILabel(),tagline=UILabel(),footer=UILabel()
    private let primary=UIButton(type:.system),practice=UIButton(type:.system),secondary=UIButton(type:.system),help=UIButton(type:.system)
    private let spinner=UIActivityIndicatorView(style:.medium)
    private let brand=UIStackView()
    override init(frame:CGRect) {
        super.init(frame:frame)
        backgroundColor=ETPadTheme.ink;overrideUserInterfaceStyle = .dark;accessibilityIdentifier="etpad.launcher"
        art.contentMode = .scaleAspectFill;art.clipsToBounds=true;art.isAccessibilityElement=false;addSubview(art)
        shade.startPoint=CGPoint(x:0,y:0.5);shade.endPoint=CGPoint(x:1,y:0.5)
        shade.colors=[ETPadTheme.ink.withAlphaComponent(0.92).cgColor,ETPadTheme.ink.withAlphaComponent(0.55).cgColor,UIColor.clear.cgColor]
        shade.locations=[0,0.42,0.75];layer.addSublayer(shade)
        floor.colors=[UIColor.clear.cgColor,ETPadTheme.ink.withAlphaComponent(0.85).cgColor];floor.locations=[0.6,1];layer.addSublayer(floor)

        let icon=UIImageView(image:UIImage(named:"LauncherIcon"));icon.layer.cornerRadius=10;icon.clipsToBounds=true
        icon.translatesAutoresizingMaskIntoConstraints=false
        let name=UILabel();name.attributedText=NSAttributedString(string:"ETPad",attributes:[.font:UIFont.systemFont(ofSize:22,weight:.bold),.foregroundColor:ETPadTheme.cream])
        let header=UIStackView(arrangedSubviews:[icon,name]);header.spacing=12;header.alignment = .center
        header.translatesAutoresizingMaskIntoConstraints=false;addSubview(header)

        eyebrow.numberOfLines=1;eyebrow.adjustsFontSizeToFitWidth=true;eyebrow.minimumScaleFactor=0.7
        kicker.attributedText=NSAttributedString(string:"WOLFENSTEIN",attributes:[.kern:7,.font:ETPadTheme.stencil(20,.heavy),.foregroundColor:ETPadTheme.cream.withAlphaComponent(0.85)])
        let title=NSMutableAttributedString(string:"ENEMY\n",attributes:[.kern:2,.font:ETPadTheme.stencil(76,.black),.foregroundColor:ETPadTheme.cream])
        title.append(NSAttributedString(string:"TERRITORY",attributes:[.kern:2,.font:ETPadTheme.stencil(76,.black),.foregroundColor:ETPadTheme.brass]))
        let paragraph=NSMutableParagraphStyle();paragraph.lineHeightMultiple=0.82
        title.addAttribute(.paragraphStyle,value:paragraph,range:NSRange(location:0,length:title.length))
        wordmark.attributedText=title;wordmark.numberOfLines=2;wordmark.adjustsFontSizeToFitWidth=true;wordmark.minimumScaleFactor=0.5
        wordmark.accessibilityLabel="Wolfenstein: Enemy Territory";wordmark.accessibilityTraits = .header
        tagline.numberOfLines=0;tagline.font=UIFont.systemFont(ofSize:16,weight:.regular);tagline.textColor=ETPadTheme.cream.withAlphaComponent(0.78)

        style(primary,title:"Play Online",symbol:"globe.europe.africa.fill",filled:true)
        style(practice,title:"Practice with Bots",symbol:"person.3.fill",filled:false)
        style(secondary,title:"Main Menu",symbol:"list.bullet.rectangle",filled:false)
        practice.showsMenuAsPrimaryAction=true
        primary.addAction(UIAction { [weak self] _ in self?.primaryTapped() },for:.touchUpInside)
        secondary.addAction(UIAction { [weak self] _ in self?.secondaryTapped() },for:.touchUpInside)
        let buttons=UIStackView(arrangedSubviews:[primary,practice,secondary]);buttons.spacing=12;buttons.alignment = .center

        var helpStyle=UIButton.Configuration.plain()
        helpStyle.image=UIImage(systemName:"questionmark.circle");helpStyle.imagePadding=6;helpStyle.title="How to Play"
        helpStyle.baseForegroundColor=ETPadTheme.cream;helpStyle.cornerStyle = .capsule
        helpStyle.background.backgroundColor=ETPadTheme.ink.withAlphaComponent(0.72);helpStyle.background.strokeColor=ETPadTheme.cream.withAlphaComponent(0.3);helpStyle.background.strokeWidth=1
        helpStyle.contentInsets=NSDirectionalEdgeInsets(top:0,leading:16,bottom:0,trailing:16)
        helpStyle.titleTextAttributesTransformer=UIConfigurationTextAttributesTransformer { var a=$0;a.font=UIFont.systemFont(ofSize:15,weight:.semibold);return a }
        help.configuration=helpStyle;help.addAction(UIAction { [weak self] _ in self?.onHelp?() },for:.touchUpInside)
        help.translatesAutoresizingMaskIntoConstraints=false;addSubview(help)

        let statusRow=UIStackView(arrangedSubviews:[spinner,eyebrow]);statusRow.spacing=8
        spinner.color=ETPadTheme.brass;spinner.hidesWhenStopped=true
        for (view,space) in [(statusRow,14),(kicker,4),(wordmark,14),(tagline,26),(buttons,0)] as [(UIView,CGFloat)] { brand.addArrangedSubview(view);brand.setCustomSpacing(space,after:view) }
        brand.axis = .vertical;brand.alignment = .leading;brand.translatesAutoresizingMaskIntoConstraints=false;addSubview(brand)
        footer.numberOfLines=1;footer.adjustsFontSizeToFitWidth=true;footer.minimumScaleFactor=0.7;footer.translatesAutoresizingMaskIntoConstraints=false;addSubview(footer)
        let guide=safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant:40),icon.heightAnchor.constraint(equalToConstant:40),
            header.leadingAnchor.constraint(equalTo:guide.leadingAnchor,constant:48),header.topAnchor.constraint(equalTo:guide.topAnchor,constant:28),
            // Same row and height as the ••• capsule (48 wide, 48 from the edge).
            help.centerYAnchor.constraint(equalTo:header.centerYAnchor),help.heightAnchor.constraint(equalToConstant:44),
            help.trailingAnchor.constraint(equalTo:guide.trailingAnchor,constant:-106),
            brand.leadingAnchor.constraint(equalTo:guide.leadingAnchor,constant:48),brand.trailingAnchor.constraint(lessThanOrEqualTo:guide.trailingAnchor,constant:-48),
            wordmark.widthAnchor.constraint(lessThanOrEqualTo:guide.widthAnchor,multiplier:0.55),
            tagline.widthAnchor.constraint(lessThanOrEqualToConstant:470),
            brand.centerYAnchor.constraint(equalTo:guide.centerYAnchor,constant:30),
            footer.leadingAnchor.constraint(equalTo:guide.leadingAnchor,constant:48),footer.trailingAnchor.constraint(lessThanOrEqualTo:guide.trailingAnchor,constant:-48),
            footer.bottomAnchor.constraint(equalTo:guide.bottomAnchor,constant:-26)])
        setState(.checking)
        NotificationCenter.default.addObserver(self,selector:#selector(motionChanged),name:UIAccessibility.reduceMotionStatusDidChangeNotification,object:nil)
    }
    required init?(coder:NSCoder){fatalError("init(coder:)")}
    override func layoutSubviews() {
        super.layoutSubviews()
        let artBounds=bounds.insetBy(dx:-bounds.width*0.03,dy:-bounds.height*0.03)
        if art.bounds.size != artBounds.size { art.bounds=CGRect(origin:.zero,size:artBounds.size);art.center=CGPoint(x:bounds.midX,y:bounds.midY) }
        CATransaction.begin();CATransaction.setDisableActions(true);shade.frame=bounds;floor.frame=bounds;CATransaction.commit()
        startDrift()
    }
    override func didMoveToWindow(){super.didMoveToWindow();startDrift()}
    // A slow drift gives the poster some life; Reduce Motion keeps it still.
    private func startDrift() {
        guard window != nil else { return }
        if UIAccessibility.isReduceMotionEnabled { art.layer.removeAllAnimations();art.transform = .identity;return }
        guard art.layer.animation(forKey:"drift")==nil else { return }
        let drift=CABasicAnimation(keyPath:"transform")
        drift.fromValue=CATransform3DIdentity
        drift.toValue=CATransform3DConcat(CATransform3DMakeScale(1.05,1.05,1),CATransform3DMakeTranslation(-bounds.width*0.015,0,0))
        drift.duration=24;drift.autoreverses=true;drift.repeatCount = .infinity
        drift.timingFunction=CAMediaTimingFunction(name:.easeInEaseOut)
        art.layer.add(drift,forKey:"drift")
    }
    @objc private func motionChanged(){art.layer.removeAnimation(forKey:"drift");startDrift()}
    private func style(_ button:UIButton,title:String,symbol:String,filled:Bool) {
        var c=filled ? UIButton.Configuration.filled():UIButton.Configuration.plain()
        c.title=title;c.image=UIImage(systemName:symbol);c.imagePadding=10;c.cornerStyle = .medium
        c.preferredSymbolConfigurationForImage=UIImage.SymbolConfiguration(pointSize:16,weight:.bold)
        c.titleTextAttributesTransformer=UIConfigurationTextAttributesTransformer { var a=$0;a.font=UIFont.systemFont(ofSize:17,weight:.bold);return a }
        c.contentInsets=NSDirectionalEdgeInsets(top:16,leading:filled ? 24:18,bottom:16,trailing:filled ? 26:18)
        if filled {
            c.baseBackgroundColor=ETPadTheme.oxblood;c.baseForegroundColor=ETPadTheme.cream
            c.background.strokeColor=ETPadTheme.cream.withAlphaComponent(0.35);c.background.strokeWidth=1
        } else {
            c.baseForegroundColor=ETPadTheme.cream
            c.background.backgroundColor=ETPadTheme.ink.withAlphaComponent(0.55)
            c.background.strokeColor=ETPadTheme.cream.withAlphaComponent(0.35);c.background.strokeWidth=1
        }
        button.configuration=c
        button.layer.shadowColor=UIColor.black.cgColor;button.layer.shadowOpacity=filled ? 0.45:0;button.layer.shadowRadius=12;button.layer.shadowOffset=CGSize(width:0,height:6)
    }
    private func retitle(_ button:UIButton,_ title:String,_ symbol:String) {
        var c=button.configuration;c?.title=title;c?.image=UIImage(systemName:symbol);button.configuration=c
    }
    private func setEyebrow(_ text:String,color:UIColor) {
        eyebrow.attributedText=NSAttributedString(string:"●  "+text.uppercased(),attributes:[.kern:2.2,.font:UIFont.systemFont(ofSize:13,weight:.heavy),.foregroundColor:color])
    }
    private func setFooter(_ items:[(String,String)]) {
        let text=NSMutableAttributedString()
        for (index,item) in items.enumerated() {
            if index>0 { text.append(NSAttributedString(string:"      ")) }
            let attachment=NSTextAttachment(image:UIImage(systemName:item.0,withConfiguration:UIImage.SymbolConfiguration(pointSize:12,weight:.semibold))!.withTintColor(ETPadTheme.cream.withAlphaComponent(0.7),renderingMode:.alwaysOriginal))
            text.append(NSAttributedString(attachment:attachment))
            text.append(NSAttributedString(string:"  "+item.1,attributes:[.font:UIFont.systemFont(ofSize:13,weight:.medium),.foregroundColor:ETPadTheme.cream.withAlphaComponent(0.7)]))
        }
        footer.attributedText=text
    }
    func setState(_ newState:State) {
        state=newState
        let ready=newState == .ready
        practice.isHidden = !ready;secondary.isHidden = !(ready || newState == .missing)
        primary.isEnabled=ready || newState == .missing;secondary.isEnabled=primary.isEnabled
        switch newState {
        case .checking:
            spinner.startAnimating();setEyebrow("Checking game data",color:ETPadTheme.brass)
            tagline.text="Making sure the original game files are in place.";retitle(primary,"Play Online","globe.europe.africa.fill")
        case .missing:
            spinner.stopAnimating();setEyebrow("Game data needed",color:ETPadTheme.brass)
            tagline.text="ETPad plays with the original pak0, pak1 and pak2 files. Download Splash Damage's free official release, or import your own copies from Files."
            retitle(primary,"Download Free Game Data","arrow.down.circle.fill");retitle(secondary,"Import pak Files…","folder")
        case .busy(let message):
            spinner.startAnimating();setEyebrow(message,color:ETPadTheme.brass)
            tagline.text="Keep ETPad open while the files download and are checked."
        case .ready:
            spinner.stopAnimating();setEyebrow("Ready for deployment",color:ETPadTheme.brass)
            tagline.text="Objective-based WWII multiplayer: join a live server, drill against bots, or open the classic menu."
            retitle(primary,"Play Online","globe.europe.africa.fill");retitle(secondary,"Main Menu","list.bullet.rectangle")
        case .starting:
            spinner.startAnimating();setEyebrow("Deploying",color:ETPadTheme.brass);practice.isHidden=true;secondary.isHidden=true;primary.isHidden=true
        }
        if newState != .starting { primary.isHidden=false }
        setFooter(ready || newState == .starting ? [("gamecontroller","Touch, controller, or keyboard and mouse"),("checkmark.seal","Original game data verified")]
                  : [("gamecontroller","Touch, controller, or keyboard and mouse"),("doc.text","Game data stays under Splash Damage's original EULA")])
    }
    private func primaryTapped() { state == .missing ? onDownload?():onPlayOnline?() }
    private func secondaryTapped() { state == .missing ? onImport?():onMainMenu?() }
    // Controller navigation: left/right moves a brass focus ring, A chooses.
    // A on Practice with Bots starts the last practice map without the menu.
    func controller(move:Int,activate:Bool) {
        let buttons=[primary,practice,secondary].filter { !$0.isHidden && $0.isEnabled }
        guard !buttons.isEmpty else { return }
        if move != 0 || focus == nil { focus=max(0,min(buttons.count-1,(focus ?? -move)+move)) }
        let index=min(focus ?? 0,buttons.count-1)
        for button in [primary,practice,secondary] {
            let focused=button === buttons[index]
            button.layer.borderWidth=focused ? 3:0;button.layer.cornerRadius=12
            button.layer.borderColor=ETPadTheme.brass.cgColor
        }
        guard activate else { return }
        let chosen=buttons[index]
        if chosen === practice { onQuickPractice?() } else if chosen === primary { primaryTapped() } else { secondaryTapped() }
    }
}
