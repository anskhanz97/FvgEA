//+------------------------------------------------------------------+
//|                                                       Config.mqh |
//|                                                   Modular FVG EA |
//+------------------------------------------------------------------+
#property strict
#include "Logger.mqh"

// Inputs directly here or managed via a class
input group " --- Risk Settings --- "
input double      InpLotSize        = 0.01;        // Lot Size
input int         InpSLPips         = 30;          // Stop Loss (Pips)
input int         InpTPPips         = 30;          // Take Profit (Pips)

input group " --- FVG Settings --- "
input int         InpHistoryDays    = 7;           // History Scan (Days)
input color       InpColorUntapped  = clrBisque;   // Color: Untapped (Lighter)
input color       InpColorTapped    = clrPink;     // Color: Tapped / Traded (Lighter)

enum ENUM_FVG_ENTRY_MODE
  {
   ENTRY_MODE_PROXIMAL, // Proximal (Nearest Edge - Quick Fill)
   ENTRY_MODE_MIDPOINT, // Midpoint (50% of Gap)
   ENTRY_MODE_DISTAL    // Distal (Furthest Edge - Extreme Discount)
  };
  
input ENUM_FVG_ENTRY_MODE InpEntryMode = ENTRY_MODE_PROXIMAL; // Entry Mode

input group " --- Debug --- "
input ENUM_LOG_LEVEL InpLogLevel    = LOG_LEVEL_INFO; // Log Level

class CConfig
  {
public:
   double            LotSize;
   int               SLPips;
   int               TPPips;
   int               HistoryDays;
   color             ColorUntapped;
   color             ColorTapped;
   ENUM_FVG_ENTRY_MODE EntryMode;
   
                     CConfig()
     {
      LotSize = InpLotSize;
      SLPips = InpSLPips;
      TPPips = InpTPPips;
      HistoryDays = InpHistoryDays;
      ColorUntapped = InpColorUntapped;
      ColorTapped = InpColorTapped;
      EntryMode = InpEntryMode;
      
      // Initialize Logger
      Logger.SetLevel(InpLogLevel);
     }
  };

CConfig Config;
//+------------------------------------------------------------------+
