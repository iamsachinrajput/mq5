//+------------------------------------------------------------------+
//| CloseFunctions.mqh                                               |
//| Close all positions wrapper                                      |
//+------------------------------------------------------------------+

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
