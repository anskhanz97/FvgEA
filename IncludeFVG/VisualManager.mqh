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
         // Start from fvg.startTime (Candle 1) instead of creationTime
         ObjectCreate(0, ObjName, OBJ_RECTANGLE, 0, fvg.startTime, fvg.topPrice, fvg.creationTime, fvg.bottomPrice);
         
         // User Request: "Box should be empty only boundary walls"
         ObjectSetInteger(0, ObjName, OBJPROP_FILL, false); // No Fill
         ObjectSetInteger(0, ObjName, OBJPROP_BACK, true);  // Background
         ObjectSetInteger(0, ObjName, OBJPROP_WIDTH, 1);    // Thin border
         ObjectSetInteger(0, ObjName, OBJPROP_STYLE, STYLE_DOT); // Dotted lines
        }
      
      // Update properties based on state
      if(fvg.state == FVG_STATE_UNTAPPED)
        {
         ObjectSetInteger(0, ObjName, OBJPROP_COLOR, Config.ColorUntapped);
         ObjectSetInteger(0, ObjName, OBJPROP_RAY_RIGHT, true); // Extend indefinitely
        }
      else if(fvg.state == FVG_STATE_TAPPED)
        {
         ObjectSetInteger(0, ObjName, OBJPROP_COLOR, Config.ColorTapped);
         ObjectSetInteger(0, ObjName, OBJPROP_RAY_RIGHT, false); // Stop extending
         
         // Set Right Time to Tap Time
         if(fvg.tapTime > 0)
            ObjectSetInteger(0, ObjName, OBJPROP_TIME, 1, fvg.tapTime);
         else
            ObjectSetInteger(0, ObjName, OBJPROP_TIME, 1, TimeCurrent()); // Fallback
        }
     }
     
   void ClearAll()
     {
      ObjectsDeleteAll(0, "BU-Fvg_");
      ObjectsDeleteAll(0, "BR-Fvg_");
     }
  };
//+------------------------------------------------------------------+
