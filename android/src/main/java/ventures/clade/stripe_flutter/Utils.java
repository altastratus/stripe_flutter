package ventures.clade.stripe_flutter;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.android.gms.wallet.PaymentData;
import com.stripe.android.model.Card;
import com.stripe.android.model.PaymentMethod;

import org.jetbrains.annotations.NotNull;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

class Utils {
    static Map<String, Object> toCardSourceMap(@Nullable PaymentMethod paymentMethod) {
        if (paymentMethod != null) {
            PaymentMethod.Card card = paymentMethod.card;
            Map<String, Object> cardSource = new HashMap<>();
            if (card != null) {
                cardSource.put("id", paymentMethod.id != null ? paymentMethod.id : "");
                cardSource.put("last4", card.last4 != null ? card.last4 : "");
                cardSource.put("brand", card.brand != null ? card.brand : "");
                cardSource.put("expiredYear", card.expiryYear != null ? card.expiryYear : 0);
                cardSource.put("expiredMonth", card.expiryMonth != null ? card.expiryMonth : 0);
                return cardSource;
            } else return null;
        } else return null;
    }

    static Map<String, Object> toCardSourceMapFromCard(@Nullable Card card) {
            Map<String, Object> cardSource = new HashMap<>();
            if (card != null) {
                cardSource.put("id", card.getId() != null ? card.getId() : "");
                cardSource.put("last4", card.getLast4() != null ? card.getLast4() : "");
                cardSource.put("brand", card.getBrand().getCode());
                cardSource.put("expiredYear", card.getExpYear() != null ? card.getExpYear() : 0);
                cardSource.put("expiredMonth", card.getExpMonth() != null ? card.getExpMonth() : 0);
                return cardSource;
            } else return null;
    }

    static PaymentMethod getSameCardFromSavedPaymentMethods(
            @NonNull PaymentData paymentData,
            @NotNull List<PaymentMethod> paymentMethods
    ) throws JSONException {

        JSONObject jsonObject = new JSONObject(paymentData.toJson());
        JSONObject gpmData = jsonObject.getJSONObject("paymentMethodData");
        final String gtype = gpmData.getString("type");
        JSONObject gInfo = gpmData.getJSONObject("info");
        final String gLast4 = gInfo.getString("cardDetails");
        final String gBrand = gInfo.getString("cardNetwork");

        for (int i = 0; i < paymentMethods.size(); i++) {
            PaymentMethod.Type pmType = paymentMethods.get(i).type;
            if (pmType != null && !pmType.code.equalsIgnoreCase(gtype)) continue;

            PaymentMethod.Card card = paymentMethods.get(i).card;
            if (card != null) {
                if (card.last4 != null && !card.last4.equalsIgnoreCase(gLast4)) {
                    System.out.println(card.last4);
                    continue;
                }
                if (card.brand != null && !card.brand.equalsIgnoreCase(gBrand)) {
                    System.out.println(card.brand);
                    continue;
                }
            }
            return paymentMethods.get(i);
        }
        return null;
    }
}
