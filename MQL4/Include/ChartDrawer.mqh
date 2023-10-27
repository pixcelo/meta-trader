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
            if (secondLastPeakValue < lastPeakValue && Low[0] > lastValleyValue) {
                trendLineColor = clrGreen;
            } else if (secondLastPeakValue > lastPeakValue && High[0] < lastPeakValue) {
                trendLineColor = clrRed;
            }
            DrawTrendLine("PeakTrendLine", secondLastPeakTime, secondLastPeakValue, lastPeakTime, lastPeakValue, trendLineColor);
        }

        if (secondLastValleyTime != 0 && lastValleyTime != 0) {
            if (secondLastValleyValue < lastValleyValue && Low[0] > lastValleyValue) {
                trendLineColor = clrGreen;
            } else if (secondLastValleyValue > lastValleyValue && High[0] < lastPeakValue) {
                trendLineColor = clrRed;
            }
            DrawTrendLine("ValleyTrendLine", secondLastValleyTime, secondLastValleyValue, lastValleyTime, lastValleyValue, trendLineColor);
        }
    }

    // トレンドラインを描画
    void DrawTrendLine(string name, datetime t1, double p1, datetime t2, double p2, color lineColor = Blue) {
        DeleteObjectByName(name);
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
            CreateHorizontalLine(lineNameForLong, trendReversalLineForLong, clrSpringGreen);
        }

        // trendReversalLineForShortが0より大きい場合、赤のラインを描画
        if (trendReversalLineForShort > 0) {
            CreateHorizontalLine(lineNameForShort, trendReversalLineForShort, clrOrchid);
        }
    }

    // 強度に基づいて水平線を描画
    void DrawHorizontalLineWithStrength(string lineName, double price, int strength) {
        color lineColor;
        int lineWidth;
        int lineStyle;
        
        // 強度に基づいてスタイルを設定
        // if (strength >= 5) {
        //     lineColor = clrRed;
        //     lineStyle = STYLE_SOLID;
        // } else if (strength >= 4) {
        //     lineColor = clrOrange;
        //     lineStyle = STYLE_SOLID;
        // } else if (strength >= 3) {
        //     lineColor = clrYellow;
        //     lineStyle = STYLE_SOLID;
        // } else if (strength >= 2) {
        //     lineColor = clrBlue;
        //     lineStyle = STYLE_DOT;
        // } else {
        //     lineColor = clrGreen;
        //     lineStyle = STYLE_DOT;
        // }

        lineColor = Teal;
        lineStyle = STYLE_DOT;
        
        DeleteObjectByName(lineName);
        CreateHorizontalLine(lineName, price, lineColor);
        ObjectSetInteger(0, lineName, OBJPROP_STYLE, lineStyle);
        ObjectSetInteger(0, lineName, OBJPROP_WIDTH, lineWidth);
    }

    // ピーク・谷から水平線を描画
    void DrawHorizontalLineWithPeakValley(string lineName, double price, bool isPeak) {
        color lineColor;
        int lineWidth;
        int lineStyle;
        
        if (isPeak) {
            lineColor = clrRed;
            lineStyle = STYLE_DOT;
        } else {
            lineColor = clrBlue;
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

    // トレンドラインの現在価格を取得
    double GetTrendLinePriceAtCurrentBar(string trendLineName) {
        double price1 = ObjectGetDouble(0, trendLineName, OBJPROP_PRICE1);
        double price2 = ObjectGetDouble(0, trendLineName, OBJPROP_PRICE2);
        datetime time1 = ObjectGetInteger(0, trendLineName, OBJPROP_TIME1);
        datetime time2 = ObjectGetInteger(0, trendLineName, OBJPROP_TIME2);
        
        double trendLinePrice = price1 + ((price2 - price1) / (time2 - time1)) * (Time[0] - time1);

        return NormalizeDouble(trendLinePrice, Digits());
    }

    // オブジェクトの色を取得
    color GetObjColor(string objName) {
        return ObjectGetInteger(0, objName, OBJPROP_COLOR);
    }

    // 指定した名前のオブジェクトを削除
    void DeleteObjectByName(string objName) {
        if(ObjectFind(0, objName) != -1) {
            ObjectDelete(0, objName);
        }
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
