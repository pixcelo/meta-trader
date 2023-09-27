input double LargeCandleBodyPips = 5.0;        // 大陽線・大陰線のローソク足の実態のpips
input double RiskRewardRatio = 1.0;            // リスクリワード比
input int ZigzagDepth = 7;                     // ZigzagのDepth設定
input int ZigzagDeviation = 5;                 // ZigzagのDeviation設定
input int ZigzagBackstep = 3;                  // ZigzagのBackstep設定
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
         Print("Spread too high");
         return;
    }

    if (ShouldGoLong()) {
    /*
        Print("Should go long condition met");
        stopLoss = GetLastZigzagLow();
        if(stopLoss == 0) {
            Print("Zigzag low not found");
            return;
        }
        takeProfit = currentAsk + RiskRewardRatio * (currentAsk - stopLoss);
        PlaceBuyOrder(stopLoss);
        */
        PlaceBuyOrderWithZigzagSL();
    } else if (ShouldGoShort()) {
    /*
        Print("Should go short condition met");
        stopLoss = GetLastZigzagHigh();
        if(stopLoss == 0) {
            Print("Zigzag high not found");
            return;
        }
        takeProfit = currentBid - RiskRewardRatio * (stopLoss - currentBid);
        PlaceSellOrder(stopLoss);
        */
        PlaceSellOrderWithZigzagSL();
    } else {
        Print("No entry conditions met");
    }
}

// スプレッド拡大への対応
bool IsSpreadTooHigh(double bid, double ask) {
    return (ask - bid) > SpreadThreshold;
}

bool ShouldGoLong() {
    // ロングの条件をチェック
    if (Close[1] > iMA(NULL, 0, 100, 0, MODE_EMA, PRICE_CLOSE, 1) 
        && IsExceptionallyLargeCandle(1)) {
        Print("Long condition: Close above EMA and Large bullish candle");
        return true;
    }
    return false;
}

bool ShouldGoShort() {
    // ショートの条件をチェック
    if (Close[1] < iMA(NULL, 0, 100, 0, MODE_EMA, PRICE_CLOSE, 1) 
        && IsExceptionallyLargeCandle(1)) {
        Print("Short condition: Close below EMA and Large bearish candle");
        return true;
    }
    return false;
}

bool CheckBullishBreakout()
{
    int consecutiveLowerHighs = 0;
    for(int i=0; i<5; i++)
    {
        if(iCustom(Symbol(), PERIOD_M1, "ZigZag", ZigzagDepth, ZigzagDeviation, ZigzagBackstep, 1, i) > 
           iCustom(Symbol(), PERIOD_M1, "ZigZag", ZigzagDepth, ZigzagDeviation, ZigzagBackstep, 1, i+1))
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
        if(iCustom(Symbol(), PERIOD_M1, "ZigZag", ZigzagDepth, ZigzagDeviation, ZigzagBackstep, 1, i) < 
           iCustom(Symbol(), PERIOD_M1, "ZigZag", ZigzagDepth, ZigzagDeviation, ZigzagBackstep, 1, i+1))
            consecutiveHigherLows++;
        else
            break;
    }
    if(consecutiveHigherLows == 5)
        return true;
    return false;
}

// ローソク足の大きさを確認（直近20本で一番大きく、ヒゲが実態の3割未満）
bool IsExceptionallyLargeCandle(int shift)
{
    double openPrice = iOpen(Symbol(), PERIOD_M1, shift);
    double closePrice = iClose(Symbol(), PERIOD_M1, shift);
    double highPrice = iHigh(Symbol(), PERIOD_M1, shift);
    double lowPrice = iLow(Symbol(), PERIOD_M1, shift);

    double bodyLength = MathAbs(closePrice - openPrice); // 実体の絶対値を取得
    double maxBody = MaximumBodyLength(20, shift + 1);
    double wickLength;

    if(closePrice > openPrice) // 陽線の場合
        wickLength = highPrice - closePrice; // 上ヒゲの長さ
    else
        wickLength = openPrice - lowPrice; // 下ヒゲの長さ

    return bodyLength > maxBody 
           && bodyLength >= LargeCandleBodyPips * Point
           && wickLength < bodyLength * 0.3; // ヒゲが実体の3割未満
}

double MaximumBodyLength(int barsToConsider, int startShift)
{
    double maxBodyLength = 0;
    for(int i = 0; i < barsToConsider; i++)
    {
        double openPrice = iOpen(Symbol(), PERIOD_M1, i + startShift);
        double closePrice = iClose(Symbol(), PERIOD_M1, i + startShift);
        double bodyLength = MathAbs(closePrice - openPrice);
        
        if(bodyLength > maxBodyLength)
            maxBodyLength = bodyLength;
    }
    return maxBodyLength;
}


// 損切ラインの値を取得
double GetLastZigzagHigh()
{
    int i = 1;
    while(i <= Bars)
    {
        double zzValue = iCustom(Symbol(), PERIOD_M1, "ZigZag", ZigzagDepth, ZigzagDeviation, ZigzagBackstep, 0, i);
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
        double zzValue = iCustom(Symbol(), PERIOD_M1, "ZigZag", ZigzagDepth, ZigzagDeviation, ZigzagBackstep, 0, i);
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