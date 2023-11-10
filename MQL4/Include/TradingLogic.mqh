// TradingLogic.mqh
input double RiskRewardRatio = 1.0;            // リスクリワード比
input int MinStopLossPips = 10;                // ストップロスの下限(pips)

// Threshold
input int SpreadThresholdPips = 5;             // スプレッド閾値(pips)
input int MaxHoldingMinutes = 60;              // ポジション保有時間の最大(分)

// EA Settings
input int Magic = 19850001;                    // マジックナンバー(EAの識別番号)

#include "ZigzagSeeker.mqh"
#include "OrderManager.mqh"
#include "Candlestick.mqh"
#include "Utility.mqh"

class TradingLogic
{
private:
    // Instances of Classes
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

        // if (!ut.IsVolatilityAcceptable(Symbol(), 4, 0.05)) {
        //     return false;
        // }

        if (ut.IsWithinTradeInterval(lastTradeTime)) {
            return false;
        }

        return true;
    }

    void Trade() {
        // 環境認識
        string trend = cs.GetTrend(PERIOD_M5, 1);
        Comment("Primary: " + trend);

        if (trend == "RANGE") {
            return;
        }

        bool isUpTrend = trend == "UP TREND";
        bool isDownTrend = trend == "DOWN TREND";
        
        // 環境認識(下位足) 
        // string trendFast = cs.GetTrend(PERIOD_M5, 5); // ある程度の値幅がほしい

        // Comment(
        //     "Primary: ", trend, "\n",
        //     "Secondary: ", trendFast, "\n");

        // Comment("Secondary: " + trendFast);

        // if (trendFast == "RANGE") {
        //     return;
        // }

        // bool isUpTrendFast = trendFast == "UP TREND";
        // bool isDownTrendFast = trendFast == "DOWN TREND";

        // Price action
        bool isLongLowerWick = cs.IsLongLowerWick(PERIOD_CURRENT, 1, 0.2, 3);
        bool isLongUpperWick = cs.IsLongUpperWick(PERIOD_CURRENT, 1, 0.2, 3);
        bool isBullishOutSideBar = cs.IsBullishOutSideBar(PERIOD_CURRENT, 1);
        bool isBearishOutSideBar = cs.IsBearishOutSideBar(PERIOD_CURRENT, 1);
        bool IsThrustUp = cs.IsThrustUp(PERIOD_CURRENT, 1);
        bool IsThrustDown = cs.IsThrustUp(PERIOD_CURRENT, 1);

        // 執行足の確認
        zzSeeker.UpdateExtremaArray(PERIOD_CURRENT, 6);
        
        // 押し安値
        double prevValleyValue = zzSeeker.GetPrevValleyValue();
        double latestPeak = zzSeeker.GetLatestValue(true);

        // 戻り高値
        double prevPeakValue = zzSeeker.GetPrevPeakValue();
        double latestValley = zzSeeker.GetLatestValue(false);

        // Execution
        bool isBuy = isUpTrend && Close[1] < prevPeakValue && Close[0] > prevPeakValue && !isLongLowerWick;
        bool isSell = isDownTrend && Close[1] > prevValleyValue && Close[0] < prevValleyValue && !isLongUpperWick;

        double risk = RiskRewardRatio;
        double stopLossPrice = 0;
        double takeProfitPrice = 0;
        double lot = 0;
        int ticket = 0;

        if (OrdersTotal() > 0) {
            return;
        }

        // Buy
        if (isBuy) {
            stopLossPrice = latestValley;
            ticket = orderMgr.PlaceMarketOrder("BUY", stopLossPrice, takeProfitPrice, lot, risk, Magic);
        }

        // Sell
        if (isSell) {
            stopLossPrice = latestPeak;
            ticket = orderMgr.PlaceMarketOrder("SELL", stopLossPrice, takeProfitPrice, lot, risk, Magic);
        }
        
        // if (ticket > 0) {
        //     lastTradeTime = TimeCurrent();
        // }
    }

    // ストップロスの下限を指定したpipsに設定
    double AdjustStopLoss(string order, double currentPrice, double stopLossValue, int minPips) {
        double minStopLoss = 0;

        if (order == "BUY") {
            minStopLoss = currentPrice - ut.PipsToPrice(minPips);
            if (stopLossValue > minStopLoss) {
                return minStopLoss;
            }
        } else if (order == "SELL") {
            minStopLoss = currentPrice + ut.PipsToPrice(minPips);
            if (stopLossValue < minStopLoss) {
                return minStopLoss;
            }
        }
        
        return stopLossValue;
    }

};