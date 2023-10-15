// HorizontalLineManager.mqh
struct HorizontalLine {
    double price;
    int strength;
};

HorizontalLine hLines[];

#include "ZigzagSeeker.mqh"
#include "Utility.mqh"

class HorizontalLineManager
{
private:    
    Utility utility;

public:
    // 強度の計算
    void CalculateStrength() {
        double pipsRange = 5.0;  // ブレイクを判定する範囲 (pips)
        double distance = utility.PipsToPrice(pipsRange);
        
        for (int i = 0; i < ArraySize(hLines); i++) {
            hLines[i].strength = 5;  // 初期値は5

            for (int j = i; j >= 0; j--) {
                // ローソク足の高値または安値がhLineを n pips以上ブレイクしていた場合、強度を下げる
                if (High[j] > hLines[i].price + distance || Low[j] < hLines[i].price - distance) {
                    hLines[i].strength--;
                }
            }
        }
    }

    // 強度の閾値以上の極値をフィルタリング
    void FilterStrongLines(int strengthThreshold) {
        HorizontalLine tempLines[];
        ArrayResize(tempLines, ArraySize(hLines));
        
        int k = 0;
        for (int i = 0; i < ArraySize(hLines); i++) {
            if (hLines[i].strength >= strengthThreshold) {
                //Print("hLines[i].strength ", hLines[i].strength);
                tempLines[k] = hLines[i];
                k++;
            }
        }
        ArrayResize(tempLines, k);
        ArrayResize(hLines, k);
        ArrayCopy(hLines, tempLines);
    }

    // 指定した時間足を基に強い水平線を識別
    void IdentifyStrongHorizontalLines(int strengthThreshold, int timeframe, int term = 60) {
        double highs[], lows[];
        
        // 指定した時間足のバー数を取得
        int rates_count = MathMin(iBars(NULL, timeframe), term);

        ArrayResize(highs, rates_count);
        ArrayResize(lows, rates_count);
        
        int i;
        for (i = 0; i < rates_count; i++) {
            highs[i] = iHigh(NULL, timeframe, i);   // 指定した時間足の高値を取得
            lows[i] = iLow(NULL, timeframe, i);     // 指定した時間足の安値を取得
        }
        
        // 高値と安値を組み合わせて一つの配列に結合
        double prices[];
        ArrayResize(prices, 2 * rates_count);
        for (i = 0; i < rates_count; i++) {
            prices[2 * i] = highs[i];
            prices[2 * i + 1] = lows[i];
        }
        
        // 高値と安値をセットし、強度を計算、強度の閾値以上のものをフィルタリングして、最終的な強い水平線のセットをhLinesに保持
        ArrayResize(hLines, 2 * rates_count);
        for (i = 0; i < 2 * rates_count; i++) {
            hLines[i].price = prices[i];
            hLines[i].strength = 0;
        }

        CalculateStrength();
        FilterStrongLines(strengthThreshold);
    }

    // 強度を計算し、閾値以上の極値をフィルタリングして水平線を識別
    void IdentifyStrongHorizontalLinesByExtrema(int strengthThreshold) {
        // 極値の配列から価格データのみを抽出
        double prices[];
        ArrayResize(prices, ArraySize(ExtremaArray));
        for (int i = 0; i < ArraySize(ExtremaArray); i++) {
            prices[i] = ExtremaArray[i].value;
        }
        
        // 極値をセットし、強度を計算、強度の閾値以上のものをフィルタリングして、最終的な強い水平線のセットをhLinesに保持
        ArrayResize(hLines, ArraySize(prices));
        for (int j = 0; j < ArraySize(prices); j++) {
            hLines[j].price = prices[j];
            hLines[j].strength = 0;
        }
        CalculateStrength();
        FilterStrongLines(strengthThreshold);
    }

};