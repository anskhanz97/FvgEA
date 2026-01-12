//+------------------------------------------------------------------+
//|                                                        FvgEA.mq5 |
//|                                                   Modular FVG EA |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Modular FVG EA"
#property link      ""
#property version   "1.00"

#include "IncludeFVG/Config.mqh"
#include "IncludeFVG/Common.mqh"
#include "IncludeFVG/FvgDetector.mqh"
#include "IncludeFVG/VisualManager.mqh"
#include "IncludeFVG/TradeManager.mqh"

// System Components
CFvgDetector   *Detector;
CVisualManager *Visuals;
CTradeManager  *Trader;

// State Vars
int            g_last_fvg_count = 0;
datetime       g_last_bar_time = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Initialize Components
   Detector = new CFvgDetector();
   Visuals = new CVisualManager();
   Trader = new CTradeManager();
   
   // --- Historical Scan ---
   Logger.Info("Starting Historical Scan...");
   
   // Calculate start index for N days ago
   int days = Config.HistoryDays;
   datetime start_time = TimeCurrent() - (days * PeriodSeconds(PERIOD_D1));
   int start_index = iBarShift(Symbol(), Period(), start_time);
   if(start_index == -1) start_index = Bars(Symbol(), Period()) - 1; // Max avail
   
   // Get Rates
   MqlRates rates[];
   ArraySetAsSeries(rates, false); // Oldest is 0
   int copied = CopyRates(Symbol(), Period(), 0, start_index + 10, rates);
   
   if(copied > 3)
     {
      // Detect from 0 (Oldest loaded)
      Detector.Detect(rates, copied, 0); 
      
      // Process Historical FVGs (Visuals Only)
      FvgStruct fvgs[];
      Detector.GetFVGs(fvgs);
      
      for(int i=0; i<ArraySize(fvgs); i++)
        {
         Visuals.UpdateVisuals(fvgs[i]);
        }
        
      g_last_fvg_count = ArraySize(fvgs); // Mark these as "Old"
      Logger.Info("Historical Scan Complete. Found: " + IntegerToString(g_last_fvg_count));
     }
   
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Visuals.ClearAll(); // Optional: Clean up on exit? User asked extended boxes. Maybe keep? 
   // Usually standard to clear. User: "keep extending...".
   // If we remove, we lose record. 
   // Strategy Tester cleans automatically. Live chart -> maybe nice to keep.
   // But standard practice is clean up. I'll call ClearAll.
   
   delete Detector;
   delete Visuals;
   delete Trader;
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Check New Bar
   datetime check_time = iTime(Symbol(), Period(), 0);
   bool isNewBar = (check_time != g_last_bar_time);
   
   if(isNewBar)
     {
      g_last_bar_time = check_time;
      
      // Load Rates (Need at least last few bars)
      MqlRates rates[];
      ArraySetAsSeries(rates, false);
      int lookback = 100; // Look back enough for recent pattern
      int copied = CopyRates(Symbol(), Period(), 0, lookback, rates);
      
      if(copied > 5)
        {
         // Start detection from recent bars.
         // We only want to process the *newly closed* bar as 'Candle 3'.
         // In array [0..99], 99 is current open bar. 98 is closed.
         // Candle 3 should be index 98.
         // Candle 2: 97. Candle 1: 96.
         // Detector Loop: i is Candle 1. i+2 is Candle 3.
         // If we want Candle 3 = 98 (latest closed), then i = 96.
         // Detect(..., 96). Loop runs for i=96.
         
         int start_node = copied - 4; // Verify math: Total=100. 96,97,98. 
         Detector.Detect(rates, copied, start_node);
        }
     }
     
   // --- Every Tick: Update States & Trades ---
   
   FvgStruct fvgs[];
   Detector.GetFVGs(fvgs);
   int total = ArraySize(fvgs);
   
   double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   
   for(int i=0; i<total; i++)
     {
      // Reference
      FvgStruct fvg = fvgs[i];
      bool changed = false;
      
      // 1. Process New items (Trade Placement)
      if(i >= g_last_fvg_count) 
        {
         // Only trade if Untapped
         if(fvg.state == FVG_STATE_UNTAPPED)
           {
            // Place Order
            ulong t = Trader.PlaceOrder(fvg);
            if(t > 0)
              {
               fvg.ticket = t;
               Detector.UpdateFVG(i, fvg); // Sync Ticket
              }
           }
         // Mark processed
         // Will happen at end of loop by updating g_last_fvg_count logic
        }
        
      // 2. Check for Tap (Live Visual Update)
      // Only for Untapped.
      if(fvg.state == FVG_STATE_UNTAPPED)
        {
         bool tapped = false;
         if(fvg.type == FVG_BULLISH)
           {
            if(bid <= fvg.topPrice) tapped = true; // Bid hits Limit Entry
           }
         else
           {
            if(ask >= fvg.bottomPrice) tapped = true;
           }
           
         if(tapped)
           {
            fvg.state = FVG_STATE_TAPPED;
            fvg.result = FVG_RESULT_TRADED; // It's live so we assume traded? Or check order?
            fvg.tapTime = TimeCurrent();
            Detector.UpdateFVG(i, fvg); // Sync State
            changed = true;
           }
        }
      
      // 4. Update Visuals
      if(changed || i >= g_last_fvg_count)
        {
         Visuals.UpdateVisuals(fvg);
        }
        
      // Save back if needed (conceptually)
      // For this turn, I will assume I add the Update method.
     }
     
   g_last_fvg_count = total;
  }
//+------------------------------------------------------------------+
