import 'dart:async';
import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../onepay_paygate_flutter.dart';

class OnePayPaygateView extends StatefulWidget {
  OPPaymentEntity paymentEntity;
  OnPayResult? onPayResult;
  OnPayFail? onPayFail;

  OnePayPaygateView({super.key, required this.paymentEntity, this.onPayResult, this.onPayFail});

  @override
  _OnePayPaygateViewState createState() => _OnePayPaygateViewState();
}

class _OnePayPaygateViewState extends State<OnePayPaygateView> {
  late final WebViewController _webViewController;

  final _appLinks = AppLinks(); // AppLinks is singleton

  @override
  void initState() {
    super.initState();
    // Subscribe to all events (initial link and further)
    _appLinks.uriLinkStream.listen((uri) {
      // Do something (navigation, ...)
      // print("uri: ${uri.toString()}");
      handleDeeplink(uri.toString());
    });

    var url = widget.paymentEntity.createUrlPayment();
    // print("url: $url");
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {
            if (url.startsWith(widget.paymentEntity.returnUrl)) {
              handlePaymentResult(url);
            }
          },
          onPageFinished: (String url) {},
          onHttpError: (HttpResponseError error) {},
          onWebResourceError: (WebResourceError error) {
            var errorResult = OPErrorResult(errorCase: OnePayErrorCase.NOT_CONNECT_WEB_ONEPAY);
            widget.onPayFail?.call(errorResult);
          },
          onNavigationRequest: (NavigationRequest request) {
            var url = request.url;
            // print("url navigation: $url");
            if (url.toLowerCase().startsWith(widget.paymentEntity.returnUrl.toLowerCase())) {
              handlePaymentResult(url);
              return NavigationDecision.prevent;
            }
            if (url.startsWith(OPPaymentEntity.AGAIN_LINK)) {
              return NavigationDecision.prevent;
            }
            if (!url.startsWith("http") && url != "about:blank") {
              // print("url not http: $url");
              openCustomUrl(url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }


  void handleDeeplink(String? deeplink) {
    // var uri = Uri.parse(deeplink);
    if (deeplink == null) {
      return;
    }
    if (deeplink.contains(widget.paymentEntity.returnUrl)) {
      var uri = Uri.parse(deeplink);
      var encryptLink = uri.queryParameters["deep_link"];
      if (encryptLink != null && encryptLink.isNotEmpty) {
        var base64Decoder = const Base64Decoder();
        var deeplinkUri = Uri.parse("${base64Decoder.convert(encryptLink)}");
        var url = deeplinkUri.queryParameters["url"];
        if (url != null && url.isNotEmpty) {
          _webViewController.loadRequest(Uri.parse(url));
        }
        return;
      }
      var url = uri.queryParameters["url"];
      if (url != null && url.isNotEmpty) {
        _webViewController.loadRequest(Uri.parse(url));
        return;
      }
      _webViewController.loadRequest(uri);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: WebViewWidget(controller: _webViewController),
      ),
    );
  }

  void handlePaymentResult(String url) {
    var uri = Uri.parse(url);
    var queries = uri.queryParameters;
    var code = queries["vpc_TxnResponseCode"];
    var isSuccess = false;
    if (code != null && code == "0") {
      isSuccess = true;
    }
    Navigator.pop(context);
    widget.onPayResult?.call(OPPaymentResult(
        isSuccess: isSuccess,
        amount: queries["vpc_Amount"],
        card: queries["vpc_Card"],
        cardNumber: queries["vpc_CardNum"],
        command: queries["vpc_Command"],
        merchTxnRef: queries["vpc_MerchTxnRef"],
        merchant: queries["vpc_Merchant"],
        message: queries["vpc_Message"],
        orderInfo: queries["vpc_OrderInfo"],
        payChannel: queries["vpc_PayChannel"],
        transactionNo: queries["vpc_TransactionNo"],
        version: queries["vpc_Version"]
    ));

  }

  void openCustomUrl(String url) {
    OnePayPaygate.openCustomURL(url);
  }
}