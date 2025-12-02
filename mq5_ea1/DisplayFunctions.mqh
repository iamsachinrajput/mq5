
#property strict
#include "Utils.mqh"

void fnc_UpdateChartLabel(bool enableDisplay, bool enablePerf)
{
   if(!enableDisplay) return;

   color profitColor = (g_TotalProfit >= 0) ? clrLime : clrRed;




   fnc_CreateOrUpdateLabel("EA_Status",
      StringFormat("Status: %s | Profit: %.0f / %.0f", (g_TradingAllowed ? "ACTIVE" : "STOPPED"), g_TotalProfit,g_equity_profit),
      profitColor, 10, 20);

   fnc_CreateOrUpdateLabel("EA_NextLots",
      StringFormat("Next Buy: %.2f | Next Sell: %.2f", g_NextBuyLotSize, g_NextSellLotSize),
      clrWhite, 10, 50);

   fnc_CreateOrUpdateLabel("EA_Orders",
      StringFormat("ORD: %dB %.2f | %dS %.2f | %dT %.2f | %dN %.2f", g_openBuyCount, g_TotalBuyLots, g_openSellCount, g_TotalSellLots,
                   g_openTotalCount,(g_TotalBuyLots + g_TotalSellLots), (g_openBuyCount-g_openSellCount),g_TotalNetLots),
      clrWhite, 10, 80);

   fnc_CreateOrUpdateLabel("EA_Risk",
      StringFormat("MaxPos:%d | MaxLots:%.2f | MaxLoss:%.2f | Target:%.2f",
                   MaxPositions, MaxTotalLots, MaxLoss, DailyProfitTarget),
      clrWhite, 10, 110);
  
    
      

   if(enablePerf)
   {
      fnc_CreateOrUpdateLabel("EA_Perf",
         StringFormat("Perf: Last %.2f ms | Avg %.2f ms", g_LastTickTime, g_AvgTickTime),
         clrYellow, 10, 140);
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
