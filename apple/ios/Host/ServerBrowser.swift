// Native "Who's Playing Now" list for ET: Legacy servers. GPL-3.0-or-later.
// Queries the ET masters over UDP (getservers 84), then asks each server for
// getinfo. ETPad joins only servers running the built-in Legacy mod.
import UIKit
import Darwin

struct ETServer {
    let address:String
    var name:String,map:String
    var humans:Int,clients:Int,maxClients:Int
    var ping:Int,password:Bool,version:String
    var bots:Int { max(0,clients-humans) }
}

final class ETServerQuery {
    static let masters=["master.etlegacy.com","etmaster.idsoftware.com"]
    var onUpdate:(([ETServer])->Void)?
    var onFinish:(()->Void)?
    private let queue=DispatchQueue(label:"etpad.servers")
    private var socket:Int32 = -1
    private var source:DispatchSourceRead?
    private var asked=Set<String>(),sentAt:[String:CFAbsoluteTime]=[:]
    private var pending:[sockaddr_in]=[],results:[String:ETServer]=[:]
    private var lastPublish:CFAbsoluteTime=0,stopped=false
    static func clean(_ text:String)->String {
        var out="",skip=false
        for ch in text { if skip { skip=false;continue };if ch=="^" { skip=true;continue };out.append(ch) }
        return out.trimmingCharacters(in:.whitespaces)
    }
    func start() {
        queue.async { [self] in
            socket=Darwin.socket(AF_INET,SOCK_DGRAM,IPPROTO_UDP)
            guard socket>=0 else { finish();return }
            _=fcntl(socket,F_SETFL,fcntl(socket,F_GETFL)|O_NONBLOCK)
            let read=DispatchSource.makeReadSource(fileDescriptor:socket,queue:queue)
            read.setEventHandler { [weak self] in self?.receive() }
            read.setCancelHandler { [fd=socket] in close(fd) }
            source=read;read.resume()
            for host in Self.masters { if let address=resolve(host,port:27950) { send("getservers 84 empty full",to:address) } }
            // Probe servers in small batches as master packets arrive.
            for step in 1...40 { queue.asyncAfter(deadline:.now()+0.1*Double(step)) { [weak self] in self?.probeBatch() } }
            queue.asyncAfter(deadline:.now()+5.5) { [weak self] in self?.finish() }
        }
    }
    func stop() { queue.async { [self] in stopped=true;source?.cancel();source=nil } }
    private func resolve(_ host:String,port:UInt16)->sockaddr_in? {
        var hints=addrinfo(ai_flags:0,ai_family:AF_INET,ai_socktype:SOCK_DGRAM,ai_protocol:0,ai_addrlen:0,ai_canonname:nil,ai_addr:nil,ai_next:nil)
        var list:UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host,String(port),&hints,&list)==0,let first=list else { return nil }
        defer { freeaddrinfo(list) }
        return first.pointee.ai_addr.withMemoryRebound(to:sockaddr_in.self,capacity:1) { $0.pointee }
    }
    private func key(_ a:sockaddr_in)->String {
        var addr=a.sin_addr;var buffer=[CChar](repeating:0,count:Int(INET_ADDRSTRLEN))
        inet_ntop(AF_INET,&addr,&buffer,socklen_t(INET_ADDRSTRLEN))
        return String(cString:buffer)+":"+String(UInt16(bigEndian:a.sin_port))
    }
    private func send(_ text:String,to address:sockaddr_in) {
        var packet:[UInt8]=[0xff,0xff,0xff,0xff]+Array(text.utf8);var target=address
        _=withUnsafePointer(to:&target) { $0.withMemoryRebound(to:sockaddr.self,capacity:1) { sendto(socket,&packet,packet.count,0,$0,socklen_t(MemoryLayout<sockaddr_in>.size)) } }
    }
    private func probeBatch() {
        guard !stopped,socket>=0 else { return }
        for address in pending.prefix(60) { sentAt[key(address)]=CFAbsoluteTimeGetCurrent();send("getinfo etpad",to:address) }
        pending.removeFirst(min(60,pending.count))
    }
    private func receive() {
        var buffer=[UInt8](repeating:0,count:65536)
        while true {
            var from=sockaddr_in();var length=socklen_t(MemoryLayout<sockaddr_in>.size)
            let count=withUnsafeMutablePointer(to:&from) { $0.withMemoryRebound(to:sockaddr.self,capacity:1) { recvfrom(socket,&buffer,buffer.count,0,$0,&length) } }
            guard count>4 else { return }
            let data=Array(buffer[4..<count])
            if data.starts(with:Array("getserversResponse".utf8)) { parseMaster(data) }
            else if data.starts(with:Array("infoResponse".utf8)) { parseInfo(data,from:from) }
        }
    }
    private func parseMaster(_ data:[UInt8]) {
        guard var i=data.firstIndex(of:0x5c) else { return }
        while i+6<data.count,data[i]==0x5c {
            if data[i+1]==0x45 && data[i+2]==0x4f && data[i+3]==0x54 { break } // "EOT"
            var address=sockaddr_in();address.sin_family=sa_family_t(AF_INET);address.sin_len=UInt8(MemoryLayout<sockaddr_in>.size)
            address.sin_addr.s_addr=UInt32(data[i+1])|UInt32(data[i+2])<<8|UInt32(data[i+3])<<16|UInt32(data[i+4])<<24
            address.sin_port=(UInt16(data[i+5])<<8|UInt16(data[i+6])).bigEndian
            let name=key(address)
            if address.sin_port != 0 && asked.insert(name).inserted { pending.append(address) }
            i+=7
        }
    }
    private func parseInfo(_ data:[UInt8],from:sockaddr_in) {
        guard let newline=data.firstIndex(of:0x0a) else { return }
        let text=String(decoding:data[(newline+1)...],as:UTF8.self)
        let parts=text.split(separator:"\\",omittingEmptySubsequences:false).dropFirst().map(String.init)
        var info:[String:String]=[:]
        var index=0;while index+1<parts.count { info[parts[index]]=parts[index+1];index+=2 }
        guard info["game"]?.lowercased()=="legacy" else { return }
        let address=key(from)
        let ping=sentAt[address].map { Int((CFAbsoluteTimeGetCurrent()-$0)*1000) } ?? 999
        let clients=Int(info["clients"] ?? "") ?? 0
        let version=(info["version"] ?? "").components(separatedBy:" ").first(where:{ $0.hasPrefix("v") }) ?? ""
        results[address]=ETServer(address:address,name:Self.clean(info["hostname"] ?? address),map:info["mapname"] ?? "?",
            humans:Int(info["humans"] ?? "") ?? clients,clients:clients,maxClients:Int(info["sv_maxclients"] ?? "") ?? 0,
            ping:ping,password:info["needpass"]=="1",version:version)
        let now=CFAbsoluteTimeGetCurrent()
        if now-lastPublish>0.35 { lastPublish=now;publish() }
    }
    private func publish() {
        let list=results.values.sorted { ($0.humans,$0.clients,-$0.ping) > ($1.humans,$1.clients,-$1.ping) }
        DispatchQueue.main.async { [weak self] in self?.onUpdate?(list) }
    }
    private func finish() {
        guard !stopped else { return };publish();stop()
        DispatchQueue.main.async { [weak self] in self?.onFinish?() }
    }
}

final class ServerBrowserViewController: UITableViewController {
    var onJoin:((_ address:String,_ password:String?)->Void)?
    private var servers:[ETServer]=[],favorites:[String]=[]
    private var query:ETServerQuery?
    private var searching=false
    private let spinner=UIActivityIndicatorView(style:.medium)
    private var playing:[ETServer] { servers.filter { $0.humans>0 } }
    private var others:[ETServer] { servers.filter { $0.humans==0 } }
    init(){super.init(style:.insetGrouped);title="Who's Playing Now"}
    required init?(coder:NSCoder){fatalError("init(coder:)")}
    override var supportedInterfaceOrientations:UIInterfaceOrientationMask { .landscape }
    override func viewDidLoad() {
        super.viewDidLoad();overrideUserInterfaceStyle = .dark
        tableView.backgroundColor=ETPadTheme.ink
        favorites=UserDefaults.standard.stringArray(forKey:"etpad.favorites") ?? []
        navigationItem.leftBarButtonItem=UIBarButtonItem(title:"Join Address…",style:.plain,target:self,action:#selector(joinAddress))
        navigationItem.rightBarButtonItems=[UIBarButtonItem(barButtonSystemItem:.done,target:self,action:#selector(done)),
            UIBarButtonItem(barButtonSystemItem:.refresh,target:self,action:#selector(refresh)),UIBarButtonItem(customView:spinner)]
        refresh()
    }
    override func viewWillDisappear(_ animated:Bool){super.viewWillDisappear(animated);query?.stop()}
    @objc private func done(){dismiss(animated:true)}
    @objc private func refresh() {
        query?.stop();searching=true;spinner.startAnimating();tableView.reloadData()
        let q=ETServerQuery();query=q
        q.onUpdate = { [weak self] list in self?.servers=list;self?.tableView.reloadData() }
        q.onFinish = { [weak self] in self?.searching=false;self?.spinner.stopAnimating();self?.tableView.reloadData() }
        q.start()
    }
    @objc private func joinAddress() {
        let alert=UIAlertController(title:"Join by Address",message:"Enter a server's hostname or IP and port.",preferredStyle:.alert)
        alert.addTextField { $0.placeholder="host:27960";$0.keyboardType = .URL;$0.autocorrectionType = .no;$0.autocapitalizationType = .none }
        alert.addAction(UIAlertAction(title:"Cancel",style:.cancel))
        alert.addAction(UIAlertAction(title:"Join",style:.default) { [weak self] _ in
            let address=(alert.textFields?.first?.text ?? "").trimmingCharacters(in:.whitespaces)
            guard Self.validAddress(address) else { return }
            self?.join(nil,address)
        })
        present(alert,animated:true)
    }
    static func validAddress(_ address:String)->Bool {
        address.range(of:"^[A-Za-z0-9.-]+(:[0-9]{1,5})?$",options:.regularExpression) != nil
    }
    private func join(_ server:ETServer?,_ address:String) {
        let go = { [weak self] (password:String?) in self?.dismiss(animated:true) { self?.onJoin?(address,password) } }
        guard server?.password == true else { go(nil);return }
        let alert=UIAlertController(title:"Password Required",message:server?.name,preferredStyle:.alert)
        alert.addTextField { $0.isSecureTextEntry=true;$0.placeholder="Server password" }
        alert.addAction(UIAlertAction(title:"Cancel",style:.cancel))
        alert.addAction(UIAlertAction(title:"Join",style:.default) { _ in
            let password=(alert.textFields?.first?.text ?? "").filter { $0 != "\"" && $0 != ";" }
            go(password)
        })
        present(alert,animated:true)
    }
    private enum Section { case favorites,playing,others }
    private var sections:[Section] { (favorites.isEmpty ? []:[.favorites])+[.playing,.others] }
    override func numberOfSections(in tableView:UITableView)->Int { sections.count }
    override func tableView(_ tableView:UITableView,numberOfRowsInSection section:Int)->Int {
        switch sections[section] {
        case .favorites:return favorites.count
        case .playing:return max(1,playing.count)
        case .others:return others.count
        }
    }
    override func tableView(_ tableView:UITableView,titleForHeaderInSection section:Int)->String? {
        switch sections[section] {
        case .favorites:return "Favorites"
        case .playing:return "Playing now"
        case .others:return others.isEmpty ? nil:"Bots only or empty"
        }
    }
    override func tableView(_ tableView:UITableView,titleForFooterInSection section:Int)->String? {
        sections[section] == .playing ? "ET: Legacy servers from the official master lists. ETPad joins servers that run the built-in Legacy mod; maps download on first join." : nil
    }
    override func tableView(_ tableView:UITableView,cellForRowAt indexPath:IndexPath)->UITableViewCell {
        let cell=UITableViewCell(style:.subtitle,reuseIdentifier:nil)
        cell.backgroundColor=UIColor(white:0.12,alpha:1)
        var content=cell.defaultContentConfiguration()
        content.secondaryTextProperties.color = .secondaryLabel
        switch sections[indexPath.section] {
        case .favorites:
            let address=favorites[indexPath.row]
            let live=servers.first { $0.address==address }
            content.text=live?.name ?? address
            content.secondaryText=live.map(detail) ?? address
            content.image=UIImage(systemName:"star.fill");content.imageProperties.tintColor=ETPadTheme.brass
        case .playing where playing.isEmpty:
            content.text=searching ? "Looking for servers…" : "No one is playing right now"
            content.secondaryText=searching ? "Asking the ET master servers" : "Try a bots-only server below or Practice with Bots."
            cell.selectionStyle = .none
        case .playing,.others:
            let server=(sections[indexPath.section] == .playing ? playing:others)[indexPath.row]
            content.text=server.name;content.secondaryText=detail(server)
            content.image=UIImage(systemName:server.password ? "lock.fill":(server.humans>0 ? "person.3.fill":"cpu"))
            content.imageProperties.tintColor=server.humans>0 ? ETPadTheme.brass:.secondaryLabel
        }
        cell.contentConfiguration=content
        return cell
    }
    private func detail(_ s:ETServer)->String {
        var parts=["\(s.map)","\(s.humans) playing"+(s.bots>0 ? " + \(s.bots) bots":"")+" / \(s.maxClients)","\(s.ping) ms"]
        if !s.version.isEmpty { parts.append(s.version) }
        return parts.joined(separator:" · ")
    }
    override func tableView(_ tableView:UITableView,didSelectRowAt indexPath:IndexPath) {
        tableView.deselectRow(at:indexPath,animated:true)
        switch sections[indexPath.section] {
        case .favorites:let address=favorites[indexPath.row];join(servers.first { $0.address==address },address)
        case .playing where playing.isEmpty:return
        case .playing:join(playing[indexPath.row],playing[indexPath.row].address)
        case .others:join(others[indexPath.row],others[indexPath.row].address)
        }
    }
    override func tableView(_ tableView:UITableView,trailingSwipeActionsConfigurationForRowAt indexPath:IndexPath)->UISwipeActionsConfiguration? {
        let address:String
        switch sections[indexPath.section] {
        case .favorites:address=favorites[indexPath.row]
        case .playing where playing.isEmpty:return nil
        case .playing:address=playing[indexPath.row].address
        case .others:address=others[indexPath.row].address
        }
        let isFavorite=favorites.contains(address)
        let action=UIContextualAction(style:isFavorite ? .destructive:.normal,title:isFavorite ? "Unfavorite":"Favorite") { [weak self] _,_,complete in
            guard let self=self else { return }
            if isFavorite { self.favorites.removeAll { $0==address } } else { self.favorites.append(address) }
            UserDefaults.standard.set(self.favorites,forKey:"etpad.favorites");tableView.reloadData();complete(true)
        }
        action.backgroundColor=isFavorite ? ETPadTheme.oxblood:ETPadTheme.olive
        return UISwipeActionsConfiguration(actions:[action])
    }
    // Controller: up/down selects a server, A joins, Y refreshes, B closes.
    func controller(move:Int,activate:Bool,back:Bool,refresh refreshNow:Bool) {
        if back { done();return }
        if refreshNow { refresh();return }
        var rows:[IndexPath]=[]
        for section in 0..<tableView.numberOfSections { for row in 0..<tableView.numberOfRows(inSection:section) { rows.append(IndexPath(row:row,section:section)) } }
        guard !rows.isEmpty else { return }
        let current=tableView.indexPathForSelectedRow.flatMap { rows.firstIndex(of:$0) }
        if move != 0 || current == nil {
            let next=rows[max(0,min(rows.count-1,(current ?? -1)+max(move,current == nil ? 1:move)))]
            tableView.selectRow(at:next,animated:true,scrollPosition:.middle)
        }
        if activate,let selected=tableView.indexPathForSelectedRow { tableView(tableView,didSelectRowAt:selected) }
    }
}
