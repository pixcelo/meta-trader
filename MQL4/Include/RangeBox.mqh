// RangeBox.mqh
#property strict

class RangeBox
{
private:
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

        double highestValue = -DBL_MAX;
        double lowestValue = DBL_MAX;

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
        double average = CalculateAverage();
        double deviation = CalculateStandardDeviation(average);
        
        // 外れ値を検出（平均からN倍の標準偏差以上離れた価格を外れ値とする）
        int outlierCoefficient = 3;
        if (currentBoxPrice.close > average + outlierCoefficient * deviation) {
            stopLossPrice = average;
            //stopLossPrice = lowestValue;
            //Print("lowestValue", lowestValue);
            isBreakOut = true;
            direction = 1;
        } else if (currentBoxPrice.close < average - outlierCoefficient * deviation) {
            stopLossPrice = average;
            stopLossPrice = highestValue;
            //Print("highestValue", highestValue);
            isBreakOut = true;
            direction = 2;
        }

        if (isBreakOut) {
            DrawBox(highestValue, lowestValue);
            ArrayFree(boxPrices);
        }

        if (ArraySize(boxPrices) >= 30) {
            Print("Reset box");
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

};
