
//+------------------------------------------------------------------+
//| TakeSingleProfit.mqh                                            |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
#include "Utils.mqh"


// Input: profit threshold per 0.01 lot
input double TakeProfitPer01Lot = 10.0; // Example: close if profit per 0.01 lot >= 10 USD

void fnc_CloseOrdersBySingleProfit()
{
   double curBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double curAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   fnc_Print(DebugLevel, 3, StringFormat("[TakeSingleProfit] Current Bid: %.5f | Ask: %.5f", curBid, curAsk));

   int total = PositionsTotal();
   if(total <= 0)
   {
      fnc_Print(DebugLevel, 3, "[TakeSingleProfit] No open positions.");
      return;
   }

   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;

      int type = (int)PositionGetInteger(POSITION_TYPE);
      if(type != POSITION_TYPE_BUY && type != POSITION_TYPE_SELL) continue;

      double lots   = PositionGetDouble(POSITION_VOLUME);
      double profit = PositionGetDouble(POSITION_PROFIT);

      // Calculate profit per 0.01 lot
      double profitPer01Lot = (lots > 0) ? (profit / lots) * 0.01 : 0;

      fnc_Print(DebugLevel, 2, StringFormat("[TakeSingleProfit] Ticket:%d Lots:%.2f Profit:%.2f ProfitPer01Lot:%.2f Threshold:%.2f",
                                            ticket, lots, profit, profitPer01Lot, TakeProfitPer01Lot));

   
      if(profitPer01Lot >= TakeProfitPer01Lot )
      {
         fnc_Print(DebugLevel, 1, StringFormat("[hit TakeSingleProfit] Closing Ticket:%d at ProfitPer01Lot:%.2f", ticket, profitPer01Lot));

         // Track stats (optional)
         g_short_close_bytrail_total_profit += profit;
         g_short_close_bytrail_total_orders++;
         g_short_close_bytrail_total_lots += lots;

         trade.PositionClose(ticket);
      }
   }
}
