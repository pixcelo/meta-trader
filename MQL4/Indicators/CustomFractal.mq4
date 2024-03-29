//+------------------------------------------------------------------+
//|                                                     CustomFractal.mq4 |
//|                        Copyright 2023, [Your Name] |
//|                                       https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "2023 [Your Name]"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_color1 Blue // Bullish Fractal Color
#property indicator_color2 Red  // Bearish Fractal Color
#property strict

//--- input parameters
input int FractalBars = 2; // Number of bars on each side of the fractal
input ENUM_TIMEFRAMES TimeFrame = PERIOD_H1; // Timeframe to check for fractals

//--- indicator buffers
double BullishFractalBuffer[];
double BearishFractalBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
   IndicatorBuffers(2);
   SetIndexBuffer(0, BullishFractalBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, BearishFractalBuffer, INDICATOR_DATA);
   
   SetIndexStyle(0, DRAW_ARROW);
   SetIndexArrow(0, 233); // Up arrow
   SetIndexEmptyValue(0, 0);
   
   SetIndexStyle(1, DRAW_ARROW);
   SetIndexArrow(1, 234); // Down arrow
   SetIndexEmptyValue(1, 0);
   
   ArraySetAsSeries(BullishFractalBuffer, true);
   ArraySetAsSeries(BearishFractalBuffer, true);
   
   IndicatorShortName("Custom Fractal Indicator");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]) {
    int begin = Bars - FractalBars - 2;
    int lookback = FractalBars * 2; // フラクタルを計算するために必要なバーの数

    for (int i = begin; i >= lookback; i--) {
        if (high[i] > high[i+1] && high[i] > high[i+2] && high[i] > high[i-1] && high[i] > high[i-2]) {
            BullishFractalBuffer[i] = high[i]; // 上向きフラクタル
        } else {
            BullishFractalBuffer[i] = 0;
        }

        if (low[i] < low[i+1] && low[i] < low[i+2] && low[i] < low[i-1] && low[i] < low[i-2]) {
            BearishFractalBuffer[i] = low[i]; // 下向きフラクタル
        } else {
            BearishFractalBuffer[i] = 0;
        }
    }

    return(rates_total);
}

//--- Fractal detection functions
bool IsFractalUp(const double &high[], int current) {
   int bars2 = FractalBars * 2;
   if (current < bars2) return false;
   for (int i = 1; i <= FractalBars; ++i) {
      if (high[current - FractalBars] <= high[current - FractalBars + i] || 
          high[current - FractalBars] <= high[current - FractalBars - i])
         return false;
   }
   return true;
}

bool IsFractalDown(const double &low[], int current) {
   int bars2 = FractalBars * 2;
   if (current < bars2) return false;
   for (int i = 1; i <= FractalBars; ++i) {
      if (low[current - FractalBars] >= low[current - FractalBars + i] || 
          low[current - FractalBars] >= low[current - FractalBars - i])
         return false;
   }
   return true;
}
//+------------------------------------------------------------------+
