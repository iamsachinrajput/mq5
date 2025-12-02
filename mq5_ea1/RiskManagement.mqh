
#property strict
#include "Utils.mqh"

bool g_TradingAllowed = true;

void fnc_UpdateRiskStatus()
{
   g_TradingAllowed = true;

   if(PositionsTotal() >= MaxPositions)
   {
      fnc_Print(1, 1, StringFormat("Risk Check: Max positions reached (Positions=%d)", PositionsTotal()));
      g_TradingAllowed = false;
   }
   else if((g_TotalBuyLots + g_TotalSellLots) >= MaxTotalLots)
   {
      fnc_Print(1, 1, StringFormat("Risk Check: Max total lots reached (TotalLots=%.2f)", g_TotalBuyLots + g_TotalSellLots));
      g_TradingAllowed = false;
   }
   else if(g_TotalProfit <= -MaxLoss)
   {
      fnc_Print(1, 1, StringFormat("Risk Check: Max loss exceeded (Profit=%.2f)", g_TotalProfit));
      g_TradingAllowed = false;
   }
   else if(g_TotalProfit >= DailyProfitTarget)
   {
      fnc_Print(1, 1, StringFormat("Risk Check: Daily profit target reached (Profit=%.2f)", g_TotalProfit));
      g_TradingAllowed = false;
   }
}
