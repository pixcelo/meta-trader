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
    ZigzagSeeker() {
        Initialize();
    }

    void Initialize(int d=12, int dv=5, int bs=3) {
         depth = d;
         deviation = dv;
         backstep = bs;
    }

    // Note: バックテスト速度が落ちる（必要最低限のデータを取得ver）
    void GetZigzagData(double &peaks[], double &valleys[], int timeframe = PERIOD_CURRENT, int term = 1440, int limit = 10) {
        int peaksIndex = 0;
        int valleysIndex = 0;
        ArrayResize(peaks, limit);
        ArrayResize(valleys, limit);
        
        for (int i = 0; i < term; i++) {
            double zigzagValue = iCustom(NULL, timeframe, "ZigZag", depth, deviation, backstep, 0, i);
            if (zigzagValue == 0) continue;

            if (zigzagValue == iHigh(NULL, timeframe, i) && peaksIndex < limit - 1) {
                peaks[peaksIndex] = zigzagValue;
                peaksIndex++;
            } else if (zigzagValue == iLow(NULL, timeframe, i) && valleysIndex < limit - 1) {
                valleys[valleysIndex] = zigzagValue;
                valleysIndex++;
            }

            if (peaksIndex == limit - 1 && valleysIndex == limit - 1) {
                break;
            }
        }

        ArrayResize(peaks, peaksIndex);
        ArrayResize(valleys, valleysIndex);
    }

    // Note: バックテスト速度が落ちる
    void UpdateExtremaArray(int timeframe = PERIOD_CURRENT, int limitLength = 10) {
        // 必要なデータをあらかじめ取得
        datetime times[];
        double highs[];
        ArraySetAsSeries(times, true);
        ArraySetAsSeries(highs, true);
        CopyTime(NULL, timeframe, 0, Bars, times);
        CopyHigh(NULL, timeframe, 0, Bars, highs);
        
        // ExtremaArrayを最初に限界サイズでリサイズ
        ArrayResize(ExtremaArray, limitLength);
        int extremaCount = 0; // 実際に見つかった極値の数

        for (int i = 0; i < Bars && extremaCount < limitLength; i++) {
            double zigzagValue = iCustom(NULL, timeframe, "ZigZag", depth, deviation, backstep, 0, i);
            if (zigzagValue == 0) continue;
            
            Extremum ex;
            ex.value = zigzagValue;
            ex.timestamp = times[i];
            ex.isPeak = highs[i] == zigzagValue;
    
            ExtremaArray[extremaCount] = ex;
            extremaCount++;
        }

        // 使用されていない部分を切り捨てる
        ArrayResize(ExtremaArray, extremaCount);

        // 起点となった時系列的に一つ前の極値をプロパティに保持
        double lastPeakValue = 0;
        double lastValleyValue = 0;
        for (int j = extremaCount - 1; j >= 0; j--) {
            if (ExtremaArray[j].isPeak) {
                ExtremaArray[j].prevValue = lastValleyValue;
                lastPeakValue = ExtremaArray[j].value;
            } else {
                ExtremaArray[j].prevValue = lastPeakValue;
                lastValleyValue = ExtremaArray[j].value;
            }
        }
    }

    // 最新の極値を取得する
    double GetLatestValue(bool isPeak) {
        int len = ArraySize(ExtremaArray);

        for (int i = 0; i < len; i++) {
            Extremum ex = ExtremaArray[i];
            if (isPeak && ex.isPeak) {
                return ex.value;
            }
            
            if (!isPeak && !ex.isPeak) {
                return ex.value;
            }
        }

        return 0;
    }

    // 戻り高値（最安値の起点となった高値）を取得
    double GetPrevPeakValue() {
        int len = ArraySize(ExtremaArray);

        for (int i = 0; i < len; i++) {
            Extremum ex = ExtremaArray[i];
            if (!ex.isPeak) {
                return ex.prevValue;
            }
        }

        return 0;
    }

    // 押し安値（最高値の起点となった安値）を取得
    double GetPrevValleyValue() {
        int len = ArraySize(ExtremaArray);

        for (int i = 0; i < len; i++) {
            Extremum ex = ExtremaArray[i];
            if (ex.isPeak) {
                return ex.prevValue;
            }
        }

        return 0;
    }

    // 極大値と極小値を描画
    void DrawPeaksAndValleys(Extremum &extremaArray[], int limit = 10) {
        // 既存のピークと谷のオブジェクトを削除
        for (int i = ObjectsTotal() - 1; i >= 0; i--) {
            string name = ObjectName(i);
            if (StringFind(name, "Peak_") != -1 || StringFind(name, "Valley_") != -1) {
                ObjectDelete(name);
            }
        }

        int count = 0;

        // ピークと谷を描画
        for (int j = 0; j < ArraySize(extremaArray) && (count < limit); j++) {
            string extremumName;
            int arrowCode;
            color arrowColor;
            if (extremaArray[j].isPeak) {
                extremumName = StringFormat("Peak_%d", j);
                arrowCode = 233;  // 上向き矢印
                arrowColor = Yellow;
            } else {
                extremumName = StringFormat("Valley_%d", j);
                arrowCode = 234;  // 下向き矢印
                arrowColor = Aqua;
            }
            
            datetime extremumTime = extremaArray[j].timestamp;
            double extremumValue = extremaArray[j].value;
            ObjectCreate(0, extremumName, OBJ_ARROW, 0, extremumTime, extremumValue);
            ObjectSetInteger(0, extremumName, OBJPROP_ARROWCODE, arrowCode);
            ObjectSetInteger(0, extremumName, OBJPROP_COLOR, arrowColor);
            
            count++;
        }
    }

};