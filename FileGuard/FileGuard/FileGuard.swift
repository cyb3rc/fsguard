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

protocol IFileGuardStateObserver: class {
    func fileGuardDidStart()
    func fileGuardDidStop()
    func fileGuardDidHandleCriticalError(_ errorText: String)
}

class FileGuard {
    private let ruleQueue = DispatchQueue(label: "", attributes: .concurrent,target: DispatchQueue.global())
    private var rules: [AccessRule] = []
    
    private let fileAccessFilter: FAFFileAccessFilter
    
    
    weak var observer: IFileGuardStateObserver?
    
    init(fileAccessFilter: FAFFileAccessFilter) {
        self.fileAccessFilter = fileAccessFilter
    }
    
    func addRule(_ rule: AccessRule) {
        ruleQueue.async(flags: .barrier) { self.rules.append(rule) }
    }
    
    func removeRule(_ rule: AccessRule) {
        ruleQueue.async(flags: .barrier) { self.rules.removeAll(where: { $0 === rule }) }
    }
    
    func start() {
        fileAccessFilter.register(self) { (success) in
            if success {
                self.observer?.fileGuardDidStart()
            } else {
                self.observer?.fileGuardDidHandleCriticalError("Failed to start monitoring.")
            }
        }
    }
    
    func stop() {
        fileAccessFilter.register(nil) { (success) in
            if success {
                self.observer?.fileGuardDidStart()
            } else {
                self.observer?.fileGuardDidHandleCriticalError("Failed to stop monitoring.")
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



