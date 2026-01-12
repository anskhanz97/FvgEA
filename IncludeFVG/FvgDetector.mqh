//+------------------------------------------------------------------+
//|                                                  FvgDetector.mqh |
//|                                                   Modular FVG EA |
//+------------------------------------------------------------------+
#property strict
#include "Common.mqh"
#include "Config.mqh"
#include "Logger.mqh"

class CFvgDetector
  {
private:
   FvgStruct         m_fvgs[];
   int               m_total_fvgs;

public:
                     CFvgDetector() { m_total_fvgs=0; }
                    ~CFvgDetector() {}

   // Get List
   void              GetFVGs(FvgStruct &fvgs[])
     {
      ArrayResize(fvgs, m_total_fvgs);
      for(int i=0; i<m_total_fvgs; i++)
         fvgs[i] = m_fvgs[i];
     }
     
   // Update FVG at index
   void              UpdateFVG(int index, const FvgStruct &fvg)
     {
      if(index >= 0 && index < m_total_fvgs)
         m_fvgs[index] = fvg;
     }

   // Clear (for full rescan if needed)
   void              Clear()
     {
      ArrayFree(m_fvgs);
      m_total_fvgs = 0;
     }

   // Main Detection Function
   void Detect(const MqlRates &rates[], int total_bars, int start_index)
     {
      // Ensure we have enough bars
      if(start_index < 0) start_index = 0;
      
      // We need to ensure we only process CLOSED candles.
      // If 'rates' includes the current open bar at [total_bars-1],
      // then the last closed bar is [total_bars-2].
      // We look for pattern: Candle 1 (i), Candle 2 (i+1), Candle 3 (i+2).
      // Candle 3 (i+2) MUST be closed.
      // So max (i+2) = total_bars - 2.
      // Thus max i = total_bars - 4. 
      // Example: 100 bars (0..99). 99 is open. 98 is last closed.
      // We want Candle 3 to be 98.
      // i+2 = 98 => i = 96.
      // Loop condition: i <= total_bars - 4.
      
      for(int i=start_index; i <= total_bars - 4; i++)
        {
         // Indexes:
         // i   = Candle 1 (Left) - Closed
         // i+1 = Candle 2 (Middle) - Closed
         // i+2 = Candle 3 (Right) - Closed (Confirmation)
         
         // 1. Bullish FVG
         // Gap between Candle 1 High and Candle 3 Low
         if(rates[i+2].low > rates[i].high)
           {
            // Found Bullish FVG
            FvgStruct fvg;
            fvg.type = FVG_BULLISH;
            fvg.creationTime = rates[i+2].time; // Time of confirming candle (Candle 3)
            fvg.startTime = rates[i].time;      // Time of first candle (Box Start)
            fvg.timeframe = TimeframeToString(Period());
            fvg.name = GenerateName(fvg.type, fvg.creationTime, fvg.timeframe);
            
            fvg.topPrice = rates[i+2].low;    // Entry Level
            fvg.bottomPrice = rates[i].high;  // SL Reference
            
            // Check State (History Check or Live Check)
            // If checking live, 'rates' has future data? No.
            // If historical, check from i+3.
            CheckState(fvg, rates, total_bars, i+3);
            
            AddFVG(fvg);
           }
         
         // 2. Bearish FVG
         // Gap between Candle 1 Low and Candle 3 High
         else if(rates[i+2].high < rates[i].low)
           {
            // Found Bearish FVG
            FvgStruct fvg;
            fvg.type = FVG_BEARISH;
            fvg.creationTime = rates[i+2].time;
            fvg.startTime = rates[i].time;      // Time of first candle
            fvg.timeframe = TimeframeToString(Period());
            fvg.name = GenerateName(fvg.type, fvg.creationTime, fvg.timeframe);
            
            fvg.topPrice = rates[i].low;      // SL Reference
            fvg.bottomPrice = rates[i+2].high; // Entry Level
            
            // Check State
            CheckState(fvg, rates, total_bars, i+3);
            
            AddFVG(fvg);
           }
        }
     }

private:
   void AddFVG(FvgStruct &fvg)
     {
      m_total_fvgs++;
      ArrayResize(m_fvgs, m_total_fvgs);
      m_fvgs[m_total_fvgs-1] = fvg;
     }
     
   string GenerateName(ENUM_FVG_TYPE type, datetime time, string tf)
     {
      string prefix = (type == FVG_BULLISH) ? "BU-Fvg" : "BR-Fvg";
      MqlDateTime tm;
      TimeToStruct(time, tm);
      string datePart = StringFormat("%02d%02d%04d", tm.day, tm.mon, tm.year);
      string timePart = StringFormat("%02d:%02d", tm.hour, tm.min);
      
      return StringFormat("%s_%s-%s-%s", prefix, datePart, timePart, tf);
     }
     
   string TimeframeToString(ENUM_TIMEFRAMES tf)
     {
      string s = EnumToString(tf); // PERIOD_M1
      StringReplace(s, "PERIOD_", "");
      return s;
     }

   // Check if FVG was tapped in subsequent bars
   void CheckState(FvgStruct &fvg, const MqlRates &rates[], int total, int check_from_index)
     {
      // Default
      fvg.state = FVG_STATE_UNTAPPED;
      fvg.result = FVG_RESULT_NONE;
      
      for(int k=check_from_index; k<total; k++)
        {
         if(fvg.type == FVG_BULLISH)
           {
            if(rates[k].low <= fvg.topPrice)
              {
               fvg.state = FVG_STATE_TAPPED;
               fvg.result = FVG_RESULT_MISSED; // Assume missed if checking history
               fvg.tapTime = rates[k].time;
               return; // State final for now (simple logic)
              }
           }
         else // Bearish
           {
            if(rates[k].high >= fvg.bottomPrice)
              {
               fvg.state = FVG_STATE_TAPPED;
               fvg.result = FVG_RESULT_MISSED;
               fvg.tapTime = rates[k].time;
               return;
              }
           }
        }
     }
  };
//+------------------------------------------------------------------+
