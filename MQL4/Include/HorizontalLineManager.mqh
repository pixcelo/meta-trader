// HorizontalLineManager.mqh

#include "ZigzagSeeker.mqh"
#include "Utility.mqh"

class HorizontalLineManager
{
private:
    struct HorizontalLine {
        double price;
        int strength;
    };

    HorizontalLine hLines[];
    
    Utility utility;

public:
    // Getter
    void GetLines(HorizontalLine &linesCopy[]) {
        ArrayResize(linesCopy, ArraySize(hLines));
        for (int i = 0; i < ArraySize(hLines); i++) {
            linesCopy[i] = hLines[i];
        }
    }

    // 強度の計算
    void CalculateStrength() {
        double pipRange = 5.0;  // 隣接する極値を同一と見なす範囲（ピプス）
        
        for (int i = 0; i < ArraySize(hLines); i++) {
            hLines[i].strength = 1;  // 初期値として自身をカウント
            for (int j = 0; j < ArraySize(hLines); j++) {
                double diffPips = utility.PriceToPips(MathAbs(hLines[i].price - hLines[j].price));
                if (i != j && diffPips <= pipRange) {
                    hLines[i].strength++;  // 価格がpipRange以内であればカウントアップ
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
                tempLines[k] = hLines[i];
                k++;
            }
        }
        ArrayResize(tempLines, k);
        ArrayCopy(hLines, tempLines);
    }

    // 強度を計算し、閾値以上の極値をフィルタリングして水平線を識別
    void IdentifyStrongHorizontalLines(int strengthThreshold) {
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

