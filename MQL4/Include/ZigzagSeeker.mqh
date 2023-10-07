// ZigzagSeeker.mqh
struct Extremum {
    double value;       // 極値
    double prevValue;   // 一つ前の極値
    datetime timestamp; // タイムスタンプ
    bool isPeak;        // true の場合はピーク、false の場合は谷
};

// グローバル変数に定義：includeで他クラスからアクセス可能な状態
Extremum ExtremaArray[];

class ZigzagSeeker {
private:
    int depth, deviation, backstep;

public:
    void Initialize(int d=7, int dv=5, int bs=3) {
         depth = d;
         deviation = dv;
         backstep = bs;
    }

    void UpdateExtremaArray(int term, int limitLength) {
        ArrayResize(ExtremaArray, 0);

        int startBar = 0;
        int endBar = MathMin(Bars, term);
        double lastPeakValue = 0;
        double lastValleyValue = 0;

        for (int i = startBar; i < endBar; i++) {
            if (ArraySize(ExtremaArray) == limitLength) {
                break;
            }

            double zigzagValue = iCustom(NULL, 0, "ZigZag", depth, deviation, backstep, 0, i);
            if (zigzagValue == 0) {
                continue;
            }
            
            Extremum ex;
            ex.value = zigzagValue;
            ex.timestamp = iTime(NULL, 0, i);
            ex.isPeak = iHigh(NULL, 0, i) == zigzagValue;
            
            // 起点となった一つ前の極値をプロパティに保持
            if (ex.isPeak) {
                ex.prevValue = lastValleyValue;
                lastPeakValue = ex.value;
            } else {
                ex.prevValue = lastPeakValue;
                lastValleyValue = ex.value;
            }

            ArrayResize(ExtremaArray, ArraySize(ExtremaArray) + 1);
            ExtremaArray[ArraySize(ExtremaArray) - 1] = ex;
        }
    }
};
