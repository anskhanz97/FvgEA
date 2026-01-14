//+------------------------------------------------------------------+
//|                                                  FvgDetector.mqh |
//|                                                   Modular FVG EA |
//+------------------------------------------------------------------+
#property strict
#include "Common.mqh"
#include "Config.mqh"

class CFvgDetector
  {
private:
   FvgStruct         m_fvgs[];
   int               m_total_fvgs;
   ENUM_TIMEFRAMES   m_timeframe;

public:
                     CFvgDetector(ENUM_TIMEFRAMES tf) 
                     { 
                        m_total_fvgs=0; 
                        m_timeframe = tf;
                     }
                    ~CFvgDetector() {}

   // Accessors
   int Count() { return m_total_fvgs; }
   
   void GetFVGs(FvgStruct &fvgs[])
     {
      ArrayResize(fvgs, m_total_fvgs);
      for(int i=0; i<m_total_fvgs; i++)
         fvgs[i] = m_fvgs[i];
     }
     
   FvgStruct GetFVG(int index) {
      if(index >=0 && index < m_total_fvgs) return m_fvgs[index];
      FvgStruct empty; return empty;
   }

   // Update FVG at index
   void UpdateFVG(int index, const FvgStruct &fvg)
     {
      if(index >= 0 && index < m_total_fvgs)
         m_fvgs[index] = fvg;
     }

   // Reset
   void Clear()
     {
      ArrayFree(m_fvgs);
      m_total_fvgs = 0;
     }

   // Core Detection Logic
   // Pass in rates specific to the timeframe of this detector
   void Detect(const MqlRates &rates[], int total_bars, int start_index)
     {
      // Ensure we have enough bars
      if(start_index < 0) start_index = 0;
      
      Logger.Debug("Detector", StringFormat("Scanning %s from index %d to %d", 
                  TimeframeToString(m_timeframe), start_index, total_bars-4));

      for(int i=start_index; i <= total_bars - 4; i++)
        {
         // i = Candle 1, i+2 = Candle 3 (Confirmation)
         // Logic: Gap between Candle 1 High/Low and Candle 3 Low/High
         
         bool found = false;
         FvgStruct fvg;
         
         // Bullish
         if(rates[i+2].low > rates[i].high)
           {
            fvg.type = FVG_BULLISH;
            fvg.topPrice = rates[i+2].low;    // Entry
            fvg.bottomPrice = rates[i].high;  // SL Ref
            found = true;
           }
         // Bearish
         else if(rates[i+2].high < rates[i].low)
           {
            fvg.type = FVG_BEARISH;
            fvg.topPrice = rates[i].low;      // SL Ref
            fvg.bottomPrice = rates[i+2].high; // Entry
            found = true;
           }
           
         if(found)
           {
            // Populate Common Data
            fvg.creationTime = rates[i+2].time;
            fvg.startTime = rates[i].time;
            fvg.timeframe = m_timeframe;
            fvg.name = GenerateName(fvg.type, fvg.creationTime);
            
            // Calculate Metrics
            fvg.candleBodySize = MathAbs(rates[i+1].close - rates[i+1].open);
            // ATR would need external calculation or passed in. 
            // For now, raw detection doesn't filter.
            
            Logger.Debug("Detector", StringFormat("FVG %s Found at %s. Range: %.5f - %.5f" + " [Already Tapped]", 
                        fvg.name, TimeToString(fvg.creationTime), fvg.bottomPrice, fvg.topPrice));
            
            // Initial State Check (History)
            CheckState(fvg, rates, total_bars, i+3);
            
            AddFVG(fvg);
           }
        }
     }

private:
   void AddFVG(FvgStruct &fvg)
     {
      // Avoid duplicates? Simple append for now.
      m_total_fvgs++;
      ArrayResize(m_fvgs, m_total_fvgs);
      m_fvgs[m_total_fvgs-1] = fvg;
     }
     
   string GenerateName(ENUM_FVG_TYPE type, datetime time)
     {
      string prefix = (type == FVG_BULLISH) ? "BU" : "BE"; // User requested 'BE' for Bearish (implied by BU/BE pattern in example?)
      // User example: BE-M5_13012026-06:20
      
      string tfStr = TimeframeToString(m_timeframe);
      MqlDateTime tm;
      TimeToStruct(time, tm);
      
      // Format: PREFIX-TF_DDMMYYYY-HH:MM
      return StringFormat("%s-%s_%02d%02d%04d-%02d:%02d", 
                          prefix, tfStr, tm.day, tm.mon, tm.year, tm.hour, tm.min);
     }
     
   string TimeframeToString(ENUM_TIMEFRAMES tf)
     {
      switch(tf)
      {
         case PERIOD_M1: return "M1";
         case PERIOD_M5: return "M5";
         case PERIOD_H1: return "H1";
         default: return "TF";
      }
     }

   void CheckState(FvgStruct &fvg, const MqlRates &rates[], int total, int check_from_index)
     {
      fvg.state = FVG_STATE_UNTAPPED;
      
      for(int k=check_from_index; k<total; k++)
        {
         if(fvg.type == FVG_BULLISH)
           {
            // 1. Check Invalidation (Close below Bottom)
            if(rates[k].close < fvg.bottomPrice)
              {
               fvg.state = FVG_STATE_EXPIRED; // Invalidated
               fvg.result = FVG_RESULT_NONE;
               // Even if it was tapped before, if it breaks now, it's dead context.
               // We stop tracking.
               return; 
              }
              
            // 2. Check Tap
            if(rates[k].low <= fvg.topPrice)
              {
               if(fvg.state == FVG_STATE_UNTAPPED)
                 {
                  fvg.state = FVG_STATE_TOUCHED;
                  fvg.tapTime = rates[k].time;
                  fvg.result = FVG_RESULT_MISSED; 
                 }
               // Continue tracking to see if it gets invalidated later
              }
           }
         else // Bearish
           {
            // 1. Check Invalidation (Close above Top)
            // Bearish TopPrice is the High of Candle 1 (SL Ref).
            if(rates[k].close > fvg.topPrice)
              {
               fvg.state = FVG_STATE_EXPIRED;
               fvg.result = FVG_RESULT_NONE;
               return;
              }
              
            // 2. Check Tap
            if(rates[k].high >= fvg.bottomPrice)
              {
               if(fvg.state == FVG_STATE_UNTAPPED)
                 {
                  fvg.state = FVG_STATE_TOUCHED;
                  fvg.tapTime = rates[k].time;
                  fvg.result = FVG_RESULT_MISSED;
                 }
              }
           }
        }
     }
  };
//+------------------------------------------------------------------+
