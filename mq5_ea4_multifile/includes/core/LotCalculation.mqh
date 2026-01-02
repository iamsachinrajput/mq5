//+------------------------------------------------------------------+
//| LotCalculation.mqh                                               |
//| Lot sizing methods and scenario detection                        |
//+------------------------------------------------------------------+

   
   if(PositionsTotal() >= MaxPositions) {
      Log(1, StringFormat("Risk: Max positions %d reached", MaxPositions));
      g_tradingAllowed = false;
   } else if((g_buyLots + g_sellLots) >= MaxTotalLots) {
      Log(1, StringFormat("Risk: Max lots %.2f reached", MaxTotalLots));
      g_tradingAllowed = false;
   } else if(g_totalProfit <= -MaxLossLimit) {
      Log(1, StringFormat("Risk: Max loss %.2f exceeded", MaxLossLimit));
      g_tradingAllowed = false;
   } else if(g_totalProfit >= DailyProfitTarget) {
      Log(1, StringFormat("Risk: Profit target %.2f reached", DailyProfitTarget));
      g_tradingAllowed = false;
   }
}

//============================= LOT CALCULATION ====================//
double ApplyLotMethod(ENUM_LOT_CALC_METHOD method) {
   double calculatedLot = BaseLotSize;
   int buyLossCount = 0, sellLossCount = 0;
   int buyProfitCount = 0, sellProfitCount = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
      
      double profit = PositionGetDouble(POSITION_PROFIT);
      bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      
      if(profit < 0) {
         if(isBuy) buyLossCount++; else sellLossCount++;
      } else if(profit > 0) {
         if(isBuy) buyProfitCount++; else sellProfitCount++;
      }
   }
   
   g_orders_in_loss = buyLossCount + sellLossCount;
   g_orders_in_profit = buyProfitCount + sellProfitCount;
   
   switch(method) {
      case LOT_CALC_BASE:
         calculatedLot = BaseLotSize;
         break;
      
      case LOT_CALC_GLO:
         calculatedLot = BaseLotSize * MathMax(1, g_orders_in_loss);
         break;
      
      case LOT_CALC_GPO:
         calculatedLot = BaseLotSize * MathMax(1, g_orders_in_profit);
         break;
      
      case LOT_CALC_GLO_GPO_DIFF:
         {
            int diff = (int)MathAbs(g_orders_in_loss - g_orders_in_profit);
            calculatedLot = BaseLotSize * MathMax(1, diff);
         }
         break;
      
      case LOT_CALC_TOTAL_ORDERS:
         {
            int totalOrders = g_buyCount + g_sellCount;
            calculatedLot = BaseLotSize * MathMax(1, totalOrders);
         }
         break;
      
      case LOT_CALC_BUY_SELL_DIFF:
         {
            int orderDiff = (int)MathAbs(g_buyCount - g_sellCount);
            calculatedLot = BaseLotSize * MathMax(1, orderDiff);
         }
         break;
   }
   
   if(g_orders_in_loss > g_maxGLOOverall) g_maxGLOOverall = g_orders_in_loss;
   
   return calculatedLot;
}

string GetScenarioReason(ENUM_POSITION_TYPE orderType, int scenario, int level) {
   int buyLossCount = 0, sellLossCount = 0;
   bool hasBuyAbove = false, hasSellBelow = false;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
      
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double profit = PositionGetDouble(POSITION_PROFIT);
      bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      
      if(profit < 0) {
         if(isBuy) buyLossCount++; else sellLossCount++;
      }
      
      double levelPrice = LevelPrice(level, g_adaptiveGap);
      if(isBuy && openPrice > levelPrice) hasBuyAbove = true;
      if(!isBuy && openPrice < levelPrice) hasSellBelow = true;
   }
   
   int countDiff = (int)MathAbs(g_buyCount - g_sellCount);
   
   switch(scenario) {
      case 0: // Boundary
         return (orderType == POSITION_TYPE_BUY) ? "No B above" : "No S below";
      case 1: // Direction
         if(sellLossCount > buyLossCount) return (orderType == POSITION_TYPE_BUY) ? "S-loss>B-loss" : "S-loss>B-loss";
         else return (orderType == POSITION_TYPE_SELL) ? "B-loss>S-loss" : "B-loss>S-loss";
      case 2: // Reverse
         if(sellLossCount > buyLossCount) return (orderType == POSITION_TYPE_SELL) ? "S-loss>B-loss" : "S-loss>B-loss";
         else return (orderType == POSITION_TYPE_BUY) ? "B-loss>S-loss" : "B-loss>S-loss";
      case 3: // GPO > GLO
         return StringFormat("GPO:%d>GLO:%d", g_orders_in_profit, g_orders_in_loss);
      case 4: // GLO > GPO
         return StringFormat("GLO:%d>GPO:%d", g_orders_in_loss, g_orders_in_profit);
      case 5: // Centered
         return StringFormat("Diff:%d≤%d", countDiff, CenteredThreshold);
      case 6: // Sided
         return StringFormat("Diff:%d>%d", countDiff, CenteredThreshold);
      default:
         return "Unknown";
   }
}

void DetectAllMatchingScenarios(ENUM_POSITION_TYPE orderType, int level, bool &matchingScenarios[]) {
   for(int i = 0; i < 7; i++) {
      matchingScenarios[i] = false;
   }
   
   int buyLossCount = 0, sellLossCount = 0;
   bool hasBuyAbove = false, hasSellBelow = false;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
      
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double profit = PositionGetDouble(POSITION_PROFIT);
      bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      
      if(profit < 0) {
         if(isBuy) buyLossCount++; else sellLossCount++;
      }
      
      double levelPrice = LevelPrice(level, g_adaptiveGap);
      if(isBuy && openPrice > levelPrice) hasBuyAbove = true;
      if(!isBuy && openPrice < levelPrice) hasSellBelow = true;
   }
   
   int totalGLO = buyLossCount + sellLossCount;
   int totalGPO = g_orders_in_profit;
   int buyCount = g_buyCount;
   int sellCount = g_sellCount;
   int countDiff = (int)MathAbs(buyCount - sellCount);
   
   if((orderType == POSITION_TYPE_BUY && !hasBuyAbove) || 
      (orderType == POSITION_TYPE_SELL && !hasSellBelow)) {
      matchingScenarios[0] = true;
   }
   
   if(sellLossCount > buyLossCount) {
      if(orderType == POSITION_TYPE_BUY) matchingScenarios[1] = true;
      else matchingScenarios[2] = true;
   } else if(buyLossCount > sellLossCount) {
      if(orderType == POSITION_TYPE_SELL) matchingScenarios[1] = true;
      else matchingScenarios[2] = true;
   }
   
   if(totalGPO > totalGLO) matchingScenarios[3] = true;
   if(totalGLO > totalGPO) matchingScenarios[4] = true;
   if(countDiff <= CenteredThreshold) matchingScenarios[5] = true;
   if(countDiff > CenteredThreshold) matchingScenarios[6] = true;
}

ENUM_LOT_CALC_METHOD GetMethodForScenario(int scenario) {
   switch(scenario) {
      case 0: return LotCalc_Boundary;
      case 1: return LotCalc_Direction;
      case 2: return LotCalc_Counter;
      case 3: return LotCalc_GPO_More;
      case 4: return LotCalc_GLO_More;
      case 5: return LotCalc_Centered;
      case 6: return LotCalc_Sided;
      default: return LOT_CALC_BASE;
   }
}

int DetectLotScenario(ENUM_POSITION_TYPE orderType, int level) {
   bool matchingScenarios[7];
   DetectAllMatchingScenarios(orderType, level, matchingScenarios);
   
   for(int p = 0; p < 7; p++) {
      int scenarioIndex = g_lotCalcPriority[p] - 1;
      if(scenarioIndex >= 0 && scenarioIndex < 7 && matchingScenarios[scenarioIndex]) {
         ENUM_LOT_CALC_METHOD method = GetMethodForScenario(scenarioIndex);
         if(method != LOT_CALC_IGNORE) {
            return scenarioIndex;
         }
      }
   }
   
   for(int i = 0; i < 7; i++) {
      ENUM_LOT_CALC_METHOD method = GetMethodForScenario(i);
      if(method != LOT_CALC_IGNORE) {
         return i;
      }
   }
   
   return 5;
}

double NormalizeLotSize(double lotSize) {
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   lotSize = MathMax(lotSize, minLot);
   lotSize = MathRound(lotSize / stepLot) * stepLot;
   lotSize = MathMin(lotSize, maxLot);
   
   return lotSize;
}

void CalculateNextLots() {
   double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) + SymbolInfoDouble(_Symbol, SYMBOL_BID)) / 2.0;
   int currentLevel = PriceLevelIndex(currentPrice, g_adaptiveGap);
   
   int buyScenario = DetectLotScenario(POSITION_TYPE_BUY, currentLevel);
   ENUM_LOT_CALC_METHOD buyMethod = GetMethodForScenario(buyScenario);
   double buyLotResult = ApplyLotMethod(buyMethod);
   g_nextBuyLot = (buyLotResult >= 0) ? NormalizeLotSize(buyLotResult) : NormalizeLotSize(BaseLotSize);
   g_nextBuyScenario = buyScenario;
   g_nextBuyReason = GetScenarioReason(POSITION_TYPE_BUY, buyScenario, currentLevel);
   
   int sellScenario = DetectLotScenario(POSITION_TYPE_SELL, currentLevel);
   ENUM_LOT_CALC_METHOD sellMethod = GetMethodForScenario(sellScenario);
   double sellLotResult = ApplyLotMethod(sellMethod);
   g_nextSellLot = (sellLotResult >= 0) ? NormalizeLotSize(sellLotResult) : NormalizeLotSize(BaseLotSize);
   g_nextSellScenario = sellScenario;
   g_nextSellReason = GetScenarioReason(POSITION_TYPE_SELL, sellScenario, currentLevel);
   
   string scenarioNames[] = {"Boundary", "Direction", "Reverse", "GPO>GLO", "GLO>GPO", "Centered", "Sided"};
   string methodNames[] = {"Base", "GLO", "GPO", "Diff", "Total", "BuySellDiff", "IGNORE"};
   
   string buyMethodName = (buyMethod < 6) ? methodNames[buyMethod] : "IGNORE";
   string sellMethodName = (sellMethod < 6) ? methodNames[sellMethod] : "IGNORE";
   g_nextBuyMethod = buyMethodName;
   g_nextSellMethod = sellMethodName;
   
   Log(3, StringFormat("Lot Calc: BUY Scenario=%s Method=%s Lot=%.2f | SELL Scenario=%s Method=%s Lot=%.2f",
       scenarioNames[buyScenario], buyMethodName, g_nextBuyLot,
       scenarioNames[sellScenario], sellMethodName, g_nextSellLot));
   
   if(g_trailActive && (TrailOrderMode == TRAIL_ORDERS_BASESIZE || 
                         TrailOrderMode == TRAIL_ORDERS_PROFIT_DIR || 
                         TrailOrderMode == TRAIL_ORDERS_REVERSE_DIR)) {
      
      double trailLotSize = BaseLotSize;
      string lotCalcDesc = "base";
      
      switch(TrailLotMode) {
         case TRAIL_LOT_BASE:
            trailLotSize = BaseLotSize;
            lotCalcDesc = "base";
            break;
            
         case TRAIL_LOT_GLO:
            trailLotSize = BaseLotSize * MathMax(1, g_orders_in_loss);
            lotCalcDesc = StringFormat("base * GLO (%d)", g_orders_in_loss);
            break;
            
         case TRAIL_LOT_GPO:
            trailLotSize = BaseLotSize * MathMax(1, g_orders_in_profit);
            lotCalcDesc = StringFormat("base * GPO (%d)", g_orders_in_profit);
            break;
            
         case TRAIL_LOT_DIFF:
            {
               int diff = (int)MathAbs(g_orders_in_profit - g_orders_in_loss);
               trailLotSize = BaseLotSize * MathMax(1, diff);
               lotCalcDesc = StringFormat("base * |GPO-GLO| (%d)", diff);
            }
            break;
            
         case TRAIL_LOT_TOTAL:
            {
               int totalOrders = g_buyCount + g_sellCount;
               trailLotSize = BaseLotSize * MathMax(1, totalOrders);
               lotCalcDesc = StringFormat("base * Total (%d)", totalOrders);
            }
            break;
      }
      
      g_nextBuyLot = NormalizeLotSize(trailLotSize);
      g_nextSellLot = NormalizeLotSize(trailLotSize);
      string modeDesc = (TrailOrderMode == TRAIL_ORDERS_BASESIZE) ? "base size" : 
                        (TrailOrderMode == TRAIL_ORDERS_PROFIT_DIR) ? "profit direction" : "reverse direction";
      Log(3, StringFormat("Trail active: Using lot %.2f (%s) | mode: %s", trailLotSize, lotCalcDesc, modeDesc));
   }
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
