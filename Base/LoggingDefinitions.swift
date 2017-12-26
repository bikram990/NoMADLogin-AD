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
