//
//  FileGuard.swift
//  FileGuard
//
//  Created by Alkenso on 9/13/19.
//  Copyright © 2019 Volodymyr Vashurkin. All rights reserved.
//

import Foundation

@objcMembers
class AccessRule: NSObject {
    var path: String = ""
    var policy: FAFResolutionType = .readwrite
}

protocol IFileGuardStateObserver {
    func fileGuardDidStart()
    func fileGuardDidStop()
    func fileGuardDidHandleError(_ errorText: String)
}

class FileGuard {
    private let ruleQueue = DispatchQueue(label: "", attributes: .concurrent,target: DispatchQueue.global())
    private var rules: [AccessRule] = []
    private var connection: NSXPCConnection?
    
    private let observer: IFileGuardStateObserver
    
    
    init(observer: IFileGuardStateObserver) {
        self.observer = observer
    }
    
    func addRule(_ rule: AccessRule) {
        ruleQueue.async(flags: .barrier) { self.rules.append(rule) }
    }
    
    func removeRule(_ rule: AccessRule) {
        ruleQueue.async(flags: .barrier) { self.rules.removeAll(where: { $0 === rule }) }
    }
    
    func start() {
        let newConnection = NSXPCConnection.helperConnection()
        
        newConnection.invalidationHandler = { [weak self] in
            self?.observer.fileGuardDidHandleError("Service has been invalidated.")
        }
        
        newConnection.resume()
        
        let proxy = newConnection.remoteObjectProxyWithErrorHandler { [weak self] (error) in
            self?.observer.fileGuardDidHandleError((error as NSError).localizedDescription)
            } as! FAFFileAccessFilter
        
        proxy.register(self) { (success) in
            if success {
                self.observer.fileGuardDidStart()
            } else {
                self.observer.fileGuardDidHandleError("Failed to start monitoring.")
            }
        }
        
        self.connection = newConnection
    }
    
    func stop() {
        guard let connection = connection else { return }
        
        let proxy = connection.remoteObjectProxyWithErrorHandler { [weak self] (error) in
            self?.observer.fileGuardDidHandleError((error as NSError).localizedDescription)
            } as! FAFFileAccessFilter
        
        proxy.register(nil) { (success) in
            if success {
                self.observer.fileGuardDidStop()
            } else {
                self.observer.fileGuardDidHandleError("Failed to stop monitoring.")
            }
        }
    }
}

extension FileGuard: FAFResolutionDelegate {
    func resolveFileAccessRequest(_ request: FAFRequest, withResolutionHandler handler: @escaping FAFResolutionHandler) {
        let rule = findRule(for: request)
        
        DispatchQueue.global().async {
            handler(rule?.policy ?? .readwrite)
        }
    }
    
    private func findRule(for request: FAFRequest) -> AccessRule? {
        return ruleQueue.sync { self.rules.first { request.file.path.starts(with: $0.path) } }
    }
}


fileprivate extension NSXPCConnection {
    static func helperConnection() -> NSXPCConnection {
        let connection = NSXPCConnection(machServiceName: FAFFileAccessServiceMachName, options: .privileged)
        connection.remoteObjectInterface = FAFCreateXPCFileAccessFilterInterface()
        
        return connection
    }
}
