//
//  File.swift
//  Sileo
//
//  Created by Amy While on 15/04/2023.
//  Copyright © 2023 Sileo Team. All rights reserved.
//

import Foundation

enum Jailbreak: String, Codable {
    
    static let current = Jailbreak()
    static let bootstrap = Bootstrap(jailbreak: current)
    
    /// Coolstar jailbreaks
    case electra =           "Electra"
    case chimera =           "Chimera"
    case odyssey =           "Odyssey"
    case taurine =           "Taurine"

    /// Apex jailbreak
    case apex =              "Apex"
    
    // Amethyst jailbreak
    case amethyst =          "Amethyst"
    
    /// unc0ver jailbreak
    case unc0ver =           "unc0ver"
    
    /// checkra1n-type jailbreaks
    case checkra1n =         "checkra1n"
    case odysseyra1n =       "Odysseyra1n"
    
    case palera1n =          "palera1n"
    case palera1n_rootless = "palera1n • Rootless"
    case palera1n_rootful =  "palera1n • Rootful"
    case palera1n_legacy =   "palera1n • Legacy"

    case bakera1n =          "bakera1n"
    case bakera1n_rootless = "bakera1n • Rootless"
    case bakera1n_rootful =  "bakera1n • Rootful"
    
    /// Xina
    case xina15_legacy =     "XinaA15 • Legacy"
    case xina15 =            "XinaA15"
    
    /// Fugu15
    case fugu15 =            "Fugu15"
    case dopamine =          "Dopamine"
    
    case mac =               "macOS"
    case other =             "Unknown Jailbreak"
    case simulator =         "Simulator"
    
    private init() {
        // Sileo demo (userland): force a valid jailbreak identity so the app
        // never reports "Unknown Jailbreak" on non-jailbroken devices.
        // No on-device jailbreak detection is performed: the filesystem
        // probes for jailbreak marker files were removed for the demo.
        self = .dopamine
    }
}
