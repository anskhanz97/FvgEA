//+------------------------------------------------------------------+
//|                                                      Structs.mqh |
//|                                                   Modular FVG EA |
//+------------------------------------------------------------------+
#property strict

#ifndef STRUCTS_MQH
#define STRUCTS_MQH

// FVG Type
enum ENUM_FVG_TYPE
  {
   FVG_BULLISH,
   FVG_BEARISH
  };

// FVG State
enum ENUM_FVG_STATE
  {
   FVG_STATE_UNTAPPED,    // Watching
   FVG_STATE_TOUCHED,     // Price inside (M1 inside M5)
   FVG_STATE_FILLED,      // Invalidated/Filled/Traded
   FVG_STATE_EXPIRED      // Too old
  };

// FVG Result
enum ENUM_FVG_RESULT
  {
   FVG_RESULT_NONE,
   FVG_RESULT_TRADED,
   FVG_RESULT_MISSED,
   FVG_RESULT_SL,
   FVG_RESULT_TP
  };

// Core FVG Data Structure
struct FvgStruct
  {
   string            name;             // ID
   
   // Time Info
   datetime          creationTime;     // Time of the defining 3rd candle close
   datetime          startTime;        // Time of the 1st candle
   ENUM_TIMEFRAMES   timeframe;        // M5 or M1
   
   // Price Info
   double            topPrice;
   double            bottomPrice;
   
   // Meta Info
   ENUM_FVG_TYPE     type;
   ENUM_FVG_STATE    state;
   
   // Filter Metrics
   double            candleBodySize;
   double            atrAtCreation;
   bool              isStructureValid; // Post-BOS/Sweep OK
   
   // Execution Tracking
   ulong             ticket;
   datetime          tapTime;
   
   // Constructor
   FvgStruct()
     {
      name = "";
      creationTime = 0;
      startTime = 0;
      timeframe = PERIOD_CURRENT;
      topPrice = 0;
      bottomPrice = 0;
      type = FVG_BULLISH;
      state = FVG_STATE_UNTAPPED;
      candleBodySize = 0;
      atrAtCreation = 0;
      isStructureValid = false;
      ticket = 0;
      tapTime = 0;
     }
  };
#endif
//+------------------------------------------------------------------+
