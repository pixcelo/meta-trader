// RangeBox.mqh
#property strict

#include "Utility.mqh"

class RangeBox
{
private:
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
    double highestValue;
    double lowestValue;

public:
    void Init(int minBoxRangeInput, double minBoxPipsInput, double maxBoxPipsInput) {
        minBoxRange = minBoxRangeInput;
        minBoxPips = minBoxPipsInput * Point;
        maxBoxPips = maxBoxPipsInput * Point;
        boxCounter = 0;
        lastTimestamp = 0;
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

        highestValue = -DBL_MAX;
        lowestValue = DBL_MAX;

        for (int i = 0; i < ArraySize(boxPrices); i++) {
            if (boxPrices[i].high > highestValue) highestValue = boxPrices[i].high;
            if (boxPrices[i].low < lowestValue) lowestValue = boxPrices[i].low;
        }

        int direction = 0;

        if (ArraySize(boxPrices) <= minBoxRange) {
            return direction;
        }
        
        bool isBreakOut = false;

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

        int targetCandleIndex = 2;
        double wickFactor = 3.0; 
        int minWickPips = 5;

        // ボックスの中で高値圏での上ヒゲ・安値圏での下ヒゲのローソク足の出現を検知する
        int position = DeterminePositionWithinBox(Close[targetCandleIndex]);
         
        if (position == -1 && IsLongLowerWick(targetCandleIndex, wickFactor, minWickPips) && IsBullishCandle(1)) {
            stopLossPrice = lowestValue;
            isBreakOut = true;
            direction = 1;
        } else if (position == 1 && IsLongUpperWick(targetCandleIndex, wickFactor, minWickPips) && IsBearishCandle(1)) {
            stopLossPrice = highestValue;
            isBreakOut = true;
            direction = 2;
        }

        if (isBreakOut) {
            DrawBox(highestValue, lowestValue);
            ArrayFree(boxPrices);
        }

        if (ArraySize(boxPrices) >= 30) {
            DrawBox(highestValue, lowestValue);
            ArrayFree(boxPrices);
        }

        return direction;
    }

    double GetStopLossPrice() {
        return stopLossPrice;
    }

private:
    void DrawBox(double highestValue, double lowestValue) {
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

    double CalculateAverage() {
        double sum = 0.0;
        for (int i = 0; i < ArraySize(boxPrices); i++) {
            sum += boxPrices[i].close;
        }
        return sum / ArraySize(boxPrices);
    }

    double CalculateStandardDeviation(double average) {
        double variance = 0.0;
        for (int i = 0; i < ArraySize(boxPrices); i++) {
            variance += MathPow(boxPrices[i].close - average, 2);
        }
        return MathSqrt(variance / ArraySize(boxPrices));
    }

    // ローソク足が陽線なら True
    bool IsBullishCandle(int candleIndex) {
        return Close[candleIndex] > Open[candleIndex];
    }

    // ローソク足が陰線なら True
    bool IsBearishCandle(int candleIndex) {
        return Close[candleIndex] < Open[candleIndex];
    }

    // 関数は、小さな実体と長い下ヒゲを持つローソク足を検出 IsLongLowerWick(0, 0.2, 3)
    bool IsLongLowerWick(int candleIndex, double wickFactor, int minWickPips) {
        // 実体のサイズを取得
        double openPrice = Open[candleIndex];
        double closePrice = Close[candleIndex];
        double highPrice = High[candleIndex];
        double lowPrice = Low[candleIndex];
        double bodySize = MathAbs(openPrice - closePrice);
        
        // 下ヒゲのサイズを取得
        double lowerWickSize = (openPrice > closePrice) ? (closePrice - lowPrice) : (openPrice - lowPrice);
        bool isWickLongEnough = lowerWickSize >= ut.PipsToPrice(minWickPips);
        // Print("lowerWickSize ", lowerWickSize, " >= ", ut.PipsToPrice(minWickPips));

        // 実体が小さく、下ヒゲが実体の指定された倍以上であるか確認
        return lowerWickSize >= bodySize * wickFactor && isWickLongEnough;
    }

    // 関数は、小さな実体と長い上ヒゲを持つローソク足を検出 IsLongUpperWick(0, 0.2, 3)
    bool IsLongUpperWick(int candleIndex, double wickFactor, int minWickPips) {
        // 実体のサイズを取得
        double openPrice = Open[candleIndex];
        double closePrice = Close[candleIndex];
        double highPrice = High[candleIndex];
        double lowPrice = Low[candleIndex];
        double bodySize = MathAbs(openPrice - closePrice);
        
        // 上ヒゲのサイズを取得
        double upperWickSize = (openPrice > closePrice) ? (highPrice - openPrice) : (highPrice - closePrice);
        bool isWickLongEnough = upperWickSize >= ut.PipsToPrice(minWickPips);
        // Print("lowerWickSize ", upperWickSize, " >= ", ut.PipsToPrice(minWickPips));

        // 実体が小さく、上ヒゲが実体の指定された倍以上であるか確認
        return upperWickSize >= bodySize * wickFactor && isWickLongEnough;
    }

    // ボックス内での現在の位置を判定する
    int DeterminePositionWithinBox(double price) {
        // 最高値と最低値を検出
        double highest = highestValue;
        double lowest = lowestValue;

        // 安値圏と高値圏の境界を定義
        double range = highest - lowest;
        double highThreshold = highest - range * 0.20; // 上位20%を高値圏と定義
        double lowThreshold = lowest + range * 0.20; // 下位20%を安値圏と定義

        // 現在の終値がどの位置にあるか判断
        if (price <= lowThreshold) {
            return -1; // 安値圏
        } else if (price >= highThreshold) {
            return 1; // 高値圏
        } else {
            return 0; // 中間
        }
    }

};
