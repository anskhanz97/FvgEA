//+------------------------------------------------------------------+
//|                                                       Logger.mqh |
//|                                                   Modular FVG EA |
//+------------------------------------------------------------------+
#property strict
#ifndef LOGGER_MQH
#define LOGGER_MQH

enum ENUM_LOG_LEVEL
  {
   LOG_LEVEL_DEBUG = 0,
   LOG_LEVEL_INFO  = 1,
   LOG_LEVEL_ERROR = 2
  };

class CLogger
  {
private:
   ENUM_LOG_LEVEL    m_level;

public:
                     CLogger(void) { m_level = LOG_LEVEL_INFO; }
                    ~CLogger(void) {}

   void              SetLevel(ENUM_LOG_LEVEL level) { m_level = level; }

   // Basic Log with Tag
   void Log(string tag, string msg)
     {
      PrintFormat("[%s] %s", tag, msg);
     }

   // Detailed Info
   void Info(string source, string msg)
     {
      if(m_level <= LOG_LEVEL_INFO)
         PrintFormat("[INFO][%s] %s", source, msg);
     }

   // Debug for granular tracing
   void Debug(string source, string msg)
     {
      if(m_level <= LOG_LEVEL_DEBUG)
         PrintFormat("[DEBUG][%s] %s", source, msg);
     }
     
   // Overload for numeric debug
   void DebugVal(string source, string msg, double val)
     {
      if(m_level <= LOG_LEVEL_DEBUG)
         PrintFormat("[DEBUG][%s] %s: %.5f", source, msg, val);
     }

   // Error tracking
   void Error(string source, string msg)
     {
      PrintFormat("[ERROR][%s] %s", source, msg);
     }
  };

// Global Logger Instance
CLogger Logger;
#endif
//+------------------------------------------------------------------+
