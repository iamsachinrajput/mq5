//+------------------------------------------------------------------+
//| PositionStats.mqh                                                |
//| Position statistics and risk status updates                      |
//+------------------------------------------------------------------+

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

