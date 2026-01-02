//+------------------------------------------------------------------+
//| UIEventHandler.mqh                                               |
//| Chart event handling for all UI interactions                     |
//+------------------------------------------------------------------+

            g_stopNewOrdersClickTime = 0; // Reset click timer
            UpdateButtonStates();
            Log(1, StringFormat("Stop New Orders (IMMEDIATE): %s", g_stopNewOrders ? "ENABLED" : "DISABLED"));
         } else {
            // First click - schedule for next close-all
            g_stopNewOrdersClickTime = currentTime;
            g_pendingStopNewOrders = !g_stopNewOrders; // Toggle state
            if(g_pendingStopNewOrders) {
               g_pendingNoWork = false; // Cancel conflicting pending action
            }
            Log(1, StringFormat("Stop New Orders: Will %s after next Close-All (click again for immediate)", 
                g_pendingStopNewOrders ? "ENABLE" : "DISABLE"));
         }
      }
      
      // Button 2: No Work Mode (double-click: immediate, single-click: after next close-all)
      if(sparam == "BtnNoWork") {
         datetime currentTime = TimeCurrent();
         
         // Check if this is a double-click (within 2 seconds of first click)
         if(g_noWorkClickTime > 0 && (currentTime - g_noWorkClickTime) <= 2) {
            // Double-click confirmed - apply immediately
            g_noWork = !g_noWork;
            g_pendingNoWork = false; // Cancel any pending action
            
            // If activating No Work, deactivate Stop New Orders
            if(g_noWork && g_stopNewOrders) {
               g_stopNewOrders = false;
               g_pendingStopNewOrders = false;
            }
            
            g_noWorkClickTime = 0; // Reset click timer
            UpdateButtonStates();
            Log(1, StringFormat("No Work Mode (IMMEDIATE): %s", g_noWork ? "ENABLED" : "DISABLED"));
         } else {
            // First click - schedule for next close-all
            g_noWorkClickTime = currentTime;
            g_pendingNoWork = !g_noWork; // Toggle state
            if(g_pendingNoWork) {
               g_pendingStopNewOrders = false; // Cancel conflicting pending action
            }
            Log(1, StringFormat("No Work Mode: Will %s after next Close-All (click again for immediate)", 
                g_pendingNoWork ? "ENABLE" : "DISABLE"));
         }
      }
      
      // Button 3: Close All (double-click protection)
      if(sparam == "BtnCloseAll") {
         datetime currentTime = TimeCurrent();
         
         // Check if this is a double-click (within 2 seconds of first click)
         if(g_closeAllClickTime > 0 && (currentTime - g_closeAllClickTime) <= 2) {
            // Double-click confirmed - call wrapper function to handle all close-all activities
            PerformCloseAll("ButtonClick");
            g_closeAllClickTime = 0; // Reset click timer
         } else {
            // First click - start timer
            g_closeAllClickTime = currentTime;
            Log(1, "Close All: Click again within 2 seconds to confirm");
         }
      }
      
      // Button 5: Lines Control - Show selection panel for line types
      if(sparam == "BtnLinesControl") {
         if(g_activeSelectionPanel == "LinesControl") {
            DestroySelectionPanel();
         } else {
            CreateSelectionPanel("LinesControl");
         }
         return;
      }
      
      // Button 6: Toggle Labels - Show selection panel for individual label control
      if(sparam == "BtnToggleLabels") {
         if(g_activeSelectionPanel == "LabelControl") {
            DestroySelectionPanel();
         } else {
            CreateSelectionPanel("LabelControl");
         }
         return;
      }
      
      // Button 7: Print Stats
      if(sparam == "BtnPrintStats") {
         PrintCurrentStats();
         Log(1, "Stats printed to log");
      }
      
      // Button 11: History Display Mode (show selection panel)
      if(sparam == "BtnHistoryMode") {
         if(g_activeSelectionPanel == "HistoryMode") {
            DestroySelectionPanel();
         } else {
            CreateSelectionPanel("HistoryMode");
         }
      }
      
      // Button 15: Toggle VLines
      if(sparam == "BtnToggleVLines") {
         g_showVLines = !g_showVLines;
         UpdateButtonStates();
         ApplyVisibilitySettings();
         Log(1, StringFormat("VLines Display: %s", g_showVLines ? "ENABLED" : "DISABLED"));
      }
      
      // Button 16: Toggle HLines
      if(sparam == "BtnToggleHLines") {
         g_showHLines = !g_showHLines;
         UpdateButtonStates();
         ApplyVisibilitySettings();
         Log(1, StringFormat("HLines Display: %s", g_showHLines ? "ENABLED" : "DISABLED"));
      }
      
      // Permanent Control Button (Always Visible) - Direct Toggle
      if(sparam == "BtnVisibilityControls") {
         g_showMainButtons = !g_showMainButtons;
         ApplyVisibilitySettings();
         UpdateButtonStates();
         Log(1, StringFormat("Main Buttons: %s", g_showMainButtons ? "SHOWN" : "HIDDEN"));
      }
      
      // Handle Show Control selections
      if(StringFind(sparam, "SelectShow_") >= 0) {
         int selectedOption = (int)StringToInteger(StringSubstr(sparam, 11));
         switch(selectedOption) {
            case 0: g_showMainButtons = true; break;       // Buttons
            case 1: g_showInfoLabels = true; break;        // InfoLabels
            case 2: g_showOrderLabelsCtrl = true; break;   // OrderLabels
            case 3: g_showVLines = true; break;            // VLines
            case 4: g_showHLines = true; break;            // HLines
         }
         DestroySelectionPanel();
         ApplyVisibilitySettings();
         Log(2, StringFormat("Show control activated: option %d", selectedOption));
      }
      
      // Handle Hide Control selections
      if(StringFind(sparam, "SelectHide_") >= 0) {
         int selectedOption = (int)StringToInteger(StringSubstr(sparam, 11));
         switch(selectedOption) {
            case 0: g_showMainButtons = false; break;      // Buttons
            case 1: g_showInfoLabels = false; break;       // InfoLabels
            case 2: g_showOrderLabelsCtrl = false; break;  // OrderLabels
            case 3: g_showVLines = false; break;           // VLines
            case 4: g_showHLines = false; break;           // HLines
         }
         DestroySelectionPanel();
         ApplyVisibilitySettings();
         Log(2, StringFormat("Hide control activated: option %d", selectedOption));
      }
      
      // Button 7: Debug Level (show selection panel)
      if(sparam == "BtnDebugLevel") {
         if(g_activeSelectionPanel == "DebugLevel") {
            DestroySelectionPanel();
         } else {
            CreateSelectionPanel("DebugLevel");
         }
      }
      
      // Button: Trade Logging Toggle
      if(sparam == "BtnTradeLogging") {
         g_tradeLoggingActive = !g_tradeLoggingActive;
         if(g_tradeLoggingActive) {
            InitializeTradeLog();  // Initialize log file when enabled
         }
         UpdateButtonStates();
         Log(1, StringFormat("Trade Logging: %s", g_tradeLoggingActive ? "ENABLED" : "DISABLED"));
      }
      
      // Button: Level Lines Toggle
      if(sparam == "BtnLevelLines") {
         g_showLevelLines = !g_showLevelLines;
         if(g_showLevelLines) {
            DrawLevelLines();
         } else {
            RemoveLevelLines();
         }
         UpdateButtonStates();
         Log(1, StringFormat("Level Lines: %s", g_showLevelLines ? "SHOWN" : "HIDDEN"));
      }
      
      // Handle Debug Level selections
      if(StringFind(sparam, "SelectDebug_") >= 0) {
         int selectedLevel = (int)StringToInteger(StringSubstr(sparam, 12)); // Extract number from "SelectDebug_X"
         g_currentDebugLevel = selectedLevel;
         DestroySelectionPanel();
         UpdateButtonStates();
         string levelName = "";
         switch(g_currentDebugLevel) {
            case 0: levelName = "OFF"; break;
            case 1: levelName = "CRITICAL"; break;
            case 2: levelName = "INFO"; break;
            case 3: levelName = "VERBOSE"; break;
         }
         Log(1, StringFormat("Debug Level changed to: %d (%s)", g_currentDebugLevel, levelName));
      }
      
      // Handle History Mode selections
      if(StringFind(sparam, "SelectHistory_") >= 0) {
         int selectedMode = (int)StringToInteger(StringSubstr(sparam, 14)); // Extract number from "SelectHistory_X"
         g_historyDisplayMode = selectedMode;
         DestroySelectionPanel();
         UpdateButtonStates();
         string modeName = "";
         switch(g_historyDisplayMode) {
            case 0: modeName = "Overall (All Symbols/All Magic)"; break;
            case 1: modeName = "Current Symbol (All Magic)"; break;
            case 2: modeName = "Current Symbol (Current Magic)"; break;
            case 3: modeName = "Per-Symbol Breakdown"; break;
         }
         Log(2, StringFormat("History Display Mode changed to: %d (%s)", g_historyDisplayMode, modeName));
      }
      
      // Handle Label Control selections
      // Handle Lines Control selections (no ALL button anymore)
      
      if(StringFind(sparam, "SelectLine_") >= 0) {
         int selectedLine = (int)StringToInteger(StringSubstr(sparam, 11));
         
         // Toggle the selected line type
         switch(selectedLine) {
            case 0: // Next Lines - shows next buy/sell level indicators
               g_showNextLevelLines = !g_showNextLevelLines;
               Log(1, StringFormat("Next Lines: %s", g_showNextLevelLines ? "VISIBLE" : "HIDDEN"));
               break;
               
            case 1: // Level Lines - shows grid level lines only
               g_showLevelLines = !g_showLevelLines;
               if(!g_showLevelLines) {
                  RemoveLevelLines();
               } else {
                  DrawLevelLines();
               }
               Log(1, StringFormat("Level Lines: %s", g_showLevelLines ? "VISIBLE" : "HIDDEN"));
               break;
               
            case 2: // Order Labels - shows order placement/close text labels
               g_showOrderLabelsCtrl = !g_showOrderLabelsCtrl;
               if(!g_showOrderLabelsCtrl) {
                  HideAllOrderLabels();
               } else {
                  ShowAllOrderLabels();
               }
               Log(1, StringFormat("Order Labels: %s", g_showOrderLabelsCtrl ? "VISIBLE" : "HIDDEN"));
               break;
         }
         
         // Update button appearance
         string btnName = StringFormat("SelectLine_%d", selectedLine);
         bool isVisible = false;
         string lineNames[] = {"Next Lines", "Level Lines", "Order Labels"};
         
         switch(selectedLine) {
            case 0: isVisible = g_showNextLevelLines; break;
            case 1: isVisible = g_showLevelLines; break;
            case 2: isVisible = g_showOrderLabelsCtrl; break;
         }
         
         ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, isVisible ? clrDarkGreen : clrDarkRed);
         ObjectSetString(0, btnName, OBJPROP_TEXT, isVisible ? ("✓ " + lineNames[selectedLine]) : ("✗ " + lineNames[selectedLine]));
      }
      
      // Handle Label Control selections
      // Handle ALL labels toggle
      if(sparam == "SelectLabel_ALL") {
         // Check current state - if any label is hidden, show all; if all are shown, hide all
         bool allVisible = g_showCurrentProfitLabel && g_showPositionDetailsLabel && g_showSpreadEquityLabel && g_showNextLotCalcLabel &&
                          g_showSingleTrailLabel && g_showGroupTrailLabel && g_showTotalTrailLabel && g_showLevelInfoLabel &&
                          g_showNearbyOrdersLabel && g_showLast5ClosesLabel && g_showHistoryDisplayLabel &&
                          g_showCenterProfitLabel && g_showCenterCycleLabel && g_showCenterBookedLabel && g_showCenterNetLotsLabel;
         
         // Toggle all labels to opposite of current state
         bool newState = !allVisible;
         g_showCurrentProfitLabel = newState;
         g_showPositionDetailsLabel = newState;
         g_showSpreadEquityLabel = newState;
         g_showNextLotCalcLabel = newState;
         g_showSingleTrailLabel = newState;
         g_showGroupTrailLabel = newState;
         g_showTotalTrailLabel = newState;
         g_showLevelInfoLabel = newState;
         g_showNearbyOrdersLabel = newState;
         g_showLast5ClosesLabel = newState;
         g_showHistoryDisplayLabel = newState;
         g_showCenterProfitLabel = newState;
         g_showCenterCycleLabel = newState;
         g_showCenterBookedLabel = newState;
         g_showCenterNetLotsLabel = newState;
         
         // Update ALL button appearance
         ObjectSetInteger(0, "SelectLabel_ALL", OBJPROP_BGCOLOR, newState ? clrDarkGreen : clrDarkRed);
         ObjectSetString(0, "SelectLabel_ALL", OBJPROP_TEXT, newState ? "✓ ALL" : "✗ ALL");
         
         // Update all individual label buttons
         string labelNames[] = {
            "CurrentProfit", "PositionDetails", "SpreadEquity", "NextLotCalc",
            "SingleTrail", "GroupTrail", "TotalTrail", "LevelInfo",
            "NearbyOrders", "Last5Closes", "HistoryDisplay",
            "CenterProfit", "CenterCycle", "CenterBooked", "CenterNetLots"
         };
         
         for(int i = 0; i < 15; i++) {
            string btnName = StringFormat("SelectLabel_%d", i);
            if(newState) {
               ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, clrDarkGreen);
               ObjectSetString(0, btnName, OBJPROP_TEXT, "✓ " + labelNames[i]);
            } else {
               ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, clrDarkRed);
               ObjectSetString(0, btnName, OBJPROP_TEXT, "✗ " + labelNames[i]);
            }
         }
         
         Log(2, StringFormat("All labels toggled: %s", newState ? "VISIBLE" : "HIDDEN"));
      }
      
      if(StringFind(sparam, "SelectLabel_") >= 0 && sparam != "SelectLabel_ALL") {
         int selectedLabel = (int)StringToInteger(StringSubstr(sparam, 12)); // Extract number from "SelectLabel_X"
         
         // Toggle the selected label
         switch(selectedLabel) {
            case 0: g_showCurrentProfitLabel = !g_showCurrentProfitLabel; break;
            case 1: g_showPositionDetailsLabel = !g_showPositionDetailsLabel; break;
            case 2: g_showSpreadEquityLabel = !g_showSpreadEquityLabel; break;
            case 3: g_showNextLotCalcLabel = !g_showNextLotCalcLabel; break;
            case 4: g_showSingleTrailLabel = !g_showSingleTrailLabel; break;
            case 5: g_showGroupTrailLabel = !g_showGroupTrailLabel; break;
            case 6: g_showTotalTrailLabel = !g_showTotalTrailLabel; break;
            case 7: g_showLevelInfoLabel = !g_showLevelInfoLabel; break;
            case 8: g_showNearbyOrdersLabel = !g_showNearbyOrdersLabel; break;
            case 9: g_showLast5ClosesLabel = !g_showLast5ClosesLabel; break;
            case 10: g_showHistoryDisplayLabel = !g_showHistoryDisplayLabel; break;
            case 11: g_showCenterProfitLabel = !g_showCenterProfitLabel; break;
            case 12: g_showCenterCycleLabel = !g_showCenterCycleLabel; break;
            case 13: g_showCenterBookedLabel = !g_showCenterBookedLabel; break;
            case 14: g_showCenterNetLotsLabel = !g_showCenterNetLotsLabel; break;
         }
         
         // Update button appearance to show current state
         string btnName = StringFormat("SelectLabel_%d", selectedLabel);
         bool isVisible = false;
         string labelNames[] = {
            "CurrentProfit", "PositionDetails", "SpreadEquity", "NextLotCalc",
            "SingleTrail", "GroupTrail", "TotalTrail", "LevelInfo",
            "NearbyOrders", "Last5Closes", "HistoryDisplay",
            "CenterProfit", "CenterCycle", "CenterBooked", "CenterNetLots"
         };
         
         switch(selectedLabel) {
            case 0: isVisible = g_showCurrentProfitLabel; break;
            case 1: isVisible = g_showPositionDetailsLabel; break;
            case 2: isVisible = g_showSpreadEquityLabel; break;
            case 3: isVisible = g_showNextLotCalcLabel; break;
            case 4: isVisible = g_showSingleTrailLabel; break;
            case 5: isVisible = g_showGroupTrailLabel; break;
            case 6: isVisible = g_showTotalTrailLabel; break;
            case 7: isVisible = g_showLevelInfoLabel; break;
            case 8: isVisible = g_showNearbyOrdersLabel; break;
            case 9: isVisible = g_showLast5ClosesLabel; break;
            case 10: isVisible = g_showHistoryDisplayLabel; break;
            case 11: isVisible = g_showCenterProfitLabel; break;
            case 12: isVisible = g_showCenterCycleLabel; break;
            case 13: isVisible = g_showCenterBookedLabel; break;
            case 14: isVisible = g_showCenterNetLotsLabel; break;
         }
         
         string labelName = (selectedLabel >= 0 && selectedLabel < 15) ? labelNames[selectedLabel] : "Unknown";
         if(isVisible) {
            ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, clrDarkGreen);
            ObjectSetString(0, btnName, OBJPROP_TEXT, "✓ " + labelName);
         } else {
            ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, clrDarkRed);
            ObjectSetString(0, btnName, OBJPROP_TEXT, "✗ " + labelName);
         }
         
         // Update ALL button state based on whether all labels are now visible
         bool allVisible = g_showCurrentProfitLabel && g_showPositionDetailsLabel && g_showSpreadEquityLabel && g_showNextLotCalcLabel &&
                          g_showSingleTrailLabel && g_showGroupTrailLabel && g_showTotalTrailLabel && g_showLevelInfoLabel &&
                          g_showNearbyOrdersLabel && g_showLast5ClosesLabel && g_showHistoryDisplayLabel &&
                          g_showCenterProfitLabel && g_showCenterCycleLabel && g_showCenterBookedLabel && g_showCenterNetLotsLabel;
         ObjectSetInteger(0, "SelectLabel_ALL", OBJPROP_BGCOLOR, allVisible ? clrDarkGreen : clrDarkRed);
         ObjectSetString(0, "SelectLabel_ALL", OBJPROP_TEXT, allVisible ? "✓ ALL" : "✗ ALL");
      }
      
      // Button 8: Single Trail Mode (show selection panel)
      if(sparam == "BtnSingleTrail") {
         if(g_activeSelectionPanel == "SingleTrail") {
            DestroySelectionPanel();
         } else {
            CreateSelectionPanel("SingleTrail");
         }
      }
      
      // Handle Single Trail selections
      if(StringFind(sparam, "SelectSTrail_") >= 0) {
         int selectedMode = (int)StringToInteger(StringSubstr(sparam, 13)); // Extract number from "SelectSTrail_X"
         g_singleTrailMode = selectedMode;
         DestroySelectionPanel();
         UpdateButtonStates();
         string modeName = "";
         double multiplier = 1.0;
         switch(g_singleTrailMode) {
            case 0: modeName = "TIGHT"; multiplier = 0.5; break;
            case 1: modeName = "NORMAL"; multiplier = 1.0; break;
            case 2: modeName = "LOOSE"; multiplier = 2.0; break;
         }
         Log(1, StringFormat("Single Trail Mode changed to: %d (%s, gap multiplier=%.1fx)", g_singleTrailMode, modeName, multiplier));
      }
      
      // Button 9: Total Trail Mode (show selection panel)
      if(sparam == "BtnTotalTrail") {
         if(g_activeSelectionPanel == "TotalTrail") {
            DestroySelectionPanel();
         } else {
            CreateSelectionPanel("TotalTrail");
         }
      }
      
      // Handle Total Trail selections
      if(StringFind(sparam, "SelectTTrail_") >= 0) {
         int selectedMode = (int)StringToInteger(StringSubstr(sparam, 13)); // Extract number from "SelectTTrail_X"
         g_totalTrailMode = selectedMode;
         DestroySelectionPanel();
         UpdateButtonStates();
         
         // Remove all single trail and group trail lines when switching to total trail
         RemoveAllSingleAndGroupTrailLines();
         
         string modeName = "";
         double multiplier = 1.0;
         switch(g_totalTrailMode) {
            case 0: modeName = "TIGHT"; multiplier = 0.5; break;
            case 1: modeName = "NORMAL"; multiplier = 1.0; break;
            case 2: modeName = "LOOSE"; multiplier = 2.0; break;
         }
         Log(1, StringFormat("Total Trail Mode changed to: %d (%s, gap multiplier=%.1fx)", g_totalTrailMode, modeName, multiplier));
      }
      
      // Button 10: Trail Method Strategy (show selection panel)
      if(sparam == "BtnTrailMethod") {
         if(g_activeSelectionPanel == "TrailMethod") {
            DestroySelectionPanel();
         } else {
            CreateSelectionPanel("TrailMethod");
         }
      }
      
      // Handle Trail Method selections (now for group trail method)
      if(StringFind(sparam, "SelectMethod_") >= 0) {
         int selectedMethod = (int)StringToInteger(StringSubstr(sparam, 13)); // Extract number from "SelectMethod_X"
         g_currentGroupTrailMethod = selectedMethod;
         DestroySelectionPanel();
         UpdateButtonStates();
         string methodName = "";
         switch(g_currentGroupTrailMethod) {
            case 0: methodName = "IGNORE (no group trail)"; break;
            case 1: methodName = "CLOSETOGETHER (group any-side)"; break;
            case 2: methodName = "CLOSETOGETHER_SAMETYPE (group same-side)"; break;
            case 3: methodName = "DYNAMIC (GLO-based switch)"; break;
            case 4: methodName = "DYNAMIC_SAMETYPE (GLO-based same-side)"; break;
            case 5: methodName = "DYNAMIC_ANYSIDE (GLO-based any-side)"; break;
            case 6: methodName = "HYBRID_BALANCED (net exposure based)"; break;
            case 7: methodName = "HYBRID_ADAPTIVE (GLO% + profit based)"; break;
            case 8: methodName = "HYBRID_SMART (multi-factor analysis)"; break;
            case 9: methodName = "HYBRID_COUNT_DIFF (order count difference based)"; break;
         }
         Log(1, StringFormat("Group Trail Method changed to: %d (%s)", g_currentGroupTrailMethod, methodName));
      }
      
      // Button 11: Toggle Order Labels
      if(sparam == "BtnOrderLabels") {
         g_showOrderLabels = !g_showOrderLabels;
         
         if(!g_showOrderLabels) {
            HideAllOrderLabels();
         } else {
            ShowAllOrderLabels();
         }
         
         UpdateButtonStates();
         Log(1, StringFormat("Order Labels Display: %s", g_showOrderLabels ? "ENABLED" : "DISABLED"));
      }
      
      // Button 12: Reset Counters (triple-click protection)
      if(sparam == "BtnResetCounters") {
         datetime currentTime = TimeCurrent();
         
         // Check if this is within 3 seconds of first click
         if(g_resetCountersClickTime > 0 && (currentTime - g_resetCountersClickTime) <= 3) {
            g_resetCountersClickCount++;
            
            if(g_resetCountersClickCount >= 3) {
               // Triple-click confirmed - reset all counters
               ResetAllCounters();
               g_resetCountersClickTime = 0;
               g_resetCountersClickCount = 0;
               Log(1, "Reset Counters: ALL COUNTERS RESET");
            } else {
               Log(1, StringFormat("Reset Counters: Click %d/3 - Click %d more time(s) within 3 seconds", 
                   g_resetCountersClickCount, 3 - g_resetCountersClickCount));
            }
         } else {
            // First click or timeout - restart counter
            g_resetCountersClickTime = currentTime;
            g_resetCountersClickCount = 1;
            Log(1, "Reset Counters: Click 1/3 - Click 2 more times within 3 seconds to reset");
         }
      }
   }
}

//============================= LABEL UPDATE FUNCTION ==============//
void UpdateOrCreateLabel(string name, int xDist, int yDist, string text, color textColor, int fontSize, string font) {
   // Create if doesn't exist
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xDist);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, yDist);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
      ObjectSetString(0, name, OBJPROP_FONT, font);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
   }
   
   // Update text and color
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
}

//============================= CURRENT PROFIT VLINE ==============//
void UpdateCurrentProfitVline() {
   // Get current stats
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity == 0) return;
   
   double cycleProfit = equity - g_lastCloseEquity;
   double openProfit = g_totalProfit;
   double bookedCycle = cycleProfit - openProfit;
   double overallProfit = equity - g_startingEquity;
   
   // Update vline only if we have positions and labels are shown
   if((g_buyCount + g_sellCount) > 0 && g_showLabels) {
      datetime nowTime = TimeCurrent();
      
      // Calculate offset based on current timeframe and candles
      int periodSeconds = PeriodSeconds();
      datetime vlineTime = nowTime + (VlineOffsetCandles * periodSeconds);
      
      string vlineName = "CurrentProfitVLine";
      
      // Delete old and create new
      ObjectDelete(0, vlineName);
      
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(ObjectCreate(0, vlineName, OBJ_VLINE, 0, vlineTime, currentPrice)) {
         // Color based on trail state and profit
         color lineColor;
         if(g_trailActive) {
            lineColor = clrBlue; // Blue when trailing is active
         } else {
            lineColor = (cycleProfit > 1.0) ? clrGreen : (cycleProfit < -1.0) ? clrRed : clrYellow;
         }
         ObjectSetInteger(0, vlineName, OBJPROP_COLOR, lineColor);
         
