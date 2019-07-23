import 'package:flutter/material.dart';
import 'package:stripe_flutter/stripe_flutter.dart';
import 'package:http/http.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    StripeFlutter.initialize("pk_test_YTD3ZBxycJjtRZFQPfCYq9vp");
    StripeFlutter.initCustomerSession(MyEphemeralKeyProvider());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: ListView(
          children: <Widget>[
            InkWell(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("Show Manage Payments"),
              ),
              onTap: _showManagePayments,
            )
          ],
        ),
      ),
    );
  }

  void _showManagePayments() async {
    StripeFlutter.showPaymentMethodsScreen();
  }
}

class MyEphemeralKeyProvider extends EphemeralKeyProvider {
  @override
  Future<String> createEphemeralKey(String apiVersion) async {
    final params = Map<String, String>();
    params["api_version"] = apiVersion;
    final response = await post("https://sample-stripe-api.herokuapp.com/ephemeral_keys", body: params);
    return response.body;
  }

}