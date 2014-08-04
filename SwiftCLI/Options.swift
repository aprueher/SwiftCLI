//
//  Options.swift
//  SwiftCLI
//
//  Created by Jake Heiser on 7/11/14.
//  Copyright (c) 2014 jakeheis. All rights reserved.
//

import Foundation

typealias OptionsFlagBlock = (flag: String) -> ()
typealias OptionsKeyBlock = (key: String, value: String) -> ()

class Options {
    
    let combinedFlagsAndKeys: [String]
    var flagOptions: [String] = []
    var keyedOptions: [String: String] = [:]
    
    var accountedForFlags: [String] = []
    var accountedForKeys: [String] = []
    
    convenience init() {
        self.init(arguments: [])
    }
    
    init(arguments: [String]) {
        self.combinedFlagsAndKeys = arguments
        
        self.splitArguments()
    }
    
    func description() -> String {
        return "Flag options: \(self.flagOptions) Keyed options: \(self.keyedOptions)"
    }
    
    // MARK: - Argument splitting
    
    private func splitArguments() {
        var skipNext = false
        for index in 0..<self.combinedFlagsAndKeys.count {
            if skipNext {
                skipNext = false
                continue
            }
            
            let argument = self.combinedFlagsAndKeys[index]
            
            if index < self.combinedFlagsAndKeys.count-1 {
                let nextArgument = self.combinedFlagsAndKeys[index+1]
                
                if nextArgument.hasPrefix("-") {
                    self.flagOptions += argument
                } else {
                    self.keyedOptions[argument] = nextArgument
                    skipNext = true
                }
                
            } else {
                self.flagOptions += argument
            }
            
        }
    }
    
    // MARK: - Flags

    func onFlags(flags: [String], block: OptionsFlagBlock?) {
        for flag in flags {
            if contains(self.flagOptions, flag) {
                self.accountedForFlags += flag
                block?(flag: flag)
            }
        }
    }
    
    // MAKR: - Keys
    
    func onKeys(keys: [String], block: OptionsKeyBlock?) {
        for key in keys {
            if contains(Array(self.keyedOptions.keys), key) {
                self.accountedForKeys += key
                block?(key: key, value: self.keyedOptions[key]!)
            }
        }
    }
    
    // MARK: - Other publics
    
    func allAccountedFor() -> Bool {
        return self.remainingFlagOptions().count == 0 && self.remainingKeyedOptions().count == 0
    }
    
    func unaccountedForMessage(#command: Command, routedName: String) -> String? {
        if command.unhandledOptionsPrintingBehavior() == UnhandledOptionsPrintingBehavior.PrintNone {
            return nil
        }
        
        var message = ""
        
        if command.unhandledOptionsPrintingBehavior() != .PrintOnlyUsage {
            message += "Unrecognized options:"
            for flag in self.remainingFlagOptions() {
                message += "\n\t\(flag)"
            }
            for option in self.remainingKeyedOptions() {
                message += "\n\t\(option) \(self.keyedOptions[option]!)"
            }
            
            if command.unhandledOptionsPrintingBehavior() == .PrintAll {
                message += "\n" // Padding if more will be printed
            }
        }
       
        if command.unhandledOptionsPrintingBehavior() != .PrintOnlyUnrecognizedOptions {
            message += command.commandUsageStatement(commandName: routedName)
        }
        
        return message
    }
    
    // MARK: - Privates
    
    private func remainingFlagOptions() -> [String] {
        let remainingFlags = self.flagOptions.filter({ !contains(self.accountedForFlags, $0) })
        return remainingFlags
    }
    
    private func remainingKeyedOptions() -> [String] {
        let remainingKeys = self.keyedOptions.keys.filter({ !contains(self.accountedForKeys, $0) })
        return Array(remainingKeys)
    }
    
}