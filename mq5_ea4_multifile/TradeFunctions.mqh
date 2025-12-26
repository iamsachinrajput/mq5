//+------------------------------------------------------------------+
//| TradeFunctions.mqh                                               |
//| Trading execution, order placement, and trailing logic          |
//+------------------------------------------------------------------+

//============================= ORDER EXECUTION WITH LOT SPLITTING ==//
bool ExecuteOrder(int orderType, double lotSize, string comment = "") {
   if(lotSize <= 0) {
      Log(1, "ExecuteOrder: Invalid lot size");
      return false;
   }
   
   // Extract level from comment if available (format: "E...BP...B14" or "E...BP...S-15")
   int orderLevel = 0;
   if(StringLen(comment) > 0) {
      int pos = StringFind(comment, orderType == POSITION_TYPE_BUY ? "B" : "S", 0);
      if(pos >= 0 && pos < StringLen(comment) - 1) {
         string levelStr = StringSubstr(comment, pos + 1);
         orderLevel = (int)StringToInteger(levelStr);
      }
   }
   
   double maxLotPerOrder = 20.0;
   int ordersNeeded = (int)MathCeil(lotSize / maxLotPerOrder);
   
   if(ordersNeeded == 1) {
      // Single order - execute directly
      trade.SetExpertMagicNumber(Magic);
      bool result = false;
      if(orderType == POSITION_TYPE_BUY) {
         result = trade.Buy(lotSize, _Symbol, 0, 0, 0, comment);
      } else {
         result = trade.Sell(lotSize, _Symbol, 0, 0, 0, comment);
      }
      
      // Record successful order placement
      if(result && orderLevel != 0) {
         ulong ticket = trade.ResultOrder();
         if(ticket == 0) ticket = trade.ResultDeal();
         
         string typeStr = (orderType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
         datetime currentTime = TimeCurrent();
         
         // Get actual execution price from position
         double price = 0.0;
         datetime openTime = currentTime;
         if(PositionSelectByTicket(ticket)) {
            price = PositionGetDouble(POSITION_PRICE_OPEN);
            openTime = (datetime)PositionGetInteger(POSITION_TIME);
         } else {
            // Fallback to current market price if position not found
            price = (orderType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
         }
         
         // Add to tracking array
         AddOrderToTracking(ticket, orderType, orderLevel, price, lotSize);
         
         // Create open order label with actual execution price
         CreateOpenOrderLabel(ticket, orderLevel, orderType, lotSize, price, openTime);
         
         Log(2, StringFormat("[ORDER-RECORDED] %s L%d @ %s | Lot=%.2f Ticket=%d Price=%.5f", 
             typeStr, orderLevel, TimeToString(currentTime, TIME_SECONDS), lotSize, ticket, price));
         
         // Log trade action
         string reason = (orderType == POSITION_TYPE_BUY) ? g_nextBuyReason : g_nextSellReason;
         LogOrderOpen(ticket, orderType, lotSize, orderLevel, reason);
      }
      
      // Apply delay if configured
      if(result && OrderPlacementDelayMs > 0) {
         Sleep(OrderPlacementDelayMs);
      }
      
      return result;
   }
   
   // Multiple orders needed - split the lot size
   double remainingLots = lotSize;
   int successCount = 0;
   bool firstOrderPlaced = false;
   
   Log(2, StringFormat("ExecuteOrder: Splitting %.2f lots into %d orders (max %.2f per order)",
       lotSize, ordersNeeded, maxLotPerOrder));
   
   for(int i = 0; i < ordersNeeded; i++) {
      double currentLot = MathMin(remainingLots, maxLotPerOrder);
      
      // Normalize to broker requirements
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      
      currentLot = MathMax(currentLot, minLot);
      currentLot = MathRound(currentLot / stepLot) * stepLot;
      currentLot = MathMin(currentLot, maxLot);
      
      string orderComment = comment;
      if(ordersNeeded > 1) {
         orderComment = StringFormat("%s [%d/%d]", comment, i + 1, ordersNeeded);
      }
      
      trade.SetExpertMagicNumber(Magic);
      bool result = false;
      
      if(orderType == POSITION_TYPE_BUY) {
         result = trade.Buy(currentLot, _Symbol, 0, 0, 0, orderComment);
      } else {
         result = trade.Sell(currentLot, _Symbol, 0, 0, 0, orderComment);
      }
      
      if(result) {
         ulong ticket = trade.ResultOrder();
         if(ticket == 0) ticket = trade.ResultDeal();
         
         successCount++;
         remainingLots -= currentLot;
         Log(2, StringFormat("ExecuteOrder: Order %d/%d placed: %.2f lots (%.2f remaining)",
             i + 1, ordersNeeded, currentLot, remainingLots));
         
         // Add to tracking array
         if(orderLevel != 0) {
            // Get actual execution price from position
            double price = 0.0;
            datetime openTime = TimeCurrent();
            if(PositionSelectByTicket(ticket)) {
               price = PositionGetDouble(POSITION_PRICE_OPEN);
               openTime = (datetime)PositionGetInteger(POSITION_TIME);
            } else {
               // Fallback to current market price if position not found
               price = (orderType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
            }
            
            AddOrderToTracking(ticket, orderType, orderLevel, price, currentLot);
            
            // Create open order label for each split order with actual execution price
            CreateOpenOrderLabel(ticket, orderLevel, orderType, currentLot, price, openTime);
            
            if(!firstOrderPlaced) {
               string typeStr = (orderType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
               Log(2, StringFormat("[ORDER-RECORDED-SPLIT] %s L%d Ticket=%d | Lot=%.2f (split %d/%d)", 
                   typeStr, orderLevel, ticket, currentLot, i+1, ordersNeeded));
               firstOrderPlaced = true;
               
               // Log trade action for the first split order
               string reason = (orderType == POSITION_TYPE_BUY) ? g_nextBuyReason : g_nextSellReason;
               LogOrderOpen(ticket, orderType, lotSize, orderLevel, reason);
            }
         }
         
         // Apply delay between split orders if configured
         if(OrderPlacementDelayMs > 0) {
            Sleep(OrderPlacementDelayMs);
         }
      } else {
         Log(1, StringFormat("ExecuteOrder: Failed to place order %d/%d: %.2f lots",
             i + 1, ordersNeeded, currentLot));
      }
   }
   
   bool allSuccess = (successCount == ordersNeeded);
   if(!allSuccess) {
      Log(1, StringFormat("ExecuteOrder: Partial fill - %d/%d orders succeeded",
          successCount, ordersNeeded));
   }
   
   return allSuccess;
}

//============================= DUPLICATE CHECK ====================//
bool HasOrderOnLevel(int orderType, int level, double gap) {
   // Primary check: use our tracking array
   if(HasOrderAtLevelTracked(orderType, level)) {
      return true;
   }
   
   // Secondary check: verify against live server positions (silent - SyncOrderTracking will add it next tick)
   // This is just a safety net for the rare case where an order exists but hasn't been synced yet
   double levelPrice = NormalizeDouble(LevelPrice(level, gap), _Digits);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
      
      int type = (int)PositionGetInteger(POSITION_TYPE);
      double openPrice = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN), _Digits);
      
      if(type == orderType && MathAbs(openPrice - levelPrice) < gap * 0.1) {
         // Found on server - SyncOrderTracking will add it to tracking array on next tick
         // No need to log repeatedly, sync function will log [TRACK-ADD] once
         return true;
      }
   }
   return false;
}

// Check for orders of same type within a small price distance (prevents duplicates)
bool HasOrderAtPrice(int orderType, int level, double gap) {
   string typeStr = (orderType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
   datetime currentTime = TimeCurrent();
   double levelPrice = LevelPrice(level, gap);
   double tolerance = gap * 0.45; // Nearly half gap distance for safety
   
   Log(3, StringFormat("[DUP-CHECK] %s L%d | LevelPrice=%.5f Tolerance=%.5f Gap=%.5f", 
       typeStr, level, levelPrice, tolerance, gap));
   
   // Check if we recently placed an order at this level (within last 15 seconds)
   for(int i = 0; i < g_orderCount; i++) {
      if(g_orders[i].isValid && g_orders[i].type == orderType && g_orders[i].level == level) {
         int timeDiff = (int)(currentTime - g_orders[i].openTime);
         if(timeDiff <= 15) {
            Log(2, StringFormat("[DUP-BLOCKED-TIME] %s L%d | Last order %d seconds ago", 
                typeStr, level, timeDiff));
            return true; // Block - we just placed order here
         }
      }
   }
   
   // Also check existing positions
   int positionsChecked = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
      
      int type = (int)PositionGetInteger(POSITION_TYPE);
      if(type != orderType) continue;
      
      positionsChecked++;
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double priceDistance = MathAbs(openPrice - levelPrice);
      
      Log(3, StringFormat("[DUP-CHECK] Position #%I64u %s @ %.5f | Distance=%.5f Tolerance=%.5f", 
          ticket, typeStr, openPrice, priceDistance, tolerance));
      
      if(priceDistance < tolerance) {
         Log(2, StringFormat("[DUP-BLOCKED-PRICE] %s L%d | Found position #%I64u @ %.5f (distance=%.5f < tolerance=%.5f)", 
             typeStr, level, ticket, openPrice, priceDistance, tolerance));
         return true;
      }
   }
   
   Log(3, StringFormat("[DUP-CHECK] %s L%d | Checked %d positions - ALLOW ORDER", 
       typeStr, level, positionsChecked));
   return false;
}

// Check if order exists at a specific level by parsing comment field
// More reliable than price-based checks when there's market delay
// Comment format: "E...BP...B6" (BUY level 6) or "E...BP...S-3" (SELL level -3)
bool HasOrderAtLevelByComment(int orderType, int level) {
   string searchPattern = (orderType == POSITION_TYPE_BUY) ? "B" : "S";
   string levelStr = IntegerToString(level);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
      
      int type = (int)PositionGetInteger(POSITION_TYPE);
      if(type != orderType) continue;
      
      string comment = PositionGetString(POSITION_COMMENT);
      
      // Find the position of B or S in the comment
      int bPos = StringFind(comment, "B", 0);
      int sPos = StringFind(comment, "S", 0);
      int levelPos = -1;
      
      // Determine which marker to use based on order type
      if(orderType == POSITION_TYPE_BUY && bPos >= 0) {
         // For BUY, find the last 'B' in comment (after BP)
         int lastBPos = bPos;
         int searchPos = bPos + 1;
         while(searchPos < StringLen(comment)) {
            int nextB = StringFind(comment, "B", searchPos);
            if(nextB < 0) break;
            lastBPos = nextB;
            searchPos = nextB + 1;
         }
         levelPos = lastBPos;
      } else if(orderType == POSITION_TYPE_SELL && sPos >= 0) {
         // For SELL, find the last 'S' in comment
         int lastSPos = sPos;
         int searchPos = sPos + 1;
         while(searchPos < StringLen(comment)) {
            int nextS = StringFind(comment, "S", searchPos);
            if(nextS < 0) break;
            lastSPos = nextS;
            searchPos = nextS + 1;
         }
         levelPos = lastSPos;
      }
      
      if(levelPos >= 0 && levelPos < StringLen(comment) - 1) {
         string extractedLevel = StringSubstr(comment, levelPos + 1);
         int commentLevel = (int)StringToInteger(extractedLevel);
         
         if(commentLevel == level) {
            Log(3, StringFormat("[COMMENT-CHECK] Found %s order at L%d via comment: %s",
                searchPattern, level, comment));
            return true;
         }
      }
   }
   
   return false;
}

bool HasOrderNearLevel(int orderType, int level, double gap, int window) {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
      
      int type = (int)PositionGetInteger(POSITION_TYPE);
      if(type != orderType) continue;
      
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      int existingLevel = PriceLevelIndex(openPrice, gap);
      int distance = (int)MathAbs(existingLevel - level);
      
      if(distance <= window) return true;
   }
   return false;
}

// Check if order placement is allowed based on strategy
// Returns true if order can be placed, false if blocked by strategy
bool IsOrderPlacementAllowed(int orderType, int level, double gap) {
   // If no strategy, always allow
   if(OrderPlacementStrategy == ORDER_STRATEGY_NONE) {
      return true;
   }
   
   // If no open positions, always allow first order
   if(PositionsTotal() == 0) {
      Log(3, "[STRATEGY] No positions - allowing first order");
      return true;
   }
   
   // Boundary Check Directional Strategy (Waiting for Direction Change):
   // BUY at level L - needs N SELL orders below it (SELL level < BUY level)
   // SELL at level L - needs N BUY orders above it (BUY level > SELL level)
   // Where N = BoundaryDirectionalCount input parameter
   if(OrderPlacementStrategy == ORDER_STRATEGY_BOUNDARY_DIRECTIONAL) {
      string typeStr = (orderType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
      
      int opposingCount = 0;
      
      // Use tracking array for authentic levels from comments
      for(int i = 0; i < g_orderCount; i++) {
         if(!g_orders[i].isValid) continue;
         
         int type = g_orders[i].type;
         int existingLevel = g_orders[i].level;
         
         if(orderType == POSITION_TYPE_BUY) {
            // BUY order - need SELL below (SELL level < BUY level)
            if(type == POSITION_TYPE_SELL && existingLevel < level) {
               opposingCount++;
            }
         } else {
            // SELL order - need BUY above (BUY level > SELL level)
            if(type == POSITION_TYPE_BUY && existingLevel > level) {
               opposingCount++;
            }
         }
      }
      
      if(opposingCount < BoundaryDirectionalCount) {
         string direction = (orderType == POSITION_TYPE_BUY) ? "below" : "above";
         string opposingType = (orderType == POSITION_TYPE_BUY) ? "SELL" : "BUY";
         // Get nearby orders for context
         string nearbyOrders = GetNearbyOrdersText(level, 5);
         Log(2, StringFormat("[STRATEGY-BLOCKED] %s L%d | Need %d %s orders %s, found %d | Nearby: %s",
             typeStr, level, BoundaryDirectionalCount, opposingType, direction, opposingCount, nearbyOrders));
         return false;
      }
      
      Log(3, StringFormat("[STRATEGY-PASSED] %s L%d | Found %d/%d opposing orders - direction change detected",
          typeStr, level, opposingCount, BoundaryDirectionalCount));
      return true;
   }
   
   // Far Adjacent Strategy:
   // Check for opposite-type orders starting from a specified distance
   // FarAdjacentDistance: Where to start checking (1=adjacent, 3=skip 1 level, 5=skip 2 levels)
   // FarAdjacentDepth: How many opposite-type levels to check from starting point
   // Example: BUY at L6, Distance=3, Depth=2 checks SELL at L3, L1
   // Example: BUY at L6, Distance=5, Depth=3 checks SELL at L1, L-1, L-3
   // Exception: Top BUY or Bottom SELL can always be placed
   if(OrderPlacementStrategy == ORDER_STRATEGY_FAR_ADJACENT) {
      string typeStr = (orderType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
      
      // First, check if this is a boundary order (topmost BUY or bottommost SELL)
      bool isTopBuy = false;
      bool isBottomSell = false;
      
      if(orderType == POSITION_TYPE_BUY) {
         // Check if there are any BUY orders above this level
         isTopBuy = true;
         for(int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if(!PositionSelectByTicket(ticket)) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
            
            int type = (int)PositionGetInteger(POSITION_TYPE);
            if(type != POSITION_TYPE_BUY) continue;
            
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            int existingLevel = PriceLevelIndex(openPrice, gap);
            
            if(existingLevel > level) {
               isTopBuy = false;
               break;
            }
         }
         
         if(isTopBuy) {
            Log(3, StringFormat("[STRATEGY-PASSED] %s L%d | Top BUY - no far adjacent check needed",
                typeStr, level));
            return true;
         }
      } else {
         // Check if there are any SELL orders below this level
         isBottomSell = true;
         for(int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if(!PositionSelectByTicket(ticket)) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
            
            int type = (int)PositionGetInteger(POSITION_TYPE);
            if(type != POSITION_TYPE_SELL) continue;
            
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            int existingLevel = PriceLevelIndex(openPrice, gap);
            
            if(existingLevel < level) {
               isBottomSell = false;
               break;
            }
         }
         
         if(isBottomSell) {
            Log(3, StringFormat("[STRATEGY-PASSED] %s L%d | Bottom SELL - no far adjacent check needed",
                typeStr, level));
            return true;
         }
      }
      
      // Not a boundary order, check for opposite-type orders starting from specified distance
      int requiredType = (orderType == POSITION_TYPE_BUY) ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;
      string requiredTypeStr = (requiredType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
      
      // Calculate starting level based on distance
      int startLevel;
      if(orderType == POSITION_TYPE_BUY) {
         // BUY at level L: start checking at L - FarAdjacentDistance
         startLevel = level - FarAdjacentDistance;
      } else {
         // SELL at level L: start checking at L + FarAdjacentDistance
         startLevel = level + FarAdjacentDistance;
      }
      
      // Check FarAdjacentDepth levels, each 2 apart
      bool hasOppositeOrder = false;
      int foundAtLevel = 0;
      
      for(int depthIdx = 0; depthIdx < FarAdjacentDepth; depthIdx++) {
         int checkLevel;
         
         if(orderType == POSITION_TYPE_BUY) {
            // BUY: check SELL at startLevel, startLevel-2, startLevel-4, ...
            checkLevel = startLevel - (2 * depthIdx);
         } else {
            // SELL: check BUY at startLevel, startLevel+2, startLevel+4, ...
            checkLevel = startLevel + (2 * depthIdx);
         }
         
         // Check tracking array for order at this level
         for(int i = 0; i < g_orderCount; i++) {
            if(!g_orders[i].isValid) continue;
            if(g_orders[i].type != requiredType) continue;
            
            if(g_orders[i].level == checkLevel) {
               hasOppositeOrder = true;
               foundAtLevel = checkLevel;
               break;
            }
         }
         
         if(hasOppositeOrder) break;
      }
      
      if(hasOppositeOrder) {
         Log(3, StringFormat("[STRATEGY-PASSED] %s L%d | Found %s at L%d (Distance=%d, Depth=%d)",
             typeStr, level, requiredTypeStr, foundAtLevel, FarAdjacentDistance, FarAdjacentDepth));
         return true;
      } else {
         // Get nearby orders for context
         string nearbyOrders = GetNearbyOrdersText(level, 5);
         Log(2, StringFormat("[STRATEGY-BLOCKED] %s L%d | No %s found (Distance=%d, Depth=%d) | Nearby: %s",
             typeStr, level, requiredTypeStr, FarAdjacentDistance, FarAdjacentDepth, nearbyOrders));
         return false;
      }
   }
   
   // Default: allow
   return true;
}

//============================= MISSED ORDER PLACEMENT =============//
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
// Resource-intensive function: calculates next available order levels
// Only runs when g_showNextLevelLines is true (controlled by button)
void UpdateNextLevelLines() {
   // Early exit if disabled - no calculations, no display
   if(!g_showNextLevelLines) {
      ObjectDelete(0, "NextBuyLevelUp");
      ObjectDelete(0, "NextBuyLevelDown");
      ObjectDelete(0, "NextSellLevelUp");
      ObjectDelete(0, "NextSellLevelDown");
      return;
   }
   
   double nowAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double nowBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = nowAsk - nowBid;
   
   // Find next available BUY level upward (check for existing orders)
   int nextBuyLevelUp = PriceLevelIndex(nowAsk, g_adaptiveGap);
   if(!IsEven(nextBuyLevelUp)) nextBuyLevelUp++;
   // Skip levels that already have orders (check both exact level and nearby)
   while((HasOrderOnLevel(POSITION_TYPE_BUY, nextBuyLevelUp, g_adaptiveGap) || 
          HasOrderNearLevel(POSITION_TYPE_BUY, nextBuyLevelUp, g_adaptiveGap, 1)) && 
         nextBuyLevelUp < 10000) {
      nextBuyLevelUp += 2; // BUY levels are even, increment by 2
   }
   double nextBuyPriceUp = LevelPrice(nextBuyLevelUp, g_adaptiveGap) + (spread / 2.0);
   
   // Find next available BUY level downward
   int nextBuyLevelDown = PriceLevelIndex(nowAsk, g_adaptiveGap);
   if(!IsEven(nextBuyLevelDown)) nextBuyLevelDown--;
   else nextBuyLevelDown -= 2;
   // Skip levels that already have orders (check both exact level and nearby)
   while((HasOrderOnLevel(POSITION_TYPE_BUY, nextBuyLevelDown, g_adaptiveGap) || 
          HasOrderNearLevel(POSITION_TYPE_BUY, nextBuyLevelDown, g_adaptiveGap, 1)) && 
         nextBuyLevelDown > -10000) {
      nextBuyLevelDown -= 2; // BUY levels are even, decrement by 2
   }
   double nextBuyPriceDown = LevelPrice(nextBuyLevelDown, g_adaptiveGap) + (spread / 2.0);
   
   // Find next available SELL level upward
   int nextSellLevelUp = PriceLevelIndex(nowBid, g_adaptiveGap);
   if(!IsOdd(nextSellLevelUp)) nextSellLevelUp++;
   else nextSellLevelUp += 2;
   // Skip levels that already have orders (check both exact level and nearby)
   while((HasOrderOnLevel(POSITION_TYPE_SELL, nextSellLevelUp, g_adaptiveGap) || 
          HasOrderNearLevel(POSITION_TYPE_SELL, nextSellLevelUp, g_adaptiveGap, 1)) && 
         nextSellLevelUp < 10000) {
      nextSellLevelUp += 2; // SELL levels are odd, increment by 2
   }
   double nextSellPriceUp = LevelPrice(nextSellLevelUp, g_adaptiveGap) - (spread / 2.0);
   
   // Find next available SELL level downward
   int nextSellLevelDown = PriceLevelIndex(nowBid, g_adaptiveGap);
   if(!IsOdd(nextSellLevelDown)) nextSellLevelDown--;
   // Skip levels that already have orders (check both exact level and nearby)
   while((HasOrderOnLevel(POSITION_TYPE_SELL, nextSellLevelDown, g_adaptiveGap) || 
          HasOrderNearLevel(POSITION_TYPE_SELL, nextSellLevelDown, g_adaptiveGap, 1)) && 
         nextSellLevelDown > -10000) {
      nextSellLevelDown -= 2; // SELL levels are odd, decrement by 2
   }
   double nextSellPriceDown = LevelPrice(nextSellLevelDown, g_adaptiveGap) - (spread / 2.0);
   
   // Create/Update BUY level line (upward) - Light Blue
   string buyLineNameUp = "NextBuyLevelUp";
   if(ObjectFind(0, buyLineNameUp) < 0) {
      ObjectCreate(0, buyLineNameUp, OBJ_HLINE, 0, 0, nextBuyPriceUp);
      ObjectSetInteger(0, buyLineNameUp, OBJPROP_COLOR, clrLightBlue);
      ObjectSetInteger(0, buyLineNameUp, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, buyLineNameUp, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, buyLineNameUp, OBJPROP_BACK, true);
      ObjectSetInteger(0, buyLineNameUp, OBJPROP_SELECTABLE, false);
   }
   ObjectSetDouble(0, buyLineNameUp, OBJPROP_PRICE, nextBuyPriceUp);
   ObjectSetString(0, buyLineNameUp, OBJPROP_TEXT, StringFormat("Next BUY ↑ L%d @ %.5f (Gap:%.1f)", nextBuyLevelUp, nextBuyPriceUp, g_adaptiveGap/_Point));
   
   // Create/Update BUY level line (downward) - Light Blue
   string buyLineNameDown = "NextBuyLevelDown";
   if(ObjectFind(0, buyLineNameDown) < 0) {
      ObjectCreate(0, buyLineNameDown, OBJ_HLINE, 0, 0, nextBuyPriceDown);
      ObjectSetInteger(0, buyLineNameDown, OBJPROP_COLOR, clrLightBlue);
      ObjectSetInteger(0, buyLineNameDown, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, buyLineNameDown, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, buyLineNameDown, OBJPROP_BACK, true);
      ObjectSetInteger(0, buyLineNameDown, OBJPROP_SELECTABLE, false);
   }
   ObjectSetDouble(0, buyLineNameDown, OBJPROP_PRICE, nextBuyPriceDown);
   ObjectSetString(0, buyLineNameDown, OBJPROP_TEXT, StringFormat("Next BUY ↓ L%d @ %.5f (Gap:%.1f)", nextBuyLevelDown, nextBuyPriceDown, g_adaptiveGap/_Point));
   
   // Create/Update SELL level line (upward) - Pink
   string sellLineNameUp = "NextSellLevelUp";
   if(ObjectFind(0, sellLineNameUp) < 0) {
      ObjectCreate(0, sellLineNameUp, OBJ_HLINE, 0, 0, nextSellPriceUp);
      ObjectSetInteger(0, sellLineNameUp, OBJPROP_COLOR, clrPink);
      ObjectSetInteger(0, sellLineNameUp, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, sellLineNameUp, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, sellLineNameUp, OBJPROP_BACK, true);
      ObjectSetInteger(0, sellLineNameUp, OBJPROP_SELECTABLE, false);
   }
   ObjectSetDouble(0, sellLineNameUp, OBJPROP_PRICE, nextSellPriceUp);
   ObjectSetString(0, sellLineNameUp, OBJPROP_TEXT, StringFormat("Next SELL ↑ L%d @ %.5f (Gap:%.1f)", nextSellLevelUp, nextSellPriceUp, g_adaptiveGap/_Point));
   
   // Create/Update SELL level line (downward) - Pink
   string sellLineNameDown = "NextSellLevelDown";
   if(ObjectFind(0, sellLineNameDown) < 0) {
      ObjectCreate(0, sellLineNameDown, OBJ_HLINE, 0, 0, nextSellPriceDown);
      ObjectSetInteger(0, sellLineNameDown, OBJPROP_COLOR, clrPink);
      ObjectSetInteger(0, sellLineNameDown, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, sellLineNameDown, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, sellLineNameDown, OBJPROP_BACK, true);
      ObjectSetInteger(0, sellLineNameDown, OBJPROP_SELECTABLE, false);
   }
   ObjectSetDouble(0, sellLineNameDown, OBJPROP_PRICE, nextSellPriceDown);
   ObjectSetString(0, sellLineNameDown, OBJPROP_TEXT, StringFormat("Next SELL ↓ L%d @ %.5f (Gap:%.1f)", nextSellLevelDown, nextSellPriceDown, g_adaptiveGap/_Point));
}

//============================= CLOSE ALL WRAPPER ==================//
void PerformCloseAll(string reason = "Manual") {
   // Calculate cycle stats before closing (for vline info)
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double cycleProfit = equity - g_lastCloseEquity;
   double openProfit = g_totalProfit;
   double bookedCycle = cycleProfit - openProfit;
   
   Log(1, StringFormat("CLOSE ALL (%s): profit=%.2f (open=%.2f booked=%.2f) | Positions: BUY:%d SELL:%d", 
       reason, cycleProfit, openProfit, bookedCycle, g_buyCount, g_sellCount));
   
   // Log total close action
   LogTotalCloseAll(reason, cycleProfit);
   
   // Close all positions
   int closedCount = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
      
      CreateCloseLabelBeforeClose(ticket);
      if(trade.PositionClose(ticket)) {
         closedCount++;
      }
   }
   
   Log(1, StringFormat("%d positions closed", closedCount));
   
   // Draw vertical line with trail & profit info at close
   datetime nowTime = TimeCurrent();
   string vlineName = StringFormat("%s_P%.02f_E%.0f", reason, cycleProfit, equity);
   
   // Delete old object if it exists
   ObjectDelete(0, vlineName);
   
   // Create vertical line
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ObjectCreate(0, vlineName, OBJ_VLINE, 0, nowTime, currentPrice)) {
      // Set color based on profit: yellow for -1 to +1, green for > 1, red for < -1
      color lineColor = (cycleProfit > 1.0) ? clrGreen : (cycleProfit < -1.0) ? clrRed : clrYellow;
      ObjectSetInteger(0, vlineName, OBJPROP_COLOR, lineColor);
      
      // Set line width proportional to profit: base 1, +1 for every 5 profit, max 10
      int lineWidth = 1 + (int)(MathAbs(cycleProfit) / 5.0);
      lineWidth = MathMin(lineWidth, 10);
      lineWidth = MathMax(lineWidth, 1);
      ObjectSetInteger(0, vlineName, OBJPROP_WIDTH, lineWidth);
      
      ObjectSetInteger(0, vlineName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, vlineName, OBJPROP_BACK, true);
      ObjectSetInteger(0, vlineName, OBJPROP_SELECTABLE, false);
      string vlinetext = StringFormat("P:%.2f/%.2f/%.2f(L%.2f)ML%.2f/%.2f L%.2f/%.2f", 
            cycleProfit, g_trailFloor, g_trailPeak, bookedCycle, 
            -g_maxLossCycle, -g_overallMaxLoss, g_maxLotsCycle, g_overallMaxLotSize);
      ObjectSetString(0, vlineName, OBJPROP_TEXT, vlinetext);
      ChartRedraw(0);
      
      Log(1, StringFormat("VLine created: %s (color: %s, width: %d) | Text: %s", 
          vlineName, 
          (cycleProfit > 1.0) ? "GREEN" : (cycleProfit < -1.0) ? "RED" : "YELLOW", 
          lineWidth, vlinetext));
   }
   
   // Record close profit in history (shift array and add new)
   for(int i = 4; i > 0; i--) {
      g_last5Closes[i] = g_last5Closes[i-1];
   }
   g_last5Closes[0] = cycleProfit;
   g_closeCount++;
   
   // Reset cycle parameters
   g_lastCloseEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_maxLossCycle = 0.0;
   g_maxProfitCycle = 0.0;
   g_maxLotsCycle = 0.0;
   g_lastMaxLossVline = 0.0;
   g_trailActive = false;
   g_trailStart = 0.0;
   g_trailGap = 0.0;
   g_trailPeak = 0.0;
   g_trailFloor = 0.0;
   
   // Delete total trail line
   ObjectDelete(0, "total_trail");
   
   // Apply pending button actions (single-click delayed actions)
   if(g_pendingStopNewOrders) {
      g_stopNewOrders = true;
      g_noWork = false; // Ensure mutual exclusivity
      g_pendingStopNewOrders = false;
      UpdateButtonStates();
      Log(1, "Pending Stop New Orders: ENABLED after close-all");
   }
   if(g_pendingNoWork) {
      g_noWork = true;
      g_stopNewOrders = false; // Ensure mutual exclusivity
      g_pendingNoWork = false;
      UpdateButtonStates();
      Log(1, "Pending No Work Mode: ENABLED after close-all");
   }
   
   Log(1, StringFormat("Cycle RESET: new equity=%.2f | Close count=%d", g_lastCloseEquity, g_closeCount));
}

//============================= TOTAL PROFIT TRAIL =================//
void TrailTotalProfit() {
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
int FindTrailIndex(ulong ticket) {
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
// Trail combined profit of farthest losing orders + farthest profitable orders
// useSameTypeOnly: if true, only close same-type orders together; if false, can close any-side orders
void UpdateGroupTrailing(bool useSameTypeOnly = false) {
   if(!EnableSingleTrailing) return;
   if(g_trailActive) return; // Skip when total trailing active
   if(g_noWork) return;
   
   // Check if we have minimum GLO orders required
   if(g_orders_in_loss < MinGLOForGroupTrail) {
      Log(3, StringFormat("GT | Skip: Only %d GLO orders (need %d minimum)", g_orders_in_loss, MinGLOForGroupTrail));
      return;
   }
   
   // Find single worst losing order (either BUY or SELL, whichever has more loss)
   ulong worstLossTicket = 0;
   double worstLoss = 0.0;
   int worstLossType = -1;
   
   // Track ALL profitable orders from any side
   struct ProfitableOrder {
      ulong ticket;
      double profit;
      int type;
      double lots;
   };
   ProfitableOrder profitableOrders[];
   int profitableCount = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
      
      int type = (int)PositionGetInteger(POSITION_TYPE);
      double profit = PositionGetDouble(POSITION_PROFIT);
      double lots = PositionGetDouble(POSITION_VOLUME);
      
      if(profit < 0) {
         // Track single worst losing order
         double absLoss = MathAbs(profit);
         if(absLoss > worstLoss) {
            worstLoss = absLoss;
            worstLossTicket = ticket;
            worstLossType = type;
         }
      } else if(profit > 0) {
         // Store profitable orders based on mode
         // If useSameTypeOnly is true, only include same-type profitable orders
         // If useSameTypeOnly is false, include all profitable orders (any side)
         bool shouldInclude = !useSameTypeOnly || (useSameTypeOnly && type == worstLossType);
         
         if(shouldInclude) {
            ArrayResize(profitableOrders, profitableCount + 1);
            profitableOrders[profitableCount].ticket = ticket;
            profitableOrders[profitableCount].profit = profit;
            profitableOrders[profitableCount].type = type;
            profitableOrders[profitableCount].lots = lots;
            profitableCount++;
         }
      }
   }
   
   // Need at least one losing order and some profitable orders to trail
   if(worstLossTicket == 0 || profitableCount == 0) {
      if(worstLossTicket > 0 && profitableCount == 0 && SingleTrailMethod == SINGLE_TRAIL_CLOSETOGETHER_SAMETYPE) {
         string lossTypeStr = (worstLossType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
         Log(3, StringFormat("GT | Skip: Worst loss is %s but no profitable %s orders found", lossTypeStr, lossTypeStr));
      }
      g_groupTrail.active = false;
      return;
   }
   
   // Get exact loss value
   double totalLoss = 0.0;
   if(PositionSelectByTicket(worstLossTicket)) {
      totalLoss = PositionGetDouble(POSITION_PROFIT); // Negative value
   }
   
   // Sort profitable orders by profit (highest first) to select farthest in profit
   for(int i = 0; i < profitableCount - 1; i++) {
      for(int j = i + 1; j < profitableCount; j++) {
         if(profitableOrders[j].profit > profitableOrders[i].profit) {
            ProfitableOrder temp = profitableOrders[i];
            profitableOrders[i] = profitableOrders[j];
            profitableOrders[j] = temp;
         }
      }
   }
   
   // Select only enough farthest profitable orders to cover losses and make group profitable
   double selectedProfit = 0.0;
   int selectedCount = 0;
   ulong selectedTickets[];
   
   for(int i = 0; i < profitableCount; i++) {
      selectedProfit += profitableOrders[i].profit;
      ArrayResize(selectedTickets, selectedCount + 1);
      selectedTickets[selectedCount] = profitableOrders[i].ticket;
      selectedCount++;
      
      // Stop when we have enough profit to cover losses with some margin
      if(selectedProfit + totalLoss > 0) {
         break;
      }
   }
   
   // Calculate combined profit (selected profitable orders + single worst loss order)
   double combinedProfit = selectedProfit + totalLoss;
   int groupCount = selectedCount + 1; // 1 loss order + selected profitable orders
   
   // Calculate threshold and gap if not active
   if(!g_groupTrail.active) {
      double threshold = CalculateSingleThreshold();
      g_groupTrail.threshold = threshold;
      g_groupTrail.gap = threshold * 0.50; // 50% gap like single trailing
      g_groupTrail.peakProfit = 0.0;
      // Store the worst loss ticket in appropriate field based on type
      if(worstLossType == POSITION_TYPE_BUY) {
         g_groupTrail.farthestBuyTicket = worstLossTicket;
         g_groupTrail.farthestSellTicket = 0;
      } else {
         g_groupTrail.farthestBuyTicket = 0;
         g_groupTrail.farthestSellTicket = worstLossTicket;
      }
   }
   
   // Update peak
   if(combinedProfit > g_groupTrail.peakProfit) {
      g_groupTrail.peakProfit = combinedProfit;
   }
   
   // Check if group should start trailing (with activation buffer)
   string worstLossTypeStr = (worstLossType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
   double activationThreshold = g_groupTrail.threshold * (1.0 + GroupActivationBuffer);
   if(!g_groupTrail.active && combinedProfit >= activationThreshold) {
      g_groupTrail.active = true;
      Log(1, StringFormat("GT ACTIVE | Combined=%.2f Peak=%.2f Threshold=%.2f | Loss: %s #%I64u (%.2f) | Selected %d profitable orders (%.2f profit)",
          combinedProfit, g_groupTrail.peakProfit, activationThreshold, worstLossTypeStr, worstLossTicket, totalLoss, selectedCount, selectedProfit));
      
      // Log group trail start
      string reason = StringFormat("Combined:%.2f >= Threshold:%.2f Loss:%s (%.2f) Profit:%d orders (%.2f)", 
                                   combinedProfit, activationThreshold, worstLossTypeStr, totalLoss, selectedCount, selectedProfit);
      LogGroupTrailStart(combinedProfit, reason);
   }
   
   // Trail logic
   if(g_groupTrail.active) {
      double dropFromPeak = g_groupTrail.peakProfit - combinedProfit;
      
      // Periodic logging (every 10 ticks)
      if((int)GetTickCount() - g_groupTrail.lastLogTick > 10) {
         Log(2, StringFormat("GT | Combined=%.2f Peak=%.2f Drop=%.2f Gap=%.2f | Group: %d orders (%d profitable, 1 loss %s)",
             combinedProfit, g_groupTrail.peakProfit, dropFromPeak, g_groupTrail.gap, groupCount, selectedCount, worstLossTypeStr));
         g_groupTrail.lastLogTick = (int)GetTickCount();
      }
      
      // Close group if profit drops below trail gap AND combined profit is above minimum
      if(dropFromPeak >= g_groupTrail.gap) {
         // Safety check: don't close if combined profit is below minimum threshold
         if(combinedProfit < MinGroupProfitToClose) {
            Log(2, StringFormat("GT HOLD | Combined=%.2f < MinProfit=%.2f | Drop=%.2f >= Gap=%.2f | Waiting for recovery",
                combinedProfit, MinGroupProfitToClose, dropFromPeak, g_groupTrail.gap));
            // Reset peak to current to give it another chance to recover
            g_groupTrail.peakProfit = combinedProfit;
            return;
         }
         
         Log(1, StringFormat("GT CLOSE | Combined=%.2f Peak=%.2f Drop=%.2f >= Gap=%.2f",
             combinedProfit, g_groupTrail.peakProfit, dropFromPeak, g_groupTrail.gap));
         
         // Log group trail close action
         string groupReason = StringFormat("Combined:%.2f Peak:%.2f Drop:%.2f Gap:%.2f", 
                                           combinedProfit, g_groupTrail.peakProfit, dropFromPeak, g_groupTrail.gap);
         LogGroupClose(combinedProfit, groupReason);
         
         int closedCount = 0;
         double closedProfit = 0.0;
         
         // Close the single worst losing order
         if(PositionSelectByTicket(worstLossTicket)) {
            double lots = PositionGetDouble(POSITION_VOLUME);
            double profit = PositionGetDouble(POSITION_PROFIT);
            CreateCloseLabelBeforeClose(worstLossTicket);
            if(trade.PositionClose(worstLossTicket)) {
               closedCount++;
               closedProfit += profit;
               Log(1, StringFormat("GT CLOSE #%I64u %s %.2f lots | Loss=%.2f",
                   worstLossTicket, worstLossTypeStr, lots, profit));
            }
         }
         
         // Close selected profitable orders - BUT verify they're still profitable NOW
         int profitOrdersClosed = 0;
         double profitFromOrders = 0.0;
         for(int i = 0; i < selectedCount; i++) {
            if(PositionSelectByTicket(selectedTickets[i])) {
               double lots = PositionGetDouble(POSITION_VOLUME);
               double profit = PositionGetDouble(POSITION_PROFIT);
               int type = (int)PositionGetInteger(POSITION_TYPE);
               string typeStr = (type == POSITION_TYPE_BUY) ? "BUY" : "SELL";
               
               // SAFETY: Only close if still in profit at this moment
               if(profit > 0) {
                  CreateCloseLabelBeforeClose(selectedTickets[i]);
                  if(trade.PositionClose(selectedTickets[i])) {
                     closedCount++;
                     closedProfit += profit;
                     profitOrdersClosed++;
                     profitFromOrders += profit;
                     Log(1, StringFormat("GT CLOSE #%I64u %s %.2f lots | Profit=%.2f (farthest profit)",
                         selectedTickets[i], typeStr, lots, profit));
                  }
               } else {
                  Log(2, StringFormat("GT SKIP #%I64u %s %.2f lots | Changed to loss=%.2f (was profitable when selected)",
                      selectedTickets[i], typeStr, lots, profit));
               }
            }
         }
         
         // Final safety check: If net result is still loss, log warning
         if(closedProfit < 0) {
            Log(1, StringFormat("GT WARNING | Closed at loss %.2f despite safety checks | Closed: 1 loss + %d profit orders",
                closedProfit, profitOrdersClosed));
         }
         
         Log(1, StringFormat("GT CLOSED %d orders together | Net P/L: %.2f | Remaining orders continue trading",
             closedCount, closedProfit));
         
         // Draw vertical line to mark group trail closure
         datetime nowTime = TimeCurrent();
         string vlineName = StringFormat("GT_close_%d_P%.02f", (int)nowTime, closedProfit);
         
         // Delete old object if it exists
         ObjectDelete(0, vlineName);
         
         // Create vertical line
         double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(ObjectCreate(0, vlineName, OBJ_VLINE, 0, nowTime, currentPrice)) {
            // Set color based on profit: orange for group trails
            color lineColor = (closedProfit > 0.0) ? clrOrange : clrRed;
            ObjectSetInteger(0, vlineName, OBJPROP_COLOR, lineColor);
            
            // Set line width proportional to profit
            int lineWidth = 1 + (int)(MathAbs(closedProfit) / 5.0);
            lineWidth = MathMin(lineWidth, 10);
            lineWidth = MathMax(lineWidth, 1);
            ObjectSetInteger(0, vlineName, OBJPROP_WIDTH, lineWidth);
            
            ObjectSetInteger(0, vlineName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, vlineName, OBJPROP_BACK, true);
            ObjectSetInteger(0, vlineName, OBJPROP_SELECTABLE, false);
            
            // Show group trail details in vline text
            string vlinetext = StringFormat("GT:%d(%dP%.0f %dL%.0f %s)%.1f",
                closedCount, selectedCount, selectedProfit, 1, totalLoss, worstLossTypeStr, closedProfit);
            ObjectSetString(0, vlineName, OBJPROP_TEXT, vlinetext);
            ChartRedraw(0);
            
            Log(1, StringFormat("VLine created: %s (color: %s, width: %d) | Text: %s", 
                vlineName, 
                (closedProfit > 0.0) ? "ORANGE" : "RED", 
                lineWidth, vlinetext));
         }
         
         // Reset group trail to recalculate with remaining positions
         g_groupTrail.active = false;
         g_groupTrail.peakProfit = 0.0;
         g_groupTrail.farthestBuyTicket = 0;
         g_groupTrail.farthestSellTicket = 0;
      }
   }
}

//============================= PRINT STATS FUNCTION ===============//
void PrintCurrentStats() {
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
   
   string trailMethodStr = "";
   switch(g_currentTrailMethod) {
      case SINGLE_TRAIL_NORMAL: trailMethodStr = "NORMAL"; break;
      case SINGLE_TRAIL_CLOSETOGETHER: trailMethodStr = "ANYSIDE"; break;
      case SINGLE_TRAIL_CLOSETOGETHER_SAMETYPE: trailMethodStr = "SAMETYPE"; break;
      case SINGLE_TRAIL_DYNAMIC: trailMethodStr = "DYNAMIC"; break;
      case SINGLE_TRAIL_DYNAMIC_SAMETYPE: trailMethodStr = "DYN-SAME"; break;
      case SINGLE_TRAIL_DYNAMIC_ANYSIDE: trailMethodStr = "DYN-ANY"; break;
      case SINGLE_TRAIL_HYBRID_BALANCED: trailMethodStr = "HYB-BAL"; break;
      case SINGLE_TRAIL_HYBRID_ADAPTIVE: trailMethodStr = "HYB-ADP"; break;
      case SINGLE_TRAIL_HYBRID_SMART: trailMethodStr = "HYB-SMART"; break;
      case SINGLE_TRAIL_HYBRID_COUNT_DIFF: trailMethodStr = "HYB-CNT"; break;
      default: trailMethodStr = StringFormat("%d", g_currentTrailMethod); break;
   }
   
   string sTrailModeStr = (g_singleTrailMode == 0) ? "TIGHT" : (g_singleTrailMode == 1) ? "NORMAL" : "LOOSE";
   string tTrailModeStr = (g_totalTrailMode == 0) ? "TIGHT" : (g_totalTrailMode == 1) ? "NORMAL" : "LOOSE";
   string debugLevelStr = (g_currentDebugLevel == 0) ? "OFF" : (g_currentDebugLevel == 1) ? "CRITICAL" : (g_currentDebugLevel == 2) ? "INFO" : "VERBOSE";
   
   Log(1, StringFormat("TrailMethod:%s | STrail:%s | TTrail:%s",
       trailMethodStr, sTrailModeStr, tTrailModeStr));
   Log(1, StringFormat("DebugLevel:%s | ShowLabels:%s | ShowNextLines:%s",
       debugLevelStr, g_showLabels ? "YES" : "NO", g_showNextLevelLines ? "YES" : "NO"));
   Log(1, StringFormat("SingleThreshold:%.0f | MinGLO:%d | DynGLO:%d | MinGroupProfit:%.0f",
       SingleProfitThreshold, MinGLOForGroupTrail, DynamicGLOThreshold, MinGroupProfitToClose));
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
   
   if(g_currentTrailMethod == SINGLE_TRAIL_DYNAMIC || 
      g_currentTrailMethod == SINGLE_TRAIL_DYNAMIC_SAMETYPE || 
      g_currentTrailMethod == SINGLE_TRAIL_DYNAMIC_ANYSIDE) {
      methodName = "DYN";
      shouldUseSingle = (g_orders_in_loss < DynamicGLOThreshold);
      if(shouldUseSingle) {
         return StringFormat("ST:RDY[%s] G:%d<%d", methodName, g_orders_in_loss, DynamicGLOThreshold);
      } else {
         return StringFormat("ST:OFF[%s] G:%d>=%d", methodName, g_orders_in_loss, DynamicGLOThreshold);
      }
   }
   else if(g_currentTrailMethod == SINGLE_TRAIL_HYBRID_BALANCED) {
      methodName = "HB";
      double netExposure = MathAbs(g_netLots);
      shouldUseSingle = (netExposure < HybridNetLotsThreshold);
      if(shouldUseSingle) {
         return StringFormat("ST:RDY[%s] NL:%.2f<%.2f", methodName, netExposure, HybridNetLotsThreshold);
      } else {
         return StringFormat("ST:OFF[%s] NL:%.2f>=%.2f", methodName, netExposure, HybridNetLotsThreshold);
      }
   }
   else if(g_currentTrailMethod == SINGLE_TRAIL_HYBRID_ADAPTIVE) {
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
   else if(g_currentTrailMethod == SINGLE_TRAIL_HYBRID_SMART) {
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
   else if(g_currentTrailMethod == SINGLE_TRAIL_HYBRID_COUNT_DIFF) {
      methodName = "HC";
      int countDiff = MathAbs(g_buyCount - g_sellCount);
      shouldUseSingle = (countDiff <= HybridCountDiffThreshold);
      if(shouldUseSingle) {
         return StringFormat("ST:RDY[%s] D:%d<=%d", methodName, countDiff, HybridCountDiffThreshold);
      } else {
         return StringFormat("ST:OFF[%s] D:%d>%d", methodName, countDiff, HybridCountDiffThreshold);
      }
   }
   else if(g_currentTrailMethod == SINGLE_TRAIL_CLOSETOGETHER || 
           g_currentTrailMethod == SINGLE_TRAIL_CLOSETOGETHER_SAMETYPE) {
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
   
   if(g_currentTrailMethod == SINGLE_TRAIL_DYNAMIC || 
      g_currentTrailMethod == SINGLE_TRAIL_DYNAMIC_SAMETYPE || 
      g_currentTrailMethod == SINGLE_TRAIL_DYNAMIC_ANYSIDE) {
      methodName = "DYN";
      shouldUseGroup = (g_orders_in_loss >= DynamicGLOThreshold);
      if(shouldUseGroup) {
         string details = GetGroupTrailCandidateDetails();
         return StringFormat("GT:RDY[%s] G:%d>=%d|%s", methodName, g_orders_in_loss, DynamicGLOThreshold, details);
      } else {
         return StringFormat("GT:OFF[%s] G:%d<%d", methodName, g_orders_in_loss, DynamicGLOThreshold);
      }
   }
   else if(g_currentTrailMethod == SINGLE_TRAIL_HYBRID_BALANCED) {
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
   else if(g_currentTrailMethod == SINGLE_TRAIL_HYBRID_ADAPTIVE) {
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
   else if(g_currentTrailMethod == SINGLE_TRAIL_HYBRID_SMART) {
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
   else if(g_currentTrailMethod == SINGLE_TRAIL_HYBRID_COUNT_DIFF) {
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
   else if(g_currentTrailMethod == SINGLE_TRAIL_CLOSETOGETHER) {
      string details = GetGroupTrailCandidateDetails();
      return StringFormat("GT:RDY[ANY]|%s", details);
   }
   else if(g_currentTrailMethod == SINGLE_TRAIL_CLOSETOGETHER_SAMETYPE) {
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
void TrailSinglePositions() {
   if(!EnableSingleTrailing) return;
   
   // Skip ALL single/group trail checks when total trail is active
   if(g_trailActive) {
      Log(3, "Single/Group trail skipped: Total trail is active");
      return;
   }
   
   // Dynamic methods: choose based on GLO count
   if(g_currentTrailMethod == SINGLE_TRAIL_DYNAMIC || 
      g_currentTrailMethod == SINGLE_TRAIL_DYNAMIC_SAMETYPE || 
      g_currentTrailMethod == SINGLE_TRAIL_DYNAMIC_ANYSIDE) {
      if(g_orders_in_loss >= DynamicGLOThreshold) {
         // GLO count is high - use group trailing with appropriate mode
         bool useSameType = (g_currentTrailMethod == SINGLE_TRAIL_DYNAMIC_SAMETYPE);
         UpdateGroupTrailing(useSameType);
         return;
      }
      // GLO count is low - continue with normal single trailing below
   }
   
   // Hybrid Balanced: Switch based on net exposure imbalance
   if(g_currentTrailMethod == SINGLE_TRAIL_HYBRID_BALANCED) {
      double netExposure = MathAbs(g_netLots);
      if(netExposure >= HybridNetLotsThreshold) {
         // High imbalance - use group close to reduce exposure
         bool useSameType = (netExposure > HybridNetLotsThreshold * 1.5); // Very high = same type only
         Log(2, StringFormat("HYBRID_BALANCED: Net exposure %.2f >= %.2f, using GROUP close (sameType=%d)", 
             netExposure, HybridNetLotsThreshold, useSameType ? 1 : 0));
         UpdateGroupTrailing(useSameType);
         return;
      } else {
         // Balanced grid - use single trail
         Log(3, StringFormat("HYBRID_BALANCED: Net exposure %.2f < %.2f, using SINGLE trail", 
             netExposure, HybridNetLotsThreshold));
         // Continue to normal single trailing below
      }
   }
   
   // Hybrid Adaptive: Switch based on GLO ratio and profit state
   if(g_currentTrailMethod == SINGLE_TRAIL_HYBRID_ADAPTIVE) {
      int totalOrders = g_buyCount + g_sellCount;
      double gloRatio = (totalOrders > 0) ? (double)g_orders_in_loss / totalOrders : 0.0;
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double cycleProfit = equity - g_lastCloseEquity;
      
      // If many orders in loss OR cycle is negative, use group close
      if(gloRatio >= HybridGLOPercentage || cycleProfit < 0) {
         Log(2, StringFormat("HYBRID_ADAPTIVE: GLO ratio %.1f%% >= %.1f%% OR cycleProfit %.2f < 0, using GROUP close", 
             gloRatio * 100, HybridGLOPercentage * 100, cycleProfit));
         UpdateGroupTrailing(true); // Same type only when adapting
         return;
      } else {
         // Good conditions - use single trail
         Log(3, StringFormat("HYBRID_ADAPTIVE: GLO ratio %.1f%% < %.1f%% AND cycleProfit %.2f >= 0, using SINGLE trail", 
             gloRatio * 100, HybridGLOPercentage * 100, cycleProfit));
         // Continue to normal single trailing below
      }
   }
   
   // Hybrid Smart: Multiple factors (net exposure + GLO ratio + cycle profit)
   if(g_currentTrailMethod == SINGLE_TRAIL_HYBRID_SMART) {
      double netExposure = MathAbs(g_netLots);
      int totalOrders = g_buyCount + g_sellCount;
      double gloRatio = (totalOrders > 0) ? (double)g_orders_in_loss / totalOrders : 0.0;
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double cycleProfit = equity - g_lastCloseEquity;
      
      // Calculate imbalance factor (how one-sided is the grid)
      double imbalanceFactor = 1.0;
      if(g_buyLots > 0.001 && g_sellLots > 0.001) {
         imbalanceFactor = MathMax(g_buyLots / g_sellLots, g_sellLots / g_buyLots);
      }
      
      // Decision logic: Use GROUP close when multiple risk factors present
      bool highImbalance = (imbalanceFactor >= HybridBalanceFactor);
      bool highGLO = (gloRatio >= HybridGLOPercentage);
      bool negativeCycle = (cycleProfit < -MathAbs(g_maxLossCycle * 0.3)); // More than 30% of max loss
      bool highNetExposure = (netExposure >= HybridNetLotsThreshold);
      
      int riskFactors = (highImbalance ? 1 : 0) + (highGLO ? 1 : 0) + (negativeCycle ? 1 : 0) + (highNetExposure ? 1 : 0);
      
      if(riskFactors >= 2) {
         // 2 or more risk factors - use group close
         bool useSameType = (riskFactors >= 3); // 3+ factors = same type only (stricter)
         Log(2, StringFormat("HYBRID_SMART: %d risk factors detected (Imb=%.1f>%.1f:%d, GLO=%.0f%%>%.0f%%:%d, CycleP=%.2f<%.2f:%d, NetL=%.2f>%.2f:%d), using GROUP close (sameType=%d)",
             riskFactors, imbalanceFactor, HybridBalanceFactor, highImbalance ? 1 : 0,
             gloRatio * 100, HybridGLOPercentage * 100, highGLO ? 1 : 0,
             cycleProfit, -MathAbs(g_maxLossCycle * 0.3), negativeCycle ? 1 : 0,
             netExposure, HybridNetLotsThreshold, highNetExposure ? 1 : 0,
             useSameType ? 1 : 0));
         UpdateGroupTrailing(useSameType);
         return;
      } else {
         // Low risk - use single trail
         Log(3, StringFormat("HYBRID_SMART: Only %d risk factors, using SINGLE trail (Imb=%.1f, GLO=%.0f%%, CycleP=%.2f, NetL=%.2f)",
             riskFactors, imbalanceFactor, gloRatio * 100, cycleProfit, netExposure));
         // Continue to normal single trailing below
      }
   }
   
   // Hybrid Count Diff: Switch based on buy/sell order count difference
   if(g_currentTrailMethod == SINGLE_TRAIL_HYBRID_COUNT_DIFF) {
      int countDiff = MathAbs(g_buyCount - g_sellCount);
      
      if(countDiff > HybridCountDiffThreshold) {
         // High imbalance in order counts - use group close with any side
         Log(2, StringFormat("HYBRID_COUNT_DIFF: Order count diff %d > %d (Buy=%d, Sell=%d), using GROUP close (any-side)",
             countDiff, HybridCountDiffThreshold, g_buyCount, g_sellCount));
         UpdateGroupTrailing(false); // Any side to help balance the grid
         return;
      } else {
         // Balanced order counts - use single trail
         Log(3, StringFormat("HYBRID_COUNT_DIFF: Order count diff %d <= %d (Buy=%d, Sell=%d), using SINGLE trail",
             countDiff, HybridCountDiffThreshold, g_buyCount, g_sellCount));
         // Continue to normal single trailing below
      }
   }
   
   // Route to appropriate trailing method
   if(g_currentTrailMethod == SINGLE_TRAIL_CLOSETOGETHER) {
      UpdateGroupTrailing(false); // Any side
      return;
   }
   
   if(g_currentTrailMethod == SINGLE_TRAIL_CLOSETOGETHER_SAMETYPE) {
      UpdateGroupTrailing(true); // Same type only
      return;
   }
   
   // Normal single trailing logic below
   if(g_trailActive) return; // Skip when total trailing active
   
   // Skip closing in No Work mode
   if(g_noWork) return;
   
   // Get effective threshold (auto-calc if input is negative)
   double effectiveThreshold = CalculateSingleThreshold();
   
   int currentTick = (int)GetTickCount();  // For throttling logs
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
      
      double lots = PositionGetDouble(POSITION_VOLUME);
      double profit = PositionGetDouble(POSITION_PROFIT);
      
      if(lots < 0.001) continue;
      
      double profitPer01 = (profit / lots) * 0.01;
      int idx = FindTrailIndex(ticket);
      
      // Start tracking only when profit reaches threshold
      if(profitPer01 >= effectiveThreshold && idx < 0) {
         AddTrail(ticket, profitPer01, effectiveThreshold);
         idx = FindTrailIndex(ticket);
         
         // Apply trail mode multiplier: Tight=0.5x, Normal=1.0x, Loose=2.0x
         double baseGap = effectiveThreshold / 2.0;
         double modeMultiplier = (g_singleTrailMode == 0) ? 0.5 : ((g_singleTrailMode == 2) ? 2.0 : 1.0);
         double gapValue = baseGap * modeMultiplier;
         
         // Update the trail gap in the array
         int trailIdx = FindTrailIndex(ticket);
         if(trailIdx >= 0) g_trails[trailIdx].gap = gapValue;
         
         string levelInfo = GetLevelInfoForTicket(ticket);
         string modeName = (g_singleTrailMode == 0) ? "TIGHT" : ((g_singleTrailMode == 2) ? "LOOSE" : "NORMAL");
         Log(2, StringFormat("ST START %s #%I64u PPL=%.2f | Threshold=%.2f Gap=%.2f (%.1fx-%s) ActivateAt=%.2f", 
             levelInfo, ticket, profitPer01, effectiveThreshold, gapValue, modeMultiplier, modeName, effectiveThreshold / 2.0));
         
         // Log single trail start
         if(PositionSelectByTicket(ticket)) {
            double posProfit = PositionGetDouble(POSITION_PROFIT);
            string reason = StringFormat("PPL:%.2f >= Threshold:%.2f Mode:%s Gap:%.2f", 
                                        profitPer01, effectiveThreshold, modeName, gapValue);
            LogSingleTrailStart(ticket, posProfit, reason);
         }
      }
      
      // Update tracking
      if(idx >= 0) {
         double peak = g_trails[idx].peakPPL;
         double activePeak = g_trails[idx].activePeak;
         double gap = g_trails[idx].gap;
         bool active = g_trails[idx].active;
         
         // Update peak if profit still positive and higher (before activation)
         if(!active && profitPer01 > 0 && profitPer01 > peak) {
            g_trails[idx].peakPPL = profitPer01;
            peak = profitPer01;
            string levelInfo = GetLevelInfoForTicket(ticket);
            Log(3, StringFormat("ST TRACK %s #%I64u peak=%.2f | AwaitingActivation", levelInfo, ticket, peak));
         }
         
         // Activate when drops to half threshold OR when peak reaches 2x threshold
         // This ensures high-profit positions also trail
         double activationThreshold = effectiveThreshold / 2.0;
         bool shouldActivate = (profitPer01 <= activationThreshold && profitPer01 > 0) || (peak >= effectiveThreshold * 2.0);
         
         if(!active && shouldActivate) {
            g_trails[idx].active = true;
            g_trails[idx].activePeak = peak;  // Set peak at activation point (use tracked peak, not current)
            active = true;
            activePeak = peak;
            string levelInfo = GetLevelInfoForTicket(ticket);
            Log(1, StringFormat("ST ACTIVE %s #%I64u peak=%.2f | Current=%.2f | Ready to Trail", 
                levelInfo, ticket, activePeak, profitPer01));
            UpdateSingleTrailLines(); // Create horizontal line
         }
         
         // Update active peak (trail upward after activation)
         if(active && profitPer01 > activePeak) {
            g_trails[idx].activePeak = profitPer01;
            activePeak = profitPer01;
            string levelInfo = GetLevelInfoForTicket(ticket);
            Log(2, StringFormat("ST PEAK UPDATE %s #%I64u peak=%.2f", levelInfo, ticket, activePeak));
            UpdateSingleTrailLines(); // Update horizontal line
         }
         
         // Show continuous trail status when active (throttle to avoid spam - every 500ms)
         if(active) {
            double trailFloorValue = activePeak - gap;
            if(currentTick - g_trails[idx].lastLogTick >= 500) {  // Log every 500ms
               string levelInfo = GetLevelInfoForTicket(ticket);
               Log(3, StringFormat("ST STATUS %s #%I64u | Peak=%.2f Current=%.2f Floor=%.2f Drop=%.2f", 
                   levelInfo, ticket, activePeak, profitPer01, trailFloorValue, activePeak - profitPer01));
               g_trails[idx].lastLogTick = currentTick;
            }
            
            // Close if current PPL drops below or equal to trail floor
            if(profitPer01 <= trailFloorValue) {
               // Get position details before closing
               string posType = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL";
               double posLots = PositionGetDouble(POSITION_VOLUME);
               double posProfit = PositionGetDouble(POSITION_PROFIT);
               double drop = activePeak - profitPer01;
               string levelInfo = GetLevelInfoForTicket(ticket);
               
               Log(1, StringFormat("ST CLOSE %s #%I64u %s %.2f lots | Profit=%.2f | Trail Stats: Peak=%.2f Current=%.2f Drop=%.2f TrailMin=%.2f", 
                   levelInfo, ticket, posType, posLots, posProfit, activePeak, profitPer01, drop, trailFloorValue));
               
               // Log single trail close
               string reason = StringFormat("Floor hit:%.2f Peak:%.2f Gap:%.2f", trailFloorValue, activePeak, gap);
               LogSingleClose(ticket, posProfit, reason);
               
               CreateCloseLabelBeforeClose(ticket);
               if(trade.PositionClose(ticket)) {
                  string lineName = StringFormat("TrailFloor_%I64u", ticket);
                  ObjectDelete(0, lineName);
                  RemoveTrail(idx);
               }
            }
         }
      }
   }
   
   // Cleanup stale trails (positions that no longer exist)
   for(int j = ArraySize(g_trails) - 1; j >= 0; j--) {
      if(!PositionSelectByTicket(g_trails[j].ticket)) {
         string levelInfo = GetLevelInfoForTicket(g_trails[j].ticket);
         Log(2, StringFormat("ST CLEANUP %s #%I64u (position closed)", levelInfo, g_trails[j].ticket));
         RemoveTrail(j);
      }
   }
}
