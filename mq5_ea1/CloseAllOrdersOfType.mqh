
//+------------------------------------------------------------------+
//| CloseAllOrdersOfType.mqh                                        |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
#include "Utils.mqh"


// whatType options: "ALL", "BUY", "SELL", "PROFIT", "LOSS"
void fnc_CloseAllOrdersOfType(string whatType)
{
   int total = PositionsTotal();
   if(total <= 0)
   {
      fnc_Print(DebugLevel, 1, "[CloseAllOrdersOfType] No open positions.");
      return;
   }

   fnc_Print(DebugLevel, 1, StringFormat("[CloseAllOrdersOfType] Closing type: %s | Total positions: %d", whatType, total));

   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;

      int type = (int)PositionGetInteger(POSITION_TYPE);
      double profit = PositionGetDouble(POSITION_PROFIT);

      bool shouldClose = false;

      if(whatType == "ALL")
         shouldClose = true;
      else if(whatType == "BUY" && type == POSITION_TYPE_BUY)
         shouldClose = true;
      else if(whatType == "SELL" && type == POSITION_TYPE_SELL)
         shouldClose = true;
      else if(whatType == "PROFIT" && profit > 0)
         shouldClose = true;
      else if(whatType == "LOSS" && profit < 0)
         shouldClose = true;

      if(shouldClose)
      {
         fnc_Print(DebugLevel, 1, StringFormat("[CloseAllOrdersOfType] Closing Ticket:%d Type:%s Profit:%.2f",
                                               ticket, (type==POSITION_TYPE_BUY?"BUY":"SELL"), profit));
         trade.PositionClose(ticket);
      }
   }
}
