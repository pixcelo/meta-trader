// LocalExtremaSeeker.mqh
class LocalExtremaSeeker
{
public:
    double peakValues[];         // ピークの価値を保存する配列
    datetime peakTimestamps[];   // ピークのタイムスタンプを保存する配列
    double valleyValues[];       // 谷の価値を保存する配列
    datetime valleyTimestamps[]; // 谷のタイムスタンプを保存する配列

private:
    int depth;         // 新しい高値または安値を描画するために必要な最小のバー数を指定
    int backstep;      // 2つの連続する頂点の間の最小のバー数

public:
    void Initialize(int d=7, int bs=3) {
         depth = d;
         backstep = bs;
    }

    void resetArrays() {
        ArrayResize(peakValues, 0);
        ArrayResize(peakTimestamps, 0);
        ArrayResize(valleyValues, 0);
        ArrayResize(valleyTimestamps, 0);
    }

    // Peakを見つける
    void FindPeaks(double &prices[], datetime &times[]) {
        int lastPeakIndex = -backstep;

        for (int i = depth; i < ArraySize(prices) - depth; i++) {
            bool isPeak = true;
            for (int j = 1; j <= depth; j++) {
                if (prices[i] <= prices[i-j] || prices[i] <= prices[i+j]) {
                    isPeak = false;
                    break;
                }
            }

            bool isFarEnoughFromLastPeak = (i - lastPeakIndex) >= backstep;

            if (isPeak && isFarEnoughFromLastPeak) {
                ArrayResize(peakValues, ArraySize(peakValues) + 1);
                ArrayResize(peakTimestamps, ArraySize(peakTimestamps) + 1);

                peakValues[ArraySize(peakValues) - 1] = prices[i];
                peakTimestamps[ArraySize(peakTimestamps) - 1] = times[i];

                lastPeakIndex = i;
            }
        }
    }

    // Valleyを見つける
    void FindValleys(double &prices[], datetime &times[]) {
        int lastValleyIndex = -backstep;

        for (int i = depth; i < ArraySize(prices) - depth; i++) {
            bool isValley = true;
            for (int j = 1; j <= depth; j++) {
                if (prices[i] >= prices[i-j] || prices[i] >= prices[i+j]) {
                    isValley = false;
                    break;
                }
            }

            bool isFarEnoughFromLastValley = (i - lastValleyIndex) >= backstep;

            if (isValley && isFarEnoughFromLastValley) {
                ArrayResize(valleyValues, ArraySize(valleyValues) + 1);
                ArrayResize(valleyTimestamps, ArraySize(valleyTimestamps) + 1);

                valleyValues[ArraySize(valleyValues) - 1] = prices[i];
                valleyTimestamps[ArraySize(valleyTimestamps) - 1] = times[i];

                lastValleyIndex = i;
            }
        }
    }

    // ピークと谷を更新
    void UpdatePeaksAndValleys(int barTerm=960) {
        double highPrices[];
        double lowPrices[];
        datetime timeStamps[];

        ArraySetAsSeries(highPrices, true);
        ArraySetAsSeries(lowPrices, true);
        ArraySetAsSeries(timeStamps, true);

        ArrayResize(highPrices, barTerm);
        ArrayResize(lowPrices, barTerm);
        ArrayResize(timeStamps, barTerm);

        for (int shift = 0; shift < barTerm; shift++) {
            highPrices[shift] = iHigh(Symbol(), Period(), shift);
            lowPrices[shift] = iLow(Symbol(), Period(), shift);
            timeStamps[shift] = iTime(Symbol(), Period(), shift);
        }
        
        resetArrays();
        FindPeaks(highPrices, timeStamps);
        FindValleys(lowPrices, timeStamps);
    }

    // Debug
    void printValuesAndIndices() {
        Print("Peaks:");
        Print("ArraySize ", ArraySize(peakValues));
        for (int i = 0; i < ArraySize(peakValues); i++) {
            Print("Peaks Value: ", peakValues[i], ", Timestamp: ", peakTimestamps[i]);
        }

        Print("Valleys:");
        Print("ArraySize ", ArraySize(valleyValues));
        for (int j = 0; j < ArraySize(valleyValues); j++) {
            Print("Valleys Value: ", valleyValues[j], ", Timestamp: ", valleyTimestamps[j]);
        }
    }
};
