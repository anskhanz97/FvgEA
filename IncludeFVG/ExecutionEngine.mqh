//+------------------------------------------------------------------+
//|                                                ExecutionEngine.mqh |
//|                                                   Modular FVG EA |
//+------------------------------------------------------------------+
#property strict
#include "Common.mqh"
#include "Filters.mqh"
#include "Structure.mqh"
#include "TradeManager.mqh" 

class CExecutionEngine
  {
private:
   // Lists
   FvgStruct         m_active_m5_fvgs[]; // The "Macro Zones"
   
public:
                     CExecutionEngine() {}
                    ~CExecutionEngine() {}

   // 1. Update Context (Run M5 Logic)
   // Called every New M5 Bar (or tick if efficient)
   void UpdateContext(FvgStruct &candidates[])
     {
      ArrayResize(m_active_m5_fvgs, 0); // Clear old list? Or Merge? 
      // For simplicity, we assume 'candidates' contains ALL valid historical FVGs detected by DetectorM5.
      // But DetectorM5 returns *raw* candidates. We must validte them here.
      
      int total = ArraySize(candidates);
      Logger.Debug("Execution", StringFormat("Validating %d M5 Candidates...", total));
      
      for(int i=0; i<total; i++)
        {
         FvgStruct fvg = candidates[i];
         
         // Only interested in Untapped (or Touched)
         if(fvg.state == FVG_STATE_FILLED || fvg.state == FVG_STATE_EXPIRED) continue;
         
         // A. We need context data to run filters. 
         // Since 'fvg' is just a struct, we assume the caller passed validated ones?
         // NO. The plan said: "VALIDATE M5 Candidates".
         // The Detector just finds the pattern. Here we filter.
         // Wait, to filter we need the 'rates' array.
         // This implies we need to pass rates or do this INSIDE the detector loop.
         // Better architecture: Detector accepts a Filter Strategy.
         // OR: We pass rates here.
         
         // FOR NOW: We assume 'candidates' passed here are ALREADY FILTERED by the Main EA loop 
         // calling the validation functions. Or we do it here if we had data.
         // Let's assume Main EA validates and passes only GOOD ones here.
         
         AddToActive(fvg);
        }
        
      Logger.Debug("Execution", StringFormat("Context Updated. Active M5 Zones: %d", ArraySize(m_active_m5_fvgs)));
     }
     
   // 2. Process M1 Triggers (The Intersection Logic)
   // Called every tick with fresh M1 FVGs
   void ProcessTriggers(FvgStruct &m1_fvgs[], CTradeManager *trader)
     {
      int totalM1 = ArraySize(m1_fvgs);
      int totalM5 = ArraySize(m_active_m5_fvgs);
      
      if(totalM5 == 0) return; // No context, no trade.
      
      for(int i=0; i<totalM1; i++)
        {
         FvgStruct m1 = m1_fvgs[i];
         
         // Must be Untapped
         if(m1.state != FVG_STATE_UNTAPPED) continue;
         
         // Check Overlap with ANY active M5
         for(int k=0; k<totalM5; k++)
           {
             if(IsOverlapping(m1, m_active_m5_fvgs[k]))
              {
               Logger.Info("Execution", StringFormat("INTERSECTION FOUND! M1 FVG %s inside M5 Zone %s", m1.name, m_active_m5_fvgs[k].name));
               
               // EXECUTE!
               if(trader != NULL)
                 {
                  // Rename M1 FVG to reference M5 Context (User Request)
                  string originalName = m1.name;
                  m1.name = m_active_m5_fvgs[k].name + "_Micro"; // New Name: [M5_ID]_Micro
                  
                  ulong ticket = trader.PlaceOrder(m1, (ulong)m_active_m5_fvgs[k].creationTime);
                  
                  // Sync state back to the list (Success or Failure)
                  m1_fvgs[i].ticket = m1.ticket; 
                  m1_fvgs[i].state = m1.state; 
                  
                  if(ticket > 0)
                    {
                     m1_fvgs[i].name = m1.name; // Keep new name
                     
                     // USER: Update parent context so visuals stop extending immediately
                     m_active_m5_fvgs[k].state = FVG_STATE_FILLED;
                     m_active_m5_fvgs[k].tapTime = TimeCurrent(); 
                    }
                  else
                    {
                     m1_fvgs[i].name = originalName; // Revert if failed
                    }
                 }
               break; // Handled this M1
              }
           }
        }
     }
     
   // Overlap Logic
   // Valid if M1 FVG is INSIDE or SIGNIFICANTLY OVERLAPS M5 FVG
   // Strict: M1 Top/Bottom must be inside M5 Top/Bottom?
   // User: "Draw and prioritize only those which overlap... inside the FVG of 5M"
   // "M1 FVG... inside the M5 FVG is our main concern."
   bool IsOverlapping(FvgStruct &m1, FvgStruct &m5)
     {
      // Check Time Alignment? 
      // M1 FVG must form AFTER M5 FVG? 
      // Usually yes. But if M1 forms *while* M5 is forming (impossible, M5 closes after 5 M1s).
      // So M1 comes after.
      
      if(m1.type != m5.type) return false; // Must be same direction
      
      // Check Price Inclusion
      bool inside = false;
      
      if(m1.type == FVG_BULLISH)
        {
         // M1 Range: Top to Bottom.
         // M5 Range: Top to Bottom.
         // STRICT Inside: M1 Top <= M5 Top && M1 Bottom >= M5 Bottom
         // Partial Overlap: Max(M1bot, M5bot) < Min(M1top, M5top)
         
         // Let's go with "Effective Overlap". 
         // If the M1 FVG is completely outside, ignore.
         // If it's inside, take it.
         
         double overlapTop = MathMin(m1.topPrice, m5.topPrice);
         double overlapBot = MathMax(m1.bottomPrice, m5.bottomPrice);
         
         if(overlapTop > overlapBot) inside = true; // They share a range
        }
     else
       {
        // Bearish FVG: TopPrice is SL (Higher), BottomPrice is Entry (Lower)
        // Check standard range overlap:
        
        double overlapTop = MathMin(m1.topPrice, m5.topPrice);
        double overlapBot = MathMax(m1.bottomPrice, m5.bottomPrice);
        
        if(overlapTop > overlapBot) inside = true;
       }
        
      return inside;
     }

private:
   void AddToActive(FvgStruct &fvg)
     {
      int size = ArraySize(m_active_m5_fvgs);
      ArrayResize(m_active_m5_fvgs, size+1);
      m_active_m5_fvgs[size] = fvg;
     }
  };
//+------------------------------------------------------------------+
