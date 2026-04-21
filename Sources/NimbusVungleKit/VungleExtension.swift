//
//  VungleExtension.swift
//  Nimbus
//  Created on 3/28/25
//  Copyright © 2025 Nimbus Advertising Solutions Inc. All rights reserved.
//

import NimbusKit
import UIKit
import VungleAdsSDK

/// Nimbus extension for Vungle (Liftoff).
///
/// Enables Vungle rendering when included in `Nimbus.initialize(...)`.
/// Supports dynamic enable/disable at runtime.
///
/// ### Notes:
///   - Instantiate within the `Nimbus.initialize` block; the extension is installed and enabled automatically.
///   - Disable rendering with `VungleExtension.disable()`.
///   - Re-enable rendering with `VungleExtension.enable()`.
public struct VungleExtension: NimbusRequestExtension, NimbusRenderExtension {
    @_documentation(visibility: internal)
    public var enabled = true
    
    @_documentation(visibility: internal)
    public var network: String { "vungle" }
    
    @_documentation(visibility: internal)
    public var controllerType: AdController.Type { NimbusVungleAdController.self }
    
    @_documentation(visibility: internal)
    public let interceptor: any NimbusRequest.Interceptor
    
    /// Creates a Vungle (Liftoff) extension.
    ///
    /// - Parameters:
    ///   - appId: Vungle App ID. If provided, Nimbus initializes the Vungle SDK automatically.
    ///
    /// ##### Usage
    /// ```swift
    /// Nimbus.initialize(publisher: "<publisher>", apiKey: "<apiKey>") {
    ///     VungleExtension(appId: "<appId>") // Enables Vungle rendering
    /// }
    /// ```
    public init(appId: String? = nil) {
        VungleAds.setIntegrationName("vunglehbs", version: "29")
        
        interceptor = NimbusVungleRequestInterceptor()
        
        guard let appId, !VungleAds.isInitialized() else {
            Nimbus.Log.lifecycle.debug("Skipping Vungle SDK initialization, appId was not provided or SDK is already initialized")
            return
        }
        
        VungleAds.initWithAppId(appId) { error in
            if let error {
                Nimbus.Log.lifecycle.error("Vungle SDK failed to initialize: \(error.localizedDescription)")
            } else {
                Nimbus.Log.lifecycle.debug("Vungle SDK initialization completed")
            }
        }
    }
    
    @_documentation(visibility: internal)
    public func coppaDidChange(coppa: Bool) {
        VungleRequestBridge.set(coppa: coppa)
    }
}

/**
 A `UIView` subclass capable of presenting Vungle native ads.
 
 Pass an instance conforming to this protocol to `VungleExtension.nativeAdViewProvider`
 to render a native Vungle ad.
 */
public protocol VungleNativeAdViewType: UIView {
    var mediaView: MediaView { get set }
    var iconImageView: UIImageView? { get set }
    var clickableViews: [UIView]? { get }
}

public extension VungleExtension {
    /**
     The UIView returned from this method should have all of the data set from the native ad
     on children views such as the call to action, image data, title, privacy icon etc.
     The view returned from this method should not be attached to the container passed in as
     it will be attached at a later time during the rendering process.
     
     - Parameters:
       - container: The container the layout will be attached to
       - nativeAd: The Vungle native ad with the relevant ad information
     
     - Returns: Your custom UIView (NimbusVungleNativeAdViewType) that will be attached to the container
     */
    @MainActor
    @preconcurrency
    static var nativeAdViewProvider: ((_ container: UIView, _ nativeAd: VungleNative) -> VungleNativeAdViewType)?
}
