// Candlestick.mqh
#property strict
#include "Utility.mqh"

class Candlestick
{
private:
    Utility ut;

    struct Candle {
        double open;
        double high;
        double low;
        double close;
        double bodySize;
        double upperWickSize;
        double lowerWickSize;
        bool isBullish;
        datetime timestamp;
    };

    Candle candle;

public:
    Candlestick() {
        GetCandle(1);
    }

    void GetCandle(int candleIndex, int timeframe = PERIOD_CURRENT) {
        candle.open = iOpen(NULL, timeframe, candleIndex);
        candle.close = iClose(NULL, timeframe, candleIndex);
        candle.high = iHigh(NULL, timeframe, candleIndex);
        candle.low = iLow(NULL, timeframe, candleIndex);
        candle.bodySize = NormalizeDouble(MathAbs(candle.open - candle.close), Digits());
        candle.isBullish = candle.close > candle.open;
        candle.timestamp = iTime(NULL, timeframe, candleIndex);
        CalculateWickSizes(candle);
    }

    void ShowCandleDetail() {
        Print("Timestamp: ", TimeToString(candle.timestamp, TIME_DATE|TIME_MINUTES));
        Print("Open: ", candle.open);
        Print("High: ", candle.high);
        Print("Low: ", candle.low);
        Print("Close: ", candle.close);
        Print("Body Size: ", candle.bodySize);
        Print("Upper Wick Size: ", candle.upperWickSize);
        Print("Lower Wick Size: ", candle.lowerWickSize);
        Print("Is Bullish: ", candle.isBullish ? "Yes" : "No");
    }

    // ローソク足が陽線なら True
    bool IsBullishCandle(int candleIndex) {
        GetCandle(candleIndex);
        return candle.isBullish;
    }

    bool IsUpCandle(int timeframe) {
        double open = iOpen(NULL, timeframe, 1);
        double close = iClose(NULL, timeframe, 1);
        double prevOpen = iOpen(NULL, timeframe, 2);
        double prevClose = iClose(NULL, timeframe, 2);

        double high = iHigh(NULL, timeframe, 1);
        double low = iLow(NULL, timeframe, 1);
        double prevHigh = iHigh(NULL, timeframe, 2);
        double prevLow = iLow(NULL, timeframe, 2);

        bool yousen = close > open && prevClose > prevOpen;
        bool higher = high > prevHigh && low > prevLow;

        return yousen && higher;
    }

    bool IsDownCandle(int timeframe) {
        double open = iOpen(NULL, timeframe, 1);
        double close = iClose(NULL, timeframe, 1);
        double prevOpen = iOpen(NULL, timeframe, 2);
        double prevClose = iClose(NULL, timeframe, 2);

        double high = iHigh(NULL, timeframe, 1);
        double low = iLow(NULL, timeframe, 1);
        double prebHigh = iHigh(NULL, timeframe, 2);
        double prevLow = iLow(NULL, timeframe, 2);

        bool insen = close < open && prevClose < prevOpen;
        bool lower = high < prebHigh && low < prevLow;

        return insen && lower;
    }

    // 連続して陽線が続いたかどうか
    bool IsConsecutiveBullishCandle(int shift, int n) {
        int counter = 0;
        for (int i = 1; i <= shift; i++) {
             if (Close[i] > Open[i]) {
                counter++;
             } else {
                counter = 0;
             }
        }

        return counter >= n;
    }

    // 連続して陰線が続いたかどうか
    bool IsConsecutiveBearlishCandle(int shift, int n) {
        int counter = 0;
        for (int i = 1; i <= shift; i++) {
             if (Close[i] < Open[i]) {
                counter++;
             } else {
                counter = 0;
             }
        }

        return counter >= n;
    }
    
    // 連続して陰線が続いた後、陽線で安値が切りあがる（押し目買いエントリー）
    // bool isBullishReversal(int shift, int n) {
    //     int counter = 0;
    //     bool isReversal = false;

    //     for (int i = 1; i <= shift; i++) {
    //         // 陰線をカウント
    //         if (Close[i] < Open[i]) {
    //             counter++;
    //             // 連続してN回以上陰線が続いているか確認
    //             if (counter >= n) {
    //                 // 次のローソク足が陽線で、かつ安値が前の陰線の安値より高いかチェック
    //                 if (Close[i-1] > Open[i-1] && Low[i-1] > Low[i]) {
    //                     isReversal = true;
    //                     break;
    //                 }
    //             }
    //         } else if (Close[i] > Open[i] && counter < n) {
    //             // 陽線が出たらカウントをリセット
    //             counter = 0;    
    //         }
    //     }

    //     return isReversal;
    // }

    // 連続して陰線が続いた後、陽線で安値が切り上がる（押し目買いエントリー）
    bool IsBullishReversal() {
        bool upCandle = IsUpCandle(1);
        bool c2 = IsBullishCandle(2);
        bool c3 = IsBullishCandle(3);
        bool c4 = IsBullishCandle(4);
        bool c5 = IsBullishCandle(5);

        return upCandle && c2 && !c3 && !c4 && !c5; 
    }

    // 連続して陽線が続いた後、陰線で高値が切り下がる（戻り売りエントリー）
    bool IsBearlishReversal() {
        bool downCandle = IsDownCandle(1);
        bool c2 = IsBullishCandle(2);
        bool c3 = IsBullishCandle(3);
        bool c4 = IsBullishCandle(4);
        bool c5 = IsBullishCandle(5);

        return downCandle && !c2 && c3 && c4 && c5; 
    }

    // 直近N分間の最高価格を返す
    double GetHighestPrice(int n, int timeframe = PERIOD_CURRENT) {
        int highBar = iHighest(NULL, timeframe, MODE_HIGH, n, 1);
        return iHigh(NULL, timeframe, highBar);
    }

    // 直近N分間の最低価格を返す
    double GetLowestPrice(int n, int timeframe = PERIOD_CURRENT) {
        int lowBar = iLowest(NULL, timeframe, MODE_LOW, n, 1);
        return iLow(NULL, timeframe, lowBar);
    }

    // 一つ前のローソク足から高値・安値が切り上がっているか
    bool IsHigherHighAndHigherLow(int timeframe, int candleIndex) {
        double currHigh = iHigh(NULL, timeframe, candleIndex);
        double currLow = iLow(NULL, timeframe, candleIndex);
        double prevHigh = iHigh(NULL, timeframe, candleIndex + 1);
        double prevLow = iLow(NULL, timeframe, candleIndex + 1);

        return currHigh > prevHigh && currLow > prevLow;
    }

    // 一つ前のローソク足から高値・安値が切り下がっているか
    bool IsLowerHighAndLowerLow(int timeframe, int candleIndex) {
        double currHigh = iHigh(NULL, timeframe, candleIndex);
        double currLow = iLow(NULL, timeframe, candleIndex);
        double prevHigh = iHigh(NULL, timeframe, candleIndex + 1);
        double prevLow = iLow(NULL, timeframe, candleIndex + 1);

        return currHigh < prevHigh && currLow < prevLow;
    }

    // 連続して切り上がっているか
    bool IsContinuousHigh(int timeframe, int candleIndex) {
        double high1 = iHigh(NULL, timeframe, candleIndex);
        double high2 = iHigh(NULL, timeframe, candleIndex + 1);
        double high3 = iHigh(NULL, timeframe, candleIndex + 2);
        double low1 = iLow(NULL, timeframe, candleIndex);
        double low2 = iLow(NULL, timeframe, candleIndex + 1);
        double low3 = iLow(NULL, timeframe, candleIndex + 2);

        return high1 > high2 && high2 > high3 && low1 > low2 && low2 > low3;
    }

    // 連続して切り下がっているか
    bool IsContinuousLow(int timeframe, int candleIndex) {
        double high1 = iHigh(NULL, timeframe, candleIndex);
        double high2 = iHigh(NULL, timeframe, candleIndex + 1);
        double high3 = iHigh(NULL, timeframe, candleIndex + 2);
        double low1 = iLow(NULL, timeframe, candleIndex);
        double low2 = iLow(NULL, timeframe, candleIndex + 1);
        double low3 = iLow(NULL, timeframe, candleIndex + 2);

        return high1 < high2 && high2 < high3 && low1 < low2 && low2 < low3;
    }

    // 2つの直近の極大値・極小値が連続して上昇しているか
    string GetTrend(int timeframe, int barsCount) {
        int lastHighBar = iHighest(NULL, timeframe, MODE_HIGH, barsCount, 1);
        int previousHighBar = iHighest(NULL, timeframe, MODE_HIGH, barsCount, lastHighBar + 1);
        int lastLowBar = iLowest(NULL, timeframe, MODE_LOW, barsCount, 1);
        int previousLowBar = iLowest(NULL, timeframe, MODE_LOW, barsCount, lastLowBar + 1);

        double lastHighValue = iHigh(NULL, timeframe, lastHighBar);
        double previousHighValue = iHigh(NULL, timeframe, previousHighBar);
        double lastLowValue = iLow(NULL, timeframe, lastLowBar);
        double previousLowValue = iLow(NULL, timeframe, previousLowBar);

        if (lastHighValue > previousHighValue && lastLowValue > previousLowValue) {
            return "UP TREND";
        }

        if (lastHighValue < previousHighValue && lastLowValue < previousLowValue) {
            return "DOWN TREND";
        }

        return "RANGE";
    }

    // スラストアップ：強い上昇のサイン
    bool IsThrustUp(int timeframe, int candleIndex) {
        double prevHigh = iHigh(NULL, timeframe, candleIndex + 1);
        double currClose = iClose(NULL, timeframe, candleIndex);

        return (currClose > prevHigh);
    }
    
    // スラストダウン：強い下降のサイン
    bool IsThrustDown(int timeframe, int candleIndex) {
        double prevLow = iLow(NULL, timeframe, candleIndex + 1);
        double currClose = iClose(NULL, timeframe, candleIndex);

        return (currClose < prevLow);
    }

    // 陽線の包み足（アウトサイドバー）: 反転する根拠
    // 1本目のローソク足を高値安値を2本目のローソク足の高値安値が包んでいる
    // 1本目の高値を2本目のローソク足の終値で超えている
    // エントリー: 包み足の確認後にエントリー、または2本目の高値をブレイク
    bool IsBullishOutSideBar(int timeframe, int candleIndex) {
        double prevOpen = iOpen(NULL, timeframe, candleIndex + 1);
        double prevClose = iClose(NULL, timeframe, candleIndex + 1);
        double prevHigh = iHigh(NULL, timeframe, candleIndex + 1);
        double prevLow = iLow(NULL, timeframe, candleIndex + 1);
        double currOpen = iOpen(NULL, timeframe, candleIndex);
        double currClose = iClose(NULL, timeframe, candleIndex);
        double currLow = iLow(NULL, timeframe, candleIndex);

        bool isPrevBearish = prevOpen > prevClose;
        bool isCurrBullish = currOpen < currClose;
        bool doesEngulf = currLow <= prevLow && currClose >= prevHigh;

        return isPrevBearish && isCurrBullish && doesEngulf;
    }

    // 陰線の包み足（アウトサイドバー）: 反転する根拠
    // 1本目のローソク足を高値安値を2本目のローソク足の高値安値が包んでいる
    // 1本目の安値を2本目のローソク足の終値で超えている
    // エントリー: 包み足の確認後にエントリー、または2本目の安値をブレイク
    bool IsBearishOutSideBar(int timeframe, int candleIndex) {
        double prevOpen = iOpen(NULL, timeframe, candleIndex + 1);
        double prevClose = iClose(NULL, timeframe, candleIndex + 1);
        double prevHigh = iHigh(NULL, timeframe, candleIndex + 1);
        double prevLow = iLow(NULL, timeframe, candleIndex + 1);
        double currOpen = iOpen(NULL, timeframe, candleIndex);
        double currClose = iClose(NULL, timeframe, candleIndex);
        double currHigh = iHigh(NULL, timeframe, candleIndex);

        bool isPrevBullish = prevOpen < prevClose;
        bool isCurrBearish = currOpen > currClose;
        bool doesEngulf = currHigh >= prevHigh && currClose <= prevLow;

        return isPrevBullish && isCurrBearish && doesEngulf;
    }

    // 陽の陽包み（アウトサイドバー）: トレンドへの追随
    // 1本目のローソク足を高値安値を2本目のローソク足の高値安値が包んでいる
    // 1本目の高値を2本目のローソク足の終値で超えている
    // エントリー: 包み足の確認後にエントリー、または2本目の高値をブレイク
    bool IsBullishOutSideBar2(int timeframe, int candleIndex) {
        double prevOpen = iOpen(NULL, timeframe, candleIndex + 1);
        double prevClose = iClose(NULL, timeframe, candleIndex + 1);
        double prevHigh = iHigh(NULL, timeframe, candleIndex + 1);
        double prevLow = iLow(NULL, timeframe, candleIndex + 1);
        double currOpen = iOpen(NULL, timeframe, candleIndex);
        double currClose = iClose(NULL, timeframe, candleIndex);
        double currLow = iLow(NULL, timeframe, candleIndex);

        bool isPrevBullish = prevOpen < prevClose;
        bool isCurrBullish = currOpen < currClose;
        bool doesEngulf = currLow <= prevLow && currClose >= prevHigh;

        return isPrevBullish && isCurrBullish && doesEngulf;
    }

    // 陰の陰包み（アウトサイドバー）: トレンドへの追随
    // 1本目のローソク足を高値安値を2本目のローソク足の高値安値が包んでいる
    // 1本目の安値を2本目のローソク足の終値で超えている
    // エントリー: 包み足の確認後にエントリー、または2本目の安値をブレイク
    bool IsBearishOutSideBar2(int timeframe, int candleIndex) {
        double prevOpen = iOpen(NULL, timeframe, candleIndex + 1);
        double prevClose = iClose(NULL, timeframe, candleIndex + 1);
        double prevHigh = iHigh(NULL, timeframe, candleIndex + 1);
        double prevLow = iLow(NULL, timeframe, candleIndex + 1);
        double currOpen = iOpen(NULL, timeframe, candleIndex);
        double currClose = iClose(NULL, timeframe, candleIndex);
        double currHigh = iHigh(NULL, timeframe, candleIndex);

        bool isPrevBearish = prevOpen > prevClose;
        bool isCurrBearish = currOpen > currClose;
        bool doesEngulf = currHigh >= prevHigh && currClose <= prevLow;

        return isPrevBearish && isCurrBearish && doesEngulf;
    }

    // ピンバー: 小さな実体と長い下ヒゲを持つローソク足を検出 IsLongLowerWick(PERIOD_M15, 1, 0.2, 3)
    bool IsLongLowerWick(int timeframe, int candleIndex, double wickFactor, int minWickPips) {
        GetCandle(candleIndex, timeframe);
        bool isBodySizeEnough = candle.lowerWickSize >= candle.bodySize * wickFactor;
        bool isWickLongEnough = candle.lowerWickSize >= ut.PipsToPrice(minWickPips);
        bool isLowerWickTwiceUpper = candle.lowerWickSize >= 2 * candle.upperWickSize;

        // 実体が小さく、下ヒゲが実体の指定された倍以上、下ヒゲが上ヒゲよりも大きいか
        return isBodySizeEnough && isWickLongEnough && isLowerWickTwiceUpper;
    }

    // ピンバー: 小さな実体と長い上ヒゲを持つローソク足を検出 IsLongUpperWick(PERIOD_M15, 1, 0.2, 3)
    bool IsLongUpperWick(int timeframe, int candleIndex, double wickFactor, int minWickPips) {
        GetCandle(candleIndex, timeframe);
        bool isBodySizeEnough = candle.upperWickSize >= candle.bodySize * wickFactor;
        bool isWickLongEnough = candle.upperWickSize >= ut.PipsToPrice(minWickPips);
        bool isUpperWickTwiceUpper = candle.upperWickSize >= 2 * candle.lowerWickSize;

        // 実体が小さく、上ヒゲが実体の指定された倍以上、上ヒゲが下ヒゲよりも大きいか
        return isBodySizeEnough && isWickLongEnough && isUpperWickTwiceUpper;
    }

    // 三尊: ショート用
    bool IsHeadAndShouldersSell(int timeframe, int candleIndex) {
        bool yousen = iClose(NULL, timeframe, candleIndex + 2) > iOpen(NULL, timeframe, candleIndex + 2);
        bool pinbar = IsLongUpperWick(timeframe, candleIndex + 1, 0.2, 3);
        bool insen = iClose(NULL, timeframe, candleIndex) < iOpen(NULL, timeframe, candleIndex);

        return yousen && pinbar && insen;
    }

    // 三尊: ロング用
    bool IsHeadAndShouldersBuy(int timeframe, int candleIndex) {
        bool insen = iClose(NULL, timeframe, candleIndex + 2) < iOpen(NULL, timeframe, candleIndex + 2);
        bool pinbar = IsLongLowerWick(timeframe, candleIndex + 1, 0.2, 3);
        bool yousen = iClose(NULL, timeframe, candleIndex) > iOpen(NULL, timeframe, candleIndex);

        return insen && pinbar && yousen;
    }

    // ローソク足の大きさを確認
    bool IsExceptionallyLargeCandle(int action, int timeframe) {
        double openPrice = iOpen(NULL, timeframe, 0);
        double closePrice = iClose(NULL, timeframe, 0);
        double highPrice = iHigh(NULL, timeframe, 0);
        double lowPrice = iLow(NULL, timeframe, 0);

        if (action == 1 && closePrice < openPrice) {
            return false; // 陰線の場合
        }
        if (action == 2 && closePrice > openPrice) {
            return false; // 陽線の場合
        }

        double bodyLength = MathAbs(closePrice - openPrice); // 実体の絶対値を取得
        double compareBody = MaximumBodyLength(timeframe, 20, 1);
        double wickLength;

        if (closePrice > openPrice) // 陽線の場合
            wickLength = highPrice - closePrice; // 上ヒゲの長さ
        else
            wickLength = openPrice - lowPrice; // 下ヒゲの長さ

        // 直近20本で比較的大きい（またはNpips以上）でヒゲが小さいローソク足
        return bodyLength > compareBody
            && bodyLength >= ut.PipsToPrice(5)
            && wickLength < bodyLength * 0.1;
    }

    // ローソク足の傾きを度数で取得する
    double GetCandleSlopeInDegrees(int timeframe, int backShift = 3, bool isHigh = true) {
        double low = iLow(NULL, timeframe, 0);
        double lowShift = iLow(NULL, timeframe, backShift);

        // 価格変化を取得
        double deltaPrice = (low - lowShift) / Point;

        if (isHigh) {
            double high = iHigh(NULL, timeframe, 0);
            double highShift = iHigh(NULL, timeframe, backShift);
            deltaPrice = (high - highShift) / Point;
        }
        
        // 時間（バーの数）による変化を取得
        double deltaTime = backShift;
        
        // 傾きの角度（ラジアン）を計算
        double angleInRadians = atan(deltaPrice / deltaTime);

        // 傾きの角度を度数で取得
        double angleInDegrees = angleInRadians * (180.0 / M_PI);
        
        return angleInDegrees;
    }

    // MAの傾きを度数で取得する
    double GetMovingAverageSlopeInDegrees(int maPeriod = 20, int maMethod = MODE_SMA, int backShift = 20) {
        double firstMA = iMA(NULL, 0, maPeriod, 0, maMethod, PRICE_CLOSE, 0);
        double secondMA = iMA(NULL, 0, maPeriod, 0, maMethod, PRICE_CLOSE, backShift);
        
        // 価格変化を取得
        double deltaPrice = (firstMA - secondMA) / Point;
        
        // 時間（バーの数）による変化を取得
        double deltaTime = backShift;
        
        // 傾きの角度（ラジアン）を計算
        double angleInRadians = atan(deltaPrice / deltaTime);

        // 傾きの角度を度数で取得
        double angleInDegrees = angleInRadians * (180.0 / M_PI);
        
        return angleInDegrees;
    }

    // パーフェクトオーダーを判定
    bool IsPerfectOrder(string order, int timeframe = PERIOD_CURRENT) {
        double maShort = iMA(NULL, timeframe, 50, 0, MODE_SMA, PRICE_CLOSE, 0);
        double maMiddle = iMA(NULL, timeframe, 100, 0, MODE_SMA, PRICE_CLOSE, 0);
        double maLong = iMA(NULL, timeframe, 200, 0, MODE_SMA, PRICE_CLOSE, 0);
        double maShortPrev = iMA(NULL, timeframe, 50, 0, MODE_SMA, PRICE_CLOSE, 10);
        double maMiddlePrev = iMA(NULL, timeframe, 100, 0, MODE_SMA, PRICE_CLOSE, 10);
        double maLongPrev = iMA(NULL, timeframe, 200, 0, MODE_SMA, PRICE_CLOSE, 10);

        if (order == "BUY") {
            return maShort > maMiddle && maMiddle > maLong &&
                   maLong > maLongPrev && maMiddle > maMiddlePrev && maLong > maLongPrev;
        }

        if (order == "SELL") {
            return maShort < maMiddle && maMiddle < maLong &&
                   maLong < maLongPrev && maMiddle < maMiddlePrev && maLong < maLongPrev;
        }

        return false;
    }

    // パーフェクトオーダーを判定(マルチタイムフレーム)
    bool IsPerfectOrderMTF(string order) {
        double maShort = iMA(NULL, PERIOD_CURRENT, 20, 0, MODE_SMA, PRICE_CLOSE, 0);
        double maMiddle = iMA(NULL, PERIOD_M5, 20, 0, MODE_SMA, PRICE_CLOSE, 0);
        double maLong = iMA(NULL, PERIOD_M15, 20, 0, MODE_SMA, PRICE_CLOSE, 0);
        double maShortPrev = iMA(NULL, PERIOD_CURRENT, 20, 0, MODE_SMA, PRICE_CLOSE, 10);
        double maMiddlePrev = iMA(NULL, PERIOD_M5, 20, 0, MODE_SMA, PRICE_CLOSE, 10);
        double maLongPrev = iMA(NULL, PERIOD_M15, 20, 0, MODE_SMA, PRICE_CLOSE, 10);

        if (order == "BUY") {
            return maShort > maMiddle && maMiddle > maLong &&
                   maLong > maLongPrev && maMiddle > maMiddlePrev && maLong > maLongPrev;
        }

        if (order == "SELL") {
            return maShort < maMiddle && maMiddle < maLong &&
                   maLong < maLongPrev && maMiddle < maMiddlePrev && maLong < maLongPrev;
        }

        return false;
    }

    // MACDの値を取得（正の値: 上昇トレンド、負の値: 下降トレンド)
    double GetValueOfMACD(int fastEMA = 12, int slowEMA = 26, int signalSMA = 9, int shift = 0) {
        return iMACD(NULL, PERIOD_CURRENT, fastEMA, slowEMA, signalSMA, PRICE_CLOSE, MODE_MAIN, shift);
    }

private:
    double MaximumBodyLength(int timeframe, int barsToConsider, int startShift) {
        double maxBodyLength = 0;
        for (int i = 0; i < barsToConsider; i++) {
            double openPrice = iOpen(NULL, timeframe, i + startShift);
            double closePrice = iClose(NULL, timeframe, i + startShift);
            double bodyLength = MathAbs(closePrice - openPrice);
            
            if (bodyLength > maxBodyLength)
                maxBodyLength = bodyLength;
        }
        return maxBodyLength;
    }

    // 上ヒゲと下ヒゲのサイズを計算
    void CalculateWickSizes(Candle &candle) {
        if (candle.isBullish) {
            candle.upperWickSize = NormalizeDouble((candle.high - candle.close), Digits());
            candle.lowerWickSize = NormalizeDouble((candle.open - candle.low), Digits());
        } else {
            candle.upperWickSize = NormalizeDouble((candle.high - candle.open), Digits());
            candle.lowerWickSize = NormalizeDouble((candle.close - candle.low), Digits());
        }
    }

};