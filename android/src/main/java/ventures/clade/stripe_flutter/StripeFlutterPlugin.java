package ventures.clade.stripe_flutter;

import android.app.Activity;
import android.content.Intent;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.stripe.android.CustomerSession;
import com.stripe.android.PaymentConfiguration;
import com.stripe.android.StripeError;
import com.stripe.android.model.Card;
import com.stripe.android.model.Customer;
import com.stripe.android.model.Source;
import com.stripe.android.model.SourceCardData;
import com.stripe.android.model.StripeSourceTypeModel;
import com.stripe.android.view.PaymentMethodsActivity;
import com.stripe.android.view.PaymentMethodsActivityStarter;

import org.json.JSONException;
import org.json.JSONObject;

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

    private static final int STRIPE_PAYMENT_METHODS_REQUEST_ID = 911;

    public static void registerWith(Registrar registrar) {
        final MethodChannel channel = new MethodChannel(registrar.messenger(), "stripe_flutter");
        channel.setMethodCallHandler(new StripeFlutterPlugin());

        StripeFlutterPlugin.registrar = registrar;
        StripeFlutterPlugin.channel = channel;

        registrar.addActivityResultListener(new PluginRegistry.ActivityResultListener() {
            @Override
            public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
                if (requestCode == STRIPE_PAYMENT_METHODS_REQUEST_ID && resultCode == Activity.RESULT_OK) {
                    handleStripeResult(data);
                }
                return true;
            }
        });
    }

    private static void handleStripeResult(Intent data) {
        String selectedSource = data.getStringExtra(PaymentMethodsActivity.EXTRA_SELECTED_PAYMENT);
        try {
            JSONObject jsonSource = new JSONObject(selectedSource);
            Card card = Card.fromJson(jsonSource);
            Source source = Source.fromJson(jsonSource);
            if (flutterResult != null) {
                Map<String, Object> cardSource = new HashMap<>();
                if (card != null) {
                    cardSource.put("id", card.getId() != null ? card.getId() : "");
                    cardSource.put("last4", card.getLast4() != null ? card.getLast4() : "");
                    cardSource.put("brand", card.getBrand() != null ? card.getBrand() : "");
                    cardSource.put("expiredYear", card.getExpYear() != null ? card.getId() : 0);
                    cardSource.put("expiredMonth", card.getExpMonth() != null ? card.getId() : 0);
                } else if (source != null) {
                    StripeSourceTypeModel sourceTypeModel = source.getSourceTypeModel();
                    if (sourceTypeModel instanceof SourceCardData) {
                        SourceCardData sourceCardData = (SourceCardData) sourceTypeModel;
                        cardSource.put("id", source.getId() != null ? source.getId() : "");
                        cardSource.put("last4", sourceCardData.getLast4() != null ? sourceCardData.getLast4() : "");
                        cardSource.put("brand", sourceCardData.getBrand() != null ? sourceCardData.getBrand() : "");
                        cardSource.put("expiredYear", sourceCardData.getExpiryYear() != null ? sourceCardData.getExpiryYear() : 0);
                        cardSource.put("expiredMonth", sourceCardData.getExpiryMonth() != null ? sourceCardData.getExpiryMonth() : 0);
                    } else {
                        flutterResult.error("RuntimeError", "Unknown SourceTypeModel", null);
                        return;
                    }
                } else {
                    flutterResult.error("RuntimeError", "Unknown result from stripe activity", null);
                    return;
                }
                flutterResult.success(cardSource);
            }
        } catch (JSONException e) {
            e.printStackTrace();
            flutterResult.error("RuntimeError", "Error when parsing selected payment json", null);
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
        PaymentConfiguration.init(publishableKey);
    }

    private void initCustomerSession(Result result) {
        CustomerSession.initCustomerSession(new FlutterEphemeralKeyProvider(StripeFlutterPlugin.channel));
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
                new PaymentMethodsActivityStarter(StripeFlutterPlugin.registrar.activity()).startForResult(STRIPE_PAYMENT_METHODS_REQUEST_ID);
            }

            @Override
            public void onError(int errorCode, @Nullable String errorMessage, @Nullable StripeError stripeError) {
                Log.d("StripeFlutterPlugin", "onError");
                result.error("RuntimeError", errorCode + " - " + errorMessage, null);
            }
        });
    }
}
