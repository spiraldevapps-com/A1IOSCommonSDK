//
//  Purchasely.swift
//  A1OfficeSDK
//
//  Created by Tushar Goyal on 04/09/23.
//

import Foundation
import Purchasely
import Alamofire

public var isReachable: Bool {
    guard (NetworkReachabilityManager()?.isReachable)! else {
        return false
    }
    return true
}

public protocol PurchaselyManagerDelegate: AnyObject {
    func didUpdateSubscription()
    func alertAction(text: String?)
    func loader(isShown: Bool)

    func cancelSubscription()
    func loadFresh()
}

public extension PurchaselyManagerDelegate {
    func cancelSubscription() {}
    func loadFresh() {}
}

public class PurchaselyManager: NSObject {
    public static var shared = PurchaselyManager()
    weak var delegate: PurchaselyManagerDelegate?
    var purchaselyViewController: UIViewController?
    var fromController: UIViewController?
    var products: [PLYProduct]?

    public func configurePurchasely(key: String, completionHandler: @escaping (Int, Error?) -> Void) {
        handlerAction()
        Purchasely.start(withAPIKey: key, appUserId: nil, runningMode: .full, eventDelegate: self, logLevel: .debug) { [weak self] (success, error) in
            Purchasely.setUIDelegate(self)
            if error == nil {
                self?.restorePurchasely(completionHandler: { value, error in
                    completionHandler(value, error)
                })
            } else {
                completionHandler(0, error)
            }
        }
        Purchasely.isReadyToPurchase(true)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadContent(_:)), name: .ply_purchasedSubscription, object: nil)
    }

    private func restorePurchasely(completionHandler: @escaping (Int, Error?) -> Void) {
        Purchasely.restoreAllProducts(success: { [weak self] in
            print("Purchasely.restoreAllProducts success")
            self?.fetchSubscriptions(completionHandler: { value, error in
                completionHandler(value, error)
            })
            self?.fetchProducts()
        }, failure: { [weak self] error in
            print("Purchasely.restoreAllProducts error", error.localizedDescription)
            self?.fetchSubscriptions(completionHandler: { value, error in
                completionHandler(value, error)
            })
            self?.fetchProducts()
        })
    }

    private func fetchSubscriptions(completionHandler: @escaping (Int, Error?) -> Void) {
        Purchasely.userSubscriptions { subscriptions in
            completionHandler(subscriptions?.count ?? 0, nil)
        } failure: { error in
            completionHandler(0, error)
        }
    }

    func updateControllers() {
        if delegate != nil {
            delegate?.didUpdateSubscription()
        }
        else {
            delegate?.loadFresh()
        }
    }

    public func showFreeTrial(from: UIViewController, placement: String, content: String = "", delegate: PurchaselyManagerDelegate) {
        guard isReachable else {
            delegate.alertAction(text: Localization.internetError)
            return
        }
        self.delegate = delegate
        delegate.loader(isShown: true)
        Purchasely.fetchPresentation(for: placement, contentId: content, fetchCompletion: { [weak self] result, error in
            self?.delegate?.loader(isShown: false)
            if error == nil, let vc = result?.controller {
                EventManager.shared.logEvent(title: PurchaselyKey.event_subs_purchasely_load_started.rawValue)
                vc.modalPresentationStyle = .fullScreen
                self?.purchaselyViewController = vc
                EventManager.shared.logEvent(title: PurchaselyKey.event_subs_purchasely_show_requested.rawValue)
                from.present(vc, animated: true, completion: nil)
                if vc.isBeingPresented {
                    EventManager.shared.logEvent(title: PurchaselyKey.event_subs_purchasely_screen_shown.rawValue)
                }
            }
        })
    }


   private func handlerAction() {
        Purchasely.setDefaultPresentationResultHandler { [weak self] result, plan in
            guard let self = self else {return}
            switch result {
            case .purchased:
                print("User purchased: \(plan?.name ?? "No plan")")
                self.updateControllers()
                EventManager.shared.logEvent(title: PurchaselyKey.event_subs_purchase_acknowledged.rawValue, key: "plan_type", value: plan?.name ?? "No plan")
            case .restored:
                print("User restored: \(plan?.name ?? "No plan")")
                self.updateControllers()
                EventManager.shared.logEvent(title: PurchaselyKey.event_subs_purchase_acknowledged.rawValue)
            case .cancelled:
                print("User cancelled: \(plan?.name ?? "No plan")")
                self.delegate?.cancelSubscription()
            default:
                break
            }
        }
    }

    private func fetchProducts() {
        Purchasely.allProducts(success: { [weak self] products in
            self?.products = products
            self?.printPlans()
            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: "ReceivedPrice")))
        }, failure: { [weak self] (error) in
            self?.delegate?.alertAction(text: Localization.fetchPlansError)
        })
    }
    //    func makePurchase() {
    //        if let products = products, products.count > 0 {
    //            let product = products[0]
    //            let plans = product.plans
    //            if plans.count > 2 {
    //                let plan = plans[2]
    //                Purchasely.purchase(plan: plan) {
    //                    Utility.showAlert(message: "Successfully purchased the plan")
    //                } failure: { error in
    //                    Utility.showAlert(message: error.localizedDescription)
    //                }
    //            }
    //        }
    //
    //    }

    func printPlans() {
        if let products = products, products.count > 0 {
            let product = products[0]
            let plans = product.plans
            if plans.count > 0 {
                print(plans[0].appleProductId ?? "0 No appleProductId")
            }
            if plans.count > 1 {
                print(plans[1].appleProductId ?? "1 No appleProductId")
            }
            if plans.count > 2 {
                print(plans[2].appleProductId ?? "2 No appleProductId")
            }
        }
    }

    @objc func reloadContent(_ notification: Notification) {
        print("reloadContent", notification.name)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

}

extension PurchaselyManager: PLYUIDelegate {
    public func display(controller: UIViewController, type: PLYUIControllerType, from sourceController: UIViewController?) {
        EventManager.shared.logEvent(title: PurchaselyKey.event_subs_purchasely_screen_shown.rawValue)
    }

    public func display(alert: PLYAlertMessage, error: Error?) {
        print(alert)
        if error != nil {
            purchaselyViewController?.dismiss(animated: true) {
                if let message = error?.localizedDescription, message != "Too many calls on /configuration" {
                    EventManager.shared.logEvent(title: PurchaselyKey.event_subs_purchasely_payment_failed.rawValue, key: "error", value: message)
                    if message == "The network connection was lost." {
                        self.delegate?.alertAction(text: Localization.networkError)
                    } else {
                        self.delegate?.alertAction(text: Localization.priceError)
                    }
                }
            }
        }
    }
}

extension PurchaselyManager: PLYEventDelegate{
    @objc public func eventTriggered(_ event: PLYEvent, properties: [String : Any]?) {
        print("eventTriggered", event.name)
        print(properties ?? "No Properties")
        switch event {
        case .receiptValidated:
            print("receiptValidated")
        case .receiptFailed:
            print("receiptFailed")
        default: break
        }
    }
}
