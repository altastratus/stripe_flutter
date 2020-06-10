package ventures.clade.stripe_flutter;

import android.content.Context;

import androidx.annotation.NonNull;

import com.google.android.gms.wallet.IsReadyToPayRequest;
import com.google.android.gms.wallet.PaymentDataRequest;
import com.stripe.android.GooglePayConfig;
import com.stripe.android.PaymentConfiguration;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

class GooglePayHelper {
    @NonNull
    static IsReadyToPayRequest createIsReadyToPayRequest() throws JSONException {
        final JSONArray allowedAuthMethods = new JSONArray();
        allowedAuthMethods.put("PAN_ONLY");
        allowedAuthMethods.put("CRYPTOGRAM_3DS");

        final JSONArray allowedCardNetworks = new JSONArray();
        allowedCardNetworks.put("AMEX");
        allowedCardNetworks.put("DISCOVER");
        allowedCardNetworks.put("JCB");
        allowedCardNetworks.put("MASTERCARD");
        allowedCardNetworks.put("VISA");

        final JSONObject isReadyToPayRequestJson = new JSONObject();
        isReadyToPayRequestJson.put("allowedAuthMethods", allowedAuthMethods);
        isReadyToPayRequestJson.put("allowedCardNetworks", allowedCardNetworks);

        return IsReadyToPayRequest.fromJson(isReadyToPayRequestJson.toString());
    }


    @NonNull
    static PaymentDataRequest createPaymentDataRequest(Context context, String merchantName, String totalPrice) throws JSONException {
        final JSONObject tokenizationSpec;
        tokenizationSpec = new GooglePayConfig(
                PaymentConfiguration.getInstance(context).getPublishableKey()
        ).getTokenizationSpecification();

        final JSONArray allowedAuthMethods = new JSONArray()
                .put("PAN_ONLY")
                .put("CRYPTOGRAM_3DS");

        final JSONArray allowedCardNetworks = new JSONArray()
                .put("AMEX")
                .put("DISCOVER")
                .put("JCB")
                .put("MASTERCARD")
                .put("VISA");

        final JSONObject cardPaymentMethod = new JSONObject()
                .put("type", "CARD")
                .put(
                        "parameters",
                        new JSONObject()
                                .put("allowedAuthMethods", allowedAuthMethods)
                                .put("allowedCardNetworks", allowedCardNetworks)

                                // require billing address
                                .put("billingAddressRequired", true)
                                .put(
                                        "billingAddressParameters",
                                        new JSONObject()
                                                // require full billing address
                                                .put("format", "FULL")

                                                // require phone number
                                                .put("phoneNumberRequired", true)
                                )
                )
                .put("tokenizationSpecification", tokenizationSpec);

        // create PaymentDataRequest
        final String paymentDataRequest = new JSONObject()
                .put("apiVersion", 2)
                .put("apiVersionMinor", 0)
                .put("allowedPaymentMethods", new JSONArray().put(cardPaymentMethod))
                .put("transactionInfo", new JSONObject()
                        .put("totalPrice", String.valueOf(totalPrice))
                        .put("totalPriceStatus", "FINAL")
                        .put("currencyCode", "AUD")
                )
                .put("merchantInfo", new JSONObject().put("merchantName", merchantName))

                // require email address
                .put("emailRequired", true)
                .toString();

        return PaymentDataRequest.fromJson(paymentDataRequest);
    }
}
