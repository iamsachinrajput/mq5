//+------------------------------------------------------------------+
//| mq5_ea_single_file_quick.mq5                                    |
//| Fast single-file grid trading EA with profit trailing          |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

//============================= INPUTS =============================//
// Core Trading Parameters
input int    Magic = 12345;               // Magic number
input double GapInPoints = 1000.0;         // Gap between levels in points
input double BaseLotSize = 0.01;          // Starting lot size
input int    DebugLevel = 0;              // Debug level (0=off, 1=critical, 2=info, 3=verbose)

// Lot Calculation Method
enum ENUM_LOT_METHOD {
   LOT_METHOD_MAXORDERS_SWITCH = 0,    // Max Orders with Switch
   LOT_METHOD_ORDERDIFF_SWITCH = 1,    // Order Difference with Switch
   LOT_METHOD_HEDGE_SAMESIZE = 2       // Hedge Same Size on Switch
};
input ENUM_LOT_METHOD LotChangeMethod = LOT_METHOD_MAXORDERS_SWITCH; // Lot calculation method

// Risk Management (simplified)
input int    MaxPositions = 100000;         // Maximum open positions
input double MaxTotalLots = 500000.0;        // Maximum total lot exposure
input double MaxLossLimit = 500000.0;       // Maximum loss limit
input double DailyProfitTarget = 5000000.0;  // Daily profit target to stop trading

// total Profit Trailing
input bool   EnableTotalTrailing = true;  // Enable total profit trailing
input double TrailStartPct = 0.10;        // Start trail at % of max loss (0.10 = 10%)
input double TrailProfitPct = 0.85;       // Start trail at % of max profit (0.85 = 85%)
input double TrailGapPct = 0.50;          // Trail gap as % of start value (0.50 = 50%)
input double MaxTrailGap = 2500.0;         // Maximum trail gap (absolute cap)

input bool   EnableSingleTrailing = true; // Enable single position trailing
input double SingleProfitThreshold = 0.01; // Profit per 0.01 lot to start trail (negative = auto-calc from gap)

// Adaptive Gap
input bool   UseAdaptiveGap = true;       // Use ATR-based adaptive gap
input int    ATRPeriod = 14;              // ATR period for adaptive gap
input double ATRMultiplier = 1.5;         // ATR multiplier
input double MinGapPoints = 500.0;         // Minimum gap points
input double MaxGapPoints =10000.0;        // Maximum gap points

//============================= GLOBALS ============================//
CTrade trade;

// Price & Grid
double g_originPrice = 0.0;
double g_adaptiveGap = 0.0;

// Position Stats
int    g_buyCount = 0;
int    g_sellCount = 0;
double g_buyLots = 0.0;
double g_sellLots = 0.0;
double g_netLots = 0.0;
double g_totalProfit = 0.0;
double g_nextBuyLot = 0.01;
double g_nextSellLot = 0.01;

// Risk Status
bool g_tradingAllowed = true;

// Total Trailing State
bool   g_trailActive = false;
double g_trailStart = 0.0;
double g_trailGap = 0.0;
double g_trailPeak = 0.0;
double g_trailFloor = 0.0;
double g_lastCloseEquity = 0.0;
double g_startingEquity = 0.0;      // EA start equity for overall P/L tracking
double g_maxLossCycle = 0.0;
double g_maxProfitCycle = 0.0;
double g_overallMaxProfit = 0.0;    // Maximum profit ever reached (from start)
double g_overallMaxLoss = 0.0;      // Maximum loss ever reached (from start)
double g_maxLotsCycle = 0.0;        // Maximum single lot size in current cycle
double g_overallMaxLotSize = 0.0;   // Maximum single lot size ever used (never resets)

// Single Trailing State
struct SingleTrail {
   ulong  ticket;
   double peakPPL;
   double activePeak;    // Peak AFTER activation (for trailing calculation)
   double threshold;
   double gap;
   bool   active;
   int    lastLogTick;   // Track last log tick to avoid spam
};
SingleTrail g_trails[];

// Price tracking
static double g_prevAsk = 0.0;
static double g_prevBid = 0.0;

//============================= UTILITY FUNCTIONS ==================//
void Log(int level, string msg) {
   if(level <= DebugLevel) Print("[Log", level, "] ", msg);
}

bool IsEven(int n) { return (n % 2 == 0); }
bool IsOdd(int n) { return (n % 2 != 0); }

int PriceLevelIndex(double price, double gap) {
   if(gap == 0) return 0;
   return (int)MathFloor((price - g_originPrice) / gap);
}

double LevelPrice(int level, double gap) {
   return g_originPrice + gap * level;
}

double SafeDiv(double a, double b) {
   return (b == 0.0) ? 0.0 : (a / b);
}

//============================= SINGLE THRESHOLD CALCULATION ========//
double CalculateSingleThreshold() {
   // If positive input, use it directly
   if(SingleProfitThreshold > 0) {
      return SingleProfitThreshold;
   }
   
   // Auto-calculate from gap: position should close just before next same-type order
   // For a BUY position, next BUY is 2 gaps away (even levels)
   // For a SELL position, next SELL is 2 gaps away (odd levels)
   // Profit needed per 0.01 lot to reach 2 gaps in favorable direction
   
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   double gapDistance = 2.0 * g_adaptiveGap; // Distance to next same-type order
   double priceMove = gapDistance - spread;  // Account for spread
   
   // Convert to profit per 0.01 lot
   // For 0.01 lot, profit = price_move * contract_size * lot_size
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tickSize == 0) tickSize = _Point;
   
   double profitPer01 = (priceMove / tickSize) * tickValue * 0.01;
   
   // Safety minimum
   if(profitPer01 < 0.01) profitPer01 = 0.01;
   
   Log(3, StringFormat("Auto-calc threshold: Gap=%.1f pts | Distance=%.1f | Spread=%.1f | Threshold=%.2f",
       g_adaptiveGap/_Point, gapDistance/_Point, spread/_Point, profitPer01));
   
   return profitPer01;
}

//============================= ATR CALCULATION ====================//
double CalculateATR() {
   if(!UseAdaptiveGap) return GapInPoints * _Point;
   
   double atr[];
   ArraySetAsSeries(atr, true);
   int handle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
   if(handle == INVALID_HANDLE) return GapInPoints * _Point;
   
   if(CopyBuffer(handle, 0, 0, 1, atr) <= 0) {
      IndicatorRelease(handle);
      return GapInPoints * _Point;
   }
   
   IndicatorRelease(handle);
   double atrPoints = atr[0] / _Point;
   double adaptivePoints = atrPoints * ATRMultiplier;
   adaptivePoints = MathMax(MinGapPoints, MathMin(MaxGapPoints, adaptivePoints));
   
   Log(3, StringFormat("ATR: %.2f pts | Adaptive: %.2f pts", atrPoints, adaptivePoints));
   return adaptivePoints * _Point;
}

//============================= POSITION STATS =====================//
void UpdatePositionStats() {
   g_buyCount = 0;
   g_sellCount = 0;
   g_buyLots = 0.0;
   g_sellLots = 0.0;
   g_totalProfit = 0.0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
      
      int type = (int)PositionGetInteger(POSITION_TYPE);
      double lots = PositionGetDouble(POSITION_VOLUME);
      double profit = PositionGetDouble(POSITION_PROFIT);
      
      g_totalProfit += profit;
      
      if(type == POSITION_TYPE_BUY) {
         g_buyCount++;
         g_buyLots += lots;
      } else if(type == POSITION_TYPE_SELL) {
         g_sellCount++;
         g_sellLots += lots;
      }
   }
   
   g_netLots = g_buyLots - g_sellLots;
   
   // Track max single lot size in cycle and overall
   double maxSingleLot = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
      
      double lots = PositionGetDouble(POSITION_VOLUME);
      if(lots > maxSingleLot) maxSingleLot = lots;
   }
   if(maxSingleLot > g_maxLotsCycle) g_maxLotsCycle = maxSingleLot;
   if(maxSingleLot > g_overallMaxLotSize) g_overallMaxLotSize = maxSingleLot;

   // Profit views: overall P/L since start, cycle profit (booked+open), open vs booked breakdown
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity == 0) return;  // Account data not ready yet
   
   double overallProfit = equity - g_startingEquity;         // overall profit since EA started
   double cycleProfit = equity - g_lastCloseEquity;         // current cycle profit (booked + open since last close-all)
   double openProfit = g_totalProfit;                       // current open P/L
   double bookedCycle = cycleProfit - openProfit;           // booked in this cycle
   
   // Track overall max profit/loss (update every tick, never reset)
   if(overallProfit > g_overallMaxProfit) g_overallMaxProfit = overallProfit;
   if(overallProfit < 0 && MathAbs(overallProfit) > g_overallMaxLoss) g_overallMaxLoss = MathAbs(overallProfit);
   
   // Track cycle max loss (resets on close-all)
   if(cycleProfit < 0) {
      double absLoss = MathAbs(cycleProfit);
      if(absLoss > g_maxLossCycle) g_maxLossCycle = absLoss;
   }   Log(3, StringFormat("Stats B%d/%.2f S%d/%.2f N%.2f ML%.0f/%.0f MP=%.0f/%.0f MaxLot%.2f/%.2f P%.0f(%.0f+%.0f=%.2f)EQ=%.0f", 
      g_buyCount, g_buyLots, g_sellCount, g_sellLots, g_netLots, -g_maxLossCycle, -g_overallMaxLoss, g_maxProfitCycle, g_overallMaxProfit, g_maxLotsCycle, g_overallMaxLotSize, overallProfit, openProfit, bookedCycle, cycleProfit, equity));
}

//============================= RISK CHECK =========================//
void UpdateRiskStatus() {
   g_tradingAllowed = true;
   
   if(PositionsTotal() >= MaxPositions) {
      Log(1, StringFormat("Risk: Max positions %d reached", MaxPositions));
      g_tradingAllowed = false;
   } else if((g_buyLots + g_sellLots) >= MaxTotalLots) {
      Log(1, StringFormat("Risk: Max lots %.2f reached", MaxTotalLots));
      g_tradingAllowed = false;
   } else if(g_totalProfit <= -MaxLossLimit) {
      Log(1, StringFormat("Risk: Max loss %.2f exceeded", MaxLossLimit));
      g_tradingAllowed = false;
   } else if(g_totalProfit >= DailyProfitTarget) {
      Log(1, StringFormat("Risk: Profit target %.2f reached", DailyProfitTarget));
      g_tradingAllowed = false;
   }
}

//============================= LOT CALCULATION ====================//
// Method 1: Max Orders with Switch (original logic)
void CalculateLots_MaxOrders_Switch() {
   int maxOrders = MathMax(g_buyCount, g_sellCount);
   
   // Progressive sizing based on max orders
   g_nextSellLot = BaseLotSize * (maxOrders + 1);
   g_nextBuyLot = BaseLotSize * (maxOrders + 1);
   
   // Balance exposure
   if(g_netLots > 0.01) {
      g_nextBuyLot = 2 * g_nextSellLot + (g_netLots / 2);
   } else if(g_netLots < -0.01) {
      g_nextSellLot = 2 * g_nextBuyLot + (MathAbs(g_netLots) / 2);
   }
   
   // Switch mode after 10 orders
   if(maxOrders >= 10 && MathAbs(g_netLots) > 0.01) {
      double temp = g_nextSellLot;
      g_nextSellLot = g_nextBuyLot;
      g_nextBuyLot = temp;
   }
}

// Method 2: Order Difference with Switch
void CalculateLots_OrderDiff_Switch() {
   int orderDiff = MathAbs(g_buyCount - g_sellCount);
   
   // Progressive sizing based on order count difference
   g_nextSellLot = BaseLotSize * (orderDiff + 1);
   g_nextBuyLot = BaseLotSize * (orderDiff + 1);
   
   // Balance exposure
   if(g_netLots > 0.01) {
      g_nextBuyLot = 2 * g_nextSellLot + (g_netLots / 2);
   } else if(g_netLots < -0.01) {
      g_nextSellLot = 2 * g_nextBuyLot + (MathAbs(g_netLots) / 2);
   }
   
   // Switch mode after 10 order difference
   if(orderDiff >= 10 && MathAbs(g_netLots) > 0.01) {
      double temp = g_nextSellLot;
      g_nextSellLot = g_nextBuyLot;
      g_nextBuyLot = temp;
   }
}

// Method 3: Hedge Same Size on Switch
void CalculateLots_Hedge_SameSize() {
   int maxOrders = MathMax(g_buyCount, g_sellCount);
   
   // Progressive sizing - same for both directions
   g_nextSellLot = BaseLotSize * (maxOrders + 1);
   g_nextBuyLot = BaseLotSize * (maxOrders + 1);
   
   // Keep same size in both directions (no balancing)
   // Switch triggered after 10 orders, but maintain equal sizing
   if(maxOrders >= 10 && MathAbs(g_netLots) > 0.01) {
      // Still apply base lot calculation, but keep them equal
      double baseLot = BaseLotSize * (maxOrders + 1);
      g_nextSellLot = baseLot;
      g_nextBuyLot = baseLot;
   }
}

void NormalizeLots() {
   // Normalize to broker requirements
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   g_nextBuyLot = MathMax(g_nextBuyLot, minLot);
   g_nextBuyLot = MathRound(g_nextBuyLot / stepLot) * stepLot;
   g_nextBuyLot = MathMin(g_nextBuyLot, maxLot);
   
   g_nextSellLot = MathMax(g_nextSellLot, minLot);
   g_nextSellLot = MathRound(g_nextSellLot / stepLot) * stepLot;
   g_nextSellLot = MathMin(g_nextSellLot, maxLot);
}

void CalculateNextLots() {
   // Call appropriate lot calculation method
   switch(LotChangeMethod) {
      case LOT_METHOD_MAXORDERS_SWITCH:
         CalculateLots_MaxOrders_Switch();
         break;
      
      case LOT_METHOD_ORDERDIFF_SWITCH:
         CalculateLots_OrderDiff_Switch();
         break;
      
      case LOT_METHOD_HEDGE_SAMESIZE:
         CalculateLots_Hedge_SameSize();
         break;
      
      default:
         CalculateLots_MaxOrders_Switch();
         break;
   }
   
   // Normalize lots to broker requirements
   NormalizeLots();
}

//============================= ORDER EXECUTION WITH LOT SPLITTING ==//
bool ExecuteOrder(int orderType, double lotSize, string comment = "") {
   if(lotSize <= 0) {
      Log(1, "ExecuteOrder: Invalid lot size");
      return false;
   }
   
   double maxLotPerOrder = 20.0;
   int ordersNeeded = (int)MathCeil(lotSize / maxLotPerOrder);
   
   if(ordersNeeded == 1) {
      // Single order - execute directly
      trade.SetExpertMagicNumber(Magic);
      if(orderType == POSITION_TYPE_BUY) {
         return trade.Buy(lotSize, _Symbol, 0, 0, 0, comment);
      } else {
         return trade.Sell(lotSize, _Symbol, 0, 0, 0, comment);
      }
   }
   
   // Multiple orders needed - split the lot size
   double remainingLots = lotSize;
   int successCount = 0;
   
   Log(2, StringFormat("ExecuteOrder: Splitting %.2f lots into %d orders (max %.2f per order)",
       lotSize, ordersNeeded, maxLotPerOrder));
   
   for(int i = 0; i < ordersNeeded; i++) {
      double currentLot = MathMin(remainingLots, maxLotPerOrder);
      
      // Normalize to broker requirements
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      
      currentLot = MathMax(currentLot, minLot);
      currentLot = MathRound(currentLot / stepLot) * stepLot;
      currentLot = MathMin(currentLot, maxLot);
      
      string orderComment = comment;
      if(ordersNeeded > 1) {
         orderComment = StringFormat("%s [%d/%d]", comment, i + 1, ordersNeeded);
      }
      
      trade.SetExpertMagicNumber(Magic);
      bool result = false;
      
      if(orderType == POSITION_TYPE_BUY) {
         result = trade.Buy(currentLot, _Symbol, 0, 0, 0, orderComment);
      } else {
         result = trade.Sell(currentLot, _Symbol, 0, 0, 0, orderComment);
      }
      
      if(result) {
         successCount++;
         remainingLots -= currentLot;
         Log(2, StringFormat("ExecuteOrder: Order %d/%d placed: %.2f lots (%.2f remaining)",
             i + 1, ordersNeeded, currentLot, remainingLots));
      } else {
         Log(1, StringFormat("ExecuteOrder: Failed to place order %d/%d: %.2f lots",
             i + 1, ordersNeeded, currentLot));
      }
   }
   
   bool allSuccess = (successCount == ordersNeeded);
   if(!allSuccess) {
      Log(1, StringFormat("ExecuteOrder: Partial fill - %d/%d orders succeeded",
          successCount, ordersNeeded));
   }
   
   return allSuccess;
}

//============================= DUPLICATE CHECK ====================//
bool HasOrderOnLevel(int orderType, int level, double gap) {
   double levelPrice = NormalizeDouble(LevelPrice(level, gap), _Digits);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
      
      int type = (int)PositionGetInteger(POSITION_TYPE);
      double openPrice = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN), _Digits);
      
      if(type == orderType && MathAbs(openPrice - levelPrice) < gap * 0.1) {
         return true;
      }
   }
   return false;
}

bool HasOrderNearLevel(int orderType, int level, double gap, int window) {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
      
      int type = (int)PositionGetInteger(POSITION_TYPE);
      if(type != orderType) continue;
      
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      int existingLevel = PriceLevelIndex(openPrice, gap);
      int distance = (int)MathAbs(existingLevel - level);
      
      if(distance <= window) return true;
   }
   return false;
}

//============================= ORDER PLACEMENT ====================//
void PlaceGridOrders() {
   if(!g_tradingAllowed) {
      Log(2, "Trading blocked by risk limits");
      return;
   }
   
   // Block new orders during total trailing
   if(g_trailActive) {
      Log(3, "New orders blocked: total trailing active (closing positions)");
      return;
   }
   
   double nowAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double nowBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   
   // Initialize static variables
   if(g_prevAsk == 0.0) g_prevAsk = nowAsk;
   if(g_prevBid == 0.0) g_prevBid = nowBid;
   
   // BUY logic - price moving up
   // BUY executes at ASK, so trigger should ensure ASK crosses level + half spread
   if(nowAsk > g_prevAsk) {
      int Llo = PriceLevelIndex(MathMin(g_prevAsk, nowAsk), g_adaptiveGap) - 2;
      int Lhi = PriceLevelIndex(MathMax(g_prevAsk, nowAsk), g_adaptiveGap) + 2;
      
      for(int L = Llo; L <= Lhi; L++) {
         if(!IsEven(L)) continue;
         
         // BUY trigger: level price + half spread (so ASK crosses the level accounting for spread)
         double trigger = LevelPrice(L, g_adaptiveGap) + (spread / 2.0);
         if(g_prevAsk <= trigger && nowAsk > trigger) {
            if(HasOrderOnLevel(POSITION_TYPE_BUY, L, g_adaptiveGap)) continue;
            if(HasOrderNearLevel(POSITION_TYPE_BUY, L, g_adaptiveGap, 1)) continue;
            
            string orderComment = StringFormat("BUY L%d", L);
            if(ExecuteOrder(POSITION_TYPE_BUY, g_nextBuyLot, orderComment)) {
               Log(1, StringFormat("BUY %.2f @ L%d (%.5f)", g_nextBuyLot, L, nowAsk));
            }
         }
      }
   }
   
   // SELL logic - price moving down
   // SELL executes at BID, so trigger should ensure BID crosses level - half spread
   if(nowBid < g_prevBid) {
      int Llo = PriceLevelIndex(MathMin(g_prevBid, nowBid), g_adaptiveGap) - 2;
      int Lhi = PriceLevelIndex(MathMax(g_prevBid, nowBid), g_adaptiveGap) + 2;
      
      for(int L = Lhi; L >= Llo; L--) {
         if(!IsOdd(L)) continue;
         
         // SELL trigger: level price - half spread (so BID crosses the level accounting for spread)
         double trigger = LevelPrice(L, g_adaptiveGap) - (spread / 2.0);
         if(g_prevBid >= trigger && nowBid < trigger) {
            if(HasOrderOnLevel(POSITION_TYPE_SELL, L, g_adaptiveGap)) continue;
            if(HasOrderNearLevel(POSITION_TYPE_SELL, L, g_adaptiveGap, 1)) continue;
            
            string orderComment = StringFormat("SELL L%d", L);
            if(ExecuteOrder(POSITION_TYPE_SELL, g_nextSellLot, orderComment)) {
               Log(1, StringFormat("SELL %.2f @ L%d (%.5f)", g_nextSellLot, L, nowBid));
            }
         }
      }
   }
   
   g_prevAsk = nowAsk;
   g_prevBid = nowBid;
}

//============================= TOTAL PROFIT TRAIL =================//
void TrailTotalProfit() {
   if(!EnableTotalTrailing) return;
   
   // Need at least 3 positions to activate
   int totalPos = g_buyCount + g_sellCount;
   if(totalPos < 3) {
      if(g_trailActive) {
         Log(2, "Trail deactivated: insufficient positions");
         g_trailActive = false;
      }
      return;
   }
   
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double cycleProfit = currentEquity - g_lastCloseEquity;
   
   // Track cycle max profit
   if(cycleProfit > 0) {
      if(cycleProfit > g_maxProfitCycle) g_maxProfitCycle = cycleProfit;
   }
   
   // Calculate trail start level
   double lossStart = g_maxLossCycle * TrailStartPct;
   double profitStart = g_maxProfitCycle * TrailProfitPct;  // Use adjustable profit percentage
   g_trailStart = MathMax(lossStart, profitStart);
   
   if(g_trailStart > 0) {
      g_trailGap = MathMin(g_trailStart * TrailGapPct, MaxTrailGap);
   }
   
   // Debug: show trail decision values
   Log(3, StringFormat("Trail DEBUG: cycleProfit=%.2f | MaxLoss=%.2f(start=%.2f) MaxProfit=%.2f(start=%.2f) | trailStart=%.2f | active=%d", 
       cycleProfit, -g_maxLossCycle, -lossStart, g_maxProfitCycle, profitStart, g_trailStart, g_trailActive ? 1 : 0));
   
   // Start trailing: should activate when cycle profit > (max profit already reached - some buffer)
   // Or when cycle profit exceeds max loss recovery + buffer
   // Also check: net lots must be at least 2x base lot size to avoid balanced positions
   double minNetLots = BaseLotSize * 2.0;
   bool hasSignificantExposure = MathAbs(g_netLots) >= minNetLots;
   
   if(!g_trailActive && cycleProfit > g_trailStart && g_trailStart > 0) {
      if(!hasSignificantExposure) {
         Log(2, StringFormat("Trail BLOCKED: Net lots %.2f < minimum %.2f (too balanced)", MathAbs(g_netLots), minNetLots));
      } else {
         g_trailActive = true;
         g_trailPeak = cycleProfit;
         g_trailFloor = g_trailPeak - g_trailGap;
         double lossStart = g_maxLossCycle * TrailStartPct;
         double profitStart = g_maxProfitCycle * 1.0;
         Log(1, StringFormat("Trail START: profit=%.2f start=%.2f gap=%.2f floor=%.2f | NetLots=%.2f | MaxLoss=%.2f LossStart=%.2f MaxProfit=%.2f ProfitStart=%.2f", 
             cycleProfit, g_trailStart, g_trailGap, g_trailFloor, MathAbs(g_netLots), g_maxLossCycle, lossStart, g_maxProfitCycle, profitStart));
      }
   }
   
   // Update trail
   if(g_trailActive) {
      if(cycleProfit > g_trailPeak) {
         g_trailPeak = cycleProfit;
         g_trailFloor = g_trailPeak - g_trailGap;
         Log(2, StringFormat("Trail UPDATE: peak=%.2f floor=%.2f", g_trailPeak, g_trailFloor));
      }
      
      // Check for close trigger
      if(cycleProfit <= g_trailFloor) {
         Log(1, StringFormat("Trail CLOSE ALL: profit=%.2f <= floor=%.2f | Peak=%.2f Gap=%.2f | BUY:%d SELL:%d", 
             cycleProfit, g_trailFloor, g_trailPeak, g_trailGap, g_buyCount, g_sellCount));
         
         // Calculate cycle stats before closing (for vline info)
         double openProfit = g_totalProfit;
         double bookedCycle = cycleProfit - openProfit;
         
         // Close all positions
         for(int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if(!PositionSelectByTicket(ticket)) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
            
            trade.PositionClose(ticket);
         }
         // Draw vertical line with trail & profit info at close
         datetime nowTime = TimeCurrent();
         string vlineName = StringFormat("TrailClose_P%.02f_E%.0f", cycleProfit, AccountInfoDouble(ACCOUNT_EQUITY));
         
         // Delete old object if it exists
         ObjectDelete(0, vlineName);
         
         // Create vertical line with price parameter
         double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(ObjectCreate(0, vlineName, OBJ_VLINE, 0, nowTime, currentPrice)) {
            // Set color based on profit: green if positive, red if negative
            color lineColor = (cycleProfit >= 0) ? clrGreen : clrRed;
            ObjectSetInteger(0, vlineName, OBJPROP_COLOR, lineColor);
            
            // Set line width proportional to profit: base 1, +1 for every 500 profit, max 10
            int lineWidth = 1 + (int)(MathAbs(cycleProfit) / 5.0);
            lineWidth = MathMin(lineWidth, 10);
            lineWidth = MathMax(lineWidth, 1);
            ObjectSetInteger(0, vlineName, OBJPROP_WIDTH, lineWidth);
            
            ObjectSetInteger(0, vlineName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetString(0, vlineName, OBJPROP_TEXT, 
               StringFormat(" P:%.0f|ML:%.0f|Book:%.0f|MaxLot:%.2f|Peak:%.0f|Drop:%.0f|%dpos", 
                  cycleProfit, -g_maxLossCycle, bookedCycle, g_maxLotsCycle, g_trailPeak, g_trailPeak - cycleProfit, g_buyCount + g_sellCount));
            ChartRedraw(0);
            Log(1, StringFormat("VLine created: %s (color: %s, width: %d) | ML:%.0f Book:%.0f Lot:%.2f", vlineName, (cycleProfit >= 0) ? "GREEN" : "RED", lineWidth, -g_maxLossCycle, bookedCycle, g_maxLotsCycle));
         }


         // Reset cycle parameters
         g_lastCloseEquity = AccountInfoDouble(ACCOUNT_EQUITY);
         g_maxLossCycle = 0.0;
         g_maxProfitCycle = 0.0;
         g_maxLotsCycle = 0.0;
         g_trailActive = false;
         g_trailStart = 0.0;
         g_trailGap = 0.0;
         g_trailPeak = 0.0;
         g_trailFloor = 0.0;
         // If you add more cycle stats, reset them here as well
         
         
         
         Log(1, StringFormat("Cycle RESET: new equity=%.2f", g_lastCloseEquity));
      }
   }
}

//============================= SINGLE POSITION TRAIL ==============//
int FindTrailIndex(ulong ticket) {
   int size = ArraySize(g_trails);
   for(int i = 0; i < size; i++) {
      if(g_trails[i].ticket == ticket) return i;
   }
   return -1;
}

void AddTrail(ulong ticket, double peakPPL, double threshold) {
   int size = ArraySize(g_trails);
   ArrayResize(g_trails, size + 1);
   g_trails[size].ticket = ticket;
   g_trails[size].peakPPL = peakPPL;
   g_trails[size].activePeak = 0.0;   // Will be set when trail activates
   g_trails[size].threshold = threshold;
   g_trails[size].gap = threshold / 2.0;
   g_trails[size].active = false;
   g_trails[size].lastLogTick = 0;
}

void RemoveTrail(int index) {
   int size = ArraySize(g_trails);
   if(index < 0 || index >= size) return;
   
   for(int i = index; i < size - 1; i++) {
      g_trails[i] = g_trails[i + 1];
   }
   ArrayResize(g_trails, size - 1);
}

void TrailSinglePositions() {
   if(!EnableSingleTrailing) return;
   if(g_trailActive) return; // Skip when total trailing active
   
   // Get effective threshold (auto-calc if input is negative)
   double effectiveThreshold = CalculateSingleThreshold();
   
   int currentTick = (int)GetTickCount();  // For throttling logs
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
      
      double lots = PositionGetDouble(POSITION_VOLUME);
      double profit = PositionGetDouble(POSITION_PROFIT);
      
      if(lots < 0.001) continue;
      
      double profitPer01 = (profit / lots) * 0.01;
      int idx = FindTrailIndex(ticket);
      
      // Start tracking only when profit reaches threshold
      if(profitPer01 >= effectiveThreshold && idx < 0) {
         AddTrail(ticket, profitPer01, effectiveThreshold);
         idx = FindTrailIndex(ticket);
         double gapValue = effectiveThreshold / 2.0;
         Log(2, StringFormat("Trail START #%I64u PPL=%.2f | Threshold=%.2f Gap=%.2f ActivateAt=%.2f", 
             ticket, profitPer01, effectiveThreshold, gapValue, effectiveThreshold / 2.0));
      }
      
      // Update tracking
      if(idx >= 0) {
         double peak = g_trails[idx].peakPPL;
         double activePeak = g_trails[idx].activePeak;
         double gap = g_trails[idx].gap;
         bool active = g_trails[idx].active;
         
         // Update peak if profit still positive and higher (before activation)
         if(!active && profitPer01 > 0 && profitPer01 > peak) {
            g_trails[idx].peakPPL = profitPer01;
            peak = profitPer01;
            Log(2, StringFormat("Trail PEAK TRACK #%I64u peak=%.2f | AwaitingActivation", ticket, peak));
         }
         
         // Activate when drops to half threshold OR when peak reaches 2x threshold
         // This ensures high-profit positions also trail
         double activationThreshold = effectiveThreshold / 2.0;
         bool shouldActivate = (profitPer01 <= activationThreshold && profitPer01 > 0) || (peak >= effectiveThreshold * 2.0);
         
         if(!active && shouldActivate) {
            g_trails[idx].active = true;
            g_trails[idx].activePeak = peak;  // Set peak at activation point (use tracked peak, not current)
            active = true;
            activePeak = peak;
            Log(1, StringFormat("Trail ACTIVE #%I64u peak=%.2f | Current=%.2f | Ready to Trail", 
                ticket, activePeak, profitPer01));
         }
         
         // Update active peak (trail upward after activation)
         if(active && profitPer01 > activePeak) {
            g_trails[idx].activePeak = profitPer01;
            activePeak = profitPer01;
            Log(2, StringFormat("Trail PEAK UPDATE #%I64u peak=%.2f", ticket, activePeak));
         }
         
         // Show continuous trail status when active (throttle to avoid spam - every 500ms)
         if(active) {
            double trailFloorValue = activePeak - gap;
            if(currentTick - g_trails[idx].lastLogTick >= 500) {  // Log every 500ms
               Log(3, StringFormat("Trail STATUS #%I64u | Peak=%.2f Current=%.2f Floor=%.2f Drop=%.2f", 
                   ticket, activePeak, profitPer01, trailFloorValue, activePeak - profitPer01));
               g_trails[idx].lastLogTick = currentTick;
            }
            
            // Close if current PPL drops below or equal to trail floor
            if(profitPer01 <= trailFloorValue) {
               // Get position details before closing
               string posType = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL";
               double posLots = PositionGetDouble(POSITION_VOLUME);
               double posProfit = PositionGetDouble(POSITION_PROFIT);
               double drop = activePeak - profitPer01;
               
               Log(1, StringFormat("Trail CLOSE #%I64u %s %.2f lots | Profit=%.2f | Trail Stats: Peak=%.2f Current=%.2f Drop=%.2f TrailMin=%.2f", 
                   ticket, posType, posLots, posProfit, activePeak, profitPer01, drop, trailFloorValue));
               
               if(trade.PositionClose(ticket)) {
                  RemoveTrail(idx);
               }
            }
         }
      }
   }
   
   // Cleanup stale trails (positions that no longer exist)
   for(int j = ArraySize(g_trails) - 1; j >= 0; j--) {
      if(!PositionSelectByTicket(g_trails[j].ticket)) {
         Log(2, StringFormat("Trail CLEANUP #%I64u (position closed)", g_trails[j].ticket));
         RemoveTrail(j);
      }
   }
}

//============================= MAIN FUNCTIONS =====================//
int OnInit() {
   Log(1, StringFormat("EA Init: Magic=%d Gap=%.1f Lot=%.2f", Magic, GapInPoints, BaseLotSize));
   
   // Initialize equity tracking
   g_startingEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_lastCloseEquity = g_startingEquity;
   
   return INIT_SUCCEEDED;
}

void OnTick() {
   // Initialize origin price
   if(g_originPrice == 0.0) {
      g_originPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   }
   
   // Calculate adaptive gap
   g_adaptiveGap = CalculateATR();
   
   // Update position statistics
   UpdatePositionStats();
   
   // Check risk limits
   UpdateRiskStatus();
   
   // Calculate next lot sizes
   CalculateNextLots();
   
   // Place grid orders
   PlaceGridOrders();
   
   // Trail total profit
   TrailTotalProfit();
   
   // Trail individual positions
   TrailSinglePositions();
   
   // Update current profit vline (follows current time with stats)
   UpdateCurrentProfitVline();
}

//============================= CURRENT PROFIT VLINE ==============//
void UpdateCurrentProfitVline() {
   // Only show if we have open positions
   if((g_buyCount + g_sellCount) == 0) {
      ObjectDelete(0, "CurrentProfitVLine");
      return;
   }
   
   // Get current stats
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity == 0) return;
   
   double cycleProfit = equity - g_lastCloseEquity;
   double openProfit = g_totalProfit;
   double bookedCycle = cycleProfit - openProfit;
   
   // Update vline at current time (slightly ahead)
   datetime nowTime = TimeCurrent();
   string vlineName = "CurrentProfitVLine";
   
   // Delete old and create new
   ObjectDelete(0, vlineName);
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ObjectCreate(0, vlineName, OBJ_VLINE, 0, nowTime+120, currentPrice)) {
      // Color based on profit
      color lineColor = (cycleProfit >= 0) ? clrGreen : clrRed;
      ObjectSetInteger(0, vlineName, OBJPROP_COLOR, lineColor);
      
      // Width proportional to profit
      int lineWidth = 1 + (int)(MathAbs(cycleProfit) / 5.0);
      lineWidth = MathMin(lineWidth, 10);
      lineWidth = MathMax(lineWidth, 1);
      ObjectSetInteger(0, vlineName, OBJPROP_WIDTH, lineWidth);
      
      ObjectSetInteger(0, vlineName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetString(0, vlineName, OBJPROP_TEXT, 
         StringFormat("LIVE|P:%.0f|ML:%.0f|Book:%.0f|MaxLot:%.2f|B%d/S%d", 
            cycleProfit, -g_maxLossCycle, bookedCycle, g_maxLotsCycle, g_buyCount, g_sellCount));
   }
}
void OnDeinit(const int reason) {
   string reasonText = "Unknown";
   switch(reason) {
      case 0: reasonText = "EA Stopped"; break;
      case 1: reasonText = "Program Closed"; break;
      case 2: reasonText = "Recompile"; break;
      case 3: reasonText = "Symbol/Period Changed"; break;
      case 4: reasonText = "Chart Closed"; break;
      case 5: reasonText = "Input Changed"; break;
      case 6: reasonText = "Account Changed"; break;
   }
   
   Log(1, StringFormat("EA Deinit: %s | Positions: %d | Profit: %.2f", 
       reasonText, PositionsTotal(), g_totalProfit));
}
