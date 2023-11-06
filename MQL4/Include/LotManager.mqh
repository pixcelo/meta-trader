// LotManager
#include "Utility.mqh"

class LotManager
{
private:
    double riskPercentage;
    Utility ut;

public:
    void SetRiskPercentage(double riskPercent = 2.0) {
        riskPercentage = riskPercent;
    }

    // 資金に対して適切なロットサイズを計算する
    double GetLotSize(string order, double stopLossPrice) {
        double entryPrice = MarketInfo(Symbol(), MODE_BID);

        if (order == "BUY") {
            entryPrice = MarketInfo(Symbol(), MODE_ASK);
        }

        double stopLossPips = ut.PriceToPips(MathAbs(entryPrice - stopLossPrice));
        double lotSize = CalculateLot(stopLossPips);
        return lotSize;
    }

private:
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
                lotSize = accountMax * 0.9;
                lotSize = MathFloor(lotSize / lotStep) * lotStep;
            }
        }

        double minLots = MarketInfo(Symbol(), MODE_MINLOT);
        double maxLots = MarketInfo(Symbol(), MODE_MAXLOT);

        if (lotSize < minLots){
            lotSize = minLots;
        } else if (lotSize > maxLots){
            lotSize = maxLots;
        }

        return lotSize;
    }
    // 資産のＮ％のリスクのロット数を計算する
    // double CalculateLot(double stopLossPips) {
    //     double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
    //     double pipsValue = tickValue * ut.GetPointCoefficient();
    //     Print("Symbol() ", Symbol());
    //     Print("pipsValue ", pipsValue);
    //     double accountBalance = AccountBalance();
    //     double riskAmount = accountBalance * (riskPercentage / 100.0);
    //     double lotSize = riskAmount / (stopLossPips * pipsValue);
    //     double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
    //     lotSize = MathCeil(lotSize / lotStep) * lotStep;

    //     double margin = MarketInfo(Symbol(), MODE_MARGINREQUIRED);
    //     // 1ロットあたりの必要マージンの計算
    //     double requiredMarginForLotSize = lotSize * margin;
    //     // 使用可能マージンの計算
    //     double availableMargin = AccountEquity() - AccountMargin();
    //     // ロットサイズの調整
    //     if (requiredMarginForLotSize > availableMargin){
    //         lotSize = availableMargin / margin;
    //         lotSize = MathFloor(lotSize / lotStep) * lotStep;
    //     }

    //     double minLots = MarketInfo(Symbol(), MODE_MINLOT);
    //     double maxLots = MarketInfo(Symbol(), MODE_MAXLOT);

    //     if (lotSize < minLots){
    //         lotSize = minLots;
    //     } else if (lotSize > maxLots){
    //         lotSize = maxLots;
    //     }

    //     return lotSize;
    // }

    // double CalculateLot(double stopLossInPoints) {
    //     // 1. リスク許容額の計算
    //     double riskAmount = AccountBalance() * 0.02;
    //     double riskPerPoint = riskAmount / stopLossInPoints;
    //     double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
        
    //     // 3桁または5桁の通貨ペアのTickValueの考慮
    //     if (MarketInfo(Symbol(), MODE_DIGITS) == 3 || MarketInfo(Symbol(), MODE_DIGITS) == 5){
    //         tickValue *= 10.0;
    //     }

    //     double lotSize = riskPerPoint / tickValue;

    //     // 2. ロットステップの考慮
    //     double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
    //     lotSize = MathFloor(lotSize / lotStep) * lotStep;

    //     // 3. 最大証拠金の考慮
    //     // double margin = MarketInfo(Symbol(), MODE_MARGINREQUIRED);
    //     // // 1ロットあたりの必要マージンの計算
    //     // double requiredMarginForLotSize = lotSize * margin;
    //     // // 使用可能マージンの計算
    //     // double availableMargin = AccountEquity() - AccountMargin();
    //     // // ロットサイズの調整
    //     // if (requiredMarginForLotSize > availableMargin){
    //     //     lotSize = availableMargin / margin;
    //     //     lotSize = MathFloor(lotSize / lotStep) * lotStep;
    //     // }

    //     // 4. ブローカーの制約の考慮
    //     double minLots = MarketInfo(Symbol(), MODE_MINLOT);
    //     double maxLots = MarketInfo(Symbol(), MODE_MAXLOT);
    //     if (lotSize < minLots){
    //         lotSize = minLots;
    //     } else if (lotSize > maxLots){
    //         lotSize = maxLots;
    //     }

    //     // 各変数の値を表示
    //     Print("Risk Amount: ", riskAmount);
    //     Print("Risk Per Point: ", riskPerPoint);
    //     Print("Tick Value: ", tickValue);
    //     Print("Initial Lot Size: ", lotSize);
    //     Print("Lot Step: ", lotStep);
    //     Print("requiredMarginForLotSize: ", requiredMarginForLotSize);
    //     Print("Available Margin: ", availableMargin);
    //     Print("Min Lots: ", minLots);
    //     Print("Max Lots: ", maxLots);
    //     Print("Final Lot Size: ", lotSize);

    //     return lotSize;
    // }


};
