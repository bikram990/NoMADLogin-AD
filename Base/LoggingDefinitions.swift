//
//  LoggingDefinitions.swift
//  NoMADLoginAD
//
//  Created by Josh Wisenbaker on 12/26/17.
//  Copyright © 2017 NoMAD. All rights reserved.
//

import os.log

let uiLog = OSLog(subsystem: "menu.nomad.noload", category: "UI")
let checkADLog = OSLog(subsystem: "menu.nomad.noload", category: "CheckADMech")
let createUserLog = OSLog(subsystem: "menu.nomad.noload", category: "CreateUserMech")
let noLoMechlog = OSLog(subsystem: "menu.nomad.noload", category: "NoLoSwiftMech")
let noLoBaseMechlog = OSLog(subsystem: "menu.nomad.noload", category: "NoLoBaseMech")
let loggerMech = OSLog(subsystem: "menu.nomad.noload", category: "LoggerMech")
let demobilizeLog = OSLog(subsystem: "menu.nomad.noload", category: "DemobilizeMech")
let powerControlLog = OSLog(subsystem: "menu.nomad.noload", category: "PowerControlMech")
let enableFDELog = OSLog(subsystem: "menu.nomad.noload", category: "EnableFDELog")
let sierraFixesLog = OSLog(subsystem: "menu.nomad.noload", category: "SierraFixesLog")
let keychainAddLog = OSLog(subsystem: "menu.nomad.noload", category: "KeychainAdd")
let eulaLog = OSLog(subsystem: "menu.nomad.noload", category: "EULA")
