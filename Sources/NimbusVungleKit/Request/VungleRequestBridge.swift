//
//  VungleRequestBridge.swift
//  NimbusVungleKit
//
//  Created on 1/28/26.
//  Copyright © 2026 Nimbus Advertising Solutions Inc. All rights reserved.
//

import VungleAdsSDK


protocol VungleRequestBridgeType: Sendable {
    var isVungleInitialized: Bool { get }
    var token: String { get }
}

final class VungleRequestBridge: VungleRequestBridgeType {
    public var isVungleInitialized: Bool { VungleAds.isInitialized() }
    
    public var token: String { VungleAds.getBiddingToken() }
    
    @inlinable
    public static func set(coppa: Bool) {
        VunglePrivacySettings.setCOPPAStatus(coppa)
    }
}
