#include "ZigzagSeeker.mqh"

class ChartDrawer {
private:
    color peakColor;
    color valleyColor;

public:
    ChartDrawer() {
        peakColor = Yellow;  // ピークの色
        valleyColor = Aqua;  // 谷の色
    }

    // 極大値と極小値を描画
    void DrawPeaksAndValleys(Extremum &extremaArray[], int numOfExtrema = 10) {
        // 既存のピークと谷のオブジェクトを削除
        for (int i = ObjectsTotal() - 1; i >= 0; i--) {
            string name = ObjectName(i);
            if (StringFind(name, "Peak_") != -1 || StringFind(name, "Valley_") != -1) {
                ObjectDelete(name);
            }
        }

        int count = 0;  // 描画された極値の数を追跡するカウンター

        // ピークと谷を描画
        for (int j = 0; j < ArraySize(extremaArray) && (count < numOfExtrema); j++) {
            string extremumName;
            int arrowCode;
            color arrowColor;
            if (extremaArray[j].isPeak) {
                extremumName = StringFormat("Peak_%d", j);
                arrowCode = 233;  // 上向き矢印
                arrowColor = peakColor;
            } else {
                extremumName = StringFormat("Valley_%d", j);
                arrowCode = 234;  // 下向き矢印
                arrowColor = valleyColor;
            }
            
            datetime extremumTime = extremaArray[j].timestamp;  // タイムスタンプを取得
            double extremumValue = extremaArray[j].value;
            ObjectCreate(0, extremumName, OBJ_ARROW, 0, extremumTime, extremumValue);
            ObjectSetInteger(0, extremumName, OBJPROP_ARROWCODE, arrowCode);
            ObjectSetInteger(0, extremumName, OBJPROP_COLOR, arrowColor);
            
            count++;  // 描画された極値の数をインクリメント
        }
    }

    // 極値からトレンドラインを描画
    void DrawTrendLineFromPeaksAndValleys(Extremum &extremaArray[]) {
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

        // トレンドラインを描画
        color trendLineColor;
        if (secondLastPeakTime != 0 && lastPeakTime != 0) {
            if (secondLastPeakValue < lastPeakValue && Close[0] > lastPeakValue) {
                trendLineColor = Green;
            } else if (secondLastPeakValue > lastPeakValue && Close[0] < lastPeakValue) {
                trendLineColor = Red;
            }
            DrawTrendLine("PeakTrendLine", secondLastPeakTime, secondLastPeakValue, lastPeakTime, lastPeakValue, trendLineColor);
        }

        if (secondLastValleyTime != 0 && lastValleyTime != 0) {
            if (secondLastValleyValue < lastValleyValue && Close[0] > lastValleyValue) {
                trendLineColor = Green;
            } else if (secondLastValleyValue > lastValleyValue && Close[0] < lastValleyValue) {
                trendLineColor = Red;
            }
            DrawTrendLine("ValleyTrendLine", secondLastValleyTime, secondLastValleyValue, lastValleyTime, lastValleyValue, trendLineColor);
        }
    }

    // フラクタルを検出し、トレンドラインを描画
    void DrawFractalTrendLines(int timeframe) {
        datetime lastUpFractalTime = 0, secondLastUpFractalTime = 0;
        datetime lastDownFractalTime = 0, secondLastDownFractalTime = 0;
        double lastUpFractalPrice = 0, secondLastUpFractalPrice = 0;
        double lastDownFractalPrice = 0, secondLastDownFractalPrice = 0;

        int rates_count = iBars(NULL, timeframe);

        for(int i = 2; i < rates_count; i++) {
            double currentHigh = iHigh(NULL, timeframe, i);
            double currentLow = iLow(NULL, timeframe, i);

            // UPフラクタルの検出
            if (currentHigh > iHigh(NULL, timeframe, i-1) && 
                currentHigh > iHigh(NULL, timeframe, i-2) && 
                currentHigh > iHigh(NULL, timeframe, i+1) && 
                currentHigh > iHigh(NULL, timeframe, i+2)) {

                if (lastUpFractalTime == 0) {
                    lastUpFractalTime = iTime(NULL, timeframe, i);
                    lastUpFractalPrice = currentHigh;
                } else if (secondLastUpFractalTime == 0) {
                    secondLastUpFractalTime = iTime(NULL, timeframe, i);
                    secondLastUpFractalPrice = currentHigh;
                }
            }

            // DOWNフラクタルの検出
            if (currentLow < iLow(NULL, timeframe, i-1) && 
                currentLow < iLow(NULL, timeframe, i-2) && 
                currentLow < iLow(NULL, timeframe, i+1) && 
                currentLow < iLow(NULL, timeframe, i+2)) {

                if (lastDownFractalTime == 0) {
                    lastDownFractalTime = iTime(NULL, timeframe, i);
                    lastDownFractalPrice = currentLow;
                } else if (secondLastDownFractalTime == 0) {
                    secondLastDownFractalTime = iTime(NULL, timeframe, i);
                    secondLastDownFractalPrice = currentLow;
                }
            }

            if (secondLastUpFractalTime != 0 && secondLastDownFractalTime != 0) {
                    break;
            }
        }

        // UPフラクタルのトレンドラインの検証と描画
        if (secondLastUpFractalPrice < lastUpFractalPrice && Close[0] > lastUpFractalPrice) {
            DrawTrendLine("UpFractalTrendLine", secondLastUpFractalTime, secondLastUpFractalPrice, lastUpFractalTime, lastUpFractalPrice, Green);
        } else if (secondLastUpFractalPrice > lastUpFractalPrice && Close[0] < lastUpFractalPrice) {
            DrawTrendLine("UpFractalTrendLine", secondLastUpFractalTime, secondLastUpFractalPrice, lastUpFractalTime, lastUpFractalPrice, Red);
        }

        // DOWNフラクタルのトレンドラインの検証と描画
        if (secondLastDownFractalPrice < lastDownFractalPrice && Close[0] > lastDownFractalPrice) {
            DrawTrendLine("DownFractalTrendLine", secondLastDownFractalTime, secondLastDownFractalPrice, lastDownFractalTime, lastDownFractalPrice, Green);
        } else if (secondLastDownFractalPrice > lastDownFractalPrice && Close[0] < lastDownFractalPrice) {
            DrawTrendLine("DownFractalTrendLine", secondLastDownFractalTime, secondLastDownFractalPrice, lastDownFractalTime, lastDownFractalPrice, Red);
        }
    }

    // トレンドラインを描画
    void DrawTrendLine(string name, datetime t1, double p1, datetime t2, double p2, color lineColor = Blue) {
        ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
        ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
    }

    // チャネルラインを描画
    void DrawChannelLines(string name1, string name2, datetime t1, double p1, datetime t2, double p2, double distance) {
        DrawTrendLine(name1, t1, p1, t2, p2, Red);
        ObjectCreate(0, name2, OBJ_TREND, 0, t1, p1 + distance, 0, t2, p2 + distance);
        ObjectSetInteger(0, name2, OBJPROP_COLOR, Blue);
    }

    // トレンド転換ラインを描画（2つの水平線）
    void DrawTrendReversalLines(double trendReversalLineForLong, double trendReversalLineForShort) {
        string lineNameForLong = "TrendReversalLineForLong";
        string lineNameForShort = "TrendReversalLineForShort";

        // 前回のトレンド転換ラインを削除
        if (ObjectFind(lineNameForLong) != -1) {
            ObjectDelete(lineNameForLong);
        }

        if (ObjectFind(lineNameForShort) != -1) {
            ObjectDelete(lineNameForShort);
        }

        // trendReversalLineForLongが0より大きい場合、緑のラインを描画
        if (trendReversalLineForLong > 0) {
            CreateHorizontalLine(lineNameForLong, trendReversalLineForLong, clrGreen);
        }

        // trendReversalLineForShortが0より大きい場合、赤のラインを描画
        if (trendReversalLineForShort > 0) {
            CreateHorizontalLine(lineNameForShort, trendReversalLineForShort, clrRed);
        }
    }

    // 強度に基づいて水平線を描画
    void DrawHorizontalLineWithStrength(string lineName, double price, int strength) {
        color lineColor;
        int lineWidth;
        int lineStyle;
        
        // 強度に基づいてスタイルを設定
        if (strength >= 5) {
            lineColor = clrRed;
            lineStyle = STYLE_SOLID;
        } else if (strength >= 4) {
            lineColor = clrOrange;
            lineStyle = STYLE_SOLID;
        } else if (strength >= 3) {
            lineColor = clrYellow;
            lineStyle = STYLE_SOLID;
        } else if (strength >= 2) {
            lineColor = clrBlue;
            lineStyle = STYLE_DOT;
        } else {
            lineColor = clrGreen;
            lineStyle = STYLE_DOT;
        }
        
        CreateHorizontalLine(lineName, price, lineColor);
        ObjectSetInteger(0, lineName, OBJPROP_STYLE, lineStyle);
        ObjectSetInteger(0, lineName, OBJPROP_WIDTH, lineWidth);
    }

    // 水平ラインを作成するヘルパー関数
    void CreateHorizontalLine(string lineName, double price, color lineColor) {
        ObjectCreate(lineName, OBJ_HLINE, 0, TimeCurrent(), price);
        ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);
        ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, true); // 右に伸びるように設定
        ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID); // 実線に設定
        ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1); // 線の太さを設定
        ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, 0); // 選択不可に設定
        ObjectSetInteger(0, lineName, OBJPROP_SELECTED, 0); // 選択状態を解除
    }

    // 名前から強度を取得
    int GetStrengthOfLine(string lineName) {
        int lastUnderscorePos = StringFind(lineName, "_", 0);
        string strengthStr = StringSubstr(lineName, lastUnderscorePos + 1); 
        return StringToInteger(strengthStr);
    }

    // すべてのオブジェクトを削除
    void DeleteAllObjects() {
        int total = ObjectsTotal();
        for (int i = total - 1; i >= 0; i--) {
            string name = ObjectName(i);
            ObjectDelete(name);
        }
    }
};
