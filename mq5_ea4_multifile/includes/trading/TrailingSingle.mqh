//+------------------------------------------------------------------+
//| TrailingSingle.mqh                                               |
//| Single position trailing and lines management                    |
//+------------------------------------------------------------------+

   int size = ArraySize(g_trails);
   for(int i = 0; i < size; i++) {
      if(g_trails[i].ticket == ticket) return i;
   }
   return -1;
}

void AddTrail(ulong ticket, double peakPPL, double threshold) {
   int size = ArraySize(g_trails);
   ArrayResize(g_trails, size + 1);
   g_trails[size].ticket = ticket;
   g_trails[size].peakPPL = peakPPL;
   g_trails[size].activePeak = 0.0;   // Will be set when trail activates
   g_trails[size].threshold = threshold;
   g_trails[size].gap = threshold / 2.0;
   g_trails[size].active = false;
   g_trails[size].lastLogTick = 0;
}

void RemoveTrail(int index) {
   int size = ArraySize(g_trails);
   if(index < 0 || index >= size) return;
   
   // Delete horizontal line for this trail
   string lineName = StringFormat("TrailFloor_%I64u", g_trails[index].ticket);
   ObjectDelete(0, lineName);
   
   for(int i = index; i < size - 1; i++) {
      g_trails[i] = g_trails[i + 1];
   }
   ArrayResize(g_trails, size - 1);
}

// Update horizontal lines for all active single trails
void UpdateSingleTrailLines() {
   if(!g_showLabels) {
      // Delete all trail lines if labels are hidden
      for(int i = 0; i < ArraySize(g_trails); i++) {
         string lineName = StringFormat("TrailFloor_%I64u", g_trails[i].ticket);
         ObjectDelete(0, lineName);
      }
      return;
   }
   
   for(int i = 0; i < ArraySize(g_trails); i++) {
      if(!g_trails[i].active) continue; // Only show lines for active trails
      
      ulong ticket = g_trails[i].ticket;
      if(!PositionSelectByTicket(ticket)) continue;
      
      double lots = PositionGetDouble(POSITION_VOLUME);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      int posType = (int)PositionGetInteger(POSITION_TYPE);
      
      // Calculate floor price (close trigger price)
      double activePeak = g_trails[i].activePeak;
      double gap = g_trails[i].gap;
      double trailFloorPPL = activePeak - gap;
      
      // Convert PPL to actual price
      // PPL = profit per 0.01 lot
      // For BUY: close when bid <= floorPrice
      // For SELL: close when ask >= floorPrice
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickSize == 0 || tickValue == 0) continue;
      
      double priceMove = (trailFloorPPL * tickSize) / (tickValue * 0.01);
      double floorPrice;
      
      if(posType == POSITION_TYPE_BUY) {
         floorPrice = openPrice + priceMove;
      } else {
         floorPrice = openPrice - priceMove;
      }
      
      // Create or update horizontal line
      string lineName = StringFormat("TrailFloor_%I64u", ticket);
      
      if(ObjectFind(0, lineName) < 0) {
         ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, floorPrice);
         ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrBlue);  // Solid blue color
         ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);  // Width 2 for single trail
         ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DOT);  // Dotted style
         ObjectSetInteger(0, lineName, OBJPROP_BACK, false);
         ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
         string levelInfo = GetLevelInfoForTicket(ticket);
         ObjectSetString(0, lineName, OBJPROP_TEXT, StringFormat("ST Floor %s #%I64u", levelInfo, ticket));
      } else {
         // Update price if it changed
         ObjectSetDouble(0, lineName, OBJPROP_PRICE, floorPrice);
      }
   }
}

// Remove all single trail and group trail horizontal lines
void RemoveAllSingleAndGroupTrailLines() {
   // Remove all single trail lines
   for(int i = 0; i < ArraySize(g_trails); i++) {
      string lineName = StringFormat("TrailFloor_%I64u", g_trails[i].ticket);
      if(ObjectFind(0, lineName) >= 0) {
         ObjectDelete(0, lineName);
         Log(2, StringFormat("[TRAIL-CLEAN] Removed single trail line: %s", lineName));
      }
   }
   
   // Remove group trail lines
   if(ObjectFind(0, "GroupTrailFloor_BUY") >= 0) {
      ObjectDelete(0, "GroupTrailFloor_BUY");
      Log(2, "[TRAIL-CLEAN] Removed group trail line: GroupTrailFloor_BUY");
   }
   if(ObjectFind(0, "GroupTrailFloor_SELL") >= 0) {
      ObjectDelete(0, "GroupTrailFloor_SELL");
      Log(2, "[TRAIL-CLEAN] Removed group trail line: GroupTrailFloor_SELL");
   }
   
   Log(1, "All single and group trail lines removed");
}

//============================= GROUP TRAILING (CLOSE TOGETHER) ====//
   if(!EnableSingleTrailing) return;
   
   // Skip ALL single/group trail checks when total trail is active
   if(g_trailActive) {
      Log(3, "Single/Group trail skipped: Total trail is active");
      return;
   }
   
   // Check if single trail is disabled
   if(SingleTrailActivation == SINGLE_ACTIVATION_IGNORE) {
      Log(3, "Single trail: IGNORE mode - skipping single trail");
   } else {
      // Process single trail for individual orders
      ProcessSingleTrail();
   }
   
   // Check if group trail is disabled
   if(GroupTrailMethod == GROUP_TRAIL_IGNORE) {
      Log(3, "Group trail: IGNORE mode - skipping group trail");
      return;
   }
   
   // Process group trail methods
   ProcessGroupTrail();
}

void ProcessSingleTrail() {
   double effectiveThreshold = CalculateSingleThreshold();
   
   for(int i = 0; i < g_orderCount; i++) {
      if(!g_orders[i].isValid) continue;
      
      ulong ticket = g_orders[i].ticket;
      if(!PositionSelectByTicket(ticket)) continue;
      
      double lots = PositionGetDouble(POSITION_VOLUME);
      double profit = PositionGetDouble(POSITION_PROFIT);
      double profitPer01 = (lots > 0) ? (profit / lots) * 0.01 : 0.0;
      
      int trailIdx = FindTrailIndex(ticket);
      bool isTrailing = (trailIdx >= 0);
      
      // Determine if order should start trailing based on activation method
      bool shouldStartTrail = false;
      
      if(SingleTrailActivation == SINGLE_ACTIVATION_PROFIT) {
         // Profit-based activation
         shouldStartTrail = (profitPer01 >= effectiveThreshold);
      } else if(SingleTrailActivation == SINGLE_ACTIVATION_LEVEL) {
         // Level-based activation
         int levelCount = (int)SingleActivationValue;
         if(levelCount <= 0) levelCount = 2; // Default to 2 levels
         
         // Calculate how many levels in profit
         double currentPrice = (g_orders[i].type == POSITION_TYPE_BUY) ? 
                               SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                               SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double openPrice = g_orders[i].openPrice;
         double priceDiff = (g_orders[i].type == POSITION_TYPE_BUY) ? 
                            (currentPrice - openPrice) : 
                            (openPrice - currentPrice);
         int levelsInProfit = (int)(priceDiff / g_adaptiveGap);
         
         shouldStartTrail = (levelsInProfit >= levelCount);
         
         if(levelsInProfit > 0 && trailIdx < 0) {
            Log(3, StringFormat("ST LEVEL CHECK %s #%I64u: %d levels in profit (need %d to activate)",
                g_orders[i].type == POSITION_TYPE_BUY ? "BUY" : "SELL",
                ticket, levelsInProfit, levelCount));
         }
      }
      
      // Start new trail
      if(!isTrailing && shouldStartTrail) {
         double gap = CalculateSingleTrailGap(effectiveThreshold, profitPer01);
         AddTrail(ticket, profitPer01, effectiveThreshold);
         trailIdx = FindTrailIndex(ticket);
         if(trailIdx >= 0) {
            g_trails[trailIdx].gap = gap;
         }
         
         string activationTypeStr = (SingleTrailActivation == SINGLE_ACTIVATION_PROFIT) ? "PROFIT" : "LEVEL";
         Log(2, StringFormat("ST START %s #%I64u PPL=%.2f | Activation=%s Threshold=%.2f Gap=%.2f (%.1f%s)", 
             g_orders[i].type == POSITION_TYPE_BUY ? "BUY" : "SELL",
             ticket, profitPer01, activationTypeStr, effectiveThreshold, gap,
             SingleTrailGapValue, 
             SingleTrailGapMethod == SINGLE_GAP_FIXED ? "pts" : 
             SingleTrailGapMethod == SINGLE_GAP_PERCENTAGE ? "%" : "dyn"));
         continue;
      }
      
      // Update existing trail
      if(isTrailing) {
         double peak = g_trails[trailIdx].peakPPL;
         
         // Update peak if profit increased
         if(profitPer01 > peak) {
            Log(3, StringFormat("ST PEAK UPDATE #%I64u: %.2f -> %.2f", ticket, peak, profitPer01));
            g_trails[trailIdx].peakPPL = profitPer01;
            peak = profitPer01;
         }
         
         double gap = g_trails[trailIdx].gap;
         double threshold = g_trails[trailIdx].threshold;
         
         // Activation logic based on trail mode
         double activationThreshold = effectiveThreshold / 2.0;
         bool shouldActivate = (profitPer01 <= activationThreshold && profitPer01 > 0) || (peak >= effectiveThreshold * 2.0);
         
         if(!g_trails[trailIdx].active && shouldActivate) {
            g_trails[trailIdx].active = true;
            g_trails[trailIdx].activePeak = peak;
            Log(2, StringFormat("ST ACTIVATED #%I64u: PPL=%.2f Peak=%.2f Threshold=%.2f", 
                ticket, profitPer01, peak, activationThreshold));
         }
         
         // Trail close logic
         if(g_trails[trailIdx].active) {
            double activePeak = g_trails[trailIdx].activePeak;
            if(profitPer01 > activePeak) {
               g_trails[trailIdx].activePeak = profitPer01;
               activePeak = profitPer01;
            }
            
            double trailFloor = activePeak - gap;
            if(profitPer01 <= trailFloor && profitPer01 > 0) {
               Log(1, StringFormat("ST CLOSE #%I64u: PPL=%.2f <= Floor=%.2f | Peak=%.2f Gap=%.2f",
                   ticket, profitPer01, trailFloor, activePeak, gap));
               
               CreateCloseLabelBeforeClose(ticket);
               if(trade.PositionClose(ticket)) {
                  RemoveTrail(trailIdx);
                  string typeStr = (g_orders[i].type == ORDER_TYPE_BUY) ? "BUY" : "SELL";
                  LogTradeAction("SingleTrailClose", typeStr, ticket, lots, 0, profit);
               }
            }
         }
      }
   }
}

void ProcessGroupTrail() {
