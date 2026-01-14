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
       // Sync to ALL charts of the same symbol (User Request)
       long chartId = ChartFirst();
       while(chartId >= 0)
         {
          if(ChartSymbol(chartId) == Symbol())
            {
             DrawOnChart(chartId, fvg);
            }
          chartId = ChartNext(chartId);
         }
      }
      
    private:
    void DrawOnChart(long chartId, const FvgStruct &fvg)
      {
       string ObjName = fvg.name;
       
       if(ObjectFind(chartId, ObjName) < 0)
         {
          ObjectCreate(chartId, ObjName, OBJ_RECTANGLE, 0, fvg.startTime, fvg.topPrice, fvg.creationTime, fvg.bottomPrice);
          ObjectSetInteger(chartId, ObjName, OBJPROP_FILL, false);
          ObjectSetInteger(chartId, ObjName, OBJPROP_BACK, true);
          ObjectSetInteger(chartId, ObjName, OBJPROP_STYLE, STYLE_DOT);
          
          if(fvg.timeframe == PERIOD_M1)
            {
             ObjectSetInteger(chartId, ObjName, OBJPROP_STYLE, STYLE_DASH);
             ObjectSetInteger(chartId, ObjName, OBJPROP_BACK, false);
            }
         }
         
       // Update State Colors / Ray
       if(fvg.timeframe == PERIOD_M1)
         {
          color c = (fvg.type == FVG_BULLISH) ? clrLimeGreen : clrRed;
          ObjectSetInteger(chartId, ObjName, OBJPROP_COLOR, c);
          
          bool stopM1 = (fvg.state == FVG_STATE_TOUCHED || fvg.state == FVG_STATE_FILLED || fvg.state == FVG_STATE_EXPIRED);
          ObjectSetInteger(chartId, ObjName, OBJPROP_RAY_RIGHT, !stopM1);
          
          if(stopM1 && fvg.tapTime > 0)
             ObjectSetInteger(chartId, ObjName, OBJPROP_TIME, 1, fvg.tapTime);
             
          if(fvg.ticket > 0) ObjectSetInteger(chartId, ObjName, OBJPROP_WIDTH, 2);
         }
       else
         {
          // M5 Context Colors
          ObjectSetInteger(chartId, ObjName, OBJPROP_COLOR, clrDarkGray);
          
          // RAY LOGIC (User Request)
          bool stopM5 = false;
          if(Config.UseMtfExecution)
            {
             // MTF Mode: Only stop if Traded (FILLED) or Invalid (EXPIRED)
             if(fvg.state == FVG_STATE_FILLED || fvg.state == FVG_STATE_EXPIRED) stopM5 = true;
            }
          else
            {
             // Direct Mode: Stop on Touch, Fill, or Expire
             if(fvg.state == FVG_STATE_TOUCHED || fvg.state == FVG_STATE_FILLED || fvg.state == FVG_STATE_EXPIRED) stopM5 = true;
            }
            
          ObjectSetInteger(chartId, ObjName, OBJPROP_RAY_RIGHT, !stopM5);
          
          if(stopM5 && fvg.tapTime > 0)
             ObjectSetInteger(chartId, ObjName, OBJPROP_TIME, 1, fvg.tapTime);
         }
      }
      
    public:
     
   void ClearAll()
     {
      ObjectsDeleteAll(0, "BU-");
      ObjectsDeleteAll(0, "BR-");
     }
  };
//+------------------------------------------------------------------+
