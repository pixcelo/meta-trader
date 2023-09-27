input double LargeCandleBodyPips = 5.0;        // 大陽線・大陰線のローソク足の実態のpips
input double RiskRewardRatio = 1.0;            // リスクリワード比
input int ZigzagDepth = 7;                     // ZigzagのDepth設定
input double lotSize = 0.01;
input double SpreadThreshold = 0.05;           // スプレッド閾値

// 必要な定数の定義
#define Green clrGreen
#define Red clrRed

// Utility.mqh の関数を使用する場合はここでインクルード
//#include "Utility.mqh"

void TradingStrategy() {
    double currentBid = MarketInfo(Symbol(), MODE_BID);
    double currentAsk = MarketInfo(Symbol(), MODE_ASK);
    double stopLoss, takeProfit;

    if (IsSpreadTooHigh(currentBid, currentAsk)) {
        return;
    }

    if (ShouldGoLong()) {
        stopLoss = GetLastZigzagLow();
        takeProfit = currentAsk + RiskRewardRatio * (currentAsk - stopLoss);
        PlaceBuyOrder(stopLoss);
    } else if (ShouldGoShort()) {
        stopLoss = GetLastZigzagHigh();
        takeProfit = currentBid - RiskRewardRatio * (stopLoss - currentBid);
        PlaceSellOrder(stopLoss);
    }
}



bool IsSpreadTooHigh(double bid, double ask) {
    return (ask - bid) > SpreadThreshold;
}

bool ShouldGoLong() {
    // ロングの条件をチェック
    if (Close[1] > iMA(NULL, 0, 100, 0, MODE_EMA, PRICE_CLOSE, 1) 
        && IsLargeBullishCandle(1)) {
        return true;
    }
    return false;
}

bool ShouldGoShort() {
    // ショートの条件をチェック
    if (Close[1] < iMA(NULL, 0, 100, 0, MODE_EMA, PRICE_CLOSE, 1) 
        && IsLargeBearishCandle(1)) {
        return true;
    }
    return false;
}

bool CheckBullishBreakout()
{
    int consecutiveLowerHighs = 0;
    for(int i=0; i<5; i++)
    {
        if(iCustom(Symbol(), PERIOD_M1, "ZigZag", ZigzagDepth, 1, i) > iCustom(Symbol(), PERIOD_M1, "ZigZag", ZigzagDepth, 1, i+1))
            consecutiveLowerHighs++;
        else
            break;
    }
    if(consecutiveLowerHighs == 5)
        return true;
    return false;
}

bool CheckBearishBreakout()
{
    int consecutiveHigherLows = 0;
    for(int i=0; i<5; i++)
    {
        if(iCustom(Symbol(), PERIOD_M1, "ZigZag", ZigzagDepth, 1, i) < iCustom(Symbol(), PERIOD_M1, "ZigZag", ZigzagDepth, 1, i+1))
            consecutiveHigherLows++;
        else
            break;
    }
    if(consecutiveHigherLows == 5)
        return true;
    return false;
}

double AverageBodyLength(int barsToConsider, int startShift)
{
    double totalBodyLength = 0;
    for(int i = 0; i < barsToConsider; i++)
    {
        double openPrice = iOpen(Symbol(), PERIOD_M1, i + startShift);
        double closePrice = iClose(Symbol(), PERIOD_M1, i + startShift);
        totalBodyLength += MathAbs(closePrice - openPrice);
    }
    return totalBodyLength / barsToConsider;
}

bool IsLargeBullishCandle(int shift)
{
    double openPrice = iOpen(Symbol(), PERIOD_M1, shift);
    double closePrice = iClose(Symbol(), PERIOD_M1, shift);
    double avgBody = AverageBodyLength(20, shift + 1);
    
    return (closePrice - openPrice) > avgBody && (closePrice - openPrice) >= LargeCandleBodyPips * Point;
}

bool IsLargeBearishCandle(int shift)
{
    double openPrice = iOpen(Symbol(), PERIOD_M1, shift);
    double closePrice = iClose(Symbol(), PERIOD_M1, shift);
    double avgBody = AverageBodyLength(20, shift + 1);

    return (openPrice - closePrice) > avgBody && (openPrice - closePrice) >= LargeCandleBodyPips * Point;
}


double GetLastZigzagHigh()
{
    int i = 1;
    while(i <= Bars)
    {
        double zzValue = iCustom(Symbol(), PERIOD_M1, "ZigZag", ZigzagDepth, 0, i);
        if(zzValue != 0 && zzValue > iOpen(Symbol(), PERIOD_M1, i))
            return zzValue;
        i++;
    }
    return 0; // Not found
}

double GetLastZigzagLow()
{
    int i = 1;
    while(i <= Bars)
    {
        double zzValue = iCustom(Symbol(), PERIOD_M1, "ZigZag", ZigzagDepth, 0, i);
        if(zzValue != 0 && zzValue < iOpen(Symbol(), PERIOD_M1, i))
            return zzValue;
        i++;
    }
    return 0; // Not found
}

void PlaceBuyOrderWithZigzagSL()
{
    double stopLossPrice = GetLastZigzagLow();
    if(stopLossPrice != 0)
    {
        PlaceBuyOrder(stopLossPrice);
    }
}

void PlaceSellOrderWithZigzagSL()
{
    double stopLossPrice = GetLastZigzagHigh();
    if(stopLossPrice != 0)
    {
        PlaceSellOrder(stopLossPrice);
    }
}


void PlaceBuyOrder(double stopLossPrice)
{
    double entryPrice = MarketInfo(Symbol(), MODE_ASK);
    double takeProfitPrice = entryPrice + (entryPrice - stopLossPrice) * RiskRewardRatio;

    int ticket = OrderSend(Symbol(), OP_BUY, lotSize, entryPrice, 2, stopLossPrice, takeProfitPrice, "Buy Order", 0, 0, Green);
}

void PlaceSellOrder(double stopLossPrice)
{
    double entryPrice = MarketInfo(Symbol(), MODE_BID);
    double takeProfitPrice = entryPrice - (stopLossPrice - entryPrice) * RiskRewardRatio;

    int ticket = OrderSend(Symbol(), OP_SELL, lotSize, entryPrice, 2, stopLossPrice, takeProfitPrice, "Sell Order", 0, 0, Red);
}

// 使用方法：
// ロング注文の場合
// double lastLow = GetLastLow(0, 5); // 直近5本の最低価格を取得
// PlaceBuyOrder(lastLow);

// ショート注文の場合
// double lastHigh = GetLastHigh(0, 5); // 直近5本の最高価格を取得
// PlaceSellOrder(lastHigh);
