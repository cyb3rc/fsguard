//
//  AppDelegate.swift
//  FileGuard
//
//  Created by Volodymyr Vashurkin on 8/21/19.
//  Copyright © 2019 Volodymyr Vashurkin. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

	var windowController: MainWindowController!


	func applicationDidFinishLaunching(_ aNotification: Notification) {
        windowController = MainWindowController.createDefault()
        windowController.showWindow(self)
	}
}

