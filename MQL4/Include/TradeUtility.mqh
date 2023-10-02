// TradeUtility.mqh
class TradeUtility {

public:
   // 時間帯内にいるかをチェックする
   bool IsWithinTradingHours(int startHour, int endHour) {
      datetime currentTime = TimeCurrent();
      int currentHour = TimeHour(currentTime);
      if (currentHour >= startHour && currentHour < endHour)
         return true;
      return false;
   }

   // ボラティリティが許容範囲内かチェックする
   bool IsVolatilityAcceptable(string symbol, int period = 14, double minATRThreshold = 0.01) {
      double atrValue = iATR(symbol, PERIOD_H1, period, 0);
      if (atrValue > minATRThreshold)
         return true;
      return false;
   }

   // エントリーチェック関数
   bool CanEnterTrade(string symbol, int startHour, int endHour, double minATRThreshold = 0.01) {
      if (IsWithinTradingHours(startHour, endHour) && IsVolatilityAcceptable(symbol, 14, minATRThreshold))
         return true;
      return false;
   }
};
