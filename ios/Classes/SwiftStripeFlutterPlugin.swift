import Flutter
import UIKit
import Stripe

public class SwiftStripeFlutterPlugin: NSObject, FlutterPlugin {
    
    static var flutterChannel: FlutterMethodChannel!
    static var customerContext: STPCustomerContext?
    static var paymentContext: STPPaymentContext?
    
    static var delegateHandler: PaymentOptionViewControllerDelegate!
    
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "stripe_flutter", binaryMessenger: registrar.messenger())
    self.flutterChannel = channel
    let instance = SwiftStripeFlutterPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    
    self.delegateHandler = PaymentOptionViewControllerDelegate()
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
    default:
        result(FlutterMethodNotImplemented)
    }
  }
    
    func configurePaymentConfiguration(publishableKey: String, _ result: @escaping FlutterResult) {
        STPPaymentConfiguration.shared().publishableKey = publishableKey
        
        result(nil)
    }
    
    func initCustomerSession(_ result: @escaping FlutterResult) {
        let flutterEphemeralKeyProvider = FlutterEphemeralKeyProvider(channel: SwiftStripeFlutterPlugin.flutterChannel)
        SwiftStripeFlutterPlugin.customerContext = STPCustomerContext(keyProvider: flutterEphemeralKeyProvider)
        if let context = SwiftStripeFlutterPlugin.customerContext {
            SwiftStripeFlutterPlugin.paymentContext = STPPaymentContext(customerContext: context)
        }
        result(nil)
    }
    
    func endCustomerSession(_ result: @escaping FlutterResult) {
        SwiftStripeFlutterPlugin.customerContext?.clearCache()
        SwiftStripeFlutterPlugin.customerContext = nil
        
        result(nil)
    }
    
    func getSelectedOption(_ result: @escaping FlutterResult) {
        if let customerContext = SwiftStripeFlutterPlugin.customerContext {
            result(STPPaymentContext(customerContext: customerContext).selectedPaymentOption?.description)
        } else {
            result(nil)
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
        print("didSelectPaymentMethod")
        currentPaymentMethod = paymentOption
        print(paymentOption)
        if let source = paymentOption as? STPPaymentMethod {
            print("paymentMethod as STPSource")
            tuppleResult["id"] = source.stripeId
            tuppleResult["last4"] = source.card?.last4
            tuppleResult["brand"] = STPCard.string(from: source.card?.brand ?? STPCardBrand.unknown)
            tuppleResult["expiredYear"] = Int(source.card?.expYear ?? 0)
            tuppleResult["expiredMonth"] = Int(source.card?.expMonth ?? 0)
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
