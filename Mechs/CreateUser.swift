//
//  CreateUser.swift
//  NoMADLogin
//
//  Created by Joel Rennich on 9/21/17.
//  Copyright © 2017 Joel Rennich. All rights reserved.
//

import OpenDirectory
import os.log
import NoMAD_ADAuth


/// Mechanism to create a local user and homefolder.
class CreateUser: NoLoMechanism {
    
    //MARK: - Properties
    let session = ODSession.default()
    
    
    /// Native attributes that are all set to the user's shortname on account creation to give them
    /// the ability to update the items later.
    var nativeAttrsWriters = ["dsAttrTypeNative:_writers_AvatarRepresentation",
                              "dsAttrTypeNative:_writers_hint",
                              "dsAttrTypeNative:_writers_jpegphoto",
                              "dsAttrTypeNative:_writers_picture",
                              "dsAttrTypeNative:_writers_unlockOptions",
                              "dsAttrTypeNative:_writers_UserCertificate",
                              "dsAttrTypeNative:_writers_realname"]
    
    /// Native attributes that are simply set to OS defaults on account creation.
    let nativeAttrsDetails = ["dsAttrTypeNative:AvatarRepresentation": "",
                              "dsAttrTypeNative:unlockOptions": "0"]
    
    @objc   func run() {
        os_log("CreateUser mech starting", log: createUserLog, type: .debug)
        if nomadPass != nil && !NoLoMechanism.checkForLocalUser(name: nomadUser!) {
            guard let uid = findFirstAvaliableUID() else {
                os_log("Could not find an avaliable UID", log: createUserLog, type: .debug)
                return
            }
            
            os_log("Checking for createLocalAdmin key", log: createUserLog, type: .debug)
            var isAdmin = false
            if let createAdmin = getManagedPreference(key: .CreateAdminUser) as? Bool {
                isAdmin = createAdmin
                os_log("Found a createLocalAdmin key value: %{public}@", log: createUserLog, type: .debug, isAdmin.description)
            }
            
            os_log("Checking for CreateAdminIfGroupMember groups", log: uiLog, type: .debug)
            if let adminGroups = getManagedPreference(key: .CreateAdminIfGroupMember) as? [String] {
                os_log("Found a CreateAdminIfGroupMember key value: %{public}@ ", log: uiLog, type: .debug, adminGroups)
                nomadGroups?.forEach { group in
                    if adminGroups.contains(group) {
                        isAdmin = true
                        os_log("User is a member of %{public}@ group. Setting isAdmin = true ", log: uiLog, type: .debug, group)
                    }
                }
            }
            var customAttributes = [String: String]()
            
            let nomadMetaPrefix = "_nomad"
            
            customAttributes["dsAttrTypeNative:\(nomadMetaPrefix)_didCreateUser"] = "1"
            
            let currentDate = ISO8601DateFormatter().string(from: Date())
            customAttributes["dsAttrTypeNative:\(nomadMetaPrefix)_creationDate"] = currentDate
            
            customAttributes["dsAttrTypeNative:\(nomadMetaPrefix)_domain"] = nomadDomain!
            
            createUser(shortName: nomadUser!,
                       first: nomadFirst!,
                       last: nomadLast!,
                       pass: nomadPass!,
                       uid: uid,
                       gid: "20",
                       canChangePass: true,
                       isAdmin: isAdmin,
                       customAttributes: customAttributes)
            
            os_log("Creating local homefolder for %{public}@", log: createUserLog, type: .debug, nomadUser!)
            createHomeDirFor(nomadUser!)
            os_log("Fixup home permissions for: %{public}@", log: createUserLog, type: .debug, nomadUser!)
            let _ = cliTask("/usr/sbin/diskutil resetUserPermissions / \(uid)", arguments: nil, waitForTermination: true)
            os_log("Account creation complete, allowing login", log: createUserLog, type: .debug)
        } else {
            // no user to create
            os_log("Skipping local account creation", log: createUserLog, type: .default)
            
            // Set the login timestamp if requested
            setTimestampFor(nomadUser as? String ?? "")
            
            os_log("Account creation skipped, allowing login", log: createUserLog, type: .debug)
        }
        let _ = allowLogin()
        os_log("CreateUser mech complete", log: createUserLog, type: .debug)
    }
    
    // mark utility functions
    func createUser(shortName: String, first: String, last: String, pass: String?, uid: String, gid: String, canChangePass: Bool, isAdmin: Bool, customAttributes: [String:String]) {
        var newRecord: ODRecord?
        os_log("Creating new local account for: %{public}@", log: createUserLog, type: .default, shortName)
        os_log("New user attributes. first: %{public}@, last: %{public}@, uid: %{public}@, gid: %{public}@, canChangePass: %{public}@, isAdmin: %{public}@, customAttributes: %{public}@", log: createUserLog, type: .debug, first, last, uid, gid, canChangePass.description, isAdmin.description, customAttributes)
        
        // note for anyone following behind me
        // you need to specify the attribute values in an array
        // regardless of if there's more than one value or not
        
        os_log("Checking for UserProfileImage key", log: createUserLog, type: .debug)


        var userPicture = getManagedPreference(key: .UserProfileImage) as? String ?? ""
        
        if userPicture.isEmpty && !FileManager.default.fileExists(atPath: userPicture) {
            os_log("Key did not contain an image, randomly picking one", log: createUserLog, type: .debug)
            userPicture = randomUserPic()
        }

        os_log("userPicture is: %{public}@", log: createUserLog, type: .debug, userPicture)
        
        // Adds kODAttributeTypeJPEGPhoto as data, seems to be necessary for the profile pic to appear everywhere expected.
        // Does not necessarily have to be in JPEG format. TIF and PNG both tested okay
        // Apple seems to populate both kODAttributeTypePicture and kODAttributeTypeJPEGPhoto from the GUI user creator
        let picURL = URL(fileURLWithPath: userPicture)
        let picData = NSData(contentsOf: picURL)
        let picString = picData?.description ?? ""

        var attrs: [AnyHashable:Any] = [
            kODAttributeTypeFullName: [first + " " + last],
            kODAttributeTypeNFSHomeDirectory: [ "/Users/" + shortName ],
            kODAttributeTypeUserShell: ["/bin/bash"],
            kODAttributeTypeUniqueID: [uid],
            kODAttributeTypePrimaryGroupID: [gid],
            kODAttributeTypeAuthenticationHint: [""],
            kODAttributeTypePicture: [userPicture],
            kODAttributeTypeJPEGPhoto: [picString],
            kODAttributeADUser: [getHint(type: .kerberos_principal) as? String ?? ""]
        ]
        
        if getManagedPreference(key: .UseCNForFullName) as? Bool ?? false {
            attrs[kODAttributeTypeFullName] = [getHint(type: .noMADFull) as? String ?? ""]
        }
        
        if let signInTime = getHint(type: .networkSignIn) {
            attrs[kODAttributeNetworkSignIn] = [signInTime]
        }
        
        do {
            os_log("Creating user account in local ODNode", log: createUserLog, type: .debug)
            let node = try ODNode.init(session: session, type: ODNodeType(kODNodeTypeLocalNodes))
            newRecord = try node.createRecord(withRecordType: kODRecordTypeUsers, name: shortName, attributes: attrs)
        } catch {
            let errorText = error.localizedDescription
            os_log("Unable to create account. Error: %{public}@", log: createUserLog, type: .error, errorText)
            return
        }
        os_log("Local ODNode user created successfully", log: createUserLog, type: .debug)
        
        os_log("Setting native attributes", log: createUserLog, type: .debug)
        if #available(macOS 10.13, *) {
            os_log("We are on 10.13 so drop the _writers_realname", log: createUserLog, type: .debug)
            nativeAttrsWriters.removeLast()
        }
        
        for item in nativeAttrsWriters {
            do {
                os_log("Setting %{public}@ attribute for new local user", log: createUserLog, type: .debug, item)
                try newRecord?.addValue(shortName, toAttribute: item)
            } catch {
                os_log("Failed to set attribute: %{public}@", log: createUserLog, type: .error, item)
            }
        }
        
        for item in nativeAttrsDetails {
            do {
                os_log("Setting %{public}@ attribute for new local user", log: createUserLog, type: .debug, item.key)
                try newRecord?.addValue(item.value, toAttribute: item.key)
            } catch {
                os_log("Failed to set attribute: %{public}@", log: createUserLog, type: .error, item.key)
            }
        }
        
        if canChangePass {
            do {
                os_log("Setting _writers_passwd for new local user", log: createUserLog, type: .debug)
                try newRecord?.addValue(shortName, toAttribute: "dsAttrTypeNative:_writers_passwd")
            } catch {
                os_log("Unable to set _writers_passwd", log: createUserLog, type: .error)
            }
        }
        
        if let password = pass {
            do {
                os_log("Setting password for new local user", log: createUserLog, type: .debug)
                try newRecord?.changePassword(nil, toPassword: password)
            } catch {
                os_log("Error setting password for new local user", log: createUserLog, type: .error)
            }
        }
        
        if customAttributes.isEmpty == false {
            os_log("Setting additional attributes for new local user", log: createUserLog, type: .debug)
            for item in customAttributes {
                do {
                    os_log("Setting %{public}@ attribute for new local user, value: %{public}@", log: createUserLog, type: .debug, item.key, item.value)
                    try newRecord?.addValue(item.value, toAttribute: item.key)
                } catch {
                    os_log("Failed to set additional attribute: %{public}@", log: createUserLog, type: .error, item.key)
                }
            }
        }
        
        if isAdmin {
            do {
                os_log("Find the administrators group", log: createUserLog, type: .debug)
                let node = try ODNode.init(session: session, type: ODNodeType(kODNodeTypeLocalNodes))
                let query = try ODQuery.init(node: node,
                                             forRecordTypes: kODRecordTypeGroups,
                                             attribute: kODAttributeTypeRecordName,
                                             matchType: ODMatchType(kODMatchEqualTo),
                                             queryValues: "admin",
                                             returnAttributes: kODAttributeTypeNativeOnly,
                                             maximumResults: 1)
                let results = try query.resultsAllowingPartial(false) as! [ODRecord]
                let adminGroup = results.first
                
                os_log("Adding user to administrators group", log: createUserLog, type: .debug)
                try adminGroup?.addMemberRecord(newRecord)
            } catch {
                let errorText = error.localizedDescription
                os_log("Unable to add user to administrators group: %{public}@", log: createUserLog, type: .error, errorText)
            }
            
            if isFdeEnabled() == false {
                if #available(OSX 10.14, *) {
                    addSecureToken(shortName, pass)
                }
            }
            
        }
        
        os_log("User creation complete for: %{public}@", log: createUserLog, type: .debug, shortName)
    }
    
    // func to get a random string
    func randomString(length: Int) -> String {
        
        let letters : NSString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()"
        let len = UInt32(letters.length)
        
        var randomString = ""
        
        for _ in 0 ..< length {
            let rand = arc4random_uniform(len)
            var nextChar = letters.character(at: Int(rand))
            randomString += NSString(characters: &nextChar, length: 1) as String
        }
        
        return randomString
    }

    //TODO: Change to throws instead of optional.
    /// Finds the first avaliable UID in the DSLocal domain above 500 and returns it as a `String`
    ///
    /// - Returns: `String` representing the UID
    func findFirstAvaliableUID() -> String? {
        var newUID = ""
        os_log("Checking for avaliable UID", log: createUserLog, type: .debug)
        for potentialUID in 501... {
            do {
                let node = try ODNode.init(session: session, type: ODNodeType(kODNodeTypeLocalNodes))
                let query = try ODQuery.init(node: node, forRecordTypes: kODRecordTypeUsers, attribute: kODAttributeTypeUniqueID, matchType: ODMatchType(kODMatchEqualTo), queryValues: String(potentialUID), returnAttributes: kODAttributeTypeNativeOnly, maximumResults: 0)
                let records = try query.resultsAllowingPartial(false) as! [ODRecord]
                if records.isEmpty {
                    newUID = String(potentialUID)
                    break
                }
            } catch {
                let errorText = error.localizedDescription
                os_log("ODError searching for avaliable UID: %{public}@", log: createUserLog, type: .error, errorText)
                return nil
            }
        }
        os_log("Found first avaliable UID: %{public}@", log: createUserLog, type: .default, newUID)
        return newUID
    }

    //TODO: Convert to throws
    /// Finds the local homefolder template that corresponds to the locale of the system and copies it into place.
    ///
    /// - Parameter user: The shortname of the user to create a home for as a `String`.
    func createHomeDirFor(_ user: String) {
        os_log("Find system locale...", log: createUserLog, type: .debug)
        let currentLanguage = Locale.current.languageCode ?? "Non_localized"
        os_log("System language is: %{public}@", log: createUserLog, type: .debug, currentLanguage)
        let templateName = templateForLang(currentLanguage)
        let sourceURL = URL(fileURLWithPath: "/System/Library/User Template/" + templateName)
        let downloadsURL = URL(fileURLWithPath: "/System/Library/User Template/Non_localized/Downloads")
        let documentsURL = URL(fileURLWithPath: "/System/Library/User Template/Non_localized/Documents")
        do {
            os_log("Copying template to /Users", log: createUserLog, type: .debug)
            try FileManager.default.copyItem(at: sourceURL, to: URL(fileURLWithPath: "/Users/" + user))
            os_log("Copying non-localized folders to new home", log: createUserLog, type: .debug)
            try FileManager.default.copyItem(at: downloadsURL, to: URL(fileURLWithPath: "/Users/" + user + "/Downloads"))
            try FileManager.default.copyItem(at: documentsURL, to: URL(fileURLWithPath: "/Users/" + user + "/Documents"))
        } catch {
            os_log("Home template copy failed with: %{public}@", log: createUserLog, type: .error, error.localizedDescription)
        }
    }
    
    /// Looks at the Apple provided User Pictures directory, recurses it, and delivers a random picture path.
    ///
    /// - Returns: A `String` path to a random user picture. If there is a failure it returns an empty `String`.
    func randomUserPic() -> String {
        let libraryDir = FileManager.default.urls(for: .libraryDirectory, in: .localDomainMask)
        guard let library = libraryDir.first else {
            return ""
        }
        let picturePath = library.appendingPathComponent("User Pictures", isDirectory: true)
        let picDirs = (try? FileManager.default.contentsOfDirectory(at: picturePath, includingPropertiesForKeys: [URLResourceKey.isDirectoryKey], options: .skipsHiddenFiles)) ?? []
        let pics = picDirs.flatMap {(try? FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: [URLResourceKey.isRegularFileKey], options: .skipsHiddenFiles)) ?? []}
        return pics[Int(arc4random_uniform(UInt32(pics.count)))].path
    }
    
    /// Given an connonical ISO language code, find and return the macOS home folder template name that is appropriate.
    ///
    /// - Parameter code: The `languageCode` of the current user `Locale`.
    ///             You can find the current language with `Locale.current.languageCode`
    /// - Returns: A `String` that is the name of the localized home folder template on macOS. If the language code doesn't
    ///             map to one of the default macOS home templates the `Non_localized` name will be returned.
    func templateForLang(_ code: String) -> String {
        let templateName = ".lproj"
        switch code {
        case "es":
            return "Spanish" + templateName
        case "nl":
            return "Dutch" + templateName
        case "en":
            return "English" + templateName
        case "fr":
            return "French" + templateName
        case "it":
            return "Italian" + templateName
        case "ja":
            return "Japanese" + templateName
        case "ar":
            return "ar" + templateName
        case "ca":
            return "ca" + templateName
        case "cs":
            return "cs" + templateName
        case "da":
            return "da" + templateName
        case "el":
            return "el" + templateName
        case "es-419":
            return "es_419" + templateName
        case "fi":
            return "fi" + templateName
        case "he":
            return "he" + templateName
        case "hi":
            return "hi" + templateName
        case "hr":
            return  "hr" + templateName
        case "hu":
            return "hu" + templateName
        case "id":
            return "id" + templateName
        case "ko":
            return "ko" + templateName
        case "ms":
            return "ms" + templateName
        case "nb":
            return "no" + templateName
        case "pl":
            return "pl" + templateName
        case "pt":
            return "pt" + templateName
        case "pt-PT":
            return "pt_PT" + templateName
        case "ro":
            return "ro" + templateName
        case "ru":
            return "ru" + templateName
        case "sk":
            return "sk" + templateName
        case "sv":
            return "sv" + templateName
        case "th":
            return "th" + templateName
        case "tr":
            return "tr" + templateName
        case "uk":
            return "uk" + templateName
        case "vi":
            return "vi" + templateName
        case "zh-Hans":
            return "zh_CN" + templateName
        case "zh-Hant":
            return "zh_TW" + templateName
        default:
            return "Non_localized"
        }
    }
    
    fileprivate func setTimestampFor(_ nomadUser: String) {
        // Add network sign in stamp
        if let signInTime = getHint(type: .networkSignIn) {
            if NoLoMechanism.updateSignIn(name: nomadUser, time: signInTime as AnyObject) {
                os_log("Sign in time updated", log: createUserLog, type: .default)
            } else {
                os_log("Dould not add timestamp", log: createUserLog, type: .error)
            }
        }
    }
    
    fileprivate func addSecureToken(_ shortName: String, _ pass: String?) {
        //MARK: 10.14 fix
        // check for 10.14
        // check for no existing local users?
        // - perhaps looking for diskutil apfs listcryptousers /
        //     if a user already has a token, this will fail anyway
        // - gate behind a pref key?
        
        // attempt to add token to user
        
        
        os_log("Attempting to add a token to new user.", log: createUserLog, type: .default)
        
        let launchPath = "/usr/sbin/sysadminctl"
        
        var args = [
            "-secureTokenOn",
            shortName,
            "-password",
            pass ?? "",
            "-adminUser",
            shortName,
            "-adminPassword",
            pass ?? ""
        ]
        
        let result = cliTask(launchPath, arguments: args, waitForTermination: true)
        os_log("sysdaminctl result: @{public}%", log: createUserLog, type: .debug, result)
        args = [
            "********",
            "********",
            "********",
            "********",
            "********",
            "********",
            "********",
            "********"
        ]
    }
    
    fileprivate func isFdeEnabled() -> Bool {
        
        // check to see if FV is already running
        
        let launchPath = "/usr/bin/fdesetup"
        let args = [
            "status"
        ]
        if cliTask(launchPath, arguments: args, waitForTermination: true).contains("FileVault is Off") {
            return false
        } else {
            return true
        }
    }
}
