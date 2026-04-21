//
//  NimbusVungleAdController.swift
//  NimbusVungleKit
//
//  Created on 13/09/22.
//  Copyright © 2023 Nimbus Advertising Solutions Inc. All rights reserved.
//

import NimbusKit
import UIKit
import VungleAdsSDK

final class NimbusVungleAdController: AdController,
                                      @preconcurrency VungleBannerViewDelegate,
                                      @preconcurrency VungleNativeDelegate,
                                      @preconcurrency VungleInterstitialDelegate,
                                      @preconcurrency VungleRewardedDelegate {
    
    /// Determines whether ad has registered an impression
    private var hasRegisteredAdImpression = false
    
    private var bannerAd: VungleBannerView?
    private var interstitialAd: VungleInterstitial?
    private var rewardedAd: VungleRewarded?
    private var nativeAd: VungleNative?
    
    override class func setup(
        response: NimbusResponse,
        container: UIView,
        adPresentingViewController: UIViewController?
    ) -> AdController {
        let adController = Self.init(
            response: response,
            isBlocking: false,
            isRewarded: false,
            container: container,
            adPresentingViewController: adPresentingViewController
        )
        
        return adController
    }
    
    override class func setupBlocking(
        response: NimbusResponse,
        isRewarded: Bool,
        adPresentingViewController: UIViewController?
    ) -> AdController {
        let adController = Self.init(
            response: response,
            isBlocking: true,
            isRewarded: isRewarded,
            container: nil,
            adPresentingViewController: adPresentingViewController
        )
        
        return adController
    }
    
    override func load() {
        guard let placementId = response.bid.ext?.omp?.buyerPlacementId else {
            sendNimbusError(.vungle(reason: .invalidState, stage: .render, detail: "Missing placement id"))
            return
        }
        
        switch adRenderType {
        case .banner:            
            let vungleAdSize = VungleAdSize.VungleAdSizeFromCGSize(response.bid.size)
            bannerAd = VungleBannerView(placementId: placementId, vungleAdSize: vungleAdSize)
            bannerAd?.delegate = self
            bannerAd?.load(response.bid.adm)
        case .native:
            nativeAd = VungleNative(placementId: placementId)
            nativeAd?.delegate = self
            nativeAd?.load(response.bid.adm)
        case .interstitial:
            interstitialAd = VungleInterstitial(placementId: placementId)
            interstitialAd?.delegate = self
            interstitialAd?.load(response.bid.adm)
        case .rewarded:
            rewardedAd = VungleRewarded(placementId: placementId)
            rewardedAd?.delegate = self
            rewardedAd?.load(response.bid.adm)
        @unknown default:
            sendNimbusError(NimbusError.vungle(reason: .unsupported, stage: .render, detail: "adRenderType: \(adRenderType.rawValue)"))
        }
    }
    
    func presentAdIfReady() {
        guard started, adState == .ready else { return }
        
        adState = .resumed
        
        if let bannerAd {
            adView.addSubview(bannerAd)
        } else if let nativeAd, let adPresentingViewController {
            guard let nativeAdViewProvider = VungleExtension.nativeAdViewProvider else {
                sendNimbusError(.vungle(reason: .misconfiguration, stage: .render, detail: "VungleExtension.nativeAdViewProvider must be set to render native ads"))
                return
            }
            
            let nativeAdView = nativeAdViewProvider(adView, nativeAd)
            
            nativeAdView.translatesAutoresizingMaskIntoConstraints = false
            adView.addSubview(nativeAdView)
            NSLayoutConstraint.activate([
                nativeAdView.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
                nativeAdView.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
                nativeAdView.topAnchor.constraint(equalTo: adView.topAnchor),
                nativeAdView.bottomAnchor.constraint(equalTo: adView.bottomAnchor)
            ])
            
            nativeAd.registerViewForInteraction(
                view: adView,
                mediaView: nativeAdView.mediaView,
                iconImageView: nativeAdView.iconImageView,
                viewController: adPresentingViewController,
                clickableViews: nativeAdView.clickableViews
            )
        } else if let interstitialAd, let adPresentingViewController {
            guard interstitialAd.canPlayAd() else {
                sendNimbusError(.vungle(stage: .render, detail: "Interstitial ad could not be played"))
                return
            }
            
            interstitialAd.present(with: adPresentingViewController)
        } else if let rewardedAd, let adPresentingViewController {
            guard rewardedAd.canPlayAd() else {
                sendNimbusError(.vungle(stage: .render, detail: "Rewarded ad could not be played"))
                return
            }
            
            rewardedAd.present(with: adPresentingViewController)
        } else {
            sendNimbusError(.vungle(reason: .invalidState, stage: .render, detail: "Ad \(adRenderType) is invalid and could not be presented."))
        }
    }
    
    // MARK - AdController overrides
    
    override func onStart() {
        presentAdIfReady()
    }
    
    override func onDestroy() {
        bannerAd?.delegate = nil
        bannerAd = nil
        
        nativeAd?.unregisterView()
        nativeAd?.delegate = nil
        nativeAd = nil
        
        interstitialAd?.delegate = nil
        interstitialAd = nil
        
        rewardedAd?.delegate = nil
        rewardedAd = nil
    }
    
    // MARK: - VungleBannerViewDelegate
    
    func bannerAdDidLoad(_ bannerView: VungleBannerView) {
        adState = .ready
        sendNimbusEvent(.loaded)
        presentAdIfReady()
    }
    
    func bannerAdDidFail(_ bannerView: VungleBannerView, withError: NSError) {
        sendNimbusError(.vungle(stage: .render, detail: withError.localizedDescription))
    }

    func bannerAdDidClose(_ bannerView: VungleBannerView) {
        destroy()
    }

    func bannerAdDidTrackImpression(_ bannerView: VungleBannerView) {
        guard !hasRegisteredAdImpression else { return }
        
        hasRegisteredAdImpression = true
        sendNimbusEvent(.impression)
    }

    func bannerAdDidClick(_ bannerView: VungleBannerView) {
        sendNimbusEvent(.clicked)
    }
    
    // MARK: - VungleNativeDelegate
    
    func nativeAdDidLoad(_ native: VungleNative) {
        adState = .ready
        sendNimbusEvent(.loaded)
        presentAdIfReady()
    }
    
    func nativeAdDidFailToLoad(_ native: VungleNative, withError: NSError) {
        sendNimbusError(.vungle(stage: .render, detail: withError.localizedDescription))
    }
    
    func nativeAdDidFailToPresent(_ native: VungleNative, withError: NSError) {
        sendNimbusError(.vungle(stage: .render, detail: withError.localizedDescription))
    }

    func nativeAdDidTrackImpression(_ native: VungleNative) {
        guard !hasRegisteredAdImpression else { return }
        
        hasRegisteredAdImpression = true
        sendNimbusEvent(.impression)
    }
    
    func nativeAdDidClick(_ native: VungleNative) {
        sendNimbusEvent(.clicked)
    }
    
    // MARK: - VungleInterstitialDelegate
    
    func interstitialAdDidLoad(_ interstitial: VungleInterstitial) {
        adState = .ready
        
        sendNimbusEvent(.loaded)
        
        presentAdIfReady()
    }
    
    func interstitialAdDidFailToLoad(_ interstitial: VungleInterstitial, withError: NSError) {
        sendNimbusError(.vungle(stage: .render, detail: withError.localizedDescription))
    }
    
    func interstitialAdDidFailToPresent(_ interstitial: VungleInterstitial, withError: NSError) {
        sendNimbusError(.vungle(stage: .render, detail: withError.localizedDescription))
    }
    
    func interstitialAdDidClose(_ interstitial: VungleInterstitial) {
        destroy()
    }
    
    func interstitialAdDidTrackImpression(_ interstitial: VungleInterstitial) {
        guard !hasRegisteredAdImpression else { return }
        
        hasRegisteredAdImpression = true
        sendNimbusEvent(.impression)
    }
    
    func interstitialAdDidClick(_ interstitial: VungleInterstitial) {
        sendNimbusEvent(.clicked)
    }
    
    // MARK: - VungleRewardedDelegate
    
    func rewardedAdDidLoad(_ rewarded: VungleRewarded) {
        adState = .ready
        
        sendNimbusEvent(.loaded)
        
        presentAdIfReady()
    }
    
    func rewardedAdDidFailToLoad(_ rewarded: VungleRewarded, withError: NSError) {
        sendNimbusError(.vungle(stage: .render, detail: withError.localizedDescription))
    }
    
    func rewardedAdDidFailToPresent(_ rewarded: VungleRewarded, withError: NSError) {
        sendNimbusError(.vungle(stage: .render, detail: withError.localizedDescription))
    }
    
    func rewardedAdDidClose(_ rewarded: VungleRewarded) {
        destroy()
    }
    
    func rewardedAdDidTrackImpression(_ rewarded: VungleRewarded) {
        guard !hasRegisteredAdImpression else { return }
        
        hasRegisteredAdImpression = true
        sendNimbusEvent(.impression)
    }
    
    func rewardedAdDidClick(_ rewarded: VungleRewarded) {
        sendNimbusEvent(.clicked)
    }
    
    func rewardedAdDidRewardUser(_ rewarded: VungleRewarded) {
        sendNimbusEvent(.completed)
    }
}

// Internal: Do NOT implement delegate conformance as separate extensions as the methods won't not be found in runtime when built as a static library
