//+------------------------------------------------------------------+
//|                                                        FvgEA.mq5 |
//|                                                   Modular FVG EA |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Modular FVG EA"
#property link      ""
#property version   "2.00"

#include "IncludeFVG/Config.mqh"
#include "IncludeFVG/Common.mqh"
#include "IncludeFVG/FvgDetector.mqh"
#include "IncludeFVG/VisualManager.mqh"
#include "IncludeFVG/TradeManager.mqh"
#include "IncludeFVG/ExecutionEngine.mqh"
#include "IncludeFVG/MarketInfo.mqh"

// System Components
CFvgDetector     *DetectorM5; // Macro
CFvgDetector     *DetectorM1; // Micro
CVisualManager   *Visuals;
CTradeManager    *Trader;
CExecutionEngine *Engine;

// State Vars
datetime g_last_m5_time = 0;
datetime g_last_m1_time = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Validate Chart
   if(Period() != PERIOD_M1)
     {
      Alert("EA must be attached to M1 Chart!");
      // return INIT_FAILED; // Allow debug for now but warn
     }

   // Initialize Components
   DetectorM5 = new CFvgDetector(PERIOD_M5);
   DetectorM1 = new CFvgDetector(PERIOD_M1);
   Visuals = new CVisualManager();
   Trader = new CTradeManager();
   Engine = new CExecutionEngine();
   
   Logger.SetLevel(LOG_LEVEL_DEBUG); // As requested by user for detailed logs
   Logger.Info("Init", "Multi-Timeframe FVG EA Started. 2 Modes-  1- M5 or 2- M5 Context / M1 Execution.");
   Config.LogSettings();
   
   // --- Historical Scan (Optional, mostly for Visual Context) ---
   // We scan M5 history to populate 'Context' list
   
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   delete DetectorM5;
   delete DetectorM1;
   delete Visuals;
   delete Trader;
   delete Engine;
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // 1. Check M5 Context (Update roughly every M5 bar or check close)
   // We use iTime to detect new bar ON M5 from M1 Chart
   datetime currentM5 = iTime(Symbol(), PERIOD_M5, 0);
   if(currentM5 != g_last_m5_time)
     {
      g_last_m5_time = currentM5;
      
      // Update M5 Context
      UpdateM5Context();
     }
     
   // 2. Check M1 Execution (Every M1 Bar)
   datetime currentM1 = iTime(Symbol(), PERIOD_M1, 0);
   if(currentM1 != g_last_m1_time)
     {
      g_last_m1_time = currentM1;
      
      // Update M1 Candidates and Check Triggers (Only if MTF Enabled)
      if(Config.UseMtfExecution)
        {
         CheckTriggers();
        }
     }
  }

//+------------------------------------------------------------------+
//| Helper: Update M5 Context                                        |
//+------------------------------------------------------------------+
void UpdateM5Context()
  {
   // 1. Get Rates
   MqlRates rates[];
   int count = 200; // Scan last 200 M5 bars
   int copied = CMarketInfo::GetRates(Symbol(), PERIOD_M5, count, rates);
   
   if(copied > 5)
     {
      // 2. Reset Detector (to avoid duplicates if we rescan full list)
      DetectorM5.Clear(); 
      DetectorM5.Detect(rates, copied, 0);
      
      // 3. Get Candidates
      FvgStruct candidates[];
      DetectorM5.GetFVGs(candidates);
      
      // 4. Validate Candidates (Structure, Filters)
      // This implementation passes ALL candidates to Engine, 
      // but ideally we filter here or inside Engine.
      // Let's Filter here to respect the strict logic.
      
      FvgStruct validFvgs[];
      int vCount = 0;
      
      for(int i=0; i<ArraySize(candidates); i++)
        {
         FvgStruct f = candidates[i];
         
         // A. Candle Quality (using index from rates? We need index in 'rates' array)
         // The Detector doesn't store 'index', it stores Time.
         // We need to find index in 'rates' or modify Detector to store index relative to batch.
         // Easier: Use Time to find index in 'rates'
         int idx = -1;
         // Reverse search or assume order. Rates are [0..N-1]. 
         // f.creationTime is time of Candle 3.
         for(int k=0; k<copied; k++) { if(rates[k].time == f.creationTime) { idx=k; break; } }
         
         // Check index validity
         if(idx == -1) continue;
         int dispIdx = idx - 1; // Candle 2 (Displacement)
         
         // VISUALIZE ALL CANDIDATES (For Testing Phase)
         Visuals.UpdateVisuals(f);
         
         // ---------------- FILTERS ----------------
         
         // 2. Candle Quality Filter
         if(Config.UseCandleQuality)
           {
            if(!CFilters::IsCandleQuality(rates, dispIdx, f.name, Config.MinBodyRatio, Config.AvgBodyMult)) continue;
           }
         
         // 3. Trend Filter
         if(Config.UseTrendFilter)
           {
            if(!CFilters::IsTrendAligned(rates, idx, Config.TrendEmaPeriod, f.type)) 
              {
               Logger.Debug("Main", "M5 FVG Rejected by Trend: " + f.name);
               continue;
              }
           }
           
         // 4. Volatility Filter (ATR)
         if(Config.UseAtrFilter)
           {
            // Note: InpMinAtrPips is in PIPS. convert to Price.
            // Assumption: Symbol Point = 0.00001 (5 digits) -> Pip = 10 Points.
            // Or Symbol Point = 0.01 (JPY).
            // Safer: Point() * 10 * MinPips
            double minRange = SymbolInfoDouble(Symbol(), SYMBOL_POINT) * 10 * Config.MinAtrPips;
            if(!CFilters::IsVolatilityValid(rates, idx, Config.AtrPeriod, minRange, f.name)) continue;
           }
         
         // 5. Structure Filter (BOS/Sweep)
         if(Config.UseStructure)
           {
            if(!CStructure::CheckContext(rates, idx, f.type, f.name, Config.StructLookback)) 
              {
               Logger.Debug("Main", "M5 FVG Rejected by Structure: " + f.name);
               continue;
              }
           }
           
         // Accepted for Execution
         ArrayResize(validFvgs, vCount+1);
         validFvgs[vCount] = f;
         vCount++; 
         
         // ---------------- EXECUTION LOGIC ----------------
         
         // If Direct M5 Execution (No MTF)
         if(!Config.UseMtfExecution)
           {
             // Make sure we haven't traded this yet
             // Check local ticket or state
             if(f.ticket == 0 && f.state == FVG_STATE_UNTAPPED)
               {
                ulong ticket = Trader.PlaceOrder(f);
                if(ticket > 0)
                  {
                   f.ticket = ticket;
                   f.state = FVG_STATE_FILLED; // Mark as handled
                   f.result = FVG_RESULT_TRADED;
                   
                   // Update the source in Detector so we don't re-fire next tick
                   DetectorM5.UpdateFVG(i, f);
                   
                   Logger.Info("Main", "Direct M5 Execution for " + f.name);
                  }
               }
           } 
        }
      
      // Sync with MT5 History (Mark already traded)
      Trader.SyncFvgStates(validFvgs);
      
      // 5. Update Engine
      Engine.UpdateContext(validFvgs);
     }
  }

//+------------------------------------------------------------------+
//| Helper: Check M1 Triggers                                        |
//+------------------------------------------------------------------+
void CheckTriggers()
  {
   // 1. Get M1 Rates
   MqlRates rates[];
   int count = 50; // Short lookback
   int copied = CMarketInfo::GetRates(Symbol(), PERIOD_M1, count, rates);
   
   if(copied > 5)
     {
      DetectorM1.Clear();
      DetectorM1.Detect(rates, copied, 0);
      
      FvgStruct m1_fvgs[];
      DetectorM1.GetFVGs(m1_fvgs);
      
      // 2. Pass to Engine for Intersection Check
      Engine.ProcessTriggers(m1_fvgs, Trader);
      
      // 3. Visuals for M1 (Optional, maybe only show Traded ones?)
      // User: "prioritize only those which overlap... displayed inside"
      // Detailed logic: Only draw IF inside M5.
      // Current ProcessTriggers marks them as FILLED triggers or similar?
      // Visuals can be handled here if we check status.
      for(int i=0; i<ArraySize(m1_fvgs); i++)
        {
         // If "Ticket > 0" or we can add a flag "IsOverlapping"
         if(m1_fvgs[i].ticket > 0) // Traded / Valid
           {
            Visuals.UpdateVisuals(m1_fvgs[i]);
           }
        }
     }
  }
//+------------------------------------------------------------------+
