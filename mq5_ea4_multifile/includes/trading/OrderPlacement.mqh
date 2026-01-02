//+------------------------------------------------------------------+
//| OrderPlacement.mqh                                               |
//| Grid order placement, missed orders, no positions handler        |
//+------------------------------------------------------------------+

// Check for missed orders at adjacent levels and create them
// Only runs when OrderPlacementType = ORDER_PLACEMENT_FLEXIBLE
void PlaceMissedAdjacentOrders() {
   double nowAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double nowBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Get current price levels
   int currentAskLevel = PriceLevelIndex(nowAsk, g_adaptiveGap);
   int currentBidLevel = PriceLevelIndex(nowBid, g_adaptiveGap);
   
   // Check adjacent SELL level (one level above current ask - should be odd)
   int adjacentSellLevel = currentAskLevel + 1;
   if(!IsOdd(adjacentSellLevel)) adjacentSellLevel++; // Make sure it's odd
   
   // Check if SELL order exists at adjacent level - use comment check first (most reliable)
   if(!HasOrderAtLevelByComment(POSITION_TYPE_SELL, adjacentSellLevel) &&
      !HasOrderOnLevel(POSITION_TYPE_SELL, adjacentSellLevel, g_adaptiveGap) &&
      !HasOrderAtPrice(POSITION_TYPE_SELL, adjacentSellLevel, g_adaptiveGap)) {
      
      // Check if we should place this order based on strategy
      if(IsOrderPlacementAllowed(POSITION_TYPE_SELL, adjacentSellLevel, g_adaptiveGap)) {
         Log(1, StringFormat("[DELAYED-ORDER] Creating missed SELL order at adjacent level L%d", adjacentSellLevel));
         
         double equity = AccountInfoDouble(ACCOUNT_EQUITY);
         double cycleProfit = equity - g_lastCloseEquity;
         double bookedProfit = cycleProfit - g_totalProfit;
         string orderComment = StringFormat("E%.0fBP%.0fS%d", g_lastCloseEquity, bookedProfit, adjacentSellLevel);
         
         if(ExecuteOrder(POSITION_TYPE_SELL, g_nextSellLot, orderComment)) {
            if(g_nextSellLot > g_maxLotsCycle) g_maxLotsCycle = g_nextSellLot;
            if(g_nextSellLot > g_overallMaxLotSize) g_overallMaxLotSize = g_nextSellLot;
            Log(1, StringFormat("[DELAYED-ORDER] SELL %.2f @ L%d (%.5f) - missed order filled", 
                g_nextSellLot, adjacentSellLevel, nowBid));
         }
      }
   }
   
   // Check adjacent BUY level (one level below current bid - should be even)
   int adjacentBuyLevel = currentBidLevel - 1;
   if(!IsEven(adjacentBuyLevel)) adjacentBuyLevel--; // Make sure it's even
   
   // Check if BUY order exists at adjacent level - use comment check first (most reliable)
   if(!HasOrderAtLevelByComment(POSITION_TYPE_BUY, adjacentBuyLevel) &&
      !HasOrderOnLevel(POSITION_TYPE_BUY, adjacentBuyLevel, g_adaptiveGap) &&
      !HasOrderAtPrice(POSITION_TYPE_BUY, adjacentBuyLevel, g_adaptiveGap)) {
      
      // Check if we should place this order based on strategy
      if(IsOrderPlacementAllowed(POSITION_TYPE_BUY, adjacentBuyLevel, g_adaptiveGap)) {
         Log(1, StringFormat("[DELAYED-ORDER] Creating missed BUY order at adjacent level L%d", adjacentBuyLevel));
         
         double equity = AccountInfoDouble(ACCOUNT_EQUITY);
         double cycleProfit = equity - g_lastCloseEquity;
         double bookedProfit = cycleProfit - g_totalProfit;
         string orderComment = StringFormat("E%.0fBP%.0fB%d", g_lastCloseEquity, bookedProfit, adjacentBuyLevel);
         
         if(ExecuteOrder(POSITION_TYPE_BUY, g_nextBuyLot, orderComment)) {
            if(g_nextBuyLot > g_maxLotsCycle) g_maxLotsCycle = g_nextBuyLot;
            if(g_nextBuyLot > g_overallMaxLotSize) g_overallMaxLotSize = g_nextBuyLot;
            Log(1, StringFormat("[DELAYED-ORDER] BUY %.2f @ L%d (%.5f) - missed order filled", 
                g_nextBuyLot, adjacentBuyLevel, nowAsk));
         }
      }
   }
}

//============================= NO POSITIONS HANDLER ===============//
void HandleNoPositions() {
   if(NoPositionsAction == NO_POS_NONE) return;
   
   // Block new orders if Stop New Orders or No Work mode is active
   if(g_stopNewOrders) {
      Log(3, "[NO-POS] Blocked: Stop New Orders mode active");
      return;
   }
   
   if(g_noWork) {
      Log(3, "[NO-POS] Blocked: No Work mode active");
      return;
   }
   
   double nowAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double nowBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double midPrice = (nowAsk + nowBid) / 2.0;
   
   // Find nearest levels
   int nearestLevel = (int)MathRound((midPrice - g_originPrice) / g_adaptiveGap);
   
   // Determine which level is BUY (even) and which is SELL (odd)
   int buyLevel, sellLevel;
   
   if(IsEven(nearestLevel)) {
      // Nearest is even (BUY level)
      buyLevel = nearestLevel;
      sellLevel = nearestLevel + 1; // Next odd level
   } else {
      // Nearest is odd (SELL level)
      sellLevel = nearestLevel;
      buyLevel = nearestLevel - 1; // Previous even level
   }
   
   double buyPrice = LevelPrice(buyLevel, g_adaptiveGap);
   double sellPrice = LevelPrice(sellLevel, g_adaptiveGap);
   
   // Calculate lot sizes
   CalculateNextLots();
   
   if(NoPositionsAction == NO_POS_NEAREST_LEVEL) {
      // Open single order at nearest level
      double distToBuy = MathAbs(midPrice - buyPrice);
      double distToSell = MathAbs(midPrice - sellPrice);
      
      if(distToBuy <= distToSell) {
         // BUY level is nearest
         double equity = AccountInfoDouble(ACCOUNT_EQUITY);
         string comment = StringFormat("E%.0fBP0B%d", equity, buyLevel);
         bool result = ExecuteOrder(POSITION_TYPE_BUY, g_nextBuyLot, comment);
         if(result) {
            Log(1, StringFormat("[NO-POS] Opened BUY @ L%d (%.5f) - nearest level", buyLevel, buyPrice));
         }
      } else {
         // SELL level is nearest
         double equity = AccountInfoDouble(ACCOUNT_EQUITY);
         string comment = StringFormat("E%.0fBP0S%d", equity, sellLevel);
         bool result = ExecuteOrder(POSITION_TYPE_SELL, g_nextSellLot, comment);
         if(result) {
            Log(1, StringFormat("[NO-POS] Opened SELL @ L%d (%.5f) - nearest level", sellLevel, sellPrice));
         }
      }
   } else if(NoPositionsAction == NO_POS_BOTH_LEVELS) {
      // Open both BUY and SELL at nearest levels
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      
      string buyComment = StringFormat("E%.0fBP0B%d", equity, buyLevel);
      bool buyResult = ExecuteOrder(POSITION_TYPE_BUY, g_nextBuyLot, buyComment);
      if(buyResult) {
         Log(1, StringFormat("[NO-POS] Opened BUY @ L%d (%.5f) - both levels mode", buyLevel, buyPrice));
      }
      
      // Small delay between orders if configured
      if(OrderPlacementDelayMs > 0) {
         Sleep(OrderPlacementDelayMs);
      }
      
      string sellComment = StringFormat("E%.0fBP0S%d", equity, sellLevel);
      bool sellResult = ExecuteOrder(POSITION_TYPE_SELL, g_nextSellLot, sellComment);
      if(sellResult) {
         Log(1, StringFormat("[NO-POS] Opened SELL @ L%d (%.5f) - both levels mode", sellLevel, sellPrice));
      }
   }
}

//============================= ORDER PLACEMENT ====================//
void PlaceGridOrders() {
   // Check if no positions and handle according to configured action
   if(PositionsTotal() == 0) {
      HandleNoPositions();
      return;
   }
   
   if(!g_tradingAllowed) {
      Log(2, "Trading blocked by risk limits");
      return;
   }
   
   // Block new orders if Stop New Orders or No Work mode is active
   if(g_stopNewOrders) {
      Log(3, "New orders blocked: Stop New Orders mode active");
      return;
   }
   
   if(g_noWork) {
      Log(3, "New orders blocked: No Work mode active");
      return;
   }
   
   // Handle orders during total trailing based on mode
   if(g_trailActive && TrailOrderMode == TRAIL_ORDERS_NONE) {
      Log(3, "New orders blocked: total trailing active (mode: no orders)");
      return;
   }
   
   // Check for missed adjacent orders if flexible placement is enabled
   if(OrderPlacementType == ORDER_PLACEMENT_FLEXIBLE) {
      PlaceMissedAdjacentOrders();
   }
   
   double nowAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double nowBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   
   // Initialize static variables
   if(g_prevAsk == 0.0) g_prevAsk = nowAsk;
   if(g_prevBid == 0.0) g_prevBid = nowBid;
   
   // Determine if BUY/SELL orders are allowed during trail based on direction mode
   bool allowBuy = true;
   bool allowSell = true;
   
   if(g_trailActive) {
      if(TrailOrderMode == TRAIL_ORDERS_PROFIT_DIR) {
         // Profit direction: only allow orders in the direction of net exposure
         if(g_netLots < 0) allowBuy = false;  // SELL exposed, block BUY
         if(g_netLots > 0) allowSell = false; // BUY exposed, block SELL
      }
      else if(TrailOrderMode == TRAIL_ORDERS_REVERSE_DIR) {
         // Reverse direction: only allow orders opposite to net exposure (hedging)
         if(g_netLots > 0) allowBuy = false;  // BUY exposed, block more BUY
         if(g_netLots < 0) allowSell = false; // SELL exposed, block more SELL
      }
   }
   
   // BUY logic - price moving up
   // BUY executes at ASK, so trigger should ensure ASK crosses level + half spread
   if(nowAsk > g_prevAsk && allowBuy) {
      int Llo = PriceLevelIndex(MathMin(g_prevAsk, nowAsk), g_adaptiveGap) - 2;
      int Lhi = PriceLevelIndex(MathMax(g_prevAsk, nowAsk), g_adaptiveGap) + 2;
      
      for(int L = Llo; L <= Lhi; L++) {
         if(!IsEven(L)) continue;
         
         // BUY trigger: level price + half spread (so ASK crosses the level accounting for spread)
         double trigger = LevelPrice(L, g_adaptiveGap) + (spread / 2.0);
         if(g_prevAsk <= trigger && nowAsk > trigger) {
            Log(2, StringFormat("[PLACE-CHECK] BUY L%d triggered | Trigger=%.5f PrevAsk=%.5f NowAsk=%.5f", 
                L, trigger, g_prevAsk, nowAsk));
            
            if(HasOrderOnLevel(POSITION_TYPE_BUY, L, g_adaptiveGap)) {
               Log(2, StringFormat("[PLACE-BLOCKED-LEVEL] BUY L%d | HasOrderOnLevel returned true", L));
               continue;
            }
            if(HasOrderAtPrice(POSITION_TYPE_BUY, L, g_adaptiveGap)) {
               Log(2, StringFormat("[PLACE-BLOCKED-PRICE] BUY L%d | HasOrderAtPrice returned true", L));
               continue;
            }
            if(!IsOrderPlacementAllowed(POSITION_TYPE_BUY, L, g_adaptiveGap)) {
               continue;
            }
            
            Log(2, StringFormat("[PLACE-EXECUTE] BUY L%d | Checks passed, placing order...", L));
            double equity = AccountInfoDouble(ACCOUNT_EQUITY);
            double cycleProfit = equity - g_lastCloseEquity;
            double bookedProfit = cycleProfit - g_totalProfit;
            string orderComment = StringFormat("E%.0fBP%.0fB%d", g_lastCloseEquity, bookedProfit, L);
            if(ExecuteOrder(POSITION_TYPE_BUY, g_nextBuyLot, orderComment)) {
               // Track max lot size (intended lot size, not split execution)
               if(g_nextBuyLot > g_maxLotsCycle) g_maxLotsCycle = g_nextBuyLot;
               if(g_nextBuyLot > g_overallMaxLotSize) g_overallMaxLotSize = g_nextBuyLot;
               Log(1, StringFormat("BUY %.2f @ L%d (%.5f)", g_nextBuyLot, L, nowAsk));
            }
         }
      }
   }
   
   // SELL logic - price moving down
   // SELL executes at BID, so trigger should ensure BID crosses level - half spread
   if(nowBid < g_prevBid && allowSell) {
      int Llo = PriceLevelIndex(MathMin(g_prevBid, nowBid), g_adaptiveGap) - 2;
      int Lhi = PriceLevelIndex(MathMax(g_prevBid, nowBid), g_adaptiveGap) + 2;
      
      for(int L = Lhi; L >= Llo; L--) {
         if(!IsOdd(L)) continue;
         
         // SELL trigger: level price - half spread (so BID crosses the level accounting for spread)
         double trigger = LevelPrice(L, g_adaptiveGap) - (spread / 2.0);
         if(g_prevBid >= trigger && nowBid < trigger) {
            Log(2, StringFormat("[PLACE-CHECK] SELL L%d triggered | Trigger=%.5f PrevBid=%.5f NowBid=%.5f", 
                L, trigger, g_prevBid, nowBid));
            
            if(HasOrderOnLevel(POSITION_TYPE_SELL, L, g_adaptiveGap)) {
               Log(2, StringFormat("[PLACE-BLOCKED-LEVEL] SELL L%d | HasOrderOnLevel returned true", L));
               continue;
            }
            if(HasOrderAtPrice(POSITION_TYPE_SELL, L, g_adaptiveGap)) {
               Log(2, StringFormat("[PLACE-BLOCKED-PRICE] SELL L%d | HasOrderAtPrice returned true", L));
               continue;
            }
            if(!IsOrderPlacementAllowed(POSITION_TYPE_SELL, L, g_adaptiveGap)) {
               continue;
            }
            
            Log(2, StringFormat("[PLACE-EXECUTE] SELL L%d | Checks passed, placing order...", L));
            double equity = AccountInfoDouble(ACCOUNT_EQUITY);
            double cycleProfit = equity - g_lastCloseEquity;
            double bookedProfit = cycleProfit - g_totalProfit;
            string orderComment = StringFormat("E%.0fBP%.0fS%d", g_lastCloseEquity, bookedProfit, L);
            if(ExecuteOrder(POSITION_TYPE_SELL, g_nextSellLot, orderComment)) {
               // Track max lot size (intended lot size, not split execution)
               if(g_nextSellLot > g_maxLotsCycle) g_maxLotsCycle = g_nextSellLot;
               if(g_nextSellLot > g_overallMaxLotSize) g_overallMaxLotSize = g_nextSellLot;
               Log(1, StringFormat("SELL %.2f @ L%d (%.5f)", g_nextSellLot, L, nowBid));
            }
         }
      }
   }
   
   g_prevAsk = nowAsk;
   g_prevBid = nowBid;
}

//============================= NEXT LEVEL LINES ===================//
