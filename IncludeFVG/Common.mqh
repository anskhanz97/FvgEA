//+------------------------------------------------------------------+
//|                                                       Common.mqh |
//|                                                   Modular FVG EA |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Modular FVG EA"
#property link      ""
#property strict

// FVG Type Enum
enum ENUM_FVG_TYPE
  {
   FVG_BULLISH, // Bullish FVG
   FVG_BEARISH  // Bearish FVG
  };

// FVG State Enum
enum ENUM_FVG_STATE
  {
   FVG_STATE_UNTAPPED, // Fresh, Waiting for price
   FVG_STATE_TAPPED    // Price touched the zone
  };

// FVG Result Enum (Sub-state for Tapped)
enum ENUM_FVG_RESULT
  {
   FVG_RESULT_NONE,    // Not applicable (Untapped)
   FVG_RESULT_TRADED,  // Tapped and Trade taken (Live)
   FVG_RESULT_MISSED   // Tapped in history (No trade)
  };

// Main FVG Structure
struct FvgStruct
  {
   string            name;             // Unique ID: BU-Fvg_Date-Time
   datetime          creationTime;     // Time of the 3rd candle
   datetime          startTime;        // Time of the 1st candle (Start of Box)
   string            timeframe;        // Timeframe string (e.g. "M1")
   
   double            topPrice;         // Upper boundary of Gap
   double            bottomPrice;      // Lower boundary of Gap
   
   ENUM_FVG_TYPE     type;             // Bullish or Bearish
   ENUM_FVG_STATE    state;            // Untapped or Tapped
   ENUM_FVG_RESULT   result;           // Traded or Missed
   
   // Order tracking
   ulong             ticket;           // Associated Pending Order Ticket
   datetime          tapTime;          // Time when FVG was tapped
   
   // Constructor
   FvgStruct()
     {
      name="";
      creationTime=0;
      startTime=0;
      topPrice=0.0;
      bottomPrice=0.0;
      state=FVG_STATE_UNTAPPED;
      result=FVG_RESULT_NONE;
      ticket=0;
      tapTime=0;
     }
  };
//+------------------------------------------------------------------+
