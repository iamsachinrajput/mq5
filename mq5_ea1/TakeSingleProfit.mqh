
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

   // Use a local trade object to avoid relying on external globals and to handle close-result reliably
   CTrade ctrade;
   const string sym = _Symbol;
   const double EPS = 1e-12;

   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;

      // Quick filters: symbol and magic
      if(PositionGetString(POSITION_SYMBOL) != sym) continue;
      long posMagic = (long)PositionGetInteger(POSITION_MAGIC);
      if(posMagic != (long)Magic) continue;

      int type = (int)PositionGetInteger(POSITION_TYPE);
      if(type != POSITION_TYPE_BUY && type != POSITION_TYPE_SELL) continue;

      double lots   = PositionGetDouble(POSITION_VOLUME);
      double profit = PositionGetDouble(POSITION_PROFIT);

      // Safely compute profit per 0.01 lot; guard against division by zero
      double profitPer01Lot = 0.0;
      if(lots > EPS)
         profitPer01Lot = profit * 0.01 / lots;

      fnc_Print(DebugLevel, 2, StringFormat("[TakeSingleProfit] Ticket:%d Lots:%.2f Profit:%.2f ProfitPer01Lot:%.4f Threshold:%.2f",
                                            ticket, lots, profit, profitPer01Lot, TakeProfitPer01Lot));

      // Only attempt close when threshold is reached
      if(profitPer01Lot + EPS >= TakeProfitPer01Lot )
      {
         fnc_Print(DebugLevel, 1, StringFormat("[hit TakeSingleProfit] Attempting close Ticket:%d at ProfitPer01Lot:%.4f", ticket, profitPer01Lot));

         bool closed = ctrade.PositionClose(ticket);
         if(closed)
         {
            // Track stats only on successful close
            g_short_close_bytrail_total_profit += profit;
            g_short_close_bytrail_total_orders++;
            g_short_close_bytrail_total_lots += lots;

            fnc_Print(DebugLevel, 1, StringFormat("[TakeSingleProfit] Successfully closed Ticket:%d Profit:%.2f", ticket, profit));
         }
         else
         {
            int err = GetLastError();
            fnc_Print(DebugLevel, 0, StringFormat("[TakeSingleProfit] Failed to close Ticket:%d Error:%d", ticket, err));
         }
      }
   }
}

//----------------------------------------------------------------------
// Trailing-close by profit (per 0.01 lot) WITHOUT broker-side TP/SL
// - Starts trailing when profitPer01Lot >= `startTakeProfitPer01Lot`
// - Uses `halfValuePer01Lot` as the trailing distance
// - Tracks per-ticket highest profit and closes when profit drops by >= halfValue
// - Keeps internal index for each ticket to persist trailing state
//----------------------------------------------------------------------

struct TrailInfo
{
   ulong   ticket;
   double  highestProfitPer01Lot;
   double  halfValuePer01Lot;
   bool    active;
};

// dynamic array holding trail state
TrailInfo g_trails[];

// find index in g_trails for ticket, or -1
int TrailIndexByTicket(const ulong ticket)
{
   int cnt = ArraySize(g_trails);
   for(int i=0;i<cnt;i++)
      if(g_trails[i].ticket == ticket)
         return i;
   return -1;
}

// remove entry by index
void TrailRemoveByIndex(int idx)
{
   int cnt = ArraySize(g_trails);
   if(idx < 0 || idx >= cnt) return;
   for(int i=idx; i<cnt-1; i++)
      g_trails[i] = g_trails[i+1];
   ArrayResize(g_trails, cnt-1);
}

// Add or update trail entry
void TrailAddOrUpdate(const ulong ticket, const double profitPer01Lot, const double halfValuePer01Lot)
{
   int idx = TrailIndexByTicket(ticket);
   if(idx == -1)
   {
      TrailInfo t;
      t.ticket = ticket;
      t.highestProfitPer01Lot = profitPer01Lot;
      t.halfValuePer01Lot = halfValuePer01Lot;
      t.active = true;
      int newSize = ArraySize(g_trails) + 1;
      ArrayResize(g_trails, newSize);
      g_trails[newSize-1] = t;
   }
   else
   {
      if(profitPer01Lot > g_trails[idx].highestProfitPer01Lot)
         g_trails[idx].highestProfitPer01Lot = profitPer01Lot;
      g_trails[idx].halfValuePer01Lot = halfValuePer01Lot; // keep half-value in sync
      g_trails[idx].active = true;
   }
}

// Main trailing function
void fnc_TrailAndCloseSingleByProfit(const double startTakeProfitPer01Lot  = TakeProfitPer01Lot, const double halfValuePer01Lot = TakeProfitPer01Lot/2)
{
   // local trade object
   CTrade ctrade;
   const string sym = _Symbol;
   const double EPS = 1e-12;

   int total = PositionsTotal();
   if(total <= 0)
   {
      fnc_Print(DebugLevel, 3, "[TrailSingle] No open positions.");
      return;
   }

   // Iterate positions and manage trail state
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != sym) continue;
      long posMagic = (long)PositionGetInteger(POSITION_MAGIC);
      if(posMagic != (long)Magic) continue;

      double lots = PositionGetDouble(POSITION_VOLUME);
      double profit = PositionGetDouble(POSITION_PROFIT);
      double profitPer01Lot = 0.0;
      if(lots > EPS) profitPer01Lot = profit * 0.01 / lots;

      int idx = TrailIndexByTicket(ticket);

      // If not yet trailing and reached start threshold, start trailing
      if(idx == -1)
      {
         if(profitPer01Lot + EPS >= startTakeProfitPer01Lot)
         {
            TrailAddOrUpdate(ticket, profitPer01Lot, halfValuePer01Lot);
            fnc_Print(DebugLevel, 1, StringFormat("[TrailSingle] Started trailing Ticket:%d ProfitPer01Lot:%.4f Half:%.4f",
                                                  ticket, profitPer01Lot, halfValuePer01Lot));
         }
         // otherwise do nothing
      }
      else
      {
         // trailing active for this ticket
         double highest = g_trails[idx].highestProfitPer01Lot;
         double half   = g_trails[idx].halfValuePer01Lot;

         // update highest if profit improved
         if(profitPer01Lot > highest)
         {
            g_trails[idx].highestProfitPer01Lot = profitPer01Lot;
            highest = profitPer01Lot;
         }

         // if profit fell by >= half -> close
         if(highest - profitPer01Lot + EPS >= half)
         {
            fnc_Print(DebugLevel, 1, StringFormat("[TrailSingle] Closing Ticket:%d (highest:%.4f current:%.4f half:%.4f)",
                                                  ticket, highest, profitPer01Lot, half));

            bool closed = ctrade.PositionClose(ticket);
            if(closed)
            {
               // update stats
               g_short_close_bytrail_total_profit += profit;
               g_short_close_bytrail_total_orders++;
               g_short_close_bytrail_total_lots += lots;

               fnc_Print(DebugLevel, 1, StringFormat("[TrailSingle] Successfully closed Ticket:%d Profit:%.2f", ticket, profit));
               // remove trail record
               int removeIdx = TrailIndexByTicket(ticket);
               if(removeIdx != -1) TrailRemoveByIndex(removeIdx);
            }
            else
            {
               int err = GetLastError();
               fnc_Print(DebugLevel, 0, StringFormat("[TrailSingle] Failed to close Ticket:%d Error:%d", ticket, err));
            }
         }
      }
   }

   // Cleanup: remove trails for tickets that no longer exist
   int tcnt = ArraySize(g_trails);
   for(int j = tcnt - 1; j >= 0; j--)
   {
      ulong tkt = g_trails[j].ticket;
      bool exists = false;
      // search positions quickly
      int pTotal = PositionsTotal();
      for(int p = 0; p < pTotal; p++)
      {
         if(PositionGetTicket(p) == tkt) { exists = true; break; }
      }
      if(!exists) TrailRemoveByIndex(j);
   }
}
