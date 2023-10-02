// TradingLogic.mqh
input double LargeCandleBodyPips = 4.0;        // 大陽線・大陰線のローソク足の実態のpips
input double RiskRewardRatio = 1.0;            // リスクリワード比
input double stopLossBuffer = 0.02;
input int Depth = 7;                           // ZigzagのDepth設定
input int Backstep = 3;                        // ZigzagのBackstep設定
input double SpreadThreshold = 0.05;           // スプレッド閾値
input int ConsecutiveCount = 5;                // 連続して上昇・下降した回数
input int DataPeriod = 500;                    // 極値を計算する期間
input int MaxHoldingMinutes = 60;              // ポジションの保有時間の最大
input int MaxProfitPips = 10;                  // ポジションを閉じる際に許容する利益幅
input int MinLossPips = 10;                    // ポジションを閉じる際に許容する損切り幅
input int Magic = 19850001;                    // マジックナンバー（EAの識別番号）

#include "LocalExtremaSeeker.mqh"
#include "ChartDrawer.mqh"
#include "OrderManager.mqh"
#include "LotManager.mqh"
#include "PrintManager.mqh"

class TradingLogic
{
private:
    LocalExtremaSeeker extremaSeeker;
    ChartDrawer chartDrawer;
    OrderManager orderMgr;
    LotManager lotMgr;
    PrintManager printer;

    double highestPrice;      // 最高値（ショートの損切ライン）
    double lowestPrice;       // 最安値（ロングの損切ライン）
    datetime highestTime;     // 最高値をつけた時間
    datetime lowestTime;      // 最安値をつけた時間

    double trendReversalLineForLong;
    double trendReversalLineForShort;

    enum TradeAction
    {
        WAIT = 0,
        BUY  = 1,
        SELL = 2
    };

public:
    TradingLogic() {
            extremaSeeker.Initialize(Depth, Backstep);
            lotMgr.SetRiskPercentage(2.0);
            printer.EnableLogging(false);
            Initialize();
        }
        
    void Initialize() {
        highestPrice = -1;
        lowestPrice = -1;
        trendReversalLineForLong = 0;
        trendReversalLineForShort = 0;
    }

    void Execute() {
        printer.PrintLog("Trade executed.");
        printer.ShowCounts();
    }
   
    void TradingStrategy() 
    { 
        DisplayInfo();

        if (IsSpreadTooHigh()) {
             printer.PrintLog("Spread too high");
             return;
        }

        if (OrdersTotal() > 0) {
            // 途中決済
            orderMgr.CheckAndCloseStagnantPositions(MaxHoldingMinutes, -MinLossPips, MaxProfitPips);
            Initialize();
            return;
        }

        chartDrawer.DrawTrendReversalLine(trendReversalLineForLong, trendReversalLineForShort);
   
        // Set up
        extremaSeeker.UpdatePeaksAndValleys(DataPeriod);
        IsEntryCondition();
    }

private:
    // スプレッド拡大への対応
    bool IsSpreadTooHigh()
    {
        double bid = MarketInfo(Symbol(), MODE_BID);
        double ask = MarketInfo(Symbol(), MODE_ASK);

        return (ask - bid) > SpreadThreshold;
    }

    // 下降トレンド転換ラインを取得
    double GetTrendReversalLineForShort() {
        int valleyValuesLength = ArraySize(extremaSeeker.valleyValues);
        double previousValley = -1;

        // 最高値の一つ前の谷を見つける
        for (int i = 0; i < valleyValuesLength; i++) {
            if (extremaSeeker.valleyTimestamps[i] < highestTime) {
                previousValley = extremaSeeker.valleyValues[i];
                break;
            }
        }

        return previousValley;
    }

    // 上昇トレンド転換ラインを取得
    double GetTrendReversalLineForLong() {
        int peakValuesLength = ArraySize(extremaSeeker.peakValues);
        double previousPeak = -1;

        // 最安値の一つ前のピークを見つける
        for (int i = 0; i < peakValuesLength; i++) {
            if (extremaSeeker.peakTimestamps[i] < lowestTime) {
                previousPeak = extremaSeeker.peakValues[i];
                break;
            }
        }

        return previousPeak;
    }

    // ローソク足の大きさを確認（直近20本で一番大きく、ヒゲが実態の3割未満）
    bool IsExceptionallyLargeCandle(int shift)
    {
        double openPrice = iOpen(Symbol(), Period(), shift);
        double closePrice = iClose(Symbol(), Period(), shift);
        double highPrice = iHigh(Symbol(), Period(), shift);
        double lowPrice = iLow(Symbol(), Period(), shift);

        double bodyLength = MathAbs(closePrice - openPrice); // 実体の絶対値を取得
        double maxBody = MaximumBodyLength(20, shift + 1);
        double wickLength;

        if(closePrice > openPrice) // 陽線の場合
            wickLength = highPrice - closePrice; // 上ヒゲの長さ
        else
            wickLength = openPrice - lowPrice; // 下ヒゲの長さ

        return bodyLength > maxBody 
            && bodyLength >= LargeCandleBodyPips * Point
            && wickLength < bodyLength * 0.3; // ヒゲが実体の3割未満
    }

    double MaximumBodyLength(int barsToConsider, int startShift)
    {
        double maxBodyLength = 0;
        for(int i = 0; i < barsToConsider; i++)
        {
            double openPrice = iOpen(Symbol(), Period(), i + startShift);
            double closePrice = iClose(Symbol(), Period(), i + startShift);
            double bodyLength = MathAbs(closePrice - openPrice);
            
            if(bodyLength > maxBodyLength)
                maxBodyLength = bodyLength;
        }
        return maxBodyLength;
    }

    void IsEntryCondition() {
        // 値動きから行動を選択
        TradeAction action = JudgeTradeAction();

        // レンジの場合
        if (action == WAIT) {
            return;
        }

        // トレンド転換ラインが設定されている場合、大陽線で上抜けしたかを判定する
        if (action == BUY) {
            if (Close[1] < trendReversalLineForLong
                && Close[0] > trendReversalLineForLong
                && IsExceptionallyLargeCandle(0)
                && Close[0] > iMA(Symbol(), 0, 100, 0, MODE_EMA, PRICE_CLOSE, 0)) {

                double lotSizeBuy = GetLotSize(BUY);
                int resultBuy = orderMgr.PlaceBuyOrder(lotSizeBuy, (lowestPrice - stopLossBuffer), RiskRewardRatio, Magic);
                if (resultBuy > 0) {
                    Initialize();
                }
            }
        }

        // トレンド転換ラインが設定されている場合、大陰線で下抜けしたかを判定する
        if (action == SELL) {
            if (Close[1] > trendReversalLineForShort
                && Close[0] < trendReversalLineForShort
                && IsExceptionallyLargeCandle(0)
                && Close[0] < iMA(Symbol(), 0, 100, 0, MODE_EMA, PRICE_CLOSE, 0)) {

                double lotSizeSell = GetLotSize(SELL);
                int resultSell = orderMgr.PlaceSellOrder(lotSizeSell, (highestPrice + stopLossBuffer), RiskRewardRatio, Magic);
                if (resultSell > 0) {
                    Initialize();
                }
            }
        }
    }

    // ローソク足の値動きから環境を認識する
    // レンジ：  "WAIT"  スキップして待つ
    // 下降傾向："BUY"   ロングへのトレンド転換を狙う
    // 上昇傾向："SELL"  ショートへのトレンド転換を狙う
    TradeAction JudgeTradeAction() {
        // EMA100で全体を俯瞰
        double latestEMA = iMA(Symbol(), 0, 100, 0, MODE_EMA, PRICE_CLOSE, 0);
        double oldestEMA = iMA(Symbol(), 0, 100, 0, MODE_EMA, PRICE_CLOSE, 60);
        
        // 上昇傾向
        if (latestEMA > oldestEMA) {
            printer.PrintLog("上昇傾向");
            
            // 連続で上昇しているかを確認する
            if (!IsConsecutiveRise(ConsecutiveCount)) {
                printer.PrintLog("連続で上昇していない");
                return WAIT;
            }

            // 直近の最高値を取得（オーダー時に損切ラインに設定）
            GetHighestValue();

            // 下降トレンド転換ラインの設定
            trendReversalLineForShort = GetTrendReversalLineForShort();
            if (trendReversalLineForShort > 0) {
                return SELL;
            } else {
                printer.PrintLog("下降トレンド転換ラインが設定できなかった");
            }

        // 下降傾向
        } else {
            printer.PrintLog("下降傾向");

            // 連続で下降しているかを確認する
            if (!IsConsecutiveFall(ConsecutiveCount)) {
                printer.PrintLog("連続で下降していない");
                return WAIT;
            }

            // 直近の最安値を取得（オーダー時に損切ラインに設定）
            GetLowestValue();

            // 上昇トレンド転換ラインの設定
            trendReversalLineForLong = GetTrendReversalLineForLong();
            if (trendReversalLineForLong > 0) {
                return BUY;
            } else {
                printer.PrintLog("上昇トレンド転換ラインが設定できなかった");
            }
        }
        
        return WAIT;
    }

    // ピークと谷が連続してN回上昇したかを判定する（ショートエントリー用）
    bool IsConsecutiveRise(int N) {
        int peakValuesLength = ArraySize(extremaSeeker.peakValues);
        int valleyValuesLength = ArraySize(extremaSeeker.valleyValues);

        if (peakValuesLength < N || valleyValuesLength < N) {
            return false;
        }

        int highCount = 0;
        double lastValue = DBL_MAX;

        // peakValuesLength[0]が最新の極値        
        for (int i = 0; i < peakValuesLength; i++) {
            if (extremaSeeker.peakValues[i] < lastValue) {
                lastValue = extremaSeeker.peakValues[i];
                highCount++;
                if (highCount == N) {
                    break;
                }
            } else {
                lastValue = DBL_MAX;
                highCount = 0;
            }
        }

        int lowCount = 0;
        double lastLowValue = DBL_MAX;

        for (int j = 0; j < valleyValuesLength; j++) {
            if (extremaSeeker.valleyValues[j] < lastLowValue) {
                lastLowValue = extremaSeeker.valleyValues[j];
                lowCount++;
                if (lowCount == N) {
                    break;
                }
            } else {
                lastLowValue = DBL_MAX;
                lowCount = 0;
            }
        }

        printer.PrintLog("Rise highCount: " + highCount + " lowCount: " +  lowCount);
        return highCount >= N && lowCount >= N;
    }

    // ピークと谷が連続してN回下降した回数の最大値を判定する（ロングエントリー用）
    bool IsConsecutiveFall(int N) {
        int peakValuesLength = ArraySize(extremaSeeker.peakValues);
        int valleyValuesLength = ArraySize(extremaSeeker.valleyValues);

        if (peakValuesLength < N || valleyValuesLength < N) {
            return false;
        }

        int highCount = 0;
        double lastValue = -DBL_MAX;

        // peakValuesLength[0]が最新の極値
        for (int i = 0; i < peakValuesLength; i++) {
            if (extremaSeeker.peakValues[i] > lastValue) {
                lastValue = extremaSeeker.peakValues[i];
                highCount++;
                if (highCount == N) {
                    break;
                }
            } else {
                lastValue = -DBL_MAX;
                highCount = 0;
            }
        }

        int lowCount = 0;
        double lastLowValue = -DBL_MAX;

        for (int j = 0; j < valleyValuesLength; j++) {
            if (extremaSeeker.valleyValues[j] > lastLowValue) {
                lastLowValue = extremaSeeker.valleyValues[j];
                lowCount++;
                if (lowCount == N) {
                    break;
                }
            } else {
                lastValue = -DBL_MAX;
                lowCount = 0;
            }
        }

        printer.PrintLog("Rise highCount: " + highCount + " lowCount: " +  lowCount);
        return highCount >= N && lowCount >= N;
    }

    void GetLowestValue(int term=100) {
        // 最近N本の中での最低値を持つバーの位置を取得
        int lowestBar = iLowest(Symbol(), Period(), MODE_LOW, term, 1);
        // そのバーの最低値・時間を取得
        lowestPrice = iLow(Symbol(), Period(), lowestBar);
        lowestTime = iTime(Symbol(), Period(), lowestBar);
    }

    void GetHighestValue(int term=100) {
        // 最近N本の中での最高値を持つバーの位置を取得
        int highestBar = iHighest(Symbol(), Period(), MODE_HIGH, term, 1);
        // そのバーの最高値・時間を取得
        highestPrice = iHigh(Symbol(), Period(), highestBar);
        highestTime = iTime(Symbol(), Period(), highestBar);
    }

    // 資金に対して適切なロットサイズを計算する
    double GetLotSize(TradeAction action) {
        double entryPrice = MarketInfo(Symbol(), MODE_BID);
        double stopLossPrice = highestPrice + stopLossBuffer; 

        if (action == BUY) {
            entryPrice = MarketInfo(Symbol(), MODE_ASK);
            stopLossPrice = lowestPrice - stopLossBuffer;
        }
        
        double stopLossPips = lotMgr.PriceDifferenceToPips(entryPrice, stopLossPrice);
        double lotSize = lotMgr.CalculateLot(stopLossPips);
        printer.PrintLog("LotSize " + lotSize);
        return lotSize;
    }

    void DisplayInfo()
    {
        // Account info
        double accountBalance = AccountBalance();
        double accountMargin = AccountFreeMarginCheck(Symbol(), OP_BUY, 1.0);
        
        // Trading info
        double spread = MarketInfo(Symbol(), MODE_SPREAD);
        
        // Last trade info
        string lastTradeResult = "No trades yet";
        if (OrdersHistoryTotal() > 0) {
            if (OrderSelect(OrdersHistoryTotal() - 1, SELECT_BY_POS, MODE_HISTORY)) {
                lastTradeResult = OrderType() == OP_BUY ? "BUY" : "SELL";
                lastTradeResult += " " + DoubleToStr(OrderProfit(), 2);
            }
        }
        
        // Position status
        string positionStatus = (OrdersTotal() > 0) ? "Open" : "Closed";

        Comment(
            "Highest Price: ", highestPrice, "\n",
            "Lowest Price: ", lowestPrice, "\n",
            "Trend Reversal (Long): ", trendReversalLineForLong, "\n",
            "Trend Reversal (Short): ", trendReversalLineForShort, "\n",
            "Position Status: ", positionStatus, "\n",
            "Spread: ", spread, "\n",
            "Account Balance: ", accountBalance, "\n",
            "Available Margin for 1 lot: ", accountMargin, "\n",
            "Last Trade Result: ", lastTradeResult
        );
    }

};
