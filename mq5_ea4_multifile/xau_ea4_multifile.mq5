//+------------------------------------------------------------------+
//| xau_ea4_multifile.mq5                                            |
//| Multi-file grid trading EA with profit trailing                 |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
#include "GlobalsAndInputs.mqh"
#include "Utils.mqh"
#include "TradeFunctions.mqh"
#include "DisplayFunctions.mqh"
#include "OptionalTasks.mqh"

//============================= EA INITIALIZATION ==================//
int OnInit() {
   // Initialize current debug level from input
   g_currentDebugLevel = DebugLevel;
   
   // Parse lot calculation priority sequence
   ParsePrioritySequence();
   
   // Initialize group trail method from input
   g_currentGroupTrailMethod = GroupTrailMethod;
   
   // Initialize order labels from input
   g_showOrderLabels = ShowOrderLabels;
   
   // Initialize button states from inputs
   g_stopNewOrders = InitialStopNewOrders;
   g_noWork = InitialNoWork;
   g_showNextLevelLines = ShowNextLevelLines;
   g_showLevelLines = ShowNextLevelLines;  // Sync with next level lines
   g_singleTrailMode = InitialSingleTrailMode;
   g_totalTrailMode = InitialTotalTrailMode;
   g_showMainButtons = InitialShowButtons;
   g_tradeLoggingActive = EnableTradeLogging;
   
   Log(1, StringFormat("EA Init: Magic=%d Gap=%.1f Lot=%.2f", Magic, GapInPoints, BaseLotSize));
   
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Initialize equity tracking
   if(StartingEquityInput > 0.0) {
      g_startingEquity = StartingEquityInput;
      Log(1, StringFormat("Using input starting equity: %.2f", g_startingEquity));
   } else {
      g_startingEquity = currentEquity;
      Log(1, StringFormat("Using current equity as starting: %.2f", g_startingEquity));
   }
   
   if(LastCloseEquityInput > 0.0) {
      g_lastCloseEquity = LastCloseEquityInput;
      Log(1, StringFormat("Using input last close equity: %.2f", g_lastCloseEquity));
   } else {
      g_lastCloseEquity = currentEquity;
      Log(1, StringFormat("Using current equity as last close: %.2f", g_lastCloseEquity));
   }
   
   g_lastDayEquity = currentEquity;
   
   // Initialize history arrays
   ArrayInitialize(g_last5Closes, 0.0);
   ArrayInitialize(g_dailyProfits, 0.0);
   ArrayInitialize(g_historySymbolDaily, 0.0);
   ArrayInitialize(g_historyOverallDaily, 0.0);
   g_closeCount = 0;
   g_lastDay = -1;
   g_dayIndex = 0;
   
   // Calculate history-based daily profits
   CalculateHistoryDailyProfits();
   
   // Restore state from existing positions (if any)
   RestoreStateFromPositions();
   
   // Initialize order tracking array
   ArrayResize(g_orders, 0);
   g_orderCount = 0;
   SyncOrderTracking();
   Log(1, StringFormat("Order tracking initialized: %d orders found", g_orderCount));
   
   // Always create permanent visibility control button
   CreateVisibilityControlButton();
   Log(1, "Visibility control button created");
   
   // Create main control buttons if enabled
   if(ShowLabels) CreateButtons();
   
   // Apply initial visibility settings based on g_showMainButtons
   ApplyVisibilitySettings();
   
   // Initialize trade logging if enabled
   InitializeTradeLog();
   
   // Force chart redraw
   ChartRedraw(0);
   
   return INIT_SUCCEEDED;
}

//============================= EA MAIN TICK =======================//
void OnTick() {
   // Sync order tracking with live server positions
   SyncOrderTracking();
   
   // Initialize origin price
   if(g_originPrice == 0.0) {
      g_originPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   }
   
   // Calculate adaptive gap
   g_adaptiveGap = CalculateATR();
   
   // Update position statistics
   UpdatePositionStats();
   
   // Check risk limits
   UpdateRiskStatus();
   
   // Calculate next lot sizes
   CalculateNextLots();
   
   // Place grid orders
   PlaceGridOrders();
   
   // Trail total profit
   TrailTotalProfit();
   
   // Trail individual positions
   TrailSinglePositions();
   
   // Update single trail lines
   UpdateSingleTrailLines();
   
   // Update next level lines
   UpdateNextLevelLines();
   
   // Track daily profit (once per day)
   MqlDateTime dt;
   TimeCurrent(dt);
   if(g_lastDay != dt.day) {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      
      // Calculate profit made on the previous day (or since EA start if first day)
      double previousDayProfit = equity - g_lastDayEquity;
      
      // Only record if not the first day (g_lastDay == -1 means EA just started)
      if(g_lastDay != -1) {
         // Shift array and add previous day's profit to history
         for(int i = 4; i > 0; i--) {
            g_dailyProfits[i] = g_dailyProfits[i-1];
         }
         g_dailyProfits[0] = previousDayProfit;
      }
      
      // Update tracking variables for new day
      g_lastDay = dt.day;
      g_lastDayEquity = equity;
      
      // Recalculate history-based daily profits
      CalculateHistoryDailyProfits();
   }
   
   // Always update display (will show or hide based on g_showLabels)
   UpdateCurrentProfitVline();
   
   // Update level lines if enabled
   if(g_showLevelLines) {
      DrawLevelLines();
   }
}

//============================= EA DEINITIALIZATION ================//
void OnDeinit(const int reason) {
   // Clean up buttons and labels
   ObjectDelete(0, "BtnStopNewOrders");
   ObjectDelete(0, "BtnNoWork");
   ObjectDelete(0, "BtnCloseAll");
   ObjectDelete(0, "BtnToggleLabels");
   ObjectDelete(0, "BtnToggleNextLines");
   ObjectDelete(0, "BtnPrintStats");
   ObjectDelete(0, "BtnDebugLevel");
   ObjectDelete(0, "BtnSingleTrail");
   ObjectDelete(0, "BtnTotalTrail");
   ObjectDelete(0, "BtnTrailMethod");
   ObjectDelete(0, "BtnVisibilityControls");  // Permanent control button
   
   // Clean up level lines
   RemoveLevelLines();
   ObjectDelete(0, "total_trail");  // Total trail floor line
   ObjectDelete(0, "CenterProfitLabel");
   ObjectDelete(0, "CenterCycleLabel");
   ObjectDelete(0, "CenterBookedLabel");
   ObjectDelete(0, "CenterNetLotsLabel");
   ObjectDelete(0, "NextBuyLevelUp");
   ObjectDelete(0, "NextBuyLevelDown");
   ObjectDelete(0, "NextSellLevelUp");
   ObjectDelete(0, "NextSellLevelDown");
   
   // Clean up single trail floor lines
   for(int i = 0; i < ArraySize(g_trails); i++) {
      string lineName = StringFormat("TrailFloor_%I64u", g_trails[i].ticket);
      ObjectDelete(0, lineName);
   }
   
   string reasonText = "Unknown";
   switch(reason) {
      case 0: reasonText = "EA Stopped"; break;
      case 1: reasonText = "Program Closed"; break;
      case 2: reasonText = "Recompile"; break;
      case 3: reasonText = "Symbol/Period Changed"; break;
      case 4: reasonText = "Chart Closed"; break;
      case 5: reasonText = "Input Changed"; break;
      case 6: reasonText = "Account Changed"; break;
   }
   
   Log(1, StringFormat("EA Deinit: %s | Positions: %d | Profit: %.2f", 
       reasonText, PositionsTotal(), g_totalProfit));
   
   // Print final statistics (same as displayed in labels)
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double cycleProfit = equity - g_lastCloseEquity;
   double openProfit = g_totalProfit;
   double bookedCycle = cycleProfit - openProfit;
   double overallProfit = equity - g_startingEquity;
   
   // Label 1: Current Profit Label
   string stats1 = StringFormat("P:%.2f/%.2f/%.2f(L%.2f)ML%.2f/%.2f L%.2f/%.2f", 
         cycleProfit, g_trailPeak - cycleProfit, g_trailPeak, bookedCycle, -g_maxLossCycle, -g_overallMaxLoss, 
         g_maxLotsCycle, g_overallMaxLotSize);
   
   // Label 2: Position Details
   int totalCount = g_buyCount + g_sellCount;
   double totalLots = g_buyLots + g_sellLots;
   string stats2 = StringFormat("N:%d/%.2f/%.2f B:%d/%.2f/%.2f S:%d/%.2f/%.2f",
         totalCount, g_netLots, totalLots,
         g_buyCount, g_buyLots, g_buyProfit,
         g_sellCount, g_sellLots, g_sellProfit);
   
   // Label 3: Spread & Equity
   double currentSpread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   string stats3 = StringFormat("Spread:%.1f/%.1f | Equity:%.2f | Overall:%.2f", 
         currentSpread/_Point, g_maxSpread/_Point, equity, overallProfit);
   
   // Label 4: Last 5 Closes
   string stats4 = "Last5 Closes: ";
   for(int i = 0; i < 5; i++) {
      if(i < g_closeCount) {
         stats4 += StringFormat("%.2f", g_last5Closes[i]);
      } else {
         stats4 += "-";
      }
      if(i < 4) stats4 += " | ";
   }
   
   // Label 5: Last 5 Days Symbol-Specific (from history)
   string stats5 = "Last5D Symbol: ";
   for(int i = 0; i < 5; i++) {
      stats5 += StringFormat("%.2f", g_historySymbolDaily[i]);
      if(i < 4) stats5 += " | ";
   }
   
   // Label 6: Last 5 Days Overall (from history)
   string stats6 = "Last5D Overall: ";
   for(int i = 0; i < 5; i++) {
      stats6 += StringFormat("%.2f", g_historyOverallDaily[i]);
      if(i < 4) stats6 += " | ";
   }
   
   // Print all stats
   Print("========== FINAL STATISTICS ==========");
   Print(stats1);
   Print(stats2);
   Print(stats3);
   Print(stats4);
   Print(stats5);
   Print(stats6);
   Print("======================================");
}
