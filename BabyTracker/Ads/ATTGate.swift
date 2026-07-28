//
//  ATTGate.swift
//  BabyTracker
//
//  App Tracking Transparency.
//
//  Without ATT consent there is no IDFA: bidding partners skip most requests
//  and eCPM drops sharply. But the prompt must come at a moment the user can
//  make sense of, and every ad request must wait for the answer - a request
//  fired before the prompt resolves carries the wrong consent state.
//
//  Deliberately NO custom pre-prompt. The pregnancy tracker had one removed
//  because of popup fatigue, and that decision carries over here.
//

import Foundation
import AppTrackingTransparency
import AdSupport

enum ATTGate {

    static var status: ATTrackingManager.AuthorizationStatus {
        ATTrackingManager.trackingAuthorizationStatus
    }

    /// True once the user has answered, either way.
    static var isResolved: Bool { status != .notDetermined }

    /// Shows the system prompt if it hasn't been answered, then returns.
    /// Always returns on the main actor, and always returns - a denial is a
    /// resolved state, not a failure.
    @MainActor
    @discardableResult
    static func requestIfNeeded() async -> ATTrackingManager.AuthorizationStatus {
        guard status == .notDetermined else { return status }
        return await ATTrackingManager.requestTrackingAuthorization()
    }
}
