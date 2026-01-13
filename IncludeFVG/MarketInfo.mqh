//+------------------------------------------------------------------+
//|                                                   MarketInfo.mqh |
//|                                                   Modular FVG EA |
//+------------------------------------------------------------------+
#property strict
#include "Common.mqh"

class CMarketInfo
  {
public:
   // Get Rates for any timeframe
   static int GetRates(string symbol, ENUM_TIMEFRAMES tf, int count, MqlRates &rates[])
     {
      ArraySetAsSeries(rates, false); // Standard Indexing (0=Oldest)
      int copied = CopyRates(symbol, tf, 0, count, rates);
      
      if(copied < 0)
        {
         Logger.Error("MarketInfo", StringFormat("Failed to copy rates for %d. Err: %d", tf, GetLastError()));
         return 0;
        }
      return copied;
     }

   // Get Specific Candle Body Size
   static double GetBodySize(const MqlRates &rate)
     {
      return MathAbs(rate.close - rate.open);
     }
     
   // Get Average Body Size (Simple SMA of bodies)
   static double GetAvgBodySize(const MqlRates &rates[], int count)
     {
      double sum = 0;
      int total = ArraySize(rates);
      if(total < count) count = total;
      
      for(int i = total - 1; i >= total - count; i--)
        {
         sum += GetBodySize(rates[i]);
        }
      return (count > 0) ? sum / count : 0.0;
     }

   // Get ATR (Approximate using TR if indicator handle too slow, or use Loop)
   // For EA, best to use iATR handle or simple TR calculation loop if infrequent.
   // Let's implement robust manual TR average to avoid Handle complexity in classes for now unless needed.
   static double CalculateATR(const MqlRates &rates[], int period)
     {
      int total = ArraySize(rates);
      if(total <= period) return 0.0;
      
      double sumArgs = 0.0;
      // Calculate last 'period' TRs
      // TR = Max(H-L, Abs(H-Cp), Abs(L-Cp))
      
      for(int i = total - 1; i >= total - period; i--)
        {
         if(i == 0) continue; 
         double hl = rates[i].high - rates[i].low;
         double hcp = MathAbs(rates[i].high - rates[i-1].close);
         double lcp = MathAbs(rates[i].low - rates[i-1].close);
         
         double tr = MathMax(hl, MathMax(hcp, lcp));
         sumArgs += tr;
        }
        
      return sumArgs / period;
     }
  };
//+------------------------------------------------------------------+
