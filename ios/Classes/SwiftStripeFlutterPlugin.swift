import Flutter
import UIKit
import Stripe

public class SwiftStripeFlutterPlugin: NSObject, FlutterPlugin {
    
    static var flutterChannel: FlutterMethodChannel!
    static var customerContext: STPCustomerContext?
    
    static var delegateHandler: PaymentMethodsViewControllerDelegate!
    
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
        if let uiAppDelegate = UIApplication.shared.delegate,
            let tempWindow = uiAppDelegate.window,
            let window = tempWindow,
            let rootVc = window.rootViewController {
            
            SwiftStripeFlutterPlugin.delegateHandler.window = window
            SwiftStripeFlutterPlugin.delegateHandler.flutterViewController = rootVc
            
            let vc = STPPaymentMethodsViewController(configuration: STPPaymentConfiguration.shared(),
                                                     theme: STPTheme.default(),
                                                     customerContext: _context,
                                                     delegate: SwiftStripeFlutterPlugin.delegateHandler)
            
            let uiNavController = UINavigationController(rootViewController: vc)
            
            UIView.transition(with: window, duration: 0.2, options: .transitionCrossDissolve, animations: {
                window.rootViewController = uiNavController
            }, completion: nil)
            
            window.rootViewController = uiNavController

            result(nil)
        
            return
        } else {
            result(FlutterError(code: "IllegalStateError",
                                message: "Root ViewController in Window is currently not available.",
                                details: nil))
            
            return
        }
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

class PaymentMethodsViewControllerDelegate: NSObject,  STPPaymentMethodsViewControllerDelegate {
    
    private let flutterChannel: FlutterMethodChannel
    
    var flutterViewController: UIViewController?
    var window: UIWindow?
    
    init(flutterChannel: FlutterMethodChannel) {
        self.flutterChannel = flutterChannel
    }
    
    func paymentMethodsViewController(_ paymentMethodsViewController: STPPaymentMethodsViewController, didFailToLoadWithError error: Error) {
        closeWindow()
        cleanInstance()
    }
    
    func paymentMethodsViewControllerDidFinish(_ paymentMethodsViewController: STPPaymentMethodsViewController) {
        closeWindow()
        cleanInstance()
    }
    
    func paymentMethodsViewControllerDidCancel(_ paymentMethodsViewController: STPPaymentMethodsViewController) {
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
