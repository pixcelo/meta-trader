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

    // トレンド転換ラインを描画
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

    void DrawHorizontalLineWithStrength(string lineName, double price, int strength) {
        color lineColor;
        int lineWidth;
        int lineStyle;
        
        // 強度に基づいてスタイルを設定
        if (strength >= 30) {
            lineColor = clrRed;
            lineStyle = STYLE_SOLID;
        } else if (strength >= 25) {
            lineColor = clrOrange;
            lineStyle = STYLE_SOLID;
        } else if (strength >= 20) {
            lineColor = clrYellow;
            lineStyle = STYLE_SOLID;
        } else if (strength >= 10) {
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
