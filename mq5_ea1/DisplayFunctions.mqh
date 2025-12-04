
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

   // compute spread in price terms if possible
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = 0.0;
   if(ask > 0 && bid > 0) spread = (ask - bid);

   // Calculate profit metrics
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // Total profit from opening balance
   double totalProfitFromStart = currentEquity - g_opening_balance;
   
   // Current cycle profit (from last closeall)
   double cycleClosedProfit = currentBalance - g_last_closeall_equity;  // profit from closed orders in cycle
   double cycleOpenProfit = g_current_open_profit;                      // current open positions profit
   double cycleTotalProfit = currentEquity - g_last_closeall_equity;    // total cycle profit
   
   color profitColor = (cycleTotalProfit >= 0) ? clrLime : clrRed;

   // Compact multiline panel (fewer labels -> fewer object ops)
   string panel = StringFormat(
      "Status:%s | Total Profit: %.2f (from opening)\nCycle Profit: Closed:%.2f Open:%.2f Total:%.2f (from last closeall)\nMaxLoss: %.2f/%.2f | MaxProfit: %.2f/%.2f\nTrail: Start:%.2f Gap:%.2f Peak:%.2f Floor:%.2f | Expected:%.2f\nNextLots B:%.2f S:%.2f | Spread:%.5f\nOrders: B%d/%.2f S%d/%.2f Tot:%d NetLots:%.2f\nPerf: Last %.2f ms | Avg %.2f ms",
      (g_TradingAllowed ? "ACTIVE" : "STOPPED"),
      totalProfitFromStart,
      cycleClosedProfit, cycleOpenProfit, cycleTotalProfit,
      g_max_loss_current_cycle, g_max_loss_overall, g_max_profit_current_cycle, g_max_profit_overall,
      g_total_starttrail, g_total_trailgap, g_total_peakprofit, g_total_floorprofit, g_total_next_closeall_expected,
      g_NextBuyLotSize, g_NextSellLotSize, spread,
      g_openBuyCount, g_TotalBuyLots, g_openSellCount, g_TotalSellLots,
      g_openTotalCount, g_TotalNetLots,
      g_LastTickTime, g_AvgTickTime
   );

   // Use single panel label (left-upper corner)
   fnc_CreateOrUpdatePanel("EA_Panel", panel, profitColor, 10, 20, 12);

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
