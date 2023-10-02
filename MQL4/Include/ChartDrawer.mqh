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

public:
    ChartDrawer() {
        entryColor = clrGreen; // エントリーの色
        exitColor = clrRed;    // エグジットの色
        trendReversalLineColor = clrBlue; // トレンド転換ラインの色
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
