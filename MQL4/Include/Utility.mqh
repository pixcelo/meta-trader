// Utility.mqh
class Utility {

public:
   // 現在の通貨ペアのポイント係数を返す
   // 通貨ペアやブローカーによって異なる価格の小数点位置を調整する
   int GetPointCoefficient() {
      if(_Digits == 3 || _Digits == 5) {
         return 10;
      } else {
         return 1;
      }
   }

   // スプレッド拡大への対応
   bool IsSpreadTooHigh(int pips)
   {
      double bid = MarketInfo(NULL, MODE_BID);
      double ask = MarketInfo(NULL, MODE_ASK);
      double spread = ask - bid;
      double threshold = PipsToPrice(pips);
      return spread > threshold;
   }

   // 時間帯内にいるかをチェックする
   bool IsWithinTradingHours(int startHour, int endHour) {
      datetime currentTime = TimeCurrent();
      int currentHour = TimeHour(currentTime);
      if (currentHour >= startHour && currentHour < endHour)
         return true;
      return false;
   }

   // 最後の取引から一定の秒数が経過しているかをチェックする
   bool IsWithinTradeInterval(datetime lastTradeTime) {
      int lastTradeIntervalSeconds = 300; // 最後のトレードからの間隔(秒)
      if (TimeCurrent() - lastTradeTime < lastTradeIntervalSeconds) {
         return true;
      }
      return false;
   }

   // ボラティリティが許容範囲内かチェックする
   bool IsVolatilityAcceptable(string symbol, int period = 14, double minATRThreshold = 0.01) {
      double atrValue = iATR(symbol, PERIOD_CURRENT, period, 0);
      return atrValue > minATRThreshold;
   }

   // エントリーチェック関数
   bool CanEnterTrade(string symbol, int startHour, int endHour, double minATRThreshold = 0.01) {
      if (IsWithinTradingHours(startHour, endHour) && IsVolatilityAcceptable(symbol, 14, minATRThreshold))
         return true;
      return false;
   }

   // 値幅の差が N pips 以下かを判定する
   bool IsPriceDiffLessThanTargetPips(double a, double b, int pips) {
      double diffPips = PriceToPips(MathAbs(a - b));
      return diffPips <= pips;
   }

   // 値幅の差が N pips 以上かを判定する
   bool IsPriceDiffLargerThanTargetPips(double a, double b, int pips) {
      double diffPips = PriceToPips(MathAbs(a - b));
      return diffPips >= pips;
   }

   // 値幅が N pips 以上かを判定する
   bool IsPriceLargerThanTargetPips(double price, int pips) {
      double pricePips = PriceToPips(price);
      return pricePips >= pips;
   }

   // 価格をpipsに換算する
   double PriceToPips(double price) {
      double pips = 0;

      // 現在の通貨ペアの小数点以下の桁数を取得
      int digits = (int)MarketInfo(Symbol(), MODE_DIGITS);

      // 3桁・5桁のFXブローカーの場合
      if (digits == 3 || digits == 5){
         pips = price * MathPow(10, digits) / 10;
      }

      // 2桁・4桁のFXブローカーの場合
      if (digits == 2 || digits == 4){
         pips = price * MathPow(10, digits);
      }

      // 少数点以下を１桁に丸める（目的によって桁数は変更する）
      pips = NormalizeDouble(pips, 1);

      return pips;
   }

   // pipsを価格に換算する
   double PipsToPrice(double pips) {
      double price = 0;

      // 現在の通貨ペアの小数点以下の桁数を取得
      int digits = (int)MarketInfo(Symbol(), MODE_DIGITS);

      // 3桁・5桁のFXブローカー
      if (digits == 3 || digits == 5){
         price = pips / MathPow(10, digits) * 10;
      }

      // 2桁・4桁のFXブローカー
      if (digits == 2 || digits == 4){
         price = pips / MathPow(10, digits);
      }

      // 価格を有効桁数で丸める
      price = NormalizeDouble(price, digits);
      
      return price;
   }

};
