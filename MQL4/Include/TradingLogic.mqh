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
    bool isTradingCondition;

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

        // if (!ut.IsVolatilityAcceptable(Symbol(), 14, 0.01)) {
        //     return false;
        // }

        if (ut.IsWithinTradeInterval(lastTradeTime)) {
            return false;
        }

        return true;
    }

    void Trade() {
        // ローソク足による環境認識(上位足)
        bool isUpTrend = iHigh(NULL, PERIOD_H4, 0) > iHigh(NULL, PERIOD_H4, 1) && iLow(NULL, PERIOD_H4, 0) > iLow(NULL, PERIOD_H4, 1);
        bool isDownTrend = iHigh(NULL, PERIOD_H4, 0) < iHigh(NULL, PERIOD_H4, 1) && iLow(NULL, PERIOD_H4, 0) < iLow(NULL, PERIOD_H4, 1);

        if (!isUpTrend && !isDownTrend) {
            return;
        }

        // 環境認識(下位足) ※調整トレンド発生の確認
        bool isUpTrendFast = iHigh(NULL, PERIOD_M15, 1) > iHigh(NULL, PERIOD_M15, 2) && iLow(NULL, PERIOD_M15, 1) > iLow(NULL, PERIOD_M15, 2);
        bool isDownTrendFast = iHigh(NULL, PERIOD_M15, 1) < iHigh(NULL, PERIOD_M15, 2) && iLow(NULL, PERIOD_M15, 1) < iLow(NULL, PERIOD_M15, 2);

        if (!isUpTrendFast && !isDownTrendFast) {
            return;
        }

        // 執行足の確認
        zzSeeker.UpdateExtremaArray(PERIOD_CURRENT, 5);
        
        // 押し安値
        double prevValleyValue = zzSeeker.GetPrevValleyValue();
        double latstPeak = zzSeeker.GetLatestValue(true);

        // 戻り高値
        double prevPeakValue = zzSeeker.GetPrevPeakValue();
        double latstValley = zzSeeker.GetLatestValue(false);

        // プライスアクション
        // bool isLongLowerWick = cs.IsLongLowerWick(PERIOD_CURRENT, 1, 0.2, 3);
        // bool isLongUpperWick = cs.IsLongUpperWick(PERIOD_CURRENT, 1, 0.2, 3);
        // bool isBullishOutSideBar = cs.IsBullishOutSideBar2(PERIOD_CURRENT, 1);
        // bool isBearishOutSideBar = cs.IsBearishOutSideBar2(PERIOD_CURRENT, 1);
        bool IsThrustUp = cs.IsThrustUp(PERIOD_CURRENT, 1);
        bool IsThrustDown = cs.IsThrustUp(PERIOD_CURRENT, 1);

        bool isBreakOutLong = Close[1] < prevPeakValue && Close[0] > prevPeakValue;
        bool isBreakOutShort = Close[1] > prevValleyValue && Close[0] < prevValleyValue;

        double stopLossPrice = 0;
        double takeProfitPrice = 0;
        int ticket = 0;

        if (OrdersTotal() > 0) {
            return;
        }

        // TODO ある条件下でrr比を*2する処理を入れる
        // 1. 上位足で上昇ダウ中に、下位足でトレンド調整（弱い下落トレンド）が終わり、
        // 2. 戻り高値ブレイクで上昇ダウを形成したらロングエントリ、上位足ダウの高値に到達でクローズ

        // Buy
        if (isBreakOutLong && isDownTrendFast && isUpTrend) {
            stopLossPrice = latstValley;
            // stopLossPrice = AdjustStopLoss("BUY", MarketInfo(NULL, MODE_ASK), stopLossPrice, MinStopLossPips);
            ticket = orderMgr.PlaceBuyOrder("BUY", stopLossPrice, takeProfitPrice, RiskRewardRatio, Magic);
        }

        // Sell
        if (isBreakOutShort && isUpTrendFast && isDownTrend) {
            stopLossPrice = latstPeak;
            // stopLossPrice = AdjustStopLoss("SELL", MarketInfo(NULL, MODE_BID), stopLossPrice, MinStopLossPips);
            ticket = orderMgr.PlaceSellOrder("SELL", stopLossPrice, takeProfitPrice, RiskRewardRatio, Magic);
        }

        if (ticket > 0) {
            lastTradeTime = TimeCurrent();
        }
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