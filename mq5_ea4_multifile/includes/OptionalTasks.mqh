//+------------------------------------------------------------------+
//| OptionalTasks.mqh                                                |
//| Optional functionality - trade logging, analysis, etc.          |
//+------------------------------------------------------------------+

//============================= TRADE LOGGING =======================//

string g_currentLogFile = "";  // Current log file path

// Initialize log file for the day
void InitializeTradeLog() {
   if(!g_tradeLoggingActive) return;  // Check runtime state
   
   MqlDateTime dt;
   TimeCurrent(dt);
   
   string fileName = StringFormat("TradeLog_%s_%d_%04d-%02d-%02d.csv", 
                                   _Symbol, Magic, dt.year, dt.mon, dt.day);
   
   g_currentLogFile = fileName;
   
   // Check if file exists, if not create with headers
   int fileHandle = FileOpen(fileName, FILE_READ|FILE_CSV|FILE_COMMON);
   if(fileHandle == INVALID_HANDLE) {
      // File doesn't exist, create with headers
      fileHandle = FileOpen(fileName, FILE_WRITE|FILE_CSV|FILE_COMMON);
      if(fileHandle != INVALID_HANDLE) {
         FileWrite(fileHandle, "Timestamp", "Date", "Time", "Ask", "Bid", "Spread", 
                   "Action", "Equity", "Reason", "Ticket", "LotSize", "Level", 
                   "Profit", "GLO", "GPO", "NetLots", "TotalOrders");
         FileClose(fileHandle);
         Log(1, StringFormat("Trade log initialized: %s", fileName));
      } else {
         Log(1, StringFormat("Failed to create trade log: %s (Error: %d)", fileName, GetLastError()));
      }
   } else {
      FileClose(fileHandle);
      Log(2, StringFormat("Trade log exists: %s", fileName));
   }
}

// Log a trade action
void LogTradeAction(string action, string reason, ulong ticket = 0, double lotSize = 0.0, 
                   int level = 0, double profit = 0.0) {
   if(!g_tradeLoggingActive) return;  // Check runtime state
   if(g_currentLogFile == "") InitializeTradeLog();
   if(g_currentLogFile == "") return;  // Still failed
   
   // Get current market data
   datetime currentTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = ask - bid;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Format timestamp
   string timestamp = StringFormat("%04d-%02d-%02d %02d:%02d:%02d", 
                                    dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec);
   string dateStr = StringFormat("%04d-%02d-%02d", dt.year, dt.mon, dt.day);
   string timeStr = StringFormat("%02d:%02d:%02d", dt.hour, dt.min, dt.sec);
   
   // Get current stats
   int totalOrders = g_buyCount + g_sellCount;
   
   // Open file in append mode
   int fileHandle = FileOpen(g_currentLogFile, FILE_WRITE|FILE_READ|FILE_CSV|FILE_COMMON);
   if(fileHandle != INVALID_HANDLE) {
      FileSeek(fileHandle, 0, SEEK_END);  // Move to end of file
      
      // Write log entry
      FileWrite(fileHandle, 
                timestamp, dateStr, timeStr,
                DoubleToString(ask, _Digits), 
                DoubleToString(bid, _Digits),
                DoubleToString(spread, _Digits),
                action, 
                DoubleToString(equity, 2),
                reason,
                (ticket > 0) ? IntegerToString(ticket) : "0",
                DoubleToString(lotSize, 2),
                IntegerToString(level),
                (profit != 0.0) ? DoubleToString(profit, 2) : "",
                IntegerToString(g_orders_in_loss),
                IntegerToString(g_orders_in_profit),
                DoubleToString(g_netLots, 2),
                IntegerToString(totalOrders));
      
      FileClose(fileHandle);
      
      Log(3, StringFormat("Trade logged: %s - %s", action, reason));
   } else {
      Log(1, StringFormat("Failed to open trade log for writing: %s (Error: %d)", 
          g_currentLogFile, GetLastError()));
   }
}

// Wrapper functions for common actions
void LogOrderOpen(ulong ticket, int orderType, double lotSize, int level, string reason) {
   string action = (orderType == POSITION_TYPE_BUY) ? "BUY_OPEN" : "SELL_OPEN";
   LogTradeAction(action, reason, ticket, lotSize, level, 0.0);
}

void LogSingleTrailStart(ulong ticket, double profit, string reason) {
   LogTradeAction("SINGLE_TRAIL_START", reason, ticket, 0.0, 0, profit);
}

void LogSingleClose(ulong ticket, double profit, string reason) {
   LogTradeAction("SINGLE_CLOSE", reason, ticket, 0.0, 0, profit);
}

void LogGroupTrailStart(double groupProfit, string reason) {
   LogTradeAction("GROUP_TRAIL_START", reason, 0, 0.0, 0, groupProfit);
}

void LogGroupClose(double profit, string reason) {
   LogTradeAction("GROUP_CLOSE", reason, 0, 0.0, 0, profit);
}

void LogTotalTrailStart(double cycleProfit, string reason) {
   LogTradeAction("TOTAL_TRAIL_START", reason, 0, 0.0, 0, cycleProfit);
}

void LogTotalCloseAll(string reason, double profit) {
   LogTradeAction("TOTAL_CLOSE_ALL", reason, 0, 0.0, 0, profit);
}

void LogResetCounters(string triggerReason) {
   LogTradeAction("RESET_COUNTERS", triggerReason, 0, 0.0, 0, 0.0);
}

void LogManualCloseAll(string triggerReason, int orderCount, double totalProfit) {
   string reason = StringFormat("%s Orders:%d Profit:%.2f", triggerReason, orderCount, totalProfit);
   LogTradeAction("MANUAL_CLOSE_ALL", reason, 0, 0.0, 0, totalProfit);
}
