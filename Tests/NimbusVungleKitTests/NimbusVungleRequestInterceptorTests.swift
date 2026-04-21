//
//  NimbusVungleRequestInterceptorTests.swift
//  NimbusVungleKitTests
//
//  Created on 12/09/22.
//  Copyright © 2023 Nimbus Advertising Solutions Inc. All rights reserved.
//

@testable import NimbusVungleKit
import VungleAdsSDK
import XCTest
import Testing
@testable import NimbusKit

@Suite("Vungle request interceptor tests")
struct NimbusVungleRequestInterceptorTests {
    let appId = "APP_ID_12345"
    
    @Test func vungleTokenIsReturned() async throws {
        let interceptor = NimbusVungleRequestInterceptor(bridge: MockNimbusVungleBridge())
        let ad = try await Nimbus.bannerAd(position: "test", size: .banner)
        let info = try await NimbusRequest(from: ad.adRequest!.request)
        let deltas = try await interceptor.modifyRequest(request: info)
        
        #expect(deltas.count == 1)
        #expect(deltas[0].target == .user)
        #expect(deltas[0].key == "vungle_buyeruid")
        #expect(deltas[0].value as? String == "testToken")
    }
    
    @MainActor
    @Test func vungleTokenGetsInsertedIntoRequest() async throws {
        let interceptor = NimbusVungleRequestInterceptor(bridge: MockNimbusVungleBridge())
        
        let ad = try Nimbus.rewardedAd(position: "test")
        ad.adRequest!.request.interceptors = [interceptor]
        
        try await ad.adRequest!.request.modifyRequestWithExtras(
            configuration: Nimbus.configuration,
            vendorId: Nimbus.vendorId,
            appVersion: "1.0.0"
        )
        
        #expect(ad.adRequest!.request.user?.ext?.extras["vungle_buyeruid"] as? String == "testToken")
    }
    
    @Test func vungleInterceptorThrowsIfVungleIsNotInitialized() async throws {
        let bridge = MockNimbusVungleBridge()
        bridge._isVungleInitialized = false
        let interceptor = NimbusVungleRequestInterceptor(bridge: bridge)
        let ad = try await Nimbus.bannerAd(position: "test", size: .banner)
        
        let error = await #expect(throws: NimbusError.self) {
            try await interceptor.modifyRequest(request: try NimbusRequest(from: ad.adRequest!.request))
        }
        
        #expect(error!.domain == .vungle)
        #expect(error!.reason == .invalidState)
        #expect(error!.stage == .request)
        #expect(error!.detail == "Not initialized before request")
    }
}

final class MockNimbusVungleBridge: VungleRequestBridgeType, @unchecked Sendable {
    var _isVungleInitialized: Bool = true
    var _token: String = "testToken"
    
    var isVungleInitialized: Bool { _isVungleInitialized }
    var token: String { _token }
}
