// ZigzagSeeker.mqh
struct Extremum {
    double value;       // 極値
    double prevValue;   // 一つ前の極値
    datetime timestamp; // タイムスタンプ
    bool isPeak;        // true の場合はピーク、false の場合は谷
};

// グローバル変数に定義：includeで他クラスからアクセス可能な状態
Extremum ExtremaArray[];
Extremum ExSecondArray[];

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

    void UpdateExtremaArray(int limitLength) {
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

    // 価格が最新と一つ前のピークよりも高いかを判定
    bool IsPriceHigherThanRecentPeaks(double price) {
        int len = ArraySize(ExtremaArray);
        double lastPeakValue = 0;
        bool foundFirstPeak = false;

        for (int i = 0; i < len; i++) {
            Extremum ex = ExtremaArray[i];
            if (ex.isPeak) {
                if (!foundFirstPeak) {
                    foundFirstPeak = true;
                    lastPeakValue = ex.value;
                } else {
                    return price >= lastPeakValue && price > ex.value;
                }
            }
        }

        // ループ後、最新のピークしか見つからなかった場合は、そのピークのみを比較
        if (foundFirstPeak) {
            return price >= lastPeakValue;
        }

        return false;
    }

    // 価格がダウ理論の上昇トレンドを形成しかかっているかを判定
    bool IsPriceFormingUpTrend() {
        int len = ArraySize(ExtremaArray);
        double latestValley = 0;
        double secondLatestValley = 0;
        bool foundFirstValley = false;

        for (int i = 0; i < len; i++) {
            Extremum ex = ExtremaArray[i];
            if (!ex.isPeak) {
                if (!foundFirstValley) {
                    foundFirstValley = true;
                    latestValley = ex.value;
                } else if (secondLatestValley == 0) {
                    secondLatestValley = ex.value;
                }
            }

            if (latestValley > 0 && secondLatestValley > 0) {
                break;
            }
        }

        // 最新の谷が一つ前の谷より高い場合に true を返す
        return foundFirstValley && secondLatestValley != 0 && latestValley > secondLatestValley;
    }

    // 価格がダウ理論の下降トレンドの形成を行っているかを判定
    bool IsPriceFormingDownTrend() {
        int len = ArraySize(ExtremaArray);
        double latestPeak = 0;
        double secondLatestPeak = 0;
        bool foundFirstPeak = false;

        for (int i = 0; i < len; i++) {
            Extremum ex = ExtremaArray[i];
            if (ex.isPeak) {
                if (!foundFirstPeak) {
                    foundFirstPeak = true;
                    latestPeak = ex.value;
                } else if (secondLatestPeak == 0) {
                    secondLatestPeak = ex.value;
                }
            }

            if (latestPeak > 0 && secondLatestPeak > 0) {
                break;
            }
        }

        // 最新のピークが一つ前のピークより低い場合に true を返す
        return foundFirstPeak && secondLatestPeak != 0 && latestPeak < secondLatestPeak;
    }

    // 指定した時間足のトレンド転換ラインを取得
    double GetTrendReversalLine(int tf, int direction) {
        Extremum tmpArray[];
        ArrayResize(tmpArray, 0);
        int startBar = 0;
        int i;

        for (i = startBar; i < Bars; i++) {
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

    void UpdateExSecondArray(int limitLength, int tf = PERIOD_M1) {
        ArrayResize(ExSecondArray, 0);

        for (int i = 0; i < Bars; i++) {
            if (ArraySize(ExSecondArray) == limitLength) {
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

            ArrayResize(ExSecondArray, ArraySize(ExSecondArray) + 1);
            ExSecondArray[ArraySize(ExSecondArray) - 1] = ex;
        }

        // 起点となった時系列的に一つ前の極値をプロパティに保持
        double lastPeakValue = 0;
        double lastValleyValue = 0;
        for (int j = ArraySize(ExSecondArray) - 1; j >= 0; j--) {
            if (ExSecondArray[j].isPeak) {
                ExSecondArray[j].prevValue = lastValleyValue;
                lastPeakValue = ExSecondArray[j].value;
            } else {
                ExSecondArray[j].prevValue = lastPeakValue;
                lastValleyValue = ExSecondArray[j].value;
            }
        }
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