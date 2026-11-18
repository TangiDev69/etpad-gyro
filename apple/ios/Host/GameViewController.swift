// ETPad host, adapted from UTP GameViewController.swift at
// a9313911efcf044fd66f9a679af53e55e255a8b4. GPL-3.0-or-later.
import UIKit
import GameController
import UniformTypeIdentifiers

final class GameViewController:UIViewController,UIDocumentPickerDelegate {
    // The last input used decides whether touch controls show. A controller or
    // keyboard/mouse hides them (when Auto-Hide is on); a finger brings them back.
    private enum InputMode { case touch,controller,keyboard }
    private var started=false,engineReady=false,checking=false,dataReady=false
    private var showTouch=true
    private var autoHide:Bool { overlay.configuration.hideWithController }
    private var displayLink:CADisplayLink?
    private var observers:[NSObjectProtocol]=[]
    private let dataManager=GameDataManager()
    private let prompts=UIButton(type:.system),menu=UIButton(type:.system)
    private let launcher=LauncherView(frame:.zero)
    private let overlay=GoldenPadTouchOverlay(frame:.zero),surface=GameSurfaceInputView(frame:.zero)
    private var gameHome:URL { dataManager.home }
    private let hostOnly=ProcessInfo.processInfo.arguments.contains("--etpad-host-only")
    private var controllerConnected=false,gameplayActive=false,hasMouse=false
    private var inputMode:InputMode = .touch
    private var lastPadEvent:Double=0
    private var wantsPointerLock=false
    private var clientState:Int32=0
    private var pendingBots=false
    private var pendingCommand:String?
    private var padPrevious:[String:Bool]=[:]
    // ET's own menus (main menu, Limbo, Host Game) take a mouse cursor. With a
    // controller the left stick moves it, A clicks and B goes back.
    private var menuCursor=CGPoint(x:0.5,y:0.5),cursorShown=false,cursorClickHeld=false
    private var lastPracticeMap:String { UserDefaults.standard.string(forKey:"etpad.lastPractice") ?? "oasis" }
    private var frameTimes:[Double]=[],intervals:[Double]=[],hostTimes:[Double]=[],callbackTimes:[Double]=[]
    private var lastFrameTime:Double=0
    private var controllerHintUntil:Double=0
    private weak var promptController:GCController?
    private var inFrame=false
    private var inMatch:Bool { engineReady && clientState>=5 }
    static let practiceMaps=[("Oasis","oasis","Allies breach the walls of an old desert city"),("Goldrush","goldrush","Steal the gold from the Axis bank"),
        ("Radar","radar","Allies destroy two radar arrays"),("Battery","battery","Storm a coastal gun battery"),
        ("Fuel Dump","fueldump","Escort the tank to the Axis fuel depot"),("Rail Gun","railgun","Disable an Axis railway gun")]
    override var supportedInterfaceOrientations:UIInterfaceOrientationMask { .landscape }
    override var prefersStatusBarHidden:Bool { true }
    override var prefersHomeIndicatorAutoHidden:Bool { true }
    override var prefersPointerLocked:Bool { wantsPointerLock }
    override var canBecomeFirstResponder:Bool { true }
    override func viewDidLoad(){
        super.viewDidLoad();overrideUserInterfaceStyle = .dark;view.backgroundColor = .black
        showTouch=UserDefaults.standard.object(forKey:"etpad.showTouch") as? Bool ?? true
        // Migrate the two older switches without changing effective visibility.
        let legacyAutoHide=UserDefaults.standard.object(forKey:"etpad.autoHide") as? Bool ?? true
        overlay.configuration.hideWithController=legacyAutoHide && overlay.configuration.hideWithController
        UserDefaults.standard.set(autoHide,forKey:"etpad.autoHide")
        view.addSubview(surface);view.addSubview(overlay);view.addSubview(launcher)
        var controllerStyle=UIButton.Configuration.plain()
        controllerStyle.image=UIImage(systemName:"gamecontroller.fill");controllerStyle.imagePadding=7
        controllerStyle.baseForegroundColor=ETPadTheme.cream;controllerStyle.cornerStyle = .capsule
        controllerStyle.background.backgroundColor=ETPadTheme.ink.withAlphaComponent(0.72)
        controllerStyle.contentInsets=NSDirectionalEdgeInsets(top:7,leading:12,bottom:7,trailing:12)
        controllerStyle.titleTextAttributesTransformer=UIConfigurationTextAttributesTransformer { incoming in
            var outgoing=incoming;outgoing.font=UIFont.systemFont(ofSize:12,weight:.semibold);return outgoing
        }
        prompts.configuration=controllerStyle;prompts.addTarget(self,action:#selector(mapping),for:.touchUpInside)
        prompts.accessibilityHint="Opens controller button mapping";view.addSubview(prompts)
        launcher.onPlayOnline = { [weak self] in self?.showServers() }
        launcher.onMainMenu = { [weak self] in self?.launch([]) }
        launcher.onDownload = { [weak self] in self?.downloadData() }
        launcher.onImport = { [weak self] in self?.importData() }
        launcher.onHelp = { [weak self] in self?.showGuide() }
        launcher.onQuickPractice = { [weak self] in guard let self=self else { return };self.practice(self.lastPracticeMap) }
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
        overlay.onLook = { [weak self] value in if self?.engineReady == true { etpad_mouse(Int32((value.x*1.5).rounded()),Int32((value.y*1.5).rounded())) } }
        overlay.onTouch = { [weak self] in self?.setInputMode(.touch) }
        overlay.onConfigurationChanged = { [weak self] in self?.refreshMenu() }
        surface.pointer = { [weak self] point,edge in
            guard let self=self,self.engineReady else { return }
            self.menuCursor=point;etpad_pointer(Float(point.x),Float(point.y),edge)
        }
        surface.claimDirectTouch = { [weak self] in
            // During play with touch controls hidden by another input, the
            // first finger restores them and never reaches the game as a click.
            guard let self=self,self.gameplayActive,self.inputMode != .touch,self.showTouch else { return false }
            self.setInputMode(.touch);return true
        }
        dataManager.onProgress = { [weak self] message in self?.launcher.setState(.busy(message)) }
        dataManager.onComplete = { [weak self] result in
            guard let self=self else { return }
            switch result {
            case .success:self.dataReady=true;NSLog("ETPad DATA verified download/import complete")
            case .failure(let error):self.alert("Game Data",error.localizedDescription)
            }
            self.updateLauncher();self.refreshMenu()
        }
        for name in [UIWindow.didBecomeKeyNotification,UIApplication.didBecomeActiveNotification,.GCControllerDidConnect,.GCControllerDidDisconnect,.GCMouseDidConnect,.GCMouseDidDisconnect,.GCKeyboardDidConnect] {
            observers.append(NotificationCenter.default.addObserver(forName:name,object:nil,queue:.main) { [weak self] note in
                guard let self=self else { return }
                if note.name == .GCControllerDidConnect { self.setInputMode(.controller) }
                if note.name == .GCControllerDidDisconnect && GCController.controllers().isEmpty && self.inputMode == .controller { self.setInputMode(.touch) }
                self.restoreHost();self.refreshPrompts()
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName:UIPointerLockState.didChangeNotification,object:nil,queue:.main) { [weak self] _ in
            let locked=self?.view.window?.windowScene?.pointerLockState?.isLocked ?? false
            etpad_set_pointer_locked(locked ? 1:0);NSLog("ETPad pointer lock %@",locked ? "on":"off")
        })
        observers.append(NotificationCenter.default.addObserver(forName:UIApplication.willResignActiveNotification,object:nil,queue:.main) { [weak self] _ in
            guard let self=self else { return };self.releaseInputs();self.displayLink?.isPaused=true;self.lastFrameTime=0;NSLog("ETPad lifecycle paused")
        })
        if !GCController.controllers().isEmpty { inputMode = .controller }
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
            self.updateLauncher();self.refreshMenu()
            // Test hooks run the same paths as the launcher buttons.
            let arguments=ProcessInfo.processInfo.arguments
            func value(_ flag:String)->String? { arguments.firstIndex(of:flag).flatMap { $0+1<arguments.count ? arguments[$0+1]:nil } }
            guard ready else { return }
            self.pendingCommand=value("--etpad-command")
            if arguments.contains("--etpad-oasis") { self.launch(["+set","sv_pure","0","+set","g_gametype","2","+devmap","oasis"]) }
            else if let map=value("--etpad-practice") { self.practice(map) }
            else if let address=value("--etpad-connect") { self.join(address,password:nil) }
            else if arguments.contains("--etpad-servers") { self.showServers() }
        }
    }
    override func viewDidLayoutSubviews(){
        super.viewDidLayoutSubviews();setFrame(view.bounds,for:surface);setFrame(view.bounds,for:overlay);setFrame(view.bounds,for:launcher)
        let safe=view.bounds.inset(by:view.safeAreaInsets)
        layoutMenu(in:safe)
        let chipWidth=min(prompts.sizeThatFits(CGSize(width:420,height:44)).width,min(420,safe.width-144))
        setFrame(CGRect(x:safe.midX-chipWidth/2,y:safe.minY+12,width:chipWidth,height:44),for:prompts)
        restoreHost()
    }
    func restoreHost(){
        guard let host=view.window,let scene=host.windowScene else { return }
        if engineReady { host.isOpaque=false;host.backgroundColor = .clear;view.isOpaque=false }
        if let pointer=etpad_render_window(){
            let renderer=Unmanaged<UIWindow>.fromOpaque(pointer).takeUnretainedValue()
            if renderer.windowScene !== scene { renderer.windowScene=scene }
            renderer.windowLevel = .normal;setFrame(host.bounds,for:renderer);renderer.isUserInteractionEnabled=false
        }
        // Native menus/keyboards own their windows; reassert only SDL's window.
        host.windowLevel=engineReady ? UIWindow.Level(rawValue:UIWindow.Level.normal.rawValue+1) : .normal
        if !host.isKeyWindow { host.makeKeyAndVisible() }
        if UIApplication.shared.applicationState == .active { displayLink?.isPaused=false }
        view.bringSubviewToFront(menu)
        if presentedViewController==nil { becomeFirstResponder() }
    }
    private func updateLauncher(){
        guard !started else { return }
        if dataManager.busy { return }
        launcher.setState(dataReady ? .ready:.missing)
        launcher.practiceMenu=UIMenu(title:"Practice with Bots",children:practiceItems())
    }
    // Start the engine once. Later choices run as engine commands instead.
    private func launch(_ extra:[String]){
        guard dataReady && !started else { return }
        started=true;launcher.setState(.starting);waitForLandscape(attempt:0,extra:extra)
    }
    private func showServers(){
        releaseInputs()
        let browser=ServerBrowserViewController()
        browser.onJoin = { [weak self] address,password in self?.join(address,password:password) }
        let navigation=UINavigationController(rootViewController:browser)
        navigation.modalPresentationStyle = .formSheet;navigation.preferredContentSize=CGSize(width:720,height:640)
        navigation.overrideUserInterfaceStyle = .dark
        present(navigation,animated:true)
    }
    private func join(_ address:String,password:String?){
        NSLog("ETPad joining %@",address)
        if engineReady {
            command((password.map { "set password \"\($0)\";" } ?? "")+"connect \(address)")
        } else {
            launch((password.map { ["+set","password",$0] } ?? [])+["+connect",address])
        }
    }
    private func practice(_ map:String){
        pendingBots=true;UserDefaults.standard.set(map,forKey:"etpad.lastPractice")
        let setup=["+set","omnibot_enable","1","+set","g_gametype","2","+set","sv_pure","0"]
        if engineReady { command("set omnibot_enable 1;set g_gametype 2;set sv_pure 0;map \(map)") } else { launch(setup+["+map",map]) }
    }
    private var botCount:Int { let n=UserDefaults.standard.integer(forKey:"etpad.botCount");return [6,10,16].contains(n) ? n:10 }
    private func practiceItems()->[UIMenuElement]{
        let maps=Self.practiceMaps.map { name,map,detail -> UIMenuElement in
            let item=action(name,icon:"map"){[weak self] in self?.practice(map)}
            item.subtitle=detail;return item
        }
        let counts=[(6,"Small: 5 bots"),(10,"Medium: 9 bots"),(16,"Large: 15 bots")].map { count,title -> UIMenuElement in
            action(title,state:botCount==count){[weak self] in UserDefaults.standard.set(count,forKey:"etpad.botCount");self?.refreshMenu()}
        }
        let size=UIMenu(title:"Bot Count",image:UIImage(systemName:"person.3.sequence"),children:counts)
        size.subtitle="\(botCount-1) bots join you"
        return [UIMenu(options:.displayInline,children:maps),UIMenu(options:.displayInline,children:[size])]
    }
    @objc private func downloadData(){releaseInputs();dataManager.download()}
    @objc private func importData(){
        guard !dataManager.busy else { return };releaseInputs()
        let picker=UIDocumentPickerViewController(forOpeningContentTypes:[.item],asCopy:false);picker.allowsMultipleSelection=true
        picker.delegate=self;picker.directoryURL=gameHome.deletingLastPathComponent();present(picker,animated:true)
    }
    func documentPicker(_ controller:UIDocumentPickerViewController,didPickDocumentsAt urls:[URL]){dataManager.importPaks(urls)}
    override func pressesBegan(_ presses:Set<UIPress>,with event:UIPressesEvent?) {
        if engineReady && presentedViewController==nil && presses.contains(where:{ $0.key != nil }) { setInputMode(.keyboard) }
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
    private func setInputMode(_ mode:InputMode){
        guard mode != inputMode else { return }
        inputMode=mode;NSLog("ETPad input mode %@",String(describing:mode))
        if mode == .controller { controllerHintUntil=CACurrentMediaTime()+8 }
        updateTouchVisibility()
    }
    // Cheap per-frame checks: GameController exposes the last event time, and
    // the engine reports SDL mouse use while the pointer is locked.
    private func pollInputSources(){
        if let controller=GCController.controllers().first {
            let profile=controller.physicalInputProfile
            if profile.lastEventTimestamp != lastPadEvent {
                lastPadEvent=profile.lastEventTimestamp
                if profile.allButtons.contains(where:{ $0.isPressed }) || profile.allDpads.contains(where:{ hypot($0.xAxis.value,$0.yAxis.value)>0.4 }) { setInputMode(.controller) }
            }
        }
        if GCKeyboard.coalesced?.keyboardInput?.isAnyKeyPressed == true || etpad_take_mouse_activity() != 0 { setInputMode(.keyboard) }
    }
    // Native screens (launcher, server list, guides) are UIKit, which does not
    // move focus with a gamepad on iPadOS. Read edges here instead; the game
    // itself keeps reading the controller through SDL.
    private func pollMenuController(){
        let browser=(presentedViewController as? UINavigationController)?.viewControllers.first as? ServerBrowserViewController
        guard !engineReady || presentedViewController != nil,let pad=GCController.controllers().first?.extendedGamepad else { return }
        func edge(_ name:String,_ on:Bool)->Bool { let was=padPrevious[name] ?? false;padPrevious[name]=on;return on && !was }
        let x=pad.dpad.xAxis.value+pad.leftThumbstick.xAxis.value,y=pad.dpad.yAxis.value+pad.leftThumbstick.yAxis.value
        let left=edge("left",x < -0.5),right=edge("right",x>0.5),up=edge("up",y>0.5),down=edge("down",y < -0.5)
        let a=edge("a",pad.buttonA.isPressed),b=edge("b",pad.buttonB.isPressed),refresh=edge("y",pad.buttonY.isPressed)
        guard left || right || up || down || a || b || refresh else { return }
        setInputMode(.controller)
        if let browser=browser { browser.controller(move:down ? 1:(up ? -1:0),activate:a,back:b,refresh:refresh) }
        else if let presented=presentedViewController { if b { presented.dismiss(animated:true) } }
        else if !started { launcher.controller(move:right || down ? 1:(left || up ? -1:0),activate:a) }
    }
    private func pollGameMenuCursor(){
        guard presentedViewController==nil,!gameplayActive,clientState==0 || clientState==1 || clientState==8,
              let pad=GCController.controllers().first?.extendedGamepad else {
            if cursorClickHeld { cursorClickHeld=false;etpad_pointer(Float(menuCursor.x),Float(menuCursor.y),0) }
            cursorShown=false;return
        }
        func edge(_ name:String,_ on:Bool)->Bool { let was=padPrevious[name] ?? false;padPrevious[name]=on;return on != was }
        var x=CGFloat(pad.leftThumbstick.xAxis.value),y=CGFloat(pad.leftThumbstick.yAxis.value)
        let length=hypot(x,y)
        if length<0.18 { x=0;y=0 } else {
            // Curved response: fine control near center, fast at full tilt.
            let speed=pow((min(1,length)-0.18)/0.82,1.7)*0.022
            x=x/length*speed;y=y/length*speed
        }
        let aChanged=edge("game.a",pad.buttonA.isPressed),bChanged=edge("game.b",pad.buttonB.isPressed)
        if x != 0 || y != 0 || !cursorShown {
            let aspect=view.bounds.width/max(1,view.bounds.height)
            menuCursor=CGPoint(x:max(0,min(1,menuCursor.x+x/aspect)),y:max(0,min(1,menuCursor.y-y)))
            if x != 0 || y != 0 || aChanged { cursorShown=true;setInputMode(.controller) }
            if cursorShown { etpad_pointer(Float(menuCursor.x),Float(menuCursor.y),-1) }
        }
        if aChanged {
            cursorShown=true;cursorClickHeld=pad.buttonA.isPressed
            etpad_pointer(Float(menuCursor.x),Float(menuCursor.y),pad.buttonA.isPressed ? 1:0)
        }
        if bChanged && pad.buttonB.isPressed { etpad_key(27,1);etpad_key(27,0) }
    }
    private func refreshPrompts(){
        hasMouse = !GCMouse.mice().isEmpty
        guard let controller=GCController.controllers().first else {
            controllerConnected=false;setHidden(true,for:prompts);promptController=nil;controllerHintUntil=0;updateTouchVisibility();return
        }
        controllerConnected=true
        if promptController !== controller { controllerHintUntil=CACurrentMediaTime()+8;promptController=controller }
        let profile=controller.physicalInputProfile
        let playStation=profile is GCDualShockGamepad || profile is GCDualSenseGamepad
        let family=playStation ? "PlayStation" : profile is GCXboxGamepad ? "Xbox" : "Controller"
        let quickBindings=playStation ? "R2 Fire · ✕ Jump · □ Reload" : "RT Fire · A Jump · X Reload"
        prompts.setTitle(quickBindings,for:.normal)
        prompts.accessibilityLabel="\(controller.vendorName ?? family) connected. Controller Button Mapping"
        setHidden(false,for:prompts);view.setNeedsLayout();updateTouchVisibility()
    }
    private func setHidden(_ hidden:Bool,for target:UIView){
        if target.isHidden != hidden { target.isHidden=hidden }
    }
    private func setFrame(_ frame:CGRect,for target:UIView){
        if target.frame != frame { target.frame=frame }
    }
    private func layoutMenu(in safe:CGRect){
        // Layout callbacks reuse the last completed host-state snapshot. They
        // can occur inside SDL's nested UIKit loop while Com_Frame is running.
        // On the launcher the capsule shares the header row and right margin
        // with How to Play; over ET's own menus it keeps the corner anchor.
        let frame=gameplayActive ? CGRect(x:safe.minX+12,y:safe.minY+12,width:64,height:44)
            : (!started ? CGRect(x:safe.maxX-48-48,y:safe.minY+26,width:48,height:44)
            : CGRect(x:safe.maxX-60,y:safe.minY+12,width:48,height:44))
        setFrame(frame,for:menu)
    }
    private func updateTouchVisibility(){
        // Keep actual HUD/scoreboard polling every display tick. Controller
        // membership changes are captured by refreshPrompts on lifecycle and
        // connect/disconnect notifications, including the initial refresh.
        gameplayActive=engineReady && etpad_gameplay() != 0
        let state=engineReady ? etpad_client_state():0
        if (state>=5) != (clientState>=5) { clientState=state;refreshMenu() } else { clientState=state }
        if pendingBots && state==8 && etpad_local_server() != 0 {
            // Omni-bot counts the player; open team selection once bots join.
            pendingBots=false;command("bot maxbots \(botCount)")
            DispatchQueue.main.asyncAfter(deadline:.now()+1.5) { [weak self] in
                guard let self=self else { return }
                if let test=self.pendingCommand { self.pendingCommand=nil;self.command(test) }
                // openlimbomenu toggles; ET may already show team selection.
                else if etpad_gameplay() != 0 { self.command("openlimbomenu") }
            }
        } else if let test=pendingCommand,!pendingBots,state==8 {
            pendingCommand=nil;DispatchQueue.main.asyncAfter(deadline:.now()+1.5) { [weak self] in self?.command(test) }
        }
        let hudFlags=engineReady ? etpad_hud_flags():0
        let scoreboard=(hudFlags & 3) != 0
        if overlay.scoreboardVisible != scoreboard { overlay.scoreboardVisible=scoreboard }
        setHidden(!controllerConnected || inputMode != .controller || (!hostOnly && (scoreboard || CACurrentMediaTime()>controllerHintUntil)),for:prompts)
        layoutMenu(in:view.bounds.inset(by:view.safeAreaInsets))
        let otherInput=autoHide && inputMode != .touch
        let active=hostOnly || gameplayActive
        let hidden = !overlay.arranging && (!showTouch || otherInput || !active)
        if hidden != overlay.isHidden {
            if hidden { overlay.releaseAll() }
            overlay.isHidden=hidden
        }
        // Lock the pointer for mouse look only during play with a mouse attached.
        let lock=engineReady && gameplayActive && hasMouse && presentedViewController==nil && !overlay.arranging
        if lock != wantsPointerLock { wantsPointerLock=lock;setNeedsUpdateOfPrefersPointerLocked() }
    }
    @objc private func frame(){
        guard UIApplication.shared.applicationState == .active && !inFrame else { return }
        inFrame=true;defer { inFrame=false }
        let start=CACurrentMediaTime()
        var engineMilliseconds:Double=0
        if engineReady {
            etpad_frame();engineMilliseconds=(CACurrentMediaTime()-start)*1000
            if lastFrameTime>0 { intervals.append((start-lastFrameTime)*1000) };lastFrameTime=start
            pollInputSources()
        }
        pollMenuController()
        if engineReady { pollGameMenuCursor() }
        updateTouchVisibility()
        guard engineReady else { return }
        let totalMilliseconds=(CACurrentMediaTime()-start)*1000
        frameTimes.append(engineMilliseconds)
        hostTimes.append(max(0,totalMilliseconds-engineMilliseconds))
        callbackTimes.append(totalMilliseconds)
        if frameTimes.count>=600 {
            let sorted=frameTimes.sorted(),callbacks=callbackTimes.sorted(),hosts=hostTimes.sorted()
            let count=Double(frameTimes.count),p95=Int(Double(frameTimes.count-1)*0.95)
            let interval=intervals.isEmpty ? 0:intervals.reduce(0,+)/Double(intervals.count)
            NSLog("ETPad TIMING renderer=%@ pixels=%dx%d frames=%d cpu_avg_ms=%.3f cpu_p95_ms=%.3f host_avg_ms=%.3f host_p95_ms=%.3f callback_avg_ms=%.3f callback_p95_ms=%.3f interval_avg_ms=%.3f",String(cString:etpad_renderer()),etpad_render_width(),etpad_render_height(),frameTimes.count,frameTimes.reduce(0,+)/count,sorted[p95],hostTimes.reduce(0,+)/count,hosts[p95],callbackTimes.reduce(0,+)/count,callbacks[p95],interval)
            frameTimes.removeAll(keepingCapacity:true);intervals.removeAll(keepingCapacity:true)
            hostTimes.removeAll(keepingCapacity:true);callbackTimes.removeAll(keepingCapacity:true)
        }
    }
    private func action(_ title:String,icon:String?=nil,fullTitle:String?=nil,state:Bool?=nil,attributes:UIAction.Attributes=[],_ handler:@escaping()->Void)->UIAction {
        UIAction(title:title,image:icon.flatMap { UIImage(systemName:$0) },discoverabilityTitle:fullTitle,attributes:attributes,state:state==true ? .on:.off) { _ in handler() }
    }
    private func setAutoHide(_ enabled:Bool){
        overlay.configuration.hideWithController=enabled
        refreshMenu()
    }
    private func group(_ children:[UIMenuElement],_ title:String="")->UIMenu { UIMenu(title:title,options:.displayInline,children:children) }
    // Short top level: what you do right now, then three folders.
    //   In a match: Team & Class · Game Menu · Chat ▸ · Vote ▸ · Command Map
    //   Otherwise:  Find a Server · Practice with Bots ▸ · Join by Address
    //   Then:       Play Elsewhere ▸ (in a match) · Settings ▸ · Help ▸
    //   Last:       Leave Match (in a match)
    private func refreshMenu(){
        // Layout restore/import also changes this one canonical setting.
        UserDefaults.standard.set(autoHide,forKey:"etpad.autoHide")
        let servers=action("Find a Server",icon:"globe"){[weak self] in self?.showServers()}
        servers.subtitle=inMatch ? "Leaves this match when you join":"Live servers with players"
        let practice=UIMenu(title:"Practice with Bots",image:UIImage(systemName:"person.3.sequence"),children:practiceItems())
        practice.subtitle=inMatch ? "Leaves this match":"\(botCount-1) bots, offline"
        let address=action("Join by Address…",icon:"link"){[weak self] in self?.joinAddress()}
        var sections:[UIMenuElement]=[]
        if inMatch {
            sections.append(group(matchItems()))
            let elsewhere=UIMenu(title:"Play Elsewhere",image:UIImage(systemName:"arrow.triangle.swap"),children:[servers,practice,address])
            sections.append(group([elsewhere,settingsMenu(),helpMenu()]))
            sections.append(group([action("Leave Match",icon:"rectangle.portrait.and.arrow.right",attributes:.destructive){[weak self] in self?.leaveMatch()}]))
        } else {
            sections.append(group([servers,practice,address]))
            sections.append(group([settingsMenu(),helpMenu()]))
        }
        menu.menu=UIMenu(title:"",children:sections)
        updateLauncher()
        updateTouchVisibility()
    }
    private func settingsMenu()->UIMenu {
        let hideItem=action("Hide When Using a Controller",icon:"eye.slash",state:autoHide){[weak self] in guard let s=self else{return};s.setAutoHide(!s.autoHide)}
        hideItem.subtitle="Or a keyboard. Touch the screen to bring them back."
        let touch=UIMenu(title:"Touch Controls",image:UIImage(systemName:"hand.tap"),children:[
            group([action("Show Touch Controls",state:showTouch){[weak self] in guard let s=self else{return};s.showTouch.toggle();UserDefaults.standard.set(s.showTouch,forKey:"etpad.showTouch");s.refreshMenu()},hideItem]),
            group([action("Size, Opacity and Look Speed…",icon:"slider.horizontal.3"){[weak self] in self?.touchSettings()},
                action(overlay.arranging ? "Done Moving Buttons":"Move Buttons",icon:overlay.arranging ? "checkmark":"hand.draw"){[weak self] in guard let s=self else{return};s.releaseInputs();s.overlay.arranging.toggle();s.refreshMenu()}])])
        let controller=action("Controller Buttons…",icon:"gamecontroller"){[weak self] in self?.mapping()}
        controller.subtitle=GCController.controllers().first.map { $0.vendorName ?? "Connected" } ?? "No controller connected"
        let width=UserDefaults.standard.integer(forKey:"etpad.renderWidth")
        let graphics=UIMenu(title:"Graphics",image:UIImage(systemName:"display"),children:[
            UIMenu(title:"Resolution",options:.displayInline,children:[960,1280,1600,1920].map { w in action("\(w) pixels wide",state:(width==0 ? 1280:width)==w){[weak self] in self?.resolution(w)} }),
            group([action("Field of View…",icon:"viewfinder"){[weak self] in self?.fieldOfView()},
                action("Show FPS Counter",icon:"speedometer",state:UserDefaults.standard.bool(forKey:"etpad.fps")){[weak self] in guard let s=self else{return};let on = !UserDefaults.standard.bool(forKey:"etpad.fps");UserDefaults.standard.set(on,forKey:"etpad.fps");s.command("set cg_drawFPS \(on ? 1:0)");s.refreshMenu()}])])
        let name=action("Player Name…",icon:"person.crop.circle"){[weak self] in self?.playerName()}
        name.subtitle=UserDefaults.standard.string(forKey:"etpad.name") ?? "ETPadPlayer"
        let data=UIMenu(title:"Game Data",image:UIImage(systemName:"folder"),children:[
            group([action("Download Free Game Data",icon:"arrow.down.circle"){[weak self] in self?.downloadData()},
                action("Import pak Files…",icon:"square.and.arrow.down"){[weak self] in self?.importData()}]),
            group([action("Remove Stored Game Data",icon:"trash",attributes:.destructive){[weak self] in self?.removeData()}])])
        return UIMenu(title:"Settings",image:UIImage(systemName:"gearshape"),children:[group([touch,controller]),group([graphics,name]),group([data])])
    }
    private func helpMenu()->UIMenu {
        UIMenu(title:"Help",image:UIImage(systemName:"questionmark.circle"),children:[
            group([action("How to Play",icon:"book"){[weak self] in self?.showGuide()}]),
            group([action("Console…",icon:"terminal"){[weak self] in self?.console()},
                action("Game Keyboard…",icon:"keyboard"){[weak self] in self?.gameKeyboard()}]),
            group([action("Report a Problem…",icon:"exclamationmark.bubble"){[weak self] in self?.reportProblem()},
                action("ETPad on GitHub",icon:"safari"){ UIApplication.shared.open(URL(string:"https://github.com/chrissotraidis/etpad")!) }])])
    }
    private func matchItems()->[UIMenuElement]{
        let quick=[("Medic!","vsay_team Medic"),("Need Ammo","vsay_team NeedAmmo"),("Need Backup","vsay_team NeedBackup"),("Need an Engineer","vsay_team NeedEngineer"),
                   ("Cover Me","vsay_team CoverMe"),("Affirmative","vsay_team Affirmative"),("Negative","vsay_team Negative"),("Thanks","vsay Thanks"),("Great Shot","vsay GreatShot")]
        let chat=UIMenu(title:"Chat",image:UIImage(systemName:"bubble.left.and.bubble.right"),children:[
            group([action("Say to Everyone…",icon:"bubble.left.and.bubble.right"){[weak self] in self?.chat("say")},
                action("Say to Team…",icon:"bubble.left"){[weak self] in self?.chat("say_team")}]),
            group(quick.map { title,cmd in action(title){[weak self] in self?.command(cmd)} },"Quick Chat")])
        let vote=UIMenu(title:"Vote",image:UIImage(systemName:"hand.raised"),children:[
            action("Vote Yes",icon:"hand.thumbsup"){[weak self] in self?.command("vote yes")},
            action("Vote No",icon:"hand.thumbsdown"){[weak self] in self?.command("vote no")}])
        return [action("Team & Class…",icon:"person.2"){[weak self] in self?.command("openlimbomenu")},
                action("Game Menu",icon:"list.bullet.rectangle"){[weak self] in self?.command("togglemenu")},
                chat,vote,
                action("Command Map",icon:"map"){[weak self] in self?.command("ToggleAutoMap")}]
    }
    private func chat(_ verb:String){
        prompt(verb=="say" ? "Say to Everyone":"Say to Team",placeholder:"Message",submit:"Send"){[weak self] text in
            let clean=String(text.filter { $0 != "\"" && $0 != ";" && $0 != "\n" }.prefix(150))
            if !clean.isEmpty { self?.command("\(verb) \"\(clean)\"") }
        }
    }
    private func leaveMatch(){
        let alert=UIAlertController(title:"Leave this match?",message:"You return to the main menu.",preferredStyle:.alert)
        alert.addAction(UIAlertAction(title:"Stay",style:.cancel))
        alert.addAction(UIAlertAction(title:"Leave",style:.destructive){[weak self] _ in self?.command("disconnect")})
        present(alert,animated:true)
    }
    private func joinAddress(){
        prompt("Join by Address",placeholder:"host:27960",submit:"Join"){[weak self] address in
            let trimmed=address.trimmingCharacters(in:.whitespaces)
            guard ServerBrowserViewController.validAddress(trimmed) else { self?.alert("Join by Address","Enter a hostname or IPv4 address, optionally with :port.");return }
            self?.join(trimmed,password:nil)
        }
    }
    private func showGuide(){
        releaseInputs()
        let navigation=UINavigationController(rootViewController:GuideViewController())
        navigation.modalPresentationStyle = .formSheet;navigation.preferredContentSize=CGSize(width:640,height:620)
        present(navigation,animated:true)
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
            .slider("Look Speed",0.4,2.5,Float(overlay.configuration.lookSpeed)){[weak self] in self?.overlay.configuration.lookSpeed=Double($0)},
            .toggle("Push stick forward to sprint",overlay.configuration.sprintByPush){[weak self] in self?.overlay.configuration.sprintByPush=$0},
            .toggle("Hide while a controller or keyboard is used",autoHide){[weak self] in self?.setAutoHide($0)},
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
    private func console(){prompt("Console",placeholder:"ET command",submit:"Run"){[weak self] text in self?.command(text)}}
    private func gameKeyboard(){prompt("Game Keyboard",placeholder:"Text for the selected game field",submit:"Type"){[weak self] text in guard self?.engineReady == true else{return};for scalar in text.unicodeScalars {etpad_character(Int32(scalar.value))}}}
    private func removeData(){
        guard !dataManager.busy else{return};releaseInputs()
        let message=engineReady ? "The three original pak files will be removed next time you open ETPad. Your saves and downloaded maps will stay." : "Remove the three original pak files? Your saves and downloaded maps will stay. You can download or import the data again."
        let alert=UIAlertController(title:"Remove Stored Game Data",message:message,preferredStyle:.alert);alert.addAction(UIAlertAction(title:"Cancel",style:.cancel))
        alert.addAction(UIAlertAction(title:"Remove Game Data",style:.destructive){[weak self] _ in guard let self=self else{return}
            if self.engineReady {UserDefaults.standard.set(true,forKey:"etpad.removeDataOnLaunch");self.alert("Game Data","Removal is scheduled for the next app launch.")}
            else {do{try self.dataManager.removeInstalled();self.dataReady=false;self.updateLauncher()}catch{self.alert("Game Data",error.localizedDescription)}}
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
    private func waitForLandscape(attempt:Int,extra:[String]) {
        if view.window?.windowScene?.interfaceOrientation.isLandscape == true && view.bounds.width > view.bounds.height {
            startEngine(extra:extra)
        } else if attempt < 40 {
            DispatchQueue.main.asyncAfter(deadline:.now()+0.1) { [weak self] in self?.waitForLandscape(attempt:attempt+1,extra:extra) }
        } else { started=false;updateLauncher();alert("Rotate to Landscape","ETPad could not enter landscape. Rotate the iPad and try again.") }
    }
    private func startEngine(extra:[String]) {
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
        args += extra
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
        // The engine now renders beneath the host window; retire the launcher.
        UIView.animate(withDuration:0.35,animations:{ self.launcher.alpha=0 }) { _ in self.launcher.removeFromSuperview() }
    }

}

// Short controls guide for touch, controller and keyboard/mouse play.
private final class GuideViewController:UIViewController {
    override func viewDidLoad(){
        super.viewDidLoad();title="How to Play";overrideUserInterfaceStyle = .dark;view.backgroundColor=ETPadTheme.ink
        navigationItem.rightBarButtonItem=UIBarButtonItem(barButtonSystemItem:.done,target:self,action:#selector(done))
        let text=UITextView();text.isEditable=false;text.backgroundColor = .clear;text.textContainerInset=UIEdgeInsets(top:20,left:22,bottom:28,right:22)
        let body=NSMutableAttributedString()
        func heading(_ s:String){body.append(NSAttributedString(string:s.uppercased()+"\n",attributes:[.font:ETPadTheme.stencil(17),.kern:1.6,.foregroundColor:ETPadTheme.brass]))}
        func line(_ s:String){body.append(NSAttributedString(string:s+"\n",attributes:[.font:UIFont.systemFont(ofSize:15),.foregroundColor:ETPadTheme.cream]))}
        func gap(){body.append(NSAttributedString(string:"\n",attributes:[.font:UIFont.systemFont(ofSize:8)]))}
        heading("Getting into a game");line("Play Online lists live ET: Legacy servers with people on them. Tap one to join; maps download the first time.");line("Practice with Bots starts an offline round on a classic map. Choose a team and class when the Limbo menu opens.");gap()
        heading("Touch");line("Left thumb: drag anywhere on the left to move. Push the stick well past its rim, forward, to sprint.");line("Right thumb: drag anywhere on the right to look. Hold FIRE and slide your thumb to aim while firing.");line("JUMP, CROUCH, PRONE, RELOAD, ALT (scope or alternate fire) and USE sit around FIRE. ‹ › change weapons.");line("SCORE (hold) and MENU sit at the top left beside the ••• menu. Arrange Controls lets you move any button.");gap()
        heading("Controller");line("Left stick moves, right stick looks. RT fires, LT alternate fire. A jump, B crouch, X reload, Y use. L3 sprint, R3 prone.");line("Back shows scores, Start opens the game menu. D-pad: map, Limbo, previous and next weapon.");line("Hold LB for lean, votes and quick chat; hold RB for weapon banks. Options › Controls › Controller Buttons shows and changes every binding.");gap()
        heading("Keyboard and mouse");line("ET's standard keys work: W A S D to move, Space jump, C crouch, X prone, Shift sprint, Q and E lean, R reload, F use, 1–0 weapons, Tab scores, Esc menu, ~ console.");line("During play the pointer locks for mouse look: left click fires, right click is alternate fire. In menus the pointer clicks normally.");gap()
        heading("Switching");line("Use any input at any time. Touch controls hide while a controller or keyboard is in use and return when you touch the screen. Turn this off in Options › Controls.")
        text.attributedText=body
        text.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(text)
        NSLayoutConstraint.activate([text.leadingAnchor.constraint(equalTo:view.leadingAnchor),text.trailingAnchor.constraint(equalTo:view.trailingAnchor),text.topAnchor.constraint(equalTo:view.topAnchor),text.bottomAnchor.constraint(equalTo:view.bottomAnchor)])
    }
    @objc private func done(){dismiss(animated:true)}
}
