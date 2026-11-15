//
//  Bootstrap.swift
//  Sileo
//
//  Created by Amy While on 15/04/2023.
//  Copyright © 2023 Sileo Team. All rights reserved.
//

import Foundation

enum Bootstrap: String, Codable {
    
    // Sileo demo (userland): no bootstrap is ever detected from the
    // filesystem. These are constants so callers that branch on the
    // bootstrap keep compiling with the stock (non-jailbreak) values.
    // The old bootstrap marker-file probes were removed for the demo.
    static let procursus_rootless = false
    static let procursus_rootful = false
    
    case procursus = "Procursus"
    case elucubratus = "Bingner/Elucubratus"
    
    case xinaa15_strap = "Procursus/Xina"
    case electra_strap = "Electra/Chimera"
    case other_strap = "Unknown Bootstrap"
    
    init(jailbreak: Jailbreak) {
        // Pure mapping from the (demo-forced) jailbreak identity.
        // No filesystem reads and no bootstrap detection.
        switch jailbreak {
            
        case .electra:
            self = .electra_strap
            
        case .chimera:
            self = .electra_strap
            
        case .unc0ver, .checkra1n:
            self = .elucubratus
            
        case .odysseyra1n, .taurine, .odyssey, .fugu15, .xina15, .dopamine, .apex, .amethyst:
            self = .procursus
            
        case .palera1n_legacy, .palera1n_rootful, .palera1n_rootless, .bakera1n_rootful, .bakera1n_rootless:
            self = .other_strap
            
        case .xina15_legacy:
            self = .xinaa15_strap
            
        default:
            self = .other_strap
        }
    }
    
}
