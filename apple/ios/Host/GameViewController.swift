// ETPad native host; window ownership follows UTP GameViewController.swift at
// a9313911efcf044fd66f9a679af53e55e255a8b4, host +1 / render-only SDL window.
// GPL-3.0-or-later; see COPYING.txt.
import UIKit
import GameController

final class GameViewController: UIViewController {
    private var started = false
    private var displayLink: CADisplayLink?
    private let status = UILabel()
    private let menu = UIButton(type: .system)
    private var observers: [NSObjectProtocol] = []
    private var gameHome: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("ETPad", isDirectory: true) }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var canBecomeFirstResponder: Bool { true }
    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = .black
        status.text = "ETPad\nChecking game data…"
        status.textColor = .white; status.numberOfLines = 0; status.textAlignment = .center
        status.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(status)
        NSLayoutConstraint.activate([status.centerXAnchor.constraint(equalTo: view.centerXAnchor),status.centerYAnchor.constraint(equalTo: view.centerYAnchor)])
        menu.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        menu.tintColor = .white; menu.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        menu.layer.cornerRadius = 22; menu.showsMenuAsPrimaryAction = true
        menu.accessibilityLabel = "ETPad menu"
        view.addSubview(menu)
        menu.menu = UIMenu(title: "ETPad", children: [UIAction(title: "Game Menu", image: UIImage(systemName:"pause")) { [weak self] _ in self?.command("togglemenu") }])
        for name in [UIWindow.didBecomeKeyNotification, UIApplication.didBecomeActiveNotification] {
            observers.append(NotificationCenter.default.addObserver(forName:name,object:nil,queue:.main) { [weak self] _ in self?.restoreHost() })
        }
        observers.append(NotificationCenter.default.addObserver(forName:UIApplication.willResignActiveNotification,object:nil,queue:.main) { [weak self] _ in
            if self?.started == true { etpad_release_inputs(); self?.displayLink?.isPaused = true }
        })
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        restoreHost()
        guard !started else { return }
        let paks = ["pak0.pk3","pak1.pk3","pak2.pk3"].map { gameHome.appendingPathComponent("etmain/\($0)") }
        guard paks.allSatisfy({ FileManager.default.fileExists(atPath:$0.path) }) else {
            status.text = "ETPad\nGame data is missing.\nDownload the free original data or import your pak files."
            return
        }
        started = true
        status.isHidden = true
        waitForLandscape(attempt:0)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        menu.frame = CGRect(x:view.bounds.width-view.safeAreaInsets.right-64,y:view.safeAreaInsets.top+12,width:48,height:44)
        restoreHost()
    }
    func restoreHost() {
        guard let host = view.window, let scene = host.windowScene else { return }
        if started { host.isOpaque=false;host.backgroundColor = .clear;view.isOpaque=false }
        if let pointer=etpad_render_window() {
            let engine=Unmanaged<UIWindow>.fromOpaque(pointer).takeUnretainedValue()
            if engine.windowScene !== scene {
                engine.windowScene=scene
                scene.requestGeometryUpdate(.iOS(interfaceOrientations:.landscape)) { NSLog("ETPad SDL landscape: %@",$0.localizedDescription) }
            }
        }
        for window in scene.windows where window !== host {
            window.windowLevel = .normal
            window.frame = host.bounds
            window.autoresizingMask = [.flexibleWidth,.flexibleHeight]
            window.isUserInteractionEnabled = false
        }
        host.windowLevel = UIWindow.Level(rawValue:UIWindow.Level.normal.rawValue+1)
        if !host.isKeyWindow { host.makeKeyAndVisible() }
        if UIApplication.shared.applicationState == .active { displayLink?.isPaused = false }
        view.bringSubviewToFront(menu)
        becomeFirstResponder()
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
        let renderHeight=Int((1280*view.bounds.height/view.bounds.width).rounded())
        var args = [Bundle.main.executablePath ?? "ETPad", "+set","fs_basepath",Bundle.main.bundleURL.appendingPathComponent("GameContent").path,
                    "+set","fs_homepath",gameHome.path,"+set","fs_game","legacy","+set","com_introplayed","1","+set","logfile","2",
                    "+set","r_fullscreen","1","+set","r_mode","-1","+set","r_customwidth","1280","+set","r_customheight",String(renderHeight),
                    "+set","r_allowSoftwareGL","1","+set","name","ETPadPlayer"]
        if ProcessInfo.processInfo.arguments.contains("--etpad-oasis") { args += ["+set","sv_pure","0","+set","g_gametype","2","+devmap","oasis"] }
        let pointers = args.map { strdup($0) }
        defer { pointers.forEach { free($0) } }
        var mutable = pointers + [nil]
        mutable.withUnsafeMutableBufferPointer { _ = etpad_engine_main(Int32(args.count),$0.baseAddress) }
        restoreHost()
        displayLink = CADisplayLink(target:self,selector:#selector(frame))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum:30,maximum:60,preferred:60)
        displayLink?.add(to:.main,forMode:.common)
    }
    @objc private func frame() { etpad_frame() }
    private func command(_ value:String) { if started { etpad_command(value) } }
}
