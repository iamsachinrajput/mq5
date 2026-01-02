//+------------------------------------------------------------------+
//| TrailingTotal.mqh                                                |
//| Total profit trailing system                                     |
//+------------------------------------------------------------------+

   if(!EnableTotalTrailing) return;
   
   // Skip closing in No Work mode
   if(g_noWork) return;
   
   // Delete total trail line if labels are hidden
   if(!g_showLabels) {
      ObjectDelete(0, "total_trail");
   }
   
   // Need at least 3 positions to activate
   int totalPos = g_buyCount + g_sellCount;
   if(totalPos < 3) {
      if(g_trailActive) {
         Log(2, "TT deactivated: insufficient positions");
         g_trailActive = false;
         ObjectDelete(0, "total_trail");  // Delete line when trail not active
      }
      return;
   }
   
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double cycleProfit = currentEquity - g_lastCloseEquity;
   
   // Calculate trail start level
   double lossStart = g_maxLossCycle * TrailStartPct;
   double profitStart = g_maxProfitCycle * TrailProfitPct;  // Use adjustable profit percentage
   g_trailStart = MathMax(lossStart, profitStart);
   
   if(g_trailStart > 0) {
      // Apply total trail mode multiplier: Tight=0.5x, Normal=1.0x, Loose=2.0x
      double baseGap = g_trailStart * TrailGapPct;
      double modeMultiplier = (g_totalTrailMode == 0) ? 0.5 : ((g_totalTrailMode == 2) ? 2.0 : 1.0);
      g_trailGap = MathMin(baseGap * modeMultiplier, MaxTrailGap * modeMultiplier);
   }
   
   // Debug: show trail decision values
   Log(3, StringFormat("TT: cycleProfit=%.2f | MaxLoss=%.2f(start=%.2f) MaxProfit=%.2f(start=%.2f) | trailStart=%.2f | active=%d", 
       cycleProfit, -g_maxLossCycle, -lossStart, g_maxProfitCycle, profitStart, g_trailStart, g_trailActive ? 1 : 0));
   
   // Start trailing: should activate when cycle profit > (max profit already reached - some buffer)
   // Or when cycle profit exceeds max loss recovery + buffer
   // Also check: net lots must be at least 2x base lot size to avoid balanced positions
   double minNetLots = BaseLotSize * 2.0;
   bool hasSignificantExposure = MathAbs(g_netLots) >= minNetLots;
   
   if(!g_trailActive && cycleProfit > g_trailStart && g_trailStart > 0) {
      if(!hasSignificantExposure) {
         Log(2, StringFormat("TT BLOCKED: Net lots %.2f < minimum %.2f (too balanced)", MathAbs(g_netLots), minNetLots));
      } else {
         g_trailActive = true;
         g_trailPeak = cycleProfit;
         g_trailFloor = g_trailPeak - g_trailGap;
         double lossStart = g_maxLossCycle * TrailStartPct;
         double profitStart = g_maxProfitCycle * 1.0;
         double modeMultiplier = (g_totalTrailMode == 0) ? 0.5 : ((g_totalTrailMode == 2) ? 2.0 : 1.0);
         string modeName = (g_totalTrailMode == 0) ? "TIGHT" : ((g_totalTrailMode == 2) ? "LOOSE" : "NORMAL");
         Log(1, StringFormat("TT START: profit=%.2f start=%.2f gap=%.2f (%.1fx-%s) floor=%.2f | NetLots=%.2f | MaxLoss=%.2f LossStart=%.2f MaxProfit=%.2f ProfitStart=%.2f", 
             cycleProfit, g_trailStart, g_trailGap, modeMultiplier, modeName, g_trailFloor, MathAbs(g_netLots), g_maxLossCycle, lossStart, g_maxProfitCycle, profitStart));
         
         // Log total trail start
         string reason = StringFormat("Profit:%.2f > Start:%.2f Mode:%s Gap:%.2f NetLots:%.2f", 
                                     cycleProfit, g_trailStart, modeName, g_trailGap, MathAbs(g_netLots));
         LogTotalTrailStart(cycleProfit, reason);
         
         // Deactivate and cleanup all single trail states
         int singleTrailsCleared = 0;
         for(int i = ArraySize(g_trails) - 1; i >= 0; i--) {
            // Delete horizontal line for this single trail
            string lineName = StringFormat("TrailFloor_%I64u", g_trails[i].ticket);
            if(ObjectFind(0, lineName) >= 0) {
               ObjectDelete(0, lineName);
               singleTrailsCleared++;
            }
         }
         ArrayResize(g_trails, 0); // Clear all single trail states
         
         // Deactivate and cleanup group trail state
         if(g_groupTrail.active) {
            g_groupTrail.active = false;
            g_groupTrail.peakProfit = 0.0;
            g_groupTrail.farthestBuyTicket = 0;
            g_groupTrail.farthestSellTicket = 0;
            
            // Delete group trail horizontal lines
            ObjectDelete(0, "GroupTrailFloor_BUY");
            ObjectDelete(0, "GroupTrailFloor_SELL");
            
            Log(2, StringFormat("TT CLEANUP: Deactivated group trail and removed %d single trail lines", singleTrailsCleared));
         } else if(singleTrailsCleared > 0) {
            Log(2, StringFormat("TT CLEANUP: Removed %d single trail lines", singleTrailsCleared));
         }
      }
   }
   
   // Update trail
   if(g_trailActive) {
      // Recalculate gap based on current mode (allows dynamic mode switching)
      if(g_trailStart > 0) {
         double baseGap = g_trailStart * TrailGapPct;
         double modeMultiplier = (g_totalTrailMode == 0) ? 0.5 : ((g_totalTrailMode == 2) ? 2.0 : 1.0);
         double newGap = MathMin(baseGap * modeMultiplier, MaxTrailGap * modeMultiplier);
         
         // If gap changed, update floor and log it
         if(MathAbs(newGap - g_trailGap) > 0.01) {
            string modeName = (g_totalTrailMode == 0) ? "TIGHT" : ((g_totalTrailMode == 2) ? "LOOSE" : "NORMAL");
            double oldFloor = g_trailFloor;
            g_trailGap = newGap;
            g_trailFloor = g_trailPeak - g_trailGap;
            Log(1, StringFormat("TT MODE CHANGE: %s (%.1fx) | Gap: %.2f->%.2f | Floor: %.2f->%.2f", 
                modeName, modeMultiplier, g_trailGap, newGap, oldFloor, g_trailFloor));
         }
      }
      
      if(cycleProfit > g_trailPeak) {
         g_trailPeak = cycleProfit;
         g_trailFloor = g_trailPeak - g_trailGap;
         Log(2, StringFormat("TT UPDATE: peak=%.2f floor=%.2f", g_trailPeak, g_trailFloor));
      }
      
      // Update total trail floor line (always show when total trail is active)
      // Calculate floor price based on equity
      double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      double floorEquity = g_lastCloseEquity + g_trailFloor;
      
      // Convert equity floor to approximate price level
      // We'll show the line at the average position price adjusted by profit needed
      double avgPrice = 0.0;
      double totalLots = 0.0;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
         
         double posLots = PositionGetDouble(POSITION_VOLUME);
         double posPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         avgPrice += posPrice * posLots;
         totalLots += posLots;
      }
      
      if(totalLots > 0) {
         avgPrice /= totalLots;
         
         // Create or update horizontal line with simple name
         string lineName = "total_trail";
         
         if(ObjectFind(0, lineName) < 0) {
            ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, avgPrice);
            ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrBlue);  // Solid blue color
            ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 4);  // Width 4 for total trail
            ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DOT);  // Dotted style
            ObjectSetInteger(0, lineName, OBJPROP_BACK, false);
            ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
            ObjectSetString(0, lineName, OBJPROP_TEXT, StringFormat("TT Floor: %.2f (Equity: %.2f)", g_trailFloor, floorEquity));
         } else {
            // Update BOTH price and text with current floor values
            ObjectSetDouble(0, lineName, OBJPROP_PRICE, avgPrice);
            ObjectSetString(0, lineName, OBJPROP_TEXT, StringFormat("TT Floor: %.2f (Equity: %.2f)", g_trailFloor, floorEquity));
         }
      }
      
      // Check for close trigger
      if(cycleProfit <= g_trailFloor) {
         Log(1, StringFormat("Trail CLOSE trigger: profit=%.2f <= floor=%.2f | Peak=%.2f Gap=%.2f", 
             cycleProfit, g_trailFloor, g_trailPeak, g_trailGap));
         
         // Call wrapper function to handle all close-all activities
         PerformCloseAll("TrailClose");
      }
   }
}

//============================= SINGLE POSITION TRAIL ==============//
