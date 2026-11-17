// ETPad host, adapted from UTP GameViewController.swift at
// a9313911efcf044fd66f9a679af53e55e255a8b4. GPL-3.0-or-later.
import UIKit
import GameController
import UniformTypeIdentifiers

final class GameViewController:UIViewController,UIDocumentPickerDelegate {
    private var started=false,engineReady=false,checking=false,dataReady=false
    private var showTouch=true
    private var autoHide:Bool { overlay.configuration.hideWithController }
    private var displayLink:CADisplayLink?
    private var observers:[NSObjectProtocol]=[]
    private let dataManager=GameDataManager()
    private let status=UILabel(),prompts=UIButton(type:.system),menu=UIButton(type:.system)
    private let downloadButton=UIButton(type:.system),importButton=UIButton(type:.system),playButton=UIButton(type:.system)
    private let overlay=GoldenPadTouchOverlay(frame:.zero),surface=GameSurfaceInputView(frame:.zero)
    private var gameHome:URL { dataManager.home }
    private var hostOnly:Bool { ProcessInfo.processInfo.arguments.contains("--etpad-host-only") }
    private var frameTimes:[Double]=[],intervals:[Double]=[]
    private var lastFrameTime:Double=0
    private var controllerHintUntil:Double=0
    private weak var promptController:GCController?
    private var inFrame=false
    override var supportedInterfaceOrientations:UIInterfaceOrientationMask { .landscape }
    override var prefersStatusBarHidden:Bool { true }
    override var prefersHomeIndicatorAutoHidden:Bool { true }
    override var canBecomeFirstResponder:Bool { true }
    override func viewDidLoad(){
        super.viewDidLoad();overrideUserInterfaceStyle = .dark;view.backgroundColor = .black
        showTouch=UserDefaults.standard.object(forKey:"etpad.showTouch") as? Bool ?? true
        // Migrate the two older switches without changing effective visibility.
        let legacyAutoHide=UserDefaults.standard.object(forKey:"etpad.autoHide") as? Bool ?? true
        overlay.configuration.hideWithController=legacyAutoHide && overlay.configuration.hideWithController
        UserDefaults.standard.set(autoHide,forKey:"etpad.autoHide")
        view.addSubview(surface);view.addSubview(overlay)
        status.text="ETPad\nChecking original game data…";status.textColor = .white;status.numberOfLines=0;status.textAlignment = .center
        status.font = .systemFont(ofSize:18,weight:.medium);view.addSubview(status)
        var controllerStyle=UIButton.Configuration.plain()
        controllerStyle.image=UIImage(systemName:"gamecontroller.fill");controllerStyle.imagePadding=7
        controllerStyle.baseForegroundColor = .white;controllerStyle.cornerStyle = .capsule
        controllerStyle.background.backgroundColor=UIColor(white:0.06,alpha:0.72)
        controllerStyle.contentInsets=NSDirectionalEdgeInsets(top:7,leading:12,bottom:7,trailing:12)
        controllerStyle.titleTextAttributesTransformer=UIConfigurationTextAttributesTransformer { incoming in
            var outgoing=incoming;outgoing.font=UIFont.systemFont(ofSize:12,weight:.semibold);return outgoing
        }
        prompts.configuration=controllerStyle;prompts.addTarget(self,action:#selector(mapping),for:.touchUpInside)
        prompts.accessibilityHint="Opens controller button mapping";view.addSubview(prompts)
        for (button,title,action) in [(downloadButton,"Download Free Game Data",#selector(downloadData)),(importButton,"Import Game Data",#selector(importData)),(playButton,"Play ETPad",#selector(play))] {
            button.setTitle(title,for:.normal);button.backgroundColor=UIColor.white.withAlphaComponent(0.1);button.layer.cornerRadius=12
            button.addTarget(self,action:action,for:.touchUpInside);view.addSubview(button)
        }
        // Capsule appearance adapted from Kartpad apple/ios/KartPadMenuButton.h,
        // commit 90647e905db8afd10b4dde8e18ed4e44f234c6fc (read-only reference).
        var menuStyle=UIButton.Configuration.plain()
        menuStyle.image=UIImage(systemName:"ellipsis",withConfiguration:UIImage.SymbolConfiguration(pointSize:20,weight:.semibold))?.withTintColor(.white,renderingMode:.alwaysOriginal)
        menuStyle.baseForegroundColor = .white;menuStyle.cornerStyle = .capsule
        menuStyle.contentInsets = .zero
        menuStyle.background.backgroundColor=UIColor(white:0.06,alpha:0.72)
        menuStyle.background.cornerRadius=20;menuStyle.background.strokeColor=UIColor.white.withAlphaComponent(0.30)
        menuStyle.background.strokeWidth=1
        menu.automaticallyUpdatesConfiguration=false;menu.configuration=menuStyle;menu.tintColor = .white
        menu.showsMenuAsPrimaryAction=true;menu.accessibilityLabel="ETPad menu";view.addSubview(menu)
        overlay.onAction = { [weak self] action,pressed in self?.touchAction(action,pressed:pressed) }
        overlay.onMove = { [weak self] value in if self?.engineReady == true { etpad_touch_move(Float(value.x),Float(value.y)) } }
        overlay.onLook = { [weak self] value in if self?.engineReady == true { etpad_mouse(Int32(value.x*1.5),Int32(value.y*1.5)) } }
        overlay.onConfigurationChanged = { [weak self] in self?.refreshMenu() }
        surface.pointer = { [weak self] point,edge in if self?.engineReady == true { etpad_pointer(Float(point.x),Float(point.y),edge) } }
        dataManager.onProgress = { [weak self] message in self?.status.isHidden=false;self?.status.text=message;self?.updateDataButtons() }
        dataManager.onComplete = { [weak self] result in
            guard let self=self else { return }
            switch result {
            case .success:self.dataReady=true;self.status.text="Original game data verified. Ready to play.";NSLog("ETPad DATA verified download/import complete")
            case .failure(let error):self.status.text=error.localizedDescription;self.alert("Game Data",error.localizedDescription)
            }
            self.updateDataButtons();self.refreshMenu()
        }
        for name in [UIWindow.didBecomeKeyNotification,UIApplication.didBecomeActiveNotification,.GCControllerDidConnect,.GCControllerDidDisconnect] {
            observers.append(NotificationCenter.default.addObserver(forName:name,object:nil,queue:.main) { [weak self] _ in self?.restoreHost();self?.refreshPrompts() })
        }
        observers.append(NotificationCenter.default.addObserver(forName:UIApplication.willResignActiveNotification,object:nil,queue:.main) { [weak self] _ in
            guard let self=self else { return };self.releaseInputs();self.displayLink?.isPaused=true;self.lastFrameTime=0;NSLog("ETPad lifecycle paused")
        })
        displayLink=CADisplayLink(target:self,selector:#selector(frame));displayLink?.preferredFrameRateRange=CAFrameRateRange(minimum:30,maximum:60,preferred:60);displayLink?.add(to:.main,forMode:.common)
        refreshMenu();refreshPrompts()
    }
    override func viewDidAppear(_ animated:Bool){
        super.viewDidAppear(animated);restoreHost()
        guard !started && !checking else { return };checking=true
        if UserDefaults.standard.bool(forKey:"etpad.removeDataOnLaunch") {
            do { try dataManager.removeInstalled();UserDefaults.standard.removeObject(forKey:"etpad.removeDataOnLaunch") } catch { alert("Game Data",error.localizedDescription) }
        }
        dataManager.checkInstalled { [weak self] ready in
            guard let self=self else { return };self.dataReady=ready
            self.status.text=ready ? "ETPad\nOriginal game data verified." : "ETPad\nOriginal game data is missing.\nDownload the free release or import pak0.pk3, pak1.pk3 and pak2.pk3.\nGame data remains under its original EULA."
            self.updateDataButtons()
            if ready && !self.hostOnly { self.play() }
        }
    }
    override func viewDidLayoutSubviews(){
        super.viewDidLayoutSubviews();surface.frame=view.bounds;overlay.frame=view.bounds
        let safe=view.bounds.inset(by:view.safeAreaInsets)
        layoutMenu(in:safe)
        let chipWidth=min(prompts.sizeThatFits(CGSize(width:420,height:44)).width,min(420,safe.width-144))
        prompts.frame=CGRect(x:safe.midX-chipWidth/2,y:safe.minY+12,width:chipWidth,height:44)
        status.frame=CGRect(x:safe.midX-350,y:safe.midY-140,width:700,height:150)
        downloadButton.frame=CGRect(x:safe.midX-160,y:safe.midY+20,width:320,height:48)
        importButton.frame=CGRect(x:safe.midX-160,y:safe.midY+80,width:320,height:48)
        playButton.frame=CGRect(x:safe.midX-160,y:safe.midY+140,width:320,height:48)
        restoreHost()
    }
    func restoreHost(){
        guard let host=view.window,let scene=host.windowScene else { return }
        if engineReady { host.isOpaque=false;host.backgroundColor = .clear;view.isOpaque=false }
        if let pointer=etpad_render_window(){
            let renderer=Unmanaged<UIWindow>.fromOpaque(pointer).takeUnretainedValue()
            if renderer.windowScene !== scene { renderer.windowScene=scene }
            renderer.windowLevel = .normal;renderer.frame=host.bounds;renderer.isUserInteractionEnabled=false
        }
        // Native menus/keyboards own their windows; reassert only SDL's window.
        host.windowLevel=engineReady ? UIWindow.Level(rawValue:UIWindow.Level.normal.rawValue+1) : .normal
        if !host.isKeyWindow { host.makeKeyAndVisible() }
        if UIApplication.shared.applicationState == .active { displayLink?.isPaused=false }
        view.bringSubviewToFront(menu)
        if presentedViewController==nil { becomeFirstResponder() }
    }
    private func updateDataButtons(){
        downloadButton.isHidden=engineReady;importButton.isHidden=engineReady;playButton.isHidden=engineReady || !dataReady
        downloadButton.isEnabled = !dataManager.busy;importButton.isEnabled = !dataManager.busy;playButton.isEnabled = !dataManager.busy
    }
    @objc private func play(){guard dataReady && !started else { return };started=true;status.isHidden=true;downloadButton.isHidden=true;importButton.isHidden=true;playButton.isHidden=true;waitForLandscape(attempt:0)}
    @objc private func downloadData(){releaseInputs();dataManager.download()}
    @objc private func importData(){
        guard !dataManager.busy else { return };releaseInputs()
        let picker=UIDocumentPickerViewController(forOpeningContentTypes:[.item],asCopy:false);picker.allowsMultipleSelection=true
        picker.delegate=self;picker.directoryURL=gameHome.deletingLastPathComponent();present(picker,animated:true)
    }
    func documentPicker(_ controller:UIDocumentPickerViewController,didPickDocumentsAt urls:[URL]){dataManager.importPaks(urls)}
    override func pressesBegan(_ presses:Set<UIPress>,with event:UIPressesEvent?) {
        if engineReady && presentedViewController==nil && GCKeyboard.coalesced==nil {
            for press in presses { if let key=press.key { etpad_hardware_key(Int32(key.keyCode.rawValue),1) } }
        }
        if engineReady && presentedViewController==nil {
            for press in presses { for scalar in press.key?.characters.unicodeScalars ?? "".unicodeScalars where !CharacterSet.controlCharacters.contains(scalar) { etpad_character(Int32(scalar.value)) } }
        }
        super.pressesBegan(presses,with:event)
    }
    override func pressesEnded(_ presses:Set<UIPress>,with event:UIPressesEvent?) {
        if engineReady && GCKeyboard.coalesced==nil { for press in presses { if let key=press.key { etpad_hardware_key(Int32(key.keyCode.rawValue),0) } } }
        super.pressesEnded(presses,with:event)
    }
    override func pressesCancelled(_ presses:Set<UIPress>,with event:UIPressesEvent?) {
        if engineReady { releaseInputs() };super.pressesCancelled(presses,with:event)
    }
    private func command(_ text:String){guard engineReady else { return };etpad_command(text)}
    private func touchAction(_ action:String,pressed:Bool){
        if action=="togglemenu" && pressed && overlay.arranging { overlay.arranging=false;refreshMenu();return }
        guard engineReady else { return }
        if action.hasPrefix("+") { command((pressed ? "+":"-")+action.dropFirst()) }
        else if pressed { command(action) }
    }
    private func releaseInputs(){overlay.releaseAll();if engineReady { etpad_release_inputs() }}
    private func refreshPrompts(){
        guard let controller=GCController.controllers().first else {
            prompts.isHidden=true;promptController=nil;controllerHintUntil=0;updateTouchVisibility();return
        }
        if promptController !== controller { controllerHintUntil=CACurrentMediaTime()+8;promptController=controller }
        let profile=controller.physicalInputProfile
        let playStation=profile is GCDualShockGamepad || profile is GCDualSenseGamepad
        let family=playStation ? "PlayStation" : profile is GCXboxGamepad ? "Xbox" : "Controller"
        let quickBindings=playStation ? "R2 Fire · ✕ Jump · □ Reload" : "RT Fire · A Jump · X Reload"
        prompts.setTitle(quickBindings,for:.normal)
        prompts.accessibilityLabel="\(controller.vendorName ?? family) connected. Controller Button Mapping"
        prompts.isHidden=false;view.setNeedsLayout();updateTouchVisibility()
    }
    private func layoutMenu(in safe:CGRect){
        // Active ET HUD reserves the left gutter; its upper-right corner is
        // occupied by the compass. Rendered ET menus use their original layout.
        let playing=engineReady && etpad_gameplay() != 0
        menu.frame=playing ? CGRect(x:safe.minX+12,y:safe.minY+12,width:64,height:44)
            : CGRect(x:safe.maxX-60,y:safe.minY+12,width:48,height:44)
    }
    private func updateTouchVisibility(){
        let hudFlags=engineReady ? etpad_hud_flags():0
        overlay.scoreboardVisible=(hudFlags & 3) != 0
        prompts.isHidden=GCController.controllers().isEmpty || (!hostOnly && ((hudFlags & 3) != 0 || CACurrentMediaTime()>controllerHintUntil))
        layoutMenu(in:view.bounds.inset(by:view.safeAreaInsets))
        let controllerHides=autoHide && !GCController.controllers().isEmpty
        let active=hostOnly || (engineReady && etpad_gameplay() != 0)
        let hidden = !overlay.arranging && (!showTouch || controllerHides || !active)
        if hidden && !overlay.isHidden { overlay.releaseAll() };overlay.isHidden=hidden
    }
    @objc private func frame(){
        guard UIApplication.shared.applicationState == .active && !inFrame else { return }
        inFrame=true;defer { inFrame=false }
        if engineReady {
            let start=CACurrentMediaTime();etpad_frame();frameTimes.append((CACurrentMediaTime()-start)*1000)
            if lastFrameTime>0 { intervals.append((start-lastFrameTime)*1000) };lastFrameTime=start
            if frameTimes.count>=600 {
                let sorted=frameTimes.sorted(),average=frameTimes.reduce(0,+)/Double(frameTimes.count)
                let interval=intervals.isEmpty ? 0:intervals.reduce(0,+)/Double(intervals.count)
                NSLog("ETPad TIMING renderer=%@ pixels=%dx%d frames=%d cpu_avg_ms=%.3f cpu_p95_ms=%.3f interval_avg_ms=%.3f",String(cString:etpad_renderer()),etpad_render_width(),etpad_render_height(),frameTimes.count,average,sorted[Int(Double(sorted.count-1)*0.95)],interval)
                frameTimes.removeAll(keepingCapacity:true);intervals.removeAll(keepingCapacity:true)
            }
        }
        updateTouchVisibility()
    }
    private func action(_ title:String,icon:String?=nil,fullTitle:String?=nil,state:Bool?=nil,attributes:UIAction.Attributes=[],_ handler:@escaping()->Void)->UIAction {
        UIAction(title:title,image:icon.flatMap { UIImage(systemName:$0) },discoverabilityTitle:fullTitle,attributes:attributes,state:state==true ? .on:.off) { _ in handler() }
    }
    private func setAutoHide(_ enabled:Bool){
        overlay.configuration.hideWithController=enabled
        refreshMenu()
    }
    private func refreshMenu(){
        // Layout restore/import also changes this one canonical setting.
        UserDefaults.standard.set(autoHide,forKey:"etpad.autoHide")
        let visibility=UIMenu(options:.displayInline,children:[
            action("Show Controls",icon:"hand.tap",fullTitle:"Show Touch Controls",state:showTouch){[weak self] in guard let s=self else{return};s.showTouch.toggle();UserDefaults.standard.set(s.showTouch,forKey:"etpad.showTouch");s.refreshMenu()},
            action("Auto-Hide Controls",icon:"eye.slash",fullTitle:"Auto-Hide Touch Controls",state:autoHide){[weak self] in guard let s=self else{return};s.setAutoHide(!s.autoHide)}])
        let layout=UIMenu(options:.displayInline,children:[
            action("Touch Settings…",icon:"slider.horizontal.3",fullTitle:"Touch Control Settings…"){[weak self] in self?.touchSettings()},
            action(overlay.arranging ? "Done Arranging Controls":"Arrange Controls",icon:overlay.arranging ? "checkmark":"hand.draw"){[weak self] in guard let s=self else{return};s.releaseInputs();s.overlay.arranging.toggle();s.refreshMenu()}])
        let controls=UIMenu(title:"Controls",image:UIImage(systemName:"gamecontroller"),children:[visibility,layout,
            UIMenu(options:.displayInline,children:[action("Button Mapping…",icon:"gamecontroller",fullTitle:"Controller Button Mapping…"){[weak self] in self?.mapping()}])])
        let display=UIMenu(title:"Display",image:UIImage(systemName:"display"),children:[
            UIMenu(title:"Render Resolution",image:UIImage(systemName:"rectangle.expand.vertical"),children:[960,1280,1600,1920].map { width in action("\(width) pixels wide",state:UserDefaults.standard.integer(forKey:"etpad.renderWidth")==width){[weak self] in self?.resolution(width)} }),
            action("Field of View…",icon:"viewfinder"){[weak self] in self?.fieldOfView()},
            action("Show FPS Counter",icon:"speedometer",state:UserDefaults.standard.bool(forKey:"etpad.fps")){[weak self] in guard let s=self else{return};let on = !UserDefaults.standard.bool(forKey:"etpad.fps");UserDefaults.standard.set(on,forKey:"etpad.fps");s.command("set cg_drawFPS \(on ? 1:0)");s.refreshMenu()}])
        let online=UIMenu(title:"Online",image:UIImage(systemName:"network"),children:[
            action("Player Name…",icon:"person.crop.circle"){[weak self] in self?.playerName()},
            action("Favorite Servers",icon:"star"){[weak self] in self?.favorites()}])
        let data=UIMenu(title:"Game Data & Saves",image:UIImage(systemName:"folder"),children:[
            UIMenu(options:.displayInline,children:[
                action("Download Free Game Data",icon:"arrow.down.circle"){[weak self] in self?.downloadData()},
                action("Import or Reimport Game Data",icon:"square.and.arrow.down"){[weak self] in self?.importData()}]),
            UIMenu(options:.displayInline,children:[action("Remove Stored Game Data",icon:"trash",attributes:.destructive){[weak self] in self?.removeData()}])])
        let tools=UIMenu(title:"Tools",image:UIImage(systemName:"wrench.and.screwdriver"),children:[
            action("Console…",icon:"terminal"){[weak self] in self?.console()},
            action("Game Keyboard…",icon:"keyboard"){[weak self] in self?.gameKeyboard()}])
        let play=UIMenu(title:"Play",options:.displayInline,children:[
            action("Game Menu",icon:"pause.rectangle",attributes:engineReady ? []:.disabled){[weak self] in self?.command("togglemenu")},
            action("Team & Class…",icon:"person.2",attributes:engineReady ? []:.disabled){[weak self] in self?.command("openlimbomenu")},
            action("Toggle Map",icon:"map",attributes:engineReady ? []:.disabled){[weak self] in self?.command("ToggleAutoMap")}])
        menu.menu=UIMenu(title:"ETPad",children:[play,
            UIMenu(title:"Settings",options:.displayInline,children:[controls,display,online,data]),
            UIMenu(options:.displayInline,children:[tools]),
            UIMenu(options:.displayInline,children:[action("Report a Problem…",icon:"questionmark.circle"){[weak self] in self?.reportProblem()}])])
        updateTouchVisibility()
    }
    private func alert(_ title:String,_ message:String){let alert=UIAlertController(title:title,message:message,preferredStyle:.alert);alert.addAction(UIAlertAction(title:"OK",style:.default));present(alert,animated:true)}
    private func prompt(_ title:String,placeholder:String,value:String="",submit:String="Save",completion:@escaping(String)->Void){
        releaseInputs();let alert=UIAlertController(title:title,message:nil,preferredStyle:.alert)
        alert.addTextField{$0.placeholder=placeholder;$0.text=value;$0.autocorrectionType = .no;$0.autocapitalizationType = .none}
        alert.addAction(UIAlertAction(title:"Cancel",style:.cancel));alert.addAction(UIAlertAction(title:submit,style:.default){_ in completion(alert.textFields?.first?.text ?? "")});present(alert,animated:true)
    }
    private func presentSettings(_ title:String,rows:[HostSettingsViewController.Row]){
        releaseInputs();let controller=UINavigationController(rootViewController:HostSettingsViewController(title:title,rows:rows));controller.modalPresentationStyle = .formSheet;controller.preferredContentSize=CGSize(width:560,height:570);present(controller,animated:true)
    }
    private func touchSettings(){
        presentSettings("Touch Control Settings",rows:[
            .slider("Opacity",0.25,1,Float(overlay.configuration.opacity)){[weak self] in self?.overlay.configuration.opacity=Double($0)},
            .slider("Size",0.7,1.3,Float(overlay.configuration.size)){[weak self] in self?.overlay.configuration.size=Double($0)},
            .toggle("Left-handed",overlay.configuration.leftHanded){[weak self] in self?.releaseInputs();self?.overlay.configuration.leftHanded=$0},
            .toggle("Hide with controller",autoHide){[weak self] in self?.setAutoHide($0)},
            .button("Arrange Controls"){[weak self] in self?.overlay.arranging=true;self?.refreshMenu()},
            .button("Saved Layouts"){[weak self] in self?.savedLayouts()},
            .button("Restore Default Layout"){[weak self] in self?.overlay.restoreDefault();self?.refreshMenu()}])
    }
    private func savedLayouts(){
        var saved=UserDefaults.standard.dictionary(forKey:"etpad.touch.saved") as? [String:Data] ?? [:]
        var rows:[HostSettingsViewController.Row]=[.button("Save Current Layout…"){[weak self] in self?.prompt("Save Layout",placeholder:"Layout name") { name in guard let self=self,!name.trimmingCharacters(in:.whitespaces).isEmpty,let data=try? JSONEncoder().encode(self.overlay.configuration) else{return};saved[String(name.prefix(48))]=data;UserDefaults.standard.set(saved,forKey:"etpad.touch.saved") }}]
        for name in saved.keys.sorted(){rows.append(.button(name){[weak self] in if let data=saved[name],let config=try? JSONDecoder().decode(TouchConfiguration.self,from:data){self?.releaseInputs();self?.overlay.configuration=config;self?.refreshMenu()} })}
        presentSettings("Saved Layouts",rows:rows)
    }
    @objc private func mapping(){
        let text="LS Move · RS Look\nRT Fire · LT Alt fire\nA / ✕ Jump · B / ○ Crouch\nX / □ Reload · Y / △ Use\nL3 Sprint · R3 Prone\nBack Score · Start Game menu\nD-pad: Map, Limbo, Previous, Next\n\nHold LB: A/B Lean · X/Y Vote Yes/No\nBack Console · Start Team · L3 Class\nD-pad: Medic, Need Ammo, Thanks, Affirmative\n\nHold RB: A/B/X/Y weapon banks 5–8\nBack 9 · Start 10 · L3 1 · R3 2\nD-pad Up/Down 3/4 · Left/Right Previous/Next"
        var rows:[HostSettingsViewController.Row]=[.button("View Default Mapping"){[weak self] in self?.alert("Default Controller Mapping",text)}]
        let saved=UserDefaults.standard.dictionary(forKey:"etpad.controller.bindings") as? [String:String] ?? [:]
        for (label,key,standard) in Self.controllerKeys {
            let value=saved[key] ?? standard
            let name=Self.bindingActions.first(where:{$0.1==value})?.0 ?? value
            rows.append(.button("\(label): \(name)"){[weak self] in self?.editBinding(label:label,key:key,current:value)})
        }
        rows.append(.button("Restore Default Bindings"){[weak self] in self?.releaseInputs();UserDefaults.standard.removeObject(forKey:"etpad.controller.bindings");self?.command("exec etpad-controller.cfg")})
        presentSettings("Controller Button Mapping",rows:rows)
    }
    private static let controllerKeys:[(String,String,String)]=[
        ("A / Cross","PAD0_A","+moveup"),("B / Circle","PAD0_B","+movedown"),("X / Square","PAD0_X","+reload"),("Y / Triangle","PAD0_Y","+activate"),
        ("Right Trigger","PAD0_RIGHTTRIGGER","+attack"),("Left Trigger","PAD0_LEFTTRIGGER","weapalt"),("Left Stick Click","PAD0_LEFTSTICK_CLICK","+sprint"),("Right Stick Click","PAD0_RIGHTSTICK_CLICK","+prone"),
        ("Back / Share","PAD0_BACK","+scores"),("Start / Options","PAD0_START","togglemenu"),
        ("D-pad Up","PAD0_DPAD_UP","+mapexpand"),("D-pad Down","PAD0_DPAD_DOWN","openlimbomenu"),("D-pad Left","PAD0_DPAD_LEFT","weapprev"),("D-pad Right","PAD0_DPAD_RIGHT","weapnext")]
    private static let bindingActions:[(String,String)]=[
        ("Fire","+attack"),("Alt Fire","weapalt"),("Reload","+reload"),("Jump","+moveup"),("Crouch","+movedown"),("Prone","+prone"),("Sprint","+sprint"),
        ("Lean Left","+leanleft"),("Lean Right","+leanright"),("Use","+activate"),("Previous Weapon","weapprev"),("Next Weapon","weapnext"),("Scoreboard","+scores"),("Limbo","openlimbomenu"),("Team Menu","teammenu"),("Class Menu","classmenu"),("Map","+mapexpand"),("Vote Yes","vote yes"),("Vote No","vote no"),("Console","toggleconsole"),("Game Menu","togglemenu"),
        ("Medic Quick Chat","vsay_team Medic"),("Ammo Quick Chat","vsay_team NeedAmmo"),("Thanks Quick Chat","vsay_team Thanks"),("Affirmative Quick Chat","vsay_team Affirmative"),("Unbound","")]
        + (1...10).map { ("Weapon Bank \($0)","weaponbank \($0)") }
    private func editBinding(label:String,key:String,current:String){
        presentSettings(label,rows:Self.bindingActions.map { name,value in .button((value==current ? "✓ ":"")+name){[weak self] in
            guard let self=self else{return};self.releaseInputs()
            var saved=UserDefaults.standard.dictionary(forKey:"etpad.controller.bindings") as? [String:String] ?? [:]
            saved[key]=value;UserDefaults.standard.set(saved,forKey:"etpad.controller.bindings");self.command("bind \(key) \"\(value)\"")
        }})
    }
    private func resolution(_ width:Int){
        UserDefaults.standard.set(width,forKey:"etpad.renderWidth")
        if engineReady { let height=Int((CGFloat(width)*view.bounds.height/view.bounds.width).rounded());command("set r_customwidth \(width);set r_customheight \(height);vid_restart") }
        refreshMenu()
    }
    private func fieldOfView(){presentSettings("Field of View",rows:[.slider("Field of View",75,120,Float(UserDefaults.standard.object(forKey:"etpad.fov") as? Double ?? 90)){[weak self] value in UserDefaults.standard.set(Double(value),forKey:"etpad.fov");self?.command("set cg_fov \(Int(value))") }])}
    private func playerName(){prompt("Player Name",placeholder:"Player name",value:UserDefaults.standard.string(forKey:"etpad.name") ?? "ETPadPlayer"){[weak self] name in
        let safe=String(name.unicodeScalars.filter{CharacterSet.alphanumerics.contains($0) || " _-^".unicodeScalars.contains($0)}.prefix(32));UserDefaults.standard.set(safe,forKey:"etpad.name");self?.command("set name \"\(safe)\"")
    }}
    private func favorites(){
        let servers=UserDefaults.standard.stringArray(forKey:"etpad.favorites") ?? []
        var rows:[HostSettingsViewController.Row]=[.button("Add Favorite Server…"){[weak self] in self?.prompt("Favorite Server",placeholder:"hostname:27960") { address in
            guard address.range(of:"^[A-Za-z0-9.-]+:[0-9]{1,5}$",options:.regularExpression) != nil,let port=Int(address.split(separator:":").last ?? ""),(1...65535).contains(port) else {self?.alert("Favorite Server","Enter a hostname or IPv4 address and port.");return}
            var list=servers;if !list.contains(address){list.append(address)};UserDefaults.standard.set(list,forKey:"etpad.favorites")
        }}]
        for address in servers { rows.append(.button(address){[weak self] in self?.command("connect \(address)")}) }
        presentSettings("Favorite Servers",rows:rows)
    }
    private func console(){prompt("Console",placeholder:"ET command",submit:"Run"){[weak self] text in self?.command(text)}}
    private func gameKeyboard(){prompt("Game Keyboard",placeholder:"Text for the selected game field",submit:"Type"){[weak self] text in guard self?.engineReady == true else{return};for scalar in text.unicodeScalars {etpad_character(Int32(scalar.value))}}}
    private func removeData(){
        guard !dataManager.busy else{return};releaseInputs()
        let message=engineReady ? "The three original pak files will be removed next time you open ETPad. Your saves and downloaded maps will stay." : "Remove the three original pak files? Your saves and downloaded maps will stay. You can download or import the data again."
        let alert=UIAlertController(title:"Remove Stored Game Data",message:message,preferredStyle:.alert);alert.addAction(UIAlertAction(title:"Cancel",style:.cancel))
        alert.addAction(UIAlertAction(title:"Remove Game Data",style:.destructive){[weak self] _ in guard let self=self else{return}
            if self.engineReady {UserDefaults.standard.set(true,forKey:"etpad.removeDataOnLaunch");self.alert("Game Data","Removal is scheduled for the next app launch.")}
            else {do{try self.dataManager.removeInstalled();self.dataReady=false;self.status.text="Game data removed. Download or import it to play.";self.updateDataButtons()}catch{self.alert("Game Data",error.localizedDescription)}}
        });present(alert,animated:true)
    }
    private func reportProblem(){
        // SunPadGameOverlay.mm reportProblem flow, e43f0ea6b797e5110787171957c9dc3c6213269c.
        releaseInputs();let alert=UIAlertController(title:"Report a Problem",message:"Describe the issue and ETPad will add device information and a bounded text log. Reports never contain game files, saves, signing material or controller input. Review the report before sharing; GitHub reports are public.",preferredStyle:.alert)
        for title in ["What went wrong?","Area and what you were doing (optional)","Every time, sometimes, once, or not sure?"] {alert.addTextField{$0.placeholder=title}}
        alert.addAction(UIAlertAction(title:"Cancel",style:.cancel))
        alert.addAction(UIAlertAction(title:"Share Report…",style:.default){[weak self] _ in self?.shareReport(alert.textFields?.map{$0.text ?? ""} ?? [])})
        present(alert,animated:true)
    }
    private func shareReport(_ answers:[String]){
        let device=UIDevice.current,info=Bundle.main.infoDictionary ?? [:]
        var text="ETPad problem report\n\(answers.joined(separator:"\n"))\n\n\(device.model), \(device.systemName) \(device.systemVersion)\nVersion \(info["CFBundleShortVersionString"] ?? "unknown") (\(info["CFBundleVersion"] ?? "unknown"))\nRenderer ANGLE Metal / GL4ES (experimental)\n"
        let file=gameHome.appendingPathComponent("legacy/etconsole.log")
        if let handle=try? FileHandle(forReadingFrom:file){defer{try? handle.close()};let end=(try? handle.seekToEnd()) ?? 0;try? handle.seek(toOffset:end>65536 ? end-65536:0)
            if let data=try? handle.readToEnd(),let log=String(data:data,encoding:.utf8){text += "\nRecent engine log:\n"+log.replacingOccurrences(of:NSHomeDirectory(),with:"<app-home>")}
        }
        let url=FileManager.default.temporaryDirectory.appendingPathComponent("ETPad-report-\(UUID().uuidString.prefix(8)).txt")
        do{try text.write(to:url,atomically:true,encoding:.utf8);let share=UIActivityViewController(activityItems:[url],applicationActivities:nil);share.popoverPresentationController?.sourceView=menu;share.popoverPresentationController?.sourceRect=menu.bounds;present(share,animated:true)}catch{self.alert("Report Unavailable",error.localizedDescription)}
    }
    private func waitForLandscape(attempt:Int) {
        if view.window?.windowScene?.interfaceOrientation.isLandscape == true && view.bounds.width > view.bounds.height {
            startEngine()
        } else if attempt < 40 {
            DispatchQueue.main.asyncAfter(deadline:.now()+0.1) { [weak self] in self?.waitForLandscape(attempt:attempt+1) }
        } else { status.isHidden=false;status.text="ETPad could not enter landscape. Rotate the iPad and reopen the app." }
    }
    private func startEngine() {
        view.backgroundColor = .clear
        let profile = gameHome.appendingPathComponent("legacy/profiles/ETPad")
        try? FileManager.default.createDirectory(at:profile,withIntermediateDirectories:true)
        try? "\"ETPad\"".write(to:profile.appendingPathComponent("profile.dat"),atomically:true,encoding:.utf8)
        try? "\"ETPad\"".write(to:profile.deletingLastPathComponent().appendingPathComponent("defaultprofile.dat"),atomically:true,encoding:.utf8)
        let stored=UserDefaults.standard.integer(forKey:"etpad.renderWidth")
        let renderWidth=[960,1280,1600,1920].contains(stored) ? stored:1280
        let renderHeight=Int((CGFloat(renderWidth)*view.bounds.height/view.bounds.width).rounded())
        var args = [Bundle.main.executablePath ?? "ETPad", "+set","fs_basepath",Bundle.main.bundleURL.appendingPathComponent("GameContent").path,
                    "+set","fs_homepath",gameHome.path,"+set","fs_game","legacy","+set","in_joystick","1","+set","in_joystickUseAnalog","1","+set","cl_wwwDownload","0","+set","com_introplayed","1","+set","logfile","2",
                    "+set","r_fullscreen","1","+set","r_mode","-1","+set","r_customwidth",String(renderWidth),"+set","r_customheight",String(renderHeight),
                    "+set","r_allowSoftwareGL","1","+set","r_swapInterval","0","+set","com_maxfps","250","+set","name",UserDefaults.standard.string(forKey:"etpad.name") ?? "ETPadPlayer",
                    "+set","cg_fov",String(Int(UserDefaults.standard.object(forKey:"etpad.fov") as? Double ?? 90)),
                    "+set","cg_drawFPS",UserDefaults.standard.bool(forKey:"etpad.fps") ? "1":"0"]
        args += ["+set","cl_renderer",ProcessInfo.processInfo.arguments.contains("--etpad-vulkan") ? "vulkan":"opengles"]
        if ProcessInfo.processInfo.arguments.contains("--etpad-oasis") { args += ["+set","sv_pure","0","+set","g_gametype","2","+devmap","oasis"] }
        let pointers = args.map { strdup($0) }
        defer { pointers.forEach { free($0) } }
        var mutable = pointers + [nil]
        mutable.withUnsafeMutableBufferPointer { _ = etpad_engine_main(Int32(args.count),$0.baseAddress) }
        engineReady=true
        refreshMenu()
        for (key,value) in UserDefaults.standard.dictionary(forKey:"etpad.controller.bindings") as? [String:String] ?? [:] {
            if Self.controllerKeys.contains(where:{$0.1==key}) && Self.bindingActions.contains(where:{$0.1==value}) { command("bind \(key) \"\(value)\"") }
        }
        restoreHost()
        updateDataButtons()
    }

}
