#property strict

class RCICalculator {
  private:
    struct RciData {
        datetime date_value;                        // 日付
        double   rate_value;                        // 価格
        int      rank_date;                         // 日付順位
        int      rank_rate;                         // 価格順位
        double   rank_adjust_rate;                  // 価格順位(調整後)
    };
  
  public:
    // RCIを計算するメソッド
    double Calculate(int rciPeriod, int shift = 0, int timeframe = PERIOD_CURRENT) {
        // RCI算出用配列を初期化
        RciData rciData[];
        ArrayResize(rciData, rciPeriod);
        
        // 配列にデータをセット
        for (int i = 0; i < rciPeriod; i++) {
            rciData[i].date_value = i + 1;
            rciData[i].rate_value = iClose(NULL, timeframe, shift + i);
            rciData[i].rank_date = i + 1;
        }
        
        // 価格に基づいてランク付け
        for (int i = 0; i < rciPeriod; i++) {
            for (int j = i + 1; j < rciPeriod; j++) {
                if (rciData[j].rate_value < rciData[i].rate_value) {
                    Swap(rciData[i], rciData[j]);
                }
            }
        }
        
        // RCIの計算
        double d_sum = 0;
        for (int i = 0; i < rciPeriod; i++) {
            int rank_rate = rciPeriod - i;
            double d = rciData[i].rank_date - rank_rate;
            d_sum += d * d;
        }
        
        double rci = (1.0 - 6.0 * d_sum / (rciPeriod * (rciPeriod * rciPeriod - 1))) * 100;
        return rci;
    }
    
  private:
    void Swap(RciData &a, RciData &b) {
        RciData temp = a;
        a = b;
        b = temp;
    }
};