// エントリータイプの列挙型
enum EntryType {
    LONG_ENTRY,
    SHORT_ENTRY
};

// エグジットタイプの列挙型
enum ExitType {
    LONG_EXIT,
    SHORT_EXIT
};

class ChartDrawer {
private:
    color entryColor;
    color exitColor;
    color trendReversalLineColor;
    color peakColor;
    color valleyColor;

public:
    ChartDrawer() {
        entryColor = clrGreen; // エントリーの色
        exitColor = clrRed;    // エグジットの色
        trendReversalLineColor = clrBlue; // トレンド転換ラインの色
        peakColor = Yellow;  // ピークの色
        valleyColor = Aqua;  // 谷の色
    }

    // エントリー位置を描画
    void DrawEntry(double price, datetime time, EntryType entryType) {
        ObjectCreate("EntryArrow_" + time, OBJ_ARROW, 0, time, price);
        ObjectSetInteger(0, "EntryArrow_" + time, OBJPROP_COLOR, entryColor);
        
        // エントリータイプに応じて矢印の方向を設定
        if (entryType == LONG_ENTRY) {
            ObjectSetInteger(0, "EntryArrow_" + time, OBJPROP_ARROWCODE, SYMBOL_ARROWUP);
        } else if (entryType == SHORT_ENTRY) {
            ObjectSetInteger(0, "EntryArrow_" + time, OBJPROP_ARROWCODE, SYMBOL_ARROWDOWN);
        }
    }

    // エグジット位置を描画
    void DrawExit(double price, datetime time, ExitType exitType) {
        ObjectCreate("ExitArrow_" + time, OBJ_ARROW, 0, time, price);
        ObjectSetInteger(0, "ExitArrow_" + time, OBJPROP_COLOR, exitColor);
        
        // エグジットタイプに応じて矢印の方向を設定
        if (exitType == LONG_EXIT) {
            ObjectSetInteger(0, "ExitArrow_" + time, OBJPROP_ARROWCODE, SYMBOL_ARROWDOWN);
        } else if (exitType == SHORT_EXIT) {
            ObjectSetInteger(0, "ExitArrow_" + time, OBJPROP_ARROWCODE, SYMBOL_ARROWUP);
        }
    }

    // 極大値と極小値を描画
    void DrawPeaksAndValleys(double &peakValues[], double &valleyValues[], int numOfExtrema = 10) {
        // 既存のピークと谷のオブジェクトを削除
        for (int i = ObjectsTotal() - 1; i >= 0; i--) {
            string name = ObjectName(i);
            if (StringFind(name, "Peak_") != -1 || StringFind(name, "Valley_") != -1) {
                ObjectDelete(name);
            }
        }

        int peakCount = 0;  // 描画されたピークの数を追跡するカウンター
        int valleyCount = 0;  // 描画された谷の数を追跡するカウンター

        // ピークを描画
        for (int j = 0; j < ArraySize(peakValues) && (peakCount < numOfExtrema); j++) {
            if (peakValues[j] != 0) {  // 値が0でないことを確認
                string peakName = StringFormat("Peak_%d", j);
                datetime peakTime = iTime(_Symbol, _Period, j);  // バーのインデックスからタイムスタンプを取得
                double peakValue = peakValues[j];
                ObjectCreate(0, peakName, OBJ_ARROW, 0, peakTime, peakValue);
                ObjectSetInteger(0, peakName, OBJPROP_ARROWCODE, 233);  // 上向き矢印
                ObjectSetInteger(0, peakName, OBJPROP_COLOR, peakColor);
                peakCount++;  // 描画されたピークの数をインクリメント
            }
        }

        // 谷を描画
        for (int k = 0; k < ArraySize(valleyValues) && (valleyCount < numOfExtrema); k++) {
            if (valleyValues[k] != 0) {  // 値が0でないことを確認
                string valleyName = StringFormat("Valley_%d", k);
                datetime valleyTime = iTime(_Symbol, _Period, k);  // バーのインデックスからタイムスタンプを取得
                double ValleyValue = valleyValues[k];
                ObjectCreate(0, valleyName, OBJ_ARROW, 0, valleyTime, ValleyValue);
                ObjectSetInteger(0, valleyName, OBJPROP_ARROWCODE, 234);  // 下向き矢印
                ObjectSetInteger(0, valleyName, OBJPROP_COLOR, valleyColor);
                valleyCount++;  // 描画された谷の数をインクリメント
            }
        }
    }

    void DrawFromHistory()
    {
        int totalOrders = OrdersHistoryTotal(); // Order Historyの総数を取得

        for (int i = 0; i < totalOrders; i++)
        {
            if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
            {
                if (OrderSymbol() == Symbol() && (OrderType() == OP_BUY || OrderType() == OP_SELL))
                {
                    // エントリーポイントを描画
                    datetime entryTime = OrderOpenTime();
                    double entryPrice = OrderOpenPrice();
                    EntryType entryType;
                    if (OrderType() == OP_BUY) {
                        entryType = LONG_ENTRY;
                    } else {
                        entryType = SHORT_ENTRY;
                    }
                    DrawEntry(entryPrice, entryTime, entryType);

                    if (OrderClosePrice() == OrderTakeProfit() || OrderClosePrice() == OrderStopLoss())
                    {
                        // エグジットポイントを描画
                        datetime exitTime = OrderCloseTime();
                        double exitPrice = OrderClosePrice();
                        ExitType exitType;
                        if (OrderType() == OP_BUY) {
                            exitType = LONG_EXIT;
                        } else {
                            exitType = SHORT_EXIT;
                        }
                        DrawExit(exitPrice, exitTime, exitType);
                    }
                }
            }
        }
    }

    // トレンド転換ラインを描画
    void DrawTrendReversalLine(double trendReversalLineForLong, double trendReversalLineForShort) {
        string lineNameForLong = "TrendReversalLineForLong";
        string lineNameForShort = "TrendReversalLineForShort";

        // 前回のトレンド転換ラインを削除
        if(ObjectFind(lineNameForLong) != -1) {
            ObjectDelete(lineNameForLong);
        }

        if(ObjectFind(lineNameForShort) != -1) {
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

    // すべてのオブジェクトを削除
    void DeleteAllObjects() {
        int total = ObjectsTotal();
        for (int i = total - 1; i >= 0; i--) {
            string name = ObjectName(i);
            ObjectDelete(name);
        }
    }
};
