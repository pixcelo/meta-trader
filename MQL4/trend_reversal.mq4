//+------------------------------------------------------------------+
//|                                               trend_reversal.mq4 |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.00"
#property strict

input double LargeCandleBodyPips = 5.0;        // 大陽線・大陰線のローソク足の実態のpips
input double RiskRewardRatio = 1.0;            // リスクリワード比
input int ZigzagDepth = 12;                    // ZigzagのDepth設定
input double lotSize = 0.01;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // EAが終了されるときに行われる処理をこちらに記述
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    // Zigzagの値取得
    double currentZigzag = iCustom(Symbol(), PERIOD_M1, "Zigzag", ZigzagDepth, 0, 0);
    double currentClose = iClose(Symbol(), PERIOD_M1, 0);
    
    bool isBullishBreakout = CheckBullishBreakout() && currentClose > EMA100(0);
    bool isBearishBreakout = CheckBearishBreakout() && currentClose < EMA100(0);
    
    if(isBullishBreakout)
    {
        // ロングのエントリー条件を確認...
        PlaceBuyOrderWithZigzagSL();
    }
    
    if(isBearishBreakout)
    {
        // ショートのエントリー条件を確認...
        PlaceSellOrderWithZigzagSL();
    }
   
  }
//+------------------------------------------------------------------+
void OnTester()
{
    // バックテスト完了時に行われる処理をこちらに記述...
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

double EMA100(int shift)
{
    return iMA(Symbol(), PERIOD_M1, 100, 0, MODE_EMA, PRICE_CLOSE, shift);
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
