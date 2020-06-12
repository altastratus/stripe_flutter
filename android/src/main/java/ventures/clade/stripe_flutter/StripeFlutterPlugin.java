package ventures.clade.stripe_flutter;

import android.app.Activity;
import android.content.Intent;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.android.gms.common.api.Status;
import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;
import com.google.android.gms.wallet.AutoResolveHelper;
import com.google.android.gms.wallet.IsReadyToPayRequest;
import com.google.android.gms.wallet.PaymentData;
import com.google.android.gms.wallet.PaymentDataRequest;
import com.google.android.gms.wallet.PaymentsClient;
import com.google.android.gms.wallet.Wallet;
import com.google.android.gms.wallet.WalletConstants;
import com.stripe.android.ApiResultCallback;
import com.stripe.android.CustomerSession;
import com.stripe.android.PaymentConfiguration;
import com.stripe.android.Stripe;
import com.stripe.android.StripeError;
import com.stripe.android.model.Customer;
import com.stripe.android.model.CustomerSource;
import com.stripe.android.model.PaymentMethod;
import com.stripe.android.model.PaymentMethodCreateParams;
import com.stripe.android.view.PaymentMethodsActivityStarter;

import org.jetbrains.annotations.NotNull;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
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

    private static Stripe stripe;
    private PaymentsClient paymentsClient;

    private static final int LOAD_PAYMENT_DATA_REQUEST_CODE = 53;


    public static void registerWith(Registrar registrar) {
        final MethodChannel channel = new MethodChannel(registrar.messenger(), "stripe_flutter");
        channel.setMethodCallHandler(new StripeFlutterPlugin());

        StripeFlutterPlugin.registrar = registrar;
        StripeFlutterPlugin.channel = channel;

        registrar.addActivityResultListener(new PluginRegistry.ActivityResultListener() {
            @Override
            public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
                if (requestCode == PaymentMethodsActivityStarter.REQUEST_CODE) {
                    if (resultCode == Activity.RESULT_OK) {
                        handleStripeResult(data);
                    } else {
                        flutterResult.success(null);
                    }
                } else if (requestCode == LOAD_PAYMENT_DATA_REQUEST_CODE) {
                    handelGooglePayResult(resultCode, data);
                }
                return true;
            }
        });
    }

    private static void handleStripeResult(Intent data) {
        PaymentMethodsActivityStarter.Result result = PaymentMethodsActivityStarter.Result.fromIntent(data);
        if (result == null) {
            flutterResult.success(null);
            return;
        }
        @Nullable PaymentMethod paymentMethod = result.component1();
        if (paymentMethod == null) {
            flutterResult.error("RuntimeError", "Unknown result from stripe activity", null);
            return;
        }
        if (flutterResult != null) {
            Map<String, Object> cardSource = Utils.toCardSourceMap(paymentMethod);
            if (cardSource != null) {
                flutterResult.success(cardSource);
            } else {
                flutterResult.error("RuntimeError", "Unknown result from stripe activity", null);
            }
        }
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        flutterResult = result;
        Object args = call.arguments;
        switch (call.method) {
            case "sendPublishableKey":
                if (call.arguments instanceof Map) {
                    final Map params = (Map) args;
                    Object publishableKey = params.get("publishableKey");
                    if (publishableKey != null) {
                        stripe = new Stripe(registrar.context(), publishableKey.toString());
                        configurePaymentConfiguration(publishableKey.toString());
                    } else {
                        result.error("NullPublishableKey", "PublishableKey is Null", null);
                    }
                } else {
                    result.error("NullPublishableKeyResponse", "Response is Null", null);
                }
                break;
            case "initCustomerSession":
                initCustomerSession(result);
                break;
            case "endCustomerSession":
                endCustomerSession(result);
                break;
            case "getCustomerDefaultSource":
                getCustomerDefaultSource(result);
                break;
            case "getCustomerPaymentMethods":
                getCustomerPaymentMethods(result);
                break;
            case "showPaymentMethodsScreen":
                showPaymentMethodsScreen(result);
                break;
            case "initGooglePay":
                if (call.arguments instanceof Map) {
                    final Map params = (Map) args;
                    Object environment = params.get("environment");
                    if (environment != null)
                        initGooglePay(environment.toString());
                    else {
                        result.error("INVALID_ARG", "WalletEnvironment is Null", null);
                    }
                } else {
                    result.error("INVALID_ARG", "Invalid environment parameter", null);
                }
                break;
            case "payUsingGooglePay":
                if (call.arguments instanceof Map) {
                    final Map params = (Map) args;
                    Object merchantName = params.get("merchant_name");
                    if (!(merchantName instanceof String)) {
                        result.error("INVALID_ARG", "Invalid merchantName argument", null);
                        return;
                    }
                    Object totalPrice = params.get("total_price");
                    if (!(totalPrice instanceof String)) {
                        result.error("INVALID_ARG", "Invalid totalPrice argument", null);
                        return;
                    }
                    payUsingGooglePay(merchantName.toString(), totalPrice.toString());
                } else {
                    result.error("INVALID_ARG", "Invalid environment parameter", null);
                }
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

    private void getCustomerDefaultSource(final Result result) {
        try {
            CustomerSession.getInstance();
        } catch (IllegalStateException unused) {
            result.error("IllegalStateError", "CustomerSession is not properly initialized, have you correctly initialize CustomerSession?", null);
            return;
        }
        CustomerSession.getInstance().retrieveCurrentCustomer(new CustomerSession.CustomerRetrievalListener() {
            @Override
            public void onCustomerRetrieved(@NotNull Customer customer) {
                String defaultSource = customer.getDefaultSource();
                if (defaultSource != null) {
                    CustomerSource cSource = customer.getSourceById(defaultSource);
                    if (cSource != null) {
                        result.success(Utils.toCardSourceMapFromCard(cSource.asCard()));
                    }
                }
                result.success(null);
            }

            @Override
            public void onError(int errorCode, @NotNull String errorMessage, @org.jetbrains.annotations.Nullable StripeError stripeError) {
                result.error("RETRIEVE_CUSTOMER_FAILED", errorCode + " - " + errorMessage, null);
            }
        });
    }

    private void getCustomerPaymentMethods(final Result result) {
        try {
            CustomerSession.getInstance().getPaymentMethods(PaymentMethod.Type.Card, new CustomerSession.PaymentMethodsRetrievalListener() {
                @Override
                public void onPaymentMethodsRetrieved(@NotNull List<PaymentMethod> list) {
                    List<Map<String, Object>> mapList = new ArrayList<>();
                    for (int i=0; i < list.size(); i++) {
                        mapList.add(Utils.toCardSourceMap(list.get(i)));
                    }
                    result.success(mapList);
                }

                @Override
                public void onError(int errorCode, @NotNull String message, @org.jetbrains.annotations.Nullable StripeError stripeError) {
                    result.error("RETRIEVE_PAYMENT_METHODS_FAILED", errorCode + " - " + message, null );
                }
            });
        } catch (IllegalStateException unused) {
            result.error("IllegalStateError", "CustomerSession is not properly initialized, have you correctly initialize CustomerSession?", null);
        } catch (Exception exception) {
            result.error("UNKNOWN_ERROR", exception.getLocalizedMessage(), null);
        }
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

    private void initGooglePay(String environment) {
        int walletEnv = WalletConstants.ENVIRONMENT_TEST;
        if (environment.equalsIgnoreCase("production")) {
            walletEnv = WalletConstants.ENVIRONMENT_PRODUCTION;
        }
        paymentsClient = Wallet.getPaymentsClient(registrar.activity(),
                new Wallet.WalletOptions.Builder().setEnvironment(walletEnv).build());

        final IsReadyToPayRequest request;
        try {
            request = GooglePayHelper.createIsReadyToPayRequest();
            paymentsClient.isReadyToPay(request)
                    .addOnCompleteListener(
                            new OnCompleteListener<Boolean>() {
                                public void onComplete(@NotNull Task<Boolean> task) {
                                    if (task.isSuccessful()) {
                                        flutterResult.success(true);
                                    } else {
                                        Exception e = task.getException();
                                        if (e != null) {
                                            e.printStackTrace();
                                            flutterResult.error("FAILED_REQUEST", e.getLocalizedMessage(), null);
                                        } else {
                                            flutterResult.success(false);
                                        }
                                    }
                                }
                            }
                    );
        } catch (JSONException e) {
            e.printStackTrace();
            flutterResult.error("PARSE_JSON_ERROR", e.getLocalizedMessage(), null);
        }
    }

    private void payUsingGooglePay(String merchantName, String totalPrice) {
        PaymentDataRequest request;
        try {
            request = GooglePayHelper.createPaymentDataRequest(registrar.activity(), merchantName, totalPrice);
            AutoResolveHelper.resolveTask(
                    paymentsClient.loadPaymentData(request),
                    registrar.activity(),
                    LOAD_PAYMENT_DATA_REQUEST_CODE
            );
        } catch (JSONException e) {
            e.printStackTrace();
            flutterResult.error("FAILED_CREATE_REQUEST", e.getLocalizedMessage(), null);
        }
    }

    private static void setPaymentMethodAsDefault(PaymentMethod paymentMethod) {
        if (paymentMethod.id == null || paymentMethod.type == null) return;
        CustomerSession.getInstance().setCustomerDefaultSource(paymentMethod.id, paymentMethod.type.code, new CustomerSession.CustomerRetrievalListener() {
            @Override
            public void onCustomerRetrieved(@NotNull Customer customer) {
            }

            @Override
            public void onError(int i, @NotNull String s, @org.jetbrains.annotations.Nullable StripeError stripeError) {
                System.out.println(s);
                String code = stripeError != null && stripeError.getCode() != null ? stripeError.getCode() : "ERROR";
                String msg = stripeError != null && stripeError.getMessage() != null ? stripeError.getMessage() : "UNKNOWN ERROR";
                Log.e(code, msg);
            }
        });
    }

    private static void doNativeCheckout(final PaymentMethod paymentMethod) {
        Map<String, Object> cardSource = Utils.toCardSourceMap(paymentMethod);
        if (cardSource == null) {
            flutterResult.error("RuntimeError", "Unknown result", null);
            return;
        }
        channel.invokeMethod("doNativePaymentCheckout", cardSource, new MethodChannel.Result() {
            @Override
            public void success(Object result) {
                if (result instanceof HashMap) {
                    HashMap mapResult = (HashMap) result;
                    Map<String, Object> checkoutResult = new HashMap<>();

                    Object isSuccess = mapResult.containsKey("isSuccess") &&
                            mapResult.get("isSuccess") != null
                            ? mapResult.get("isSuccess") : false;
                    checkoutResult.put("success", isSuccess != null ? isSuccess : false);

                    Object argument = mapResult.get("argument");
                    if (argument != null) checkoutResult.put("arg", argument);

                    flutterResult.success(checkoutResult);
                    setPaymentMethodAsDefault(paymentMethod);
                }
            }

            @Override
            public void error(String errorCode, String errorMessage, Object errorDetails) {
                flutterResult.error(errorCode, errorMessage, null);
            }

            @Override
            public void notImplemented() {
                flutterResult.notImplemented();
            }
        });
    }

    private static void createAndDoCheckout(PaymentMethodCreateParams paymentMethodCreateParams) {
        stripe.createPaymentMethod(
                paymentMethodCreateParams,
                new ApiResultCallback<PaymentMethod>() {
                    @Override
                    public void onSuccess(@NonNull PaymentMethod result) {
                        doNativeCheckout(result);
                    }

                    @Override
                    public void onError(@NonNull Exception e) {
                        flutterResult.error("CREATE_PM_ERROR", e.getLocalizedMessage(), null);
                    }
                }
        );
    }

    private static void onGooglePayResult(@NonNull Intent data) {
        final PaymentData paymentData = PaymentData.getFromIntent(data);
        if (paymentData == null) {
            Map<String, Object> checkoutResult = new HashMap<>();
            checkoutResult.put("success", false);
            flutterResult.success(checkoutResult);
            return;
        }

        // Get and check if selected card from google pay is already saved on stripe customer
        CustomerSession.getInstance().getPaymentMethods(PaymentMethod.Type.Card, new CustomerSession.PaymentMethodsRetrievalListener() {
            @Override
            public void onPaymentMethodsRetrieved(@NotNull List<PaymentMethod> list) {
                try {
                    final PaymentMethodCreateParams paymentMethodCreateParams =
                            PaymentMethodCreateParams.createFromGooglePay(new JSONObject(paymentData.toJson()));
                    PaymentMethod savedPaymentMethod = Utils.getSameCardFromSavedPaymentMethods(paymentData, list);

                    if (savedPaymentMethod != null) {
                        doNativeCheckout(savedPaymentMethod);
                    } else {
                        createAndDoCheckout(paymentMethodCreateParams);
                    }
                } catch (JSONException e) {
                    e.printStackTrace();
                    flutterResult.error("PARSE_JSON_ERROR", e.getLocalizedMessage(), null);
                }
            }

            @Override
            public void onError(int i, @NotNull String s, @org.jetbrains.annotations.Nullable StripeError stripeError) {
                String code = stripeError != null && stripeError.getCode() != null ? stripeError.getCode() : "ERROR";
                String msg = stripeError != null && stripeError.getMessage() != null ? stripeError.getMessage() : "UNKNOWN ERROR";
                Log.e(code, msg);
                flutterResult.error(code, msg, null);
            }
        });
    }

    private static void handelGooglePayResult(int resultCode, Intent data) {
        switch (resultCode) {
            case Activity.RESULT_OK: {
                if (data != null) onGooglePayResult(data);
                break;
            }
            case Activity.RESULT_CANCELED: {
                // Canceled
                Map<String, Object> checkoutResult = new HashMap<>();
                checkoutResult.put("success", false);
                flutterResult.success(checkoutResult);
                break;
            }
            case AutoResolveHelper.RESULT_ERROR: {
                // Log the status for debugging
                // Generally there is no need to show an error to
                // the user as the Google Payment API will do that
                final Status status = AutoResolveHelper.getStatusFromIntent(data);
                if (status != null) {
                    flutterResult.error("GOOGLE_PAY_ERROR", status.getStatusMessage(), null);
                } else {
                    flutterResult.error("GOOGLE_PAY_ERROR", "Unknown error", null);
                }
                break;
            }
            default: {
                // Do nothing.
                flutterResult.notImplemented();
            }
        }
    }
}
