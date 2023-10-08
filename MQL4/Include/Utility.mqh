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
