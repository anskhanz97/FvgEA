//+------------------------------------------------------------------+
//|                                                    Structure.mqh |
//|                                                   Modular FVG EA |
//+------------------------------------------------------------------+
#property strict
#include "Common.mqh"

class CStructure
  {
private:
   // Structure Point
   struct SwingPoint
     {
      double   price;
      datetime time;
      bool     isHigh; // true=High, false=Low
      int      index;
     };

public:
   // Check if the FVG at 'fvg_creation_index' (Candle 3)
   // was preceded by a valid Structure Event (BOS or Sweep) caused by Candle 2 (Displacement).
   // Candle 2 Index = fvg_creation_index - 1.
   static bool CheckContext(const MqlRates &rates[], int fvg_creation_idx, ENUM_FVG_TYPE type, string fvgName, int lookback)
     {
      int actionIdx = fvg_creation_idx - 1; // The candle that made the move
      if(actionIdx < 5) return false;
      
      // 1. Find recent Swings (Look back 50 bars)
      SwingPoint lastHigh, lastLow;
      lastHigh.price = 0; 
      lastLow.price = 999999;
      
      FindRecentSwings(rates, actionIdx, lookback, lastHigh, lastLow);
      
      Logger.Debug("Structure", StringFormat("Validating Structure for %s. LastHigh: %.5f, LastLow: %.5f", 
                  fvgName, lastHigh.price, lastLow.price));

      // 2. Validate Events
      if(type == FVG_BULLISH)
        {
         // Needs to have broken a High (BOS) or Swept a Low?
         // User Logic: "After BOS" or "After Sweep of Highs/Lows"?
         // Logic: Sweep -> Displacement -> FVG.
         // Bullish FVG typically forms after Sweeping a LOW (taking liquidity) and reversing up.
         // OR after Breaking a HIGH (continuation).
         
         // A. Sweep of Low (Bullish Reversal)
         // Did the action candle (or recent few) dip below LastLow but close above?
         if(lastLow.price < 999999)
           {
            if(rates[actionIdx].low < lastLow.price && rates[actionIdx].close > lastLow.price)
              {
               Logger.Info("Structure", StringFormat("Valid: Bullish Sweep of Low for %s", fvgName));
               return true;
              }
           }
           
         // B. BOS of High (Bullish Continuation)
         if(lastHigh.price > 0)
           {
             if(rates[actionIdx].close > lastHigh.price)
               {
               Logger.Info("Structure", StringFormat("Valid: Bullish BOS for %s", fvgName));
                return true;
               }
           }
        }
      else // BEARISH
        {
         // A. Sweep of High (Bearish Reversal)
         if(lastHigh.price > 0)
           {
            if(rates[actionIdx].high > lastHigh.price && rates[actionIdx].close < lastHigh.price)
              {
               Logger.Info("Structure", StringFormat("Valid: Bearish Sweep of High for %s", fvgName));
               return true;
              }
           }
           
         // B. BOS of Low (Bearish Continuation)
         if(lastLow.price < 999999)
           {
            if(rates[actionIdx].close < lastLow.price)
              {
               Logger.Info("Structure", StringFormat("Valid: Bearish BOS for %s", fvgName));
               return true;
              }
           }
        }
        
      return false;
     }

private:
   // Simple 3-bar Fractal search? Or 5?
   // Let's use 5-bar (High surrounded by 2 lower highs on each side)
   static void FindRecentSwings(const MqlRates &rates[], int currentIdx, int lookback, SwingPoint &outHigh, SwingPoint &outLow)
     {
      // Search backwards
      int start = currentIdx - 2; // Can't be swing if not formed
      int end = MathMax(0, currentIdx - lookback);
      
      for(int i=start; i > end + 2; i--)
        {
         // Check High Fractal
         if(rates[i].high > rates[i-1].high && rates[i].high > rates[i-2].high &&
            rates[i].high > rates[i+1].high && rates[i].high > rates[i+2].high)
           {
            if(outHigh.price == 0) // Found most recent
              {
               outHigh.price = rates[i].high;
               outHigh.time = rates[i].time;
               outHigh.index = i;
               outHigh.isHigh = true;
              }
           }
           
         // Check Low Fractal
         if(rates[i].low < rates[i-1].low && rates[i].low < rates[i-2].low &&
            rates[i].low < rates[i+1].low && rates[i].low < rates[i+2].low)
           {
            if(outLow.price == 999999) // Found most recent
              {
               outLow.price = rates[i].low;
               outLow.time = rates[i].time;
               outLow.index = i;
               outLow.isHigh = false;
              }
           }
           
         if(outHigh.price != 0 && outLow.price != 999999) break; // Found both
        }
     }
  };
//+------------------------------------------------------------------+
