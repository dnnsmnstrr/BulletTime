//
//  SessionStates.swift
//  BulletTime
//
//  Created by Dennis Muensterer on 01.06.18.
//  Copyright © 2018 Dennis Muensterer. All rights reserved.
//

import Foundation


enum SessionStates: String, CustomStringConvertible {
    case initialized = "initialized"
    case ready = "ready"
    case temporarilyUnavailable = "temporarily unavailable"
    case failed = "failed"
    
    var description: String {
        switch self {
        case .initialized:
            return "Look for a good center point"
        case .ready:
            return "Tap to select center point"
        case .temporarilyUnavailable:
            return "Please wait"
        case .failed:
            return "Error! Please restart App."
        }
    }
}
