//
//  CheckAD.swift
//  NoMADLogin
//
//  Created by Joel Rennich on 9/20/17.
//  Copyright © 2017 Joel Rennich. All rights reserved.
//

import Cocoa
import os

class CheckAD: NoLoMechanism {
    @objc func run() {
        os_log("Activating app", log: UILog, type: .debug)
        NSApp.activate(ignoringOtherApps: true)
        os_log("Loading XIB", log: UILog, type: .debug)
        let signIn = SignIn(windowNibName: NSNib.Name(rawValue: "SignIn"))
        os_log("Set mech for loginwindow", log: UILog, type: .debug)
        signIn.mech = mech
        let windowTest = signIn.window
        if windowTest == nil {
            os_log("Could not create login window UI", log: UILog, type: .default)
        }
        os_log("Display window", log: UILog, type: .debug)
        NSApp.runModal(for: signIn.window!)
    }
}
