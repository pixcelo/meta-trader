// OrderManager.mqh

#include "LotManager.mqh"
#include "Utility.mqh"

class OrderManager
{
private:
    LotManager lotMgr;
    Utility ut;

public:
    OrderManager() {
        lotMgr.SetRiskPercentage(2.0);
    }

    int PlaceMarketOrder(int orderType, double stopLoss, double takeProfitPrice, double lot, double riskRewardRatio, int magicNumber) {
        double entryPrice;
        double lotSize;
        string orderComment;
        color orderColor;
        double stopLossPrice = NormalizeDouble(stopLoss, Digits());

        if (orderType == OP_BUY) {
            entryPrice = MarketInfo(Symbol(), MODE_ASK);
            lotSize = lot > 0 ? lot : lotMgr.GetLotSize("BUY", stopLossPrice);
            orderComment = "Buy Order";
            orderColor = clrGreen;
        } else if (orderType == OP_SELL) {
            entryPrice = MarketInfo(Symbol(), MODE_BID);
            lotSize = lot > 0 ? lot : lotMgr.GetLotSize("SELL", stopLossPrice);
            orderComment = "Sell Order";
            orderColor = clrHotPink;
        }

        // テイクプロフィット価格が指定されていない場合、リスクリワード比に基づいて計算
        if (takeProfitPrice <= 0) {
            if (orderType == OP_BUY) {
                takeProfitPrice = NormalizeDouble(entryPrice + (entryPrice - stopLossPrice) * riskRewardRatio, Digits());
            } else {
                takeProfitPrice = NormalizeDouble(entryPrice - (stopLossPrice - entryPrice) * riskRewardRatio, Digits());
            }
        }
    
        int ticket = OrderSend(Symbol(), orderType, lotSize, entryPrice, 2, stopLossPrice, takeProfitPrice, orderComment, magicNumber, 0, orderColor);

        if (ticket < 0) {
            int lastError = GetLastError();
            Print("Error in ", orderComment, ": ", lastError);
        } else {
            // Order was successful
            // Print(orderComment, " successfully placed with ticket: ", ticket);
        }

        return ticket;
    }

    // 全ての注文を閉じる
    void CloseAllOrders() {
        bool result;
        for (int i = OrdersTotal() - 1; i >= 0; i--) {
            if (OrderSelect(i, SELECT_BY_POS)) {
                if (OrderSymbol() == Symbol()) {
                    if (OrderType() == OP_BUY) {
                        result = OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_BID), 2, Green);
                    } else if (OrderType() == OP_SELL) {
                        result = OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_ASK), 2, Red);
                    }
                }
            }
        }
    }

    // 週末にポジションを閉じる（ギャップアップ対策）
    void CloseAllPositionsBeforeWeekend(int hourToClose = 22) {
        // 現在の曜日と時刻を取得
        datetime currentTime = TimeCurrent();
        int dayOfWeek = TimeDayOfWeek(currentTime);
        int currentHour = TimeHour(currentTime);

        // 金曜日で指定された時刻以降である場合
        if (dayOfWeek == 5 && currentHour >= hourToClose) {
            for (int i = OrdersTotal() - 1; i >= 0; i--) {
                if (OrderSelect(i, SELECT_BY_POS) && OrderSymbol() == Symbol()) {
                    bool result = OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), 3, clrNONE);
                }
            }
        }
    }

    // 停滞しているポジションを閉じる（現在価格で決済）
    void CheckAndCloseStagnantPositions(int timeLimitMinutes, int magicNumber) {
        for (int i = 0; i < OrdersTotal(); i++)
        {
            if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            {
                // アクティブなポジションを選択
                if ((OrderType() == OP_BUY || OrderType() == OP_SELL) && OrderMagicNumber() == magicNumber)
                {
                    datetime orderOpenTime = OrderOpenTime();
                    datetime currentTime = TimeCurrent();
                    int timeDiffMinutes = (int)(TimeDiff(currentTime, orderOpenTime) / 60); // 経過時間を分で計算

                    if (timeDiffMinutes >= timeLimitMinutes) // 経過時間が指定された限度以上
                    {
                        bool result = OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), 3, White);
                    }
                }
            }
        }
    }

    // 停滞しているポジションが指定した値幅の範囲内ならポジションを閉じる
    void CheckAndCloseStagnantPositionsInTargetPipsRange(int timeLimitMinutes, double minProfitPips, double maxProfitPips, int magicNumber) {
        for (int i = 0; i < OrdersTotal(); i++)
        {
            if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            {
                // アクティブなポジションを選択
                if ((OrderType() == OP_BUY || OrderType() == OP_SELL) && OrderMagicNumber() == magicNumber)
                {
                    datetime orderOpenTime = OrderOpenTime();
                    datetime currentTime = TimeCurrent();
                    int timeDiffMinutes = (int)(TimeDiff(currentTime, orderOpenTime) / 60); // 経過時間を分で計算

                    if (timeDiffMinutes >= timeLimitMinutes) // 経過時間が指定された限度以上
                    {
                        double pointValue = MarketInfo(OrderSymbol(), MODE_POINT) * ut.GetPointCoefficient();
                        double floatingProfit = OrderProfit() / pointValue; // 浮動損益をpipsで取得
                        if (floatingProfit >= minProfitPips && floatingProfit <= maxProfitPips)
                        {
                            bool result = OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), 3, White); // ポジションを決済
                        }
                    }
                }
            }
        }
    }

    int TimeDiff(datetime startTime, datetime endTime)
    {
        return (int)(startTime - endTime);
    }

    // 利益目標に達していたらポジションを閉じる
    void CloseOrderOnTargetPrice(double targetPoint, int magicNumber) {
        for (int i = 0; i < OrdersTotal(); i++) {
            if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
                if (OrderMagicNumber() == magicNumber) {
                    double diff = 0;

                    // Buy order
                    if (OrderType() == OP_BUY) {
                        diff = MarketInfo(OrderSymbol(), MODE_ASK) - OrderOpenPrice();
                    }
                    // Sell order
                    else if (OrderType() == OP_SELL) {
                        diff = OrderOpenPrice() - MarketInfo(OrderSymbol(), MODE_BID);
                    }

                    // If difference reaches the target, then close the order
                    if (diff > targetPoint) {
                        Print("diff ", diff);
                        Print("targetPoint ", targetPoint);
                        // Close the order
                        bool result = OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), 3, White);

                        if (!result) {
                            Print("Failed to close order. Error: ", GetLastError());
                        }
                    }
                }
            }
        }
    }

    // 指定した方向のポジションを閉じる　OP_BUY=0, OP_SELL=1
    void ClosePositionOnSignal(int closeDirection, int magicNumber) {
        int totalOrders = OrdersTotal();
        
        for (int i = totalOrders - 1; i >= 0; i--) {
            if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
                if (OrderMagicNumber() == magicNumber
                    && OrderSymbol() == Symbol()
                    && OrderType() == closeDirection) {
                    bool result = OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), 3, clrYellow);

                    if (!result) {
                        Print("Failed to close order. Error: ", GetLastError());
                    }
                }
            }
        }
    }
    
    // EMA100を基準に損切り決済
    void CloseWithEMA100(int magicNumber) {
        for (int i = 0; i < OrdersTotal(); i++) {
            if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
                if (OrderMagicNumber() == magicNumber) {
                    double ema = iMA(NULL, 0, 100, 0, MODE_EMA, PRICE_CLOSE, 0);
                    bool shouldClose = false;

                    // Buy order
                    if (OrderType() == OP_BUY) {
                        // EMAを下抜けたら決済する
                        if (Close[0] < ema) {
                            shouldClose = true;
                        }
                    }
                    // Sell order
                    else if (OrderType() == OP_SELL) {
                        // EMAを上抜けたら決済する
                        if (Close[0] > ema) {
                            shouldClose = true;
                        }
                    }

                    if (shouldClose) {
                        // Close the order
                        bool result = OrderClose(OrderTicket(), OrderLots(), (OrderType() == OP_BUY ? Bid : Ask), 3, White);

                        if (!result) {
                            Print("Failed to close order. Error: ", GetLastError());
                        }
                    }
                }
            }
        }
    }

    // ストップロスだけ設定する注文
    int PlaceBuyOrderWithStopLoss(double lotSize, double stopLoss, int magicNumber, color orderColor = Blue) {
        double stopLossPrice = NormalizeDouble(stopLoss, Digits());
        int ticket = OrderSend(Symbol(), OP_BUY, lotSize, Ask, 2, stopLossPrice, 0, "Buy Order", magicNumber, 0, orderColor);

        if (ticket < 0) {
            int lastError = GetLastError();
            Print("Error in Buy Order: ", lastError);
        }

        return ticket;
    }

    int PlaceSellOrderWithStopLoss(double lotSize, double stopLoss, int magicNumber, color orderColor = Orange) {
        double stopLossPrice = NormalizeDouble(stopLoss, Digits());
        int ticket = OrderSend(Symbol(), OP_SELL, lotSize, Bid, 2, stopLossPrice, 0, "Sell Order", magicNumber, 0, orderColor);

        if (ticket < 0) {
            int lastError = GetLastError();
            Print("Error in Sell Order: ", lastError);
        }

        return ticket;
    }

    // トレイリングストップ
    // trailStart: トレイリングストップを開始するためのプロフィット(pips)
    // trailStop: 新しいストップロスと現在の価格との差(pips)
    void ApplyTrailingStop(double trailStart, double trailStop)
    {
        for (int i = OrdersTotal() - 1; i >= 0; i--) {
            if (OrderSelect(i, SELECT_BY_POS)) {
                double currentPrice = 0.0;
                double pointValue = Point * ut.GetPointCoefficient();

                if (OrderType() == OP_BUY) {
                    currentPrice = MarketInfo(OrderSymbol(), MODE_BID);
                    if ((currentPrice - OrderOpenPrice()) > (trailStart * pointValue)) {
                        if ((currentPrice - OrderStopLoss()) > (trailStop * pointValue) || OrderStopLoss() == 0) {
                            double stopLossBuy = currentPrice - (trailStop * pointValue);
                            bool resultBuy = OrderModify(OrderTicket(), OrderOpenPrice(), stopLossBuy, OrderTakeProfit(), 0, Green);
                        }
                    }
                }
                
                if (OrderType() == OP_SELL) {
                    currentPrice = MarketInfo(OrderSymbol(), MODE_ASK);
                    if ((OrderOpenPrice() - currentPrice) > (trailStart * pointValue)) {
                        if ((OrderStopLoss() - currentPrice) > (trailStop * pointValue) || OrderStopLoss() == 0) {
                            double stopLossSell = currentPrice + (trailStop * pointValue);
                            bool resultSell = OrderModify(OrderTicket(), OrderOpenPrice(), stopLossSell, OrderTakeProfit(), 0, Red);
                        }
                    }
                }
            }
        }
    }
    
};
