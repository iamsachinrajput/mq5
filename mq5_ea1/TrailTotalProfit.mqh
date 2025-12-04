
//+------------------------------------------------------------------+
//| TrailTotalProfit.mqh                                            |
//| Trails the aggregate open profit across all EA positions.       |
//| When total profit hits the configured target, trail by half     |
//| of that target. Close all EA positions on retracement to floor. |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
#include "Utils.mqh"
#include "CloseAllOrdersOfType.mqh"
#include "graphutils.mqh"


//============================ Inputs ==============================//
// Enable/disable total-profit trailing
input bool   EnableTrailTotalProfit = true;
// Percentage of max loss touched in cycle to use as first target (e.g., 10% = 0.10)
input double TrailTargetPctOfMaxLoss = 0.10; // 10% of max loss touched
// Legacy input (kept for backward compat, but now derived from max loss)
input double TotalProfitTarget      = 500.0; // e.g., USD 500 (overridden if max loss exists)
// Close method enum selection
input CLOSE_METHOD CloseMethodType  = CLOSE_ALL; // method passed to fnc_CloseAllOrdersOfType

//============================ Globals =============================//
// NOTE: We read current total profit from a global set by Utils.mqh.
// Ensure Utils.mqh maintains this variable each tick (e.g., in fnc_GetInfoFromOrdersTraversal()).
// If you already use a different name, you can alias it here by renaming the symbol below.
extern double g_TotalProfit;   // <-- declare in Utils.mqh and keep updated

// Trail state (no function args; all globals)
bool   g_total_trailing_started = false;
double g_total_firstprofit      = 0.0; // the target when trail starts
double g_total_trailprofit      = 0.0; // half of target, used as trail amount
double g_total_floorprofit      = 0.0; // peak - trail; guaranteed take if trail hits
double g_total_peakprofit       = 0.0; // highest total profit observed since trail start
double g_total_cycle_max_loss   = 0.0; // max loss touched in current cycle (after last closeall)
double g_total_next_closeall_expected = 0.0; // expected profit if closeall triggered at current floor

// Optional: stats
double g_total_trail_last_close_profit = 0.0;
int    g_total_trail_close_count       = 0;

//-------------------------- Internal Helpers ----------------------//
bool fnc_HasEAOpenPositions()
{
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)      continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != Magic)   continue;
      int type = (int)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY || type == POSITION_TYPE_SELL)
         return true;
   }
   return false;
}

//===================== Main Trailing Function =====================//
void fnc_TrailTotalProfit()
{
   if(!EnableTrailTotalProfit)
      return;

   // If Utils doesn't have positions, avoid starting trail
   if(!fnc_HasEAOpenPositions())
   {
      // Reset state if no positions remain
      if(g_total_trailing_started)
         fnc_Print(DebugLevel, 1, "[TrailTotalProfit] No EA positions; resetting trailing state.");

      g_total_trailing_started = false;
      g_total_firstprofit      = 0.0;
      g_total_trailprofit      = 0.0;
      g_total_floorprofit      = 0.0;
      g_total_peakprofit       = 0.0;
      g_total_cycle_max_loss   = 0.0; // reset cycle tracking
      return;
   }

   // Read current total open profit (account currency) from Utils global
   double curTotalProfit = g_TotalProfit;

   // Track max loss touched in this cycle (after last closeall)
   if(curTotalProfit < g_total_cycle_max_loss)
      g_total_cycle_max_loss = curTotalProfit;

   // If trail not started, check trigger
   if(!g_total_trailing_started)
   {
      // Compute target: use whichever is larger - max loss or max profit touched in this cycle
      double maxLoss = MathAbs(g_max_Loss_touched_this_cycle);
      double maxProfit = g_max_profit_touched_this_cycle;
      double maxExtent = MathMax(maxLoss, maxProfit); // use whichever is bigger
      
      fnc_Print(DebugLevel, 2, StringFormat(
         "[TrailTotalProfit] TRIGGER CHECK: maxLoss=%.2f maxProfit=%.2f maxExtent=%.2f", 
         maxLoss, maxProfit, maxExtent));
      
      double calculatedTarget = maxExtent * TrailTargetPctOfMaxLoss;
      double target = MathMax(calculatedTarget, TotalProfitTarget); // use max of calculated or legacy

      fnc_Print(DebugLevel, 2, StringFormat(
         "[TrailTotalProfit] Target calculation: calculated=%.2f (%.2f%% of %.2f), legacy=%.2f, final target=%.2f", 
         calculatedTarget, TrailTargetPctOfMaxLoss * 100.0, maxExtent, TotalProfitTarget, target));

      if(curTotalProfit >= target)
      {
         g_total_trailing_started = true;
         g_total_firstprofit      = target;
         g_total_trailprofit      = MathMax(0.0, g_total_firstprofit * 0.5); // half of target
         g_total_peakprofit       = curTotalProfit;
         g_total_floorprofit      = g_total_peakprofit - g_total_trailprofit;
         g_total_next_closeall_expected = g_total_floorprofit; // current expected close profit

         fnc_Print(DebugLevel, 1, StringFormat(
            "[TrailTotalProfit] START: cur=%.2f maxLoss=%.2f maxProfit=%.2f maxExtent=%.2f target=%.2f trail=%.2f floor=%.2f",
            curTotalProfit, maxLoss, maxProfit, maxExtent, g_total_firstprofit, g_total_trailprofit, g_total_floorprofit));
      }
      else
      {
         // Not started yet; just log at low verbosity
         fnc_Print(DebugLevel, 2, StringFormat(
            "[TrailTotalProfit] Waiting: cur=%.2f < target=%.2f (maxLoss=%.2f maxProfit=%.2f)", curTotalProfit, target, maxLoss, maxProfit));
      }
      return; // trail not active unless started
   }

   // Trail is active: update peak and floor
   if(curTotalProfit > g_total_peakprofit)
   {
      g_total_peakprofit  = curTotalProfit;
      g_total_floorprofit = g_total_peakprofit - g_total_trailprofit;
      g_total_next_closeall_expected = g_total_floorprofit; // update expected close profit

      fnc_Print(DebugLevel, 2, StringFormat(
         "[TrailTotalProfit] PEAK UPDATE: peak=%.2f floor=%.2f (trail=%.2f)",
         g_total_peakprofit, g_total_floorprofit, g_total_trailprofit));
   }

   // Check retracement: if current <= floor, close all EA positions
   bool retraceHit = (curTotalProfit <= g_total_floorprofit);

   fnc_Print(DebugLevel, 2, StringFormat(
      "[TrailTotalProfit] cur=%.2f peak=%.2f floor=%.2f retraceHit=%s",
      curTotalProfit, g_total_peakprofit, g_total_floorprofit, (retraceHit ? "TRUE" : "FALSE")));

   if(retraceHit)
   {
      fnc_Print(DebugLevel, 1, StringFormat(
         "[TrailTotalProfit] CLOSE ALL on trail: cur=%.2f (floor=%.2f)", curTotalProfit, g_total_floorprofit));

      // Prepare line info and draw a vertical marker with relevant info.
      // Name includes epoch to ensure uniqueness.
      string name = StringFormat("TrailClose_%u", (uint)TimeCurrent());
      string text = StringFormat("TrailClose cur=%.2f peak=%.2f floor=%.2f target=%.2f",
                                 curTotalProfit, g_total_peakprofit, g_total_floorprofit, g_total_firstprofit);
      // color: positive -> green, negative -> red, zero -> gray
      color clr = clrGray;
      if(curTotalProfit > 0.0) clr = clrGreen;
      else if(curTotalProfit < 0.0) clr = clrRed;

      // Draw marker (function implemented in graphutils.mqh)
      fnc_DrawProfitCloseLine(TimeCurrent(), name, text, clr);

      // Close positions using the configured close method (ALL, BUY, SELL, PROFIT, LOSS, MAJORITY, MINORITY)
      fnc_CloseAllOrdersOfType(CloseMethodType);

      // Reset cycle tracking for fresh cycle
      fnc_ResetCycleTracking();

      // Stats
      g_total_trail_last_close_profit = curTotalProfit;
      g_total_trail_close_count++;

      // Reset or keep? We reset to allow new cycle once positions are reopened.
      g_total_trailing_started = false;
      g_total_firstprofit      = 0.0;
      g_total_trailprofit      = 0.0;
      g_total_floorprofit      = 0.0;
      g_total_peakprofit       = 0.0;
      g_total_cycle_max_loss   = 0.0; // reset cycle tracking for next cycle
      g_total_next_closeall_expected = 0.0; // reset expected profit
   }
}
