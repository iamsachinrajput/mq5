//+------------------------------------------------------------------+
//| OrderTracking.mqh                                                |
//| Order tracking system for syncing with live positions           |
//+------------------------------------------------------------------+

void SyncOrderTracking() {
   // Reset all validity flags
   for(int i = 0; i < g_orderCount; i++) {
      g_orders[i].isValid = false;
   }
   
   // Scan server positions and update our array
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
      
      // Find this ticket in our array
      int idx = -1;
      for(int j = 0; j < g_orderCount; j++) {
         if(g_orders[j].ticket == ticket) {
            idx = j;
            break;
         }
      }
      
      int type = (int)PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double lotSize = PositionGetDouble(POSITION_VOLUME);
      double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      string comment = PositionGetString(POSITION_COMMENT);
      
      // Calculate level from comment (more authentic) or fall back to price calculation
      int level = 0;
      bool levelFromComment = false;
      
      // Try to extract level from comment
      if(type == POSITION_TYPE_BUY) {
         int lastBPos = StringFind(comment, "B", 0);
         int searchPos = lastBPos + 1;
         while(searchPos >= 0 && searchPos < StringLen(comment)) {
            int nextB = StringFind(comment, "B", searchPos);
            if(nextB < 0) break;
            lastBPos = nextB;
            searchPos = nextB + 1;
         }
         if(lastBPos >= 0 && lastBPos < StringLen(comment) - 1) {
            string levelStr = StringSubstr(comment, lastBPos + 1);
            level = (int)StringToInteger(levelStr);
            levelFromComment = true;
         }
      } else {
         int lastSPos = StringFind(comment, "S", 0);
         int searchPos = lastSPos + 1;
         while(searchPos >= 0 && searchPos < StringLen(comment)) {
            int nextS = StringFind(comment, "S", searchPos);
            if(nextS < 0) break;
            lastSPos = nextS;
            searchPos = nextS + 1;
         }
         if(lastSPos >= 0 && lastSPos < StringLen(comment) - 1) {
            string levelStr = StringSubstr(comment, lastSPos + 1);
            level = (int)StringToInteger(levelStr);
            levelFromComment = true;
         }
      }
      
      // If comment parsing failed, calculate from price
      if(!levelFromComment) {
         level = PriceLevelIndex(openPrice, g_adaptiveGap);
      }
      
      if(idx >= 0) {
         // Update existing entry
         g_orders[idx].isValid = true;
         g_orders[idx].profit = profit;
         g_orders[idx].lotSize = lotSize;
      } else {
         // Add new entry
         ArrayResize(g_orders, g_orderCount + 1);
         g_orders[g_orderCount].ticket = ticket;
         g_orders[g_orderCount].type = type;
         g_orders[g_orderCount].level = level;
         g_orders[g_orderCount].openPrice = openPrice;
         g_orders[g_orderCount].lotSize = lotSize;
         g_orders[g_orderCount].profit = profit;
         g_orders[g_orderCount].openTime = openTime;
         g_orders[g_orderCount].isValid = true;
         g_orderCount++;
         Log(2, StringFormat("[TRACK-ADD] Detected external order #%d %s L%d", ticket, type == POSITION_TYPE_BUY ? "BUY" : "SELL", level));
      }
   }
   
   // Remove closed orders from our array
   for(int i = g_orderCount - 1; i >= 0; i--) {
      if(!g_orders[i].isValid) {
         Log(2, StringFormat("[TRACK-REMOVE] Order #%d closed, removing from tracking", g_orders[i].ticket));
         for(int j = i; j < g_orderCount - 1; j++) {
            g_orders[j] = g_orders[j + 1];
         }
         g_orderCount--;
         ArrayResize(g_orders, g_orderCount);
      }
   }
}

void AddOrderToTracking(ulong ticket, int type, int level, double openPrice, double lotSize) {
   ArrayResize(g_orders, g_orderCount + 1);
   g_orders[g_orderCount].ticket = ticket;
   g_orders[g_orderCount].type = type;
   g_orders[g_orderCount].level = level;
   g_orders[g_orderCount].openPrice = openPrice;
   g_orders[g_orderCount].lotSize = lotSize;
   g_orders[g_orderCount].profit = 0.0;
   g_orders[g_orderCount].openTime = TimeCurrent();
   g_orders[g_orderCount].isValid = true;
   g_orderCount++;
   Log(3, StringFormat("[TRACK-ADD] Added order #%d %s L%d to tracking array (count=%d)", 
       ticket, type == POSITION_TYPE_BUY ? "BUY" : "SELL", level, g_orderCount));
}

bool HasOrderAtLevelTracked(int orderType, int level) {
   for(int i = 0; i < g_orderCount; i++) {
      if(g_orders[i].isValid && g_orders[i].type == orderType && g_orders[i].level == level) {
         Log(3, StringFormat("[TRACK-CHECK] Found %s order at L%d in tracking array (ticket #%d)",
             orderType == POSITION_TYPE_BUY ? "BUY" : "SELL", level, g_orders[i].ticket));
         return true;
      }
   }
   return false;
}

int GetTrackedOrderCount(int orderType) {
   int count = 0;
   for(int i = 0; i < g_orderCount; i++) {
      if(g_orders[i].isValid && g_orders[i].type == orderType) {
         count++;
      }
   }
   return count;
}

double GetTrackedLots(int orderType) {
   double lots = 0.0;
   for(int i = 0; i < g_orderCount; i++) {
      if(g_orders[i].isValid && g_orders[i].type == orderType) {
         lots += g_orders[i].lotSize;
      }
   }
   return lots;
}

string GetLevelInfoForTicket(ulong ticket) {
   for(int i = 0; i < g_orderCount; i++) {
      if(g_orders[i].isValid && g_orders[i].ticket == ticket) {
         string typeStr = (g_orders[i].type == POSITION_TYPE_BUY) ? "B" : "S";
         return StringFormat("%d%s", g_orders[i].level, typeStr);
      }
   }
   return "??";
}
