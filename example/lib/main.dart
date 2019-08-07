import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:stripe_flutter/stripe_flutter.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String selectedSourceID;

  @override
  void initState() {
    super.initState();
    StripeFlutter.initialize("CHANGE_WITH_YOUR_PUBLISHABLE_KEY");
    StripeFlutter.initCustomerSession(MyEphemeralKeyProvider());
    StripeFlutter.onSourceSelected = this.onSourceSelected;
  }

  void onSourceSelected(Map<String, String> data) {
    print(json.encode(data));
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
            ),
            Container(
              padding: const EdgeInsets.all(16.0),
              child: Text("Selected = " + (selectedSourceID ?? "null")),
            )
          ],
        ),
      ),
    );
  }

  void _showManagePayments() async {
    StripeFlutter.showPaymentMethodsScreen().then((result) {
      setState(() {
        this.selectedSourceID =
        "${result.brand} ${result.last4} (${result
            .sourceId}) expired on ${result.expiredMonth}/${result
            .expiredYear}";
      });
    });
  }
}

class MyEphemeralKeyProvider extends EphemeralKeyProvider {
  @override
  Future<String> createEphemeralKey(String apiVersion) async {
    final params = Map<String, String>();
    params["api_version"] = apiVersion;
    final response = await post(
        "https://sample-stripe-api.herokuapp.com/ephemeral_keys",
        body: params);
    final body = response.body;
    return body;
  }
}
