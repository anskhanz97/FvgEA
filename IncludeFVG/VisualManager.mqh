//+------------------------------------------------------------------+
//|                                                VisualManager.mqh |
//|                                                   Modular FVG EA |
//+------------------------------------------------------------------+
#property strict
#include "Common.mqh"
#include "Config.mqh"

class CVisualManager
  {
public:
                     CVisualManager() {}
                    ~CVisualManager() {}

   void UpdateVisuals(const FvgStruct &fvg)
     {
      string ObjName = fvg.name;
      
      // If object doesn't exist, create it
      if(ObjectFind(0, ObjName) < 0)
        {
         ObjectCreate(0, ObjName, OBJ_RECTANGLE, 0, fvg.startTime, fvg.topPrice, fvg.creationTime, fvg.bottomPrice);
         
         ObjectSetInteger(0, ObjName, OBJPROP_FILL, false); // No Fill by default
         ObjectSetInteger(0, ObjName, OBJPROP_BACK, true);  // Background
         ObjectSetInteger(0, ObjName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, ObjName, OBJPROP_STYLE, STYLE_DOT); 
         
         // Distinction by Timeframe
         if(fvg.timeframe == PERIOD_M1)
           {
             // Overlap Trigger - Foreground
             ObjectSetInteger(0, ObjName, OBJPROP_STYLE, STYLE_DASH); 
             ObjectSetInteger(0, ObjName, OBJPROP_WIDTH, 1); 
             ObjectSetInteger(0, ObjName, OBJPROP_BACK, false); // Draw ON TOP of M5 Box
           }
         else
           {
             // M5 Context - Subtle
             ObjectSetInteger(0, ObjName, OBJPROP_STYLE, STYLE_DOT); 
             ObjectSetInteger(0, ObjName, OBJPROP_WIDTH, 1);
           }
        }
      
      // COLORS & EXTENSION
      if(fvg.timeframe == PERIOD_M1)
        {
         // M1 Colors (Active Triggers)
         color c = (fvg.type == FVG_BULLISH) ? clrLimeGreen : clrRed; // Hardcoded or Config? 
         // Use Config but maybe darker/brighter?
         ObjectSetInteger(0, ObjName, OBJPROP_COLOR, c);
         
         // Only extend if Untapped? M1 triggers behave same.
         ObjectSetInteger(0, ObjName, OBJPROP_RAY_RIGHT, (fvg.state == FVG_STATE_UNTAPPED));
         
         // If Filled (Ticket > 0), maybe change style to Solid to mark execution? 
         // Or keep dashed but maybe thicker? Let's keep it simple as requested.
         if(fvg.ticket > 0) ObjectSetInteger(0, ObjName, OBJPROP_WIDTH, 2);
        }
      else
        {
         // M5 Colors (Context)
         // Use Gray or similar to indicate "Zone"
         color c = clrDarkGray; // Context
         ObjectSetInteger(0, ObjName, OBJPROP_COLOR, c);
         
         // M5 extend until invalidated?
         // Ray Right to show the "Zone" persisting.
         ObjectSetInteger(0, ObjName, OBJPROP_RAY_RIGHT, true);
        }
        
      // Handle "Tapped/Closed" visual logic if needed (e.g. stop ray)
      if(fvg.state == FVG_STATE_TOUCHED || fvg.state == FVG_STATE_FILLED)
        {
         if(fvg.timeframe == PERIOD_M1)
            ObjectSetInteger(0, ObjName, OBJPROP_RAY_RIGHT, false);
         
         if(fvg.tapTime > 0)
            ObjectSetInteger(0, ObjName, OBJPROP_TIME, 1, fvg.tapTime);
        }
     }
     
   void ClearAll()
     {
      ObjectsDeleteAll(0, "BU-");
      ObjectsDeleteAll(0, "BR-");
     }
  };
//+------------------------------------------------------------------+
