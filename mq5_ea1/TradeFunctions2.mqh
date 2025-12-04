#property strict
#include <Trade/Trade.mqh>
#include "Utils.mqh"
#include "RiskManagement.mqh"

//============================= Enums =============================//
enum ENUM_TRAILING_ORDER_MODE
{
   MODE_NO_ORDERS = 1,           // No orders at all when trailing
   MODE_GAP_THRESHOLD = 2,       // Orders only if gap > threshold
   MODE_SAME_DIRECTION = 3,      // Only open direction matching net position
   MODE_OPPOSITE_DIRECTION = 4   // Only open opposite direction to net position
};

//============================= Inputs for TradeFunctions2 =============================//
input double BaseGapInPoints = 100.0; // Base gap in points
input bool UseAdaptiveGap = true; // Enable adaptive gap based on ATR
input int ATRPeriod = 14; // ATR period for volatility calculation
input double ATRMultiplier = 1.5; // Multiplier for ATR-based gap
input double MinGapPoints = 50.0; // Minimum gap in points
input double MaxGapPoints = 500.0; // Maximum gap in points

// Hedging parameters
input bool UseHedging = true; // Enable hedging when exposure is too one-sided
input double HedgeExposureThreshold = 5.0; // Net lots threshold to trigger hedge
input double HedgeRatio = 0.5; // Ratio of net exposure to hedge (0.5 = 50%)

// Lot calculation parameters for TradeFunctions2
input double BaseLotSize2 = 0.01; // Base lot size
input int SwitchModeCount2 = 10; // Switch mode after this many orders
input double LotMultiplier = 1.0; // Multiplier for lot progression

// Order placement control during total profit trailing
input ENUM_TRAILING_ORDER_MODE TrailingOrderMode = MODE_GAP_THRESHOLD; // Order placement mode when trailing active
input double TrailingGapThreshold = 200.0; // Min gap between floor and profit for MODE_GAP_THRESHOLD

//============================= Local Globals for TradeFunctions2 =============================//
double g_adaptiveGapPx = 0.0;
double g_NextBuyLotSize2 = 0.01;
double g_NextSellLotSize2 = 0.01;
double g_lastHedgeCheckTime = 0.0;
double g_hedgeCheckInterval = 60.0; // Check for hedging every 60 seconds
int g_CountBuyOrders2 = 0;
int g_CountSellOrders2 = 0;
double g_TotalBuyLots2 = 0.0;
double g_TotalSellLots2 = 0.0;
double g_NetLots2 = 0.0;

//============================= Helper Functions =============================//

// Calculate ATR for adaptive gap
double fnc_CalculateATR(int period)
{
   double atr[];
   ArraySetAsSeries(atr, true);
   
   int handle = iATR(_Symbol, PERIOD_CURRENT, period);
   if(handle == INVALID_HANDLE)
   {
      Print("Error creating ATR indicator");
      return 0.0;
   }
   
   if(CopyBuffer(handle, 0, 0, 1, atr) <= 0)
   {
      Print("Error copying ATR buffer");
      IndicatorRelease(handle);
      return 0.0;
   }
   
   IndicatorRelease(handle);
   return atr[0];
}

// Calculate adaptive gap based on ATR
double fnc_CalculateAdaptiveGap(int debugLevel)
{
   if(!UseAdaptiveGap)
   {
      return BaseGapInPoints * _Point;
   }
   
   double atr = fnc_CalculateATR(ATRPeriod);
   if(atr <= 0.0)
   {
      fnc_Print(debugLevel, 1, "ATR calculation failed, using base gap");
      return BaseGapInPoints * _Point;
   }
   
   // Convert ATR to points
   double atrPoints = atr / _Point;
   
   // Calculate adaptive gap
   double adaptiveGapPoints = atrPoints * ATRMultiplier;
   
   // Clamp to min/max range
   adaptiveGapPoints = MathMax(MinGapPoints, MathMin(MaxGapPoints, adaptiveGapPoints));
   
   fnc_Print(debugLevel, 2, StringFormat("ATR: %.5f | ATR Points: %.2f | Adaptive Gap: %.2f points", 
                                         atr, atrPoints, adaptiveGapPoints));
   
   return adaptiveGapPoints * _Point;
}

// Gather position statistics for TradeFunctions2
void fnc_GetPositionStats2(int debugLevel)
{
   g_CountBuyOrders2 = 0;
   g_CountSellOrders2 = 0;
   g_TotalBuyLots2 = 0.0;
   g_TotalSellLots2 = 0.0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
         
         double lots = PositionGetDouble(POSITION_VOLUME);
         int type = (int)PositionGetInteger(POSITION_TYPE);
         
         if(type == POSITION_TYPE_BUY)
         {
            g_CountBuyOrders2++;
            g_TotalBuyLots2 += lots;
         }
         else if(type == POSITION_TYPE_SELL)
         {
            g_CountSellOrders2++;
            g_TotalSellLots2 += lots;
         }
      }
   }
   
   g_NetLots2 = g_TotalBuyLots2 - g_TotalSellLots2;
   
   fnc_Print(debugLevel, 2, StringFormat("TF2 Stats - Buy: %d (%.2f lots) | Sell: %d (%.2f lots) | Net: %.2f lots", 
                                         g_CountBuyOrders2, g_TotalBuyLots2, 
                                         g_CountSellOrders2, g_TotalSellLots2, 
                                         g_NetLots2));
   
   // Show next expected buy/sell trigger prices
   double nextBuyPrice = 0.0;
   double nextSellPrice = 0.0;
   double sprPx = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   double nowAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double nowBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   nextBuyPrice = nowAsk + g_adaptiveGapPx;
   nextSellPrice = nowBid - g_adaptiveGapPx;
   fnc_Print(debugLevel, 2, StringFormat("Next Buy Trigger Price: %.5f | Next Sell Trigger Price: %.5f", nextBuyPrice, nextSellPrice));
}

// Check if cycle profit is safe for new orders
// Check if order placement is allowed based on TrailingOrderMode
// Returns: true = allow orders, false = block orders
// Sets orderType to restrict direction if needed: 0=both, 1=buy only, 2=sell only
bool fnc_IsCycleProfitSafeForTrading(int debugLevel, int &orderType)
{
   orderType = 0; // Default: allow both directions
   
   fnc_Print(debugLevel, 1, StringFormat("🔎 TF2 Safety Check - Trailing:%s | Mode:%d | NetLots:%.3f", 
                                         g_total_trailing_started ? "ACTIVE" : "INACTIVE",
                                         TrailingOrderMode,
                                         g_NetLots2));
   
   // Only check if trailing is active
   if(!g_total_trailing_started)
   {
      fnc_Print(debugLevel, 3, "TF2: Trailing not started, allowing all trades");
      return true;
   }
   
   // Get current cycle profit
   double curCycleProfit = AccountInfoDouble(ACCOUNT_EQUITY) - g_last_closeall_equity;
   double gapFromFloor = curCycleProfit - g_total_floorprofit;
   
   // Handle different modes
   switch(TrailingOrderMode)
   {
      case MODE_NO_ORDERS:
         fnc_Print(debugLevel, 1, StringFormat("TF2: BLOCKING ALL ORDERS - Mode: NO_ORDERS (trailing active, profit: %.2f)", curCycleProfit));
         return false;
      
      case MODE_GAP_THRESHOLD:
         if(gapFromFloor < TrailingGapThreshold)
         {
            fnc_Print(debugLevel, 1, StringFormat("TF2: BLOCKING ORDERS - Gap from floor (%.2f) < Threshold (%.2f) | Profit: %.2f | Floor: %.2f",
                                                  gapFromFloor, TrailingGapThreshold, curCycleProfit, g_total_floorprofit));
            return false;
         }
         fnc_Print(debugLevel, 2, StringFormat("TF2: Allowing orders - Gap (%.2f) >= Threshold (%.2f)", gapFromFloor, TrailingGapThreshold));
         return true;
      
      case MODE_SAME_DIRECTION:
         if(g_NetLots2 > 0.001) // Net long, allow buy only (small threshold to avoid floating point issues)
         {
            orderType = 1; // Buy only
            fnc_Print(debugLevel, 1, StringFormat("🔷 TF2: SAME_DIRECTION - NetLots: %.3f (LONG) | BUY: ✅ ALLOWED | SELL: 🚫 BLOCKED", g_NetLots2));
         }
         else if(g_NetLots2 < -0.001) // Net short, allow sell only
         {
            orderType = 2; // Sell only
            fnc_Print(debugLevel, 1, StringFormat("🔶 TF2: SAME_DIRECTION - NetLots: %.3f (SHORT) | BUY: 🚫 BLOCKED | SELL: ✅ ALLOWED", g_NetLots2));
         }
         else // Neutral, allow both
         {
            fnc_Print(debugLevel, 1, StringFormat("⚪ TF2: SAME_DIRECTION - NetLots: %.3f (NEUTRAL) | BUY: ✅ ALLOWED | SELL: ✅ ALLOWED", g_NetLots2));
         }
         return true;
      
      case MODE_OPPOSITE_DIRECTION:
         if(g_NetLots2 > 0.001) // Net long, allow sell only
         {
            orderType = 2; // Sell only
            fnc_Print(debugLevel, 1, StringFormat("🔶 TF2: OPPOSITE_DIRECTION - NetLots: %.3f (LONG) | BUY: 🚫 BLOCKED | SELL: ✅ ALLOWED", g_NetLots2));
         }
         else if(g_NetLots2 < -0.001) // Net short, allow buy only
         {
            orderType = 1; // Buy only
            fnc_Print(debugLevel, 1, StringFormat("🔷 TF2: OPPOSITE_DIRECTION - NetLots: %.3f (SHORT) | BUY: ✅ ALLOWED | SELL: 🚫 BLOCKED", g_NetLots2));
         }
         else // Neutral, allow both
         {
            fnc_Print(debugLevel, 1, StringFormat("⚪ TF2: OPPOSITE_DIRECTION - NetLots: %.3f (NEUTRAL) | BUY: ✅ ALLOWED | SELL: ✅ ALLOWED", g_NetLots2));
         }
         return true;
      
      default:
         fnc_Print(debugLevel, 1, "TF2: Unknown TrailingOrderMode, allowing trades");
         return true;
   }
}

// Calculate next lot sizes with martingale logic
void fnc_CalculateNextLotSizes2(int debugLevel)
{
   int maxOrders = MathMax(g_CountBuyOrders2, g_CountSellOrders2);
   
   // Base calculation: progressive lot sizing
   g_NextSellLotSize2 = BaseLotSize2 * (maxOrders + 1) * LotMultiplier;
   g_NextBuyLotSize2 = BaseLotSize2 * (maxOrders + 1) * LotMultiplier;
   
   // Adjust for net exposure
   if(g_NetLots2 > 0) // More buys than sells
   {
      // Increase sell size to balance
      g_NextBuyLotSize2 = 2 * g_NextSellLotSize2 + (g_NetLots2 / 2);
   }
   else if(g_NetLots2 < 0) // More sells than buys
   {
      // Increase buy size to balance
      g_NextSellLotSize2 = 2 * g_NextBuyLotSize2 + (MathAbs(g_NetLots2) / 2);
   }
   
   // Switch mode after threshold
   if(maxOrders >= SwitchModeCount2 && g_NetLots2 != 0)
   {
      double temp = g_NextSellLotSize2;
      g_NextSellLotSize2 = g_NextBuyLotSize2;
      g_NextBuyLotSize2 = temp;
   }
   
   // Normalize to broker's lot step
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   g_NextBuyLotSize2 = MathMax(g_NextBuyLotSize2, minLot);
   g_NextBuyLotSize2 = MathRound(g_NextBuyLotSize2 / stepLot) * stepLot;
   g_NextBuyLotSize2 = MathMin(g_NextBuyLotSize2, MaxSingleLotSize); // Cap max lot size
   
   g_NextSellLotSize2 = MathMax(g_NextSellLotSize2, minLot);
   g_NextSellLotSize2 = MathRound(g_NextSellLotSize2 / stepLot) * stepLot;
   g_NextSellLotSize2 = MathMin(g_NextSellLotSize2, MaxSingleLotSize); // Cap max lot size
   
   fnc_Print(debugLevel, 2, StringFormat("Next Lots - Buy: %.2f | Sell: %.2f", 
                                         g_NextBuyLotSize2, g_NextSellLotSize2));
}

// Check and execute hedging if needed
void fnc_CheckAndHedge(int debugLevel)
{
   if(!UseHedging) return;
   
   // Throttle hedge checks
   double currentTime = (double)TimeCurrent();
   if(currentTime - g_lastHedgeCheckTime < g_hedgeCheckInterval)
      return;
   
   g_lastHedgeCheckTime = currentTime;
   
   double netExposure = MathAbs(g_NetLots2);
   
   if(netExposure < HedgeExposureThreshold)
   {
      fnc_Print(debugLevel, 2, StringFormat("No hedging needed - Net exposure: %.2f < %.2f", 
                                            netExposure, HedgeExposureThreshold));
      return;
   }
   
   // Determine hedge direction (opposite to net exposure)
   ENUM_POSITION_TYPE hedgeType = (g_NetLots2 > 0) ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;
   
   // Calculate hedge lot size
   double hedgeLots = netExposure * HedgeRatio;
   
   // Normalize hedge lot
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   hedgeLots = MathMax(hedgeLots, minLot);
   hedgeLots = MathRound(hedgeLots / stepLot) * stepLot;
   hedgeLots = MathMin(hedgeLots, MaxSingleLotSize); // Cap max lot size
   
   fnc_Print(debugLevel, 1, StringFormat("HEDGE TRIGGERED - Net: %.2f | Hedge: %s %.2f lots", 
                                         g_NetLots2, 
                                         (hedgeType == POSITION_TYPE_BUY ? "BUY" : "SELL"), 
                                         hedgeLots));
   
   // Execute hedge
   trade.SetExpertMagicNumber(Magic);
   if(hedgeType == POSITION_TYPE_BUY)
      trade.Buy(hedgeLots, _Symbol);
   else
      trade.Sell(hedgeLots, _Symbol);
}

//============================= Main Order Placement Function =============================//

void fnc_PlaceLevelOrders2(double currentPrice, int debugLevel)
{
   if(!g_TradingAllowed)
   {
      fnc_Print(debugLevel, 1, "TF2: Trading stopped due to risk limits");
      return;
   }
   
   // Calculate adaptive gap
   g_adaptiveGapPx = fnc_CalculateAdaptiveGap(debugLevel);
   
   // Get position statistics
   fnc_GetPositionStats2(debugLevel);
   
   // Calculate next lot sizes
   fnc_CalculateNextLotSizes2(debugLevel);
   
   // Check for hedging opportunity
   fnc_CheckAndHedge(debugLevel);
   
   // TRAILING ORDER CONTROL: Check if orders allowed based on trailing state and mode
   int allowedOrderType = 0; // 0=both, 1=buy only, 2=sell only
   if(!fnc_IsCycleProfitSafeForTrading(debugLevel, allowedOrderType))
      return; // Skip order placement if blocked by trailing control
   
   // Initialize origin price
   if(g_originPrice == 0)
      g_originPrice = currentPrice;
   
   double sprPx = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   double nowAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double nowBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   static double prevAsk2 = nowAsk;
   static double prevBid2 = nowBid;
   
   fnc_Print(debugLevel, 2, StringFormat("TF2 - PrevAsk: %.5f NowAsk: %.5f | PrevBid: %.5f NowBid: %.5f | Gap: %.5f", 
                                         prevAsk2, nowAsk, prevBid2, nowBid, g_adaptiveGapPx));
   
   // BUY logic
   bool buyAllowed = (allowedOrderType != 2); // 2 = sell only
   bool buyPriceCondition = (nowAsk > prevAsk2);
   
   fnc_Print(debugLevel, 1, StringFormat("🔍 BUY CHECK: PriceMove=%s | Allowed=%s | AllowedType=%d (0=both,1=buyOnly,2=sellOnly)",
                                         buyPriceCondition ? "YES" : "NO",
                                         buyAllowed ? "YES" : "NO",
                                         allowedOrderType));
   
   if(buyPriceCondition && buyAllowed)
   {
      int Llo = fnc_PriceLevelIndex(MathMin(prevAsk2, nowAsk) - sprPx, g_adaptiveGapPx) - 2;
      int Lhi = fnc_PriceLevelIndex(MathMax(prevAsk2, nowAsk) - sprPx, g_adaptiveGapPx) + 2;
      
      for(int L = Llo; L <= Lhi; L++)
      {
         if(!IsEven(L)) continue;
         double trig = fnc_LevelPrice(L, g_adaptiveGapPx) + sprPx;
         fnc_Print(debugLevel, 1, StringFormat("TF2 [BUY Check] Level:%d | CurrentAsk:%.5f | ExpectedTrigger:%.5f | NextBuyLot:%.3f", 
                                              L, nowAsk, trig, g_NextBuyLotSize2));
         if(prevAsk2 <= trig && nowAsk > trig)
         {
            fnc_Print(debugLevel, 1, StringFormat("TF2 [BUY Check] Level:%d Price:%.5f Trigger:%.5f", 
                                                   L, fnc_LevelPrice(L, g_adaptiveGapPx), trig));
            
            if(fnc_HasSameTypeOnLevel(POSITION_TYPE_BUY, L, g_adaptiveGapPx))
            {
               fnc_Print(debugLevel, 1, StringFormat("TF2: Skipped BUY at Level:%d (duplicate on same level)", L));
               continue;
            }
            if(fnc_HasSameTypeNearLevel(POSITION_TYPE_BUY, L, g_adaptiveGapPx, 1, debugLevel))
            {
               fnc_Print(debugLevel, 1, StringFormat("TF2: Skipped BUY at Level:%d (duplicate near level)", L));
               continue;
            }
            
            // Execute buy
            trade.SetExpertMagicNumber(Magic);
            bool buyResult = trade.Buy(g_NextBuyLotSize2, _Symbol);
            fnc_Print(debugLevel, 1, StringFormat("✅ TF2: BUY %s at Level:%d Price:%.5f Lot:%.2f | Result:%s", 
                                                   buyResult ? "EXECUTED" : "FAILED",
                                                   L, fnc_LevelPrice(L, g_adaptiveGapPx), g_NextBuyLotSize2,
                                                   buyResult ? "SUCCESS" : trade.ResultRetcodeDescription()));
         }
      }
   }
   
   // SELL logic
   bool sellAllowed = (allowedOrderType != 1); // 1 = buy only
   bool sellPriceCondition = (nowBid < prevBid2);
   
   fnc_Print(debugLevel, 1, StringFormat("🔍 SELL CHECK: PriceMove=%s | Allowed=%s | AllowedType=%d (0=both,1=buyOnly,2=sellOnly)",
                                         sellPriceCondition ? "YES" : "NO",
                                         sellAllowed ? "YES" : "NO",
                                         allowedOrderType));
   
   if(sellPriceCondition && sellAllowed)
   {
      int Llo = fnc_PriceLevelIndex(MathMin(prevBid2, nowBid) + sprPx, g_adaptiveGapPx) - 2;
      int Lhi = fnc_PriceLevelIndex(MathMax(prevBid2, nowBid) + sprPx, g_adaptiveGapPx) + 2;
      
      for(int L = Lhi; L >= Llo; L--)
      {
         if(!IsOdd(L)) continue;
         double trig = fnc_LevelPrice(L, g_adaptiveGapPx) - sprPx;
         fnc_Print(debugLevel, 1, StringFormat("TF2 [SELL Check] Level:%d | CurrentBid:%.5f | ExpectedTrigger:%.5f | NextSellLot:%.3f", 
                                              L, nowBid, trig, g_NextSellLotSize2));
         if(prevBid2 >= trig && nowBid < trig)
         {
            fnc_Print(debugLevel, 1, StringFormat("TF2 [SELL Check] Level:%d Price:%.5f Trigger:%.5f", 
                                                   L, fnc_LevelPrice(L, g_adaptiveGapPx), trig));
            
            if(fnc_HasSameTypeOnLevel(POSITION_TYPE_SELL, L, g_adaptiveGapPx))
            {
               fnc_Print(debugLevel, 1, StringFormat("TF2: Skipped SELL at Level:%d (duplicate on same level)", L));
               continue;
            }
            if(fnc_HasSameTypeNearLevel(POSITION_TYPE_SELL, L, g_adaptiveGapPx, 1, debugLevel))
            {
               fnc_Print(debugLevel, 1, StringFormat("TF2: Skipped SELL at Level:%d (duplicate near level)", L));
               continue;
            }
            
            // Execute sell
            trade.SetExpertMagicNumber(Magic);
            bool sellResult = trade.Sell(g_NextSellLotSize2, _Symbol);
            fnc_Print(debugLevel, 1, StringFormat("✅ TF2: SELL %s at Level:%d Price:%.5f Lot:%.2f | Result:%s", 
                                                   sellResult ? "EXECUTED" : "FAILED",
                                                   L, fnc_LevelPrice(L, g_adaptiveGapPx), g_NextSellLotSize2,
                                                   sellResult ? "SUCCESS" : trade.ResultRetcodeDescription()));
         }
      }
   }
   
   prevAsk2 = nowAsk;
   prevBid2 = nowBid;
}
