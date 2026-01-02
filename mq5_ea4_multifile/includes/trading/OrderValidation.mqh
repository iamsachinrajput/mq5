//+------------------------------------------------------------------+
//| OrderValidation.mqh                                              |
//| Duplicate checks, boundary validation, placement strategy        |
//+------------------------------------------------------------------+

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

// Check if order is a boundary order
// BUY boundary: No orders ABOVE it (don't check below)
// SELL boundary: No orders BELOW it (don't check above)
bool IsBoundaryOrder(int orderType, int level, double gap) {
   if(orderType == POSITION_TYPE_BUY) {
      // BUY boundary: Check if any orders exist ABOVE this level
      // First check tracking array
      for(int i = 0; i < g_orderCount; i++) {
         if(!g_orders[i].isValid) continue;
         if(g_orders[i].level > level) return false; // Found order above
      }
      
      // Fallback: Also check live positions to ensure accuracy
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
         
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         int existingLevel = PriceLevelIndex(openPrice, gap);
         if(existingLevel > level) return false; // Found order above
      }
      
      return true; // No orders above - this is BUY boundary
   } else {
      // SELL boundary: Check if any orders exist BELOW this level
      // First check tracking array
      for(int i = 0; i < g_orderCount; i++) {
         if(!g_orders[i].isValid) continue;
         if(g_orders[i].level < level) return false; // Found order below
      }
      
      // Fallback: Also check live positions to ensure accuracy
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
         
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         int existingLevel = PriceLevelIndex(openPrice, gap);
         if(existingLevel < level) return false; // Found order below
      }
      
      return true; // No orders below - this is SELL boundary
   }
}

// Check if boundary order placement is allowed based on boundary strategy
bool IsBoundaryOrderAllowed(int orderType, int level, double gap) {
   string typeStr = (orderType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
   
   switch(BoundaryOrderStrategy) {
      case BOUNDARY_STRATEGY_ALWAYS:
         Log(3, StringFormat("[BOUNDARY-PASSED] %s L%d | Strategy: ALWAYS", typeStr, level));
         return true;
      
      case BOUNDARY_STRATEGY_TRAIL_LAST:
         {
            // Check if the last same-type boundary order is being trailed
            // Find the current boundary order of same type
            int boundaryLevel = 0;
            bool foundBoundary = false;
            
            for(int i = 0; i < g_orderCount; i++) {
               if(!g_orders[i].isValid) continue;
               if(g_orders[i].type != orderType) continue;
               
               if(orderType == POSITION_TYPE_BUY) {
                  if(!foundBoundary || g_orders[i].level > boundaryLevel) {
                     boundaryLevel = g_orders[i].level;
                     foundBoundary = true;
                  }
               } else {
                  if(!foundBoundary || g_orders[i].level < boundaryLevel) {
                     boundaryLevel = g_orders[i].level;
                     foundBoundary = true;
                  }
               }
            }
            
            if(!foundBoundary) {
               Log(3, StringFormat("[BOUNDARY-PASSED] %s L%d | Strategy: TRAIL_LAST - No existing boundary", typeStr, level));
               return true; // No existing boundary, allow new one
            }
            
            // Check if boundary order is in trail
            for(int i = 0; i < g_orderCount; i++) {
               if(!g_orders[i].isValid) continue;
               if(g_orders[i].type != orderType) continue;
               if(g_orders[i].level != boundaryLevel) continue;
               
               ulong boundaryTicket = g_orders[i].ticket;
               
               // Check if this ticket is in trails array
               for(int t = 0; t < ArraySize(g_trails); t++) {
                  if(g_trails[t].ticket == boundaryTicket) {
                     Log(3, StringFormat("[BOUNDARY-PASSED] %s L%d | Strategy: TRAIL_LAST - Boundary #%I64u L%d is in trail",
                         typeStr, level, boundaryTicket, boundaryLevel));
                     return true;
                  }
               }
            }
            
            Log(2, StringFormat("[BOUNDARY-BLOCKED] %s L%d | Strategy: TRAIL_LAST - Boundary L%d not in trail",
                typeStr, level, boundaryLevel));
            return false;
         }
      
      case BOUNDARY_STRATEGY_ORDER_COUNT:
         {
            int totalOrders = g_buyCount + g_sellCount;
            if(totalOrders < BoundaryStrategyHelper) {
               Log(3, StringFormat("[BOUNDARY-PASSED] %s L%d | Strategy: ORDER_COUNT - %d/%d orders",
                   typeStr, level, totalOrders, BoundaryStrategyHelper));
               return true;
            }
            Log(2, StringFormat("[BOUNDARY-BLOCKED] %s L%d | Strategy: ORDER_COUNT - %d >= %d orders",
                typeStr, level, totalOrders, BoundaryStrategyHelper));
            return false;
         }
      
      case BOUNDARY_STRATEGY_NO_TOTAL_TRAIL:
         {
            if(!g_trailActive) {
               Log(3, StringFormat("[BOUNDARY-PASSED] %s L%d | Strategy: NO_TOTAL_TRAIL - Total trail inactive",
                   typeStr, level));
               return true;
            }
            Log(2, StringFormat("[BOUNDARY-BLOCKED] %s L%d | Strategy: NO_TOTAL_TRAIL - Total trail active",
                typeStr, level));
            return false;
         }
      
      case BOUNDARY_STRATEGY_GLO_MORE:
         {
            if(g_orders_in_loss > g_orders_in_profit) {
               Log(3, StringFormat("[BOUNDARY-PASSED] %s L%d | Strategy: GLO_MORE - GLO:%d > GPO:%d",
                   typeStr, level, g_orders_in_loss, g_orders_in_profit));
               return true;
            }
            Log(2, StringFormat("[BOUNDARY-BLOCKED] %s L%d | Strategy: GLO_MORE - GLO:%d <= GPO:%d",
                typeStr, level, g_orders_in_loss, g_orders_in_profit));
            return false;
         }
   }
   
   return true; // Default allow
}

// Check if order placement is allowed based on strategy
// Returns true if order can be placed, false if blocked by strategy
bool IsOrderPlacementAllowed(int orderType, int level, double gap) {
   // If no open positions, always allow first order
   if(PositionsTotal() == 0) {
      Log(3, "[STRATEGY] No positions - allowing first order");
      return true;
   }
   
   // IMPORTANT: During total trail, strategy checks are bypassed
   // Trail order management is handled separately in PlaceGridOrders() via TrailOrderMode
   if(g_trailActive) {
      Log(3, "[STRATEGY] Total trail active - bypassing strategy checks (managed by TrailOrderMode)");
      return true;
   }
   
   // Check if this is a boundary order (topmost BUY or bottommost SELL)
   if(IsBoundaryOrder(orderType, level, gap)) {
      // Apply boundary order strategy instead of main strategy
      return IsBoundaryOrderAllowed(orderType, level, gap);
   }
   
   // Not a boundary order - apply main order placement strategy
   // If no strategy, always allow
   if(OrderPlacementStrategy == ORDER_STRATEGY_NONE) {
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
   if(OrderPlacementStrategy == ORDER_STRATEGY_FAR_ADJACENT) {
      string typeStr = (orderType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
      
      // Check for opposite-type orders starting from specified distance
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
