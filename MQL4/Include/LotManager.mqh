// LotManager
class LotManager
{
private:
    double riskPercentage; 

public:
    void SetRiskPercentage(double riskPercent = 2.0) {
        riskPercentage = riskPercent;
    }

    // 資産のＮ％のリスクのロット数を計算する
    double CalculateLot(double stopLossPips) {
        double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
        
        if (MarketInfo(Symbol(), MODE_DIGITS) == 3 || MarketInfo(Symbol(), MODE_DIGITS) == 5){
            tickValue *= 10.0;
        }

        double accountBalance = AccountBalance();
        double riskAmount = accountBalance * (riskPercentage / 100.0);
        double lotSize = riskAmount / (stopLossPips * tickValue);
        double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
        lotSize = MathFloor(lotSize / lotStep) * lotStep;

        double margin = MarketInfo(Symbol(), MODE_MARGINREQUIRED);
        
        if (margin > 0.0) {
            double accountMax = accountBalance / margin;
            accountMax = MathFloor(accountMax / lotStep) * lotStep;

            if (lotSize > accountMax){
                lotSize = accountMax;
            }
        }

        double minLots = MarketInfo(Symbol(), MODE_MINLOT);
        double maxLots = MarketInfo(Symbol(), MODE_MAXLOT);

        if (lotSize < minLots){
            lotSize = -1.0;
        } else if (lotSize > maxLots){
            lotSize = maxLots;
        }

        return lotSize;
    }
};
