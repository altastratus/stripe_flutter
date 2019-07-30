import Flutter
import UIKit
import Stripe

public class SwiftStripeFlutterPlugin: NSObject, FlutterPlugin {
    
    static var flutterChannel: FlutterMethodChannel!
    static var customerContext: STPCustomerContext?
    
    static var delegateHandler: STPPaymentMethodsViewControllerDelegate!
    
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "stripe_flutter", binaryMessenger: registrar.messenger())
    self.flutterChannel = channel
    let instance = SwiftStripeFlutterPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    
    self.delegateHandler = PaymentMethodsViewControllerDelegate(flutterChannel: self.flutterChannel)
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
        
        result(nil)
    }
    
    func endCustomerSession(_ result: @escaping FlutterResult) {
        SwiftStripeFlutterPlugin.customerContext?.clearCachedCustomer()
        SwiftStripeFlutterPlugin.customerContext = nil
        
        result(nil)
    }
    
    func showPaymentMethodsScreen(_ result: @escaping FlutterResult) {
        guard let _context = SwiftStripeFlutterPlugin.customerContext else {
            result(FlutterError(code: "IllegalStateError",
                                message: "CustomerSession is not properly initialized, have you correctly initialize CustomerSession?",
                                details: nil))
            return
        }
        let vc = STPPaymentMethodsViewController(configuration: STPPaymentConfiguration.shared(),
                                                 theme: STPTheme.default(),
                                                 customerContext: _context,
                                                 delegate: SwiftStripeFlutterPlugin.delegateHandler)
        
        let rootController = UINavigationController(rootViewController: vc)
        let window: UIWindow = ((UIApplication.shared.delegate?.window)!)!
        window.rootViewController = rootController
        
        result(nil)
    }
}

class FlutterEphemeralKeyProvider : NSObject, STPEphemeralKeyProvider {
    
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
            
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            
            guard let data = try? encoder.encode(_json) else {
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

class PaymentMethodsViewControllerDelegate: NSObject,  STPPaymentMethodsViewControllerDelegate {
    
    var flutterChannel: FlutterMethodChannel
    
    init(flutterChannel: FlutterMethodChannel) {
        self.flutterChannel = flutterChannel
    }
    
    func paymentMethodsViewController(_ paymentMethodsViewController: STPPaymentMethodsViewController, didFailToLoadWithError error: Error) {
        
    }
    
    func paymentMethodsViewControllerDidFinish(_ paymentMethodsViewController: STPPaymentMethodsViewController) {
        
    }
    
    func paymentMethodsViewControllerDidCancel(_ paymentMethodsViewController: STPPaymentMethodsViewController) {
        
    }
    
}

class CastMismatchError : Error {
    
}

class InternalStripeError : Error {
    
}
