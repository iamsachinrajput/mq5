
//+------------------------------------------------------------------+
//| CloseAllOrdersOfType.mqh                                        |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
#include "Utils.mqh"


// whatType options: "ALL", "BUY", "SELL", "PROFIT", "LOSS", "MAJORITY", "MINORITY"
// - "MAJORITY": closes orders of the side with the majority net lots (e.g., net>0 -> close BUYs)
// - "MINORITY": closes orders of the side with the minority net lots
void fnc_CloseAllOrdersOfType(string whatType)
{
   int total = PositionsTotal();
   if(total <= 0)
   {
      fnc_Print(DebugLevel, 1, "[CloseAllOrdersOfType] No open positions.");
      return;
   }

   fnc_Print(DebugLevel, 1, StringFormat("[CloseAllOrdersOfType] Closing type: %s | Total positions: %d", whatType, total));

   // prepare majority/minority decision if requested
   int majoritySide = -1; // POSITION_TYPE_BUY or POSITION_TYPE_SELL
   int minoritySide = -1;
   double net = g_netLots; // prefer per-traversal net (bLots - sLots)
   if(whatType == "MAJORITY" || whatType == "MINORITY")
   {
      if(MathAbs(net) < 1e-12)
      {
         fnc_Print(DebugLevel, 1, "[CloseAllOrdersOfType] Net lots are zero; MAJORITY/MINORITY ambiguous. No action.");
         return;
      }
      if(net > 0)
      {
         majoritySide = POSITION_TYPE_BUY;
         minoritySide = POSITION_TYPE_SELL;
      }
      else
      {
         majoritySide = POSITION_TYPE_SELL;
         minoritySide = POSITION_TYPE_BUY;
      }
   }

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
      else if(whatType == "MAJORITY" && type == majoritySide)
         shouldClose = true;
      else if(whatType == "MINORITY" && type == minoritySide)
         shouldClose = true;

      if(shouldClose)
      {
         fnc_Print(DebugLevel, 1, StringFormat("[CloseAllOrdersOfType] Closing Ticket:%d Type:%s Profit:%.2f",
                                               ticket, (type==POSITION_TYPE_BUY?"BUY":"SELL"), profit));
         CTrade ctrade;
         bool ok = ctrade.PositionClose(ticket);
         if(!ok)
         {
            int err = GetLastError();
            fnc_Print(DebugLevel, 0, StringFormat("[CloseAllOrdersOfType] Failed to close Ticket:%d Err:%d", ticket, err));
         }
      }
   }
}
