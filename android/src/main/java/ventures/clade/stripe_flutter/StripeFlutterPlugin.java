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
import com.stripe.android.view.PaymentMethodsActivity;
import com.stripe.android.view.PaymentMethodsActivityStarter;
import io.flutter.Log;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.plugin.common.PluginRegistry.Registrar;

import java.util.Map;

/**
 * StripeFlutterPlugin
 */
public class StripeFlutterPlugin implements MethodCallHandler {
  /**
   * Plugin registration.
   */

  private static Registrar registrar;
  private static MethodChannel channel;

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

  }

  @Override
  public void onMethodCall(MethodCall call, Result result) {
    switch (call.method) {
      case "sendPublishableKey":
        final Map<String, Object> params = (Map) call.arguments;
        configurePaymentConfiguration(params.get("publishableKey").toString());
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
        result.success(null);
      }

      @Override
      public void onError(int errorCode, @Nullable String errorMessage, @Nullable StripeError stripeError) {
        Log.d("StripeFlutterPlugin", "onError");
        result.error("RuntimeError", errorCode + " - " + errorMessage, null);
      }
    });
  }
}
