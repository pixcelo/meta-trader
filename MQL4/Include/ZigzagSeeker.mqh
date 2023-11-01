// ZigzagSeeker.mqh
struct Extremum {
    double value;       // 極値
    double prevValue;   // 一つ前の極値
    datetime timestamp; // タイムスタンプ
    bool isPeak;        // true の場合はピーク、false の場合は谷
};

// グローバル変数に定義：includeで他クラスからアクセス可能な状態
Extremum ExtremaArray[];
Extremum ExShortArray[];

class ZigzagSeeker {
private:
    int depth, deviation, backstep, timeframe;

public:
    void Initialize(int d=12, int dv=5, int bs=3, int tf=0) {
         depth = d;
         deviation = dv;
         backstep = bs;
         timeframe = tf;
    }

    void UpdateExtremaArray(int term, int limitLength) {
        ArrayResize(ExtremaArray, 0);

        int startBar = 0;
        int endBar = MathMin(Bars, term);

        for (int i = startBar; i < endBar; i++) {
            if (ArraySize(ExtremaArray) == limitLength) {
                break;
            }

            double zigzagValue = iCustom(NULL, timeframe, "ZigZag", depth, deviation, backstep, 0, i);
            if (zigzagValue == 0) {
                continue;
            }
            
            Extremum ex;
            ex.value = zigzagValue;
            ex.timestamp = iTime(NULL, timeframe, i);
            ex.isPeak = iHigh(NULL, timeframe, i) == zigzagValue;

            ArrayResize(ExtremaArray, ArraySize(ExtremaArray) + 1);
            ExtremaArray[ArraySize(ExtremaArray) - 1] = ex;
        }

        // 起点となった時系列的に一つ前の極値をプロパティに保持
        double lastPeakValue = 0;
        double lastValleyValue = 0;
        for (int j = ArraySize(ExtremaArray) - 1; j >= 0; j--) {
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

    // 指定した時間足のトレンド転換ラインを取得
    double GetTrendReversalLine(int tf, int term, int direction) {
        Extremum tmpArray[];
        ArrayResize(tmpArray, 0);

        int startBar = 0;
        int endBar = MathMin(Bars, term);
        int i;

        for (i = startBar; i < endBar; i++) {
            double zigzagValue = iCustom(NULL, tf, "ZigZag", depth, deviation, backstep, 0, i);
            if (zigzagValue == 0) {
                continue;
            }
            
            Extremum ex;
            ex.value = zigzagValue;
            ex.timestamp = iTime(NULL, tf, i);
            ex.isPeak = iHigh(NULL, tf, i) == zigzagValue;

            ArrayResize(tmpArray, ArraySize(tmpArray) + 1);
            tmpArray[ArraySize(tmpArray) - 1] = ex;
        }

        // 起点となった時系列的に一つ前の極値をプロパティに保持
        double lastPeakValue = 0;
        double lastValleyValue = 0;
        for (int j = ArraySize(tmpArray) - 1; j >= 0; j--) {
            if (tmpArray[j].isPeak) {
                tmpArray[j].prevValue = lastValleyValue;
                lastPeakValue = tmpArray[j].value;
            } else {
                tmpArray[j].prevValue = lastPeakValue;
                lastValleyValue = tmpArray[j].value;
            }
        }


        double trendReversalLine = 0;

        if (direction == 1) {
            // 期間内で最安の極小値の起点となったピークをトレンド転換ラインとする
            double lowestValue = DBL_MAX;

            for (i = 0; i < ArraySize(tmpArray); i++) {
                Extremum ex = tmpArray[i];
                if (ex.isPeak) {
                    continue;
                }
                if (lowestValue >= ex.value) {
                    lowestValue = ex.value;
                    trendReversalLine = ex.prevValue;
                }
            }

            return trendReversalLine; // ここを超えたらロング
        }

        if (direction == 2) {
            // 期間内で最高の極大値の起点となった谷をトレンド転換ラインとする
            double highestValue = -DBL_MAX;

            for (i = 0; i < ArraySize(tmpArray); i++) {
                Extremum ex = tmpArray[i];
                if (!ex.isPeak) {
                    continue;
                }
                if (highestValue <= ex.value) {
                    highestValue = ex.value;
                    trendReversalLine = ex.prevValue;
                }
            }

            return trendReversalLine; // ここを抜けたらショート
        }

        return -1;
    }

    // ダウ理論に基づいたトレンド方向を取得
    int GetTrendDirection(Extremum &extremaArray[]) {
        datetime lastPeakTime = 0, secondLastPeakTime = 0;
        datetime lastValleyTime = 0, secondLastValleyTime = 0;
        double lastPeakValue = 0, secondLastPeakValue = 0;
        double lastValleyValue = 0, secondLastValleyValue = 0;

        // 最新と2番目のピークと谷を見つける
        for (int i = 0; i < ArraySize(extremaArray); i++) {
            if (extremaArray[i].isPeak) {
                if (lastPeakTime == 0) {
                    lastPeakTime = extremaArray[i].timestamp;
                    lastPeakValue = extremaArray[i].value;
                } else if (secondLastPeakTime == 0) {
                    secondLastPeakTime = extremaArray[i].timestamp;
                    secondLastPeakValue = extremaArray[i].value;
                }
            } else {
                if (lastValleyTime == 0) {
                    lastValleyTime = extremaArray[i].timestamp;
                    lastValleyValue = extremaArray[i].value;
                } else if (secondLastValleyTime == 0) {
                    secondLastValleyTime = extremaArray[i].timestamp;
                    secondLastValleyValue = extremaArray[i].value;
                }
            }

            if (secondLastPeakTime != 0 && secondLastValleyTime !=0) {
                break;
            }
        }

        // トレンド方向を判断
        if (secondLastPeakTime != 0 && lastPeakTime != 0 && secondLastValleyTime != 0 && lastValleyTime != 0) {
            if (secondLastPeakValue < lastPeakValue && secondLastValleyValue < lastValleyValue) {
                return 1; // 上昇トレンド
            } else if (secondLastPeakValue > lastPeakValue && secondLastValleyValue > lastValleyValue) {
                return 2; // 下降トレンド
            }
        }

        return 0;
    }

    void UpdateExShortArray(int term, int limitLength, int tf = PERIOD_M1) {
        ArrayResize(ExShortArray, 0);

        int startBar = 0;
        int endBar = MathMin(Bars, term);

        for (int i = startBar; i < endBar; i++) {
            if (ArraySize(ExShortArray) == limitLength) {
                break;
            }

            double zigzagValue = iCustom(NULL, tf, "ZigZag", 12, 5, 3, 0, i);
            if (zigzagValue == 0) {
                continue;
            }
            
            Extremum ex;
            ex.value = zigzagValue;
            ex.timestamp = iTime(NULL, tf, i);
            ex.isPeak = iHigh(NULL, tf, i) == zigzagValue;

            ArrayResize(ExShortArray, ArraySize(ExShortArray) + 1);
            ExShortArray[ArraySize(ExShortArray) - 1] = ex;
        }

        // 起点となった時系列的に一つ前の極値をプロパティに保持
        double lastPeakValue = 0;
        double lastValleyValue = 0;
        for (int j = ArraySize(ExShortArray) - 1; j >= 0; j--) {
            if (ExShortArray[j].isPeak) {
                ExShortArray[j].prevValue = lastValleyValue;
                lastPeakValue = ExShortArray[j].value;
            } else {
                ExShortArray[j].prevValue = lastPeakValue;
                lastValleyValue = ExShortArray[j].value;
            }
        }
    }

};