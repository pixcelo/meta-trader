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

    // 直近N分間の最高価格を返す
    double GetHighestPrice(int n, int timeframe) {
        int highBar = iHighest(NULL, timeframe, MODE_HIGH, n, 1);
        return iHigh(NULL, timeframe, highBar);
    }

    // 直近N分間の最低価格を返す
    double GetLowestPrice(int n, int timeframe) {
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

    // ピンバー: 小さな実体と長い下ヒゲを持つローソク足を検出 IsLongLowerWick(1, PERIOD_M15, 0.2, 3)
    bool IsLongLowerWick(int timeframe, int candleIndex, double wickFactor, int minWickPips) {
        GetCandle(candleIndex, timeframe);
        bool isBodySizeEnough = candle.lowerWickSize >= candle.bodySize * wickFactor;
        bool isWickLongEnough = candle.lowerWickSize >= ut.PipsToPrice(minWickPips);
        bool isLowerWickTwiceUpper = candle.lowerWickSize >= 2 * candle.upperWickSize;

        // 実体が小さく、下ヒゲが実体の指定された倍以上、下ヒゲが上ヒゲよりも大きいか
        return isBodySizeEnough && isWickLongEnough && isLowerWickTwiceUpper;
    }

    // ピンバー: 小さな実体と長い上ヒゲを持つローソク足を検出 IsLongUpperWick(1, PERIOD_M15, 0.2, 3)
    bool IsLongUpperWick(int timeframe, int candleIndex, double wickFactor, int minWickPips) {
        GetCandle(candleIndex, timeframe);
        bool isBodySizeEnough = candle.upperWickSize >= candle.bodySize * wickFactor;
        bool isWickLongEnough = candle.upperWickSize >= ut.PipsToPrice(minWickPips);
        bool isUpperWickTwiceUpper = candle.upperWickSize >= 2 * candle.lowerWickSize;

        // 実体が小さく、上ヒゲが実体の指定された倍以上、上ヒゲが下ヒゲよりも大きいか
        return isBodySizeEnough && isWickLongEnough && isUpperWickTwiceUpper;
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

    // パーフェクトオーダーを判定
    bool IsPerfectOrder(int action, int timeframe) {
        double maShort = iMA(NULL, timeframe, 50, 0, MODE_SMA, PRICE_CLOSE, 0);
        double maMiddle = iMA(NULL, timeframe, 100, 0, MODE_SMA, PRICE_CLOSE, 0);
        double maLong = iMA(NULL, timeframe, 200, 0, MODE_SMA, PRICE_CLOSE, 0);
        double maShortPrev = iMA(NULL, timeframe, 50, 0, MODE_SMA, PRICE_CLOSE, 10);
        double maMiddlePrev = iMA(NULL, timeframe, 100, 0, MODE_SMA, PRICE_CLOSE, 10);
        double maLongPrev = iMA(NULL, timeframe, 200, 0, MODE_SMA, PRICE_CLOSE, 10);

        if (action == 1) {
            return maShort > maMiddle && maMiddle > maLong &&
                   maLong > maLongPrev && maMiddle > maMiddlePrev && maLong > maLongPrev;
        }

        if (action == 2) {
            return maShort < maMiddle && maMiddle < maLong &&
                   maLong < maLongPrev && maMiddle < maMiddlePrev && maLong < maLongPrev;
        }

        return false;
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