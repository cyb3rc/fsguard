//
//  MainWindowController.swift
//  FileGuard
//
//  Created by Volodymyr Vashurkin on 8/21/19.
//  Copyright © 2019 Volodymyr Vashurkin. All rights reserved.
//

import Cocoa
import Security
import ServiceManagement


class MainWindowController: NSWindowController {
    private enum SegmentButtonIndex: Int {
        case add = 0
        case remove = 1
    }
    
    @IBOutlet private var arrayController: NSArrayController!
    @IBOutlet private var tableView: NSTableView!
    @IBOutlet private var segmentButtons: NSSegmentedControl!
    @IBOutlet private var checkboxEnable: NSButton!
    
    private var connectionClient = XPCPrivilegedHelperClient()
    private var fileGuard: FileGuard?
    
    
    static func createDefault() -> MainWindowController {
        return MainWindowController(windowNibName: "MainWindow")
    }
}

extension MainWindowController {
    @IBAction private func enableFileGuardClicked(_ sender: NSButton) {
        checkboxEnable.isEnabled = false
        
        if let fileGuard = fileGuard {
            let isEnabling = checkboxEnable.state == .on
            if isEnabling {
                fileGuard.start()
            } else {
                fileGuard.stop()
            }
            
            return
        }
        
        guard installHelper() else {
            disconnectWithError("Failed to install helper")
            return
        }
        
        connectionClient.start()
    }
    
    private func installHelper() -> Bool {
        guard let authorization = PrivilegedUtils.askAuthorization() else {
            return false
        }
        
        guard PrivilegedUtils.blessHelper(label: "com.alkenso.fileaccessfilterd", authorization: authorization) else {
            return false
        }
        
        return true
    }
    
    private func disconnectWithError(_ text: String) {
        showError(text)
        updateEnabledState(false)
    }
    
    private func showError(_ text: String) {
        let alert = NSAlert()
        alert.messageText = text
        alert.beginSheetModal(for: window!, completionHandler: nil)
    }
}

extension MainWindowController: XPCPrivilegedHelperClientObserver {
    func privilegedHelperDidConnect(helper: FAFPrivilegedHelper) {
        guard let kextLocation = Bundle.main.url(forResource: "FileSystemGuard", withExtension: "kext") else {
            return
        }
        
        helper.loadKEXT(kextLocation, identifier: "com.c0de1n.FileSystemGuard") { (error) in
            if error != 0 {
                self.disconnectWithError("Failed to load KEXT: \(error)")
                return
            }
            
            let fileGuard = FileGuard(fileAccessFilter: helper)
            fileGuard.observer = self
            self.setFileGuard(fileGuard)
            
            fileGuard.start()
        }
    }
    
    func privilegedHelperDidDisconnect() {
        disconnectWithError("XPC connection has been lost.")
    }
    
    private func setFileGuard(_ fileGuard: FileGuard?) {
        DispatchQueue.main.async {
            self.fileGuard = fileGuard
        }
    }
}

extension MainWindowController: IFileGuardStateObserver {
    func fileGuardDidStart() {
        updateEnabledState(true)
    }
    
    func fileGuardDidStop() {
        updateEnabledState(false)
    }
    
    func fileGuardDidHandleCriticalError(_ errorText: String) {
        disconnectWithError(errorText)
    }
    
    private func updateEnabledState(_ enabled: Bool) {
        DispatchQueue.main.async {
            self.checkboxEnable.isEnabled = true
            self.checkboxEnable.state = enabled ? .on : .off
        }
    }
}

extension MainWindowController: NSTableViewDelegate {
    override func windowDidLoad() {
        connectionClient.observer = self
        
        updateButtonsState()
        arrayController.objectClass = AccessRule.self
    }
    
    @IBAction private func segmentButtonClicked(_ sender: NSSegmentedControl) {
        guard let fileGuard = fileGuard else { return }
        
        switch SegmentButtonIndex(rawValue: sender.selectedSegment) {
        case .add?:
            selectPath { (url) in
                let rule = self.arrayController.newObject() as! AccessRule
                rule.path = url.path
                self.arrayController.addObject(rule)
                fileGuard.addRule(rule)
            }
        case .remove?:
            let rulesToRemove = arrayController.selectedObjects as! [AccessRule]
            arrayController.remove(contentsOf: rulesToRemove)
            rulesToRemove.forEach(fileGuard.removeRule)
        default:
            break;
        }
    }
    
    private func selectPath(_ completion: @escaping (URL) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.beginSheetModal(for: window!) { (response) in
            guard response == .OK, let url = openPanel.url else { return }
            completion(url)
        }
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        updateButtonsState()
    }
    
    func tableView(_ tableView: NSTableView, didRemove rowView: NSTableRowView, forRow row: Int) {
        updateButtonsState()
    }
    
    private func updateButtonsState() {
        segmentButtons.setEnabled(!arrayController.selectionIndexes.isEmpty, forSegment: SegmentButtonIndex.remove.rawValue)
    }
}

fileprivate enum PrivilegedUtils {
    static func askAuthorization() -> AuthorizationRef? {
        
        var rightItems = [AuthorizationItem(name: kSMRightBlessPrivilegedHelper, valueLength: 0, value: nil, flags: 0)]
        var rights = AuthorizationRights(count: UInt32(rightItems.count), items: &rightItems)

        var auth: AuthorizationRef?
        let status: OSStatus = AuthorizationCreate(&rights, nil, [.extendRights, .interactionAllowed, .preAuthorize], &auth)
        guard status == errAuthorizationSuccess else {
            NSLog("[SMJBS]: Authorization failed with status code \(status)")
            return nil
        }
        
        return auth
    }
    
    static func blessHelper(label: String, authorization: AuthorizationRef) -> Bool {
        var error: Unmanaged<CFError>?
        let blessStatus = SMJobBless(kSMDomainSystemLaunchd, label as CFString, authorization, &error)
        
        if !blessStatus {
            NSLog("[SMJBS]: Helper bless failed with error \(error!.takeUnretainedValue())")
        }
        
        return blessStatus
    }
}
