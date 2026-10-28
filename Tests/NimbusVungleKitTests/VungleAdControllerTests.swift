//
//  VungleAdControllerTests.swift
//  NimbusVungleKitTests
//  Created on 10/23/26
//  Copyright © 2026 Nimbus Advertising Solutions Inc. All rights reserved.
//

import Testing
@testable import NimbusVungleKit
@testable import NimbusKit
import UIKit
import VungleAdsSDK

private let placementId = "test-placement-id"
private let bidPayload = "test-bid-payload"

@Suite("Vungle AdController tests")
@MainActor
struct VungleAdControllerTests {

    // MARK: - Banner

    @Test func bannerAdEventsGetFired() throws {
        let (adController, delegate) = makeAdController(.banner)

        let banner = adController.buildBannerAd(placementId: placementId)
        #expect(adController.bannerAd === banner)
        #expect(adController.nativeAd == nil)
        #expect(adController.interstitialAd == nil)
        #expect(adController.rewardedAd == nil)

        let vungle = try #require(banner.delegate, "banner delegate not wired")
        #expect(vungle === adController)

        vungle.bannerAdDidLoad?(banner)
        #expect(delegate.events == [.loaded])

        #expect(adController.adView.subviews.isEmpty)
        adController.start()
        #expect(adController.adView.subviews.first === banner)

        vungle.bannerAdDidTrackImpression?(banner)
        #expect(delegate.events == [.loaded, .impression])

        // Impressions are only counted once
        vungle.bannerAdDidTrackImpression?(banner)
        #expect(delegate.events == [.loaded, .impression])

        vungle.bannerAdDidClick?(banner)
        #expect(delegate.events == [.loaded, .impression, .clicked])
        #expect(delegate.lastError == nil)

        vungle.bannerAdDidClose?(banner)
        #expect(delegate.lastError == nil)
        #expect(delegate.events.last == .destroyed)
        #expect(adController.bannerAd == nil)
    }

    @Test func bannerAdGetsDestroyedOnError() throws {
        let (adController, delegate) = makeAdController(.banner)
        let banner = adController.buildBannerAd(placementId: placementId)
        let vungle = try #require(banner.delegate, "banner delegate not wired")

        vungle.bannerAdDidFail?(banner, withError: vungleError)

        expectVungleError(delegate)
        #expect(delegate.events.last == .destroyed)
    }

    // MARK: - Native

    @Test func nativeAdEventsGetFired() throws {
        let (adController, delegate) = makeAdController(.native)

        let native = adController.buildNativeAd(placementId: placementId)
        #expect(adController.nativeAd === native)
        #expect(adController.bannerAd == nil)
        #expect(adController.interstitialAd == nil)
        #expect(adController.rewardedAd == nil)

        let vungle = try #require(native.delegate, "native delegate not wired")
        #expect(vungle === adController)
        detachFromSDK(native)

        let nativeView = MockNativeAdView()
        var providedAd: VungleNative?
        VungleExtension.nativeAdViewProvider = { _, ad in
            providedAd = ad
            return nativeView
        }
        defer { VungleExtension.nativeAdViewProvider = nil }

        vungle.nativeAdDidLoad?(native)
        #expect(delegate.events == [.loaded])
        #expect(adController.adView.subviews.isEmpty)

        adController.start()
        #expect(adController.adView.subviews.first === nativeView)
        #expect(providedAd === native)

        vungle.nativeAdDidTrackImpression?(native)
        #expect(delegate.events == [.loaded, .impression])

        vungle.nativeAdDidClick?(native)
        #expect(delegate.events == [.loaded, .impression, .clicked])
        #expect(delegate.lastError == nil)

        // Video completion arrives through the media view's delegate, which the adapter wires on render
        let media = try #require(nativeView.mediaView.delegate, "media view delegate not wired")
        #expect(media === adController)

        media.mediaViewVideoDidEnd?(nativeView.mediaView)
        #expect(delegate.events == [.loaded, .impression, .clicked, .completed])
        #expect(!delegate.events.contains(.rewardEarned))
        #expect(delegate.lastError == nil)
    }

    /// Inline ads may be set up without a presenting view controller; Vungle's registration accepts nil.
    @Test func nativeAdRendersWithoutPresentingViewController() throws {
        let (adController, delegate) = makeAdController(.native, withPresenter: false)
        let native = adController.buildNativeAd(placementId: placementId)
        let vungle = try #require(native.delegate, "native delegate not wired")
        detachFromSDK(native)

        let nativeView = MockNativeAdView()
        VungleExtension.nativeAdViewProvider = { _, _ in nativeView }
        defer { VungleExtension.nativeAdViewProvider = nil }

        vungle.nativeAdDidLoad?(native)
        adController.start()

        #expect(delegate.lastError == nil)
        #expect(adController.adView.subviews.first === nativeView)
        #expect(nativeView.mediaView.delegate === adController)
    }

    @Test func nativeAdWithoutViewProviderGetsDestroyed() throws {
        let (adController, delegate) = makeAdController(.native)
        let native = adController.buildNativeAd(placementId: placementId)
        let vungle = try #require(native.delegate, "native delegate not wired")
        VungleExtension.nativeAdViewProvider = nil

        vungle.nativeAdDidLoad?(native)
        adController.start()

        #expect(delegate.lastError?.reason == .configuration)
        #expect(adController.adView.subviews.isEmpty)
        #expect(delegate.events.last == .destroyed)
    }

    @Test func nativeAdGetsDestroyedOnLoadError() throws {
        let (adController, delegate) = makeAdController(.native)
        let native = adController.buildNativeAd(placementId: placementId)
        let vungle = try #require(native.delegate, "native delegate not wired")

        vungle.nativeAdDidFailToLoad?(native, withError: vungleError)

        expectVungleError(delegate)
        #expect(delegate.events.last == .destroyed)
    }

    @Test func nativeAdGetsDestroyedOnPresentError() throws {
        let (adController, delegate) = makeAdController(.native)
        let native = adController.buildNativeAd(placementId: placementId)
        let vungle = try #require(native.delegate, "native delegate not wired")

        vungle.nativeAdDidFailToPresent?(native, withError: vungleError)

        expectVungleError(delegate)
        #expect(delegate.events.last == .destroyed)
    }

    // MARK: - Interstitial

    // Showing a fullscreen ad needs a really loaded Vungle ad, which tests can't produce. These tests
    // fire the callbacks the shown ad would send, and check that start() won't show an ad that can't play.

    @Test func interstitialAdEventsGetFired() throws {
        let (adController, delegate) = makeAdController(.interstitial)

        let interstitial = adController.buildInterstitialAd(placementId: placementId)
        #expect(adController.interstitialAd === interstitial)
        #expect(adController.bannerAd == nil)
        #expect(adController.nativeAd == nil)
        #expect(adController.rewardedAd == nil)

        let vungle = try #require(interstitial.delegate, "interstitial delegate not wired")
        #expect(vungle === adController)

        vungle.interstitialAdDidLoad?(interstitial)
        #expect(delegate.events == [.loaded])

        vungle.interstitialAdDidTrackImpression?(interstitial)
        #expect(delegate.events == [.loaded, .impression])

        vungle.interstitialAdDidClick?(interstitial)
        #expect(delegate.events == [.loaded, .impression, .clicked])
        #expect(delegate.lastError == nil)

        vungle.interstitialAdDidClose?(interstitial)
        #expect(delegate.lastError == nil)
        #expect(!delegate.events.contains(.rewardEarned))
        #expect(delegate.events.last == .destroyed)
        #expect(adController.interstitialAd == nil)
    }

    @Test func interstitialThatCannotPlayIsNotPresented() throws {
        let (adController, delegate) = makeAdController(.interstitial)
        let interstitial = adController.buildInterstitialAd(placementId: placementId)
        let vungle = try #require(interstitial.delegate, "interstitial delegate not wired")

        // Never really loaded, so Vungle's canPlayAd() is false
        vungle.interstitialAdDidLoad?(interstitial)
        adController.start()

        #expect(delegate.lastError?.detail == "Interstitial ad could not be played")
        #expect(delegate.events.last == .destroyed)
    }

    @Test func interstitialAdGetsDestroyedOnLoadError() throws {
        let (adController, delegate) = makeAdController(.interstitial)
        let interstitial = adController.buildInterstitialAd(placementId: placementId)
        let vungle = try #require(interstitial.delegate, "interstitial delegate not wired")

        vungle.interstitialAdDidFailToLoad?(interstitial, withError: vungleError)

        expectVungleError(delegate)
        #expect(delegate.events.last == .destroyed)
    }

    @Test func interstitialAdGetsDestroyedOnPresentError() throws {
        let (adController, delegate) = makeAdController(.interstitial)
        let interstitial = adController.buildInterstitialAd(placementId: placementId)
        let vungle = try #require(interstitial.delegate, "interstitial delegate not wired")

        vungle.interstitialAdDidLoad?(interstitial)
        vungle.interstitialAdDidFailToPresent?(interstitial, withError: vungleError)

        expectVungleError(delegate)
        #expect(delegate.events.last == .destroyed)
    }

    // MARK: - Rewarded

    @Test func rewardedAdEventsGetFired() throws {
        let (adController, delegate) = makeAdController(.rewarded)

        let rewarded = adController.buildRewardedAd(placementId: placementId)
        #expect(adController.rewardedAd === rewarded)
        #expect(adController.bannerAd == nil)
        #expect(adController.nativeAd == nil)
        #expect(adController.interstitialAd == nil)

        let vungle = try #require(rewarded.delegate, "rewarded delegate not wired")
        #expect(vungle === adController)

        vungle.rewardedAdDidLoad?(rewarded)
        #expect(delegate.events == [.loaded])

        vungle.rewardedAdDidTrackImpression?(rewarded)
        #expect(delegate.events == [.loaded, .impression])

        vungle.rewardedAdDidClick?(rewarded)
        #expect(delegate.events == [.loaded, .impression, .clicked])

        vungle.rewardedAdDidRewardUser?(rewarded)
        #expect(delegate.events == [.loaded, .impression, .clicked, .rewardEarned])
        #expect(delegate.lastError == nil)

        vungle.rewardedAdDidClose?(rewarded)
        #expect(delegate.lastError == nil)
        #expect(delegate.events.last == .destroyed)
        #expect(adController.rewardedAd == nil)
    }

    @Test func rewardedThatCannotPlayIsNotPresented() throws {
        let (adController, delegate) = makeAdController(.rewarded)
        let rewarded = adController.buildRewardedAd(placementId: placementId)
        let vungle = try #require(rewarded.delegate, "rewarded delegate not wired")

        // Never really loaded, so Vungle's canPlayAd() is false
        vungle.rewardedAdDidLoad?(rewarded)
        adController.start()

        #expect(delegate.lastError?.detail == "Rewarded ad could not be played")
        #expect(delegate.events.last == .destroyed)
    }

    @Test func rewardedAdGetsDestroyedOnLoadError() throws {
        let (adController, delegate) = makeAdController(.rewarded)
        let rewarded = adController.buildRewardedAd(placementId: placementId)
        let vungle = try #require(rewarded.delegate, "rewarded delegate not wired")

        vungle.rewardedAdDidFailToLoad?(rewarded, withError: vungleError)

        expectVungleError(delegate)
        #expect(!delegate.events.contains(.rewardEarned))
        #expect(delegate.events.last == .destroyed)
    }

    @Test func rewardedAdGetsDestroyedOnPresentError() throws {
        let (adController, delegate) = makeAdController(.rewarded)
        let rewarded = adController.buildRewardedAd(placementId: placementId)
        let vungle = try #require(rewarded.delegate, "rewarded delegate not wired")

        vungle.rewardedAdDidLoad?(rewarded)
        vungle.rewardedAdDidFailToPresent?(rewarded, withError: vungleError)

        expectVungleError(delegate)
        #expect(!delegate.events.contains(.rewardEarned))
        #expect(delegate.events.last == .destroyed)
    }

    // MARK: - Load validation

    @Test func loadFailsWithoutPlacementId() {
        let adController = VungleAdController(
            response: NimbusResponse(id: "", bid: .init(mtype: .static, adm: bidPayload, price: 0, ext: .init())),
            isBlocking: false,
            isRewarded: false,
            container: container,
            adPresentingViewController: presenter
        )
        let delegate = MockDelegate()
        adController.delegate = delegate

        adController.load()

        #expect(adController.bannerAd == nil)
        #expect(delegate.lastError?.detail == "Missing placement id")
        #expect(delegate.events.last == .destroyed)
    }

    // MARK: - Helpers

    /// Fresh per test: Swift Testing creates a new suite instance for every @Test.
    private let container = UIView()

    /// AdController holds adPresentingViewController weakly, so it must outlive the test body.
    private let presenter = UIViewController()

    private let vungleError = NSError(
        domain: "com.vungle.test",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Vungle test error"]
    )

    enum Format { case banner, native, interstitial, rewarded }

    private func makeAdController(
        _ format: Format,
        withPresenter: Bool = true
    ) -> (VungleAdController, MockDelegate) {
        let mtype: NimbusResponse.Bid.MarkupType = switch format {
        case .banner, .interstitial: .static
        case .native: .native
        case .rewarded: .video
        }

        let adController = VungleAdController(
            response: NimbusResponse(id: "", bid: .init(
                mtype: mtype,
                adm: bidPayload,
                price: 0,
                ext: .init(omp: .init(buyer: "vungle", buyerPlacementId: placementId)),
                w: 320,
                h: 50
            )),
            isBlocking: format == .interstitial || format == .rewarded,
            isRewarded: format == .rewarded,
            container: container,
            adPresentingViewController: withPresenter ? presenter : nil
        )
        let delegate = MockDelegate()
        adController.delegate = delegate
        return (adController, delegate)
    }

    /// The native ad never really loaded, so Vungle may report its registration as a presentation failure.
    /// Detach the SDK object from the controller (after checking the wiring) so only callbacks the test fires arrive.
    private func detachFromSDK(_ native: VungleNative) {
        native.delegate = nil
    }

    private func expectVungleError(_ delegate: MockDelegate, sourceLocation: SourceLocation = #_sourceLocation) {
        let error = delegate.lastError
        #expect(error != nil, sourceLocation: sourceLocation)
        #expect(error!.domain == NimbusError.Domain(rawValue: "vungle"), sourceLocation: sourceLocation)
        #expect(error!.detail == "Vungle test error", sourceLocation: sourceLocation)
    }
}

// MARK: - Mocks

class MockDelegate: AdController.Delegate {
    var events: [AdEvent] = []
    var lastError: NimbusError?

    func didReceiveNimbusEvent(event: NimbusKit.AdEvent) {
        events.append(event)
    }

    func didReceiveNimbusError(error: NimbusKit.NimbusError) {
        lastError = error
    }
}

final class MockNativeAdView: UIView, VungleNativeAdViewType {
    var mediaView = MediaView(frame: .zero)
    var iconImageView: UIImageView? = UIImageView()
    var clickableViews: [UIView]? { [mediaView] }
}
