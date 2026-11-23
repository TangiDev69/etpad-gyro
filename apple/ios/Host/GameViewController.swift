// ETPad host, adapted from UTP GameViewController.swift at
// a9313911efcf044fd66f9a679af53e55e255a8b4. GPL-3.0-or-later.
import UIKit
import GameController
import UniformTypeIdentifiers
import CoreMotion

// GCEventViewController keeps controller presses away from UIKit (which
// otherwise highlights on-screen buttons); the game and host read them
// through SDL and GameController instead.
final class GameViewController:GCEventViewController,UIDocumentPickerDelegate {
    // The last input used decides whether touch controls show. A controller or
    // keyboard/mouse hides them (when Auto-Hide is on); a finger brings them back.
    private enum InputMode { case touch,controller,keyboard }
    private var started=false,engineReady=false,checking=false,dataReady=false
    private var showTouch=true
    private var autoHide:Bool { overlay.configuration.hideWithController }
    private var displayLink:CADisplayLink?
    private let fpsBadge=UILabel()
    private var fpsWindowStart:Double=0,fpsWindowFrames=0,currentFPS=0
    private let motionManager=CMMotionManager()
    private var gyroLastTime:Double=0,gyroAccumX:Double=0,gyroAccumY:Double=0
    private var gyroEnabled:Bool { UserDefaults.standard.bool(forKey:"etpad.gyro") }
    private var gyroSensitivity:Double { UserDefaults.standard.object(forKey:"etpad.gyroSensitivity") as? Double ?? 2.0 }
    private var gyroInvertX:Bool { UserDefaults.standard.bool(forKey:"etpad.gyroInvertX") }
    private var gyroInvertY:Bool { UserDefaults.standard.object(forKey:"etpad.gyroInvertY") as? Bool ?? true }
    private var observers:[NSObjectProtocol]=[]
    private let dataManager=GameDataManager()
    private let prompts=UIButton(type:.system),menu=MenuButton(type:.system)
    private let wheel=CommsWheel(frame:.zero),back=UIButton(type:.system),textInput=GameTextInput(frame:.zero)
    private var keyboardHintUntil:Double=0
    private var wheelFromController=false
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
    override var supportedInterfaceOrientations:UIInterfaceOrientationMask { traitCollection.userInterfaceIdiom == .pad ? .all : .landscape }
    override var prefersStatusBarHidden:Bool { true }
    override var prefersHomeIndicatorAutoHidden:Bool { true }
    override var prefersPointerLocked:Bool { wantsPointerLock }
    override var canBecomeFirstResponder:Bool { true }
    override func viewDidLoad(){
        super.viewDidLoad();overrideUserInterfaceStyle = .dark;view.backgroundColor = .black;controllerUserInteractionEnabled=false
        fpsBadge.textAlignment = .left;fpsBadge.font = UIFont.monospacedDigitSystemFont(ofSize:12,weight:.medium);fpsBadge.textColor=UIColor(red:0.72,green:1,blue:0.30,alpha:1);fpsBadge.backgroundColor = .clear;fpsBadge.layer.borderWidth=0;fpsBadge.layer.cornerRadius=0;fpsBadge.layer.masksToBounds=false;fpsBadge.isUserInteractionEnabled=false;fpsBadge.text="--";fpsBadge.isHidden=true;view.addSubview(fpsBadge)
        showTouch=UserDefaults.standard.object(forKey:"etpad.showTouch") as? Bool ?? true
        motionManager.deviceMotionUpdateInterval=1.0/60.0
        if gyroEnabled { motionManager.startDeviceMotionUpdates() }
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
        // Back closes ET's own menus (game menu, Team & Class, console) when
        // there is no Escape key, so a touch player is never stuck in them.
        var backStyle=UIButton.Configuration.plain()
        backStyle.image=UIImage(systemName:"chevron.left",withConfiguration:UIImage.SymbolConfiguration(pointSize:15,weight:.bold))
        backStyle.title="Back";backStyle.imagePadding=6;backStyle.baseForegroundColor = .white;backStyle.cornerStyle = .capsule
        backStyle.background.backgroundColor=UIColor(white:0.06,alpha:0.72);backStyle.background.strokeColor=UIColor.white.withAlphaComponent(0.30);backStyle.background.strokeWidth=1
        backStyle.titleTextAttributesTransformer=UIConfigurationTextAttributesTransformer { var a=$0;a.font=UIFont.systemFont(ofSize:15,weight:.semibold);return a }
        back.configuration=backStyle;back.isHidden=true;back.accessibilityLabel="Back to the game"
        back.addAction(UIAction { [weak self] _ in guard self?.engineReady == true else { return };etpad_key(27,1);etpad_key(27,0) },for:.touchUpInside)
        view.addSubview(back)
        // A mouse or trackpad pointer (not Apple Pencil hover) means keyboard and mouse play.
        let hover=UIHoverGestureRecognizer(target:self,action:#selector(pointerHover(_:)));view.addGestureRecognizer(hover)
        menu.onShow = { [weak self] showing in
            guard let self=self else { return }
            if showing { self.releaseInputs() } else { DispatchQueue.main.async { self.restoreHost() } }
        }
        wheel.onSend = { [weak self] command in self?.command(command) }
        // While the wheel is open the controller drives it, not the game.
        wheel.onOpen = { [weak self] in self?.releaseInputs();etpad_set_suspend_look(1) }
        wheel.onClose = { [weak self] in self?.wheelFromController=false;etpad_set_suspend_look(0) }
        view.addSubview(wheel)
        textInput.onCharacter = { [weak self] scalar in if self?.engineReady == true { etpad_character(Int32(scalar.value)) } }
        textInput.onKey = { [weak self] key in
            guard self?.engineReady == true else { return }
            etpad_key(key,1);etpad_key(key,0)
            // ET's text fields delete on the Ctrl-H character, as desktop SDL sends it.
            if key == 127 { etpad_character(8) }
        }
        view.addSubview(textInput)
        overlay.onAction = { [weak self] action,pressed in self?.touchAction(action,pressed:pressed) }
        overlay.onMove = { [weak self] value in if self?.engineReady == true { etpad_touch_move(Float(value.x),Float(value.y)) } }
        overlay.onLook = { [weak self] value in if self?.engineReady == true { etpad_mouse(Int32((value.x*1.5).rounded()),Int32((value.y*1.5).rounded())) } }
        overlay.onTouch = { [weak self] in self?.setInputMode(.touch) }
        overlay.onConfigurationChanged = { [weak self] in self?.refreshMenu() }
        overlay.onExitArrange = { [weak self] in guard let self=self else{return};self.overlay.arranging=false;self.refreshMenu() }
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
                // A keyboard case reports as connected even when folded back,
                // so keyboard mode starts with an actual key press instead.
                if note.name == .GCMouseDidConnect { self.setInputMode(.keyboard) }
                if note.name == .GCMouseDidDisconnect && GCMouse.mice().isEmpty && self.inputMode == .keyboard { self.setInputMode(.touch) }
                if note.name == .GCControllerDidDisconnect && GCController.controllers().isEmpty && self.inputMode == .controller { self.setInputMode(.touch) }
                self.restoreHost();self.refreshPrompts()
            })
        }
        // Plugging a display in or out keeps mirroring; log it for external-display checks.
        for name in [UIScreen.didConnectNotification,UIScreen.didDisconnectNotification] {
            observers.append(NotificationCenter.default.addObserver(forName:name,object:nil,queue:.main) { [weak self] note in
                NSLog("ETPad %@: %d screens",note.name.rawValue,UIScreen.screens.count);self?.restoreHost()
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName:UIPointerLockState.didChangeNotification,object:nil,queue:.main) { [weak self] _ in
            let locked=self?.view.window?.windowScene?.pointerLockState?.isLocked ?? false
            etpad_set_pointer_locked(locked ? 1:0);NSLog("ETPad pointer lock %@",locked ? "on":"off")
        })
        observers.append(NotificationCenter.default.addObserver(forName:UIApplication.willResignActiveNotification,object:nil,queue:.main) { [weak self] _ in
            guard let self=self else { return };self.releaseInputs();self.displayLink?.isPaused=true;self.lastFrameTime=0;self.motionManager.stopDeviceMotionUpdates();self.gyroLastTime=0;NSLog("ETPad lifecycle paused")
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
        super.viewDidLayoutSubviews();setFrame(view.bounds,for:surface);setFrame(view.bounds,for:overlay);setFrame(view.bounds,for:launcher);setFrame(view.bounds,for:wheel)
        let safe=view.bounds.inset(by:view.safeAreaInsets)
        layoutMenu(in:safe)
        setFrame(CGRect(x:safe.minX+12,y:safe.minY+12,width:42,height:18),for:fpsBadge)
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
        // While the ••• menu is open its own window must stay key.
        if !host.isKeyWindow && !menu.showing { host.makeKeyAndVisible() }
        if UIApplication.shared.applicationState == .active { displayLink?.isPaused=false;if gyroEnabled && !motionManager.isDeviceMotionActive { motionManager.startDeviceMotionUpdates() } }
        view.bringSubviewToFront(menu)
        if presentedViewController==nil && !textInput.isFirstResponder { becomeFirstResponder() }
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
            for press in presses { if let key=press.key {
                etpad_hardware_key(Int32(key.keyCode.rawValue),1)
                if key.keyCode == .keyboardDeleteOrBackspace { etpad_character(8) }
            } }
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
        if action=="etpad_comms" { if pressed && engineReady && !overlay.arranging { wheel.show(tap:true) };return }
        // SCORE is a toggle on touch: tap to show the scoreboard, tap to hide.
        if action=="etpad_scores" { if pressed && engineReady { command((etpad_hud_flags() & 1) != 0 ? "-scores":"+scores") };return }
        guard engineReady else { return }
        if action.hasPrefix("+") { command((pressed ? "+":"-")+action.dropFirst()) }
        else if pressed { command(action) }
    }
    private func releaseInputs(){overlay.releaseAll();if engineReady { etpad_release_inputs() }}
    private func setInputMode(_ mode:InputMode){
        guard mode != inputMode else { return }
        inputMode=mode;NSLog("ETPad input mode %@",String(describing:mode))
        if mode == .controller { controllerHintUntil=CACurrentMediaTime()+8;wheel.useController() }
        if mode == .keyboard { keyboardHintUntil=CACurrentMediaTime()+8 }
        refreshPrompts()
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
    private func pollComms(){
        let pad=GCController.controllers().first?.extendedGamepad
        let rb=pad?.rightShoulder.isPressed ?? false
        func edge(_ name:String,_ on:Bool)->Bool { let was=padPrevious[name] ?? false;padPrevious[name]=on;return on && !was }
        let rbDown=edge("rb",rb),aDown=edge("wheel.a",pad?.buttonA.isPressed ?? false),bDown=edge("wheel.b",pad?.buttonB.isPressed ?? false)
        if !wheel.isHidden {
            // One wheel, any input: a stick points, A or releasing RB sends,
            // B cancels, and a tap on a wedge sends from touch.
            if !gameplayActive || presentedViewController != nil { wheel.hide();return }
            if let pad=pad {
                let right=pad.rightThumbstick,left=pad.leftThumbstick
                let stick=hypot(right.xAxis.value,right.yAxis.value)>0.45 ? right:left
                if hypot(stick.xAxis.value,stick.yAxis.value)>0.45 { wheel.useController();setInputMode(.controller) }
                wheel.point(x:stick.xAxis.value,y:stick.yAxis.value)
            }
            if rbDown { wheelFromController=true;wheel.useController() }
            if aDown { wheel.commit() } else if bDown { wheel.hide() } else if wheelFromController && !rb { wheel.commit() }
        } else if rbDown && gameplayActive && presentedViewController==nil {
            wheelFromController=true;wheel.show(tap:false);setInputMode(.controller)
        }
    }
    // Controller look speed and inversion, applied to ET's joystick scales.
    // ET's text fields (profile name, chat, passwords, console) get the iPad
    // keyboard when no hardware keyboard is attached.
    private func updateSoftwareKeyboard(){
        // iPadOS decides whether the on-screen keyboard appears (it stays
        // away while a usable hardware keyboard is attached).
        let wants=engineReady && presentedViewController==nil && etpad_text_input_active() != 0
        if wants && !textInput.isFirstResponder { let ok=textInput.becomeFirstResponder();NSLog("ETPad software keyboard show %d",ok ? 1:0) }
        else if !wants && textInput.isFirstResponder { _=textInput.resignFirstResponder();becomeFirstResponder();NSLog("ETPad software keyboard hide") }
        if wants,let preview=etpad_text_input_preview() { textInput.showPreview(String(cString:preview)) }
    }
    @objc private func pointerHover(_ gesture:UIHoverGestureRecognizer){
        guard gesture.state == .began || gesture.state == .changed else { return }
        if #available(iOS 16.1,*), gesture.zOffset>0 { return } // Apple Pencil hover
        setInputMode(.keyboard)
    }
    // Launch-hook commands; "etpad_comms" opens the quick-chat wheel.
    private func runTest(_ text:String){
        var parts=text.split(separator:";").map({ $0.trimmingCharacters(in:.whitespaces) })
        while !parts.isEmpty {
            let part=parts.removeFirst()
            // "etpad_pause" waits one second before the rest run.
            if part=="etpad_pause" { let rest=parts.joined(separator:";");DispatchQueue.main.asyncAfter(deadline:.now()+1) { [weak self] in self?.runTest(rest) };return }
            switch part {
            case "etpad_comms":wheel.show(tap:true)
            case "etpad_touch":setInputMode(.touch)
            case "etpad_scores":touchAction("etpad_scores",pressed:true)
            case "etpad_settings":showSettings()
            case "etpad_backspace":textInput.deleteBackward()
            case let typed where typed.hasPrefix("etpad_type "):textInput.insertText(String(typed.dropFirst(11)))
            default:command(part)
            }
        }
    }
    private func applyPadLook(){
        let speed=UserDefaults.standard.object(forKey:"etpad.padLook") as? Double ?? 1
        let invert=UserDefaults.standard.bool(forKey:"etpad.padInvert")
        command(String(format:"set j_yaw %.5f;set j_pitch %.5f",-0.007*speed,0.0055*speed*(invert ? -1:1)))
    }
    private func padLookSpeed(){
        presentSettings("Controller Look Speed",rows:[.slider("Look Speed",0.4,2.5,Float(UserDefaults.standard.object(forKey:"etpad.padLook") as? Double ?? 1)){[weak self] value in
            UserDefaults.standard.set(Double(value),forKey:"etpad.padLook");self?.applyPadLook() }])
    }
    // The chip under the top edge names the active input's key controls for
    // eight seconds after switching to it.
    private func refreshPrompts(){
        hasMouse = !GCMouse.mice().isEmpty
        let controller=GCController.controllers().first
        controllerConnected=controller != nil
        if let controller=controller,promptController !== controller { controllerHintUntil=CACurrentMediaTime()+8;promptController=controller }
        if controller==nil { promptController=nil }
        var style=prompts.configuration
        if inputMode == .keyboard {
            style?.image=UIImage(systemName:"keyboard");style?.title=hasMouse ? "Mouse aims · Esc menu · V quick chat · Tab scores":"Esc menu · V quick chat · Tab scores"
            prompts.accessibilityLabel="Keyboard and mouse controls"
        } else if let controller=controller {
            let profile=controller.physicalInputProfile
            let playStation=profile is GCDualShockGamepad || profile is GCDualSenseGamepad
            style?.image=UIImage(systemName:"gamecontroller.fill")
            style?.title=playStation ? "R2 Fire · △ Grenade · R1 Quick chat":"RT Fire · Y Grenade · RB Quick chat"
            prompts.accessibilityLabel="\(controller.vendorName ?? "Controller") connected. Controller buttons"
        }
        prompts.configuration=style
        view.setNeedsLayout();updateTouchVisibility()
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
        // An open scoreboard needs the whole screen; ••• returns when it closes.
        setHidden(gameplayActive && overlay.scoreboardVisible,for:menu)
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
                if let test=self.pendingCommand { self.pendingCommand=nil;self.runTest(test) }
                // openlimbomenu toggles; ET may already show team selection.
                else if etpad_gameplay() != 0 { self.command("openlimbomenu") }
            }
        } else if let test=pendingCommand,!pendingBots,state==8 {
            pendingCommand=nil;DispatchQueue.main.asyncAfter(deadline:.now()+1.5) { [weak self] in self?.runTest(test) }
        }
        let hudFlags=engineReady ? etpad_hud_flags():0
        let scoreboard=(hudFlags & 3) != 0
        if overlay.scoreboardVisible != scoreboard { overlay.scoreboardVisible=scoreboard }
        let now=CACurrentMediaTime()
        let hint=(inputMode == .controller && controllerConnected && now<controllerHintUntil) || (inputMode == .keyboard && now<keyboardHintUntil)
        setHidden(!started || !hint || scoreboard || !wheel.isHidden,for:prompts)
        // Back shows over ET's own menus during a match.
        let inEngineMenu=engineReady && state==8 && !gameplayActive && presentedViewController==nil
        setHidden(!inEngineMenu,for:back)
        if inEngineMenu { let safe=view.bounds.inset(by:view.safeAreaInsets);setFrame(CGRect(x:safe.maxX-60-12-104,y:safe.minY+12,width:104,height:44),for:back) }
        layoutMenu(in:view.bounds.inset(by:view.safeAreaInsets))
        let otherInput=autoHide && inputMode != .touch
        let active=hostOnly || gameplayActive
        let hidden = !overlay.arranging && (!showTouch || otherInput || !active)
        if hidden != overlay.isHidden {
            if hidden { overlay.releaseAll() }
            overlay.isHidden=hidden
        }
        // Lock the pointer for mouse look only during play with a mouse attached.
        let lock=engineReady && gameplayActive && hasMouse && inputMode == .keyboard && presentedViewController==nil && !overlay.arranging && wheel.isHidden
        if lock != wantsPointerLock { wantsPointerLock=lock;setNeedsUpdateOfPrefersPointerLocked() }
    }
    @objc private func frame(){
        guard UIApplication.shared.applicationState == .active && !inFrame else { return }
        inFrame=true;defer { inFrame=false }
        let start=CACurrentMediaTime()
        var engineMilliseconds:Double=0
        if engineReady {
            pollGyro(now:start)
            etpad_frame();engineMilliseconds=(CACurrentMediaTime()-start)*1000
            if lastFrameTime>0 { intervals.append((start-lastFrameTime)*1000) };lastFrameTime=start
            pollInputSources()
        }
        pollMenuController()
        if engineReady { pollGameMenuCursor();pollComms() }
        updateTouchVisibility()
        updateSoftwareKeyboard()
        guard engineReady else { fpsBadge.isHidden=true;return }
        let totalMilliseconds=(CACurrentMediaTime()-start)*1000
        if UserDefaults.standard.bool(forKey:"etpad.fps") && gameplayActive && !overlay.scoreboardVisible { fpsBadge.isHidden=false;fpsWindowFrames+=1;if fpsWindowStart==0 { fpsWindowStart=start };if start-fpsWindowStart>=1 { currentFPS=Int((Double(fpsWindowFrames)/(start-fpsWindowStart)).rounded());fpsBadge.text="\(currentFPS)";fpsWindowFrames=0;fpsWindowStart=start } } else { fpsBadge.isHidden=true;fpsWindowFrames=0;fpsWindowStart=0 }
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
    // The ••• menu holds actions only; everything adjustable is in Settings.
    //   In a match: Team & Class · Chat ▸ · Vote ▸ · Command Map · Game Menu
    //               Play Elsewhere ▸ · Settings… · Help ▸ · Leave Match
    //   Otherwise:  Find a Server · Practice with Bots ▸ · Join by Address…
    //               Settings… · Help ▸
    private func refreshMenu(){
        UserDefaults.standard.set(autoHide,forKey:"etpad.autoHide")
        let servers=action("Find a Server",icon:"globe"){[weak self] in self?.showServers()}
        servers.subtitle=inMatch ? "Leaves this match when you join":"Live servers with players"
        let practice=UIMenu(title:"Practice with Bots",image:UIImage(systemName:"person.3.sequence"),children:practiceItems())
        practice.subtitle=inMatch ? "Leaves this match":"\(botCount-1) bots, offline"
        let address=action("Join by Address…",icon:"link"){[weak self] in self?.joinAddress()}
        let settings=action("Settings…",icon:"gearshape"){[weak self] in self?.showSettings()}
        settings.subtitle="Touch, controller, keyboard and mouse, graphics"
        let help=UIMenu(title:"Help",image:UIImage(systemName:"questionmark.circle"),children:[
            group([action("How to Play",icon:"book"){[weak self] in self?.showGuide()}]),
            group([action("Console…",icon:"terminal"){[weak self] in self?.console()},
                action("Type into the Game…",icon:"keyboard"){[weak self] in self?.gameKeyboard()}]),
            group([action("Report a Problem…",icon:"exclamationmark.bubble"){[weak self] in self?.reportProblem()},
                action("ETPad on GitHub",icon:"safari"){ UIApplication.shared.open(URL(string:"https://github.com/chrissotraidis/etpad")!) }])])
        var sections:[UIMenuElement]=[]
        if inMatch {
            sections.append(group(matchItems()))
            let elsewhere=UIMenu(title:"Play Elsewhere",image:UIImage(systemName:"arrow.triangle.swap"),children:[servers,practice,address])
            sections.append(group([elsewhere,settings,help]))
            sections.append(group([action("Leave Match",icon:"rectangle.portrait.and.arrow.right",attributes:.destructive){[weak self] in self?.leaveMatch()}]))
        } else {
            sections.append(group([servers,practice,address]))
            sections.append(group([settings,help]))
        }
        menu.menu=UIMenu(title:"",children:sections)
        updateLauncher()
        updateTouchVisibility()
    }
    private func matchItems()->[UIMenuElement]{
        let chat=UIMenu(title:"Chat",image:UIImage(systemName:"bubble.left.and.bubble.right"),children:[
            action("Quick-Chat Wheel",icon:"circle.grid.cross"){[weak self] in self?.wheel.show(tap:true)},
            action("Say to Team…",icon:"bubble.left"){[weak self] in self?.chat("say_team")},
            action("Say to Everyone…",icon:"bubble.left.and.bubble.right"){[weak self] in self?.chat("say")}])
        let vote=UIMenu(title:"Vote",image:UIImage(systemName:"hand.raised"),children:[
            action("Vote Yes",icon:"hand.thumbsup"){[weak self] in self?.command("vote yes")},
            action("Vote No",icon:"hand.thumbsdown"){[weak self] in self?.command("vote no")}])
        return [action("Team & Class…",icon:"person.2"){[weak self] in self?.command("openlimbomenu")},
                chat,vote,
                action("Command Map",icon:"map"){[weak self] in self?.command("ToggleAutoMap")},
                action("Game Menu",icon:"list.bullet.rectangle"){[weak self] in self?.command("togglemenu")}]
    }
    private func showSettings(){
        let d=UserDefaults.standard,c=overlay.configuration
        let width=d.integer(forKey:"etpad.renderWidth"),widths=[960,1280,1600,1920]
        let pad=GCController.controllers().first
        typealias S=HostSettingsViewController.Section
        var sections:[S]=[
            S(title:"Touch Controls",footer:"Touch the screen at any time to bring touch controls back.",rows:[
                .toggle("Show Touch Controls",showTouch){[weak self] on in guard let s=self else{return};s.showTouch=on;d.set(on,forKey:"etpad.showTouch");s.refreshMenu()},
                .toggle("Hide While Using a Controller or Keyboard",autoHide){[weak self] in self?.setAutoHide($0)},
                .slider("Size",0.7,1.3,Float(c.size)){[weak self] in self?.overlay.configuration.size=Double($0)},
                .slider("Opacity",0.25,1,Float(c.opacity)){[weak self] in self?.overlay.configuration.opacity=Double($0)},
                .slider("Look Speed",0.4,8.0,Float(c.lookSpeed)){[weak self] in self?.overlay.configuration.lookSpeed=Double($0)},
                .toggle("Push Stick Forward to Sprint",c.sprintByPush){[weak self] in self?.overlay.configuration.sprintByPush=$0},
                .toggle("Left-Handed",c.leftHanded){[weak self] in self?.releaseInputs();self?.overlay.configuration.leftHanded=$0},
                .button("Move / Resize Buttons"){[weak self] in self?.overlay.arranging=true;self?.refreshMenu()},
                .button("Customize Each Button"){[weak self] in self?.customizeButtons()},
                .button("Saved Layouts"){[weak self] in self?.savedLayouts()},
                .destructive("Restore Default Layout"){[weak self] in self?.overlay.restoreDefault();self?.refreshMenu()}]),
            S(title:"Gyroscope",footer:"Landscape handheld mapping based on your Quake III port. If aiming feels reversed, invert each axis independently.",rows:[
                .toggle("Enable Gyroscope",gyroEnabled){[weak self] on in UserDefaults.standard.set(on,forKey:"etpad.gyro");self?.setGyroEnabled(on)},
                .slider("Gyro Sensitivity",0.5,6.0,Float(gyroSensitivity)){[weak self] in UserDefaults.standard.set(Double($0),forKey:"etpad.gyroSensitivity");self?.gyroAccumX=0;self?.gyroAccumY=0},
                .toggle("Invert Horizontal",gyroInvertX){[weak self] on in UserDefaults.standard.set(on,forKey:"etpad.gyroInvertX");self?.gyroAccumX=0},
                .toggle("Invert Vertical",gyroInvertY){[weak self] on in UserDefaults.standard.set(on,forKey:"etpad.gyroInvertY");self?.gyroAccumY=0}]),
            S(title:"Controller",footer:pad.map { "\($0.vendorName ?? "Controller") connected." } ?? "Pair an Xbox, PlayStation or MFi controller in iPad Settings › Bluetooth.",rows:[
                .slider("Look Speed",0.4,2.5,Float(d.object(forKey:"etpad.padLook") as? Double ?? 1)){[weak self] in d.set(Double($0),forKey:"etpad.padLook");self?.applyPadLook()},
                .toggle("Invert Look",d.bool(forKey:"etpad.padInvert")){[weak self] in d.set($0,forKey:"etpad.padInvert");self?.applyPadLook()},
                .button("Buttons"){[weak self] in self?.mapping()}]),
            S(title:"Keyboard and Mouse",footer:"WASD move · Space jump · C crouch · X prone · Shift sprint · R reload · F use · 1–0 weapons · Tab scores · V quick chat · Esc menu. The pointer locks for aiming during play.",rows:[
                .slider("Mouse Sensitivity",1,20,Float(d.object(forKey:"etpad.mouseSensitivity") as? Double ?? 5)){[weak self] in d.set(Double($0),forKey:"etpad.mouseSensitivity");self?.applyMouse()},
                .toggle("Invert Mouse",d.bool(forKey:"etpad.mouseInvert")){[weak self] in d.set($0,forKey:"etpad.mouseInvert");self?.applyMouse()}]),
            S(title:"Graphics",footer:"Higher resolutions look sharper and use more power.",rows:[
                .segment("Resolution (pixels wide)",widths.map(String.init),widths.firstIndex(of:width==0 ? 1280:width) ?? 1){[weak self] in self?.resolution(widths[$0])},
                .button("Custom Resolution…"){[weak self] in self?.customResolution()},
                .slider("Field of View",75,120,Float(d.object(forKey:"etpad.fov") as? Double ?? 90)){[weak self] v in d.set(Double(v),forKey:"etpad.fov");self?.command("set cg_fov \(Int(v))")},
                .toggle("Show FPS Counter",d.bool(forKey:"etpad.fps")){[weak self] on in d.set(on,forKey:"etpad.fps");self?.fpsBadge.isHidden = !on;self?.fpsWindowFrames=0;self?.fpsWindowStart=0;self?.command("set cg_drawFPS \(on ? 1:0)")}]),
            S(title:"Player",footer:nil,rows:[.button("Name: \(d.string(forKey:"etpad.name") ?? "ETPadPlayer")"){[weak self] in self?.playerName()}]),
            S(title:"Game Data",footer:dataReady ? "Original pak0, pak1 and pak2 are installed and verified.":"ETPad needs the original pak0, pak1 and pak2 files.",rows:[
                .button("Download Free Game Data"){[weak self] in self?.downloadData()},
                .button("Import pak Files…"){[weak self] in self?.importData()},
                .destructive("Remove Stored Game Data"){[weak self] in self?.removeData()}])]
        // Lead with the controls for the input in use.
        let lead=inputMode == .controller ? "Controller":(inputMode == .keyboard ? "Keyboard and Mouse":"Touch Controls")
        if let index=sections.firstIndex(where:{ $0.title==lead }) { sections.insert(sections.remove(at:index),at:0) }
        releaseInputs()
        let controller=UINavigationController(rootViewController:HostSettingsViewController(title:"Settings",sections:sections))
        controller.modalPresentationStyle = .formSheet;controller.preferredContentSize=CGSize(width:600,height:680);present(controller,animated:true)
    }
    private func setGyroEnabled(_ on:Bool){
        gyroAccumX=0;gyroAccumY=0;gyroLastTime=0
        if on && UIApplication.shared.applicationState == .active { motionManager.startDeviceMotionUpdates() } else { motionManager.stopDeviceMotionUpdates() }
    }
    private func pollGyro(now:Double){
        guard gyroEnabled,gyroSensitivity>0,motionManager.isDeviceMotionAvailable,motionManager.deviceMotion != nil,
              inMatch,gameplayActive,inputMode == .touch,presentedViewController==nil,!menu.showing,!overlay.arranging,wheel.isHidden,!hasMouse else { gyroLastTime=now;return }
        let dt=max(0,min(0.05,now-(gyroLastTime>0 ? gyroLastTime:now)));gyroLastTime=now
        guard dt>0 else{return}
        let rate=motionManager.deviceMotion!.rotationRate
        // Match the handheld landscape axis/sign convention used by the Quake III port.
        let left=view.window?.windowScene?.interfaceOrientation == .landscapeLeft ? -1.0:1.0
        let gain=gyroSensitivity*8.0*dt*120.0*left
        gyroAccumX += -rate.x*gain*(gyroInvertX ? -1.0:1.0)
        gyroAccumY += rate.y*gain*(gyroInvertY ? -1.0:1.0)
        let dx=Int32(gyroAccumX.rounded(.towardZero)),dy=Int32(gyroAccumY.rounded(.towardZero))
        if dx != 0 || dy != 0 { gyroAccumX-=Double(dx);gyroAccumY-=Double(dy);etpad_mouse(dx,dy) }
    }
    private func applyMouse(){
        let d=UserDefaults.standard
        let sensitivity=d.object(forKey:"etpad.mouseSensitivity") as? Double ?? 5
        command(String(format:"set sensitivity %.2f;set m_pitch %.3f",sensitivity,d.bool(forKey:"etpad.mouseInvert") ? -0.022:0.022))
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
    private func customizeButtons(){
        let c=overlay.configuration
        var rows:[HostSettingsViewController.Row]=[]
        for action in GoldenPadTouchOverlay.actions {
            rows.append(.slider("\(action.title) Size",0.55,1.8,Float(c.buttonSizes[action.title] ?? 1)){[weak self] in self?.overlay.setButtonSize(action.title,Double($0))})
            rows.append(.slider("\(action.title) Opacity",0.15,1,Float(c.buttonOpacities[action.title] ?? 1)){[weak self] in self?.overlay.setButtonOpacity(action.title,Double($0))})
        }
        presentSettings("Individual Button Controls",rows:rows)
    }
    private func savedLayouts(){
        var saved=UserDefaults.standard.dictionary(forKey:"etpad.touch.saved") as? [String:Data] ?? [:]
        var rows:[HostSettingsViewController.Row]=[.button("Save Current Layout…"){[weak self] in self?.prompt("Save Layout",placeholder:"Layout name") { name in guard let self=self,!name.trimmingCharacters(in:.whitespaces).isEmpty,let data=try? JSONEncoder().encode(self.overlay.configuration) else{return};saved[String(name.prefix(48))]=data;UserDefaults.standard.set(saved,forKey:"etpad.touch.saved");self.savedLayouts() }}]
        for name in saved.keys.sorted(){
            rows.append(.button("Load: \(name)"){[weak self] in if let data=saved[name],let config=try? JSONDecoder().decode(TouchConfiguration.self,from:data){self?.releaseInputs();self?.overlay.configuration=config;self?.refreshMenu()} })
            rows.append(.destructive("Delete: \(name)"){ let alert=UIAlertController(title:"Delete Layout?",message:"Delete saved layout ‘\(name)’?",preferredStyle:.alert);alert.addAction(UIAlertAction(title:"Cancel",style:.cancel));alert.addAction(UIAlertAction(title:"Delete",style:.destructive){_ in var current=UserDefaults.standard.dictionary(forKey:"etpad.touch.saved") as? [String:Data] ?? [:];current.removeValue(forKey:name);UserDefaults.standard.set(current,forKey:"etpad.touch.saved");self.savedLayouts()});self.present(alert,animated:true) })
        }
        presentSettings("Saved Layouts",rows:rows)
    }
    @objc private func mapping(){
        let text="Left stick Move · Right stick Look\nRT Fire · LT Alt fire / scope\nA Jump · B Crouch · X Reload · Y Grenade\nLB Use (doors, objectives, ladders)\nHold RB Quick-chat wheel\nL3 Sprint · R3 Prone\nView Scores · Menu Game menu (Team & Class)\n\nD-pad\n→ Next weapon (cycles everything)\n← Last weapon (swap back)\n↑ Class tool: syringe, pliers, smoke\n↓ Class item: health, ammo, dynamite\n\nIn ET menus: left stick moves the cursor, A clicks, B goes back."
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
        ("Right Trigger","PAD0_RIGHTTRIGGER","+attack"),("Left Trigger","PAD0_LEFTTRIGGER","weapalt"),
        ("A / Cross","PAD0_A","+moveup"),("B / Circle","PAD0_B","+movedown"),("X / Square","PAD0_X","+reload"),("Y / Triangle","PAD0_Y","weaponbank 4"),
        ("Left Bumper","PAD0_LEFTSHOULDER","+activate"),
        ("Left Stick Click","PAD0_LEFTSTICK_CLICK","+sprint"),("Right Stick Click","PAD0_RIGHTSTICK_CLICK","+prone"),
        ("View / Share","PAD0_BACK","+scores"),("Menu / Options","PAD0_START","togglemenu"),
        ("D-pad Right","PAD0_DPAD_RIGHT","weapnext"),("D-pad Left","PAD0_DPAD_LEFT","weaplastused"),("D-pad Up","PAD0_DPAD_UP","weaponbank 5"),("D-pad Down","PAD0_DPAD_DOWN","weaponbank 6")]
    private static let bindingActions:[(String,String)]=[
        ("Fire","+attack"),("Alt Fire / Scope","weapalt"),("Reload","+reload"),("Jump","+moveup"),("Crouch","+movedown"),("Prone","+prone"),("Sprint","+sprint"),("Use","+activate"),
        ("Grenade","weaponbank 4"),("Class Tool (syringe, pliers, smoke)","weaponbank 5"),("Class Item (health, ammo, dynamite)","weaponbank 6"),("Mines / Adrenaline","weaponbank 7"),("Binoculars","weaponbank 8"),
        ("Knife","weaponbank 1"),("Pistol","weaponbank 2"),("Main Weapon","weaponbank 3"),
        ("Next Weapon","weapnext"),("Previous Weapon","weapprev"),("Last Weapon","weaplastused"),
        ("Lean Left","+leanleft"),("Lean Right","+leanright"),("Scoreboard","+scores"),("Command Map","+mapexpand"),("Team & Class","openlimbomenu"),("Game Menu","togglemenu"),
        ("Vote Yes","vote yes"),("Vote No","vote no"),("Console","toggleconsole"),
        ("Medic Quick Chat","vsay_team Medic"),("Ammo Quick Chat","vsay_team NeedAmmo"),("Thanks Quick Chat","vsay_team Thanks"),("Affirmative Quick Chat","vsay_team Affirmative"),("Unbound","")]
    private func editBinding(label:String,key:String,current:String){
        presentSettings(label,rows:Self.bindingActions.map { name,value in .button((value==current ? "✓ ":"")+name){[weak self] in
            guard let self=self else{return};self.releaseInputs()
            var saved=UserDefaults.standard.dictionary(forKey:"etpad.controller.bindings") as? [String:String] ?? [:]
            saved[key]=value;UserDefaults.standard.set(saved,forKey:"etpad.controller.bindings");self.command("bind \(key) \"\(value)\"")
        }})
    }
    private func resolution(_ width:Int){
        UserDefaults.standard.set(width,forKey:"etpad.renderWidth");UserDefaults.standard.set(0,forKey:"etpad.renderHeight")
        let height=Int((CGFloat(width)*view.bounds.height/max(view.bounds.width,1)).rounded())
        applyResolution(width,height)
    }
    private func customResolution(){
        let d=UserDefaults.standard,w=d.integer(forKey:"etpad.renderWidth"),h=d.integer(forKey:"etpad.renderHeight")
        let defaultHeight=Int((CGFloat(w>0 ? w:1280)*view.bounds.height/max(view.bounds.width,1)).rounded())
        prompt("Custom Resolution",placeholder:"Width x Height",value:"\(w>0 ? w:1280) x \(h>0 ? h:defaultHeight)",submit:"Apply") {[weak self] raw in
            let parts=raw.lowercased().split(whereSeparator:{!$0.isNumber})
            guard parts.count==2,let width=Int(parts[0]),let height=Int(parts[1]),width>=320,width<=4096,height>=240,height<=4096 else { self?.alert("Invalid Resolution","Enter width and height, for example 1280 x 720. Values must be between 320×240 and 4096×4096.");return }
            d.set(width,forKey:"etpad.renderWidth");d.set(height,forKey:"etpad.renderHeight");self?.applyResolution(width,height)
        }
    }
    private func applyResolution(_ width:Int,_ height:Int){
        if engineReady { command("set r_customwidth \(width);set r_customheight \(height);vid_restart") }
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
        if view.window?.windowScene != nil && view.bounds.width > 0 && view.bounds.height > 0 &&
            (traitCollection.userInterfaceIdiom == .pad || view.window?.windowScene?.interfaceOrientation.isLandscape == true) {
            startEngine(extra:extra)
        } else if attempt < 40 {
            DispatchQueue.main.asyncAfter(deadline:.now()+0.1) { [weak self] in self?.waitForLandscape(attempt:attempt+1,extra:extra) }
        } else { started=false;updateLauncher();alert("Rotate to Landscape","ETPad could not enter landscape. Rotate the iPad and try again.") }
    }
    private func startEngine(extra:[String]) {
        setenv("ETPAD_IPAD", traitCollection.userInterfaceIdiom == .pad ? "1" : "0", 1)
        view.backgroundColor = .clear
        let profile = gameHome.appendingPathComponent("legacy/profiles/ETPad")
        try? FileManager.default.createDirectory(at:profile,withIntermediateDirectories:true)
        try? "\"ETPad\"".write(to:profile.appendingPathComponent("profile.dat"),atomically:true,encoding:.utf8)
        try? "\"ETPad\"".write(to:profile.deletingLastPathComponent().appendingPathComponent("defaultprofile.dat"),atomically:true,encoding:.utf8)
        let d=UserDefaults.standard,stored=d.integer(forKey:"etpad.renderWidth"),storedHeight=d.integer(forKey:"etpad.renderHeight")
        let renderWidth=(stored>=320 && stored<=4096) ? stored:1280
        let renderHeight=(storedHeight>=240 && storedHeight<=4096) ? storedHeight:Int((CGFloat(renderWidth)*view.bounds.height/max(view.bounds.width,1)).rounded())
        var args = [Bundle.main.executablePath ?? "ETPad", "+set","fs_basepath",Bundle.main.bundleURL.appendingPathComponent("GameContent").path,
                    "+set","fs_homepath",gameHome.path,"+set","fs_game","legacy","+set","in_joystick","1","+set","in_joystickUseAnalog","1","+set","cl_wwwDownload","1","+set","rate","100000","+set","com_introplayed","1","+set","logfile","2",
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
        applyPadLook();applyMouse()
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
        heading("Touch");line("Left thumb: drag anywhere on the left to move. Push the stick well past its rim, forward, to sprint.");line("Right thumb: drag anywhere on the right to look. Hold FIRE and slide your thumb to aim while firing.");line("JUMP, CROUCH, PRONE, RELOAD, ALT (scope or alternate fire) and USE sit around FIRE. ‹ › change weapons.");line("SCORE (hold), MENU and CHAT (the quick-chat wheel) sit at the top left under the ••• menu. Settings › Touch Controls › Move Buttons lets you move any button.");gap()
        heading("Controller");line("Left stick moves, right stick looks. RT fires, LT is alternate fire or scope.");line("A jump · B crouch · X reload · Y grenade (then RT to throw) · LB use for doors, ladders and objectives · L3 sprint · R3 prone.");line("D-pad: right cycles every weapon, left swaps back to your last one, up picks your class tool (syringe, pliers, smoke) and down your class item (health, ammo, dynamite).");line("Hold RB for the quick-chat wheel: point the right stick and let go. View holds the scoreboard; Menu opens the game menu, where Team & Class is first.");line("In ET menus the left stick moves the cursor, A clicks and B goes back. Settings › Controller has look speed, invert look and every button.");gap()
        heading("Keyboard and mouse");line("ET's standard keys work: W A S D to move, Space jump, C crouch, X prone, Shift sprint, Q and E lean, R reload, F use, 1–0 weapons, Tab scores, Esc menu, ~ console.");line("During play the pointer locks for mouse look: left click fires, right click is alternate fire. In menus the pointer clicks normally.");gap()
        heading("Switching");line("Use any input at any time. Touch controls hide while a controller or keyboard is in use and return when you touch the screen. Turn this off in Options › Controls.")
        text.attributedText=body
        text.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(text)
        NSLayoutConstraint.activate([text.leadingAnchor.constraint(equalTo:view.leadingAnchor),text.trailingAnchor.constraint(equalTo:view.trailingAnchor),text.topAnchor.constraint(equalTo:view.topAnchor),text.bottomAnchor.constraint(equalTo:view.bottomAnchor)])
    }
    @objc private func done(){dismiss(animated:true)}
}
// The ••• capsule reports when its menu is on screen, so the host does not
// pull key-window focus back from the menu while it animates.
final class MenuButton:UIButton {
    var onShow:((Bool)->Void)?
    private(set) var showing=false
    override func contextMenuInteraction(_ interaction:UIContextMenuInteraction,willDisplayMenuFor configuration:UIContextMenuConfiguration,animator:UIContextMenuInteractionAnimating?) {
        super.contextMenuInteraction(interaction,willDisplayMenuFor:configuration,animator:animator);showing=true;onShow?(true)
    }
    override func contextMenuInteraction(_ interaction:UIContextMenuInteraction,willEndFor configuration:UIContextMenuConfiguration,animator:UIContextMenuInteractionAnimating?) {
        super.contextMenuInteraction(interaction,willEndFor:configuration,animator:animator)
        if let animator=animator { animator.addCompletion { [weak self] in self?.showing=false;self?.onShow?(false) } } else { showing=false;onShow?(false) }
    }
}
