//+------------------------------------------------------------------+
//| mq5_ea_single_file_quick.mq5                                    |
//| Fast single-file grid trading EA with profit trailing          |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

//============================= INPUTS =============================//
// Core Trading Parameters
input int    Magic = 12345;               // Magic number
input double GapInPoints = 3000.0;         // Gap between levels in points
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
input int    MaxPositions = 9999999;         // Maximum open positions
input double MaxTotalLots = 9999999;        // Maximum total lot exposure
input double MaxLossLimit = 9999999;       // Maximum loss limit
input double DailyProfitTarget = 9999999;  // Daily profit target to stop trading

// total Profit Trailing
 bool   EnableTotalTrailing = true;  // Enable total profit trailing
 double TrailStartPct = 0.10;        // Start trail at % of max loss (0.10 = 10%)
 double TrailProfitPct = 0.85;       // Start trail at % of max profit (0.85 = 85%)
 double TrailGapPct = 0.50;          // Trail gap as % of start value (0.50 = 50%)
 double MaxTrailGap = 2500.0;         // Maximum trail gap (absolute cap)

 bool   EnableSingleTrailing = true; // Enable single position trailing
 double SingleProfitThreshold = -1; // Profit per 0.01 lot to start trail (negative = auto-calc from gap)

// Adaptive Gap
input bool   UseAdaptiveGap = false;       // Use ATR-based adaptive gap
 int    ATRPeriod = 14;              // ATR period for adaptive gap
 double ATRMultiplier = 1.5;         // ATR multiplier
 double MinGapPoints = GapInPoints/2;         // Minimum gap points
double MaxGapPoints = GapInPoints*1.10;        // Maximum gap points

// Display Settings
input bool   ShowLabels = true;         // Show chart labels (disable for performance)

// Button Positioning
input int    BtnXDistance = 200;         // Button X distance from right edge
input int    BtnYDistance = 50;         // Button Y distance from top edge

// Starting Equity
input double StartingEquityInput = 0.0; // Starting equity (0 = use current equity at init)
input double LastCloseEquityInput = 0.0; // Last close equity (0 = use current equity at init)

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

// Button Control States
bool g_stopNewOrders = false;    // If true: no new orders, only manage existing
bool g_noWork = false;           // If true: no new orders, no closing, only display
datetime g_closeAllClickTime = 0; // Track first click time for double-click protection
bool g_showLabels = true;        // If true: show all labels, if false: hide for performance

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
double g_maxSpread = 0.0;           // Maximum spread ever touched

// History tracking
double g_last5Closes[5];            // Last 5 close-all profits
int    g_closeCount = 0;            // Total number of close-alls
double g_dailyProfits[5];           // Last 5 days daily profit changes
int    g_lastDay = -1;              // Last recorded day
int    g_dayIndex = 0;              // Current day index in array
double g_lastDayEquity = 0.0;       // Equity at start of current day

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

//============================= BUTTON FUNCTIONS ===================//
void CreateButtons() {
   // Get chart dimensions for adaptive positioning
   long chartWidth = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   long chartHeight = ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   
   int buttonWidth = 150;
   int buttonHeight = 30;
   int rightMargin = BtnXDistance;   // Use input parameter
   int topMargin = BtnYDistance;     // Use input parameter
   int verticalGap = 5;              // Gap between buttons
   
   // Button 1: Stop New Orders
   string btn1Name = "BtnStopNewOrders";
   if(ObjectFind(0, btn1Name) < 0) {
      ObjectCreate(0, btn1Name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, btn1Name, OBJPROP_XDISTANCE, rightMargin);
      ObjectSetInteger(0, btn1Name, OBJPROP_YDISTANCE, topMargin);
      ObjectSetInteger(0, btn1Name, OBJPROP_XSIZE, buttonWidth);
      ObjectSetInteger(0, btn1Name, OBJPROP_YSIZE, buttonHeight);
      ObjectSetInteger(0, btn1Name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, btn1Name, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, btn1Name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, btn1Name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, btn1Name, OBJPROP_HIDDEN, false);
   }
   
   // Button 2: No Work Mode
   string btn2Name = "BtnNoWork";
   if(ObjectFind(0, btn2Name) < 0) {
      ObjectCreate(0, btn2Name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, btn2Name, OBJPROP_XDISTANCE, rightMargin);
      ObjectSetInteger(0, btn2Name, OBJPROP_YDISTANCE, topMargin + buttonHeight + verticalGap);
      ObjectSetInteger(0, btn2Name, OBJPROP_XSIZE, buttonWidth);
      ObjectSetInteger(0, btn2Name, OBJPROP_YSIZE, buttonHeight);
      ObjectSetInteger(0, btn2Name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, btn2Name, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, btn2Name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, btn2Name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, btn2Name, OBJPROP_HIDDEN, false);
   }
   
   // Button 3: Close All
   string btn3Name = "BtnCloseAll";
   if(ObjectFind(0, btn3Name) < 0) {
      ObjectCreate(0, btn3Name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, btn3Name, OBJPROP_XDISTANCE, rightMargin);
      ObjectSetInteger(0, btn3Name, OBJPROP_YDISTANCE, topMargin + (buttonHeight + verticalGap) * 2);
      ObjectSetInteger(0, btn3Name, OBJPROP_XSIZE, buttonWidth);
      ObjectSetInteger(0, btn3Name, OBJPROP_YSIZE, buttonHeight);
      ObjectSetInteger(0, btn3Name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, btn3Name, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, btn3Name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, btn3Name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, btn3Name, OBJPROP_HIDDEN, false);
   }
   
   // Button 4: Toggle Labels
   string btn4Name = "BtnToggleLabels";
   if(ObjectFind(0, btn4Name) < 0) {
      ObjectCreate(0, btn4Name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, btn4Name, OBJPROP_XDISTANCE, rightMargin);
      ObjectSetInteger(0, btn4Name, OBJPROP_YDISTANCE, topMargin + (buttonHeight + verticalGap) * 3);
      ObjectSetInteger(0, btn4Name, OBJPROP_XSIZE, buttonWidth);
      ObjectSetInteger(0, btn4Name, OBJPROP_YSIZE, buttonHeight);
      ObjectSetInteger(0, btn4Name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, btn4Name, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, btn4Name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, btn4Name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, btn4Name, OBJPROP_HIDDEN, false);
   }
   
   UpdateButtonStates();
}

void UpdateButtonStates() {
   // Update Button 1: Stop New Orders
   string btn1Name = "BtnStopNewOrders";
   if(g_stopNewOrders) {
      ObjectSetString(0, btn1Name, OBJPROP_TEXT, "MANAGE ONLY [ON]");
      ObjectSetInteger(0, btn1Name, OBJPROP_BGCOLOR, clrOrange);
      ObjectSetInteger(0, btn1Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn1Name, OBJPROP_STATE, true);
   } else {
      ObjectSetString(0, btn1Name, OBJPROP_TEXT, "Stop New Orders");
      ObjectSetInteger(0, btn1Name, OBJPROP_BGCOLOR, clrDarkGray);
      ObjectSetInteger(0, btn1Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn1Name, OBJPROP_STATE, false);
   }
   
   // Update Button 2: No Work
   string btn2Name = "BtnNoWork";
   if(g_noWork) {
      ObjectSetString(0, btn2Name, OBJPROP_TEXT, "NO WORK [ON]");
      ObjectSetInteger(0, btn2Name, OBJPROP_BGCOLOR, clrRed);
      ObjectSetInteger(0, btn2Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn2Name, OBJPROP_STATE, true);
   } else {
      ObjectSetString(0, btn2Name, OBJPROP_TEXT, "No Work Mode");
      ObjectSetInteger(0, btn2Name, OBJPROP_BGCOLOR, clrDarkGray);
      ObjectSetInteger(0, btn2Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn2Name, OBJPROP_STATE, false);
   }
   
   // Update Button 3: Close All (always active appearance, double-click protected)
   string btn3Name = "BtnCloseAll";
   ObjectSetString(0, btn3Name, OBJPROP_TEXT, "Close All (2x click)");
   ObjectSetInteger(0, btn3Name, OBJPROP_BGCOLOR, clrDarkRed);
   ObjectSetInteger(0, btn3Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn3Name, OBJPROP_STATE, false);
   
   // Update Button 4: Toggle Labels
   string btn4Name = "BtnToggleLabels";
   if(g_showLabels) {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, "Labels [ON]");
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrGreen);
      ObjectSetInteger(0, btn4Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn4Name, OBJPROP_STATE, true);
   } else {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, "Show Labels");
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkGray);
      ObjectSetInteger(0, btn4Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn4Name, OBJPROP_STATE, false);
   }
   
   ChartRedraw(0);
}

//============================= RESTORE STATE FROM POSITIONS =======//
void RestoreStateFromPositions() {
   // This function restores EA state variables from existing open positions
   // Useful when EA is restarted with open positions
   
   int totalPositions = 0;
   double maxLotFound = 0.0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
      
      totalPositions++;
      
      double lots = PositionGetDouble(POSITION_VOLUME);
      if(lots > maxLotFound) maxLotFound = lots;
   }
   
   // Restore max lot sizes if we found positions
   if(totalPositions > 0 && maxLotFound > 0) {
      g_maxLotsCycle = maxLotFound;
      g_overallMaxLotSize = maxLotFound;
      
      Log(1, StringFormat("State Restored: Found %d positions | Max Lot: %.2f", 
          totalPositions, maxLotFound));
   }
   
   // UpdatePositionStats will be called in OnTick to populate buy/sell counts and lots
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
double g_buyProfit = 0.0;
double g_sellProfit = 0.0;

void UpdatePositionStats() {
   g_buyCount = 0;
   g_sellCount = 0;
   g_buyLots = 0.0;
   g_sellLots = 0.0;
   g_totalProfit = 0.0;
   g_buyProfit = 0.0;
   g_sellProfit = 0.0;
   
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
         g_buyProfit += profit;
      } else if(type == POSITION_TYPE_SELL) {
         g_sellCount++;
         g_sellLots += lots;
         g_sellProfit += profit;
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
   }
   
   // Track max spread
   double currentSpread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   if(currentSpread > g_maxSpread) g_maxSpread = currentSpread;
   
   Log(3, StringFormat("Stats B%d/%.2f S%d/%.2f N%.2f ML%.2f/%.2f MP=%.2f/%.2f MaxLot%.2f/%.2f P%.2f(%.2f+%.2f=%.2f)EQ=%.2f", 
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
   
   // Block new orders if Stop New Orders or No Work mode is active
   if(g_stopNewOrders) {
      Log(3, "New orders blocked: Stop New Orders mode active");
      return;
   }
   
   if(g_noWork) {
      Log(3, "New orders blocked: No Work mode active");
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
   
   // Skip closing in No Work mode
   if(g_noWork) return;
   
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
            string vlinetext = StringFormat("P:%.2f/%.2f/%.2f(L%.2f)ML%.2f/%.2f L%.2f/%.2f", 
                  cycleProfit,g_trailPeak - cycleProfit,g_trailPeak,bookedCycle, -g_maxLossCycle, -g_overallMaxLoss, g_maxLotsCycle, g_overallMaxLotSize);
            ObjectSetString(0, vlineName, OBJPROP_TEXT, vlinetext);
            ChartRedraw(0);
            Log(1, StringFormat("VLine created: %s (color: %s, width: %d) | ML:%.2f Book:%.2f Lot:%.2f", vlineName, (cycleProfit >= 0) ? "GREEN" : "RED", lineWidth, -g_maxLossCycle, bookedCycle, g_maxLotsCycle));
            Log(1, StringFormat("VLine Text: %s", vlinetext));
         }


         // Record close profit in history (shift array and add new)
         for(int i = 4; i > 0; i--) {
            g_last5Closes[i] = g_last5Closes[i-1];
         }
         g_last5Closes[0] = cycleProfit;
         g_closeCount++;
         
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
   
   // Skip closing in No Work mode
   if(g_noWork) return;
   
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

//============================= CHART EVENT HANDLER ================//
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
   if(id == CHARTEVENT_OBJECT_CLICK) {
      // Button 1: Stop New Orders (toggle)
      if(sparam == "BtnStopNewOrders") {
         g_stopNewOrders = !g_stopNewOrders;
         
         // If activating Stop New Orders, deactivate No Work
         if(g_stopNewOrders && g_noWork) {
            g_noWork = false;
         }
         
         UpdateButtonStates();
         Log(1, StringFormat("Stop New Orders: %s", g_stopNewOrders ? "ENABLED" : "DISABLED"));
      }
      
      // Button 2: No Work Mode (toggle)
      if(sparam == "BtnNoWork") {
         g_noWork = !g_noWork;
         
         // If activating No Work, deactivate Stop New Orders
         if(g_noWork && g_stopNewOrders) {
            g_stopNewOrders = false;
         }
         
         UpdateButtonStates();
         Log(1, StringFormat("No Work Mode: %s", g_noWork ? "ENABLED" : "DISABLED"));
      }
      
      // Button 3: Close All (double-click protection)
      if(sparam == "BtnCloseAll") {
         datetime currentTime = TimeCurrent();
         
         // Check if this is a double-click (within 2 seconds of first click)
         if(g_closeAllClickTime > 0 && (currentTime - g_closeAllClickTime) <= 2) {
            // Double-click confirmed - close all positions
            int closedCount = 0;
            for(int i = PositionsTotal() - 1; i >= 0; i--) {
               ulong ticket = PositionGetTicket(i);
               if(!PositionSelectByTicket(ticket)) continue;
               if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
               if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
               
               if(trade.PositionClose(ticket)) {
                  closedCount++;
               }
            }
            
            Log(1, StringFormat("CLOSE ALL executed: %d positions closed", closedCount));
            g_closeAllClickTime = 0; // Reset click timer
         } else {
            // First click - start timer
            g_closeAllClickTime = currentTime;
            Log(1, "Close All: Click again within 2 seconds to confirm");
         }
      }
      
      // Button 4: Toggle Labels
      if(sparam == "BtnToggleLabels") {
         g_showLabels = !g_showLabels;
         
         if(!g_showLabels) {
            // Hide all labels
            ObjectDelete(0, "CurrentProfitLabel");
            ObjectDelete(0, "PositionDetailsLabel");
            ObjectDelete(0, "SpreadEquityLabel");
            ObjectDelete(0, "Last5ClosesLabel");
            ObjectDelete(0, "Last5DaysLabel");
            ObjectDelete(0, "CenterProfitLabel");
            ObjectDelete(0, "CurrentProfitVLine");
         }
         
         UpdateButtonStates();
         Log(1, StringFormat("Labels Display: %s", g_showLabels ? "ENABLED" : "DISABLED"));
      }
   }
}

//============================= MAIN FUNCTIONS =====================//
int OnInit() {
   Log(1, StringFormat("EA Init: Magic=%d Gap=%.1f Lot=%.2f", Magic, GapInPoints, BaseLotSize));
   
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Initialize equity tracking
   if(StartingEquityInput > 0.0) {
      g_startingEquity = StartingEquityInput;
      Log(1, StringFormat("Using input starting equity: %.2f", g_startingEquity));
   } else {
      g_startingEquity = currentEquity;
      Log(1, StringFormat("Using current equity as starting: %.2f", g_startingEquity));
   }
   
   if(LastCloseEquityInput > 0.0) {
      g_lastCloseEquity = LastCloseEquityInput;
      Log(1, StringFormat("Using input last close equity: %.2f", g_lastCloseEquity));
   } else {
      g_lastCloseEquity = currentEquity;
      Log(1, StringFormat("Using current equity as last close: %.2f", g_lastCloseEquity));
   }
   
   g_lastDayEquity = currentEquity;
   
   // Initialize history arrays
   ArrayInitialize(g_last5Closes, 0.0);
   ArrayInitialize(g_dailyProfits, 0.0);
   g_closeCount = 0;
   g_lastDay = -1;
   g_dayIndex = 0;
   
   // Restore state from existing positions (if any)
   RestoreStateFromPositions();
   
   // Create control buttons
   if(ShowLabels) CreateButtons();
   
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
   
   // Track daily profit (once per day)
   MqlDateTime dt;
   TimeCurrent(dt);
   if(g_lastDay != dt.day) {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      
      // Calculate profit made on the previous day (or since EA start if first day)
      double previousDayProfit = equity - g_lastDayEquity;
      
      // Only record if not the first day (g_lastDay == -1 means EA just started)
      if(g_lastDay != -1) {
         // Shift array and add previous day's profit to history
         for(int i = 4; i > 0; i--) {
            g_dailyProfits[i] = g_dailyProfits[i-1];
         }
         g_dailyProfits[0] = previousDayProfit;
      }
      
      // Update tracking variables for new day
      g_lastDay = dt.day;
      g_lastDayEquity = equity;
   }
   
   // Update current profit vline (follows current time with stats)
   if(ShowLabels) UpdateCurrentProfitVline();
}

//============================= DISPLAY HELPER ====================//
void UpdateOrCreateLabel(string name, int xDist, int yDist, string text, color clr, int fontSize = 10, string font = "Arial") {
   // Create if doesn't exist
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xDist);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, yDist);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
      ObjectSetString(0, name, OBJPROP_FONT, font);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
   }
   
   // Update text and color
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

//============================= CURRENT PROFIT VLINE ==============//
void UpdateCurrentProfitVline() {
   // Skip if labels are hidden
   if(!g_showLabels) return;
   
   // Get current stats
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity == 0) return;
   
   double cycleProfit = equity - g_lastCloseEquity;
   double openProfit = g_totalProfit;
   double bookedCycle = cycleProfit - openProfit;
   double overallProfit = equity - g_startingEquity;
   
   // Update vline only if we have positions
   if((g_buyCount + g_sellCount) > 0) {
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
         
         ObjectSetInteger(0, vlineName, OBJPROP_STYLE, STYLE_SOLID);
         int totalCount = g_buyCount + g_sellCount;
         double totalLots = g_buyLots + g_sellLots;
         string vlinetext = StringFormat("P:%.2f/%.2f/%.2f(L%.2f)ML%.2f/%.2f L%.2f/%.2f N:%d/%.2f/%.2f", 
               cycleProfit,g_trailPeak - cycleProfit,g_trailPeak,bookedCycle, -g_maxLossCycle, -g_overallMaxLoss, 
               g_maxLotsCycle,g_overallMaxLotSize,totalCount, g_netLots, totalLots);
         ObjectSetString(0, vlineName, OBJPROP_TEXT, vlinetext);
      }
   } else {
      // Remove vline if no positions
      ObjectDelete(0, "CurrentProfitVLine");
   }
   
   // Label 1: Current Profit Label (always show)
   color lineColor = (cycleProfit >= 0) ? clrGreen : clrRed;
   string modeIndicator = "";
   if(g_noWork) modeIndicator = " [NO WORK]";
   else if(g_stopNewOrders) modeIndicator = " [MANAGE ONLY]";
   string vlinetext = StringFormat("P:%.2f/%.2f/%.2f(L%.2f)ML%.2f/%.2f L%.2f/%.2f%s", 
         cycleProfit, g_trailPeak - cycleProfit, g_trailPeak, bookedCycle, -g_maxLossCycle, -g_overallMaxLoss, 
         g_maxLotsCycle, g_overallMaxLotSize, modeIndicator);
   UpdateOrCreateLabel("CurrentProfitLabel", 10, 30, vlinetext, lineColor, 12, "Arial Bold");
   
   // Label 2: Position Details (always show)
   int totalCount = g_buyCount + g_sellCount;
   double totalLots = g_buyLots + g_sellLots;
   string label2text = StringFormat("N:%d/%.2f/%.2f B:%d/%.2f/%.2f S:%d/%.2f/%.2f",
         totalCount, g_netLots, totalLots,
         g_buyCount, g_buyLots, g_buyProfit,
         g_sellCount, g_sellLots, g_sellProfit);
   color label2Color = (g_totalProfit >= 0) ? clrLime : clrOrange;
   UpdateOrCreateLabel("PositionDetailsLabel", 10, 50, label2text, label2Color, 10, "Arial Bold");
   
   // Label 3: Spread & Equity (always show)
   double currentSpread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   string label3text = StringFormat("Spread:%.1f/%.1f | Equity:%.2f | Overall:%.2f", 
         currentSpread/_Point, g_maxSpread/_Point, equity, overallProfit);
   color label3Color = (overallProfit >= 0) ? clrGreen : clrRed;
   UpdateOrCreateLabel("SpreadEquityLabel", 10, 70, label3text, label3Color, 10, "Arial Bold");
   
   // Label 4: Last 5 Closes (always show)
   string label4text = "Last5 Closes: ";
   for(int i = 0; i < 5; i++) {
      if(i < g_closeCount) {
         label4text += StringFormat("%.2f", g_last5Closes[i]);
      } else {
         label4text += "-";
      }
      if(i < 4) label4text += " | ";
   }
   UpdateOrCreateLabel("Last5ClosesLabel", 10, 90, label4text, clrYellow, 9, "Arial");
   
   // Label 5: Last 5 Days (always show)
   double currentDayProfit = equity - g_lastDayEquity;
   string label5text = "Last5 Days: ";
   label5text += StringFormat("%.2f", currentDayProfit);  // Current day
   for(int i = 0; i < 4; i++) {
      label5text += " | ";
      if(g_lastDay != -1) {
         label5text += StringFormat("%.2f", g_dailyProfits[i]);
      } else {
         label5text += "-";
      }
   }
   UpdateOrCreateLabel("Last5DaysLabel", 10, 108, label5text, clrCyan, 9, "Arial");
   
   // Label 6: Center Label - Overall Profit & Net Lots
   long chartWidth = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   long chartHeight = ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   int centerX = (int)(chartWidth / 2);
   int centerY = (int)(chartHeight / 2);
   
   string centerText = StringFormat("PR%.0f N%.2f", overallProfit, g_netLots);
   color centerColor = (overallProfit >= 0) ? clrLime : clrRed;
   
   // Create center label with absolute positioning
   string centerName = "CenterProfitLabel";
   if(ObjectFind(0, centerName) < 0) {
      ObjectCreate(0, centerName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, centerName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, centerName, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, centerName, OBJPROP_XDISTANCE, centerX);
      ObjectSetInteger(0, centerName, OBJPROP_YDISTANCE, centerY);
      ObjectSetInteger(0, centerName, OBJPROP_FONTSIZE, 36);
      ObjectSetString(0, centerName, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, centerName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, centerName, OBJPROP_HIDDEN, false);
      ObjectSetInteger(0, centerName, OBJPROP_BACK, false);
      ObjectSetInteger(0, centerName, OBJPROP_ZORDER, 0);
   } else {
      // Update position in case chart was resized
      ObjectSetInteger(0, centerName, OBJPROP_XDISTANCE, centerX);
      ObjectSetInteger(0, centerName, OBJPROP_YDISTANCE, centerY);
   }
   
   ObjectSetString(0, centerName, OBJPROP_TEXT, centerText);
   ObjectSetInteger(0, centerName, OBJPROP_COLOR, centerColor);
   
   ChartRedraw(0);
}
void OnDeinit(const int reason) {
   // Clean up buttons and labels
   ObjectDelete(0, "BtnStopNewOrders");
   ObjectDelete(0, "BtnNoWork");
   ObjectDelete(0, "BtnCloseAll");
   ObjectDelete(0, "BtnToggleLabels");
   ObjectDelete(0, "CenterProfitLabel");
   
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
   
   // Print final statistics (same as displayed in labels)
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double cycleProfit = equity - g_lastCloseEquity;
   double openProfit = g_totalProfit;
   double bookedCycle = cycleProfit - openProfit;
   double overallProfit = equity - g_startingEquity;
   
   // Label 1: Current Profit Label
   string stats1 = StringFormat("P:%.2f/%.2f/%.2f(L%.2f)ML%.2f/%.2f L%.2f/%.2f", 
         cycleProfit, g_trailPeak - cycleProfit, g_trailPeak, bookedCycle, -g_maxLossCycle, -g_overallMaxLoss, 
         g_maxLotsCycle, g_overallMaxLotSize);
   
   // Label 2: Position Details
   int totalCount = g_buyCount + g_sellCount;
   double totalLots = g_buyLots + g_sellLots;
   string stats2 = StringFormat("N:%d/%.2f/%.2f B:%d/%.2f/%.2f S:%d/%.2f/%.2f",
         totalCount, g_netLots, totalLots,
         g_buyCount, g_buyLots, g_buyProfit,
         g_sellCount, g_sellLots, g_sellProfit);
   
   // Label 3: Spread & Equity
   double currentSpread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   string stats3 = StringFormat("Spread:%.1f/%.1f | Equity:%.2f | Overall:%.2f", 
         currentSpread/_Point, g_maxSpread/_Point, equity, overallProfit);
   
   // Label 4: Last 5 Closes
   string stats4 = "Last5 Closes: ";
   for(int i = 0; i < 5; i++) {
      if(i < g_closeCount) {
         stats4 += StringFormat("%.2f", g_last5Closes[i]);
      } else {
         stats4 += "-";
      }
      if(i < 4) stats4 += " | ";
   }
   
   // Label 5: Last 5 Days (including current day)
   double currentDayProfit = equity - g_lastDayEquity;  // Profit made today
   string stats5 = "Last5 Days: ";
   stats5 += StringFormat("%.2f", currentDayProfit);  // Current day profit
   for(int i = 0; i < 4; i++) {
      stats5 += " | ";
      if(g_lastDay != -1) {
         stats5 += StringFormat("%.2f", g_dailyProfits[i]);
      } else {
         stats5 += "-";
      }
   }
   
   // Print all stats
   Print("========== FINAL STATISTICS ==========");
   Print(stats1);
   Print(stats2);
   Print(stats3);
   Print(stats4);
   Print(stats5);
   Print("======================================");
}
