// TradingLogic.mqh
input double LargeCandleBodyPips = 4.0;        // 大陽線・大陰線のローソク足の実態のpips
input double RiskRewardRatio = 1.0;            // リスクリワード比
input double ResetPipsDistance = 20;           // トレンド転換ラインがローソク足と何pips離れたらリセットするか
input int Depth = 7;                           // ZigzagのDepth設定
input int Deviation = 5;                       // ZigzagのDeviation設定
input int Backstep = 3;                        // ZigzagのBackstep設定
input double SpreadThreshold = 0.05;           // スプレッド閾値
input int ConsecutiveCount = 6;                // 連続して上昇・下降した回数
input int StableCount = 2;                     // 上昇・下降の後に安定した回数
input int zigzagTerm = 700;                    // 極値を計算する期間
input int MaxHoldingMinutes = 60;              // ポジションの保有時間の最大
input int MaxProfitPips = 10;                  // ポジションを閉じる際に許容する利益幅
input int MinLossPips = 10;                    // ポジションを閉じる際に許容する損切り幅
input int Magic = 19850001;                    // マジックナンバー（EAの識別番号）

input bool EnableLogging = true;                  // ログ出力
input bool Visualmode = true;                      // 描画

#include "ZigzagSeeker.mqh"
#include "ChartDrawer.mqh"
#include "OrderManager.mqh"
#include "LotManager.mqh"
#include "PrintManager.mqh"

#include <stdlib.mqh>

class TradingLogic
{
private:
    ZigzagSeeker zzSeeker;
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

    // 関数呼び出しは計算コストが掛かるため変数に格納する
    string symbol;
    string timeframe;

public:
    TradingLogic() {
        zzSeeker.Initialize(Depth, Deviation, Backstep);
        lotMgr.SetRiskPercentage(2.0);
        printer.EnableLogging(EnableLogging);
        //Initialize();

        symbol = Symbol();
        timeframe = PERIOD_CURRENT;
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

        // Set up
        zzSeeker.UpdateExtremaArray(zigzagTerm, 50);

        /// ==========================test=====================
        // Print values to check if they are populated correctly
        // Print("zigzag Values: ");
        // for (int k = 0; k < ArraySize(ExtremaArray); k++) {
        //     Print("Timestamp: ", ExtremaArray[k].timestamp, ", Value: ", ExtremaArray[k].value, " isPeak:", ExtremaArray[k].isPeak);
        // }

        // Entry check
        JudgeEntryCondition();

        // Draw objects and comments
        if (Visualmode) {
            DisplayInfo();
            chartDrawer.DrawTrendReversalLine(trendReversalLineForLong, trendReversalLineForShort);
            chartDrawer.DrawPeaksAndValleys(ExtremaArray, 50);
        }
    }

private:
    // スプレッド拡大への対応
    bool IsSpreadTooHigh()
    {
        double bid = MarketInfo(symbol, MODE_BID);
        double ask = MarketInfo(symbol, MODE_ASK);

        return (ask - bid) > SpreadThreshold;
    }

    // 下降トレンド転換ラインを取得
    double GetTrendReversalLineForShort(int term) {
        int len = ArraySize(ExtremaArray);
        double highestValue = -DBL_MAX;
        double trendReversalLine = 0;

        // 直近の期間内で最高の極大値の起点となった谷をトレンド転換ラインとする
        for (int i = 0; i < term; i++) {
            Extremum ex = ExtremaArray[i];
            if (!ex.isPeak) {
                continue;
            }
            if (highestValue <= ex.value) {
                highestValue = ex.value;
                trendReversalLine = ex.prevValue;
                
                // 損切ラインとして保存
                highestPrice = ex.value;
                highestTime = ex.timestamp;
            }
        }

        return trendReversalLine;
    }

    // 上昇トレンド転換ラインを取得
    double GetTrendReversalLineForLong(int term) {
        int len = ArraySize(ExtremaArray);
        double lowestValue = DBL_MAX;
        double trendReversalLine = 0;

        // 直近の期間内で最安の極小値の起点となったピークをトレンド転換ラインとする
        for (int i = 0; i < term; i++) {
            Extremum ex = ExtremaArray[i];
            if (ex.isPeak) {
                continue;
            }
            if (lowestValue >= ex.value) {
                lowestValue = ex.value;
                trendReversalLine = ex.prevValue;
                
                // 損切ラインとして保存
                lowestPrice = ex.value;
                lowestTime = ex.timestamp;
            }
        }

        return trendReversalLine;
    }

    // ローソク足の大きさを確認（直近20本で一番大きく、ヒゲが実態の3割未満）
    bool IsExceptionallyLargeCandle(int shift)
    {
        double openPrice = iOpen(symbol, timeframe, shift);
        double closePrice = iClose(symbol, timeframe, shift);
        double highPrice = iHigh(symbol, timeframe, shift);
        double lowPrice = iLow(symbol, timeframe, shift);

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
            double openPrice = iOpen(symbol, timeframe, i + startShift);
            double closePrice = iClose(symbol, timeframe, i + startShift);
            double bodyLength = MathAbs(closePrice - openPrice);
            
            if(bodyLength > maxBodyLength)
                maxBodyLength = bodyLength;
        }
        return maxBodyLength;
    }

    void JudgeEntryCondition() {
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
                && Close[0] > iMA(symbol, timeframe, 100, 0, MODE_EMA, PRICE_CLOSE, 0)) {

                int lowBar = iLowest(symbol, timeframe, MODE_LOW, 1, 1);
                double latestLow = iLow(symbol, timeframe, lowBar);
                double stopLossPriceBuy = CalculateStopLossForLong(MarketInfo(symbol, MODE_ASK), latestLow, 10);
                double lotSizeBuy = GetLotSize(BUY, stopLossPriceBuy);
                int resultBuy = orderMgr.PlaceBuyOrder(lotSizeBuy, stopLossPriceBuy, RiskRewardRatio, Magic);
                if (resultBuy > 0) {
                    Initialize();
                }
            }
        }

        // トレンド転換ラインが設定されている場合、大陰線で下抜けしたかを判定する　(TODO: or 連続陰線 or ローソク足高値安値連続切り下げ)
        if (action == SELL) {
            if (Close[1] > trendReversalLineForShort
                && Close[0] < trendReversalLineForShort
                && IsExceptionallyLargeCandle(0)
                && Close[0] < iMA(symbol, timeframe, 100, 0, MODE_EMA, PRICE_CLOSE, 0)) {

                int highBar = iHighest(symbol, timeframe, MODE_HIGH, 1, 1);
                double latestHigh = iLow(symbol, timeframe, highBar);
                double stopLossPriceSell = CalculateStopLossForShort(MarketInfo(symbol, MODE_BID), latestHigh, 10);
                double lotSizeSell = GetLotSize(SELL, stopLossPriceSell);
                int resultSell = orderMgr.PlaceSellOrder(lotSizeSell, stopLossPriceSell, RiskRewardRatio, Magic);
                if (resultSell > 0) {
                    Initialize();
                }
            }
        }
    }

    // ローソク足の値動きからエントリータイミングをチェックする
    // レンジ：  "WAIT"  スキップして待つ
    // 下降傾向："BUY"   ロングへのトレンド転換を狙う
    // 上昇傾向："SELL"  ショートへのトレンド転換を狙う
    TradeAction JudgeTradeAction() { 
        // 連続で上昇しているかを確認する
        if (IsConsecutiveRiseAndStabilize(ConsecutiveCount, StableCount, 0.05)) { //IsConsecutiveRise(ConsecutiveCount)) {
            // 下降トレンド転換ラインの設定
            trendReversalLineForShort = GetTrendReversalLineForShort(10);
            if (trendReversalLineForShort <= 0) {
                printer.PrintLog("下降トレンド転換ラインが設定できなかった");
            }
        }

        // 連続で下降しているかを確認する
        if (IsConsecutiveFallAndStabilize(ConsecutiveCount, StableCount, 0.05)) { //IsConsecutiveFall(ConsecutiveCount)) {
            // 上昇トレンド転換ラインの設定
            trendReversalLineForLong = GetTrendReversalLineForLong(10);
            if (trendReversalLineForLong <= 0) {
                printer.PrintLog("上昇トレンド転換ラインが設定できなかった");
            }
        }

        //double hLine = FindMostTouchedPrice(highBuffer, lowBuffer, 5, 2);
        //Print("hLine: ", hLine);

        ResetTrendReversalLineIfTooFar(ResetPipsDistance);

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
        pipsDistance *= Point; // pips to price value

        if (trendReversalLineForShort > 0) {
            if (Close[0] < trendReversalLineForShort - pipsDistance) { 
                trendReversalLineForShort = 0;
            }
        }

        if (trendReversalLineForLong > 0) {
            if (Close[0] > trendReversalLineForLong + pipsDistance) {
                trendReversalLineForLong = 0;
            }
        }
    }

    // ピークと谷が連続してN回下降した後に、横ばいか上昇をした価格の推移を検知する（ショートエントリー用）
    bool IsConsecutiveFallAndStabilize(int N, int M, double epsilon) {
        int len = ArraySize(ExtremaArray);
        int highCount = 0;
        int lowCount = 0;
        int stableCount = 0;
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
                    lastHighValue = DBL_MAX;
                }
            } else {
                if (ex.value < lastLowValue) {
                    lastLowValue = ex.value;
                    lowCount++;
                } else {
                    lowCount = 0;
                    lastLowValue = DBL_MAX;
                }
            }

            if (highCount >= N && lowCount >= N) {
                // N回の連続下落を確認した後に、M回の安定を確認する
                for (int j = i; j >= 0; j--) {
                    Extremum nextEx = ExtremaArray[j];

                    if (!nextEx.isPeak) {
                        if (MathAbs(nextEx.value - lastLowValue) <= epsilon) {
                            stableCount++;
                            lastLowValue = nextEx.value;
                        } else {
                            break;
                        }
                    }

                    if (stableCount >= M) {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    bool IsConsecutiveRiseAndStabilize(int N, int M, double epsilon) {
        int len = ArraySize(ExtremaArray);
        int highCount = 0;
        int lowCount = 0;
        int stableCount = 0; // 安定しているかをカウントする新しい変数
        double lastHighValue = -DBL_MAX; // 上昇を検知するための変数を初期化
        double lastLowValue = -DBL_MAX;  // 上昇を検知するための変数を初期化

        for (int i = len - 1; i >= 0; i--) {
            Extremum ex = ExtremaArray[i];

            if (ex.isPeak) {  // ピークの場合
                if (ex.value > lastHighValue) {
                    lastHighValue = ex.value;
                    highCount++;
                } else {
                    highCount = 0;
                    lastHighValue = -DBL_MAX;
                }
            } else {  // 谷の場合
                if (ex.value > lastLowValue) {
                    lastLowValue = ex.value;
                    lowCount++;
                } else {
                    lowCount = 0;
                    lastLowValue = -DBL_MAX;
                }
            }

            if (highCount >= N && lowCount >= N) {
                // N回の連続上昇を確認した後に、M回の安定を確認する
                for (int j = i; j >= 0; j--) {
                    Extremum nextEx = ExtremaArray[j];

                    if (!nextEx.isPeak) { 
                        if (MathAbs(nextEx.value - lastLowValue) <= epsilon) {
                            stableCount++;
                            lastLowValue = nextEx.value;
                        } else {
                            break; 
                        }
                    }

                    if (stableCount >= M) {
                        return true; 
                    }
                }
            }
        }

        return false; 
    }

    // ピークと谷が連続してN回上昇したかを判定する（ショートエントリー用）
    bool IsConsecutiveRise(int N) {
        int len = ArraySize(ExtremaArray);
        int highCount = 0;
        int lowCount = 0;
        double lastHighValue = -DBL_MAX;
        double lastLowValue = -DBL_MAX;

        for (int i = len - 1; i >= 0; i--) {
            Extremum ex = ExtremaArray[i];

            if (ex.isPeak) {  // ピークの場合
                if (ex.value > lastHighValue) {
                    lastHighValue = ex.value;
                    highCount++;
                } else {
                    highCount = 0;
                    lastHighValue = -DBL_MAX;
                }
            } else {  // 谷の場合
                if (ex.value > lastLowValue) {
                    lastLowValue = ex.value;
                    lowCount++;
                } else {
                    lowCount = 0;
                    lastLowValue = -DBL_MAX;
                }
            }

            if (highCount >= N && lowCount >= N) {
                break;
            }
        }

        printer.PrintLog("Rise highCount: " + highCount + " lowCount: " + lowCount);
        return highCount >= N && lowCount >= N;
    }

    // ピークと谷が連続してN回下降したかを判定する（ロングエントリー用）
    bool IsConsecutiveFall(int N) {
        int len = ArraySize(ExtremaArray);
        int highCount = 0;
        int lowCount = 0;
        double lastHighValue = DBL_MAX;
        double lastLowValue = DBL_MAX;

        for (int i = len - 1; i >= 0; i--) {
            Extremum ex = ExtremaArray[i];

            if (ex.isPeak) {  // ピークの場合
                if (ex.value < lastHighValue) {
                    lastHighValue = ex.value;
                    highCount++;
                } else {
                    highCount = 0;
                    lastHighValue = DBL_MAX;
                }
            } else {  // 谷の場合
                if (ex.value < lastLowValue) {
                    lastLowValue = ex.value;
                    lowCount++;
                } else {
                    lowCount = 0;
                    lastLowValue = DBL_MAX;
                }
            }

            if (highCount >= N && lowCount >= N) {
                break;
            }
        }

        printer.PrintLog("Fall highCount: " + highCount + " lowCount: " + lowCount);
        return highCount >= N && lowCount >= N;
    }

    double FindMostTouchedPrice(double &highs[], double &lows[], double zoneWidth, int minTouches)
    {
        double allExtremas[];
        ArrayResize(allExtremas, ArraySize(highs) + ArraySize(lows));
        ArrayCopy(allExtremas, highs);
        ArrayCopy(allExtremas, lows, 0, ArraySize(highs), WHOLE_ARRAY);
        
        int mostTouches = minTouches;
        double mostTouchedPrice = -1;
        for(int i = 0; i < ArraySize(allExtremas); ++i)
        {
            int touches = 0;
            for(int j = 0; j < ArraySize(allExtremas); ++j)
            {
                if(i != j && MathAbs(allExtremas[i] - allExtremas[j]) <= zoneWidth)
                    touches++;
            }
            if(touches >= mostTouches)
            {
                mostTouches = touches;
                mostTouchedPrice = allExtremas[i];
            }
        }
        return mostTouchedPrice;
    }

    // EMA100から特定のpips数以上離れて連続しているかを判定する関数
    bool IsContinuouslyDroppingBelowEMA100ByPips(double pipsDistance, int barsToCheck = 100) {
        int currentBar = 0;
        double ema100;
        double distance = pipsDistance * Point;

        int countBelowEMA = 0;
        for(int i = currentBar; i < currentBar + barsToCheck; i++) {
            ema100 = iMA(NULL, 0, 100, 0, MODE_EMA, PRICE_CLOSE, i);
            if (Close[i] < ema100 - distance) {
                countBelowEMA++;
            } else {
                break; // 連続していない場合はループを抜ける
            }
        }

        return countBelowEMA == barsToCheck;
    }

    // 損切り幅が10pips未満なら10pipsを損切り幅とする
    double CalculateStopLossForLong(double entryPrice, double recentLow, double pipsDistance) {
        double minStopDistance = pipsDistance * Point;

        if (entryPrice - recentLow < minStopDistance) {
            return entryPrice - minStopDistance;
        } else {
            return recentLow;
        }
    }

    // 損切り幅が10pips未満なら10pipsを損切り幅とする
    double CalculateStopLossForShort(double entryPrice, double recentHigh, double pipsDistance) {
        double minStopDistance = pipsDistance * Point;

        if (recentHigh - entryPrice < minStopDistance) {
            return entryPrice + minStopDistance;
        } else {
            return recentHigh;
        }
    }

    // 資金に対して適切なロットサイズを計算する
    double GetLotSize(TradeAction action, double stopLossPrice) {
        double entryPrice = MarketInfo(symbol, MODE_BID);

        if (action == BUY) {
            entryPrice = MarketInfo(symbol, MODE_ASK);
            stopLossPrice = lowestPrice;
        }
        
        double stopLossPips = lotMgr.PriceDifferenceToPips(entryPrice, stopLossPrice);
        double lotSize = lotMgr.CalculateLot(stopLossPips);
        return lotSize;
    }

    void DisplayInfo()
    {
        // Account info
        double accountBalance = AccountBalance();
        double accountMargin = AccountFreeMarginCheck(symbol, OP_BUY, 1.0);
        
        // Trading info
        double spread = MarketInfo(symbol, MODE_SPREAD);
        
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
