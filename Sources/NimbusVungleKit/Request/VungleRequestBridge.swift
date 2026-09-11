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
    var token: String { get async }
}

final class VungleRequestBridge: VungleRequestBridgeType {
    
    private static let queue = DispatchQueue(label: "NimbusVungleKit.requestQueue")
    
    /// `VungleAds.isInitialized` is a simple boolean it doesn't need to be synchronized through queue
    var isVungleInitialized: Bool { VungleAds.isInitialized() }
    
    var token: String {
        get async {
            await withCheckedContinuation { cont in
                Self.queue.async { cont.resume(returning: VungleAds.getBiddingToken()) }
            }
        }
    }
    
    @inlinable
    static func set(coppa: Bool) {
        Self.queue.async { VunglePrivacySettings.setCOPPAStatus(coppa) }
    }
}
