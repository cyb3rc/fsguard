//
//  XPCPrivilegedHelperClient.swift
//  FileGuard
//
//  Created by Alk on 9/13/19.
//  Copyright © 2019 Volodymyr Vashurkin. All rights reserved.
//

import Foundation

protocol XPCPrivilegedHelperClientObserver: class {
    func privilegedHelperDidConnect(helper: FAFPrivilegedHelper)
    func privilegedHelperDidDisconnect()
}

class XPCPrivilegedHelperClient {
    weak var observer: XPCPrivilegedHelperClientObserver?
    
    private var connection: NSXPCConnection?
    private let connectionQueue = DispatchQueue(label: "", target: DispatchQueue.global())
    
    func start() {
        let newConnection = NSXPCConnection.helperConnection()
        newConnection.invalidationHandler = { [weak self, weak newConnection] in
            self?.observer?.privilegedHelperDidDisconnect()
            newConnection?.invalidationHandler = nil
        }
        
        newConnection.resume()
        
        handleConnect(newConnection)
    }
    
    func stop() {
        handleDisconnect()
    }
    
    private func handleConnect(_ newConnection: NSXPCConnection) {
        let proxy = newConnection.remoteObjectProxyWithErrorHandler { [weak self, weak newConnection] (error) in
            self?.observer?.privilegedHelperDidDisconnect()
            newConnection?.invalidationHandler = nil
            } as! FAFPrivilegedHelper
        
        connection = newConnection
        observer?.privilegedHelperDidConnect(helper: proxy)
    }
    
    private func handleDisconnect() {
        connection?.invalidationHandler = nil
        connection = nil
        observer?.privilegedHelperDidDisconnect()
    }
}


fileprivate extension NSXPCConnection {
    static func helperConnection() -> NSXPCConnection {
        let connection = NSXPCConnection(machServiceName: FAFFileAccessServiceMachName, options: .privileged)
        connection.remoteObjectInterface = FAFCreateXPCFileAccessFilterInterface()
        
        return connection
    }
}
