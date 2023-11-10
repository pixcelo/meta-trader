class FractalDetector {
private:
    int timeframe;
    double lastFractalHigh;    // 直近の高値フラクタル
    double lastFractalLow;     // 直近の安値フラクタル
    double prevFractalHigh;    // 直前の高値フラクタル
    double prevFractalLow;     // 直前の安値フラクタル

public:
    FractalDetector() {
        timeframe = PERIOD_CURRENT;
    }

    void UpdateFractals() {
        int totalBars = iBars(NULL, timeframe);
        int lookback = 60 + 2;
        for (int shift = lookback; shift < totalBars - lookback; ++shift) {
            if (IsBullishFractal(shift, 30)) {
                if (lastFractalHigh != 0 && lastFractalHigh != iHigh(NULL, timeframe, shift)) {
                    prevFractalHigh = lastFractalHigh;
                }
                lastFractalHigh = iHigh(NULL, timeframe, shift);
            }
            if (IsBearishFractal(shift, 30)) {
                if (lastFractalLow != 0 && lastFractalLow != iLow(NULL, timeframe, shift)) {
                    prevFractalLow = lastFractalLow;
                }
                lastFractalLow = iLow(NULL, timeframe, shift);
            }
        }
    }

    bool IsBullishFractal(int shift, int bars) {
        double currentHigh = iHigh(NULL, timeframe, shift);
        for (int i = 1; i <= bars; i++) {
            if (currentHigh < iHigh(NULL, timeframe, shift + i) ||
                currentHigh < iHigh(NULL, timeframe, shift - i)) {
                return false;
            }
        }
        return true;
    }

    bool IsBearishFractal(int shift, int bars) {
        double currentLow = iLow(NULL, timeframe, shift);
        for (int i = 1; i <= bars; i++) {
            if (currentLow > iLow(NULL, timeframe, shift + i) ||
                currentLow > iLow(NULL, timeframe, shift - i)) {
                return false;
            }
        }
        return true;
    }
};
