//+------------------------------------------------------------------+
//| TrailStatus.mqh                                                  |
//| Print statistics and trail status information                    |
//+------------------------------------------------------------------+

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double cycleProfit = equity - g_lastCloseEquity;
   double openProfit = g_totalProfit;
   double bookedCycle = cycleProfit - openProfit;
   double overallProfit = equity - g_startingEquity;
   
   Log(1, "========== CURRENT EA STATISTICS ==========");
   Log(1, StringFormat("Cycle P:%.0f Max:%.0f Loss:%.0f | Overall:%.0f Max:%.0f Loss:%.0f",
       cycleProfit, g_maxProfitCycle, -g_maxLossCycle, overallProfit, g_overallMaxProfit, -g_overallMaxLoss));
   Log(1, StringFormat("Open:%.0f Booked:%.0f | Equity:%.0f Start:%.0f LastClose:%.0f",
       openProfit, bookedCycle, equity, g_startingEquity, g_lastCloseEquity));
   Log(1, StringFormat("Orders: B%d/%.2f S%d/%.2f Net%.2f | NextLot B%.2f S%.2f",
       g_buyCount, g_buyLots, g_sellCount, g_sellLots, g_netLots, g_nextBuyLot, g_nextSellLot));
   int orderCountDiff = MathAbs(g_buyCount - g_sellCount);
   Log(1, StringFormat("MaxLot: Cycle%.2f Overall%.2f | GLO:%d/%d/%d | Spread:%.1f/%.1f",
       g_maxLotsCycle, g_overallMaxLotSize, orderCountDiff, g_orders_in_loss, g_maxGLOOverall, 
       (SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point)/_Point, g_maxSpread/_Point));
   
   // Display current input settings
   Log(1, "---------- CURRENT INPUT SETTINGS ----------");
   Log(1, StringFormat("Magic:%d | Gap:%.0f | BaseLot:%.2f | MaxPos:%d",
       Magic, GapInPoints, BaseLotSize, MaxPositions));
   
   string methodNames[] = {"Base", "GLO", "GPO", "Diff", "Total", "BuySellDiff"};
   Log(1, StringFormat("LotScenarios: Boundary=%s Direction=%s Counter=%s GPO>GLO=%s GLO>GPO=%s Centered=%s Sided=%s",
       methodNames[LotCalc_Boundary], methodNames[LotCalc_Direction], methodNames[LotCalc_Counter],
       methodNames[LotCalc_GPO_More], methodNames[LotCalc_GLO_More], methodNames[LotCalc_Centered],
       methodNames[LotCalc_Sided]));
   Log(1, StringFormat("CenteredThreshold:%d", CenteredThreshold));
   
   string singleActivationStr = "";
   switch(SingleTrailActivation) {
      case SINGLE_ACTIVATION_IGNORE: singleActivationStr = "IGNORE"; break;
      case SINGLE_ACTIVATION_PROFIT: singleActivationStr = "PROFIT"; break;
      case SINGLE_ACTIVATION_LEVEL: singleActivationStr = "LEVEL"; break;
      default: singleActivationStr = StringFormat("%d", SingleTrailActivation); break;
   }
   
   string groupMethodStr = "";
   switch(g_currentGroupTrailMethod) {
      case GROUP_TRAIL_IGNORE: groupMethodStr = "IGNORE"; break;
      case GROUP_TRAIL_CLOSETOGETHER: groupMethodStr = "ANYSIDE"; break;
      case GROUP_TRAIL_CLOSETOGETHER_SAMETYPE: groupMethodStr = "SAMETYPE"; break;
      case GROUP_TRAIL_DYNAMIC: groupMethodStr = "DYNAMIC"; break;
      case GROUP_TRAIL_DYNAMIC_SAMETYPE: groupMethodStr = "DYN-SAME"; break;
      case GROUP_TRAIL_DYNAMIC_ANYSIDE: groupMethodStr = "DYN-ANY"; break;
      case GROUP_TRAIL_HYBRID_BALANCED: groupMethodStr = "HYB-BAL"; break;
      case GROUP_TRAIL_HYBRID_ADAPTIVE: groupMethodStr = "HYB-ADP"; break;
      case GROUP_TRAIL_HYBRID_SMART: groupMethodStr = "HYB-SMART"; break;
      case GROUP_TRAIL_HYBRID_COUNT_DIFF: groupMethodStr = "HYB-CNT"; break;
      default: groupMethodStr = StringFormat("%d", g_currentGroupTrailMethod); break;
   }
   
   string sTrailModeStr = (g_singleTrailMode == 0) ? "TIGHT" : (g_singleTrailMode == 1) ? "NORMAL" : "LOOSE";
   string tTrailModeStr = (g_totalTrailMode == 0) ? "TIGHT" : (g_totalTrailMode == 1) ? "NORMAL" : "LOOSE";
   string debugLevelStr = (g_currentDebugLevel == 0) ? "OFF" : (g_currentDebugLevel == 1) ? "CRITICAL" : (g_currentDebugLevel == 2) ? "INFO" : "VERBOSE";
   
   Log(1, StringFormat("SingleTrail:%s(%.1f) | GroupTrail:%s | SMode:%s | TMode:%s",
       singleActivationStr, SingleActivationValue, groupMethodStr, sTrailModeStr, tTrailModeStr));
   Log(1, StringFormat("DebugLevel:%s | ShowLabels:%s | ShowNextLines:%s",
       debugLevelStr, g_showLabels ? "YES" : "NO", g_showNextLevelLines ? "YES" : "NO"));
   Log(1, StringFormat("SingleGap:%d(%.1f) | MinGLO:%d | DynGLO:%d | MinGroupProfit:%.0f",
       SingleTrailGapMethod, SingleTrailGapValue, MinGLOForGroupTrail, DynamicGLOThreshold, MinGroupProfitToClose));
   Log(1, StringFormat("HybridNetLots:%.1f | HybridGLO%%:%.0f%% | HybridBalance:%.1f | HybridCountDiff:%d",
       HybridNetLotsThreshold, HybridGLOPercentage * 100, HybridBalanceFactor, HybridCountDiffThreshold));
   Log(1, StringFormat("OrderStrategy:%d | PlacementType:%d | FarAdj Dist:%d Depth:%d",
       OrderPlacementStrategy, OrderPlacementType, FarAdjacentDistance, FarAdjacentDepth));
   Log(1, StringFormat("TrailOrderMode:%d | UseAdaptiveGap:%s | ATRPeriod:%d",
       TrailOrderMode, UseAdaptiveGap ? "YES" : "NO", ATRPeriod));
   Log(1, "-------------------------------------------");
   
   // Print order tracker buffer
   Log(1, StringFormat("Order Tracker: %d orders in buffer", g_orderCount));
   
   // Create array of valid orders with their levels
   struct OrderDisplay {
      int level;
      string text;
   };
   OrderDisplay validOrders[];
   int validCount = 0;
   
   // Collect valid orders
   for(int i = 0; i < g_orderCount; i++) {
      if(g_orders[i].isValid) {
         ArrayResize(validOrders, validCount + 1);
         validOrders[validCount].level = g_orders[i].level;
         string typeStr = (g_orders[i].type == POSITION_TYPE_BUY) ? "B" : "S";
         validOrders[validCount].text = StringFormat("%d%s%.2f", g_orders[i].level, typeStr, g_orders[i].lotSize);
         validCount++;
      }
   }
   
   // Sort by level (simple bubble sort)
   for(int i = 0; i < validCount - 1; i++) {
      for(int j = 0; j < validCount - i - 1; j++) {
         if(validOrders[j].level > validOrders[j + 1].level) {
            // Swap
            OrderDisplay temp = validOrders[j];
            validOrders[j] = validOrders[j + 1];
            validOrders[j + 1] = temp;
         }
      }
   }
   
   // Print sorted orders
   string orderBuffer = "";
   int printedCount = 0;
   for(int i = 0; i < validCount; i++) {
      orderBuffer += validOrders[i].text + " ";
      printedCount++;
      // Print every 10 orders on a new line
      if(printedCount % 10 == 0) {
         Log(1, orderBuffer);
         orderBuffer = "";
      }
   }
   // Print remaining orders
   if(orderBuffer != "") {
      Log(1, orderBuffer);
   }
   
   Log(1, "===========================================");
}

//============================= TRAIL STATUS INFO =================//
string GetSingleTrailStatusInfo() {
   if(!EnableSingleTrailing) return "ST: Disabled";
   
   // Skip if total trail is active
   if(g_trailActive) return "ST: Skipped (Total Trail Active)";
   
   // Count active single trails and gather details
   int activeTrails = 0;
   double totalProfit = 0.0;
   string trailDetails = "";
   
   for(int i = 0; i < ArraySize(g_trails); i++) {
      if(g_trails[i].active) {
         activeTrails++;
         // Find position to get current profit and details
         if(PositionSelectByTicket(g_trails[i].ticket)) {
            double currentProfit = PositionGetDouble(POSITION_PROFIT);
            double currentPPL = currentProfit / (PositionGetDouble(POSITION_VOLUME) / 0.01);
            totalProfit += currentProfit;
            
            // Get level info
            string levelInfo = GetLevelInfoForTicket(g_trails[i].ticket);
            
            // Add to details string (show first 3 trails)
            if(activeTrails <= 3) {
               if(trailDetails != "") trailDetails += " ";
               trailDetails += StringFormat("%s:%.0f/%.0f", levelInfo, currentPPL, g_trails[i].activePeak);
            }
         }
      }
   }
   
   if(activeTrails > 0) {
      if(activeTrails <= 3) {
         // Show detailed info for small number of trails
         return StringFormat("ST:%d %s", activeTrails, trailDetails);
      } else {
         // Show summary for many trails
         return StringFormat("ST:%d TP:%.0f", activeTrails, totalProfit);
      }
   }
   
   // Check if single trail should be active based on method
   string methodName = "";
   bool shouldUseSingle = false;
   
   if(g_currentGroupTrailMethod == GROUP_TRAIL_DYNAMIC || 
      g_currentGroupTrailMethod == GROUP_TRAIL_DYNAMIC_SAMETYPE || 
      g_currentGroupTrailMethod == GROUP_TRAIL_DYNAMIC_ANYSIDE) {
      methodName = "DYN";
      shouldUseSingle = (g_orders_in_loss < DynamicGLOThreshold);
      if(shouldUseSingle) {
         return StringFormat("ST:RDY[%s] G:%d<%d", methodName, g_orders_in_loss, DynamicGLOThreshold);
      } else {
         return StringFormat("ST:OFF[%s] G:%d>=%d", methodName, g_orders_in_loss, DynamicGLOThreshold);
      }
   }
   else if(g_currentGroupTrailMethod == GROUP_TRAIL_HYBRID_BALANCED) {
      methodName = "HB";
      double netExposure = MathAbs(g_netLots);
      shouldUseSingle = (netExposure < HybridNetLotsThreshold);
      if(shouldUseSingle) {
         return StringFormat("ST:RDY[%s] NL:%.2f<%.2f", methodName, netExposure, HybridNetLotsThreshold);
      } else {
         return StringFormat("ST:OFF[%s] NL:%.2f>=%.2f", methodName, netExposure, HybridNetLotsThreshold);
      }
   }
   else if(g_currentGroupTrailMethod == GROUP_TRAIL_HYBRID_ADAPTIVE) {
      methodName = "HA";
      int totalOrders = g_buyCount + g_sellCount;
      double gloRatio = (totalOrders > 0) ? (double)g_orders_in_loss / totalOrders : 0.0;
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double cycleProfit = equity - g_lastCloseEquity;
      shouldUseSingle = (gloRatio < HybridGLOPercentage && cycleProfit >= 0);
      if(shouldUseSingle) {
         return StringFormat("ST:RDY[%s] G:%.0f%%<%.0f%% P:%.0f", methodName, gloRatio*100, HybridGLOPercentage*100, cycleProfit);
      } else {
         return StringFormat("ST:OFF[%s] G:%.0f%%>=%.0f%% P:%.0f", methodName, gloRatio*100, HybridGLOPercentage*100, cycleProfit);
      }
   }
   else if(g_currentGroupTrailMethod == GROUP_TRAIL_HYBRID_SMART) {
      methodName = "HS";
      double netExposure = MathAbs(g_netLots);
      int totalOrders = g_buyCount + g_sellCount;
      double gloRatio = (totalOrders > 0) ? (double)g_orders_in_loss / totalOrders : 0.0;
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double cycleProfit = equity - g_lastCloseEquity;
      double imbalanceFactor = 1.0;
      if(g_buyLots > 0.001 && g_sellLots > 0.001) {
         imbalanceFactor = MathMax(g_buyLots / g_sellLots, g_sellLots / g_buyLots);
      }
      bool highImbalance = (imbalanceFactor >= HybridBalanceFactor);
      bool highGLO = (gloRatio >= HybridGLOPercentage);
      bool negativeCycle = (cycleProfit < -MathAbs(g_maxLossCycle * 0.3));
      bool highNetExposure = (netExposure >= HybridNetLotsThreshold);
      int riskFactors = (highImbalance ? 1 : 0) + (highGLO ? 1 : 0) + (negativeCycle ? 1 : 0) + (highNetExposure ? 1 : 0);
      shouldUseSingle = (riskFactors < 2);
      if(shouldUseSingle) {
         return StringFormat("ST:RDY[%s] R:%d/4", methodName, riskFactors);
      } else {
         return StringFormat("ST:OFF[%s] R:%d/4 I:%d G:%d C:%d N:%d", methodName, riskFactors, highImbalance?1:0, highGLO?1:0, negativeCycle?1:0, highNetExposure?1:0);
      }
   }
   else if(g_currentGroupTrailMethod == GROUP_TRAIL_HYBRID_COUNT_DIFF) {
      methodName = "HC";
      int countDiff = MathAbs(g_buyCount - g_sellCount);
      shouldUseSingle = (countDiff <= HybridCountDiffThreshold);
      if(shouldUseSingle) {
         return StringFormat("ST:RDY[%s] D:%d<=%d", methodName, countDiff, HybridCountDiffThreshold);
      } else {
         return StringFormat("ST:OFF[%s] D:%d>%d", methodName, countDiff, HybridCountDiffThreshold);
      }
   }
   else if(g_currentGroupTrailMethod == GROUP_TRAIL_CLOSETOGETHER || 
           g_currentGroupTrailMethod == GROUP_TRAIL_CLOSETOGETHER_SAMETYPE) {
      return "ST:OFF[GRP-ONLY]";
   }
   else {
      // Normal single trail method
      return "ST:RDY[NORM]";
   }
}

// Helper function to get group trail candidate details
string GetGroupTrailCandidateDetails() {
   double farthestBuyLoss = 0.0;
   double farthestSellLoss = 0.0;
   ulong farthestBuyTicket = 0;
   ulong farthestSellTicket = 0;
   double totalProfitOrders = 0.0;
   int profitOrderCount = 0;
   
   // Scan all positions
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
      
      double profit = PositionGetDouble(POSITION_PROFIT);
      int type = (int)PositionGetInteger(POSITION_TYPE);
      
      if(profit < 0) {
         // Track farthest in-loss orders
         if(type == POSITION_TYPE_BUY) {
            if(profit < farthestBuyLoss) {
               farthestBuyLoss = profit;
               farthestBuyTicket = ticket;
            }
         } else {
            if(profit < farthestSellLoss) {
               farthestSellLoss = profit;
               farthestSellTicket = ticket;
            }
         }
      } else if(profit > 0) {
         // Track profit orders
         totalProfitOrders += profit;
         profitOrderCount++;
      }
   }
   
   // Build detail string
   string details = "";
   if(farthestBuyTicket > 0) {
      details += StringFormat("BL:%.0f ", farthestBuyLoss);
   } else {
      details += "BL:- ";
   }
   
   if(farthestSellTicket > 0) {
      details += StringFormat("SL:%.0f ", farthestSellLoss);
   } else {
      details += "SL:- ";
   }
   
   details += StringFormat("PO:%d/%.0f", profitOrderCount, totalProfitOrders);
   
   return details;
}

string GetGroupTrailStatusInfo() {
   if(!EnableSingleTrailing) return "GT:Disabled";
   
   // Skip if total trail is active
   if(g_trailActive) return "GT:Skip(TT-On)";
   
   // Check if group trail is active
   if(g_groupTrail.active) {
      // Calculate current group profit
      double currentProfit = 0.0;
      int buyCount = 0, sellCount = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
         
         double profit = PositionGetDouble(POSITION_PROFIT);
         int type = (int)PositionGetInteger(POSITION_TYPE);
         
         if(type == POSITION_TYPE_BUY) buyCount++;
         else sellCount++;
         currentProfit += profit;
      }
      
      return StringFormat("GT:ON P:%.0f Pk:%.0f|%d(%dB/%dS)", 
                         currentProfit, g_groupTrail.peakProfit, buyCount+sellCount, buyCount, sellCount);
   }
   
   // Check if group trail should be active based on method
   string methodName = "";
   bool shouldUseGroup = false;
   
   if(g_currentGroupTrailMethod == GROUP_TRAIL_DYNAMIC || 
      g_currentGroupTrailMethod == GROUP_TRAIL_DYNAMIC_SAMETYPE || 
      g_currentGroupTrailMethod == GROUP_TRAIL_DYNAMIC_ANYSIDE) {
      methodName = "DYN";
      shouldUseGroup = (g_orders_in_loss >= DynamicGLOThreshold);
      if(shouldUseGroup) {
         string details = GetGroupTrailCandidateDetails();
         return StringFormat("GT:RDY[%s] G:%d>=%d|%s", methodName, g_orders_in_loss, DynamicGLOThreshold, details);
      } else {
         return StringFormat("GT:OFF[%s] G:%d<%d", methodName, g_orders_in_loss, DynamicGLOThreshold);
      }
   }
   else if(g_currentGroupTrailMethod == GROUP_TRAIL_HYBRID_BALANCED) {
      methodName = "HB";
      double netExposure = MathAbs(g_netLots);
      shouldUseGroup = (netExposure >= HybridNetLotsThreshold);
      if(shouldUseGroup) {
         string details = GetGroupTrailCandidateDetails();
         return StringFormat("GT:RDY[%s] NL:%.2f>=%.2f|%s", methodName, netExposure, HybridNetLotsThreshold, details);
      } else {
         return StringFormat("GT:OFF[%s] NL:%.2f<%.2f", methodName, netExposure, HybridNetLotsThreshold);
      }
   }
   else if(g_currentGroupTrailMethod == GROUP_TRAIL_HYBRID_ADAPTIVE) {
      methodName = "HA";
      int totalOrders = g_buyCount + g_sellCount;
      double gloRatio = (totalOrders > 0) ? (double)g_orders_in_loss / totalOrders : 0.0;
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double cycleProfit = equity - g_lastCloseEquity;
      shouldUseGroup = (gloRatio >= HybridGLOPercentage || cycleProfit < 0);
      if(shouldUseGroup) {
         string details = GetGroupTrailCandidateDetails();
         return StringFormat("GT:RDY[%s] G:%.0f%%>=%.0f%% P:%.0f|%s", methodName, gloRatio*100, HybridGLOPercentage*100, cycleProfit, details);
      } else {
         return StringFormat("GT:OFF[%s] G:%.0f%%<%.0f%% P:%.0f", methodName, gloRatio*100, HybridGLOPercentage*100, cycleProfit);
      }
   }
   else if(g_currentGroupTrailMethod == GROUP_TRAIL_HYBRID_SMART) {
      methodName = "HS";
      double netExposure = MathAbs(g_netLots);
      int totalOrders = g_buyCount + g_sellCount;
      double gloRatio = (totalOrders > 0) ? (double)g_orders_in_loss / totalOrders : 0.0;
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double cycleProfit = equity - g_lastCloseEquity;
      double imbalanceFactor = 1.0;
      if(g_buyLots > 0.001 && g_sellLots > 0.001) {
         imbalanceFactor = MathMax(g_buyLots / g_sellLots, g_sellLots / g_buyLots);
      }
      bool highImbalance = (imbalanceFactor >= HybridBalanceFactor);
      bool highGLO = (gloRatio >= HybridGLOPercentage);
      bool negativeCycle = (cycleProfit < -MathAbs(g_maxLossCycle * 0.3));
      bool highNetExposure = (netExposure >= HybridNetLotsThreshold);
      int riskFactors = (highImbalance ? 1 : 0) + (highGLO ? 1 : 0) + (negativeCycle ? 1 : 0) + (highNetExposure ? 1 : 0);
      shouldUseGroup = (riskFactors >= 2);
      if(shouldUseGroup) {
         string details = GetGroupTrailCandidateDetails();
         return StringFormat("GT:RDY[%s] R:%d/4 I:%d G:%d C:%d N:%d|%s", methodName, riskFactors, highImbalance?1:0, highGLO?1:0, negativeCycle?1:0, highNetExposure?1:0, details);
      } else {
         return StringFormat("GT:OFF[%s] R:%d/4", methodName, riskFactors);
      }
   }
   else if(g_currentGroupTrailMethod == GROUP_TRAIL_HYBRID_COUNT_DIFF) {
      methodName = "HC";
      int countDiff = MathAbs(g_buyCount - g_sellCount);
      shouldUseGroup = (countDiff > HybridCountDiffThreshold);
      if(shouldUseGroup) {
         string details = GetGroupTrailCandidateDetails();
         return StringFormat("GT:RDY[%s] D:%d>%d B:%d S:%d|%s", methodName, countDiff, HybridCountDiffThreshold, g_buyCount, g_sellCount, details);
      } else {
         return StringFormat("GT:OFF[%s] D:%d<=%d", methodName, countDiff, HybridCountDiffThreshold);
      }
   }
   else if(g_currentGroupTrailMethod == GROUP_TRAIL_CLOSETOGETHER) {
      string details = GetGroupTrailCandidateDetails();
      return StringFormat("GT:RDY[ANY]|%s", details);
   }
   else if(g_currentGroupTrailMethod == GROUP_TRAIL_CLOSETOGETHER_SAMETYPE) {
      string details = GetGroupTrailCandidateDetails();
      return StringFormat("GT:RDY[SAME]|%s", details);
   }
   else {
      return "GT:OFF[SGL-ONLY]";
   }
}

string GetTotalTrailStatusInfo() {
   if(!EnableTotalTrailing) return "TT:Disabled";
   
   // Check if total trail is active
   if(g_trailActive) {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double cycleProfit = equity - g_lastCloseEquity;
      string mode = (g_totalTrailMode == 0) ? "T" : (g_totalTrailMode == 1) ? "N" : "L";
      int totalPos = g_buyCount + g_sellCount;
      return StringFormat("TT:ON[%s] P:%.0f Pk:%.0f F:%.0f G:%.0f|%d", 
                         mode, cycleProfit, g_trailPeak, g_trailFloor, g_trailGap, totalPos);
   }
   
   // Check if total trail should activate
   int totalPos = g_buyCount + g_sellCount;
   if(totalPos < 3) {
      return StringFormat("TT:WAIT Need3+(%d)", totalPos);
   }
   
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double cycleProfit = equity - g_lastCloseEquity;
   double lossStart = g_maxLossCycle * TrailStartPct;
   double profitStart = g_maxProfitCycle * TrailProfitPct;
   double trailStart = MathMax(lossStart, profitStart);
   double minNetLots = BaseLotSize * 2.0;
   bool hasSignificantExposure = MathAbs(g_netLots) >= minNetLots;
   
   if(trailStart <= 0) {
      return StringFormat("TT:WAIT TStart=0 ML:%.0f MP:%.0f", g_maxLossCycle, g_maxProfitCycle);
   }
   
   if(!hasSignificantExposure) {
      return StringFormat("TT:BLOCK Balanced NL:%.2f<%.2f", MathAbs(g_netLots), minNetLots);
   }
   
   if(cycleProfit <= trailStart) {
      return StringFormat("TT:WAIT P:%.0f<%.0f(%.0f)", cycleProfit, trailStart, trailStart - cycleProfit);
   }
   
   // All conditions met
   return StringFormat("TT:RDY P:%.0f>%.0f NL:%.2f (Click)", cycleProfit, trailStart, MathAbs(g_netLots));
}

//============================= SINGLE TRAILING ===================//
