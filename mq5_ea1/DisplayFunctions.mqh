
#property strict
#include "Utils.mqh"

// Cached last panel text to avoid unnecessary updates
string g_last_panel_text = "";
color  g_last_panel_color = clrWhite;
int    g_last_panel_lines = 0;

// Lightweight panel updater: only updates label when text or color changes
void fnc_CreateOrUpdatePanel(const string name, const string text, const color col, const int x, const int y, const int fontsize)
{
   // If nothing changed, skip the update
   if(StringCompare(g_last_panel_text, text) == 0 && g_last_panel_color == col && ObjectFind(0, name) != -1)
      return;

   // Split text into lines and create one label per line so multi-line rendering is reliable
   string lines[];
   int count = StringSplit(text, '\n', lines);

   // Create/update each line label with increased spacing to prevent collision
   for(int i=0; i<count; i++)
   {
      string lineName = StringFormat("%s_line%d", name, i);
      int lineY = y + i * (fontsize + 6); // increased spacing from 2 to 6
      if(ObjectFind(0, lineName) == -1)
      {
         ObjectCreate(0, lineName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, lineName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, lineName, OBJPROP_XDISTANCE, x);
         ObjectSetInteger(0, lineName, OBJPROP_YDISTANCE, lineY);
      }
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, col);
      ObjectSetInteger(0, lineName, OBJPROP_FONTSIZE, fontsize);
      ObjectSetString(0, lineName, OBJPROP_TEXT, lines[i]);
   }

   // Cleanup any old line objects beyond current count
   for(int j=count; j<g_last_panel_lines; j++)
   {
      string oldName = StringFormat("%s_line%d", name, j);
      if(ObjectFind(0, oldName) != -1)
         ObjectDelete(0, oldName);
   }

   // Cache values
   g_last_panel_text = text;
   g_last_panel_color = col;
   g_last_panel_lines = count;
}

// Main updater: produces a compact multi-line panel and updates only when needed
void fnc_UpdateChartLabel(bool enableDisplay, bool enablePerf)
{
   if(!enableDisplay) return;

   // Calculate profit metrics
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // Total profit from opening balance
   double totalProfitFromStart = currentEquity - g_opening_balance;
   
   // Current cycle profit (from last closeall) - RESETS on closeall because g_last_closeall_equity is updated
   double cycleTotalProfit = currentEquity - g_last_closeall_equity;    // total cycle profit (closed + open)
   double cycleOpenProfit = g_current_open_profit;                      // current open positions profit
   double cycleClosedProfit = cycleTotalProfit - cycleOpenProfit;       // closed orders profit = total - open
   
   color profitColor = (cycleTotalProfit >= 0) ? clrLime : clrRed;

   // Compact multiline panel (fewer labels -> fewer object ops)
   string panel = StringFormat(
      "Status:%s | Profit T:%.0f (%.0f + %.0f =%.0f )\nMax Loss: %.0f/%.0f Profit: %.0f/%.0f\nTrail: Start:%.0f Gap:%.0f Peak:%.0f Floor:%.0f | wish:%.0f\nNextLots B:%.2f S:%.2f \nSpread: %.5f/%.5f\nOrders: B%d/%.2f S%d/%.2f Tot:%d NetLots:%.2f\n%s\nPerf: Last %.2f ms | Avg %.2f ms",
      (g_TradingAllowed ? "ACTIVE" : "STOPPED"),
      totalProfitFromStart,
      cycleClosedProfit, cycleOpenProfit, cycleTotalProfit,
      g_max_loss_current_cycle, g_max_loss_overall, g_max_profit_current_cycle, g_max_profit_overall,
      g_total_starttrail, g_total_trailgap, g_total_peakprofit, g_total_floorprofit, g_total_next_closeall_expected,
      g_NextBuyLotSize, g_NextSellLotSize, g_current_spread_px, g_max_spread_px,
      g_openBuyCount, g_TotalBuyLots, g_openSellCount, g_TotalSellLots,
      g_openTotalCount, g_TotalNetLots,
      fnc_GetLast10CloseallProfits(),
      g_LastTickTime, g_AvgTickTime
   );

   // Use single panel label (left-upper corner)
   fnc_CreateOrUpdatePanel("EA_Panel", panel, profitColor, 10, 5, 12);

   // Optional: performance label kept separate and updated only when perf enabled
   if(enablePerf)
   {
      string perfText = StringFormat("Perf: Last %.2f ms | Avg %.2f ms", g_LastTickTime, g_AvgTickTime);
      // Reuse existing small label function for perf to avoid adding another cached variable
      fnc_CreateOrUpdateLabel("EA_Perf", perfText, clrYellow, 10, 140);
   }
}

void fnc_CreateOrUpdateLabel(string name, string text, color col, int x, int y)
{
   if(ObjectFind(0, name) == -1)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   }
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 14);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

// Comprehensive deinit summary - displays all tracked information when EA closes
void fnc_PrintDeinitSummary(int reason)
{
   string reasonText = "";
   switch(reason)
   {
      case 1:  reasonText = "Program Termination"; break;
      case 2:  reasonText = "EA Removed"; break;
      case 3:  reasonText = "EA Recompiled"; break;
      case 4:  reasonText = "Chart Changed"; break;
      case 5:  reasonText = "Chart Closed"; break;
      case 6:  reasonText = "Parameters Changed"; break;
      case 7:  reasonText = "Account Changed"; break;
      case 8:  reasonText = "Symbol Changed"; break;
      case 9:  reasonText = "Initialization Failed"; break;
      default: reasonText = "Unknown Reason"; break;
   }
   
   // Calculate cycle profit from last closeall (same as in fnc_UpdateChartLabel)
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double cycleTotalProfit = currentEquity - g_last_closeall_equity;
   double cycleOpenProfit = g_current_open_profit;
   double cycleClosedProfit = cycleTotalProfit - cycleOpenProfit;
   double totalProfitFromStart = g_opening_balance > 0 ? (currentEquity - g_opening_balance) : 0.0;
   
   Print("");
   Print("═════════════════════════════════════════════════════════════════════════════════");
   Print("                          EA DEINIT SUMMARY REPORT");
   Print("═════════════════════════════════════════════════════════════════════════════════");
   Print("");
   
   Print("━━ TERMINATION INFO ━━");
   Print("  Reason: " + reasonText);
   Print("  Symbol: " + _Symbol);
   Print("");
   
   Print("━━ PROFIT TRACKING ━━");
   Print("  Starting Equity: ", g_opening_balance);
   Print("  Current Equity: ", currentEquity);
   Print("  Total P&L from Start: ", totalProfitFromStart);
   Print("");
   Print("  Current Cycle Closed P&L: ", cycleClosedProfit);
   Print("  Current Cycle Open P&L: ", cycleOpenProfit);
   Print("  Current Cycle Total: ", cycleTotalProfit);
   Print("");
   
   Print("━━ MAXIMUM TOUCH POINTS (Overall) ━━");
   Print("  Max Loss Touched: ", g_max_loss_overall, " (drawdown threshold)");
   Print("  Max Profit Touched: ", g_max_profit_overall);
   Print("");
   
   Print("━━ CURRENT CYCLE EXTREMES ━━");
   Print("  Max Loss in Cycle: ", g_max_loss_current_cycle);
   Print("  Max Profit in Cycle: ", g_max_profit_current_cycle);
   Print("");
   
   Print("━━ TRAILING STATISTICS ━━");
   Print("  Trail Start Profit: ", g_total_starttrail);
   Print("  Trail Gap Used: ", g_total_trailgap);
   Print("  Peak Profit Reached: ", g_total_peakprofit);
   Print("  Floor Level (Close Trigger): ", g_total_floorprofit);
   Print("");
   
   Print("━━ CLOSE-ALL HISTORY ━━");
   Print("  Total Close-All Events: ", g_closeall_count);
   if(g_closeall_count > 0)
   {
      double sum = 0.0;
      for(int i = 0; i < MAX_CLOSEALL_HISTORY; i++)
         sum += g_closeall_profits[i];
      double avgProfit = sum / (double)(g_closeall_count > MAX_CLOSEALL_HISTORY ? MAX_CLOSEALL_HISTORY : g_closeall_count);
      Print("  Average Profit per Close-All: ", avgProfit);
   }
   Print("");
   
   Print("━━ ORDER & POSITION STATISTICS ━━");
   Print("  Total Open Positions: ", g_openTotalCount, " (Buy: ", g_openBuyCount, " | Sell: ", g_openSellCount, ")");
   Print("  Total Open Lots: ", (g_TotalBuyLots + g_TotalSellLots), " (Net: ", g_TotalNetLots, ")");
   Print("  Deepest Buy Level: ", g_deepest_buy_price);
   Print("  Deepest Sell Level: ", g_deepest_sell_price);
   Print("");
   
   Print("━━ SPREAD ANALYSIS ━━");
   Print("  Current Spread: ", g_current_spread_px);
   Print("  Max Spread Seen: ", g_max_spread_px);
   Print("");
   
   Print("━━ PERFORMANCE ━━");
   Print("  Total Ticks Processed: ", g_TickCount);
   Print("  Last Tick Time: ", g_LastTickTime, " ms");
   Print("  Average Tick Time: ", g_AvgTickTime, " ms");
   Print("");
   
   Print("━━ TRAIL BY PROFIT STATISTICS ━━");
   Print("  Total Orders Closed by Single Profit Trail: ", g_short_close_bytrail_total_orders);
   Print("  Total Profit from Single Profit Trail: ", g_short_close_bytrail_total_profit);
   Print("  Total Lots Closed by Single Profit Trail: ", g_short_close_bytrail_total_lots);
   Print("");
   
   Print("═════════════════════════════════════════════════════════════════════════════════");
   Print("                          END OF DEINIT SUMMARY");
   Print("═════════════════════════════════════════════════════════════════════════════════");
   Print("");
}

