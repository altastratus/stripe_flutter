import Flutter
import UIKit
import Stripe

public class SwiftStripeFlutterPlugin: NSObject, FlutterPlugin {
    
    static var flutterChannel: FlutterMethodChannel!
    static var customerContext: STPCustomerContext?
    static var paymentContext: STPPaymentContext?
    
    static var delegateHandler: PaymentOptionViewControllerDelegate!
    static var applePayContextDelegate: ApplePayContextDelegate!
    
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "stripe_flutter", binaryMessenger: registrar.messenger())
    self.flutterChannel = channel
    let instance = SwiftStripeFlutterPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    
    self.delegateHandler = PaymentOptionViewControllerDelegate()
    self.applePayContextDelegate = ApplePayContextDelegate()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "sendPublishableKey":
        guard let args = call.arguments as? [String:Any] else {
            result(FlutterError(code: "InvalidArgumentsError", message: "Invalid arguments received", details: nil))
            return
        }
        guard let stripeKey = args["publishableKey"] as? String else {
            result(FlutterError(code: "InvalidArgumentsError", message: "Invalid arguments received", details: nil))
            return
        }
        
        configurePaymentConfiguration(publishableKey: stripeKey, result)
        break
    case "initCustomerSession":
        initCustomerSession(result)
        break
    case "endCustomerSession":
        endCustomerSession(result);
        break;
    case "showPaymentMethodsScreen":
        showPaymentMethodsScreen(result);
        break;
    case "getSelectedPaymentOption":
        getSelectedOption(result)
        break
    case "payUsingApplePay":
        guard let args = call.arguments as? [[String:String]] else {
            result(FlutterError(code: "InvalidArgumentsError", message: "Invalid arguments received", details: nil))
            return
        }
        handlePaymentUsingApplePay(result, items: args)
        break
    default:
        result(FlutterMethodNotImplemented)
    }
  }
    
    func configurePaymentConfiguration(publishableKey: String, _ result: @escaping FlutterResult) {
        STPAPIClient.shared().publishableKey = publishableKey
        STPPaymentConfiguration.shared().appleMerchantIdentifier = "merchant.au.com.playeat"
        result(nil)
    }
    
    func initCustomerSession(_ result: @escaping FlutterResult) {
        let flutterEphemeralKeyProvider = FlutterEphemeralKeyProvider(channel: SwiftStripeFlutterPlugin.flutterChannel)
        SwiftStripeFlutterPlugin.customerContext = STPCustomerContext(keyProvider: flutterEphemeralKeyProvider)
        result(nil)
    }
    
    func endCustomerSession(_ result: @escaping FlutterResult) {
        SwiftStripeFlutterPlugin.customerContext?.clearCache()
        SwiftStripeFlutterPlugin.customerContext = nil
        
        result(nil)
    }
    
    func getSelectedOption(_ result: @escaping FlutterResult) {
        if let context = SwiftStripeFlutterPlugin.customerContext {
            context.retrieveCustomer({ (customer,  error) in
                if error != nil {
                    result(FlutterError(code: "StripeDefaultSource", message: error?.localizedDescription, details: nil))
                    return
                }
                if let source = customer?.defaultSource as? STPSource {
                    var tuppleResult = [String:Any?]()
                    tuppleResult["id"] = source.stripeID
                    tuppleResult["last4"] = source.cardDetails?.last4
                    tuppleResult["brand"] = STPCard.string(from: source.cardDetails?.brand ?? STPCardBrand.unknown)
                    tuppleResult["expiredYear"] = Int(source.cardDetails?.expYear ?? 0)
                    tuppleResult["expiredMonth"] = Int(source.cardDetails?.expMonth ?? 0)
                    result(tuppleResult)
                } else if let card = customer?.defaultSource as? STPCard {
                    var tuppleResult = [String:Any?]()
                    tuppleResult["id"] = card.stripeID
                    tuppleResult["last4"] = card.last4
                    tuppleResult["brand"] = STPCard.string(from: card.brand)
                    tuppleResult["expiredYear"] = Int(card.expYear)
                    tuppleResult["expiredMonth"] = Int(card.expMonth)
                } else {
                    if let c = customer {
                        result(c.description)
                        return
                    }
                    result(customer?.defaultSource?.description)
                }
            })
        } else {
            result("Customer session is null")
        }
    }
    
    func showPaymentMethodsScreen(_ result: @escaping FlutterResult) {
        guard let _context = SwiftStripeFlutterPlugin.customerContext else {
            result(FlutterError(code: "IllegalStateError",
                                message: "CustomerSession is not properly initialized, have you correctly initialize CustomerSession?",
                                details: nil))
            return
        }
        if let uiAppDelegate = UIApplication.shared.delegate,
            let tempWindow = uiAppDelegate.window,
            let window = tempWindow,
            let rootVc = window.rootViewController {
            
            SwiftStripeFlutterPlugin.delegateHandler.window = window
            SwiftStripeFlutterPlugin.delegateHandler.flutterViewController = rootVc
            SwiftStripeFlutterPlugin.delegateHandler.setFlutterResult(result)

            let vc = STPPaymentOptionsViewController(configuration: STPPaymentConfiguration.shared(),
                                                     theme: STPTheme.default(),
                                                     customerContext: _context,
                                                     delegate: SwiftStripeFlutterPlugin.delegateHandler)
            
            let uiNavController = UINavigationController(rootViewController: vc)
            
            UIView.transition(with: window, duration: 0.2, options: .transitionCrossDissolve, animations: {
                window.rootViewController = uiNavController
            }, completion: nil)
            
            window.rootViewController = uiNavController
            return
        } else {
            result(FlutterError(code: "IllegalStateError",
                                message: "Root ViewController in Window is currently not available.",
                                details: nil))
            
            return
        }
    }
    
    func handlePaymentUsingApplePay(_ result: @escaping FlutterResult, items: [[String:String]]) {
        guard let merchantId = STPPaymentConfiguration.shared().appleMerchantIdentifier else { return }
        
        if  let uiAppDelegate = UIApplication.shared.delegate,
            let tempWindow = uiAppDelegate.window,
            let window = tempWindow,
            let rootVc = window.rootViewController {
            
            let paymentRequest = Stripe.paymentRequest(withMerchantIdentifier: merchantId, country: "AU", currency: "AUD")
            paymentRequest.paymentSummaryItems = items.compactMap(){(item) -> PKPaymentSummaryItem? in
                if  let label = item["label"],
                    let strAmount = item["amount"] {
                    return PKPaymentSummaryItem(label: label, amount: NSDecimalNumber(string: strAmount))
                }
                return nil
            }
            if let applePayContext = STPApplePayContext(paymentRequest: paymentRequest, delegate: SwiftStripeFlutterPlugin.applePayContextDelegate) {
                // Present Apple Pay payment sheet
                SwiftStripeFlutterPlugin.applePayContextDelegate.setFlutterResult(result)
                applePayContext.presentApplePay(on: rootVc)
            } else {
                // There is a problem with your Apple Pay configuration
            }
        }
    }
}

class FlutterEphemeralKeyProvider : NSObject, STPCustomerEphemeralKeyProvider {
    
    private let channel: FlutterMethodChannel
    
    init(channel: FlutterMethodChannel) {
        self.channel = channel
    }
    
    func createCustomerKey(withAPIVersion apiVersion: String, completion: @escaping STPJSONResponseCompletionBlock) {
        var args = [String:Any?]()
        args["apiVersion"] = apiVersion
        channel.invokeMethod("getEphemeralKey", arguments: args, result: { result in
            let json = result as? String
            
            guard let _json = json else {
                completion(nil, CastMismatchError())
                return
            }
            
            guard let data = _json.data(using: .utf8) else {
                completion(nil, InternalStripeError())
                return
            }
            
            guard let dictionary = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: AnyObject] else {
                completion(nil, InternalStripeError())
                return
            }
            
            guard let _dict = dictionary else {
                completion(nil, InternalStripeError())
                return
            }
            
            completion(_dict, nil)
        })
    }
}

class ApplePayContextDelegate: NSObject, STPApplePayContextDelegate {
    private var flutterResult: FlutterResult? = nil
    
    func setFlutterResult(_ result: @escaping FlutterResult) {
        self.flutterResult = result
    }

    func applePayContext(_ context: STPApplePayContext, didCreatePaymentMethod paymentMethod: STPPaymentMethod, completion: @escaping STPIntentClientSecretCompletionBlock) {
        
    }
    
    func applePayContext(_ context: STPApplePayContext, didCompleteWith status: STPPaymentStatus, error: Error?) {
        switch status {
            case .success:
                self.flutterResult?(true)
                break
            case .error:
                // Payment failed, show the error
                self.flutterResult?(FlutterError(code: "ApplePayError", message: error?.localizedDescription, details: nil))
                break
            case .userCancellation:
                // User cancelled the payment
                self.flutterResult?(false)
                break
            @unknown default:
                self.flutterResult?(false)
        }
    }
}

class PaymentOptionViewControllerDelegate: NSObject,  STPPaymentOptionsViewControllerDelegate {
    
    private var currentPaymentMethod: STPPaymentOption? = nil
    private var flutterResult: FlutterResult? = nil
    private var tuppleResult = [String:Any?]()
    
    var flutterViewController: UIViewController?
    var window: UIWindow?
    
    func setFlutterResult(_ result: @escaping FlutterResult) {
        self.flutterResult = result
    }
    
    func paymentOptionsViewController(_ paymentOptionsViewController: STPPaymentOptionsViewController, didSelect paymentOption: STPPaymentOption) {
        currentPaymentMethod = paymentOption
        print(paymentOption)
        if let source = paymentOption as? STPPaymentMethod {
            print("paymentMethod as STPSource")
            tuppleResult["id"] = source.stripeId
            tuppleResult["last4"] = source.card?.last4
            tuppleResult["brand"] = STPCard.string(from: source.card?.brand ?? STPCardBrand.unknown)
            tuppleResult["expiredYear"] = Int(source.card?.expYear ?? 0)
            tuppleResult["expiredMonth"] = Int(source.card?.expMonth ?? 0)
            tuppleResult["type"] = "Card"
        } else if let applePay = paymentOption as? STPApplePayPaymentOption {
            tuppleResult["label"] = applePay.label
            tuppleResult["type"] = "ApplePay"
        }
    }
    
    func paymentOptionsViewController(_ paymentOptionsViewController: STPPaymentOptionsViewController, didFailToLoadWithError error: Error) {
        closeWindow()
        cleanInstance()
    }
    
    func paymentOptionsViewControllerDidFinish(_ paymentOptionsViewController: STPPaymentOptionsViewController) {
        print(tuppleResult)
        self.flutterResult?(tuppleResult)
        closeWindow()
        cleanInstance()
    }
    
    func paymentOptionsViewControllerDidCancel(_ paymentOptionsViewController: STPPaymentOptionsViewController) {
        closeWindow()
        cleanInstance()
    }
    
    private func closeWindow() {
        if let _window = window, let vc = flutterViewController {
            UIView.transition(with: _window, duration: 0.2, options: .transitionCrossDissolve, animations: {
                _window.rootViewController = vc
            }, completion: nil)
        }
    }
    
    private func cleanInstance() {
        flutterViewController = nil
        window = nil
    }
    
}

class CastMismatchError : Error {
    
}

class InternalStripeError : Error {
    
}
