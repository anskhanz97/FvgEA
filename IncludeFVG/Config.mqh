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

input group " --- Execution Mode --- "
input bool        InpUseMtfExecution  = true;    // Use M1 Confirmation (MTF)
                                                 // False = Direct M5 Execution

input group " --- Filters: Candle Quality --- "
input bool        InpUseCandleQuality = true;    // Use Candle Quality Filter
input double      InpMinBodyRatio     = 0.3;     // Min Body/Range Ratio (0.3 = 30%)
input double      InpAvgBodyMult      = 1.0;     // Min Body relative to Avg (1.0 = Avg)

input group " --- Filters: Structure --- "
input bool        InpUseStructure     = true;    // Use Structure Filter (BOS/Sweep)
input int         InpStructLookback   = 50;      // Structure Lookback Bars

input group " --- Filters: Trend --- "
input bool        InpUseTrendFilt     = false;   // Use Trend Filter
input int         InpTrendEmaPeriod   = 50;      // EMA Period

input group " --- Filters: Volatility (ATR) --- "
input bool        InpUseAtrFilter     = false;   // Use ATR Filter
input int         InpAtrPeriod        = 14;      // ATR Period
input double      InpMinAtrPips       = 5.0;     // Min ATR (Pips)

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
   bool              UseMtfExecution;
   
   // Filter Settings
   bool              UseCandleQuality;
   double            MinBodyRatio;
   double            AvgBodyMult;
   
   bool              UseStructure;
   int               StructLookback;
   
   bool              UseTrendFilter;
   int               TrendEmaPeriod;
   
   bool              UseAtrFilter;
   int               AtrPeriod;
   double            MinAtrPips;
   
                     CConfig()
     {
      LotSize = InpLotSize;
      SLPips = InpSLPips;
      TPPips = InpTPPips;
      HistoryDays = InpHistoryDays;
      ColorUntapped = InpColorUntapped;
      ColorTapped = InpColorTapped;
      EntryMode = InpEntryMode;
      UseMtfExecution = InpUseMtfExecution;
      
      UseCandleQuality = InpUseCandleQuality;
      MinBodyRatio = InpMinBodyRatio;
      AvgBodyMult = InpAvgBodyMult;
      
      UseStructure = InpUseStructure;
      StructLookback = InpStructLookback;
      
      UseTrendFilter = InpUseTrendFilt;
      TrendEmaPeriod = InpTrendEmaPeriod;
      
      UseAtrFilter = InpUseAtrFilter;
      AtrPeriod = InpAtrPeriod;
      MinAtrPips = InpMinAtrPips;
      
      // Initialize Logger
      Logger.SetLevel(InpLogLevel);
     }
  };

CConfig Config;
//+------------------------------------------------------------------+
