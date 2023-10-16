// TradingLogic.mqh
input double LargeCandleBodyPips = 5.0;        // 大陽線・大陰線のローソク足の実体のpips
input double RiskRewardRatio = 1.0;            // リスクリワード比

// Zigzag
input int Depth = 7;                           // ZigzagのDepth設定
input int Deviation = 5;                       // ZigzagのDeviation設定
input int Backstep = 3;                        // ZigzagのBackstep設定
input int zigzagTerm = 240;                    // 極値を計算する期間

input int ConsecutiveCount = 6;                // 連続して上昇・下降した回数
input int StableCount = 2;                     // 上昇・下降の後に安定した回数
input int MaxHoldingMinutes = 60;              // ポジション保有時間の最大(分)
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

    datetime lastTradeTime;   // 最後にトレードした時間

    enum TradeAction {
        WAIT = 0,
        BUY  = 1,
        SELL = 2
    };

    double trendReversalLineForLong;
    double trendReversalLineForShort;

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
            // 途中決済
            orderMgr.CheckAndCloseStagnantPositions(MaxHoldingMinutes, Magic);
            return;
        }

        // Set up
        zzSeeker.UpdateExtremaArray(zigzagTerm, 500);
        lineMgr.IdentifyStrongHorizontalLinesByExtrema(horizontalLineThreshold);

        /// ==========================test=====================
        // Print values to check if they are populated correctly
        // Print("zigzag Values: ");
        // for (int k = 0; k < ArraySize(ExtremaArray); k++) {
        //     Print("Timestamp: ", ExtremaArray[k].timestamp, ", Value: ", ExtremaArray[k].value, " isPeak: ", ExtremaArray[k].isPeak);
        // }

        // Startegy
        LineTrade();

        // Draw objects
        if (Visualmode) {
            chartDrawer.DeleteAllObjects();
            //chartDrawer.DrawTrendReversalLines(trendReversalLineForLong, trendReversalLineForShort);
            chartDrawer.DrawPeaksAndValleys(ExtremaArray, 500);
            for (int i = 0; i < ArraySize(hLines); i++) {
                string lineName = StringFormat("hLine%d_", i);
                int strength = hLines[i].strength;
                //Print("strength ", strength);
                if (strength < 0) {
                    continue;
                }
                chartDrawer.DrawHorizontalLineWithStrength(lineName + strength, hLines[i].price, strength);
            }
        }

        chartDrawer.DrawTrendLineFromPeaksAndValleys(ExtremaArray);
    }

private:
    void LineTrade() {
        if (TimeCurrent() - lastTradeTime < lastTradeIntervalSeconds) {
            return;
        }

        // トレンドラインの色で環境認識（オブジェクトが存在しない場合、clrNONE=0を返す）
        color plineClr = chartDrawer.GetObjColor("PeakTrendLine");
        color vlineClr = chartDrawer.GetObjColor("ValleyTrendLine");

        if (plineClr == clrNONE || vlineClr == clrNONE) {
            return;
        }

        // 1時間MAでフィルタリング
        double ma1h = iMA(symbol, PERIOD_H1, 20, 0, MODE_SMA, PRICE_CLOSE, 0);
        double ma1hPrev = iMA(symbol, PERIOD_H1, 20, 0, MODE_SMA, PRICE_CLOSE, 1);
        double maDiff = ma1h - ma1hPrev;

        int direction = 0;
        double trendLinePrice = 0;
        double stopLossPrice = 0;
        double takeProfitPrice = 0;
        double lotSize = 0;
        int ticket = 0;

        // TODO: 急激な値動きはブレイクの可能性があるので反発を狙わないようにするロジックが必要
        
        // Check Entry condition
        if (plineClr == clrGreen && vlineClr == clrGreen) {
            // 上昇トレンド中に下側のトレンドラインに近づいたら、押し目買いを狙う
            trendLinePrice = chartDrawer.GetTrendLinePriceAtCurrentBar("ValleyTrendLine");
            direction = PriceReboundDirection(2, trendLinePrice);

            if (direction == 1 && maDiff > 0) {
                double latestValleyValue = zzSeeker.GetLatestValue(false); // 直近の極値が押し目買いの損切ラインになる（少し上が良い 2pipsくらい？
                stopLossPrice = latestValleyValue - utility.PipsToPrice(10);
                lotSize = GetLotSize(BUY, stopLossPrice);
                ticket = orderMgr.PlaceBuyOrder(lotSize, stopLossPrice, takeProfitPrice, RiskRewardRatio, Magic);
                if (ticket > 0) {
                    lastTradeTime = TimeCurrent();
                }
            }
        }

        if (plineClr == clrRed && vlineClr == clrRed) {
            // 下降トレンド中に上側のトレンドラインに近づいたら、戻り売りを狙う
            trendLinePrice = chartDrawer.GetTrendLinePriceAtCurrentBar("PeakTrendLine");
            direction = PriceReboundDirection(2, trendLinePrice);

            if (direction == 2 && maDiff < 0) {
                double latestPeakValue = zzSeeker.GetLatestValue(true);
                stopLossPrice = latestPeakValue + utility.PipsToPrice(10); // 直近の極値が戻り売りの損切ラインになる（少し上が良い 2pipsくらい？
                lotSize = GetLotSize(SELL, stopLossPrice);
                ticket = orderMgr.PlaceSellOrder(lotSize, stopLossPrice, takeProfitPrice, RiskRewardRatio, Magic);
                if (ticket > 0) {
                    lastTradeTime = TimeCurrent();
                }
            }
        }
    }

    // 1: 価格が上から近づいて上に離れた
    // 2: 価格が下から近づいて下に離れた
    // 0: どちらでもない
    int PriceReboundDirection(double allowedPipsAway, double targetPrice) {

        double pointAway = utility.PipsToPrice(allowedPipsAway);
        bool approachedFromAbove = Close[1] > Close[0];

        if (approachedFromAbove) {
            if (Low[1] <= targetPrice 
                && Close[1] > targetPrice
                && Close[0] > targetPrice + pointAway) {
                // 価格が上から近づき、その後トレンドラインの上に反発した
                return 1;
            }
        } else {
            if (High[1] >= targetPrice
                && Close[1] < targetPrice
                && Close[0] < targetPrice - pointAway) {
                // 価格が下から近づき、その後トレンドラインの下に反発した
                return 2;
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
                //highestPrice = ex.value;
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
                //lowestPrice = ex.value;
            }
        }

        return trendReversalLine;
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
            }
        }

        //UpdateTrendReversalLine();

        if (trendReversalLineForShort > 0) {
            return SELL;
        }

        if (trendReversalLineForLong > 0) {
            return BUY;
        }

        return WAIT;
    }

    // TODO: lowestPrice, highestPriceをグローバルからアクセスさせるのをやめる
    // トレンド転換ラインがある状態で最高値・最安値が更新された場合はトレンド転換ラインを動かす
    // void UpdateTrendReversalLine() {
    //     if (trendReversalLineForShort > 0 && lowestPrice > iLow(symbol, timeframe, 0)) { 
    //         Initialize();
    //         trendReversalLineForShort = GetTrendReversalLineForShort(50);
    //     }

    //     if (trendReversalLineForLong > 0 && highestPrice < iHigh(symbol, timeframe, 0)) {
    //         Initialize();
    //         trendReversalLineForLong = GetTrendReversalLineForLong(50);
    //     }
    // }

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
        double stopLossPrice = SetStopLossPriceByLatestValue(BUY);
        //double takeProfitPrice = Close[0] + 10 * Point * utility.GetPointCoefficient();
        double takeProfitPrice = 0;
        double lotSize = GetLotSize(BUY, stopLossPrice);
        int result = orderMgr.PlaceBuyOrder(lotSize, stopLossPrice, takeProfitPrice, RiskRewardRatio, Magic);
        if (result > 0) {
            lastTradeTime = TimeCurrent();
        }
    }

    void SellOrder() {
        double stopLossPrice = SetStopLossPriceByLatestValue(SELL);
        //double takeProfitPrice = Close[0] - 10 * Point * utility.GetPointCoefficient();
        double takeProfitPrice = 0;
        double lotSize = GetLotSize(SELL, stopLossPrice);
        int result = orderMgr.PlaceSellOrder(lotSize, stopLossPrice, takeProfitPrice, RiskRewardRatio, Magic);
        if (result > 0) {
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

};