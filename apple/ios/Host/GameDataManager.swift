// Official free release and owned-pak import. GPL-3.0-or-later.
// Acquisition/UI structure informed by UTP UT99GameDataAcquisition.swift;
// a9313911efcf044fd66f9a679af53e55e255a8b4. Extraction is ETPad-specific.
import Foundation
import CryptoKit

final class GameDataManager: NSObject, URLSessionDownloadDelegate {
    static let hashes = [
        "pak0.pk3":"712966b20e06523fe81419516500e499c86b2b4fec823856ddbd333fcb3d26e5",
        "pak1.pk3":"5610fd749024405b4425a7ce6397e58187b941d22092ef11d4844b427df53e5d",
        "pak2.pk3":"a48ab749a1a12ab4d9137286b1f23d642c29da59845b2bafc8f64e052cf06f3e"]
    static let archiveHash = "2a8fef8e8558efffcad658bb9a8b12df8740418b3514142350eba3b7641eb3e0"
    let home = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("ETPad",isDirectory:true)
    var onProgress: ((String)->Void)?
    var onComplete: ((Result<Void,Error>)->Void)?
    private(set) var busy = false
    private var task: URLSessionDownloadTask?
    private lazy var session = URLSession(configuration:.default,delegate:self,delegateQueue:nil)
    private func report(_ value:String) { DispatchQueue.main.async { self.onProgress?(value) } }
    private func finish(_ result:Result<Void,Error>) { DispatchQueue.main.async { self.busy=false;self.task=nil;self.onComplete?(result) } }
    private func failure(_ text:String)->Error { NSError(domain:"ETPad game data",code:1,userInfo:[NSLocalizedDescriptionKey:text]) }
    private func digest(_ url:URL)throws->String {
        let file=try FileHandle(forReadingFrom:url);defer { try? file.close() }
        var hash=SHA256()
        while let block=try file.read(upToCount:1024*1024), !block.isEmpty { hash.update(data:block) }
        return hash.finalize().map { String(format:"%02x",$0) }.joined()
    }
    private func verify(_ directory:URL)throws {
        for (name,hash) in Self.hashes {
            guard try digest(directory.appendingPathComponent(name)) == hash else { throw failure("SHA-256 check failed for \(name). Existing game data was preserved.") }
        }
    }
    func checkInstalled(_ completion:@escaping(Bool)->Void) {
        DispatchQueue.global(qos:.userInitiated).async {
            var valid=false
            do { try self.recover();try self.verify(self.home.appendingPathComponent("etmain"));valid=true } catch { valid=false }
            DispatchQueue.main.async { completion(valid) }
        }
    }
    private func staging()throws->URL {
        let base=FileManager.default.urls(for:.cachesDirectory,in:.userDomainMask)[0].appendingPathComponent("ETPadData-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:base,withIntermediateDirectories:true);return base
    }
    private func recover()throws {
        let fm=FileManager.default, destination=home.appendingPathComponent("etmain"), backup=home.appendingPathComponent("etmain-backup")
        guard fm.fileExists(atPath:backup.path) else { return }
        if (try? verify(destination)) != nil { try fm.removeItem(at:backup) }
        else {
            if fm.fileExists(atPath:destination.path) { try fm.removeItem(at:destination) }
            try fm.moveItem(at:backup,to:destination)
        }
    }
    private func install(_ stage:URL)throws {
        report("Checking original game data…")
        try verify(stage)
        try recover()
        let fm=FileManager.default, destination=home.appendingPathComponent("etmain"),backup=home.appendingPathComponent("etmain-backup"),incoming=home.appendingPathComponent("etmain-incoming")
        try fm.createDirectory(at:home,withIntermediateDirectories:true)
        if fm.fileExists(atPath:incoming.path) { try fm.removeItem(at:incoming) }
        try fm.createDirectory(at:incoming,withIntermediateDirectories:true)
        // Preserve any unrelated user files in etmain while replacing originals.
        if fm.fileExists(atPath:destination.path) {
            for file in try fm.contentsOfDirectory(at:destination,includingPropertiesForKeys:nil) where Self.hashes[file.lastPathComponent] == nil {
                try fm.copyItem(at:file,to:incoming.appendingPathComponent(file.lastPathComponent))
            }
        }
        for name in Self.hashes.keys { try fm.moveItem(at:stage.appendingPathComponent(name),to:incoming.appendingPathComponent(name)) }
        do {
            if fm.fileExists(atPath:destination.path) { try fm.moveItem(at:destination,to:backup) }
            try fm.moveItem(at:incoming,to:destination)
        } catch { try? recover();throw error }
        // Backup lives in Documents until commit completes, so a process kill or
        // cache eviction between the two renames can recover on the next launch.
        if fm.fileExists(atPath:backup.path) { try fm.removeItem(at:backup) }
    }
    func importPaks(_ urls:[URL]) {
        guard !busy else { return };busy=true
        report("Importing original pak files…")
        DispatchQueue.global(qos:.userInitiated).async {
            do {
                let names=urls.map(\.lastPathComponent)
                guard Set(names)==Set(Self.hashes.keys), names.count==3 else { throw self.failure("Select pak0.pk3, pak1.pk3 and pak2.pk3 together.") }
                let stage=try self.staging();defer { try? FileManager.default.removeItem(at:stage) }
                for url in urls {
                    let access=url.startAccessingSecurityScopedResource();defer { if access { url.stopAccessingSecurityScopedResource() } }
                    try FileManager.default.copyItem(at:url,to:stage.appendingPathComponent(url.lastPathComponent))
                }
                try self.install(stage);self.finish(.success(()))
            } catch { self.finish(.failure(error)) }
        }
    }
    func download() {
        guard !busy else { return };busy=true
        report("Downloading the free original game data…")
        task=session.downloadTask(with:URL(string:"https://cdn.splashdamage.com/downloads/games/wet/et260b.x86_full.zip")!)
        task?.resume()
    }
    func urlSession(_ session:URLSession,downloadTask:URLSessionDownloadTask,didWriteData bytesWritten:Int64,totalBytesWritten:Int64,totalBytesExpectedToWrite:Int64) {
        let total=totalBytesExpectedToWrite>0 ? " / \(totalBytesExpectedToWrite/1048576) MB" : " MB"
        report("Downloading free game data: \(totalBytesWritten/1048576)\(total)")
    }
    func urlSession(_ session:URLSession,downloadTask:URLSessionDownloadTask,didFinishDownloadingTo location:URL) {
        do {
            guard let response=downloadTask.response as? HTTPURLResponse, response.statusCode==200 else { throw failure("The official download did not return a complete file. Try again later or import your pak files.") }
            report("Checking official download…")
            guard try digest(location)==Self.archiveHash else { throw failure("The official download failed its SHA-256 check. No data was installed.") }
            let stage=try staging();defer { try? FileManager.default.removeItem(at:stage) }
            report("Extracting original pak files…")
            guard etpad_extract_official(location.path,stage.path)==0 else { throw failure("The official archive could not be extracted. No installer code was executed.") }
            try install(stage);finish(.success(()))
        } catch { finish(.failure(error)) }
    }
    func urlSession(_ session:URLSession,task:URLSessionTask,didCompleteWithError error:Error?) { if let error=error { finish(.failure(error)) } }
    func removeInstalled()throws {
        try recover()
        for name in Self.hashes.keys {
            let file=home.appendingPathComponent("etmain/\(name)")
            if FileManager.default.fileExists(atPath:file.path) { try FileManager.default.removeItem(at:file) }
        }
    }
}
