// TradingLogic.mqh
input double LargeCandleBodyPips = 5.0;        // 大陽線・大陰線のローソク足の実体のpips
input double RiskRewardRatio = 1.0;            // リスクリワード比
input int MinStopLossPips = 10;                // ストップロスの下限(pips)

// Zigzag
input int Depth = 7;                           // ZigzagのDepth設定
input int Deviation = 5;                       // ZigzagのDeviation設定
input int Backstep = 3;                        // ZigzagのBackstep設定
input int zigzagArrayLength = 12;              // 極値を保持する配列の要素数

// Threshold
input int SpreadThresholdPips = 5;             // スプレッド閾値(pips)
input int MaxHoldingMinutes = 60;              // ポジション保有時間の最大(分)

// EA Settings
input int Magic = 19850001;                    // マジックナンバー（EAの識別番号）
input bool EnableLogging = true;               // ログ出力

#include "ZigzagSeeker.mqh"
#include "RangeBox.mqh"
#include "ChartDrawer.mqh"
#include "OrderManager.mqh"
#include "PrintManager.mqh"
#include "Utility.mqh"

class TradingLogic
{
private:
    // Instances of Classes
    ZigzagSeeker zzSeeker;
    RangeBox rangeBox;
    ChartDrawer chartDrawer;
    OrderManager orderMgr;
    PrintManager printer;
    Utility ut;

    datetime lastTradeTime;
    int lastTimeChecked;

    // 関数呼び出しは計算コストが掛かるため変数に格納する
    string symbol;
    int timeframe;

public:
    TradingLogic() {
        zzSeeker.Initialize(Depth, Deviation, Backstep, PERIOD_M1);
        rangeBox.Init(15, 10, 100);
        printer.EnableLogging(EnableLogging);
        symbol = Symbol();
        timeframe = PERIOD_CURRENT;
    }

    void Execute() {
        printer.PrintLog("Trade executed.");
        printer.ShowCounts();
    }
   
    void TradingStrategy() {
        if (ut.IsSpreadTooHigh(symbol, SpreadThresholdPips)) {
             printer.PrintLog("Spread too high");
             return;
        }

        // Set up
        zzSeeker.UpdateExtremaArray(zigzagArrayLength);
        // zzSeeker.UpdateExSecondArray(zigzagArrayLength, PERIOD_M5);

        // Draw objects
        zzSeeker.DrawPeaksAndValleys(ExSecondArray, 50);
        // chartDrawer.DrawTrendLineFromPeaksAndValleys(ExSecondArray);

        // 15分ごとに描画
        // datetime currentTime = TimeCurrent();
        // datetime last15MinTime = iTime(NULL, PERIOD_M15, 0);
        // if (last15MinTime > lastTimeChecked) {
        //     lastTimeChecked = last15MinTime;
        //     chartDrawer.DrawTrendLineFromPeaksAndValleys(ExSecondArray);
        // }

        // Startegy
        Run();
    }

private:
    void Run() {
        if (OrdersTotal() > 0) {
            // 途中決済
            orderMgr.CheckAndCloseStagnantPositions(MaxHoldingMinutes, Magic);
        }

        // if (!ut.IsVolatilityAcceptable(symbol, 14, 0.04)) {
        //     return;
        // }

        // if (ut.IsWithinTradeInterval(lastTradeTime)) {
        //     return;
        // }

        int action = rangeBox.OnTick();
        double stopLossPrice = 0;
        double takeProfitPrice = 0;
        int ticket = 0;

        if (OrdersTotal() > 0) {
            return;
        }

        // TODO ある条件下でrr比を*2する処理を入れる
        // レンジブレイク後にその価格を保持、その価格に戻ってきたら反対方向にエントリーしてレンジの戻りまでの利幅を取る

        // double ema = iMA(symbol, timeframe, 100, 0, MODE_EMA, PRICE_CLOSE, 0);
        int trendDirection = zzSeeker.GetTrendDirection(ExSecondArray);
        
        // Buy
        if (action == 1) {// && zzSeeker.IsPriceFormingUpTrend()) {
            // orderMgr.ClosePositionOnSignal(OP_SELL, Magic);
            // stpLosttPrice = rangeBox.GetStopLossPrice();
            stopLossPrice = zzSeeker.GetLatestValue(false);
            stopLossPrice = AdjustStopLoss(1, MarketInfo(symbol, MODE_ASK), stopLossPrice, MinStopLossPips);
            ticket = orderMgr.PlaceBuyOrder(action, stopLossPrice, takeProfitPrice, RiskRewardRatio, Magic);
        }

        // Sell
        if (action == 2) {// && zzSeeker.IsPriceFormingDownTrend()) {
            // orderMgr.ClosePositionOnSignal(OP_BUY, Magic);
            stopLossPrice = zzSeeker.GetLatestValue(true);
            stopLossPrice = AdjustStopLoss(2, MarketInfo(symbol, MODE_BID), stopLossPrice, MinStopLossPips);
            ticket = orderMgr.PlaceSellOrder(action, stopLossPrice, takeProfitPrice, RiskRewardRatio, Magic);
        }

        if (ticket > 0) {
            lastTradeTime = TimeCurrent();
        }
    }

    // ストップロスの下限を指定したpipsに設定
    double AdjustStopLoss(int action, double currentPrice, double stopLossValue, int minPips) {
        double minStopLoss = 0;

        if (action == 1) {
            minStopLoss = currentPrice - ut.PipsToPrice(minPips);
            if (stopLossValue > minStopLoss) {
                return minStopLoss;
            }
        } else if (action == 2) {
            minStopLoss = currentPrice + ut.PipsToPrice(minPips);
            if (stopLossValue < minStopLoss) {
                return minStopLoss;
            }
        }
        
        return stopLossValue;
    }

};