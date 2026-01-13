//+------------------------------------------------------------------+
//|                                                 TradeManager.mqh |
//|                                                   Modular FVG EA |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
#include "Common.mqh"
#include "Config.mqh"
#include "Logger.mqh"

class CTradeManager
  {
private:
   CTrade            m_trade;

   // Helper to get Pip Coin Value (Approximation)
   double GetPipPoint()
     {
      int digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
      double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
      
      // Check for XAU/Gold specifically for 3-digit brokers
      string sym = Symbol();
      if(StringFind(sym, "XAU") >= 0 || StringFind(sym, "GOLD") >= 0)
        {
         if(digits == 3) return point * 100; // 0.001 * 100 = 0.10
         if(digits == 2) return point * 10;  // 0.01 * 10 = 0.10
        }
        
      // JPY pairs (3 digits) -> 0.01 pip (10 points)
      if(digits == 3 || digits == 5) return point * 10;
      if(digits == 2 || digits == 4) return point; // Standard/Old
      
      return point;
     }

public:
                     CTradeManager()
     {
      m_trade.SetMarginMode();
      m_trade.SetTypeFillingBySymbol(Symbol());
      m_trade.LogLevel(LOG_LEVEL_ERRORS);
     }
                    ~CTradeManager() {}

   // Place Limit Order for FVG
   // Returns Ticket ID or 0 if failed
   ulong PlaceOrder(FvgStruct &fvg)
     {
      // Basic checks
      if(fvg.state != FVG_STATE_UNTAPPED) return 0;
      if(fvg.ticket > 0) return fvg.ticket; // Already placed
      
      ulong fvgMagic = (ulong)fvg.creationTime;
      m_trade.SetExpertMagicNumber(fvgMagic);
      
      int digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
      double pipVal = GetPipPoint(); 
      
      // Prices
      double entryPrice = 0.0;
      double slPrice = 0.0;
      double tpPrice = 0.0;
      
      string typeStr = "";
      
      if(fvg.type == FVG_BULLISH)
        {
         typeStr = "BUY LIMIT";
         
         // Calculate Entry based on Mode
         double baseEntry = fvg.topPrice; // Proximal (Default)
         
         if(Config.EntryMode == ENTRY_MODE_MIDPOINT)
            baseEntry = (fvg.topPrice + fvg.bottomPrice) / 2.0;
         else if(Config.EntryMode == ENTRY_MODE_DISTAL)
            baseEntry = fvg.bottomPrice; // Extreme (Candle 1 High)
            
         entryPrice = NormalizeDouble(baseEntry, digits);
         
         // SL: 30 pips below Low of FVG (Distal Edge)
         // Usually SL reference is always the invalidation point (Distal).
         // If we enter at Distal, SL is 30 pips below it.
         // If we enter at Proximal, SL is 30 pips below Distal (Wide SL).
         // Formula: Distal - Buffer.
         slPrice = NormalizeDouble(fvg.bottomPrice - (Config.SLPips * pipVal), digits);
            
         if(Config.TPPips > 0)
            tpPrice = NormalizeDouble(entryPrice + (Config.TPPips * pipVal), digits);
            
         if(!CheckContext(entryPrice, ORDER_TYPE_BUY_LIMIT)) return 0;

         if(m_trade.BuyLimit(Config.LotSize, entryPrice, Symbol(), slPrice, tpPrice, ORDER_TIME_GTC, 0, fvg.name))
           {
             ulong ticket = m_trade.ResultOrder();
             Logger.Info("TradeManager", StringFormat("Order Placed | Ticket: %I64u | Magic: %I64u | Type: %s | Price: %.5f | SL: %.5f | TP: %.5f", 
                                      ticket, fvgMagic, typeStr, entryPrice, slPrice, tpPrice));
             return ticket;
           }
        }
      else // Bearish
        {
         typeStr = "SELL LIMIT";
         
         double baseEntry = fvg.bottomPrice; // Proximal (Default)
         
         if(Config.EntryMode == ENTRY_MODE_MIDPOINT)
             baseEntry = (fvg.topPrice + fvg.bottomPrice) / 2.0;
         else if(Config.EntryMode == ENTRY_MODE_DISTAL)
             baseEntry = fvg.topPrice; // Extreme (Candle 1 Low)
             
         entryPrice = NormalizeDouble(baseEntry, digits);
         
         // SL: 30 pips above High of FVG (Distal Edge)
         slPrice = NormalizeDouble(fvg.topPrice + (Config.SLPips * pipVal), digits);
            
         if(Config.TPPips > 0)
            tpPrice = NormalizeDouble(entryPrice - (Config.TPPips * pipVal), digits);

         if(!CheckContext(entryPrice, ORDER_TYPE_SELL_LIMIT)) return 0;

         if(m_trade.SellLimit(Config.LotSize, entryPrice, Symbol(), slPrice, tpPrice, ORDER_TIME_GTC, 0, fvg.name))
           {
             ulong ticket = m_trade.ResultOrder();
             Logger.Info("TradeManager", StringFormat("Order Placed | Ticket: %I64u | Magic: %I64u | Type: %s | Price: %.5f | SL: %.5f | TP: %.5f", 
                                      ticket, fvgMagic, typeStr, entryPrice, slPrice, tpPrice));
             return ticket;
           }
        }
        
      // If we are here, it failed
      uint err = m_trade.ResultRetcode();
      string desc = m_trade.ResultRetcodeDescription();
      double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
      double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
      int stopLevel = (int)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);
      int freezeLevel = (int)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_FREEZE_LEVEL); 
      
      Logger.Error("TradeManager", StringFormat("Order FAILED | Type: %s | Price: %.5f | Ask: %.5f | Bid: %.5f | StopLvl: %d | Err: %u (%s)", 
                                typeStr, entryPrice, ask, bid, stopLevel, err, desc));
      return 0;
     }

private:
   // Pre-Check Validity
   bool CheckContext(double entryPrice, ENUM_ORDER_TYPE type)
     {
      double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
      double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
      double stopsLevel = SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(Symbol(), SYMBOL_POINT);
      
      if(type == ORDER_TYPE_BUY_LIMIT)
        {
         // Buy Limit must be below Ask? technically below current market price.
         // MT5: Buy Limit price must be < Ask.
         // And distance > StopsLevel.
         if(entryPrice >= ask) 
            {
             Logger.Info("TradeManager", StringFormat("Skipping Buy Limit: Price %.5f is >= Ask %.5f (Market is below Entry)", entryPrice, ask));
             return false;
            }
         if(ask - entryPrice < stopsLevel)
           {
             Logger.Info("TradeManager", StringFormat("Skipping Buy Limit: Price %.5f too close to Ask %.5f (Dist < StopLevel %.5f)", entryPrice, ask, stopsLevel));
             return false;
           }
        }
      else if(type == ORDER_TYPE_SELL_LIMIT)
        {
         // Sell Limit must be above Bid.
         if(entryPrice <= bid)
           {
            Logger.Info("TradeManager", StringFormat("Skipping Sell Limit: Price %.5f is <= Bid %.5f (Market is above Entry)", entryPrice, bid));
            return false;
           }
         if(entryPrice - bid < stopsLevel)
           {
             Logger.Info("TradeManager", StringFormat("Skipping Sell Limit: Price %.5f too close to Bid %.5f (Dist < StopLevel %.5f)", entryPrice, bid, stopsLevel));
             return false;
           }
        }
      return true;
     }
  };
//+------------------------------------------------------------------+
