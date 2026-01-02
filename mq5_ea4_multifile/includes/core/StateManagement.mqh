//+------------------------------------------------------------------+
//| StateManagement.mqh                                              |
//| State restoration, counter resets, history tracking              |
//+------------------------------------------------------------------+

}

//============================= STATE MANAGEMENT ===================//
void ResetAllCounters() {
   Log(1, "========== RESETTING ALL COUNTERS ==========");
   
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   g_startingEquity = currentEquity;
   g_lastCloseEquity = currentEquity;
   g_lastDayEquity = currentEquity;
   
   g_maxLossCycle = 0.0;
   g_maxProfitCycle = 0.0;
   g_overallMaxProfit = 0.0;
   g_overallMaxLoss = 0.0;
   g_maxLotsCycle = 0.0;
   g_overallMaxLotSize = 0.0;
   g_maxSpread = 0.0;
   g_lastMaxLossVline = 0.0;
   g_maxGLOOverall = 0;
   
   ArrayInitialize(g_last5Closes, 0.0);
   ArrayInitialize(g_dailyProfits, 0.0);
   ArrayInitialize(g_historySymbolDaily, 0.0);
   ArrayInitialize(g_historyOverallDaily, 0.0);
   g_closeCount = 0;
   g_lastDay = -1;
   g_dayIndex = 0;
   
   g_trailActive = false;
   g_trailStart = 0.0;
   g_trailGap = 0.0;
   g_trailPeak = 0.0;
   g_trailFloor = 0.0;
   
   ArrayResize(g_trails, 0);
   
   g_groupTrail.active = false;
   g_groupTrail.peakProfit = 0.0;
   g_groupTrail.threshold = 0.0;
   g_groupTrail.gap = 0.0;
   g_groupTrail.farthestBuyTicket = 0;
   g_groupTrail.farthestSellTicket = 0;
   g_groupTrail.lastLogTick = 0;
   
   double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) + SymbolInfoDouble(_Symbol, SYMBOL_BID)) / 2.0;
   g_originPrice = currentPrice;
   
   Log(1, StringFormat("All counters reset. New starting equity: %.2f | Origin price reset to: %.5f", g_startingEquity, g_originPrice));
   Log(1, "===========================================");
}

void RestoreStateFromPositions() {
   int totalPositions = 0;
   double maxLotFound = 0.0;
   ulong lastTicket = 0;
   datetime lastOpenTime = 0;
   string lastComment = "";
   int lastOrderLevel = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
      
      totalPositions++;
      
      double lots = PositionGetDouble(POSITION_VOLUME);
      if(lots > maxLotFound) maxLotFound = lots;
      
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      if(openTime > lastOpenTime) {
         lastOpenTime = openTime;
         lastTicket = ticket;
         lastComment = PositionGetString(POSITION_COMMENT);
      }
   }
   
   if(totalPositions > 0 && maxLotFound > 0) {
      g_maxLotsCycle = maxLotFound;
      if(maxLotFound > g_overallMaxLotSize) g_overallMaxLotSize = maxLotFound;
   }
   
   if(lastComment != "" && lastTicket > 0) {
      int ePos = StringFind(lastComment, "E");
      int bpPos = StringFind(lastComment, "BP");
      
      if(ePos >= 0 && bpPos > ePos) {
         string equityStr = StringSubstr(lastComment, ePos + 1, bpPos - ePos - 1);
         double parsedEquity = StringToDouble(equityStr);
         
         if(parsedEquity > 0) {
            g_lastCloseEquity = parsedEquity;
            Log(1, StringFormat("Restored lastCloseEquity from comment: %.2f", g_lastCloseEquity));
         }
      }
      
      int bPos = StringFind(lastComment, "B", bpPos);
      int sPos = StringFind(lastComment, "S", bpPos);
      int levelPos = (bPos > bpPos) ? bPos : sPos;
      
      if(levelPos > bpPos) {
         string levelStr = StringSubstr(lastComment, levelPos + 1);
         lastOrderLevel = (int)StringToInteger(levelStr);
         
         double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         int currentLevel = PriceLevelIndex(currentPrice, g_adaptiveGap);
         
         Log(1, StringFormat("Last order level: %d | Current price level: %d | Level difference: %d", 
             lastOrderLevel, currentLevel, currentLevel - lastOrderLevel));
      }
      
      Log(1, StringFormat("State Restored: Found %d positions | Max Lot: %.2f | Overall Max: %.2f | Comment: %s", 
          totalPositions, maxLotFound, g_overallMaxLotSize, lastComment));
   } else if(totalPositions > 0) {
      Log(1, StringFormat("State Restored: Found %d positions | Max Lot: %.2f | Overall Max: %.2f", 
          totalPositions, maxLotFound, g_overallMaxLotSize));
   }
}

void ParsePrioritySequence() {
   for(int i = 0; i < 7; i++) {
      g_lotCalcPriority[i] = i + 1;
   }
   
   string parts[];
   int count = StringSplit(LotCalc_PrioritySequence, ',', parts);
   
   if(count > 0 && count <= 7) {
      int validCount = 0;
      for(int i = 0; i < count && validCount < 7; i++) {
         StringTrimLeft(parts[i]);
         StringTrimRight(parts[i]);
         int num = (int)StringToInteger(parts[i]);
         if(num >= 1 && num <= 7) {
            g_lotCalcPriority[validCount] = num;
            validCount++;
         }
      }
      
      if(validCount < 7) {
         for(int num = 1; num <= 7 && validCount < 7; num++) {
            bool exists = false;
            for(int j = 0; j < validCount; j++) {
               if(g_lotCalcPriority[j] == num) {
                  exists = true;
                  break;
               }
            }
            if(!exists) {
               g_lotCalcPriority[validCount] = num;
               validCount++;
            }
         }
      }
   }
   
   string seqStr = "";
   for(int i = 0; i < 7; i++) {
      if(i > 0) seqStr += ",";
      seqStr += IntegerToString(g_lotCalcPriority[i]);
   }
   Log(1, StringFormat("Lot Calc Priority Sequence: %s", seqStr));
}
