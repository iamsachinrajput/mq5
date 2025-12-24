//+------------------------------------------------------------------+
//| Utils.mqh                                                        |
//| Utility functions, calculations, and helpers                     |
//+------------------------------------------------------------------+

//============================= UTILITY FUNCTIONS ==================//
void Log(int level, string msg) {
   if(level <= g_currentDebugLevel) Print("[Log", level, "] ", msg);
}

bool IsEven(int n) { return (n % 2 == 0); }
bool IsOdd(int n) { return (n % 2 != 0); }

int PriceLevelIndex(double price, double gap) {
   if(gap == 0) return 0;
   return (int)MathFloor((price - g_originPrice) / gap);
}

double LevelPrice(int level, double gap) {
   return g_originPrice + gap * level;
}

double SafeDiv(double a, double b) {
   return (b == 0.0) ? 0.0 : (a / b);
}

//============================= ORDER TRACKING SYSTEM ==============//
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

string GetNearbyOrdersText(int centerLevel, int maxDisplay) {
   string result = "";
   int validOrderCount = 0;
   
   for(int i = 0; i < g_orderCount; i++) {
      if(g_orders[i].isValid) validOrderCount++;
   }
   
   if(validOrderCount == 0) return "None";
   
   if(validOrderCount < 10) {
      // Show all orders sorted by level
      int levels[];
      string types[];
      double lots[];
      ArrayResize(levels, validOrderCount);
      ArrayResize(types, validOrderCount);
      ArrayResize(lots, validOrderCount);
      
      int idx = 0;
      for(int i = 0; i < g_orderCount; i++) {
         if(g_orders[i].isValid) {
            levels[idx] = g_orders[i].level;
            types[idx] = (g_orders[i].type == POSITION_TYPE_BUY) ? "B" : "S";
            lots[idx] = g_orders[i].lotSize;
            idx++;
         }
      }
      
      // Bubble sort by level
      for(int i = 0; i < validOrderCount - 1; i++) {
         for(int j = 0; j < validOrderCount - i - 1; j++) {
            if(levels[j] > levels[j + 1]) {
               int tempLevel = levels[j];
               levels[j] = levels[j + 1];
               levels[j + 1] = tempLevel;
               
               string tempType = types[j];
               types[j] = types[j + 1];
               types[j + 1] = tempType;
               
               double tempLot = lots[j];
               lots[j] = lots[j + 1];
               lots[j + 1] = tempLot;
            }
         }
      }
      
      for(int i = 0; i < validOrderCount; i++) {
         if(result != "") result += " ";
         result += StringFormat("%d%s%.2f", levels[i], types[i], lots[i]);
      }
   } else {
      // Show nearest 10
      for(int offset = -maxDisplay; offset <= maxDisplay; offset++) {
         if(offset == 0) continue;
         int checkLevel = centerLevel + offset;
         
         for(int i = 0; i < g_orderCount; i++) {
            if(g_orders[i].isValid && g_orders[i].level == checkLevel) {
               string typeStr = (g_orders[i].type == POSITION_TYPE_BUY) ? "B" : "S";
               if(result != "") result += " ";
               result += StringFormat("%d%s%.2f", checkLevel, typeStr, g_orders[i].lotSize);
               break;
            }
         }
      }
      if(result == "") result = "None nearby";
   }
   
   return result;
}

//============================= CALCULATIONS =======================//
double CalculateSingleThreshold() {
   if(SingleProfitThreshold > 0) return SingleProfitThreshold;
   
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   double gapDistance = 2.0 * g_adaptiveGap;
   double priceMove = gapDistance - spread;
   
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize == 0) tickSize = _Point;
   
   double profitPer01 = (priceMove / tickSize) * tickValue * 0.01;
   if(profitPer01 < 0.01) profitPer01 = 0.01;
   
   Log(3, StringFormat("Auto-calc threshold: Gap=%.1f pts | Distance=%.1f | Spread=%.1f | Threshold=%.2f",
       g_adaptiveGap/_Point, gapDistance/_Point, spread/_Point, profitPer01));
   
   return profitPer01;
}

double CalculateATR() {
   if(!UseAdaptiveGap) return GapInPoints * _Point;
   
   double atr[];
   ArraySetAsSeries(atr, true);
   int handle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
   if(handle == INVALID_HANDLE) return GapInPoints * _Point;
   
   if(CopyBuffer(handle, 0, 0, 1, atr) <= 0) {
      IndicatorRelease(handle);
      return GapInPoints * _Point;
   }
   
   IndicatorRelease(handle);
   double atrPoints = atr[0] / _Point;
   double adaptivePoints = atrPoints * ATRMultiplier;
   adaptivePoints = MathMax(MinGapPoints, MathMin(MaxGapPoints, adaptivePoints));
   
   Log(3, StringFormat("ATR: %.2f pts | Adaptive: %.2f pts", atrPoints, adaptivePoints));
   return adaptivePoints * _Point;
}

void CalculateHistoryDailyProfits() {
   ArrayInitialize(g_historySymbolDaily, 0.0);
   ArrayInitialize(g_historyOverallDaily, 0.0);
   ArrayResize(g_symbolHistory, 0);
   
   MqlDateTime dtNow;
   TimeCurrent(dtNow);
   datetime today = StringToTime(StringFormat("%04d.%02d.%02d 00:00:00", dtNow.year, dtNow.mon, dtNow.day));
   
   datetime dayStarts[5];
   for(int i = 0; i < 5; i++) {
      dayStarts[i] = today - (i * 86400);
   }
   
   datetime historyStart = dayStarts[4];
   datetime historyEnd = TimeCurrent();
   
   if(!HistorySelect(historyStart, historyEnd)) {
      Log(2, "Failed to load history");
      return;
   }
   
   int totalDeals = HistoryDealsTotal();
   
   for(int i = 0; i < totalDeals; i++) {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      
      long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(dealEntry != DEAL_ENTRY_OUT) continue;
      
      long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
      string dealSymbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
      double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
      datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
      
      MqlDateTime dtDeal;
      TimeToStruct(dealTime, dtDeal);
      datetime dealDay = StringToTime(StringFormat("%04d.%02d.%02d 00:00:00", dtDeal.year, dtDeal.mon, dtDeal.day));
      
      for(int d = 0; d < 5; d++) {
         if(dealDay == dayStarts[d]) {
            g_historyOverallDaily[d] += dealProfit;
            
            if(dealMagic == Magic && dealSymbol == _Symbol) {
               g_historySymbolDaily[d] += dealProfit;
            }
            
            if(dealMagic == Magic) {
               int symIdx = -1;
               for(int s = 0; s < ArraySize(g_symbolHistory); s++) {
                  if(g_symbolHistory[s].symbol == dealSymbol) {
                     symIdx = s;
                     break;
                  }
               }
               if(symIdx == -1) {
                  symIdx = ArraySize(g_symbolHistory);
                  ArrayResize(g_symbolHistory, symIdx + 1);
                  g_symbolHistory[symIdx].symbol = dealSymbol;
                  ArrayInitialize(g_symbolHistory[symIdx].daily, 0.0);
               }
               g_symbolHistory[symIdx].daily[d] += dealProfit;
            }
            break;
         }
      }
   }
   
   Log(3, StringFormat("History Daily Profits - Symbol: %.2f,%.2f,%.2f,%.2f,%.2f | Overall: %.2f,%.2f,%.2f,%.2f,%.2f",
       g_historySymbolDaily[0], g_historySymbolDaily[1], g_historySymbolDaily[2], g_historySymbolDaily[3], g_historySymbolDaily[4],
       g_historyOverallDaily[0], g_historyOverallDaily[1], g_historyOverallDaily[2], g_historyOverallDaily[3], g_historyOverallDaily[4]));
}

//============================= POSITION STATS =====================//
void UpdatePositionStats() {
   g_buyCount = 0;
   g_sellCount = 0;
   g_buyLots = 0.0;
   g_sellLots = 0.0;
   g_totalProfit = 0.0;
   g_buyProfit = 0.0;
   g_sellProfit = 0.0;
   g_orders_in_loss = 0;
   g_orders_in_profit = 0;
   
   double currentMaxLot = 0.0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
      
      int type = (int)PositionGetInteger(POSITION_TYPE);
      double lots = PositionGetDouble(POSITION_VOLUME);
      double profit = PositionGetDouble(POSITION_PROFIT);
      
      g_totalProfit += profit;
      
      if(profit < 0) g_orders_in_loss++;
      else if(profit > 0) g_orders_in_profit++;
      
      if(lots > currentMaxLot) currentMaxLot = lots;
      
      if(type == POSITION_TYPE_BUY) {
         g_buyCount++;
         g_buyLots += lots;
         g_buyProfit += profit;
      } else if(type == POSITION_TYPE_SELL) {
         g_sellCount++;
         g_sellLots += lots;
         g_sellProfit += profit;
      }
   }
   
   if(currentMaxLot > g_maxLotsCycle) g_maxLotsCycle = currentMaxLot;
   if(currentMaxLot > g_overallMaxLotSize) g_overallMaxLotSize = currentMaxLot;
   
   g_netLots = g_buyLots - g_sellLots;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity == 0) return;
   
   double overallProfit = equity - g_startingEquity;
   double cycleProfit = equity - g_lastCloseEquity;
   double openProfit = g_totalProfit;
   double bookedCycle = cycleProfit - openProfit;
   
   if(overallProfit > g_overallMaxProfit) g_overallMaxProfit = overallProfit;
   if(cycleProfit > g_maxProfitCycle) g_maxProfitCycle = cycleProfit;
   
   if(cycleProfit < 0) {
      double absLoss = MathAbs(cycleProfit);
      if(absLoss > g_maxLossCycle) {
         double prevMaxLoss = g_maxLossCycle;
         g_maxLossCycle = absLoss;
         
         if(absLoss >= MaxLossVlineThreshold && absLoss > g_lastMaxLossVline) {
            datetime nowTime = TimeCurrent();
            int lossRoundedK = (int)MathRound(absLoss / 1000.0);
            string vlineName = StringFormat("maxloss_%.0f_%dk",  g_lastCloseEquity, lossRoundedK);
            
            ObjectDelete(0, vlineName);
            
            double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(ObjectCreate(0, vlineName, OBJ_VLINE, 0, nowTime, currentPrice)) {
               color lineColor = (absLoss >= g_overallMaxLoss) ? clrRed : clrDeepPink;
               ObjectSetInteger(0, vlineName, OBJPROP_COLOR, lineColor);
               ObjectSetInteger(0, vlineName, OBJPROP_WIDTH, 1);
               ObjectSetInteger(0, vlineName, OBJPROP_STYLE, STYLE_DOT);
               ObjectSetInteger(0, vlineName, OBJPROP_BACK, true);
               ObjectSetInteger(0, vlineName, OBJPROP_SELECTABLE, false);
               
               string vlineText = StringFormat("MaxLoss: %.2f | Overall: %.2f | Equity: %.2f", absLoss, g_overallMaxLoss, equity);
               ObjectSetString(0, vlineName, OBJPROP_TEXT, vlineText);
               
               Log(2, StringFormat("MaxLoss VLine: %.2f (color: %s) | Overall: %.2f | Equity: %.2f", 
                   absLoss, (absLoss >= g_overallMaxLoss) ? "RED" : "PINK", g_overallMaxLoss, equity));
            }
            
            g_lastMaxLossVline = absLoss;
         }
      }
      if(absLoss > g_overallMaxLoss) g_overallMaxLoss = absLoss;
   }
   
   double currentSpread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   if(currentSpread > g_maxSpread) g_maxSpread = currentSpread;
   
   Log(3, StringFormat("Stats B%d/%.2f S%d/%.2f N%.2f ML%.2f/%.2f MP=%.2f/%.2f MaxLot%.2f/%.2f P%.2f(%.2f+%.2f=%.2f)EQ=%.2f", 
      g_buyCount, g_buyLots, g_sellCount, g_sellLots, g_netLots, -g_maxLossCycle, -g_overallMaxLoss, g_maxProfitCycle, g_overallMaxProfit, g_maxLotsCycle, g_overallMaxLotSize, overallProfit, openProfit, bookedCycle, cycleProfit, equity));
}

void UpdateRiskStatus() {
   g_tradingAllowed = true;
   
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
