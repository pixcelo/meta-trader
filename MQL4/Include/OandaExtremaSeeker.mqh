// ExtremaSeeker.mqh
class ExtremaSeeker {
  private:
    double ExtZigzagBuffer[];
    double ExtHighBuffer[];
    double ExtLowBuffer[];
    double UP[], DN[];

    int Depth;
    int Deviation;
    int Backstep;
    int ExtLevel;
    
  public:
    void SetProperties(int d=7, int dev=5, int bs=3) {
        Depth = d;
        Deviation = dev;
        Backstep = bs;
        ExtLevel = 3;
    }
    
    int InitializeAll() {
        ArrayResize(ExtZigzagBuffer, Bars);
        ArrayResize(ExtHighBuffer, Bars);
        ArrayResize(ExtLowBuffer, Bars);
        ArrayInitialize(ExtZigzagBuffer, 0.0);
        ArrayInitialize(ExtHighBuffer, 0.0);
        ArrayInitialize(ExtLowBuffer, 0.0);
        return(Bars - Depth);
    }
    
    // Method to calculate the ZigZag values and store them in the class properties
    void SeekExtrema(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long& volume[])
    {
        int    i, limit, counterZ, whatlookfor = 0;
        int    back, pos, lasthighpos = 0, lastlowpos = 0;
        double extremum;
        double curlow = 0.0, curhigh = 0.0, lasthigh = 0.0, lastlow = 0.0;
        //--- check for history and inputs
        if(rates_total < Depth || Backstep >= Depth)
            return;
        //--- first calculations
        if(prev_calculated == 0)
            limit = InitializeAll();
        else {
            //--- find first extremum in the depth ExtLevel or 100 last bars
            i = counterZ = 0;
            while(counterZ < ExtLevel && i < 100) {
                if(ExtZigzagBuffer[i] != 0.0)
                    counterZ++;
                i++;
            }
            //--- no extremum found - recounting all from begin
            if(counterZ == 0)
                limit = InitializeAll();
            else {
                //--- set start position to found extremum position
                limit = i - 1;
                //--- what kind of extremum?
                if(ExtLowBuffer[i] != 0.0) {
                    //--- low extremum
                    curlow = ExtLowBuffer[i];
                    //--- will look for the next high extremum
                    whatlookfor = 1;
                } else {
                    //--- high extremum
                    curhigh = ExtHighBuffer[i];
                    //--- will look for the next low extremum
                    whatlookfor = -1;
                }
                //--- clear the rest data
                for(i = limit - 1; i >= 0; i--) {
                    ExtZigzagBuffer[i] = 0.0;
                    ExtLowBuffer[i] = 0.0;
                    ExtHighBuffer[i] = 0.0;
                }
            }
        }
        //--- main loop
        for(i = limit; i >= 0; i--) {
            //--- find lowest low in depth of bars
            extremum = low[iLowest(NULL, 0, MODE_LOW, Depth, i)];
            //--- this lowest has been found previously
            if(extremum == lastlow)
                extremum = 0.0;
            else {
                //--- new last low
                lastlow = extremum;
                //--- discard extremum if current low is too high
                if(low[i] - extremum > Deviation * Point)
                    extremum = 0.0;
                else {
                    //--- clear previous extremums in backstep bars
                    for(back = 1; back <= Backstep; back++) {
                    pos = i + back;
                    if(ExtLowBuffer[pos] != 0 && ExtLowBuffer[pos] > extremum)
                        ExtLowBuffer[pos] = 0.0;
                    }
                }
            }
            //--- found extremum is current low
            if(low[i] == extremum)
                ExtLowBuffer[i] = extremum;
            else
                ExtLowBuffer[i] = 0.0;
            //--- find highest high in depth of bars
            extremum = high[iHighest(NULL, 0, MODE_HIGH, Depth, i)];
            //--- this highest has been found previously
            if(extremum == lasthigh)
                extremum = 0.0;
            else {
                //--- new last high
                lasthigh = extremum;
                //--- discard extremum if current high is too low
                if(extremum - high[i] > Deviation * Point)
                    extremum = 0.0;
                else {
                    //--- clear previous extremums in backstep bars
                    for(back = 1; back <= Backstep; back++) {
                    pos = i + back;
                    if(ExtHighBuffer[pos] != 0 && ExtHighBuffer[pos] < extremum)
                        ExtHighBuffer[pos] = 0.0;
                    }
                }
            }
            //--- found extremum is current high
            if(high[i] == extremum)
                ExtHighBuffer[i] = extremum;
            else
                ExtHighBuffer[i] = 0.0;
        }
        //--- final cutting
        if(whatlookfor == 0) {
            lastlow = 0.0;
            lasthigh = 0.0;
        } else {
            lastlow = curlow;
            lasthigh = curhigh;
        }
        for(i = limit; i >= 0; i--) {
            switch(whatlookfor) {
            case 0: // look for peak or lawn
                if(lastlow == 0.0 && lasthigh == 0.0) {
                    if(ExtHighBuffer[i] != 0.0) {
                    lasthigh = High[i];
                    lasthighpos = i;
                    whatlookfor = -1;
                    ExtZigzagBuffer[i] = lasthigh;
                    }
                    if(ExtLowBuffer[i] != 0.0) {
                    lastlow = Low[i];
                    lastlowpos = i;
                    whatlookfor = 1;
                    ExtZigzagBuffer[i] = lastlow;
                    }
                }
                break;
            case 1: // look for peak
                if(ExtLowBuffer[i] != 0.0 && ExtLowBuffer[i] < lastlow && ExtHighBuffer[i] == 0.0) {
                    ExtZigzagBuffer[lastlowpos] = 0.0;
                    lastlowpos = i;
                    lastlow = ExtLowBuffer[i];
                    ExtZigzagBuffer[i] = lastlow;
                }
                if(ExtHighBuffer[i] != 0.0 && ExtLowBuffer[i] == 0.0) {
                    lasthigh = ExtHighBuffer[i];
                    lasthighpos = i;
                    ExtZigzagBuffer[i] = lasthigh;
                    whatlookfor = -1;
                }
                break;
            case -1: // look for lawn
                if(ExtHighBuffer[i] != 0.0 && ExtHighBuffer[i] > lasthigh && ExtLowBuffer[i] == 0.0) {
                    ExtZigzagBuffer[lasthighpos] = 0.0;
                    lasthighpos = i;
                    lasthigh = ExtHighBuffer[i];
                    ExtZigzagBuffer[i] = lasthigh;
                }
                if(ExtLowBuffer[i] != 0.0 && ExtHighBuffer[i] == 0.0) {
                    lastlow = ExtLowBuffer[i];
                    lastlowpos = i;
                    ExtZigzagBuffer[i] = lastlow;
                    whatlookfor = 1;
                }
                break;
            }
        }
        //--- 色分け
        limit = Bars - prev_calculated - 1;
        int min = 0;
        int count = 0;
        for (i = 0; i < Bars - 1; i++) {
            if (ExtZigzagBuffer[i] != 0) count++;
            if (count >= 4) {
                min = i;
                break;
            }
        }
        if (limit < min) limit = min;

        int bar[4];
        double zz[4];
        for (i = limit; i >= 0; i--) {
            ArrayInitialize(bar, -1);
            ArrayInitialize(zz, 0);
            if (ExtZigzagBuffer[i] != 0) {
                bar[0] = i;
                zz[0] = ExtZigzagBuffer[i];
                count = 1;

                for (int j = i + 1; j < Bars - 1; j++) {
                    if (ExtZigzagBuffer[j] != 0) {
                    bar[count] = j;
                    zz[count] = ExtZigzagBuffer[j];
                    count++;
                    if (count >= 4) break;
                    }
                }
                if (bar[3] == -1) continue;

                // if (zz[0] == High[i] && zz[0] > zz[2] && zz[1] > zz[3]) {
                //     DrawLine(UP, bar, zz);
                // } else if (zz[0] == Low[i] && zz[0] < zz[2] && zz[1] < zz[3]) {
                //     DrawLine(DN, bar, zz);
                // }
            }
        }

    }

    void GetZigzagBuffer(double &buffer[]) {
        ArrayCopy(buffer, ExtZigzagBuffer);
    }
    
    void GetHighBuffer(double &buffer[]) {
        ArrayCopy(buffer, ExtHighBuffer);
    }

    void GetLowBuffer(double &buffer[]) {
        ArrayCopy(buffer, ExtLowBuffer);
    }
};
