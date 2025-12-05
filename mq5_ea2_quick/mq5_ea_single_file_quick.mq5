//+------------------------------------------------------------------+
//| mq5_ea_single_file_quick.mq5                                    |
//| Fast single-file grid trading EA with profit trailing          |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

//============================= INPUTS =============================//
// Core Trading Parameters
input int    Magic = 12345;               // Magic number
input double GapInPoints = 100.0;         // Gap between levels in points
input double BaseLotSize = 0.01;          // Starting lot size
input int    DebugLevel = 0;              // Debug level (0=off, 1=critical, 2=info, 3=verbose)

// Risk Management (simplified)
input int    MaxPositions = 1000;         // Maximum open positions
input double MaxTotalLots = 500.0;        // Maximum total lot exposure
input double MaxLossLimit = 5000.0;       // Maximum loss limit
input double DailyProfitTarget = 5000.0;  // Daily profit target to stop trading

// Profit Trailing
input bool   EnableTotalTrailing = true;  // Enable total profit trailing
input double TrailStartPct = 0.10;        // Start trail at % of max loss (0.10 = 10%)
input double TrailGapPct = 0.50;          // Trail gap as % of start value (0.50 = 50%)
input double MaxTrailGap = 250.0;         // Maximum trail gap (absolute cap)

input bool   EnableSingleTrailing = true; // Enable single position trailing
input double SingleProfitThreshold = 10.0; // Profit per 0.01 lot to start trail

// Adaptive Gap
input bool   UseAdaptiveGap = true;       // Use ATR-based adaptive gap
input int    ATRPeriod = 14;              // ATR period for adaptive gap
input double ATRMultiplier = 1.5;         // ATR multiplier
input double MinGapPoints = 50.0;         // Minimum gap points
input double MaxGapPoints = 500.0;        // Maximum gap points

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
double g_maxLossCycle = 0.0;
double g_maxProfitCycle = 0.0;

// Single Trailing State
struct SingleTrail {
   ulong  ticket;
   double peakPPL;
   double threshold;
   double gap;
   bool   active;
};
SingleTrail g_trails[];

// Price tracking
static double g_prevAsk = 0.0;
static double g_prevBid = 0.0;

//============================= UTILITY FUNCTIONS ==================//
void Log(int level, string msg) {
   if(level <= DebugLevel) Print("[L", level, "] ", msg);
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
   
   Log(3, StringFormat("Stats: B%d/%.2f S%d/%.2f Net:%.2f P:%.2f", 
       g_buyCount, g_buyLots, g_sellCount, g_sellLots, g_netLots, g_totalProfit));
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
void CalculateNextLots() {
   int maxOrders = MathMax(g_buyCount, g_sellCount);
   
   // Progressive sizing
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
      Log(3, "Trading blocked: total trailing active");
      return;
   }
   
   double nowAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double nowBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   
   // Initialize static variables
   if(g_prevAsk == 0.0) g_prevAsk = nowAsk;
   if(g_prevBid == 0.0) g_prevBid = nowBid;
   
   // BUY logic - price moving up
   if(nowAsk > g_prevAsk) {
      int Llo = PriceLevelIndex(MathMin(g_prevAsk, nowAsk) - spread, g_adaptiveGap) - 2;
      int Lhi = PriceLevelIndex(MathMax(g_prevAsk, nowAsk) - spread, g_adaptiveGap) + 2;
      
      for(int L = Llo; L <= Lhi; L++) {
         if(!IsEven(L)) continue;
         
         double trigger = LevelPrice(L, g_adaptiveGap) + spread;
         if(g_prevAsk <= trigger && nowAsk > trigger) {
            if(HasOrderOnLevel(POSITION_TYPE_BUY, L, g_adaptiveGap)) continue;
            if(HasOrderNearLevel(POSITION_TYPE_BUY, L, g_adaptiveGap, 1)) continue;
            
            trade.SetExpertMagicNumber(Magic);
            if(trade.Buy(g_nextBuyLot, _Symbol)) {
               Log(1, StringFormat("BUY %.2f @ L%d (%.5f)", g_nextBuyLot, L, nowAsk));
            }
         }
      }
   }
   
   // SELL logic - price moving down
   if(nowBid < g_prevBid) {
      int Llo = PriceLevelIndex(MathMin(g_prevBid, nowBid) + spread, g_adaptiveGap) - 2;
      int Lhi = PriceLevelIndex(MathMax(g_prevBid, nowBid) + spread, g_adaptiveGap) + 2;
      
      for(int L = Lhi; L >= Llo; L--) {
         if(!IsOdd(L)) continue;
         
         double trigger = LevelPrice(L, g_adaptiveGap) - spread;
         if(g_prevBid >= trigger && nowBid < trigger) {
            if(HasOrderOnLevel(POSITION_TYPE_SELL, L, g_adaptiveGap)) continue;
            if(HasOrderNearLevel(POSITION_TYPE_SELL, L, g_adaptiveGap, 1)) continue;
            
            trade.SetExpertMagicNumber(Magic);
            if(trade.Sell(g_nextSellLot, _Symbol)) {
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
   
   // Track cycle extremes
   if(cycleProfit < 0) {
      double absLoss = MathAbs(cycleProfit);
      if(absLoss > g_maxLossCycle) g_maxLossCycle = absLoss;
   }
   if(cycleProfit > 0) {
      if(cycleProfit > g_maxProfitCycle) g_maxProfitCycle = cycleProfit;
   }
   
   // Calculate trail start level
   double lossStart = g_maxLossCycle * TrailStartPct;
   double profitStart = g_maxProfitCycle * 1.0; // 100%
   g_trailStart = MathMax(lossStart, profitStart);
   
   if(g_trailStart > 0) {
      g_trailGap = MathMin(g_trailStart * TrailGapPct, MaxTrailGap);
   }
   
   // Start trailing
   if(!g_trailActive && cycleProfit > g_trailStart && g_trailStart > 0) {
      g_trailActive = true;
      g_trailPeak = cycleProfit;
      g_trailFloor = g_trailPeak - g_trailGap;
      Log(1, StringFormat("Trail START: profit=%.2f start=%.2f gap=%.2f floor=%.2f", 
          cycleProfit, g_trailStart, g_trailGap, g_trailFloor));
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
         Log(1, StringFormat("Trail CLOSE ALL: profit=%.2f <= floor=%.2f", cycleProfit, g_trailFloor));
         
         // Close all positions
         for(int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if(!PositionSelectByTicket(ticket)) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
            
            trade.PositionClose(ticket);
         }
         
         // Reset cycle
         g_lastCloseEquity = AccountInfoDouble(ACCOUNT_EQUITY);
         g_maxLossCycle = 0.0;
         g_maxProfitCycle = 0.0;
         g_trailActive = false;
         g_trailStart = 0.0;
         g_trailGap = 0.0;
         g_trailPeak = 0.0;
         g_trailFloor = 0.0;
         
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
   g_trails[size].threshold = threshold;
   g_trails[size].gap = threshold / 2.0;
   g_trails[size].active = false;
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
      
      // Start tracking
      if(profitPer01 >= SingleProfitThreshold && idx < 0) {
         AddTrail(ticket, profitPer01, SingleProfitThreshold);
         idx = FindTrailIndex(ticket);
         Log(2, StringFormat("Trail START #%I64u PPL=%.2f", ticket, profitPer01));
      }
      
      // Update tracking
      if(idx >= 0) {
         double peak = g_trails[idx].peakPPL;
         double gap = g_trails[idx].gap;
         bool active = g_trails[idx].active;
         
         // Update peak
         if(profitPer01 > peak) {
            g_trails[idx].peakPPL = profitPer01;
            peak = profitPer01;
         }
         
         // Activate when drops to half threshold
         if(!active && profitPer01 <= SingleProfitThreshold / 2.0) {
            g_trails[idx].active = true;
            active = true;
            Log(2, StringFormat("Trail ACTIVE #%I64u peak=%.2f", ticket, peak));
         }
         
         // Close if drops by gap from peak
         if(active) {
            double drop = peak - profitPer01;
            if(drop >= gap) {
               Log(1, StringFormat("Trail CLOSE #%I64u peak=%.2f cur=%.2f drop=%.2f", 
                   ticket, peak, profitPer01, drop));
               
               if(trade.PositionClose(ticket)) {
                  RemoveTrail(idx);
               }
            }
         }
      }
   }
   
   // Cleanup stale trails
   for(int j = ArraySize(g_trails) - 1; j >= 0; j--) {
      if(!PositionSelectByTicket(g_trails[j].ticket)) {
         RemoveTrail(j);
      }
   }
}

//============================= MAIN FUNCTIONS =====================//
int OnInit() {
   Log(1, StringFormat("EA Init: Magic=%d Gap=%.1f Lot=%.2f", Magic, GapInPoints, BaseLotSize));
   
   // Initialize equity tracking
   g_lastCloseEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
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
