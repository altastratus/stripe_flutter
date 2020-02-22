package ventures.clade.stripe_flutter;

import android.app.Activity;
import android.content.Intent;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.stripe.android.CustomerSession;
import com.stripe.android.PaymentConfiguration;
import com.stripe.android.StripeError;
import com.stripe.android.model.Customer;
import com.stripe.android.model.PaymentMethod;
import com.stripe.android.view.PaymentMethodsActivityStarter;

import java.util.HashMap;
import java.util.Map;

import io.flutter.Log;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.plugin.common.PluginRegistry.Registrar;

/**
 * StripeFlutterPlugin
 */
public class StripeFlutterPlugin implements MethodCallHandler {
    /**
     * Plugin registration.
     */

    private static Registrar registrar;
    private static MethodChannel channel;

    private static Result flutterResult;

    public static void registerWith(Registrar registrar) {
        final MethodChannel channel = new MethodChannel(registrar.messenger(), "stripe_flutter");
        channel.setMethodCallHandler(new StripeFlutterPlugin());

        StripeFlutterPlugin.registrar = registrar;
        StripeFlutterPlugin.channel = channel;

        registrar.addActivityResultListener(new PluginRegistry.ActivityResultListener() {
            @Override
            public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
                if (requestCode == PaymentMethodsActivityStarter.REQUEST_CODE && resultCode == Activity.RESULT_OK) {
                    handleStripeResult(data);
                }
                return true;
            }
        });
    }

    private static void handleStripeResult(Intent data) {
        PaymentMethodsActivityStarter.Result result = PaymentMethodsActivityStarter.Result.fromIntent(data);
        if (result == null) {
            flutterResult.error("RuntimeError", "Unknown result from stripe activity", null);
            return;
        }
        @Nullable PaymentMethod paymentMethod = result.component1();
        if (paymentMethod == null) {
            flutterResult.error("RuntimeError", "Unknown result from stripe activity", null);
            return;
        }
        PaymentMethod.Card card = paymentMethod.card;
        if (flutterResult != null) {
            Map<String, Object> cardSource = new HashMap<>();
            if (card != null) {
                cardSource.put("id", paymentMethod.id != null ? paymentMethod.id : "");
                cardSource.put("last4", card.last4 != null ? card.last4 : "");
                cardSource.put("brand", card.brand != null ? card.brand : "");
                cardSource.put("expiredYear", card.expiryYear != null ? card.expiryYear : 0);
                cardSource.put("expiredMonth", card.expiryMonth != null ? card.expiryMonth : 0);
            } else {
                flutterResult.error("RuntimeError", "Unknown result from stripe activity", null);
                return;
            }
            flutterResult.success(cardSource);
        }
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        flutterResult = result;
        switch (call.method) {
            case "sendPublishableKey":
                Object args = call.arguments;
                if (call.arguments instanceof Map) {
                    final Map params = (Map) args;
                    Object publishableKey = params.get("publishableKey");
                    if (publishableKey != null)
                        configurePaymentConfiguration(publishableKey.toString());
                    else {
                        result.error("NullPublishableKey", "PublishableKey is Null", null);
                    }
                } else {
                    result.error("NullPublishableKeyResponse", "Response is Null", null);
                }
            case "initCustomerSession":
                initCustomerSession(result);
                break;
            case "endCustomerSession":
                endCustomerSession(result);
                break;
            case "showPaymentMethodsScreen":
                showPaymentMethodsScreen(result);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    private void configurePaymentConfiguration(String publishableKey) {
        PaymentConfiguration.init(registrar.activity(), publishableKey);
    }

    private void initCustomerSession(Result result) {
        CustomerSession.initCustomerSession(registrar.activity(), new FlutterEphemeralKeyProvider(StripeFlutterPlugin.channel));
        result.success(null);
    }

    private void endCustomerSession(Result result) {
        CustomerSession.endCustomerSession();
        result.success(null);
    }

    private void showPaymentMethodsScreen(final Result result) {
        try {
            CustomerSession.getInstance();
        } catch (IllegalStateException unused) {
            result.error("IllegalStateError", "CustomerSession is not properly initialized, have you correctly initialize CustomerSession?", null);
            return;
        }

        CustomerSession.getInstance().retrieveCurrentCustomer(new CustomerSession.CustomerRetrievalListener() {
            @Override
            public void onCustomerRetrieved(@NonNull Customer customer) {
                Log.d("StripeFlutterPlugin", "onCustomerRetrieved");
                PaymentMethodsActivityStarter.Args args = new PaymentMethodsActivityStarter.Args.Builder().build();
                new PaymentMethodsActivityStarter(StripeFlutterPlugin.registrar.activity()).startForResult(args);
            }

            @Override
            public void onError(int errorCode, @Nullable String errorMessage, @Nullable StripeError stripeError) {
                Log.d("StripeFlutterPlugin", "onError");
                result.error("RuntimeError", errorCode + " - " + errorMessage, null);
            }
        });
    }
}
