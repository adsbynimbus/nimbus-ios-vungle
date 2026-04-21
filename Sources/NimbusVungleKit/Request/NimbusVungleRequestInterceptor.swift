//
//  NimbusVungleRequestInterceptor.swift
//  NimbusVungleKit
//
//  Created on 12/09/22.
//  Copyright © 2023 Nimbus Advertising Solutions Inc. All rights reserved.
//

import NimbusKit

/// Enables Vungle demand for NimbusRequest
/// Add an instance of this to `NimbusAdManager.requestInterceptors`
final class NimbusVungleRequestInterceptor {
    
    private let bridge: VungleRequestBridgeType
    
    init(bridge: VungleRequestBridgeType = VungleRequestBridge()) {
        self.bridge = bridge
    }
}

extension NimbusVungleRequestInterceptor: NimbusRequest.Interceptor {
    
    func modifyRequest(request: NimbusRequest) async throws -> [NimbusRequest.Delta] {
        guard bridge.isVungleInitialized else {
            throw NimbusError.vungle(reason: .invalidState, stage: .request, detail: "Not initialized before request")
        }

        return [.init(target: .user, key: "vungle_buyeruid", value: bridge.token)]
    }
}
