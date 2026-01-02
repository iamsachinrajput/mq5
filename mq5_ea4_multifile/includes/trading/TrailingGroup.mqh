//+------------------------------------------------------------------+
//| TrailingGroup.mqh                                                |
//| Group trailing system for combined orders                        |
//+------------------------------------------------------------------+

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
      if(worstLossTicket > 0 && profitableCount == 0 && GroupTrailMethod == GROUP_TRAIL_CLOSETOGETHER_SAMETYPE) {
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
   // Dynamic methods: choose based on GLO count
   if(g_currentGroupTrailMethod == GROUP_TRAIL_DYNAMIC || 
      g_currentGroupTrailMethod == GROUP_TRAIL_DYNAMIC_SAMETYPE || 
      g_currentGroupTrailMethod == GROUP_TRAIL_DYNAMIC_ANYSIDE) {
      if(g_orders_in_loss >= DynamicGLOThreshold) {
         // GLO count is high - use group trailing with appropriate mode
         bool useSameType = (g_currentGroupTrailMethod == GROUP_TRAIL_DYNAMIC_SAMETYPE);
         UpdateGroupTrailing(useSameType);
         return;
      }
      // GLO count is low - skip group trail
      return;
   }
   
   // Hybrid Balanced: Switch based on net exposure imbalance
   if(g_currentGroupTrailMethod == GROUP_TRAIL_HYBRID_BALANCED) {
      double netExposure = MathAbs(g_netLots);
      if(netExposure >= HybridNetLotsThreshold) {
         // High imbalance - use group close to reduce exposure
         bool useSameType = (netExposure > HybridNetLotsThreshold * 1.5); // Very high = same type only
         Log(2, StringFormat("HYBRID_BALANCED: Net exposure %.2f >= %.2f, using GROUP close (sameType=%d)", 
             netExposure, HybridNetLotsThreshold, useSameType ? 1 : 0));
         UpdateGroupTrailing(useSameType);
         return;
      }
      // Balanced grid - skip group trail
      return;
   }
   
   // Hybrid Adaptive: Switch based on GLO ratio and profit state
   if(g_currentGroupTrailMethod == GROUP_TRAIL_HYBRID_ADAPTIVE) {
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
      }
      // Good conditions - skip group trail
      return;
   }
   
   // Hybrid Smart: Multiple factors (net exposure + GLO ratio + cycle profit)
   if(g_currentGroupTrailMethod == GROUP_TRAIL_HYBRID_SMART) {
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
         Log(2, StringFormat("HYBRID_SMART: %d risk factors detected, using GROUP close (sameType=%d)",
             riskFactors, useSameType ? 1 : 0));
         UpdateGroupTrailing(useSameType);
         return;
      }
      // Low risk - skip group trail
      return;
   }
   
   // Hybrid Count Diff: Switch based on buy/sell count difference
   if(g_currentGroupTrailMethod == GROUP_TRAIL_HYBRID_COUNT_DIFF) {
      int countDiff = MathAbs(g_buyCount - g_sellCount);
      if(countDiff >= HybridCountDiffThreshold) {
         // High count difference - use group close
         Log(2, StringFormat("HYBRID_COUNT_DIFF: Count diff %d >= %d, using GROUP close",
             countDiff, HybridCountDiffThreshold));
         UpdateGroupTrailing(true); // Same type to balance
         return;
      }
      // Balanced count - skip group trail
      return;
   }
   
   // Direct group trail methods (CLOSETOGETHER, CLOSETOGETHER_SAMETYPE)
   if(g_currentGroupTrailMethod == GROUP_TRAIL_CLOSETOGETHER) {
      UpdateGroupTrailing(false); // Any side
   } else if(g_currentGroupTrailMethod == GROUP_TRAIL_CLOSETOGETHER_SAMETYPE) {
      UpdateGroupTrailing(true); // Same type only
   }
}
