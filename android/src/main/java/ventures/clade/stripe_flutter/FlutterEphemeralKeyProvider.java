package ventures.clade.stripe_flutter;

import androidx.annotation.NonNull;
import com.stripe.android.EphemeralKeyProvider;
import com.stripe.android.EphemeralKeyUpdateListener;
import io.flutter.plugin.common.MethodChannel;

import java.util.HashMap;
import java.util.Map;

public final class FlutterEphemeralKeyProvider implements EphemeralKeyProvider {

  private final MethodChannel methodChannel;

  public FlutterEphemeralKeyProvider(MethodChannel methodChannel) {
    this.methodChannel = methodChannel;
  }

  @Override
  public void createEphemeralKey(@NonNull String apiVersion, @NonNull final EphemeralKeyUpdateListener keyUpdateListener) {
    final Map<String, Object> args = new HashMap<>();
    args.put("apiVersion", apiVersion);
    this.methodChannel.invokeMethod("getEphemeralKey", args, new MethodChannel.Result() {
      @Override
      public void success(Object o) {
        if (o instanceof String) {
          String result = (String) o;
          keyUpdateListener.onKeyUpdate(result);
        }
      }

      @Override
      public void error(String s, String s1, Object o) {

      }

      @Override
      public void notImplemented() {

      }
    });
  }
}
