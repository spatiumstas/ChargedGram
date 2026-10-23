import Foundation
import Localization
import SceneEffects
import SwiftSignalKit
import TelegramContext
import TelegramCore
import TGUIKit

private final class PremiumStoreOperation {
    private static let registryLock = NSLock()
    private static var activeManagers: Set<ObjectIdentifier> = []
    private let managerId: ObjectIdentifier


    private(set) var isActive = true

    static func begin(manager: any InAppPurchaseManagerProtocol) -> PremiumStoreOperation? {
        precondition(Thread.isMainThread)
        let managerId = ObjectIdentifier(manager)
        registryLock.lock()
        let inserted = activeManagers.insert(managerId).inserted
        registryLock.unlock()
        guard inserted else { return nil }
        return PremiumStoreOperation(managerId: managerId)
    }

    private static func remove(_ managerId: ObjectIdentifier) {
        registryLock.lock()
        activeManagers.remove(managerId)
        registryLock.unlock()
    }

    private init(managerId: ObjectIdentifier) {
        self.managerId = managerId
    }

    func finish(_ action: () -> Void) {
        precondition(Thread.isMainThread)
        guard isActive else { return }
        isActive = false
        Self.remove(managerId)
        action()
    }

    deinit {
        if isActive {
            Self.remove(managerId)
        }
    }
}

func premiumStorePurchase(context: any AccountContextProtocol, product: InAppPurchaseProduct, paid: @escaping () -> Void) {
    let manager = context.inAppPurchaseManager
    guard let operation = PremiumStoreOperation.begin(manager: manager) else { return }
    let lockModal = PremiumLockModalController()
    delay(0.2, closure: {
        guard operation.isActive else { return }
        showModal(with: lockModal, for: context.window)
    })

    var checkedEligibility = false
    let eligibility = context.engine.payments.canPurchasePremium(purpose: .subscription) |> take(1) |> deliverOnMainQueue
    _ = (eligibility).start(next: { available in
        checkedEligibility = true
        guard available else {
            operation.finish { lockModal.close() }
            return
        }
        let purchase = manager.buyProduct(product, purpose: .subscription) |> take(1) |> deliverOnMainQueue
        _ = (purchase).start(next: { _ in
            operation.finish {
                manager.finishAllTransactions()
                lockModal.close()
                paid()
                delay(0.2, closure: {
                    PlayConfetti(for: context.window)
                    showModalText(for: context.window, text: strings().premiumBoardingAppStoreSuccess)
                    let _ = updatePremiumPromoConfigurationOnce(account: context.account).start()
                })
            }
        }, error: { error in
            operation.finish {
                manager.finishAllTransactions()
                lockModal.close()
                let text: String
                switch error {
                case .generic, .assignFailed:
                    text = strings().premiumPurchaseErrorUnknown
                case .network:
                    text = strings().premiumPurchaseErrorNetwork
                case .notAllowed:
                    text = strings().premiumPurchaseErrorNotAllowed
                case .cantMakePayments:
                    text = strings().premiumPurchaseErrorCantMakePayments
                case .cancelled:
                    text = strings().premiumBoardingAppStoreCancelled
                }
                showModalText(for: context.window, text: text)
            }
        }, completed: {
            operation.finish { lockModal.close() }
        })
    }, completed: {
        if !checkedEligibility {
            operation.finish { lockModal.close() }
        }
    })
}

func premiumStoreRestore(context: any AccountContextProtocol) {
    let manager = context.inAppPurchaseManager
    guard let operation = PremiumStoreOperation.begin(manager: manager) else { return }
    manager.restorePurchases(completion: { result in
        DispatchQueue.main.async {
            operation.finish {
                switch result {
                case let .succeed(value):
                    if value {
                        showModalText(for: context.window, text: strings().premiumRestoreSuccess)
                    }
                case .failed:
                    showModalText(for: context.window, text: strings().premiumRestoreErrorUnknown)
                }
            }
        }
    })
}
