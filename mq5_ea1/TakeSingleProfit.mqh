
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
   // Skip single position closing if total trailing is active
   if(g_total_trailing_started)
   {
      fnc_Print(DebugLevel, 3, "[TakeSingleProfit] Skipped: Total trailing is active.");
      return;
   }

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
      {
         profitPer01Lot = (profit / lots) * 0.01;
      }

      fnc_Print(DebugLevel, 3, StringFormat("[TakeSingleProfit] Ticket:%I64u Type:%s Lots:%.2f Profit:%.2f PPL:%.2f",
                                             ticket, (type == POSITION_TYPE_BUY ? "BUY" : "SELL"), lots, profit, profitPer01Lot));

      // Check threshold
      if(profitPer01Lot >= TakeProfitPer01Lot)
      {
         fnc_Print(DebugLevel, 1, StringFormat("[TakeSingleProfit] Closing Ticket:%I64u (profit per 0.01 lot %.2f >= threshold %.2f)",
                                                ticket, profitPer01Lot, TakeProfitPer01Lot));

         bool ok = ctrade.PositionClose(ticket);
         if(ok)
         {
            fnc_Print(DebugLevel, 1, StringFormat("[TakeSingleProfit] Successfully closed Ticket:%I64u", ticket));

            // Update stats only on successful close
            g_short_close_bytrail_total_profit += profit;
            g_short_close_bytrail_total_orders++;
            g_short_close_bytrail_total_lots += lots;
         }
         else
         {
            int err = GetLastError();
            fnc_Print(DebugLevel, 0, StringFormat("[TakeSingleProfit] Failed to close Ticket:%I64u Err:%d", ticket, err));
         }
      }
   }
}

//==============================================================================
// Trailing profit per ticket: once ticket profit hits startTakeProfitPer01Lot,
// it begins trailing (storing highest profit). If it drops by halfValuePer01Lot,
// close ticket. This version uses a TrailInfo array indexed by ticket to store state.
//==============================================================================

// Structure to hold per-ticket trail state
struct TrailInfo
{
   ulong  ticket;
   double highestProfitPer01Lot;
   double startTakeProfitPer01Lot;  // The threshold that triggered tracking
   double halfValuePer01Lot;        // Half of the threshold (lock-in minimum)
   bool   trailingActive;           // Trailing only starts when profit falls to half value
};

// Global array to store trail state for each ticket
TrailInfo g_trails[];  

// Helper: find index in g_trails by ticket; return -1 if not found
int findTrailIndex(ulong tk)
{
   int n = ArraySize(g_trails);
   for(int i=0; i<n; i++)
   {
      if(g_trails[i].ticket == tk)
         return i;
   }
   return -1;
}

// Helper: add a new TrailInfo entry
void addTrailInfo(ulong tk, double highestProfitPer01Lot, double startTakeProfitPer01Lot, double halfValuePer01Lot)
{
   int n = ArraySize(g_trails);
   ArrayResize(g_trails, n+1);
   g_trails[n].ticket = tk;
   g_trails[n].highestProfitPer01Lot = highestProfitPer01Lot;
   g_trails[n].startTakeProfitPer01Lot = startTakeProfitPer01Lot;
   g_trails[n].halfValuePer01Lot = halfValuePer01Lot;
   g_trails[n].trailingActive = false;  // Trailing not active until profit drops to half value
}

// Helper: remove TrailInfo by index
void removeTrailInfo(int index)
{
   int n = ArraySize(g_trails);
   if(index < 0 || index >= n)
      return;
   // Shift elements down
   for(int i=index; i<n-1; i++)
   {
      g_trails[i] = g_trails[i+1];
   }
   ArrayResize(g_trails, n-1);
}

void fnc_TrailAndCloseSingleByProfit()
{
   // Skip single position trailing if total trailing is active
   if(g_total_trailing_started)
   {
      fnc_Print(DebugLevel, 3, "[TrailSingle] Skipped: Total trailing is active.");
      return;
   }

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

      int type = (int)PositionGetInteger(POSITION_TYPE);
      if(type != POSITION_TYPE_BUY && type != POSITION_TYPE_SELL) continue;

      double lots   = PositionGetDouble(POSITION_VOLUME);
      double profit = PositionGetDouble(POSITION_PROFIT);

      // Compute profit per 0.01 lot
      double profitPer01Lot = 0.0;
      if(lots > EPS)
      {
         profitPer01Lot = (profit / lots) * 0.01;
      }

      // Log only profitable orders
      if(profit > 0)
      {
         fnc_Print(DebugLevel, 2, StringFormat("[TrailSingle] Ticket:%I64u Type:%s Lots:%.2f Profit:%.2f PPL:%.2f",
                                                ticket, (type == POSITION_TYPE_BUY ? "BUY" : "SELL"), lots, profit, profitPer01Lot));
      }

      // Find existing TrailInfo for this ticket
      int idx = findTrailIndex(ticket);

      // If profit per 0.01 lot >= startTakeProfitPer01Lot and not yet tracking
      if(profitPer01Lot >= TakeProfitPer01Lot && idx < 0)
      {
         // Start tracking (but trailing not active yet - waiting for lock-in)
         double halfValue = TakeProfitPer01Lot / 2.0;
         addTrailInfo(ticket, profitPer01Lot, TakeProfitPer01Lot, halfValue);
         idx = findTrailIndex(ticket);
         fnc_Print(DebugLevel, 1, StringFormat("[TrailSingle] ✓ START TRACK #%I64u | PPL:%.2f >= Threshold:%.2f | TrailGap:%.2f | Will trail at:%.2f | CloseGap:%.2f",
                                                ticket, profitPer01Lot, TakeProfitPer01Lot, halfValue, halfValue, halfValue));
      }

      // If we are tracking this ticket
      if(idx >= 0)
      {
         double highest = g_trails[idx].highestProfitPer01Lot;
         double halfValue = g_trails[idx].halfValuePer01Lot;
         bool isTrailing = g_trails[idx].trailingActive;

         // Update highest if current is higher
         if(profitPer01Lot > highest)
         {
            g_trails[idx].highestProfitPer01Lot = profitPer01Lot;
            highest = profitPer01Lot;
            double closeAtLevel = highest - halfValue;
            fnc_Print(DebugLevel, 1, StringFormat("[TrailSingle] ⬆ PEAK UPDATE #%I64u | NewPeak:%.2f | WillCloseAt:%.2f", 
                                                   ticket, highest, closeAtLevel));
         }

         // Show status for tracked orders (only if in profit)
         if(profit > 0)
         {
            double closeAtLevel = highest - halfValue;
            if(!isTrailing)
            {
               fnc_Print(DebugLevel, 2, StringFormat("[TrailSingle] 📊 WAITING #%I64u | PPL:%.2f | Peak:%.2f | TrailAt:%.2f (drops %.2f from peak)",
                                                      ticket, profitPer01Lot, highest, halfValue, highest - halfValue));
            }
            else
            {
               double currentDrop = highest - profitPer01Lot;
               fnc_Print(DebugLevel, 2, StringFormat("[TrailSingle] 📈 TRAILING #%I64u | PPL:%.2f | Peak:%.2f | Drop:%.2f | CloseAt:%.2f (drop %.2f)",
                                                      ticket, profitPer01Lot, highest, currentDrop, closeAtLevel, halfValue));
            }
         }

         // Check if profit has dropped from peak to the activation point (halfValue from the START threshold)
         // Once profit reaches the threshold and builds a peak, activate trailing when it drops back to halfValue
         double activationPoint = g_trails[idx].startTakeProfitPer01Lot / 2.0;
         if(!isTrailing && profitPer01Lot <= activationPoint)
         {
            g_trails[idx].trailingActive = true;
            isTrailing = true;
            double closeAtLevel = highest - halfValue;
            fnc_Print(DebugLevel, 1, StringFormat("[TrailSingle] 🔥 TRAIL ACTIVE #%I64u | PPL:%.2f dropped to activation:%.2f | Peak:%.2f | WillClose at:%.2f (when drops %.2f from peak)",
                                                   ticket, profitPer01Lot, activationPoint, highest, closeAtLevel, halfValue));
         }

         // Only close if trailing is active AND profit drops by halfValue from the highest
         if(isTrailing)
         {
            double drop = highest - profitPer01Lot;
            if(drop >= halfValue)
            {
               double finalProfit = profit;
               fnc_Print(DebugLevel, 1, StringFormat("[TrailSingle] 🛑 CLOSING #%I64u | Peak:%.2f → Current:%.2f | Drop:%.2f >= Gap:%.2f | Profit:$%.2f",
                                                      ticket, highest, profitPer01Lot, drop, halfValue, finalProfit));

               bool ok = ctrade.PositionClose(ticket);
               if(ok)
               {
                  fnc_Print(DebugLevel, 1, StringFormat("[TrailSingle] ✅ Closed #%I64u | Banked:$%.2f", ticket, finalProfit));
                  // Update stats
                  g_short_close_bytrail_total_profit += profit;
                  g_short_close_bytrail_total_orders++;
                  g_short_close_bytrail_total_lots += lots;

                  // Remove from trail array
                  removeTrailInfo(idx);
               }
               else
               {
                  int err = GetLastError();
                  fnc_Print(DebugLevel, 0, StringFormat("[TrailSingle] ❌ FAILED #%I64u Err:%d", ticket, err));
               }
            }
         }
      }
   }

   // Cleanup: remove TrailInfo for tickets that no longer exist
   for(int j = ArraySize(g_trails)-1; j>=0; j--)
   {
      ulong tk = g_trails[j].ticket;
      if(!PositionSelectByTicket(tk))
      {
         fnc_Print(DebugLevel, 3, StringFormat("[TrailSingle] Cleanup stale Ticket:%I64u", tk));
         removeTrailInfo(j);
      }
   }
}
