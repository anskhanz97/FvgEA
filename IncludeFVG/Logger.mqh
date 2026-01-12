//+------------------------------------------------------------------+
//|                                                       Logger.mqh |
//|                                                   Modular FVG EA |
//+------------------------------------------------------------------+
#property strict

enum ENUM_LOG_LEVEL
  {
   LOG_LEVEL_INFO,
   LOG_LEVEL_DEBUG,
   LOG_LEVEL_ERROR
  };

class CLogger
  {
private:
   ENUM_LOG_LEVEL    m_level;

public:
                     CLogger(void) { m_level = LOG_LEVEL_INFO; }
                    ~CLogger(void) {}

   void              SetLevel(ENUM_LOG_LEVEL level) { m_level = level; }

   void              Info(string msg)
     {
      if(m_level <= LOG_LEVEL_INFO)
         Print("[INFO] ", msg);
     }

   void              Debug(string msg)
     {
      if(m_level <= LOG_LEVEL_DEBUG)
         Print("[DEBUG] ", msg);
     }

   void              Error(string msg)
     {
      if(m_level <= LOG_LEVEL_ERROR)
         Print("[ERROR] ", msg);
     }
  };

// Global Logger Instance
CLogger Logger;
//+------------------------------------------------------------------+
