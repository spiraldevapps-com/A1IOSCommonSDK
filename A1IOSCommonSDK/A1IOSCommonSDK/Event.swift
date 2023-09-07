//
//  Event.swift
//  A1OfficeSDK
//
//  Created by Tushar Goyal on 05/09/23.
//

import Foundation
import UIKit
import YandexMobileMetrica
import FBSDKCoreKit
import FirebaseAnalytics
import Mixpanel
import Firebase

public enum PurchaselyKey: String {
    
    // MARK: - First Time Application Event
    case event_app_first_open
    
    // MARK: - Purchasely
    case event_subs_purchasely_load_started
    case event_subs_purchasely_show_requested
    case event_subs_purchasely_screen_shown
    case event_subs_purchasely_payment_failed
    case event_subs_purchase_acknowledged // with params
    
}

public class EventManager: NSObject {
    let proOpenFromKey = "pro_opened_from"
    public static var shared = EventManager()
    
    public func configureEventManager(appMetricaKey: String, mixPanelKey: String) {
        FirebaseApp.configure()
        let configuration = YMMYandexMetricaConfiguration.init(apiKey: appMetricaKey)
        YMMYandexMetrica.activate(with: configuration!)
        Mixpanel.initialize(token: mixPanelKey, trackAutomaticEvents: true)
        logEvent(title: PurchaselyKey.event_app_first_open.rawValue)
    }

    public func logEvent(title: String, key: String, value: String) {
        YMMYandexMetrica.reportEvent(title, parameters: [key : value])
        Mixpanel.mainInstance().track(event: title, properties: [key : value])
        Analytics.logEvent(title, parameters: [key: value])
        AppEvents.shared.logEvent(AppEvents.Name(title), parameters: [AppEvents.ParameterName(key): value])
    }

    public func logEvent(title: String, params: [String: String]? = nil) {
        YMMYandexMetrica.reportEvent(title, parameters: params)
        Mixpanel.mainInstance().track(event: title, properties: params)
        Analytics.logEvent(title, parameters: params)
        if let myparams = params {
            let appEventsParams = myparams.map { key, value in
                (AppEvents.ParameterName(key), value)
            }
            let parameters = Dictionary(uniqueKeysWithValues: appEventsParams)
            AppEvents.shared.logEvent(AppEvents.Name(title), parameters: parameters)
        } else {
            AppEvents.shared.logEvent(AppEvents.Name(title), parameters: nil)
        }
    }
    
    public func logProOpenedEvent(title: String, from: String) {
        YMMYandexMetrica.reportEvent(title, parameters: [proOpenFromKey: from])
        Mixpanel.mainInstance().track(event: title, properties: [proOpenFromKey: from])
        Analytics.logEvent(title, parameters: [proOpenFromKey: from])
        AppEvents.shared.logEvent(AppEvents.Name(title), parameters: [AppEvents.ParameterName(proOpenFromKey): from])
    }

    public func logFacebookEvent(name: String, params: [String: String]) {
        let appEventsParams = params.map { key, value in
            (AppEvents.ParameterName(key), value)
        }
        let parameters = Dictionary(uniqueKeysWithValues: appEventsParams)
        AppEvents.shared.logEvent(AppEvents.Name(name), parameters: parameters)
        
        //Add same events for google as well
        Analytics.logEvent(name, parameters: params)
    }

}
