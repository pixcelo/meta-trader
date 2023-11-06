// RangeBox.mqh
#property strict
#include "Candlestick.mqh"
#include "Utility.mqh"

class RangeBox
{
private:
    Candlestick cs;
    Utility ut;

    struct boxPrice {
        double open;
        double high;
        double low;
        double close;
        datetime timestamp; 
    };

    boxPrice currentBoxPrice;
    boxPrice boxPrices[];
    int minBoxRange;
    double minBoxPips;
    double maxBoxPips;
    double stopLossPrice;
    datetime lastTimestamp;
    int boxCounter;

    datetime lastLongCheckedTime;
    double highestLongValue;
    double lowestLongValue;

    datetime lastShortCheckedTime;
    double highestShortValue;
    double lowestShortValue;

public:
    void Init(int minBoxRangeInput, double minBoxPipsInput, double maxBoxPipsInput) {
        minBoxRange = minBoxRangeInput;
        minBoxPips = minBoxPipsInput * Point;
        maxBoxPips = maxBoxPipsInput * Point;
        boxCounter = 0;
        lastTimestamp = 0;
        lastLongCheckedTime = 0;
        lastShortCheckedTime = 0;
    }

    // Called on each new tick
    int OnTick() {
        currentBoxPrice.open = Open[0];
        currentBoxPrice.high = High[0];
        currentBoxPrice.low = Low[0];
        currentBoxPrice.close = Close[0];
        currentBoxPrice.timestamp = Time[0];

        if (lastTimestamp != Time[0]) {
            // 新しいローソク足が確定した場合
            ArraySetAsSeries(boxPrices, true);
            ArrayResize(boxPrices, ArraySize(boxPrices) + 1);
            boxPrices[ArraySize(boxPrices) - 1] = currentBoxPrice;

            lastTimestamp = Time[0];
        }

        // 高値圏・安値圏を判定する時間足を確認
        // CheckLongBar(PERIOD_H4);
        CheckShortBar(PERIOD_M15);

        // Print("Long ", highestLongValue, " ", lowestLongValue);
        // Print("Short ", highestShortValue, " ", lowestShortValue);

        double highestValue = -DBL_MAX;
        double lowestValue = DBL_MAX;

        for (int i = 0; i < ArraySize(boxPrices); i++) {
            if (boxPrices[i].high > highestValue) highestValue = boxPrices[i].high;
            if (boxPrices[i].low < lowestValue) lowestValue = boxPrices[i].low;
        }

        // 平均と標準偏差を計算
        // double average = CalculateAverage();
        // double deviation = CalculateStandardDeviation(average);
        
        // 外れ値を検出（平均からN倍の標準偏差以上離れた価格を外れ値とする）
        // int outlierCoefficient = 3;
        // if (currentBoxPrice.close > average + outlierCoefficient * deviation) {
        //     // stopLossPrice = average;
        //     stopLossPrice = lowestValue;
        //     isBreakOut = true;
        //     direction = 1;
        // } else if (currentBoxPrice.close < average - outlierCoefficient * deviation) {
        //     // stopLossPrice = average;
        //     stopLossPrice = highestValue;
        //     isBreakOut = true;
        //     direction = 2;
        // }

        int direction = 0;
        int targetCandleIndex = 1;
        double wickFactor = 3.0; 
        int minWickPips = 5;

        // ボックスの中で高値圏での上ヒゲ・安値圏での下ヒゲのローソク足の出現を検知する
        // int positionInLongTerm = DeterminePositionWithinBox(Close[targetCandleIndex], highestLongValue, lowestLongValue, 0.30);
        int positionInShortTerm = DeterminePositionWithinBox(Close[targetCandleIndex], highestShortValue, lowestShortValue, 0.20);
        // Print("positionInLongTerm ",positionInLongTerm, " positionInShortTerm ", positionInShortTerm);

        // ひとつまえの上位足のローソク足の状態を確認 
        
        if (positionInShortTerm == -1
            && cs.IsLongLowerWick(targetCandleIndex, wickFactor, minWickPips)
            && cs.IsBullishCandle(2)
            && cs.IsHigherHighAndHigherLow(PERIOD_CURRENT, 1)) {
            stopLossPrice = lowestValue;
            direction = 1;
        } else if (positionInShortTerm == 1
            && cs.IsLongUpperWick(targetCandleIndex, wickFactor, minWickPips)
            && !cs.IsBullishCandle(1)
            && cs.IsLowerHighAndLowerLow(PERIOD_CURRENT, 1)) {
            stopLossPrice = highestValue;
            direction = 2;
        }

        if (ArraySize(boxPrices) >= 15) {
            // DrawBox(highestShortValue, lowestShortValue);
            ArrayFree(boxPrices);
        }

        return direction;
    }

    double GetStopLossPrice() {
        return stopLossPrice;
    }

private:
    void DrawBox(double &highestValue, double &lowestValue) {
        string boxName = "RangeBox_" + IntegerToString(boxCounter);

        // Draw a new rectangle for the detected range
        ObjectCreate(0, boxName, OBJ_RECTANGLE, 0, boxPrices[0].timestamp, highestValue, boxPrices[ArraySize(boxPrices) - 1].timestamp, lowestValue);
        ObjectSetInteger(0, boxName, OBJPROP_COLOR, clrBlue);
        ObjectSetInteger(0, boxName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, boxName, OBJPROP_SELECTED, 0);
        ObjectSetInteger(0, boxName, OBJPROP_SELECTABLE, 0);
        ObjectSetInteger(0, boxName, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, boxName, OBJPROP_RAY_RIGHT, true);
        ObjectSetInteger(0, boxName, OBJPROP_BACK, false);

        boxCounter++;
    }

    // 平均を計算
    double CalculateAverage() {
        double sum = 0.0;
        for (int i = 0; i < ArraySize(boxPrices); i++) {
            sum += boxPrices[i].close;
        }
        return sum / ArraySize(boxPrices);
    }

    // 標準偏差を計算
    double CalculateStandardDeviation(double average) {
        double variance = 0.0;
        for (int i = 0; i < ArraySize(boxPrices); i++) {
            variance += MathPow(boxPrices[i].close - average, 2);
        }
        return MathSqrt(variance / ArraySize(boxPrices));
    }

    // ボックス内での現在の位置を判定する
    int DeterminePositionWithinBox(double price, double highest, double lowest, double ratio) {
        // 安値圏と高値圏の境界を定義
        double range = highest - lowest;
        double highThreshold = highest - range * ratio; // 上位N%を高値圏と定義
        double lowThreshold = lowest + range * ratio; // 下位N%を安値圏と定義

        // 現在の終値がどの位置にあるか判断
        if (price <= lowThreshold) {
            return -1; // 安値圏
        } else if (price >= highThreshold) {
            return 1; // 高値圏
        } else {
            return 0; // 中間
        }
    }

    void CheckLongBar(int timeframe) {
        int latestBar = iBarShift(NULL, timeframe, 0); // 最新のバーのインデックスを取得

        // 最新のバーの開始時刻を取得
        datetime currentBarTime = iTime(NULL, timeframe, latestBar);

        // 以前のチェックから新しいバーが形成されたかを確認
        if (currentBarTime != lastLongCheckedTime) {
            // HighとLowを取得
            highestLongValue = iHigh(NULL, timeframe, latestBar);
            lowestLongValue = iLow(NULL, timeframe, latestBar);

            // 最後にチェックした時間を更新
            lastLongCheckedTime = currentBarTime;
        }
    }

    void CheckShortBar(int timeframe) {
        int latestBar = iBarShift(NULL, timeframe, 0); // 最新のバーのインデックスを取得

        // 最新のバーの開始時刻を取得
        datetime currentBarTime = iTime(NULL, timeframe, latestBar);

        // 以前のチェックから新しいバーが形成されたかを確認
        if (currentBarTime != lastShortCheckedTime) {
            // HighとLowを取得
            highestShortValue = iHigh(NULL, timeframe, latestBar);
            lowestShortValue = iLow(NULL, timeframe, latestBar);

            // 最後にチェックした時間を更新
            lastShortCheckedTime = currentBarTime;
        }
    }

};
