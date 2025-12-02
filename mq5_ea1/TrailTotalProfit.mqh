
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


//============================ Inputs ==============================//
// Enable/disable total-profit trailing
input bool   EnableTrailTotalProfit = true;
// Target total profit (account currency) to begin trailing
input double TotalProfitTarget      = 500.0; // e.g., USD 500

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
      return;
   }

   // Read current total open profit (account currency) from Utils global
   double curTotalProfit = g_TotalProfit;

   // If trail not started, check trigger
   if(!g_total_trailing_started)
   {
      if(curTotalProfit >= TotalProfitTarget)
      {
         g_total_trailing_started = true;
         g_total_firstprofit      = TotalProfitTarget;
         g_total_trailprofit      = MathMax(0.0, g_total_firstprofit * 0.5); // half of target
         g_total_peakprofit       = curTotalProfit;
         g_total_floorprofit      = g_total_peakprofit - g_total_trailprofit;

         fnc_Print(DebugLevel, 1, StringFormat(
            "[TrailTotalProfit] START: cur=%.2f target=%.2f trail=%.2f floor=%.2f",
            curTotalProfit, g_total_firstprofit, g_total_trailprofit, g_total_floorprofit));
      }
      else
      {
         // Not started yet; just log at low verbosity
         fnc_Print(DebugLevel, 2, StringFormat(
            "[TrailTotalProfit] Waiting: cur=%.2f < target=%.2f", curTotalProfit, TotalProfitTarget));
      }
      return; // trail not active unless started
   }

   // Trail is active: update peak and floor
   if(curTotalProfit > g_total_peakprofit)
   {
      g_total_peakprofit  = curTotalProfit;
      g_total_floorprofit = g_total_peakprofit - g_total_trailprofit;

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

      // Close all EA positions (symbol+magic filtered inside helper)
      fnc_CloseAllOrdersOfType("ALL");

      // Stats
      g_total_trail_last_close_profit = curTotalProfit;
      g_total_trail_close_count++;

      // Reset or keep? We reset to allow new cycle once positions are reopened.
      g_total_trailing_started = false;
      g_total_firstprofit      = 0.0;
      g_total_trailprofit      = 0.0;
      g_total_floorprofit      = 0.0;
      g_total_peakprofit       = 0.0;
   }
}
