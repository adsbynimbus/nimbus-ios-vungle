//
//  NimbusError+Vungle.swift
//  NimbusVungleKit
//
//  Created on 2/23/26.
//  Copyright © 2026 Nimbus Advertising Solutions Inc. All rights reserved.
//

import NimbusKit

extension NimbusError.Domain {
    static let vungle = Self(rawValue: "vungle")
}

extension NimbusError {
    static func vungle(reason: Reason = .failure, stage: Stage, detail: String? = nil) -> NimbusError {
        NimbusError(reason: reason, domain: .vungle, stage: stage, detail: detail)
    }
}
