//+------------------------------------------------------------------+
//| UILabels.mqh                                                     |
//| Info label updates and profit display                            |
//+------------------------------------------------------------------+

         int lineWidth = 1 + (int)(MathAbs(cycleProfit) / 5.0);
         lineWidth = MathMin(lineWidth, 10);
         lineWidth = MathMax(lineWidth, 1);
         ObjectSetInteger(0, vlineName, OBJPROP_WIDTH, lineWidth);
         
         ObjectSetInteger(0, vlineName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, vlineName, OBJPROP_BACK, true);
         ObjectSetInteger(0, vlineName, OBJPROP_SELECTABLE, false);
         
         // Calculate trailing start threshold
         double lossStart = g_maxLossCycle * TrailStartPct;
         double profitStart = g_maxProfitCycle * TrailProfitPct;
         double trailStart = MathMax(lossStart, profitStart);
         
         int totalCount = g_buyCount + g_sellCount;
         double totalLots = g_buyLots + g_sellLots;
         string vlinetext = StringFormat("P:%.2f/%.2f/%.2f/%.2f/%.2f(L%.2f)ML%.2f/%.2f L%.2f/%.2f N:%d/%.2f/%.2f", 
               cycleProfit, g_maxProfitCycle, trailStart, g_trailFloor, g_trailPeak, bookedCycle, -g_maxLossCycle, -g_overallMaxLoss, 
               g_maxLotsCycle, g_overallMaxLotSize, totalCount, g_netLots, totalLots);
         ObjectSetString(0, vlineName, OBJPROP_TEXT, vlinetext);
      }
   } else {
      // Remove vline if no positions
      ObjectDelete(0, "CurrentProfitVLine");
   }
   
   // All labels controlled by show labels button
   if(g_showLabels) {
      // Label 1: Current Profit Label
      if(g_showCurrentProfitLabel) {
         color lineColor = (cycleProfit > 1.0) ? clrGreen : (cycleProfit < -1.0) ? clrRed : clrYellow;
         string modeIndicator = "";
         if(g_noWork) modeIndicator = " [NO WORK]";
         else if(g_stopNewOrders) modeIndicator = " [MANAGE ONLY]";
         
         // Calculate trailing start threshold
         double lossStart = g_maxLossCycle * TrailStartPct;
         double profitStart = g_maxProfitCycle * TrailProfitPct;
         double trailStart = MathMax(lossStart, profitStart);
         
         string vlinetext = StringFormat("P:%.0f/%.0f/%.0f/%.0f/%.0f(E%.0f)ML%.0f/%.0f L%.2f/%.2f glo %d/%d%s", 
               cycleProfit, g_maxProfitCycle, trailStart, g_trailFloor, g_trailPeak, bookedCycle, -g_maxLossCycle, -g_overallMaxLoss, 
               g_maxLotsCycle, g_overallMaxLotSize, g_orders_in_loss, g_maxGLOOverall, modeIndicator);
         UpdateOrCreateLabel("CurrentProfitLabel", 10, 30, vlinetext, lineColor, 12, "Arial Bold");
      } else {
         ObjectDelete(0, "CurrentProfitLabel");
      }
      
      // Label 2: Position Details
      if(g_showPositionDetailsLabel) {
         int totalCount = g_buyCount + g_sellCount;
         double totalLots = g_buyLots + g_sellLots;
         string label2text = StringFormat("N:%d/%.2f/%.0f B:%d/%.2f/%.0f S:%d/%.2f/%.0f NB%.2f/NS%.2f",
               totalCount, g_netLots, totalLots,
               g_buyCount, g_buyLots, g_buyProfit,
               g_sellCount, g_sellLots, g_sellProfit,
               g_nextBuyLot, g_nextSellLot);
         color label2Color = (g_totalProfit >= 0) ? clrLime : clrOrange;
         UpdateOrCreateLabel("PositionDetailsLabel", 10, 55, label2text, label2Color, 10, "Arial Bold");
      } else {
         ObjectDelete(0, "PositionDetailsLabel");
      }
      
      // Label 3: Spread & Equity
      if(g_showSpreadEquityLabel) {
         double currentSpread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
         double inputGapPoints = GapInPoints;
         double effectiveGapPoints = g_adaptiveGap / _Point;
         string label3text = StringFormat("SPR:%.1f/%.1f |Gp:%.0f/%.0f |Eq:%.0f |PR:%.2f/%.2f", 
               currentSpread/_Point, g_maxSpread/_Point, inputGapPoints, effectiveGapPoints, equity,cycleProfit, overallProfit);
         color label3Color = (overallProfit >= 0) ? clrGreen : clrRed;
         UpdateOrCreateLabel("SpreadEquityLabel", 10, 80, label3text, label3Color, 10, "Arial Bold");
      } else {
         ObjectDelete(0, "SpreadEquityLabel");
      }
      
      // Label NEW: Next Lot Calculation Details
      if(g_showNextLotCalcLabel) {
         string scenarioNames[] = {"Bndry", "Dir", "Rev", "GPO>GLO", "GLO>GPO", "Cntrd", "Sided"};
         string buyScenarioName = (g_nextBuyScenario >= 0 && g_nextBuyScenario < 7) ? scenarioNames[g_nextBuyScenario] : "?";
         string sellScenarioName = (g_nextSellScenario >= 0 && g_nextSellScenario < 7) ? scenarioNames[g_nextSellScenario] : "?";
         
         // Format: "NextLot: B 0.05[Dir-Diff:S-loss>B-loss] S 0.03[Rev-GPO:S-loss>B-loss] | GLO:3 GPO:5"
         string nextLotText = StringFormat("NextLot: B %.2f[%s-%s:%s] S %.2f[%s-%s:%s] | GLO:%d GPO:%d",
               g_nextBuyLot, buyScenarioName, g_nextBuyMethod, g_nextBuyReason,
               g_nextSellLot, sellScenarioName, g_nextSellMethod, g_nextSellReason,
               g_orders_in_loss, g_orders_in_profit);
         color nextLotColor = clrLightSkyBlue;
         UpdateOrCreateLabel("NextLotCalcLabel", 10, 105, nextLotText, nextLotColor, 8, "Arial Bold");
      } else {
         ObjectDelete(0, "NextLotCalcLabel");
      }
      
      // Label 4: Single Trail Status
      if(g_showSingleTrailLabel) {
         string singleTrailStatus = GetSingleTrailStatusInfo();
         color singleTrailColor = clrCyan;
         if(StringFind(singleTrailStatus, "ACTIVE") >= 0) singleTrailColor = clrYellow;
         else if(StringFind(singleTrailStatus, "READY") >= 0 || StringFind(singleTrailStatus, "RDY") >= 0) singleTrailColor = clrLimeGreen;
         else if(StringFind(singleTrailStatus, "NOT-USED") >= 0 || StringFind(singleTrailStatus, "OFF") >= 0) singleTrailColor = clrGray;
         else if(StringFind(singleTrailStatus, "Disabled") >= 0) singleTrailColor = clrRed;
         else if(StringFind(singleTrailStatus, "Skipped") >= 0 || StringFind(singleTrailStatus, "Skip") >= 0) singleTrailColor = clrOrange;
         UpdateOrCreateLabel("SingleTrailStatusLabel", 10, 130, singleTrailStatus, singleTrailColor, 10, "Arial Bold");
      } else {
         ObjectDelete(0, "SingleTrailStatusLabel");
      }
      
      // Label 5: Group Trail Status
      if(g_showGroupTrailLabel) {
         string groupTrailStatus = GetGroupTrailStatusInfo();
         color groupTrailColor = clrCyan;
         if(StringFind(groupTrailStatus, "ACTIVE") >= 0 || StringFind(groupTrailStatus, "ON") >= 0) groupTrailColor = clrOrange;
         else if(StringFind(groupTrailStatus, "READY") >= 0 || StringFind(groupTrailStatus, "RDY") >= 0) groupTrailColor = clrLimeGreen;
         else if(StringFind(groupTrailStatus, "NOT-USED") >= 0 || StringFind(groupTrailStatus, "OFF") >= 0) groupTrailColor = clrGray;
         else if(StringFind(groupTrailStatus, "Disabled") >= 0) groupTrailColor = clrRed;
         else if(StringFind(groupTrailStatus, "Skipped") >= 0 || StringFind(groupTrailStatus, "Skip") >= 0) groupTrailColor = clrOrange;
         UpdateOrCreateLabel("GroupTrailStatusLabel", 10, 155, groupTrailStatus, groupTrailColor, 10, "Arial Bold");
      } else {
         ObjectDelete(0, "GroupTrailStatusLabel");
      }
      
      // Label 6: Total Trail Status
      if(g_showTotalTrailLabel) {
         string totalTrailStatus = GetTotalTrailStatusInfo();
         color totalTrailColor = clrCyan;
         if(StringFind(totalTrailStatus, "ACTIVE") >= 0 || StringFind(totalTrailStatus, "ON") >= 0) totalTrailColor = clrBlue;
         else if(StringFind(totalTrailStatus, "READY") >= 0 || StringFind(totalTrailStatus, "RDY") >= 0) totalTrailColor = clrLimeGreen;
         else if(StringFind(totalTrailStatus, "WAIT") >= 0) totalTrailColor = clrGray;
         else if(StringFind(totalTrailStatus, "BLOCKED") >= 0 || StringFind(totalTrailStatus, "BLOCK") >= 0) totalTrailColor = clrRed;
         else if(StringFind(totalTrailStatus, "Disabled") >= 0) totalTrailColor = clrRed;
         UpdateOrCreateLabel("TotalTrailStatusLabel", 10, 205, totalTrailStatus, totalTrailColor, 10, "Arial Bold");
      } else {
         ObjectDelete(0, "TotalTrailStatusLabel");
      }
      
      // Calculate current level (used by multiple labels below)
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      int currentLevel = PriceLevelIndex(currentPrice, g_adaptiveGap);
      
      // Label 7: Current Level Info
      if(g_showLevelInfoLabel) {
         // Find nearest BUY order (even level closest to current level)
         int nearestBuyLevel = -999999;
      double nearestBuyLot = 0.0;
      ulong nearestBuyTicket = 0;
      int minBuyDistance = 999999;
      for(int i = 0; i < g_orderCount; i++) {
         if(g_orders[i].isValid && g_orders[i].type == POSITION_TYPE_BUY) {
            int distance = MathAbs(g_orders[i].level - currentLevel);
            if(distance < minBuyDistance) {
               minBuyDistance = distance;
               nearestBuyLevel = g_orders[i].level;
               nearestBuyLot = g_orders[i].lotSize;
               nearestBuyTicket = g_orders[i].ticket;
            }
         }
      }
      
      // Find nearest SELL order (odd level closest to current level)
      int nearestSellLevel = -999999;
      double nearestSellLot = 0.0;
      ulong nearestSellTicket = 0;
      int minSellDistance = 999999;
      for(int i = 0; i < g_orderCount; i++) {
         if(g_orders[i].isValid && g_orders[i].type == POSITION_TYPE_SELL) {
            int distance = MathAbs(g_orders[i].level - currentLevel);
            if(distance < minSellDistance) {
               minSellDistance = distance;
               nearestSellLevel = g_orders[i].level;
               nearestSellLot = g_orders[i].lotSize;
               nearestSellTicket = g_orders[i].ticket;
            }
         }
      }
      
      // Get comments from server positions
      string buyComment = "";
      string sellComment = "";
      
      if(nearestBuyTicket > 0) {
         if(PositionSelectByTicket(nearestBuyTicket)) {
            buyComment = PositionGetString(POSITION_COMMENT);
         }
      }
      
      if(nearestSellTicket > 0) {
         if(PositionSelectByTicket(nearestSellTicket)) {
            sellComment = PositionGetString(POSITION_COMMENT);
         }
      }
      
      string buyInfo = (nearestBuyLevel != -999999) ? StringFormat("%dB%.2f[%s]", nearestBuyLevel, nearestBuyLot, buyComment) : "-";
      string sellInfo = (nearestSellLevel != -999999) ? StringFormat("%dS%.2f[%s]", nearestSellLevel, nearestSellLot, sellComment) : "-";
         string label4text = StringFormat("Lvl: C%d %s %s", currentLevel, buyInfo, sellInfo);
         color label4Color = clrWhite;
         UpdateOrCreateLabel("LevelInfoLabel", 10, 230, label4text, label4Color, 10, "Arial Bold");
      } else {
         ObjectDelete(0, "LevelInfoLabel");
      }
      
      // Label 8: Nearby Orders
      if(g_showNearbyOrdersLabel) {
         string nearbyText = GetNearbyOrdersText(currentLevel, 5); // 5 up, 5 down = 10 total
         string label5text = StringFormat("Orders: %s", nearbyText);
         color label5Color = clrCyan;
         UpdateOrCreateLabel("NearbyOrdersLabel", 10, 255, label5text, label5Color, 10, "Arial Bold");
      } else {
         ObjectDelete(0, "NearbyOrdersLabel");
      }
      
      // Label 9: Last 5 Closes
      if(g_showLast5ClosesLabel) {
         string label6text = "Last5 Closes: ";
         for(int i = 0; i < 5; i++) {
            if(i < g_closeCount) {
               label6text += StringFormat("%.2f", g_last5Closes[i]);
            } else {
               label6text += "-";
            }
            if(i < 4) label6text += " | ";
         }
         UpdateOrCreateLabel("Last5ClosesLabel", 10, 280, label6text, clrYellow, 9, "Arial");
      } else {
         ObjectDelete(0, "Last5ClosesLabel");
      }
      
      // Label 10: History Display (based on mode)
      if(g_showHistoryDisplayLabel) {
         string historyLabel = "";
         color historyColor = clrYellow;
      
      if(g_historyDisplayMode == 0) {
         // Overall (All Symbols/All Magic)
         historyLabel = "Last5D Overall: ";
         for(int i = 0; i < 5; i++) {
            historyLabel += StringFormat("%.0f", g_historyOverallDaily[i]);
            if(i < 4) historyLabel += " | ";
         }
         historyColor = clrLightGreen;
      }
      else if(g_historyDisplayMode == 1) {
         // Current Symbol (All Magic)
         historyLabel = StringFormat("Last5D %s(AllMag): ", _Symbol);
         for(int i = 0; i < 5; i++) {
            historyLabel += StringFormat("%.0f", g_historySymbolDaily[i]);
            if(i < 4) historyLabel += " | ";
         }
         historyColor = clrCyan;
      }
      else if(g_historyDisplayMode == 2) {
         // Current Symbol (Current Magic) - for now show same as mode 1
         historyLabel = StringFormat("Last5D %s(M%d): ", _Symbol, Magic);
         for(int i = 0; i < 5; i++) {
            historyLabel += StringFormat("%.0f", g_historySymbolDaily[i]);
            if(i < 4) historyLabel += " | ";
         }
         historyColor = clrOrange;
      }
      else if(g_historyDisplayMode == 3) {
         // Per-Symbol Breakdown (show first symbol or summary)
         if(ArraySize(g_symbolHistory) > 0) {
            historyLabel = "Last5D: ";
            for(int s = 0; s < MathMin(2, ArraySize(g_symbolHistory)); s++) {
               if(s > 0) historyLabel += " ";
               historyLabel += StringFormat("%s:%.0f", g_symbolHistory[s].symbol, g_symbolHistory[s].daily[0]);
            }
            if(ArraySize(g_symbolHistory) > 2) {
               historyLabel += StringFormat(" +%d more", ArraySize(g_symbolHistory) - 2);
            }
         } else {
            historyLabel = "Last5D: No data";
         }
         historyColor = clrViolet;
      }
      
      UpdateOrCreateLabel("HistoryDisplayLabel", 10, 303, historyLabel, historyColor, 9, "Arial Bold");
      } else {
         ObjectDelete(0, "HistoryDisplayLabel");
      }
   } else {
      // Delete all labels when show labels is OFF
      ObjectDelete(0, "CurrentProfitLabel");
      ObjectDelete(0, "PositionDetailsLabel");
      ObjectDelete(0, "SpreadEquityLabel");
      ObjectDelete(0, "NextLotCalcLabel");
      ObjectDelete(0, "SingleTrailStatusLabel");
      ObjectDelete(0, "GroupTrailStatusLabel");
      ObjectDelete(0, "TotalTrailStatusLabel");
      ObjectDelete(0, "LevelInfoLabel");
      ObjectDelete(0, "NearbyOrdersLabel");
      ObjectDelete(0, "Last5ClosesLabel");
      ObjectDelete(0, "HistoryDisplayLabel");
   }
   
   // Center Panel Labels - controlled by show labels button
   if(g_showLabels) {
      // Calculate center positions
      long chartWidth = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
      long chartHeight = ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
      int centerX = (int)(chartWidth / 2);
      int centerY = (int)(chartHeight / 2);
      
      // Line 1: Cycle Profit (centered)
      if(g_showCenterCycleLabel) {
         // Calculate trail start for display
         double lossStart = g_maxLossCycle * TrailStartPct;
         double profitStart = g_maxProfitCycle * TrailProfitPct;
         double trailStart = MathMax(lossStart, profitStart);
         
         // Format: P{cycleProfit}/{trailStart}/{floorPrice}
         string cycleText;
         if(g_trailActive) {
            cycleText = StringFormat("P%.0f/%.0f/%.0f", cycleProfit, trailStart, g_trailFloor);
         } else {
            cycleText = StringFormat("P%.0f/%.0f", cycleProfit, trailStart);
         }
         color cycleColor = (cycleProfit >= 0) ? clrLime : clrRed;
         
         string centerName = "CenterCycleLabel";
         if(ObjectFind(0, centerName) < 0) {
            ObjectCreate(0, centerName, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(0, centerName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, centerName, OBJPROP_ANCHOR, ANCHOR_CENTER);
            ObjectSetInteger(0, centerName, OBJPROP_XDISTANCE, centerX);
            ObjectSetInteger(0, centerName, OBJPROP_YDISTANCE, centerY);
            ObjectSetInteger(0, centerName, OBJPROP_FONTSIZE, CenterPanelFontSize);
            ObjectSetString(0, centerName, OBJPROP_FONT, "Arial Bold");
            ObjectSetInteger(0, centerName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, centerName, OBJPROP_HIDDEN, false);
            ObjectSetInteger(0, centerName, OBJPROP_BACK, false);
            ObjectSetInteger(0, centerName, OBJPROP_ZORDER, 0);
         } else {
            ObjectSetInteger(0, centerName, OBJPROP_XDISTANCE, centerX);
            ObjectSetInteger(0, centerName, OBJPROP_YDISTANCE, centerY);
            ObjectSetInteger(0, centerName, OBJPROP_FONTSIZE, CenterPanelFontSize);
         }
         
         ObjectSetString(0, centerName, OBJPROP_TEXT, cycleText);
         ObjectSetInteger(0, centerName, OBJPROP_COLOR, cycleColor);
      } else {
         ObjectDelete(0, "CenterCycleLabel");
      }
      
      // Line 2: Total Overall Profit (centered)
      int centerY2 = centerY + (int)(CenterPanelFontSize * 1.25);
      
      if(g_showCenterProfitLabel) {
         string centerText = StringFormat("T%.0f/%.0f", overallProfit, equity);
         color centerColor = (overallProfit >= 0) ? clrLime : clrRed;
         
         string centerName = "CenterProfitLabel";
         if(ObjectFind(0, centerName) < 0) {
            ObjectCreate(0, centerName, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(0, centerName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, centerName, OBJPROP_ANCHOR, ANCHOR_CENTER);
            ObjectSetInteger(0, centerName, OBJPROP_XDISTANCE, centerX);
            ObjectSetInteger(0, centerName, OBJPROP_YDISTANCE, centerY2);
            ObjectSetInteger(0, centerName, OBJPROP_FONTSIZE, CenterPanel2FontSize);
            ObjectSetString(0, centerName, OBJPROP_FONT, "Arial Bold");
            ObjectSetInteger(0, centerName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, centerName, OBJPROP_HIDDEN, false);
            ObjectSetInteger(0, centerName, OBJPROP_BACK, false);
            ObjectSetInteger(0, centerName, OBJPROP_ZORDER, 0);
         } else {
            ObjectSetInteger(0, centerName, OBJPROP_XDISTANCE, centerX);
            ObjectSetInteger(0, centerName, OBJPROP_YDISTANCE, centerY2);
            ObjectSetInteger(0, centerName, OBJPROP_FONTSIZE, CenterPanel2FontSize);
         }
         
         ObjectSetString(0, centerName, OBJPROP_TEXT, centerText);
         ObjectSetInteger(0, centerName, OBJPROP_COLOR, centerColor);
      } else {
         ObjectDelete(0, "CenterProfitLabel");
      }
      
      // Line 3: Booked Profit + Open Profit (centered)
      int centerY3 = centerY2 + (int)(CenterPanel2FontSize * 1.25);
      
      if(g_showCenterBookedLabel) {
         string centerName2Booked = "CenterBookedLabel";
         string bookedText = StringFormat("E%.0f %.0f", bookedCycle, openProfit);
         color bookedColor = (bookedCycle >= 0) ? clrLime : clrRed;
         
         // Create/update booked profit label (centered)
         if(ObjectFind(0, centerName2Booked) < 0) {
            ObjectCreate(0, centerName2Booked, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(0, centerName2Booked, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, centerName2Booked, OBJPROP_ANCHOR, ANCHOR_CENTER);
            ObjectSetInteger(0, centerName2Booked, OBJPROP_FONTSIZE, CenterPanel2FontSize);
            ObjectSetString(0, centerName2Booked, OBJPROP_FONT, "Arial Bold");
            ObjectSetInteger(0, centerName2Booked, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, centerName2Booked, OBJPROP_HIDDEN, false);
            ObjectSetInteger(0, centerName2Booked, OBJPROP_BACK, false);
            ObjectSetInteger(0, centerName2Booked, OBJPROP_ZORDER, 0);
         }
         ObjectSetInteger(0, centerName2Booked, OBJPROP_XDISTANCE, centerX);
         ObjectSetInteger(0, centerName2Booked, OBJPROP_YDISTANCE, centerY3);
         ObjectSetInteger(0, centerName2Booked, OBJPROP_FONTSIZE, CenterPanel2FontSize);
         ObjectSetString(0, centerName2Booked, OBJPROP_TEXT, bookedText);
         ObjectSetInteger(0, centerName2Booked, OBJPROP_COLOR, bookedColor);
      } else {
         ObjectDelete(0, "CenterBookedLabel");
      }
      
      // Line 4: Net Lots / Order Count Difference / GLO / GPO (centered)
      int centerY4 = centerY3 + (int)(CenterPanel2FontSize * 1.25);
      
      if(g_showCenterNetLotsLabel) {
         string centerName3 = "CenterNetLotsLabel";
         
         // Determine which side has more orders and by how much
         int orderCountDiff = MathAbs(g_buyCount - g_sellCount);
         string orderDiffStr = "";
         if(g_sellCount > g_buyCount) {
            orderDiffStr = StringFormat("S%d", orderCountDiff);
         } else if(g_buyCount > g_sellCount) {
            orderDiffStr = StringFormat("B%d", orderCountDiff);
         } else {
            orderDiffStr = "E0"; // Equal
         }
         
         string netLotsText = StringFormat("N%.2f/%s/%d/%d", g_netLots, orderDiffStr, g_orders_in_loss, g_orders_in_profit);
         color netLotsColor = clrWhite;
         
         // Create/update net lots label (centered)
         if(ObjectFind(0, centerName3) < 0) {
            ObjectCreate(0, centerName3, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(0, centerName3, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, centerName3, OBJPROP_ANCHOR, ANCHOR_CENTER);
            ObjectSetInteger(0, centerName3, OBJPROP_FONTSIZE, CenterPanel2FontSize);
            ObjectSetString(0, centerName3, OBJPROP_FONT, "Arial Bold");
            ObjectSetInteger(0, centerName3, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, centerName3, OBJPROP_HIDDEN, false);
            ObjectSetInteger(0, centerName3, OBJPROP_BACK, false);
            ObjectSetInteger(0, centerName3, OBJPROP_ZORDER, 0);
         }
         ObjectSetInteger(0, centerName3, OBJPROP_XDISTANCE, centerX);
         ObjectSetInteger(0, centerName3, OBJPROP_YDISTANCE, centerY4);
         ObjectSetInteger(0, centerName3, OBJPROP_FONTSIZE, CenterPanel2FontSize);
         ObjectSetString(0, centerName3, OBJPROP_TEXT, netLotsText);
         ObjectSetInteger(0, centerName3, OBJPROP_COLOR, netLotsColor);
      } else {
         ObjectDelete(0, "CenterNetLotsLabel");
      }
   } else {
      // Delete center panel labels when hidden
      ObjectDelete(0, "CenterProfitLabel");
      ObjectDelete(0, "CenterCycleLabel");
      ObjectDelete(0, "CenterBookedLabel");
      ObjectDelete(0, "CenterNetLotsLabel");
   }
   
   ChartRedraw(0);
}
