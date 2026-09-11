//
//  VungleRequestInterceptor.swift
//  NimbusVungleKit
//
//  Created on 12/09/22.
//  Copyright © 2023 Nimbus Advertising Solutions Inc. All rights reserved.
//

import NimbusKit

final class VungleRequestInterceptor {
    
    private let bridge: VungleRequestBridgeType
    
    init(bridge: VungleRequestBridgeType = VungleRequestBridge()) {
        self.bridge = bridge
    }
}

extension VungleRequestInterceptor: NimbusRequest.Interceptor {
    
    func modifyRequest(request: NimbusRequest) async throws -> [NimbusRequest.Delta] {
        guard bridge.isVungleInitialized else {
            throw NimbusError.vungle(reason: .invalidState, stage: .request, detail: "Not initialized before request")
        }

        return [.init(target: .user, key: "vungle_buyeruid", value: await bridge.token)]
    }
}
