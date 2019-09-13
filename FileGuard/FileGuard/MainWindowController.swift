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
    
    lazy private var fileGuard = FileGuard(observer: self)
    
    
    static func createDefault() -> MainWindowController {
        return MainWindowController(windowNibName: "MainWindow")
    }
}

extension MainWindowController {
    @IBAction private func enableFileGuardClicked(_ sender: NSButton) {
        checkboxEnable.isEnabled = false
        let isEnabling = checkboxEnable.state == .on
        
        guard isEnabling else {
            fileGuard.stop()
            return
        }
        
        guard installHelper() else {
            updateEnabledState(false)
            return
        }
        
        fileGuard.start()
    }
    
    private func installHelper() -> Bool {
        guard let authorization = PrivilegedUtils.askAuthorization() else {
            showError("Failed to authorize")
            return false
        }
        
        guard PrivilegedUtils.blessHelper(label: "com.alkenso.fileaccessfilterd", authorization: authorization) else {
            showError("Failed to install helper")
            return false
        }
        
        return true
    }
    
    private func showError(_ text: String) {
        let alert = NSAlert()
        alert.messageText = text
        alert.beginSheetModal(for: window!, completionHandler: nil)
    }
}

extension MainWindowController: NSTableViewDelegate {
    override func windowDidLoad() {
        updateButtonsState()
        arrayController.objectClass = AccessRule.self
    }
    
    @IBAction private func segmentButtonClicked(_ sender: NSSegmentedControl) {
        switch SegmentButtonIndex(rawValue: sender.selectedSegment) {
        case .add?:
            selectPath { (url) in
                let rule = self.arrayController.newObject() as! AccessRule
                rule.path = url.path
                self.arrayController.addObject(rule)
                self.fileGuard.addRule(rule)
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

extension MainWindowController: IFileGuardStateObserver {
    func fileGuardDidStart() {
        updateEnabledState(true)
    }
    
    func fileGuardDidStop() {
        updateEnabledState(false)
    }
    
    func fileGuardDidHandleError(_ errorText: String) {
        updateEnabledState(false)
    }
    
    private func updateEnabledState(_ enabled: Bool) {
        DispatchQueue.main.async {
            self.checkboxEnable.isEnabled = true
            self.checkboxEnable.state = enabled ? .on : .off
        }
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
