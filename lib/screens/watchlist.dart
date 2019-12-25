import 'package:flutter/material.dart';
import 'package:mocktrade/screens/reorder.dart';
import 'package:mocktrade/utils/api.dart';
import 'package:mocktrade/utils/models.dart';
import 'dart:convert';
import 'package:web_socket_channel/io.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import './buysell.dart';
import './search.dart';
import '../utils/config.dart';
import '../utils/utils.dart';

class WatchlistsActivity extends StatefulWidget {
  @override
  WatchlistsActivityState createState() {
    return new WatchlistsActivityState();
  }
}

class WatchlistsActivityState extends State<WatchlistsActivity>
    with AutomaticKeepAliveClientMixin<WatchlistsActivity> {
  @override
  bool get wantKeepAlive => true;
  double width = 0;

  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  IOWebSocketChannel channel = IOWebSocketChannel.connect(
      "wss://ws.kite.trade?api_key=" + apiKey + "&access_token=" + accessToken);
  Map<int, double> tickers = new Map();
  Map<int, double> closes = new Map();

  RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  @override
  void initState() {
    super.initState();

    accountsapi();
  }

  void _onRefresh() async {
    accountsapi();
  }

  void accountsapi() {
    checkInternet().then((internet) {
      if (internet == null || !internet) {
        Future<bool> dialog = retryDialog(context, "No Internet connection", "");
        dialog.then((onValue) {
          if (onValue) {
            accountsapi();
          }
        });
        _refreshController.refreshCompleted();
      } else {
        Future<Accounts> data = getAccounts({"user_id": userID});
        data.then((response) {
          _refreshController.refreshCompleted();
          if (response.accounts != null) {
            if (response.accounts.length > 0) {
              prefs.setString("name", response.accounts[0].name);
              amount = double.parse(response.accounts[0].amount);
              marketwatch.clear();
              response.accounts[0].watchlist.split(",").forEach((id) {
                if (tickerMap[id] != null) {
                  marketwatch.add(tickerMap[id]);
                }
              });
              setState(() {
                marketwatch = marketwatch;
              });
              positionsapi();
            } else {
              takeName();
            }
          }
          if (response.meta != null && response.meta.messageType == "1") {
            oneButtonDialog(context, "", response.meta.message,
                !(response.meta.status == STATUS_403));
          }
        });
      }
    });
  }

  takeName() async {
    TextEditingController name = new TextEditingController();
    await showDialog<String>(
        barrierDismissible: false,
        context: context,
        builder: (BuildContext context) {
          return new _SystemPadding(
            child: new AlertDialog(
              contentPadding: const EdgeInsets.all(16.0),
              content: new Row(
                children: <Widget>[
                  new Expanded(
                    child: new TextField(
                      controller: name,
                      autofocus: true,
                      decoration: new InputDecoration(
                          labelText: 'Your Name', hintText: 'eg. John Smith'),
                    ),
                  )
                ],
              ),
              actions: <Widget>[
                new FlatButton(
                    child: const Text('DONE'),
                    onPressed: () {
                      if (name.text.length > 0) {
                         checkInternet().then((internet) {
                          if (internet == null || !internet) {
                            Future<bool> dialog = retryDialog(
                                context, "No Internet connection", "");
                            dialog.then((onValue) {
                              if (onValue) {
                                takeName();
                              }
                            });
                          } else {
                            Future<bool> load = add(
                              API.ACCOUNT,
                              Map.from({
                                "user_id": userID,
                                "name": name.text,
                              }),
                            );
                            load.then((onValue) {
                              prefs.setString("name", name.text);
                              Navigator.of(context).pop();
                            });
                          }
                        });
                      }
                    })
              ],
            ),
          );
        });
  }

  void positionsapi() {
    checkInternet().then((internet) {
      if (internet == null || !internet) {
         Future<bool> dialog = retryDialog(
              context, "No Internet connection", "");
          dialog.then((onValue) {
            if (onValue) {
              takeName();
            }
          });
      } else {
        Future<Positions> data = getPositions({"user_id": userID});
        data.then((response) {
          if (response.positions != null) {
            positionsMap.clear();
            positions.clear();
            if (response.positions.length > 0) {
              response.positions.forEach((position) {
                positionsMap[position.ticker] = position;
                positions.add(position);
              });
            }
            setState(() {
              positionsMap = positionsMap;
              positions = positions;
            });
            fillData();
          }
          if (response.meta != null && response.meta.messageType == "1") {
            oneButtonDialog(context, "", response.meta.message,
                !(response.meta.status == STATUS_403));
          }
        });
      }
    });
  }

  void splitdata(List<int> data) {
    if (data.length < 2) {
      return;
    }
    int noPackets = converttoint(data.getRange(0, 2));

    int j = 2;
    for (var i = 0; i < noPackets; i++) {
      if (converttoint(data.getRange(j, j + 2)) > 40) {
        tickers[converttoint(data.getRange(j + 2, j + 2 + 4))] =
            converttoint(data.getRange(j + 2 + 4, j + 2 + 8)).toDouble() / 100;
        closes[converttoint(data.getRange(j + 2, j + 2 + 4))] =
            converttoint(data.getRange(j + 2 + 40, j + 2 + 44)).toDouble() /
                100;
        j = j + 2 + 44;
      } else {
        tickers[converttoint(data.getRange(j + 2, j + 2 + 4))] =
            converttoint(data.getRange(j + 2 + 4, j + 2 + 8)).toDouble() / 100;
        closes[converttoint(data.getRange(j + 2, j + 2 + 4))] =
            converttoint(data.getRange(j + 2 + 20, j + 2 + 24)).toDouble() /
                100;
        j = j + 2 + 24;
      }
    }
  }

  getData() {
    List<int> ids = new List();

    marketwatch.forEach((f) => ids.add(int.parse(f.instrumentToken)));
    Map<String, dynamic> message = {
      "a": "mode",
      "v": ["quote", ids]
    };
    channel.sink.add(jsonEncode(message));
  }

  fillData() {
    List<String> ids = new List();

    marketwatch.forEach((f) => ids.add(f.instrumentToken));
    fillDataAPI("https://api.kite.trade/quote/ohlc?", ids).then((resp) {
      for (var id in ids) {
        if (resp["data"][id] != null) {
          tickers[int.parse(id)] = resp["data"][id]["last_price"].toDouble();
          closes[int.parse(id)] = resp["data"][id]["ohlc"]["close"].toDouble();
        }
      }
      getData();
    });
  }

  searchPage(BuildContext context, Widget page) async {
    final data = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    ) as String;
    if (data != null && data.length > 0) {
      _scaffoldKey.currentState.showSnackBar(SnackBar(
        content: Text(data),
        duration: Duration(seconds: 3),
      ));
    }
    fillData();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    width = MediaQuery.of(context).size.width;
    return new Scaffold(
      key: _scaffoldKey,
      body: new Container(
        child: new SafeArea(
          child: new Container(
            padding: EdgeInsets.all(20),
            child: new Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                new Text(
                  "MarketWatch",
                  style: TextStyle(
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w800,
                    fontSize: 25,
                  ),
                ),
                new Container(
                  height: 20,
                ),
                new RaisedButton(
                  shape: new RoundedRectangleBorder(
                    borderRadius: new BorderRadius.circular(3.0),
                    side: BorderSide(
                      color: Colors.white,
                    ),
                  ),
                  color: Colors.white,
                  elevation: 10,
                  child: new Container(
                    padding: EdgeInsets.fromLTRB(0, 13, 0, 13),
                    child: new Row(
                      children: <Widget>[
                        new Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        new Container(
                          width: 10,
                        ),
                        new Expanded(
                          child: new Text(
                            "Search & add",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        new Text(
                          marketwatch.length.toString() + "/100",
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        )
                      ],
                    ),
                  ),
                  onPressed: () {
                    searchPage(context, new SearchActivity());
                  },
                ),
                new Container(
                  height: 20,
                ),
                new StreamBuilder(
                  stream: channel.stream,
                  builder: (context, snapshot) {
                    if (snapshot.hasData && marketwatch.length > 0) {
                      splitdata(snapshot.data);
                    }
                    return new Expanded(
                      child: marketwatch.length == 0
                          ? new SmartRefresher(
                              onRefresh: _onRefresh,
                              controller: _refreshController,
                              child: new Center(
                                  child: new Text(
                                      "Use the search bar at the top to add some instruments")),
                            )
                          : new SmartRefresher(
                              onRefresh: _onRefresh,
                              controller: _refreshController,
                              child: new ListView.separated(
                                itemCount: marketwatch.length,
                                separatorBuilder: (context, i) {
                                  return marketwatch[i] == null
                                      ? new Container()
                                      : new Divider();
                                },
                                itemBuilder: (itemContext, i) {
                                  return marketwatch[i] == null
                                      ? new Container()
                                      : new GestureDetector(
                                          onLongPress: () {
                                            searchPage(context,
                                                new ReordersActivity());
                                          },
                                          onTap: () {
                                            if (marketwatch[i].segment !=
                                                "INDICES") {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (context) =>
                                                        new BuySellActivity(
                                                            marketwatch[i]
                                                                .instrumentToken,
                                                            marketwatch[i]
                                                                .tradingSymbol,
                                                            false)),
                                              );
                                            }
                                          },
                                          child: new Container(
                                            color: Colors.transparent,
                                            width: width,
                                            padding: EdgeInsets.fromLTRB(
                                                0, 10, 0, 10),
                                            child: new Column(
                                              children: <Widget>[
                                                new Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: <Widget>[
                                                    new Text(
                                                      marketwatch[i]
                                                          .tradingSymbol,
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                    new Text(
                                                      tickers[int.parse(marketwatch[
                                                                          i]
                                                                      .instrumentToken)] ==
                                                                  null ||
                                                              closes[int.parse(
                                                                      marketwatch[
                                                                              i]
                                                                          .instrumentToken)] ==
                                                                  null
                                                          ? ""
                                                          : tickers[int.parse(
                                                                  marketwatch[i]
                                                                      .instrumentToken)]
                                                              .toStringAsFixed(
                                                                  2),
                                                      style: TextStyle(
                                                        color: tickers[int.parse(
                                                                        marketwatch[i]
                                                                            .instrumentToken)] ==
                                                                    null ||
                                                                closes[int.parse(
                                                                        marketwatch[i]
                                                                            .instrumentToken)] ==
                                                                    null
                                                            ? Colors.black
                                                            : tickers[int.parse(marketwatch[i].instrumentToken)] -
                                                                        closes[int.parse(
                                                                            marketwatch[i].instrumentToken)] >
                                                                    0
                                                                ? Colors.green
                                                                : Colors.red,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                new Container(
                                                  height: 5,
                                                ),
                                                new Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: <Widget>[
                                                    new Row(
                                                      children: <Widget>[
                                                        new Text(
                                                          marketwatch[i]
                                                              .segment,
                                                          style: TextStyle(
                                                            color: Colors.grey,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                        new Container(
                                                          width: 10,
                                                        ),
                                                        positionsMap[marketwatch[
                                                                        i]
                                                                    .instrumentToken] !=
                                                                null
                                                            ? new Icon(
                                                                Icons
                                                                    .card_travel,
                                                                color:
                                                                    Colors.grey,
                                                                size: 15,
                                                              )
                                                            : new Container(),
                                                        new Container(
                                                          width: 10,
                                                        ),
                                                        positionsMap[marketwatch[
                                                                        i]
                                                                    .instrumentToken] !=
                                                                null
                                                            ? new Text(
                                                                positionsMap[marketwatch[
                                                                            i]
                                                                        .instrumentToken]
                                                                    .shares
                                                                    .toString(),
                                                                style:
                                                                    TextStyle(
                                                                  color: Colors
                                                                      .grey,
                                                                  fontSize: 12,
                                                                ))
                                                            : new Container()
                                                      ],
                                                    ),
                                                    new Row(
                                                      children: <Widget>[
                                                        new Text(
                                                          tickers[int.parse(marketwatch[i].instrumentToken)] ==
                                                                      null ||
                                                                  closes[int.parse(marketwatch[i]
                                                                          .instrumentToken)] ==
                                                                      null
                                                              ? ""
                                                              : (tickers[int.parse(marketwatch[i].instrumentToken)] -
                                                                          closes[int.parse(marketwatch[i]
                                                                              .instrumentToken)])
                                                                      .toStringAsFixed(
                                                                          2) +
                                                                  " (" +
                                                                  ((tickers[int.parse(marketwatch[i].instrumentToken)] - closes[int.parse(marketwatch[i].instrumentToken)]) *
                                                                          100 /
                                                                          closes[int.parse(marketwatch[i].instrumentToken)])
                                                                      .toStringAsFixed(2) +
                                                                  "%)",
                                                          style: TextStyle(
                                                            color: Colors.black,
                                                            fontSize: 12,
                                                          ),
                                                        )
                                                      ],
                                                    )
                                                  ],
                                                )
                                              ],
                                            ),
                                          ),
                                        );
                                },
                              ),
                            ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SystemPadding extends StatelessWidget {
  final Widget child;

  _SystemPadding({Key key, this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return new AnimatedContainer(
        duration: const Duration(milliseconds: 300), child: child);
  }
}
