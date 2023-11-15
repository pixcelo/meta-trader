// TradingLogic.mqh
input double RiskRewardRatio = 1.0;            // リスクリワード比
input int MinStopLossPips = 10;                // ストップロスの下限(pips)

// Threshold
input int SpreadThresholdPips = 5;             // スプレッド閾値(pips)
input int MaxHoldingMinutes = 60;              // ポジション保有時間の最大(分)
input int maAnglePeriod = 10;

// EA Settings
input int Magic = 19850001;                    // マジックナンバー(EAの識別番号)

#include "RCICalculator.mqh"
#include "ZigzagSeeker.mqh"
#include "OrderManager.mqh"
#include "Candlestick.mqh"
#include "Utility.mqh"

class TradingLogic
{
private:
    // Instances of Classes
    RCICalculator rciCalc;
    ZigzagSeeker zzSeeker;
    OrderManager orderMgr;
    Candlestick cs;
    Utility ut;

    datetime lastTradeTime;

public:
    void Run() {
        if (IsTradingCondition()) {
            Trade();
        }
    }

private:
    bool IsTradingCondition() {
         if (ut.IsSpreadTooHigh(SpreadThresholdPips)) {
            // Print("Spread too high");
            return false;
        }

        if (OrdersTotal() > 0) {
            // 途中決済
            orderMgr.CheckAndCloseStagnantPositions(MaxHoldingMinutes, Magic);
        }

        // if (!ut.IsVolatilityAcceptable(Symbol(), 4, 0.02)) {
        //     return false;
        // }

        if (ut.IsWithinTradeInterval(lastTradeTime)) {
            return false;
        }

        return true;
    }

    void Trade() {
        // Price action
        // bool isLongLowerWick = cs.IsLongLowerWick(PERIOD_M5, 1, 0.2, 3);
        // bool isLongUpperWick = cs.IsLongUpperWick(PERIOD_M5, 1, 0.2, 3);
        // bool isBullishOutSideBar = cs.IsBullishOutSideBar(PERIOD_CURRENT, 1);
        // bool isBearishOutSideBar = cs.IsBearishOutSideBar(PERIOD_CURRENT, 1);
        // bool IsThrustUp = cs.IsThrustUp(PERIOD_CURRENT, 1);
        // bool IsThrustDown = cs.IsThrustUp(PERIOD_CURRENT, 1);

        // 長期の角度・短期の角度の両方を条件に入れると、結果が変化するか？
        double angle = cs.GetMovingAverageSlopeInDegrees(20, MODE_SMA, maAnglePeriod);
        // double angleSlow = cs.GetMovingAverageSlopeInDegrees(20, MODE_SMA, maAnglePeriodSlow);
        // Print("angle ", angle);

        bool isUpTrend = angle >= 5 && cs.IsUpCandle(PERIOD_H1);
        bool isDownTrend = angle <= -5 && cs.IsDownCandle(PERIOD_H1);

        // bool isUpTrend = angle >= 5;// && angleSlow >= 5;
        // bool isDownTrend = angle <= -5;// && angleSlow >= 5;

        string msg = "RANGE";
        if (isUpTrend) {
            msg = "UP TREND";
        }
        if (isDownTrend) {
            msg = "DOWN TREND";
        }
        Comment("Primary: " + msg);

        // bool closeLongPosition = (Close[1] < ma100 && Close[2] > ma100) || isDownTrend;
        // bool closeShortPosition = (Close[1] > ma100 && Close[2] < ma100) || isUpTrend;

        // Close positions
        bool closeLongPosition = isDownTrend;
        bool closeShortPosition =  isUpTrend;

        int closeResult = 0;
        for (int i = OrdersTotal() - 1; i >= 0; i--) {
            if (OrderSelect(i, SELECT_BY_POS) && OrderSymbol() == Symbol() && OrderMagicNumber() == Magic) {
                if (OrderType() == OP_BUY && closeLongPosition) {
                     closeResult = OrderClose(OrderTicket(), OrderLots(), MarketInfo(Symbol(), MODE_BID), 3, clrYellow);
                } else if (OrderType() == OP_SELL && closeShortPosition) {
                     closeResult = OrderClose(OrderTicket(), OrderLots(), MarketInfo(Symbol(), MODE_ASK), 3, clrYellow);
                }
            }
        }
        
        if (OrdersTotal() > 0) {
            return;
        }

        // ロングならCloseが陰線から陽線に変わったタイミング、ショートならCloseが陰線から陽線に変わったタイミング
        // RCIが-80を下回った後に、下げ止まってダウ理論が崩れていなければロング
        // MAの中期線と長期線の傾き

        // Filter
        // bool ma = iMA(NULL, PERIOD_CURRENT, 20, 0, MODE_SMA, PRICE_CLOSE, 0);

        // Execution
        bool isBuy = isUpTrend
                    //  && Close[0] > ma
                     && cs.IsBullishReversal();

        bool isSell = isDownTrend
                    //   && Close[0] < ma
                      && cs.IsBearlishReversal();

        double risk = RiskRewardRatio;
        double stopLossPrice = 0;
        double takeProfitPrice = 0;
        double lot = 0.1;
        int ticket = 0;

        // Entry
        if (isBuy) {
            // stopLossPrice = cs.GetLowestPrice(60) - ut.PipsToPrice(5);
            // stopLossPrice = AdjustStopLoss("BUY", stopLossPrice, 10);
            // stopLossPrice = latestValley;
            stopLossPrice = MarketInfo(Symbol(), MODE_ASK) - ut.PipsToPrice(10);
            takeProfitPrice = MarketInfo(Symbol(), MODE_ASK) +  ut.PipsToPrice(10);
            ticket = orderMgr.PlaceMarketOrder(OP_BUY, stopLossPrice, takeProfitPrice, lot, risk, Magic);
            // takeProfitPrice = MarketInfo(Symbol(), MODE_ASK) + ut.PipsToPrice(5);
            // ticket = OrderSend(Symbol(), OP_BUY, 0.1, MarketInfo(Symbol(), MODE_ASK), 2, 0, takeProfitPrice, "Buy Order", Magic, 0, clrGreen);
        }

        if (isSell) {
            // stopLossPrice = cs.GetHighestPrice(60) + ut.PipsToPrice(5);
            // stopLossPrice = AdjustStopLoss("SELL", stopLossPrice, 10);
            // stopLossPrice = latestPeak;
            stopLossPrice = MarketInfo(Symbol(), MODE_BID) + ut.PipsToPrice(10);
            takeProfitPrice = MarketInfo(Symbol(), MODE_BID) - ut.PipsToPrice(10);
            ticket = orderMgr.PlaceMarketOrder(OP_SELL, stopLossPrice, takeProfitPrice, lot, risk, Magic);
            // ticket = OrderSend(Symbol(), OP_SELL, 0.1, MarketInfo(Symbol(), MODE_BID), 2, 0, takeProfitPrice, "Sell Order", Magic, 0, clrRed);
        }
        
        if (ticket > 0) {
            lastTradeTime = TimeCurrent();
        }
    }

    // ストップロスの下限を指定したpipsに設定
    double AdjustStopLoss(string order, double stopLossValue, int minPips) {
        double minStopLoss = 0;

        if (order == "BUY") {
            minStopLoss = MarketInfo(Symbol(), MODE_ASK) - ut.PipsToPrice(minPips);
            if (stopLossValue > minStopLoss) {
                return minStopLoss;
            }
        } else if (order == "SELL") {
            minStopLoss = MarketInfo(Symbol(), MODE_BID) + ut.PipsToPrice(minPips);
            if (stopLossValue < minStopLoss) {
                return minStopLoss;
            }
        }
        
        return stopLossValue;
    }

};