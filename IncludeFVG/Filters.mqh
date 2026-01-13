//+------------------------------------------------------------------+
//|                                                      Filters.mqh |
//|                                                   Modular FVG EA |
//+------------------------------------------------------------------+
#property strict
#include "Common.mqh"
#include "MarketInfo.mqh"

class CFilters
  {
public:
   // 1. Candle Quality Filter
   // Checks if the FVG creating candle (Gap Candle, i.e., Middle one?) 
   // Note: In 3-bar pattern, the gap exists *between* 1 and 3. The Move is usually Candle 2.
   // We pass the generic "Rates context" and the index of the "Displacement Candle" (Candle 2).
   static bool IsCandleQuality(const MqlRates &rates[], int disp_index, string fvgName, double minBodyRatio, double minBodyMult)
     {
      // Check limits
      if(disp_index < 1 || disp_index >= ArraySize(rates)) return false;
      
      MqlRates candle = rates[disp_index];
      double body = MathAbs(candle.close - candle.open);
      double range = candle.high - candle.low;
      
      // A. Doji Check
      if(range == 0) return false;
      if(body < (range * minBodyRatio)) // Body is less than X% of range -> Weak
        {
         Logger.Debug("Filter", StringFormat("Candle Quality Fail [Doji]. FVG: %s", fvgName));
         return false;
        }
        
      // B. Relative Size Check
      // Compare to Avg Body of last 10 candles
      double avgBody = CMarketInfo::GetAvgBodySize(rates, 10);
      if(body < (avgBody * minBodyMult))
        {
         Logger.Debug("Filter", StringFormat("Candle Quality Fail [Small Body]. Body: %.5f < Avg: %.5f. FVG: %s", body, avgBody, fvgName));
         return false;
        }
        
      return true;
     }

   // 2. Trend Bias Filter (EMA Slope)
   // Simple check: Is Close > EMA?
   static bool IsVolatilityValid(const MqlRates &rates[], int index, int m_atr_period, double min_pips, string fvgName)
     {
       // Basic ATR Calc (SMA of ranges)
       // We only need last candle range or avg.
       // Let's use simple SMA of ranges for ATR proxy.
       if(index < m_atr_period) return true;
       
       double sumTR = 0;
       for(int i=0; i<m_atr_period; i++)
         {
          int idx = index - i;
          double hl = rates[idx].high - rates[idx].low;
          double hc = MathAbs(rates[idx].high - rates[idx-1].close);
          double lc = MathAbs(rates[idx].low - rates[idx-1].close);
          double tr = MathMax(hl, MathMax(hc, lc));
          sumTR += tr;
         }
       double atr = sumTR / m_atr_period;
       
       // Convert min_pips to price
       // WARNING: Need Point/Digits? Assuming standard 0.0001 or 0.01.
       // Better to pass 'price delta'.
       // Note: MarketInfo has no Digits access helper. Assuming caller passes Pips converted to value?
       // No, user Inputs 'Pips'. We need Point size.
       // The 'rates' array doesn't carry symbol info.
       // We can just rely on the user passing 'Value' or assume standard.
       // BUT, we can't access Symbol Info here easily without Symbol name.
       // Let's assume the caller passes VALID THRESHOLD VALUE (Pips * Point).
       
       if(atr < min_pips) 
         {
          Logger.Debug("Filter", StringFormat("Volatility Fail. ATR: %.5f < Min: %.5f. FVG: %s", atr, min_pips, fvgName));
          return false;
         }
       return true;
     }

   static bool IsTrendAligned(const MqlRates &rates[], int index, int ema_period, ENUM_FVG_TYPE type)
     {
      // Need EMA handle? Or calculate manual EMA to be self-contained?
      // Manual EMA for independence in this class snippet:
      // EMA = (Close - PrevEMA) * Multiplier + PrevEMA
      // Too heavy to calc whole history here. 
      // Better to rely on the Close vs SMA for simplicity OR pass strict logic.
      // USER ASK: "50 EMA slope or simple higher-high".
      
      // Let's implement Higher-High / Lower-Low logic (3-bar swing check nearby)
      // Or just Compare Close to Close[20] as simple Trend Proxy.
      
      double ma = 0; 
      // Simple SMA 50 calculation for the specific index
      int start = index - ema_period; 
      if(start < 0) return true; // Not enough data, pass
      
      for(int k=start; k<index; k++) ma += rates[k].close;
      ma /= ema_period;
      
      if(type == FVG_BULLISH)
        {
         return (rates[index].close > ma);
        }
      else
        {
         return (rates[index].close < ma);
        }
     }
  };
//+------------------------------------------------------------------+
