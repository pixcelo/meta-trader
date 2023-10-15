// TradingLogic.mqh
input double LargeCandleBodyPips = 5.0;        // 大陽線・大陰線のローソク足の実体のpips
input double RiskRewardRatio = 1.0;            // リスクリワード比

// Zigzag
input int Depth = 7;                           // ZigzagのDepth設定
input int Deviation = 5;                       // ZigzagのDeviation設定
input int Backstep = 3;                        // ZigzagのBackstep設定
input int zigzagTerm = 240;                    // 極値を計算する期間

// MA
input int maPeriodShort = 20;                  // 短期MA
input int maPeriodMiddle = 100;                // 中期MA
input int maPeriodLong = 300;                  // 長期MA

input int ConsecutiveCount = 6;                // 連続して上昇・下降した回数
input int StableCount = 2;                     // 上昇・下降の後に安定した回数
input int MaxHoldingMinutes = 60;              // ポジション保有時間の最大
input int lastTradeIntervalSeconds = 300;      // 最後のトレードからの間隔(秒)

// Threshold
input int SpreadThresholdPips = 5;             // スプレッド閾値(pips)
input int horizontalLineThreshold = 0;         // 水平線の強度

// EA Settings
input int Magic = 19850001;                    // マジックナンバー（EAの識別番号）
input bool EnableLogging = true;               // ログ出力
input bool Visualmode = true;                  // 描画

#include "ZigzagSeeker.mqh"
#include "HorizontalLineManager.mqh"
#include "ChartDrawer.mqh"
#include "OrderManager.mqh"
#include "LotManager.mqh"
#include "PrintManager.mqh"
#include "Utility.mqh"

class TradingLogic
{
private:
    // Instances of Classes
    ZigzagSeeker zzSeeker;
    HorizontalLineManager lineMgr;
    ChartDrawer chartDrawer;
    OrderManager orderMgr;
    LotManager lotMgr;
    PrintManager printer;
    Utility utility;

    double highestPrice;      // 最高値（ショートの損切ライン）
    double lowestPrice;       // 最安値（ロングの損切ライン）
    datetime lastTradeTime;   // 最後にトレードした時間

    enum TradeAction {
        WAIT = 0,
        BUY  = 1,
        SELL = 2
    };

    double trendReversalLineForLong;
    double trendReversalLineForShort;

    struct TrendLine {
        double value;
        double touchedValues[];
        TradeAction action;
    };

    TrendLine trendLine;

    // 関数呼び出しは計算コストが掛かるため変数に格納する
    string symbol;
    int timeframe;

public:
    TradingLogic() {
        zzSeeker.Initialize(Depth, Deviation, Backstep, PERIOD_M15);
        lotMgr.SetRiskPercentage(2.0);
        printer.EnableLogging(EnableLogging);

        symbol = Symbol();
        timeframe = PERIOD_CURRENT;
    }
        
    void Initialize() {
        highestPrice = -1;
        lowestPrice = -1;
        trendReversalLineForLong = 0;
        trendReversalLineForShort = 0;

        trendLine.value = 0;
        ArrayResize(trendLine.touchedValues, 0);
        trendLine.action = WAIT;
    }

    void Execute() {
        printer.PrintLog("Trade executed.");
        printer.ShowCounts();
    }
   
    void TradingStrategy() {
        if (utility.IsSpreadTooHigh(symbol, SpreadThresholdPips)) {
             printer.PrintLog("Spread too high");
             return;
        }

        if (OrdersTotal() > 0) {

            // 途中決済（MA判定）
            if (isStopLossTriggered(5)) {
                if (OrderType() == OP_BUY) {
                   bool resultBuy = OrderClose(OrderTicket(), OrderLots(), Bid, 3, clrNONE);
                } else if (OrderType() == OP_SELL) {
                   bool resultSell = OrderClose(OrderTicket(), OrderLots(), Ask, 3, clrNONE);
                }
            }

            // 途中決済
            orderMgr.CheckAndCloseStagnantPositions(MaxHoldingMinutes, Magic);
            Initialize();
            return;
        }

        // Set up
        zzSeeker.UpdateExtremaArray(zigzagTerm, 500);
        lineMgr.IdentifyStrongHorizontalLinesByExtrema(horizontalLineThreshold);
        //lineMgr.IdentifyStrongHorizontalLines(horizontalLineThreshold, PERIOD_M15);

        /// ==========================test=====================
        // Print values to check if they are populated correctly
        // Print("zigzag Values: ");
        // for (int k = 0; k < ArraySize(ExtremaArray); k++) {
        //     Print("Timestamp: ", ExtremaArray[k].timestamp, ", Value: ", ExtremaArray[k].value, " isPeak: ", ExtremaArray[k].isPeak);
        // }

        // Strategy A 
        //JudgeEntryCondition();

        // Strategy B
        //PerfectOrderEntry();

        // Startegy C
        //HorizontalLineTrade();

        // Draw objects
        if (Visualmode) {
            chartDrawer.DeleteAllObjects();
            //chartDrawer.DrawTrendReversalLines(trendReversalLineForLong, trendReversalLineForShort);
            chartDrawer.DrawPeaksAndValleys(ExtremaArray, 500);
            for (int i = 0; i < ArraySize(hLines); i++) {
                string lineName = StringFormat("hLine%d_", i);
                string strength = hLines[i].strength;
                //Print("strength ", strength);
                chartDrawer.DrawHorizontalLineWithStrength(lineName + strength, hLines[i].price, strength);
            }
        }
    }

private:
    void HorizontalLineTrade() {
        if (TimeCurrent() - lastTradeTime < lastTradeIntervalSeconds) {
            return;
        }



    }

    void PerfectOrderEntry() {
        if (TimeCurrent() - lastTradeTime < lastTradeIntervalSeconds) {
            return;
        }

        if (isPerfectOrderShort(3)
            //&& IsMaDescending()
            && isShortEntry()) {
            double stopLossPrice = 0;

            int len = MathMin(ArraySize(ExtremaArray), 2);

            for (int i = 0; i < len; i++) {
                Extremum ex = ExtremaArray[i];
                if (!ex.isPeak) {
                    continue;
                }
                if (stopLossPrice <= ex.value) {
                    stopLossPrice = ex.value;
                }
            }

            double takeProfitPrice = 0;
            double lotSize = GetLotSize(SELL, stopLossPrice);
            int result = orderMgr.PlaceSellOrder(lotSize, stopLossPrice, takeProfitPrice, RiskRewardRatio, Magic);
            if (result > 0) {
                Initialize();
                lastTradeTime = TimeCurrent();
            }
    
        }


        if (isPerfectOrderLong(3)
            //&& IsMaAescending()
            && isLongEntry()) {


            int len2 = MathMin(ArraySize(ExtremaArray), 2);
            
            double stopLossPriceBuy = 0;

            for (int j = 0; j < len2; j++) {
                Extremum ex = ExtremaArray[j];
                if (ex.isPeak) {
                    continue;
                }
                stopLossPriceBuy = ex.value;

                if (stopLossPriceBuy > 0) {
                    break;
                }
            }

            double takeProfitPrice2 = 0;
            double lotSize2 = GetLotSize(BUY, stopLossPriceBuy);
            int result2 = orderMgr.PlaceBuyOrder(lotSize2, stopLossPriceBuy, takeProfitPrice2, RiskRewardRatio, Magic);
            if (result2 > 0) {
                Initialize();
                lastTradeTime = TimeCurrent();
            }
        }
    }

    // パーフェクトオーダー判定（ショート）
    bool isPerfectOrderShort(int minPipDiff)
    {
        double maShort = iMA(symbol, timeframe, maPeriodShort, 0, MODE_SMA, PRICE_CLOSE, 0);
        double maMiddle = iMA(symbol, timeframe, maPeriodMiddle, 0, MODE_SMA, PRICE_CLOSE, 0);
        double maLong = iMA(symbol, timeframe, maPeriodLong, 0, MODE_SMA, PRICE_CLOSE, 0);

        return maShort < maMiddle && maMiddle < maLong
            && utility.IsPriceDiffLargerThanTargetPips(maShort, maMiddle, minPipDiff);
    }

    // パーフェクトオーダー判定（ロング）
    bool isPerfectOrderLong(int minPipDiff)
    {
        double maShort = iMA(symbol, timeframe, maPeriodShort, 0, MODE_SMA, PRICE_CLOSE, 0);
        double maMiddle = iMA(symbol, timeframe, maPeriodMiddle, 0, MODE_SMA, PRICE_CLOSE, 0);
        double maLong = iMA(symbol, timeframe, maPeriodLong, 0, MODE_SMA, PRICE_CLOSE, 0);

        return maShort > maMiddle && maMiddle > maLong
            && utility.IsPriceDiffLargerThanTargetPips(maShort, maMiddle, minPipDiff);
    }

    bool isShortEntry() {
        return PriceReboundDirectionMA(2, 2, 5) == 2;
    }

    bool isLongEntry() {
        return PriceReboundDirectionMA(2, 2, 5) == 1;
    }

    // 髭の長さが実体の２割以下であるかを判定する
    // @param forLong : ロングポジションの場合はtrue、ショートポジションの場合はfalse
    // @param candleIndex : 判定するローソク足のインデックス（0が現在のローソク足）
    // @return : 条件を満たす場合はtrue、そうでない場合はfalse
    bool IsWickShortEnough(TradeAction action, int candleIndex) {
        double bodySize = MathAbs(Open[candleIndex] - Close[candleIndex]);  // 実体のサイズ
        double upperWickSize = High[candleIndex] - MathMax(Open[candleIndex], Close[candleIndex]);  // 上髭のサイズ
        double lowerWickSize = MathMin(Open[candleIndex], Close[candleIndex]) - Low[candleIndex];  // 下髭のサイズ

        if (action == BUY) {
            // ロングポジションの場合、上髭が実体の２割以下であるか判定
            return upperWickSize <= 0.2 * bodySize;
        }
        
        if (action == SELL) {
            // ショートポジションの場合、下髭が実体の２割以下であるか判定
            return lowerWickSize <= 0.2 * bodySize;
        }
        
        return false;
    }

    // 移動平均線が下向きかどうか
    bool IsMaDescending()
    {
        double maShort = iMA(symbol, timeframe, maPeriodShort, 0, MODE_SMA, PRICE_CLOSE, 0);
        double maMiddle = iMA(symbol, timeframe, maPeriodMiddle, 0, MODE_SMA, PRICE_CLOSE, 0);
        double maLong = iMA(symbol, timeframe, maPeriodLong, 0, MODE_SMA, PRICE_CLOSE, 0);

        double maShortPrev = iMA(symbol, timeframe, maPeriodShort, 0, MODE_SMA, PRICE_CLOSE, 5); // この値をちょうせいする
        double maMiddlePrev = iMA(symbol, timeframe, maPeriodMiddle, 0, MODE_SMA, PRICE_CLOSE, 25);
        double maLongPrev = iMA(symbol, timeframe, maPeriodLong, 0, MODE_SMA, PRICE_CLOSE, 50);

        return maShort < maShortPrev && maMiddle < maMiddlePrev && maLong < maLongPrev;
    }

    // 移動平均線が上向きかどうか
    bool IsMaAescending()
    {
        double maShort = iMA(symbol, timeframe, maPeriodShort, 0, MODE_SMA, PRICE_CLOSE, 0);
        double maMiddle = iMA(symbol, timeframe, maPeriodMiddle, 0, MODE_SMA, PRICE_CLOSE, 0);
        double maLong = iMA(symbol, timeframe, maPeriodLong, 0, MODE_SMA, PRICE_CLOSE, 0);

        double maShortPrev = iMA(symbol, timeframe, maPeriodShort, 0, MODE_SMA, PRICE_CLOSE, 5); // この値をちょうせいする
        double maMiddlePrev = iMA(symbol, timeframe, maPeriodMiddle, 0, MODE_SMA, PRICE_CLOSE, 25);
        double maLongPrev = iMA(symbol, timeframe, maPeriodLong, 0, MODE_SMA, PRICE_CLOSE, 50);

        return maShort > maShortPrev && maMiddle > maMiddlePrev && maLong > maLongPrev;
    }

    bool isStopLossTriggered(int pips) {
        double maShort = iMA(_Symbol, _Period, maPeriodShort, 0, MODE_SMA, PRICE_CLOSE, 0);

        // MAを指定したpipsよりも下に動いたら決済
        if (OrderType() == OP_BUY && Close[0] < maShort && Close[1] < maShort && Close[2] < maShort) {//utility.PriceToPips(maShort - Close[0]) < -pips) {
            return true;
        }

        // MAを指定したpipsよりも上に動いたら決済
        if (OrderType() == OP_SELL && Close[0] > maShort && Close[1] > maShort && Close[2] > maShort) { //&& utility.PriceToPips(Close[0] - maShort) > pips) {
            return true;
        }

        return false;
    }

    // 1: 価格が上から近づいて上に離れた
    // 2: 価格が下から近づいて下に離れた
    // 0: どちらでもない
    int PriceReboundDirection(double allowedPipsClose, double allowedPipsAway, int checkPeriod, double targetPrice) {
        double priceDistance = DBL_MAX;
        int priceIndex = -1;
        
        for (int i = 0; i < checkPeriod; i++) {
            targetPrice = iMA(symbol, timeframe, maPeriodShort, 0, MODE_SMA, PRICE_CLOSE, i);
            double distance = utility.PriceToPips(MathAbs(targetPrice - Close[i]));
            if (distance < priceDistance) {
                priceDistance = distance; // 期間内で一番近づいた距離
                priceIndex = i;
            }
        }
        
        if (priceDistance <= allowedPipsClose && priceIndex - 1 >= 0) {
            // 1つ前の足が高いなら上から近づいたということ
            bool approachedFromAbove = Close[priceIndex + 1] > Close[priceIndex];

            // 近づいた後に離れたかを調べる
            for (int j = priceIndex; j >= 0; j--) {
                targetPrice = iMA(symbol, timeframe, maPeriodShort, 0, MODE_SMA, PRICE_CLOSE, j);
                double distanceAfterClosest = utility.PriceToPips(MathAbs(targetPrice - Close[j]));
                if (approachedFromAbove && distanceAfterClosest >= allowedPipsAway) {
                    return 1;
                } else if (!approachedFromAbove && distanceAfterClosest <= -allowedPipsAway) {
                    return 2;
                }
            }
        }

        return 0;
    }

    // MAに対してのローソク足の反発を捉える
    // 1: 価格が上から近づいて上に離れた
    // 2: 価格が下から近づいて下に離れた
    // 0: どちらでもない
    int PriceReboundDirectionMA(double allowedPipsClose, double allowedPipsAway, int checkPeriod) {        
        double targetPrice = -1;
        double priceDistance = DBL_MAX;
        int priceIndex = -1;
        
        for (int i = 0; i < checkPeriod; i++) {
            targetPrice = iMA(symbol, timeframe, maPeriodShort, 0, MODE_SMA, PRICE_CLOSE, i);
            double distance = utility.PriceToPips(MathAbs(targetPrice - Close[i]));
            if (distance < priceDistance) {
                priceDistance = distance; // 期間内で一番近づいた距離
                priceIndex = i;
            }
        }
        
        if (priceDistance <= allowedPipsClose && priceIndex - 1 >= 0) {
            // 1つ前の足が高いなら上から近づいたということ
            bool approachedFromAbove = Close[priceIndex + 1] > Close[priceIndex];

            // 近づいた後に離れたかを調べる
            for (int j = priceIndex; j >= 0; j--) {
                targetPrice = iMA(symbol, timeframe, maPeriodShort, 0, MODE_SMA, PRICE_CLOSE, j);
                double distanceAfterClosest = utility.PriceToPips(MathAbs(targetPrice - Close[j]));
                if (approachedFromAbove && distanceAfterClosest >= allowedPipsAway) {
                    return 1;
                } else if (!approachedFromAbove && distanceAfterClosest <= -allowedPipsAway) {
                    return 2;
                }
            }
        }

        return 0;
    }

    // 下降トレンド転換ラインを取得
    double GetTrendReversalLineForShort(int term) {
        int len = MathMin(ArraySize(ExtremaArray), term);
        double highestValue = -DBL_MAX;
        double trendReversalLine = 0;

        // 直近の期間内で最高の極大値の起点となった谷をトレンド転換ラインとする
        for (int i = 0; i < len; i++) {
            Extremum ex = ExtremaArray[i];
            if (!ex.isPeak) {
                continue;
            }
            if (highestValue <= ex.value) {
                highestValue = ex.value;
                trendReversalLine = ex.prevValue;
                
                // 損切ラインとして保存
                highestPrice = ex.value;
            }
        }

        return trendReversalLine;
    }

    // 上昇トレンド転換ラインを取得
    double GetTrendReversalLineForLong(int term) {
        int len = MathMin(ArraySize(ExtremaArray), term);
        double lowestValue = DBL_MAX;
        double trendReversalLine = 0;

        // 直近の期間内で最安の極小値の起点となったピークをトレンド転換ラインとする
        for (int i = 0; i < len; i++) {
            Extremum ex = ExtremaArray[i];
            if (ex.isPeak) {
                continue;
            }
            if (lowestValue >= ex.value) {
                lowestValue = ex.value;
                trendReversalLine = ex.prevValue;
                
                // 損切ラインとして保存
                lowestPrice = ex.value;
            }
        }

        return trendReversalLine;
    }

    void JudgeEntryCondition() {
        // 値動きから行動を選択
        TradeAction action = SelectTradeAction();

        // レンジの場合
        if (action == WAIT) {
            return;
        }

        if (action == BUY && IsLongBreakOut()) {
            BuyOrder();
        }

        if (action == SELL && IsShortBreakOut()) {
            SellOrder();
        }
    }
    
    // N本以内での上抜け + 大陽線の確定でロングブレイクアウト
    bool IsLongBreakOut() {
        if (TimeCurrent() - lastTradeTime < lastTradeIntervalSeconds) {
            return false;
        }

        if (!IsConsecutiveRise(2, 6)) {
            return false;
        }

        int passCount = 0;
        for (int i = 0; i < 60; i++) {
            if (Close[i + 1] < trendReversalLineForLong && trendReversalLineForLong < Close[i]) {
                passCount++;
                break;
            }
        }
        
        if (passCount == 0) {
            return false;
        }

        if (!IsExceptionallyLargeCandle(BUY)) {
            return false;
        }
        
        if (Close[0] < iMA(symbol, timeframe, 100, 0, MODE_EMA, PRICE_CLOSE, 0)) {
            return false;
        }

        if (Close[0] < trendReversalLineForLong) {
            return false;
        }

        if (!Touched()) {
            return false;
        }

        return true;
    }

    // N本以内での下抜け + 大陰線の確定でショートブレイクアウト
    bool IsShortBreakOut() {
        if (TimeCurrent() - lastTradeTime < lastTradeIntervalSeconds) {
            return false;
        }

        if (!IsConsecutiveFall(2, 6)) {
            return false;
        }

        int passCount = 0; 
        for (int i = 0; i < 60; i++) {
            if (Close[i] < trendReversalLineForShort && trendReversalLineForShort < Close[i + 1]) {
                passCount++;
                break;
            }
        }
        
        if (passCount == 0) {
            return false;
        }

        if (!IsExceptionallyLargeCandle(SELL)) {
            return false;
        }
        
        if (Close[0] > iMA(symbol, timeframe, 100, 0, MODE_EMA, PRICE_CLOSE, 0)) {
            return false;
        }

        if (Close[0] > trendReversalLineForShort) {
            return false;
        }

        return true;
    }

    bool Touched() {
        bool condition1 = Close[2] < trendReversalLineForLong && Close[1] > trendReversalLineForLong; // 1. 上抜ける
        bool condition2 = Close[1] < trendReversalLineForLong && Low[1] <= trendReversalLineForLong;  // 2. 下落して接触/近接する
        bool condition3 = Close[0] > trendReversalLineForLong; // 3. 再度上昇する
        
        return condition1 && condition2 && condition3;
    }

    // ローソク足の大きさを確認
    bool IsExceptionallyLargeCandle(TradeAction action)
    {
        double openPrice = iOpen(symbol, timeframe, 0);
        double closePrice = iClose(symbol, timeframe, 0);
        double highPrice = iHigh(symbol, timeframe, 0);
        double lowPrice = iLow(symbol, timeframe, 0);

        if (action == SELL && closePrice > openPrice) {
            return false; // 陽線の場合
        }
        if (action == BUY && closePrice < openPrice) {
            return false; // 陰線の場合
        }

        double bodyLength = MathAbs(closePrice - openPrice); // 実体の絶対値を取得
        double compareBody = MaximumBodyLength(20, 1);
        double wickLength;

        if (closePrice > openPrice) // 陽線の場合
            wickLength = highPrice - closePrice; // 上ヒゲの長さ
        else
            wickLength = openPrice - lowPrice; // 下ヒゲの長さ

        // 直近20本で比較的大きい（またはNpips以上）でヒゲが小さいローソク足
        //Print("bodyLength ", NormalizeDouble(bodyLength, Digits()) , " pips ", LargeCandleBodyPips * Point * utility.GetPointCoefficient());
        return (bodyLength > compareBody
            && bodyLength >= LargeCandleBodyPips * Point * utility.GetPointCoefficient())
            && wickLength < bodyLength * 0.1;
    }

    double MaximumBodyLength(int barsToConsider, int startShift)
    {
        double maxBodyLength = 0;
        for (int i = 0; i < barsToConsider; i++)
        {
            double openPrice = iOpen(symbol, timeframe, i + startShift);
            double closePrice = iClose(symbol, timeframe, i + startShift);
            double bodyLength = MathAbs(closePrice - openPrice);
            
            if (bodyLength > maxBodyLength)
                maxBodyLength = bodyLength;
        }
        return maxBodyLength;
    }

    // ローソク足の値動きからエントリータイミングをチェックする
    // レンジ：  "WAIT"  スキップして待つ
    // 下降傾向："BUY"   ロングへのトレンド転換を狙う
    // 上昇傾向："SELL"  ショートへのトレンド転換を狙う
    TradeAction SelectTradeAction() { 
        // 連続で上昇しているかを確認する
        if (IsConsecutiveRiseAndFall(ConsecutiveCount, 1, 10)) {
            //|| IsContinuouslyAwayFromEMA100ByPips(5, 60, true)) {
            // 下降トレンド転換ラインの設定
            trendReversalLineForShort = GetTrendReversalLineForShort(50);
            if (trendReversalLineForShort <= 0) {
                printer.PrintLog("下降トレンド転換ラインが設定できなかった");
            } else {
                trendReversalLineForLong = 0;
                trendLine.value = trendReversalLineForShort;
                trendLine.action = SELL;

            }
        }

        // 連続で下降しているかを確認する
        if (IsConsecutiveFallAndRise(ConsecutiveCount, 1, 10)) {
            //|| IsContinuouslyAwayFromEMA100ByPips(5, 60, false)) {
            // 上昇トレンド転換ラインの設定
            trendReversalLineForLong = GetTrendReversalLineForLong(50);
            if (trendReversalLineForLong <= 0) {
                printer.PrintLog("上昇トレンド転換ラインが設定できなかった");
            } else {
                trendReversalLineForShort = 0;
                trendLine.value = trendReversalLineForLong;
                trendLine.action = BUY;

            }
        }

        UpdateTrendReversalLine();

        if (trendReversalLineForShort > 0) {
            return SELL;
        }

        if (trendReversalLineForLong > 0) {
            return BUY;
        }

        return WAIT;
    }

    // トレンド転換ラインがローソク足と逆方向に指定したpips離れている場合、リセット
    void ResetTrendReversalLineIfTooFar(double pipsDistance) {
        double pointValue = pipsDistance * Point * utility.GetPointCoefficient(); // pips to price value

        if (trendReversalLineForShort > 0) {
            if (Close[0] < trendReversalLineForShort - pointValue) { 
                Initialize();
            }
        }

        if (trendReversalLineForLong > 0) {
            if (Close[0] > trendReversalLineForLong + pointValue) {
                Initialize();   
            }
        }
    }

    // トレンド転換ラインがある状態で最高値・最安値が更新された場合はトレンド転換ラインを動かす
    void UpdateTrendReversalLine() {
        if (trendReversalLineForShort > 0 && lowestPrice > iLow(symbol, timeframe, 0)) { 
            Initialize();
            trendReversalLineForShort = GetTrendReversalLineForShort(50);
            trendLine.value = trendReversalLineForShort;
            trendLine.action = SELL;
        }

        if (trendReversalLineForLong > 0 && highestPrice < iHigh(symbol, timeframe, 0)) {
            Initialize();
            trendReversalLineForLong = GetTrendReversalLineForLong(50);
            trendLine.value = trendReversalLineForLong;
            trendLine.action = BUY;
        }
    }

    // ピークと谷が連続してN回下降した後に、高値が上昇をした価格の推移を検知する（ショートエントリー用）
    // ダウ理論の更新が続くことが条件（高値が上に更新しない限りは下降トレンドとみる）
    bool IsConsecutiveFallAndRise(int N, int M, int term) {
        int len = MathMin(ArraySize(ExtremaArray), term);
        int highCount = 0;
        int lowCount = 0;
        int riseCount = 0;
        double lastHighValue = DBL_MAX;
        double lastLowValue = DBL_MAX;

        for (int i = len - 1; i >= 0; i--) {
            Extremum ex = ExtremaArray[i];

            if (ex.isPeak) {
                if (ex.value < lastHighValue) {
                    lastHighValue = ex.value;
                    highCount++;
                } else {
                    highCount = 0;
                    lowCount = 0;
                    lastHighValue = DBL_MAX;
                    lastLowValue = DBL_MAX;
                }
            } else {
                if (ex.value < lastLowValue) {
                    lastLowValue = ex.value;
                    lowCount++;
                }
            }

            if (highCount >= N && lowCount >= N) {
                // N回の連続下落を確認した後に、M回のピークの高値の上昇を確認する（下降トレンドの終わり）
                for (int j = i; j >= 0; j--) {
                    Extremum nextEx = ExtremaArray[j];

                    if (nextEx.isPeak && nextEx.value > lastHighValue) {
                        riseCount++;
                        lastHighValue = nextEx.value;
                        if (riseCount >= M) {
                            return true;
                        }
                    } else {
                        riseCount = 0;
                    }
                }
            }
        }
        return false;
    }

    // ピークと谷が連続してN回上昇した後に、横ばいか下降をした価格の推移を検知する（ロングエントリー用）
    // ダウ理論の上昇の更新が続くことが条件（安値が下に更新しない限りは上昇トレンドとみる）
    bool IsConsecutiveRiseAndFall(int N, int M, int term) {
        int len = MathMin(ArraySize(ExtremaArray), term);
        int highCount = 0;
        int lowCount = 0;
        int fallCount = 0;
        double lastHighValue = -DBL_MAX;
        double lastLowValue = -DBL_MAX;

        for (int i = len - 1; i >= 0; i--) {
            Extremum ex = ExtremaArray[i];

            if (ex.isPeak) {
                if (ex.value > lastHighValue) {
                    lastHighValue = ex.value;
                    highCount++;
                }
            } else {
                if (ex.value > lastLowValue) {
                    lastLowValue = ex.value;
                    lowCount++;
                } else {
                    highCount = 0;
                    lowCount = 0;
                    lastHighValue = -DBL_MAX;
                    lastLowValue = -DBL_MAX;
                }
            }

            if (highCount >= N && lowCount >= N) {
                // N回の連続上昇を確認した後に、M回の谷の安値の下降を確認する（上昇トレンドの終わり）
                for (int j = i; j >= 0; j--) {
                    Extremum nextEx = ExtremaArray[j];

                    if (!nextEx.isPeak && nextEx.value < lastLowValue) {
                        fallCount++;
                        lastLowValue = nextEx.value;
                        if (fallCount >= M) {
                            return true;
                        }
                    } else {
                        fallCount = 0;
                    }
                }
            }
        }

        return false; 
    }

    // 期間内で直近のピークと谷が連続してN回上昇したかを判定する
    bool IsConsecutiveRise(int N, int term) {
        int len = ArraySize(ExtremaArray);
        int highCount = 0;
        int lowCount = 0;
        double lastHighValue = DBL_MAX;
        double lastLowValue = DBL_MAX;

        for (int i = 0; i < term; i++) {
            Extremum ex = ExtremaArray[i];

            if (ex.isPeak) {
                if (ex.value < lastHighValue) {
                    lastHighValue = ex.value;
                    highCount++;
                }
            } else {
                if (ex.value < lastLowValue) {
                    lastLowValue = ex.value;
                    lowCount++;
                } else {
                    highCount = 0;
                    lowCount = 0;
                    lastHighValue = DBL_MAX;
                    lastLowValue = DBL_MAX;
                }
            }

            if (highCount >= N && lowCount >= N) {
                break;
            }
        }

        return highCount >= N && lowCount >= N;
    }

    // 期間内で直近のピークと谷が連続してN回下降したかを判定する
    bool IsConsecutiveFall(int N, int term) {
        int len = ArraySize(ExtremaArray);
        int highCount = 0;
        int lowCount = 0;
        double lastHighValue = -DBL_MAX;
        double lastLowValue = -DBL_MAX;

        for (int i = 0; i < term; i++) {
            Extremum ex = ExtremaArray[i];

            if (ex.isPeak) {
                if (ex.value > lastHighValue) {
                    lastHighValue = ex.value;
                    highCount++;
                } else {
                    highCount = 0;
                    lowCount = 0;
                    lastHighValue = -DBL_MAX;
                    lastLowValue = -DBL_MAX;
                }
            } else {
                if (ex.value > lastLowValue) {
                    lastLowValue = ex.value;
                    lowCount++;
                }
            }

            if (highCount >= N && lowCount >= N) {
                break;
            }
        }

        return highCount >= N && lowCount >= N;
    }

    // EMA100から特定のpips数以上離れて連続しているかを判定する関数
    bool IsContinuouslyAwayFromEMA100ByPips(double pipsDistance, int barsToCheck = 100, bool checkAbove = false) {
        double distance = pipsDistance * Point * utility.GetPointCoefficient();

        int countAwayFromEMA = 0;
        for (int i = 0; i < barsToCheck; i++) {
            double ema100 = iMA(NULL, 0, 100, 0, MODE_EMA, PRICE_CLOSE, i);
            if (checkAbove) {
                if (Close[i] > ema100 + distance) {
                    countAwayFromEMA++;
                } else {
                    break;
                }
            } else {
                if (Close[i] < ema100 - distance) {
                    countAwayFromEMA++;
                } else {
                    break;
                }
            }
        }

        return countAwayFromEMA == barsToCheck;
    }

    // 損切り幅が10pips未満なら10pipsを損切り幅とする
    double CalculateStopLoss(TradeAction action, double entryPrice, double recentExtremum, double pipsDistance) {
        double minStopDistance =  pipsDistance * Point * utility.GetPointCoefficient();
        
        if (action == BUY) {
            if (entryPrice - recentExtremum < minStopDistance) {
                return entryPrice - minStopDistance;
            } else {
                return recentExtremum;
            }
        }
        
        if (action == SELL) {
            if (recentExtremum - entryPrice < minStopDistance) {
                return entryPrice + minStopDistance;
            } else {
                return recentExtremum;
            }
        }

        return 0;
    }

    // 資金に対して適切なロットサイズを計算する
    double GetLotSize(TradeAction action, double stopLossPrice) {
        double entryPrice = MarketInfo(symbol, MODE_BID);

        if (action == BUY) {
            entryPrice = MarketInfo(symbol, MODE_ASK);
        }

        double stopLossPips = utility.PriceToPips(MathAbs(entryPrice - stopLossPrice));
        double lotSize = lotMgr.CalculateLot(stopLossPips);
        return lotSize;
    }

    void BuyOrder() {
        //double stopLossPrice = SetStopLossPriceByLatestValue(BUY);
        double stopLossPrice = SetStopLossPriceByLatestExtremum(BUY);
        //double takeProfitPrice = Close[0] + 10 * Point * utility.GetPointCoefficient();
        double takeProfitPrice = 0;
        double lotSize = GetLotSize(BUY, stopLossPrice);
        int result = orderMgr.PlaceBuyOrder(lotSize, stopLossPrice, takeProfitPrice, RiskRewardRatio, Magic);
        if (result > 0) {
            Initialize();
            lastTradeTime = TimeCurrent();
        }
    }

    void SellOrder() {
        //double stopLossPrice = SetStopLossPriceByLatestValue(SELL);
        double stopLossPrice = SetStopLossPriceByLatestExtremum(SELL);
        //double takeProfitPrice = Close[0] - 10 * Point * utility.GetPointCoefficient();
        double takeProfitPrice = 0;
        double lotSize = GetLotSize(SELL, stopLossPrice);
        int result = orderMgr.PlaceSellOrder(lotSize, stopLossPrice, takeProfitPrice, RiskRewardRatio, Magic);
        if (result > 0) {
            Initialize();
            lastTradeTime = TimeCurrent();
        }
    }

    // A: ストップロスの設定（直近の高値・安値）
    double SetStopLossPriceByLatestValue(TradeAction action) {
        double stopLossPrice = 0;
        if (action == BUY) {
            int lowBar = iLowest(symbol, timeframe, MODE_LOW, 1, 1);
            double latestLow = iLow(symbol, timeframe, lowBar);
            stopLossPrice = latestLow;
            //stopLossPrice = CalculateStopLoss(BUY, MarketInfo(symbol, MODE_ASK), latestLow, 10);
        } else {
            int highBar = iHighest(symbol, timeframe, MODE_HIGH, 1, 1);
            double latestHigh = iHigh(symbol, timeframe, highBar);
            stopLossPrice = latestHigh;
            //stopLossPrice = CalculateStopLoss(SELL, MarketInfo(symbol, MODE_BID), latestHigh, 10);
        }
        return stopLossPrice;
    }

    // B: ストップロスの設置（直近の極値の高値・安値）
    double SetStopLossPriceByLatestExtremum(TradeAction action) {
        if (BUY) {
            // return lowestPrice;
            return CalculateStopLoss(BUY, MarketInfo(symbol, MODE_ASK), lowestPrice, 10);
        } else {
            //return highestPrice;
            return CalculateStopLoss(SELL, MarketInfo(symbol, MODE_BID), highestPrice, 10);
        }
    }

};