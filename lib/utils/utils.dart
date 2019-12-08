import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import 'dart:io';
import 'package:hex/hex.dart';
import 'package:convert_hex/convert_hex.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:http/http.dart' as http;
import './config.dart';

DateFormat headingDateFormat = new DateFormat("EEE, MMM d, ''yy");

class HexColor extends Color {
  static int _getColorFromHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF" + hexColor;
    }
    return int.parse(hexColor, radix: 16);
  }

  HexColor(final String hexColor) : super(_getColorFromHex(hexColor));
}

int converttoint(Iterable<int> data) {
  return Hex.decode(HEX.encode(data.toList()));
}

Future<String> getTickers() async {
  final response =
      await http.get("https://api.kite.trade/instruments", headers: {
    "X-Kite-Version": "3",
    "Authorization": "token " + apiKey + ":" + accessToken + ""
  });

  return response.body;
}

SharedPreferences prefs;
Future<bool> initSharedPreference() async {
  prefs = await SharedPreferences.getInstance();
  if (prefs != null) {
    return true;
  }
  return false;
}

bool isMarketOpen() {
  if (holiday) {
    return false;
  }
  if (DateTime.now().isAfter(open) && DateTime.now().isBefore(close)) {
    return true;
  }
  return false;
}

Future<bool> checkInternet() async {
  try {
    final result = await InternetAddress.lookup('google.com');
    if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
      return true;
    }
  } on SocketException catch (_) {
    return false;
  }
  return false;
}

void oneButtonDialog(
    BuildContext context, String title, String content, bool dismiss) {
  showDialog(
    barrierDismissible: false,
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: new Text(title),
        content: content != "" ? new Text(content) : null,
        actions: <Widget>[
          new FlatButton(
            child: new Text("ok"),
            onPressed: () {
              if (dismiss) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      );
    },
  );
}

Future<bool> checkAccessToken() async {
  final response =
      await http.get("https://api.kite.trade/quote/ltp?i=NSE:INFY", headers: {
    "X-Kite-Version": "3",
    "Authorization": "token " + apiKey + ":" + accessToken + ""
  });

  return response.statusCode == 200;
}
