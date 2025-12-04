
//+------------------------------------------------------------------+
//| CloseAllOrdersOfType.mqh                                        |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
#include "Utils.mqh"


//============================ Enum ==============================//
enum CLOSE_METHOD
{
   CLOSE_ALL,      // Close all EA positions
   CLOSE_BUY,      // Close only BUY positions
   CLOSE_SELL,     // Close only SELL positions
   CLOSE_PROFIT,   // Close only profitable positions
   CLOSE_LOSS,     // Close only losing positions
   CLOSE_MAJORITY, // Close the side with majority net lots
   CLOSE_MINORITY  // Close the side with minority net lots
};

//============================ Function ==========================//
// whatType: CLOSE_METHOD enum value
void fnc_CloseAllOrdersOfType(CLOSE_METHOD whatType)
{
   int total = PositionsTotal();
   if(total <= 0)
   {
      fnc_Print(DebugLevel, 1, "[CloseAllOrdersOfType] No open positions.");
      return;
   }

   fnc_Print(DebugLevel, 1, StringFormat("[CloseAllOrdersOfType] Closing type: %d | Total positions: %d", (int)whatType, total));

   // prepare majority/minority decision if requested
   int majoritySide = -1; // POSITION_TYPE_BUY or POSITION_TYPE_SELL
   int minoritySide = -1;
   double net = g_netLots; // prefer per-traversal net (bLots - sLots)
   if(whatType == CLOSE_MAJORITY || whatType == CLOSE_MINORITY)
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

      if(whatType == CLOSE_ALL)
         shouldClose = true;
      else if(whatType == CLOSE_BUY && type == POSITION_TYPE_BUY)
         shouldClose = true;
      else if(whatType == CLOSE_SELL && type == POSITION_TYPE_SELL)
         shouldClose = true;
      else if(whatType == CLOSE_PROFIT && profit > 0)
         shouldClose = true;
      else if(whatType == CLOSE_LOSS && profit < 0)
         shouldClose = true;
      else if(whatType == CLOSE_MAJORITY && type == majoritySide)
         shouldClose = true;
      else if(whatType == CLOSE_MINORITY && type == minoritySide)
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
