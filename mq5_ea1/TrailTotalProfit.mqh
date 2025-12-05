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
// Percentage of max loss touched in cycle to use for starttrail (e.g., 10% = 0.10)
input double TrailStartPctOfMaxLoss = 0.10;   // 10% of max loss touched
// Percentage of max profit touched in cycle to use for starttrail (e.g., 100% = 1.00)
input double TrailStartPctOfMaxProfit = 1.00; // 100% of max profit touched
// Legacy input (kept for backward compat, not used in new logic)
input double TotalProfitTarget      = 500.0; // e.g., USD 500 (for legacy only)
// Close method enum selection
input CLOSE_METHOD CloseMethodType  = CLOSE_ALL; // method passed to fnc_CloseAllOrdersOfType

// Trail gap control inputs
input double MaxTrailGap            = 250.0;  // Maximum trail gap (absolute cap)
input double BaseTrailGapPct        = 0.50;   // Base trail gap % for low profits (50%)
input double MinTrailGapPct         = 0.20;   // Minimum trail gap % for high profits (20%)
input double GapTransitionProfit    = 1000.0; // Profit level where gap transitions from base to min %

// Minimum order count to activate trailing
input int MinOrderCountToActivateTrail = 3; // Trail profit only activates when open orders >= this count

//============================ Globals =============================//
// NOTE: We read current total profit from a global set by Utils.mqh.
// Ensure Utils.mqh maintains this variable each tick (e.g., in fnc_GetInfoFromOrdersTraversal()).
// If you already use a different name, you can alias it here by renaming the symbol below.
extern double g_TotalProfit;   // <-- declare in Utils.mqh and keep updated

// Trail state (no function args; all globals)
// Trail state: NEW LOGIC
// - starttrail: the profit level at which trailing begins (maxloss if loss touched, else maxprofit)
// - trailgap: 50% of starttrail value (the "cushion" we keep before closing)
// - peakprofit: highest profit reached after trail start
// - floor: peakprofit - trailgap (trigger level for closeall)
// - next_expected: expected profit if closeall triggers at current floor
bool   g_total_trailing_started = false;
double g_total_starttrail       = 0.0; // the entry point for trailing (maxloss touched or maxprofit touched)
double g_total_trailgap         = 0.0; // 50% of starttrail (protection level)
double g_total_peakprofit       = 0.0; // highest profit since trail started
double g_total_floorprofit      = 0.0; // peakprofit - trailgap (closeall trigger)
double g_total_next_closeall_expected = 0.0; // expected profit if floor is hit

bool   g_total_touched_loss_this_cycle = false; // did we ever go into loss?

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
      g_total_starttrail       = 0.0;
      g_total_trailgap         = 0.0;
      g_total_floorprofit      = 0.0;
      g_total_peakprofit       = 0.0;
      g_total_touched_loss_this_cycle = false;
      return;
   }

   // Read current total cycle profit (closed + open) from equity
   double curTotalProfit = AccountInfoDouble(ACCOUNT_EQUITY) - g_last_closeall_equity;

   // Track if we've ever touched a loss in this cycle
   if(curTotalProfit < 0.0)
      g_total_touched_loss_this_cycle = true;

   // ALWAYS calculate starttrail value based on current cycle max loss/profit
   double maxLoss = g_max_loss_current_cycle;
   double maxProfit = g_max_profit_current_cycle;
   double startLoss = maxLoss * TrailStartPctOfMaxLoss;
   double startProfit = maxProfit * TrailStartPctOfMaxProfit;
   double calculatedStartValue = MathMax(startLoss, startProfit);
   
   // Update starttrail value (always visible, even before trail starts)
   if(calculatedStartValue > 0.0)
   {
      g_total_starttrail = calculatedStartValue;
      
      // Calculate adaptive trail gap with diminishing percentage and absolute cap
      double gapPct = BaseTrailGapPct;
      
      // If profit is high, reduce gap percentage (linear interpolation)
      if(curTotalProfit > 0.0 && curTotalProfit > calculatedStartValue)
      {
         if(curTotalProfit >= GapTransitionProfit)
         {
            // Use minimum percentage for high profits
            gapPct = MinTrailGapPct;
         }
         else
         {
            // Linear transition from base to min percentage
            double ratio = curTotalProfit / GapTransitionProfit;
            gapPct = BaseTrailGapPct - (ratio * (BaseTrailGapPct - MinTrailGapPct));
         }
      }
      
      // Calculate gap with adaptive percentage
      double calculatedGap = g_total_starttrail * gapPct;
      
      // Apply absolute maximum cap
      g_total_trailgap = MathMin(calculatedGap, MaxTrailGap);
      g_total_trailgap = MathMax(0.0, g_total_trailgap);
      
      // Expected next close is starttrail - gap (if we hit starttrail and retrace by gap)
      g_total_next_closeall_expected = g_total_starttrail - g_total_trailgap;
      
      fnc_Print(DebugLevel, 3, StringFormat(
         "[TrailGap] curProfit=%.2f starttrail=%.2f gapPct=%.2f%% calcGap=%.2f finalGap=%.2f (cap=%.2f)",
         curTotalProfit, g_total_starttrail, gapPct*100, calculatedGap, g_total_trailgap, MaxTrailGap));
   }

   // If trail not started, check trigger
   if(!g_total_trailing_started)
   {
      fnc_Print(DebugLevel, 2, StringFormat(
         "[TrailTotalProfit] Check: cur=%.2f starttrail=%.2f maxLoss=%.2f maxProfit=%.2f touchedLoss=%s", 
         curTotalProfit, g_total_starttrail, maxLoss, maxProfit, (g_total_touched_loss_this_cycle ? "YES" : "NO")));
      
      bool shouldStartTrail = false;
      
      // Check if we have minimum required order count
      int totalOpenOrders = g_openTotalCount;
      if(totalOpenOrders < MinOrderCountToActivateTrail)
      {
         fnc_Print(DebugLevel, 3, StringFormat(
            "[TrailTotalProfit] NOT STARTING: open orders (%d) < required (%d)", 
            totalOpenOrders, MinOrderCountToActivateTrail));
         return;
      }
      
      if(curTotalProfit > g_total_starttrail && g_total_starttrail > 0.0)
      {
         shouldStartTrail = true;
         fnc_Print(DebugLevel, 1, StringFormat(
            "[TrailTotalProfit] START TRAIL: cur=%.2f > starttrail=%.2f (maxLoss*%.2f=%.2f, maxProfit*%.2f=%.2f)",
            curTotalProfit, g_total_starttrail, TrailStartPctOfMaxLoss, startLoss, TrailStartPctOfMaxProfit, startProfit));
      }

      if(shouldStartTrail)
      {
         g_total_trailing_started = true;
         // Gap already calculated above
         g_total_peakprofit       = curTotalProfit;
         g_total_floorprofit      = g_total_peakprofit - g_total_trailgap;
         g_total_next_closeall_expected = g_total_floorprofit; // update to actual floor

         fnc_Print(DebugLevel, 1, StringFormat(
            "[TrailTotalProfit] Trail initiated: start=%.2f gap=%.2f peak=%.2f floor=%.2f expected=%.2f",
            g_total_starttrail, g_total_trailgap, g_total_peakprofit, g_total_floorprofit, g_total_next_closeall_expected));
      }
      else
      {
         // Not started yet; just log at low verbosity
         fnc_Print(DebugLevel, 3, StringFormat(
            "[TrailTotalProfit] Waiting to start: cur=%.2f starttrail=%.2f maxL=%.2f maxP=%.2f", 
            curTotalProfit, g_total_starttrail, maxLoss, maxProfit));
      }
      return; // trail not active unless started
   }

   // Trail is active: update peak and floor
   if(curTotalProfit > g_total_peakprofit)
   {
      g_total_peakprofit  = curTotalProfit;
      g_total_floorprofit = g_total_peakprofit - g_total_trailgap;
      g_total_next_closeall_expected = g_total_floorprofit; // update expected close profit

      fnc_Print(DebugLevel, 2, StringFormat(
         "[TrailTotalProfit] PEAK UPDATE: peak=%.2f floor=%.2f (gap=%.2f)",
         g_total_peakprofit, g_total_floorprofit, g_total_trailgap));
   }

   // Check retracement: if current <= floor, close all EA positions
   bool retraceHit = (curTotalProfit <= g_total_floorprofit);

   fnc_Print(DebugLevel, 2, StringFormat(
      "[TrailTotalProfit] Monitor: cur=%.2f peak=%.2f floor=%.2f retraceHit=%s",
      curTotalProfit, g_total_peakprofit, g_total_floorprofit, (retraceHit ? "TRUE" : "FALSE")));

   if(retraceHit)
   {
      fnc_Print(DebugLevel, 1, StringFormat(
         "[TrailTotalProfit] CLOSE ALL on trail: cur=%.2f (floor=%.2f)", curTotalProfit, g_total_floorprofit));

      // Prepare line info and draw a vertical marker with relevant info.
      // Name includes epoch to ensure uniqueness.
      string name = StringFormat("TrailClose_%u", (uint)TimeCurrent());
      string text = StringFormat("TrailClose cur=%.2f peak=%.2f floor=%.2f start=%.2f",
                     curTotalProfit, g_total_peakprofit, g_total_floorprofit, g_total_starttrail);
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
      g_total_starttrail       = 0.0;
      g_total_trailgap         = 0.0;
      g_total_floorprofit      = 0.0;
      g_total_peakprofit       = 0.0;
      g_total_touched_loss_this_cycle = false;
      g_total_next_closeall_expected = 0.0; // reset expected profit
   }
}
