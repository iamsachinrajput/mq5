//+------------------------------------------------------------------+
//| mq5_ea_single_file_quick.mq5                                    |
//| Fast single-file grid trading EA with profit trailing          |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

//============================= INPUTS =============================//
// Core Trading Parameters
input int    Magic = 12345;               // Magic number
input double GapInPoints = 1000;         // Gap xau100 btc1000
input double BaseLotSize = 0.01;          // Starting lot size
input int    DebugLevel = 3;              // Debug level (0=off, 1=critical, 2=info, 3=verbose)

// Lot Calculation Method
enum ENUM_LOT_METHOD {
   LOT_METHOD_MAXORDERS_SWITCH = 0,    // Max Orders with Switch
   LOT_METHOD_ORDERDIFF_SWITCH = 1,    // Order Difference with Switch
   LOT_METHOD_HEDGE_SAMESIZE = 2,      // Hedge Same Size on Switch
   LOT_METHOD_FIXED_LEVELS = 3,        // Fixed Levels Mode Switch
   LOT_METHOD_GLO_BASED = 4            // Global Loss Orders Based
};
input ENUM_LOT_METHOD LotChangeMethod = LOT_METHOD_GLO_BASED; // Lot calculation method
input int    SwitchModeCount = 20;          // Switch mode trigger count

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

enum ENUM_TRAIL_ORDER_MODE {
   TRAIL_ORDERS_NONE = 0,           // No new orders during trail
   TRAIL_ORDERS_NORMAL = 1,         // Allow normal orders with calculated lot sizes
   TRAIL_ORDERS_BASESIZE = 2,       // Allow orders but only with base lot size
   TRAIL_ORDERS_PROFIT_DIR = 3,     // Allow only profit direction orders with base lot size
   TRAIL_ORDERS_REVERSE_DIR = 4     // Allow only reverse direction orders with base lot size
};
input ENUM_TRAIL_ORDER_MODE TrailOrderMode = TRAIL_ORDERS_PROFIT_DIR;  // Order behavior during total trailing

enum ENUM_ORDER_STRATEGY {
   ORDER_STRATEGY_NONE = 0,                // No additional checks
   ORDER_STRATEGY_BOUNDARY_DIRECTIONAL = 1, // BUY needs SELL below, SELL needs BUY above
   ORDER_STRATEGY_ADJACENT_ONLY = 2        // BUY needs SELL at L-1, SELL needs BUY at L+1
};
input ENUM_ORDER_STRATEGY OrderPlacementStrategy = ORDER_STRATEGY_ADJACENT_ONLY; // Order placement strategy

enum ENUM_ORDER_PLACEMENT_TYPE {
   ORDER_PLACEMENT_NORMAL = 0,    // Normal - only place orders when price crosses
   ORDER_PLACEMENT_FLEXIBLE = 1   // Flexible - also fill missed adjacent level orders
};
input ENUM_ORDER_PLACEMENT_TYPE OrderPlacementType = ORDER_PLACEMENT_NORMAL; // Order placement type

 bool   EnableSingleTrailing = true; // Enable single position trailing
 input double SingleProfitThreshold = -1; // Profit per 0.01 lot to start trail (negative = auto-calc from gap)

enum ENUM_SINGLE_TRAIL_METHOD {
   SINGLE_TRAIL_NORMAL = 0,       // Normal - trail each order independently
   SINGLE_TRAIL_CLOSETOGETHER = 1, // Close Together - trail worst loss with profitable orders (any side)
   SINGLE_TRAIL_CLOSETOGETHER_SAMETYPE = 2, // Close Together Same Type - trail worst loss with profitable orders (same side only)
   SINGLE_TRAIL_DYNAMIC = 3       // Dynamic - switch between single and group trail based on GLO count
};
input ENUM_SINGLE_TRAIL_METHOD SingleTrailMethod = SINGLE_TRAIL_CLOSETOGETHER_SAMETYPE; // Single trail closing method
input int MinGLOForGroupTrail = 10; // Minimum GLO orders to activate group trailing
input int DynamicGLOThreshold = 5; // GLO threshold for dynamic method (< threshold = single trail, >= threshold = group trail)
input double MinGroupProfitToClose = 0.0; // Minimum combined profit to close group (prevents closing at loss)
input double GroupActivationBuffer = 0.5; // Extra profit above threshold to activate (0.5 = 50% of threshold)

// Adaptive Gap
input bool   UseAdaptiveGap = true;       // Use ATR-based adaptive gap
 int    ATRPeriod = 14;              // ATR period for adaptive gap
 double ATRMultiplier = 1.5;         // ATR multiplier
 double MinGapPoints = GapInPoints/2;         // Minimum gap points
double MaxGapPoints = GapInPoints*1.10;        // Maximum gap points

// Display Settings
input bool   ShowLabels = true;         // Show chart labels (disable for performance)
input double MaxLossVlineThreshold = 100.0;  // Min loss to show max loss vline (0 = always show)
input int    VlineOffsetCandles = 10;   // Current profit vline offset in candles from current time

// Order Placement Settings
input int    OrderPlacementDelayMs = 0;  // Delay between orders in milliseconds (0 = no delay)

enum ENUM_NO_POSITIONS_ACTION {
   NO_POS_NONE = 0,           // None - no intervention
   NO_POS_NEAREST_LEVEL = 1,  // Open single order at nearest level
   NO_POS_BOTH_LEVELS = 2     // Open both BUY and SELL at nearest levels
};
input ENUM_NO_POSITIONS_ACTION NoPositionsAction = NO_POS_NONE; // Action when no open positions

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
int    g_orders_in_loss = 0;    // Count of orders currently in loss (for GLO method)

// Risk Status
bool g_tradingAllowed = true;

// Button Control States
bool g_stopNewOrders = false;    // If true: no new orders, only manage existing
bool g_noWork = false;           // If true: no new orders, no closing, only display
datetime g_closeAllClickTime = 0; // Track first click time for double-click protection
datetime g_stopNewOrdersClickTime = 0; // Track first click time for Stop New Orders
datetime g_noWorkClickTime = 0;   // Track first click time for No Work
bool g_pendingStopNewOrders = false; // Pending action after next close-all
bool g_pendingNoWork = false;    // Pending action after next close-all
bool g_showLabels = true;        // If true: show all labels, if false: hide for performance
bool g_showNextLevelLines = true; // If true: show and calculate next level lines (toggle via button)

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
double g_lastMaxLossVline = 0.0;    // Last max loss level that had a vline created
int    g_maxGLOOverall = 0;         // Maximum GLO ever touched (never resets)

// History tracking
double g_last5Closes[5];            // Last 5 close-all profits
int    g_closeCount = 0;            // Total number of close-alls
double g_dailyProfits[5];           // Last 5 days daily profit changes
int    g_lastDay = -1;              // Last recorded day
int    g_dayIndex = 0;              // Current day index in array
double g_lastDayEquity = 0.0;       // Equity at start of current day
double g_historySymbolDaily[5];     // Last 5 days symbol-specific profits from history
double g_historyOverallDaily[5];    // Last 5 days overall profits from history

// STing State
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

// Group trailing state (for SINGLE_TRAIL_CLOSETOGETHER mode)
struct GroupTrailState {
   bool active;
   double peakProfit;
   double threshold;
   double gap;
   ulong farthestBuyTicket;
   ulong farthestSellTicket;
   int lastLogTick;
};
GroupTrailState g_groupTrail = {false, 0.0, 0.0, 0.0, 0, 0, 0};

// Price tracking
static double g_prevAsk = 0.0;
static double g_prevBid = 0.0;

// Order placement tracking (prevent duplicates during execution)
struct LastOrderInfo {
   int level;
   int type;
   datetime time;
};
LastOrderInfo g_lastBuyOrder = {0, -1, 0};
LastOrderInfo g_lastSellOrder = {0, -1, 0};

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
   
   // Button 5: Toggle Next Level Lines
   string btn5Name = "BtnToggleNextLines";
   if(ObjectFind(0, btn5Name) < 0) {
      ObjectCreate(0, btn5Name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, btn5Name, OBJPROP_XDISTANCE, rightMargin);
      ObjectSetInteger(0, btn5Name, OBJPROP_YDISTANCE, topMargin + (buttonHeight + verticalGap) * 4);
      ObjectSetInteger(0, btn5Name, OBJPROP_XSIZE, buttonWidth);
      ObjectSetInteger(0, btn5Name, OBJPROP_YSIZE, buttonHeight);
      ObjectSetInteger(0, btn5Name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, btn5Name, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, btn5Name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, btn5Name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, btn5Name, OBJPROP_HIDDEN, false);
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
   
   // Update Button 5: Toggle Next Level Lines
   string btn5Name = "BtnToggleNextLines";
   if(g_showNextLevelLines) {
      ObjectSetString(0, btn5Name, OBJPROP_TEXT, "Next Lines [ON]");
      ObjectSetInteger(0, btn5Name, OBJPROP_BGCOLOR, clrBlue);
      ObjectSetInteger(0, btn5Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn5Name, OBJPROP_STATE, true);
   } else {
      ObjectSetString(0, btn5Name, OBJPROP_TEXT, "Show Next Lines");
      ObjectSetInteger(0, btn5Name, OBJPROP_BGCOLOR, clrDarkGray);
      ObjectSetInteger(0, btn5Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn5Name, OBJPROP_STATE, false);
   }
   
   ChartRedraw(0);
}

//============================= RESTORE STATE FROM POSITIONS =======//
void RestoreStateFromPositions() {
   // This function restores EA state variables from existing open positions
   // Useful when EA is restarted with open positions
   
   int totalPositions = 0;
   double maxLotFound = 0.0;
   ulong lastTicket = 0;
   datetime lastOpenTime = 0;
   string lastComment = "";
   int lastOrderLevel = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
      
      totalPositions++;
      
      double lots = PositionGetDouble(POSITION_VOLUME);
      if(lots > maxLotFound) maxLotFound = lots;
      
      // Track last (most recent) order by open time
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      if(openTime > lastOpenTime) {
         lastOpenTime = openTime;
         lastTicket = ticket;
         lastComment = PositionGetString(POSITION_COMMENT);
      }
   }
   
   // Restore max lot sizes if we found positions
   if(totalPositions > 0 && maxLotFound > 0) {
      g_maxLotsCycle = maxLotFound;
      // Only update overall max if found lot is greater (never decrease)
      if(maxLotFound > g_overallMaxLotSize) g_overallMaxLotSize = maxLotFound;
   }
   
   // Parse last order comment to restore state
   // Format: E{lastCloseEquity}BP{bookedProfit}{B/S}{level}
   // Example: E2123BP24B42
   if(lastComment != "" && lastTicket > 0) {
      // Extract last close equity (E value)
      int ePos = StringFind(lastComment, "E");
      int bpPos = StringFind(lastComment, "BP");
      
      if(ePos >= 0 && bpPos > ePos) {
         string equityStr = StringSubstr(lastComment, ePos + 1, bpPos - ePos - 1);
         double parsedEquity = StringToDouble(equityStr);
         
         if(parsedEquity > 0) {
            g_lastCloseEquity = parsedEquity;
            Log(1, StringFormat("Restored lastCloseEquity from comment: %.2f", g_lastCloseEquity));
         }
      }
      
      // Extract grid level from comment (after B or S)
      int bPos = StringFind(lastComment, "B", bpPos);
      int sPos = StringFind(lastComment, "S", bpPos);
      int levelPos = (bPos > bpPos) ? bPos : sPos;
      
      if(levelPos > bpPos) {
         string levelStr = StringSubstr(lastComment, levelPos + 1);
         lastOrderLevel = (int)StringToInteger(levelStr);
         
         // Calculate current grid level based on current price
         double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         int currentLevel = PriceLevelIndex(currentPrice, g_adaptiveGap);
         
         Log(1, StringFormat("Last order level: %d | Current price level: %d | Level difference: %d", 
             lastOrderLevel, currentLevel, currentLevel - lastOrderLevel));
      }
      
      Log(1, StringFormat("State Restored: Found %d positions | Max Lot: %.2f | Overall Max: %.2f | Comment: %s", 
          totalPositions, maxLotFound, g_overallMaxLotSize, lastComment));
   } else if(totalPositions > 0) {
      Log(1, StringFormat("State Restored: Found %d positions | Max Lot: %.2f | Overall Max: %.2f", 
          totalPositions, maxLotFound, g_overallMaxLotSize));
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

//============================= HISTORY DAILY PROFIT CALCULATION ====//
void CalculateHistoryDailyProfits() {
   // Initialize arrays
   ArrayInitialize(g_historySymbolDaily, 0.0);
   ArrayInitialize(g_historyOverallDaily, 0.0);
   
   // Get current date
   MqlDateTime dtNow;
   TimeCurrent(dtNow);
   datetime today = StringToTime(StringFormat("%04d.%02d.%02d 00:00:00", dtNow.year, dtNow.mon, dtNow.day));
   
   // Calculate timestamps for last 5 days (from today)
   datetime dayStarts[5];
   for(int i = 0; i < 5; i++) {
      dayStarts[i] = today - (i * 86400); // 86400 = seconds in a day
   }
   
   // Request history for the last 5 days
   datetime historyStart = dayStarts[4]; // 4 days ago
   datetime historyEnd = TimeCurrent();
   
   if(!HistorySelect(historyStart, historyEnd)) {
      Log(2, "Failed to load history");
      return;
   }
   
   int totalDeals = HistoryDealsTotal();
   
   // Process each deal
   for(int i = 0; i < totalDeals; i++) {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      
      // Only count OUT deals (closing positions)
      long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(dealEntry != DEAL_ENTRY_OUT) continue;
      
      long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
      string dealSymbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
      double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
      datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
      
      // Determine which day this deal belongs to
      MqlDateTime dtDeal;
      TimeToStruct(dealTime, dtDeal);
      datetime dealDay = StringToTime(StringFormat("%04d.%02d.%02d 00:00:00", dtDeal.year, dtDeal.mon, dtDeal.day));
      
      // Add to appropriate day index
      for(int d = 0; d < 5; d++) {
         if(dealDay == dayStarts[d]) {
            // Add to overall daily profit (ALL deals regardless of magic or symbol)
            g_historyOverallDaily[d] += dealProfit;
            
            // Add to symbol-specific daily profit if it matches our magic AND symbol
            if(dealMagic == Magic && dealSymbol == _Symbol) {
               g_historySymbolDaily[d] += dealProfit;
            }
            break;
         }
      }
   }
   
   Log(3, StringFormat("History Daily Profits - Symbol: %.2f,%.2f,%.2f,%.2f,%.2f | Overall: %.2f,%.2f,%.2f,%.2f,%.2f",
       g_historySymbolDaily[0], g_historySymbolDaily[1], g_historySymbolDaily[2], g_historySymbolDaily[3], g_historySymbolDaily[4],
       g_historyOverallDaily[0], g_historyOverallDaily[1], g_historyOverallDaily[2], g_historyOverallDaily[3], g_historyOverallDaily[4]));
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
   
   // Track max lot size directly from order traversal
   double currentMaxLot = 0.0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
      
      int type = (int)PositionGetInteger(POSITION_TYPE);
      double lots = PositionGetDouble(POSITION_VOLUME);
      double profit = PositionGetDouble(POSITION_PROFIT);
      
      g_totalProfit += profit;
      
      // Track max lot size in current cycle
      if(lots > currentMaxLot) currentMaxLot = lots;
      
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
   
   // Update cycle max lot size (use >= to ensure first value is captured)
   if(currentMaxLot > g_maxLotsCycle) g_maxLotsCycle = currentMaxLot;
   
   // Update overall max lot size (never decreases, use >= to ensure first value is captured)
   if(currentMaxLot > g_overallMaxLotSize) g_overallMaxLotSize = currentMaxLot;
   
   // Debug logging for max lot tracking
   if(currentMaxLot > 0 && DebugLevel >= 3) {
      Log(3, StringFormat("MaxLot tracking: current=%.2f | cycle=%.2f | overall=%.2f", 
          currentMaxLot, g_maxLotsCycle, g_overallMaxLotSize));
   }
   
   g_netLots = g_buyLots - g_sellLots;

   // Profit views: overall P/L since start, cycle profit (booked+open), open vs booked breakdown
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity == 0) return;  // Account data not ready yet
   
   double overallProfit = equity - g_startingEquity;         // overall profit since EA started
   double cycleProfit = equity - g_lastCloseEquity;         // current cycle profit (booked + open since last close-all)
   double openProfit = g_totalProfit;                       // current open P/L
   double bookedCycle = cycleProfit - openProfit;           // booked in this cycle
   
   // Track overall max profit (update every tick, never reset)
   if(overallProfit > g_overallMaxProfit) g_overallMaxProfit = overallProfit;
   
   // Track cycle max profit/loss (resets on close-all)
   if(cycleProfit > g_maxProfitCycle) g_maxProfitCycle = cycleProfit;
   if(cycleProfit < 0) {
      double absLoss = MathAbs(cycleProfit);
      if(absLoss > g_maxLossCycle) {
         double prevMaxLoss = g_maxLossCycle;
         g_maxLossCycle = absLoss;
         
         // Create vline when max loss increases and exceeds threshold
         if(absLoss >= MaxLossVlineThreshold && absLoss > g_lastMaxLossVline) {
            datetime nowTime = TimeCurrent();
            // Round loss to nearest thousand (e.g., 5498 -> 5k, 12800 -> 13k)
            int lossRoundedK = (int)MathRound(absLoss / 1000.0);
            string vlineName = StringFormat("maxloss_%.0f_%dk",  g_lastCloseEquity, lossRoundedK);
            
            // Delete old if exists
            ObjectDelete(0, vlineName);
            
            // Create vertical line
            double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(ObjectCreate(0, vlineName, OBJ_VLINE, 0, nowTime, currentPrice)) {
               // Color: red if this is >= overall max loss, pink otherwise
               color lineColor = (absLoss >= g_overallMaxLoss) ? clrRed : clrDeepPink;
               ObjectSetInteger(0, vlineName, OBJPROP_COLOR, lineColor);
               ObjectSetInteger(0, vlineName, OBJPROP_WIDTH, 1);
               ObjectSetInteger(0, vlineName, OBJPROP_STYLE, STYLE_DOT);
               ObjectSetInteger(0, vlineName, OBJPROP_BACK, true);
               ObjectSetInteger(0, vlineName, OBJPROP_SELECTABLE, false);
               
               string vlineText = StringFormat("MaxLoss: %.2f | Overall: %.2f | Equity: %.2f", absLoss, g_overallMaxLoss, equity);
               ObjectSetString(0, vlineName, OBJPROP_TEXT, vlineText);
               
               Log(2, StringFormat("MaxLoss VLine: %.2f (color: %s) | Overall: %.2f | Equity: %.2f", 
                   absLoss, (absLoss >= g_overallMaxLoss) ? "RED" : "PINK", g_overallMaxLoss, equity));
            }
            
            g_lastMaxLossVline = absLoss;
         }
      }
      // Track overall max loss ever touched in any cycle (never resets)
      if(absLoss > g_overallMaxLoss) g_overallMaxLoss = absLoss;
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
   
   // Switch mode after threshold orders
   if(maxOrders >= SwitchModeCount && MathAbs(g_netLots) > 0.01) {
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
   
   // Switch mode after threshold order difference
   if(orderDiff >= SwitchModeCount && MathAbs(g_netLots) > 0.01) {
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
   // Switch triggered after threshold orders, but maintain equal sizing
   if(maxOrders >= SwitchModeCount && MathAbs(g_netLots) > 0.01) {
      // Still apply base lot calculation, but keep them equal
      double baseLot = BaseLotSize * (maxOrders + 1);
      g_nextSellLot = baseLot;
      g_nextBuyLot = baseLot;
   }
}

// Method 4: Fixed Levels Mode Switch
void CalculateLots_Fixed_Levels() {
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
   
   // Determine which iteration we're in based on origin price and current price
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int currentLevel = PriceLevelIndex(currentPrice, g_adaptiveGap);
   
   // Calculate which zone we're in: each zone spans SwitchModeCount levels
   // Zone 0: levels -5 to 5 (if SwitchModeCount=5)
   // Zone 1: levels 5 to 10 or -5 to -10
   // Zone 2: levels 10 to 15 or -10 to -15, etc.
   int zone = (int)(MathAbs(currentLevel) / SwitchModeCount);
   
   // Switch mode on odd zones (zone 1, 3, 5, etc.)
   bool shouldSwitch = (zone % 2 == 1);
   
   if(shouldSwitch && MathAbs(g_netLots) > 0.01) {
      double temp = g_nextSellLot;
      g_nextSellLot = g_nextBuyLot;
      g_nextBuyLot = temp;
   }
}

// Method 5: GLO Based (Global Loss Orders Based)
void CalculateLots_GLOBased() {
   // Count orders currently in loss
   g_orders_in_loss = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
      
      double profit = PositionGetDouble(POSITION_PROFIT);
      if(profit < 0) {
         g_orders_in_loss++;
      }
   }
   
   // Calculate lot size: BaseLotSize + (BaseLotSize * orders_in_loss)
   // Both buy and sell lots will be the same
   double calculatedLot = BaseLotSize + (BaseLotSize * g_orders_in_loss);
   
   g_nextBuyLot = calculatedLot;
   g_nextSellLot = calculatedLot;
   
   // Track max GLO overall (never resets)
   if(g_orders_in_loss > g_maxGLOOverall) g_maxGLOOverall = g_orders_in_loss;
   
   Log(3, StringFormat("GLO Method: Orders in loss=%d | Next lot=%.2f", 
       g_orders_in_loss, calculatedLot));
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
      
      case LOT_METHOD_FIXED_LEVELS:
         CalculateLots_Fixed_Levels();
         break;
      
      case LOT_METHOD_GLO_BASED:
         CalculateLots_GLOBased();
         break;
      
      default:
         CalculateLots_GLOBased();
         break;
   }
   
   // Override with base lot size if trail is active and mode requires it
   if(g_trailActive && (TrailOrderMode == TRAIL_ORDERS_BASESIZE || 
                         TrailOrderMode == TRAIL_ORDERS_PROFIT_DIR || 
                         TrailOrderMode == TRAIL_ORDERS_REVERSE_DIR)) {
      g_nextBuyLot = BaseLotSize;
      g_nextSellLot = BaseLotSize;
      string modeDesc = (TrailOrderMode == TRAIL_ORDERS_BASESIZE) ? "base size" : 
                        (TrailOrderMode == TRAIL_ORDERS_PROFIT_DIR) ? "profit direction" : "reverse direction";
      Log(3, StringFormat("Trail active: Using base lot size %.2f (mode: %s)", BaseLotSize, modeDesc));
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
   
   // Extract level from comment if available (format: "E...BP...B14" or "E...BP...S-15")
   int orderLevel = 0;
   if(StringLen(comment) > 0) {
      int pos = StringFind(comment, orderType == POSITION_TYPE_BUY ? "B" : "S", 0);
      if(pos >= 0 && pos < StringLen(comment) - 1) {
         string levelStr = StringSubstr(comment, pos + 1);
         orderLevel = (int)StringToInteger(levelStr);
      }
   }
   
   double maxLotPerOrder = 20.0;
   int ordersNeeded = (int)MathCeil(lotSize / maxLotPerOrder);
   
   if(ordersNeeded == 1) {
      // Single order - execute directly
      trade.SetExpertMagicNumber(Magic);
      bool result = false;
      if(orderType == POSITION_TYPE_BUY) {
         result = trade.Buy(lotSize, _Symbol, 0, 0, 0, comment);
      } else {
         result = trade.Sell(lotSize, _Symbol, 0, 0, 0, comment);
      }
      
      // Record successful order placement
      if(result && orderLevel != 0) {
         datetime currentTime = TimeCurrent();
         string typeStr = (orderType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
         if(orderType == POSITION_TYPE_BUY) {
            g_lastBuyOrder.level = orderLevel;
            g_lastBuyOrder.type = orderType;
            g_lastBuyOrder.time = currentTime;
         } else {
            g_lastSellOrder.level = orderLevel;
            g_lastSellOrder.type = orderType;
            g_lastSellOrder.time = currentTime;
         }
         Log(2, StringFormat("[ORDER-RECORDED] %s L%d @ %s | Lot=%.2f", 
             typeStr, orderLevel, TimeToString(currentTime, TIME_SECONDS), lotSize));
      }
      
      // Apply delay if configured
      if(result && OrderPlacementDelayMs > 0) {
         Sleep(OrderPlacementDelayMs);
      }
      
      return result;
   }
   
   // Multiple orders needed - split the lot size
   double remainingLots = lotSize;
   int successCount = 0;
   bool firstOrderPlaced = false;
   
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
         
         // Record first split order to prevent duplicates
         if(!firstOrderPlaced && orderLevel != 0) {
            datetime currentTime = TimeCurrent();
            string typeStr = (orderType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
            if(orderType == POSITION_TYPE_BUY) {
               g_lastBuyOrder.level = orderLevel;
               g_lastBuyOrder.type = orderType;
               g_lastBuyOrder.time = currentTime;
            } else {
               g_lastSellOrder.level = orderLevel;
               g_lastSellOrder.type = orderType;
               g_lastSellOrder.time = currentTime;
            }
            Log(2, StringFormat("[ORDER-RECORDED-SPLIT] %s L%d @ %s | Lot=%.2f (split %d/%d)", 
                typeStr, orderLevel, TimeToString(currentTime, TIME_SECONDS), currentLot, i+1, ordersNeeded));
            firstOrderPlaced = true;
         }
         
         // Apply delay between split orders if configured
         if(OrderPlacementDelayMs > 0) {
            Sleep(OrderPlacementDelayMs);
         }
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

// Check for orders of same type within a small price distance (prevents duplicates)
bool HasOrderAtPrice(int orderType, int level, double gap) {
   string typeStr = (orderType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
   datetime currentTime = TimeCurrent();
   double levelPrice = LevelPrice(level, gap);
   double tolerance = gap * 0.45; // Nearly half gap distance for safety
   
   Log(3, StringFormat("[DUP-CHECK] %s L%d | LevelPrice=%.5f Tolerance=%.5f Gap=%.5f", 
       typeStr, level, levelPrice, tolerance, gap));
   
   // Check if we just placed an order at this level (within last 15 seconds)
   if(orderType == POSITION_TYPE_BUY) {
      if(g_lastBuyOrder.level == level && g_lastBuyOrder.type == orderType) {
         int timeDiff = (int)(currentTime - g_lastBuyOrder.time);
         if(timeDiff <= 15) {
            Log(2, StringFormat("[DUP-BLOCKED-TIME] %s L%d | Last order %d seconds ago", 
                typeStr, level, timeDiff));
            return true; // Block - we just placed order here
         }
      }
   } else {
      if(g_lastSellOrder.level == level && g_lastSellOrder.type == orderType) {
         int timeDiff = (int)(currentTime - g_lastSellOrder.time);
         if(timeDiff <= 15) {
            Log(2, StringFormat("[DUP-BLOCKED-TIME] %s L%d | Last order %d seconds ago", 
                typeStr, level, timeDiff));
            return true; // Block - we just placed order here
         }
      }
   }
   
   // Also check existing positions
   int positionsChecked = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
      
      int type = (int)PositionGetInteger(POSITION_TYPE);
      if(type != orderType) continue;
      
      positionsChecked++;
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double priceDistance = MathAbs(openPrice - levelPrice);
      
      Log(3, StringFormat("[DUP-CHECK] Position #%I64u %s @ %.5f | Distance=%.5f Tolerance=%.5f", 
          ticket, typeStr, openPrice, priceDistance, tolerance));
      
      if(priceDistance < tolerance) {
         Log(2, StringFormat("[DUP-BLOCKED-PRICE] %s L%d | Found position #%I64u @ %.5f (distance=%.5f < tolerance=%.5f)", 
             typeStr, level, ticket, openPrice, priceDistance, tolerance));
         return true;
      }
   }
   
   Log(3, StringFormat("[DUP-CHECK] %s L%d | Checked %d positions - ALLOW ORDER", 
       typeStr, level, positionsChecked));
   return false;
}

// Check if order exists at a specific level by parsing comment field
// More reliable than price-based checks when there's market delay
// Comment format: "E...BP...B6" (BUY level 6) or "E...BP...S-3" (SELL level -3)
bool HasOrderAtLevelByComment(int orderType, int level) {
   string searchPattern = (orderType == POSITION_TYPE_BUY) ? "B" : "S";
   string levelStr = IntegerToString(level);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
      
      int type = (int)PositionGetInteger(POSITION_TYPE);
      if(type != orderType) continue;
      
      string comment = PositionGetString(POSITION_COMMENT);
      
      // Find the position of B or S in the comment
      int bPos = StringFind(comment, "B", 0);
      int sPos = StringFind(comment, "S", 0);
      int levelPos = -1;
      
      // Determine which marker to use based on order type
      if(orderType == POSITION_TYPE_BUY && bPos >= 0) {
         // For BUY, find the last 'B' in comment (after BP)
         int lastBPos = bPos;
         int searchPos = bPos + 1;
         while(searchPos < StringLen(comment)) {
            int nextB = StringFind(comment, "B", searchPos);
            if(nextB < 0) break;
            lastBPos = nextB;
            searchPos = nextB + 1;
         }
         levelPos = lastBPos;
      } else if(orderType == POSITION_TYPE_SELL && sPos >= 0) {
         // For SELL, find the last 'S' in comment
         int lastSPos = sPos;
         int searchPos = sPos + 1;
         while(searchPos < StringLen(comment)) {
            int nextS = StringFind(comment, "S", searchPos);
            if(nextS < 0) break;
            lastSPos = nextS;
            searchPos = nextS + 1;
         }
         levelPos = lastSPos;
      }
      
      if(levelPos >= 0 && levelPos < StringLen(comment) - 1) {
         string extractedLevel = StringSubstr(comment, levelPos + 1);
         int commentLevel = (int)StringToInteger(extractedLevel);
         
         if(commentLevel == level) {
            Log(3, StringFormat("[COMMENT-CHECK] Found %s order at L%d via comment: %s",
                searchPattern, level, comment));
            return true;
         }
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

// Check if order placement is allowed based on strategy
// Returns true if order can be placed, false if blocked by strategy
bool IsOrderPlacementAllowed(int orderType, int level, double gap) {
   // If no strategy, always allow
   if(OrderPlacementStrategy == ORDER_STRATEGY_NONE) {
      return true;
   }
   
   // If no open positions, always allow first order
   if(PositionsTotal() == 0) {
      Log(3, "[STRATEGY] No positions - allowing first order");
      return true;
   }
   
   // Boundary Check Directional Strategy:
   // BUY at level L (even) - needs SELL order below it (any odd level < L)
   // SELL at level L (odd) - needs BUY order above it (any even level > L)
   if(OrderPlacementStrategy == ORDER_STRATEGY_BOUNDARY_DIRECTIONAL) {
      string typeStr = (orderType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
      
      bool hasOpposingOrder = false;
      int opposingCount = 0;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
         
         int type = (int)PositionGetInteger(POSITION_TYPE);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         int existingLevel = PriceLevelIndex(openPrice, gap);
         
         if(orderType == POSITION_TYPE_BUY) {
            // BUY order - need SELL below (SELL level < BUY level)
            if(type == POSITION_TYPE_SELL && existingLevel < level) {
               hasOpposingOrder = true;
               opposingCount++;
            }
         } else {
            // SELL order - need BUY above (BUY level > SELL level)
            if(type == POSITION_TYPE_BUY && existingLevel > level) {
               hasOpposingOrder = true;
               opposingCount++;
            }
         }
      }
      
      if(!hasOpposingOrder) {
         string direction = (orderType == POSITION_TYPE_BUY) ? "below" : "above";
         string opposingType = (orderType == POSITION_TYPE_BUY) ? "SELL" : "BUY";
         Log(2, StringFormat("[STRATEGY-BLOCKED] %s L%d | No %s order %s - boundary check failed",
             typeStr, level, opposingType, direction));
         return false;
      }
      
      Log(3, StringFormat("[STRATEGY-PASSED] %s L%d | Found %d opposing orders - boundary check passed",
          typeStr, level, opposingCount));
      return true;
   }
   
   // Adjacent Only Strategy:
   // BUY at even level L - needs SELL order at adjacent level L-1 (odd, below)
   // SELL at odd level L - needs BUY order at adjacent level L+1 (even, above)
   // Exception: Top BUY or Bottom SELL can always be placed
   if(OrderPlacementStrategy == ORDER_STRATEGY_ADJACENT_ONLY) {
      string typeStr = (orderType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
      
      // First, check if this is a boundary order (topmost BUY or bottommost SELL)
      bool isTopBuy = false;
      bool isBottomSell = false;
      
      if(orderType == POSITION_TYPE_BUY) {
         // Check if there are any BUY orders above this level
         isTopBuy = true;
         for(int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if(!PositionSelectByTicket(ticket)) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
            
            int type = (int)PositionGetInteger(POSITION_TYPE);
            if(type != POSITION_TYPE_BUY) continue;
            
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            int existingLevel = PriceLevelIndex(openPrice, gap);
            
            if(existingLevel > level) {
               isTopBuy = false;
               break;
            }
         }
         
         if(isTopBuy) {
            Log(3, StringFormat("[STRATEGY-PASSED] %s L%d | Top BUY - no adjacent check needed",
                typeStr, level));
            return true;
         }
      } else {
         // Check if there are any SELL orders below this level
         isBottomSell = true;
         for(int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if(!PositionSelectByTicket(ticket)) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
            
            int type = (int)PositionGetInteger(POSITION_TYPE);
            if(type != POSITION_TYPE_SELL) continue;
            
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            int existingLevel = PriceLevelIndex(openPrice, gap);
            
            if(existingLevel < level) {
               isBottomSell = false;
               break;
            }
         }
         
         if(isBottomSell) {
            Log(3, StringFormat("[STRATEGY-PASSED] %s L%d | Bottom SELL - no adjacent check needed",
                typeStr, level));
            return true;
         }
      }
      
      // Not a boundary order, so check for adjacent opposing order
      int requiredLevel;
      int requiredType;
      
      if(orderType == POSITION_TYPE_BUY) {
         // BUY at even level L needs SELL at odd level L-1
         requiredLevel = level - 1;
         requiredType = POSITION_TYPE_SELL;
      } else {
         // SELL at odd level L needs BUY at even level L+1
         requiredLevel = level + 1;
         requiredType = POSITION_TYPE_BUY;
      }
      
      // Check if required adjacent order exists
      bool hasAdjacentOrder = false;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
         
         int type = (int)PositionGetInteger(POSITION_TYPE);
         if(type != requiredType) continue;
         
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         int existingLevel = PriceLevelIndex(openPrice, gap);
         
         if(existingLevel == requiredLevel) {
            hasAdjacentOrder = true;
            Log(3, StringFormat("[STRATEGY-PASSED] %s L%d | Found adjacent %s at L%d",
                typeStr, level, (requiredType == POSITION_TYPE_BUY) ? "BUY" : "SELL", requiredLevel));
            break;
         }
      }
      
      if(!hasAdjacentOrder) {
         string requiredTypeStr = (requiredType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
         Log(2, StringFormat("[STRATEGY-BLOCKED] %s L%d | No adjacent %s order at L%d",
             typeStr, level, requiredTypeStr, requiredLevel));
         return false;
      }
      
      return true;
   }
   
   // Default: allow
   return true;
}

//============================= MISSED ORDER PLACEMENT =============//
// Check for missed orders at adjacent levels and create them
// Only runs when OrderPlacementType = ORDER_PLACEMENT_FLEXIBLE
void PlaceMissedAdjacentOrders() {
   double nowAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double nowBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Get current price levels
   int currentAskLevel = PriceLevelIndex(nowAsk, g_adaptiveGap);
   int currentBidLevel = PriceLevelIndex(nowBid, g_adaptiveGap);
   
   // Check adjacent SELL level (one level above current ask - should be odd)
   int adjacentSellLevel = currentAskLevel + 1;
   if(!IsOdd(adjacentSellLevel)) adjacentSellLevel++; // Make sure it's odd
   
   // Check if SELL order exists at adjacent level - use comment check first (most reliable)
   if(!HasOrderAtLevelByComment(POSITION_TYPE_SELL, adjacentSellLevel) &&
      !HasOrderOnLevel(POSITION_TYPE_SELL, adjacentSellLevel, g_adaptiveGap) &&
      !HasOrderAtPrice(POSITION_TYPE_SELL, adjacentSellLevel, g_adaptiveGap)) {
      
      // Check if we should place this order based on strategy
      if(IsOrderPlacementAllowed(POSITION_TYPE_SELL, adjacentSellLevel, g_adaptiveGap)) {
         Log(1, StringFormat("[DELAYED-ORDER] Creating missed SELL order at adjacent level L%d", adjacentSellLevel));
         
         double equity = AccountInfoDouble(ACCOUNT_EQUITY);
         double cycleProfit = equity - g_lastCloseEquity;
         double bookedProfit = cycleProfit - g_totalProfit;
         string orderComment = StringFormat("E%.0fBP%.0fS%d", g_lastCloseEquity, bookedProfit, adjacentSellLevel);
         
         if(ExecuteOrder(POSITION_TYPE_SELL, g_nextSellLot, orderComment)) {
            if(g_nextSellLot > g_maxLotsCycle) g_maxLotsCycle = g_nextSellLot;
            if(g_nextSellLot > g_overallMaxLotSize) g_overallMaxLotSize = g_nextSellLot;
            Log(1, StringFormat("[DELAYED-ORDER] SELL %.2f @ L%d (%.5f) - missed order filled", 
                g_nextSellLot, adjacentSellLevel, nowBid));
         }
      }
   }
   
   // Check adjacent BUY level (one level below current bid - should be even)
   int adjacentBuyLevel = currentBidLevel - 1;
   if(!IsEven(adjacentBuyLevel)) adjacentBuyLevel--; // Make sure it's even
   
   // Check if BUY order exists at adjacent level - use comment check first (most reliable)
   if(!HasOrderAtLevelByComment(POSITION_TYPE_BUY, adjacentBuyLevel) &&
      !HasOrderOnLevel(POSITION_TYPE_BUY, adjacentBuyLevel, g_adaptiveGap) &&
      !HasOrderAtPrice(POSITION_TYPE_BUY, adjacentBuyLevel, g_adaptiveGap)) {
      
      // Check if we should place this order based on strategy
      if(IsOrderPlacementAllowed(POSITION_TYPE_BUY, adjacentBuyLevel, g_adaptiveGap)) {
         Log(1, StringFormat("[DELAYED-ORDER] Creating missed BUY order at adjacent level L%d", adjacentBuyLevel));
         
         double equity = AccountInfoDouble(ACCOUNT_EQUITY);
         double cycleProfit = equity - g_lastCloseEquity;
         double bookedProfit = cycleProfit - g_totalProfit;
         string orderComment = StringFormat("E%.0fBP%.0fB%d", g_lastCloseEquity, bookedProfit, adjacentBuyLevel);
         
         if(ExecuteOrder(POSITION_TYPE_BUY, g_nextBuyLot, orderComment)) {
            if(g_nextBuyLot > g_maxLotsCycle) g_maxLotsCycle = g_nextBuyLot;
            if(g_nextBuyLot > g_overallMaxLotSize) g_overallMaxLotSize = g_nextBuyLot;
            Log(1, StringFormat("[DELAYED-ORDER] BUY %.2f @ L%d (%.5f) - missed order filled", 
                g_nextBuyLot, adjacentBuyLevel, nowAsk));
         }
      }
   }
}

//============================= NO POSITIONS HANDLER ===============//
void HandleNoPositions() {
   if(NoPositionsAction == NO_POS_NONE) return;
   
   double nowAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double nowBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double midPrice = (nowAsk + nowBid) / 2.0;
   
   // Find nearest levels
   int nearestLevel = (int)MathRound((midPrice - g_originPrice) / g_adaptiveGap);
   
   // Determine which level is BUY (even) and which is SELL (odd)
   int buyLevel, sellLevel;
   
   if(IsEven(nearestLevel)) {
      // Nearest is even (BUY level)
      buyLevel = nearestLevel;
      sellLevel = nearestLevel + 1; // Next odd level
   } else {
      // Nearest is odd (SELL level)
      sellLevel = nearestLevel;
      buyLevel = nearestLevel - 1; // Previous even level
   }
   
   double buyPrice = LevelPrice(buyLevel, g_adaptiveGap);
   double sellPrice = LevelPrice(sellLevel, g_adaptiveGap);
   
   // Calculate lot sizes
   CalculateNextLots();
   
   if(NoPositionsAction == NO_POS_NEAREST_LEVEL) {
      // Open single order at nearest level
      double distToBuy = MathAbs(midPrice - buyPrice);
      double distToSell = MathAbs(midPrice - sellPrice);
      
      if(distToBuy <= distToSell) {
         // BUY level is nearest
         double equity = AccountInfoDouble(ACCOUNT_EQUITY);
         string comment = StringFormat("E%.0fBP0B%d", equity, buyLevel);
         bool result = ExecuteOrder(POSITION_TYPE_BUY, g_nextBuyLot, comment);
         if(result) {
            Log(1, StringFormat("[NO-POS] Opened BUY @ L%d (%.5f) - nearest level", buyLevel, buyPrice));
         }
      } else {
         // SELL level is nearest
         double equity = AccountInfoDouble(ACCOUNT_EQUITY);
         string comment = StringFormat("E%.0fBP0S%d", equity, sellLevel);
         bool result = ExecuteOrder(POSITION_TYPE_SELL, g_nextSellLot, comment);
         if(result) {
            Log(1, StringFormat("[NO-POS] Opened SELL @ L%d (%.5f) - nearest level", sellLevel, sellPrice));
         }
      }
   } else if(NoPositionsAction == NO_POS_BOTH_LEVELS) {
      // Open both BUY and SELL at nearest levels
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      
      string buyComment = StringFormat("E%.0fBP0B%d", equity, buyLevel);
      bool buyResult = ExecuteOrder(POSITION_TYPE_BUY, g_nextBuyLot, buyComment);
      if(buyResult) {
         Log(1, StringFormat("[NO-POS] Opened BUY @ L%d (%.5f) - both levels mode", buyLevel, buyPrice));
      }
      
      // Small delay between orders if configured
      if(OrderPlacementDelayMs > 0) {
         Sleep(OrderPlacementDelayMs);
      }
      
      string sellComment = StringFormat("E%.0fBP0S%d", equity, sellLevel);
      bool sellResult = ExecuteOrder(POSITION_TYPE_SELL, g_nextSellLot, sellComment);
      if(sellResult) {
         Log(1, StringFormat("[NO-POS] Opened SELL @ L%d (%.5f) - both levels mode", sellLevel, sellPrice));
      }
   }
}

//============================= ORDER PLACEMENT ====================//
void PlaceGridOrders() {
   // Check if no positions and handle according to configured action
   if(PositionsTotal() == 0) {
      HandleNoPositions();
      return;
   }
   
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
   
   // Handle orders during total trailing based on mode
   if(g_trailActive && TrailOrderMode == TRAIL_ORDERS_NONE) {
      Log(3, "New orders blocked: total trailing active (mode: no orders)");
      return;
   }
   
   // Check for missed adjacent orders if flexible placement is enabled
   if(OrderPlacementType == ORDER_PLACEMENT_FLEXIBLE) {
      PlaceMissedAdjacentOrders();
   }
   
   double nowAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double nowBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   
   // Initialize static variables
   if(g_prevAsk == 0.0) g_prevAsk = nowAsk;
   if(g_prevBid == 0.0) g_prevBid = nowBid;
   
   // Determine if BUY/SELL orders are allowed during trail based on direction mode
   bool allowBuy = true;
   bool allowSell = true;
   
   if(g_trailActive) {
      if(TrailOrderMode == TRAIL_ORDERS_PROFIT_DIR) {
         // Profit direction: only allow orders in the direction of net exposure
         if(g_netLots < 0) allowBuy = false;  // SELL exposed, block BUY
         if(g_netLots > 0) allowSell = false; // BUY exposed, block SELL
      }
      else if(TrailOrderMode == TRAIL_ORDERS_REVERSE_DIR) {
         // Reverse direction: only allow orders opposite to net exposure (hedging)
         if(g_netLots > 0) allowBuy = false;  // BUY exposed, block more BUY
         if(g_netLots < 0) allowSell = false; // SELL exposed, block more SELL
      }
   }
   
   // BUY logic - price moving up
   // BUY executes at ASK, so trigger should ensure ASK crosses level + half spread
   if(nowAsk > g_prevAsk && allowBuy) {
      int Llo = PriceLevelIndex(MathMin(g_prevAsk, nowAsk), g_adaptiveGap) - 2;
      int Lhi = PriceLevelIndex(MathMax(g_prevAsk, nowAsk), g_adaptiveGap) + 2;
      
      for(int L = Llo; L <= Lhi; L++) {
         if(!IsEven(L)) continue;
         
         // BUY trigger: level price + half spread (so ASK crosses the level accounting for spread)
         double trigger = LevelPrice(L, g_adaptiveGap) + (spread / 2.0);
         if(g_prevAsk <= trigger && nowAsk > trigger) {
            Log(2, StringFormat("[PLACE-CHECK] BUY L%d triggered | Trigger=%.5f PrevAsk=%.5f NowAsk=%.5f", 
                L, trigger, g_prevAsk, nowAsk));
            
            if(HasOrderOnLevel(POSITION_TYPE_BUY, L, g_adaptiveGap)) {
               Log(2, StringFormat("[PLACE-BLOCKED-LEVEL] BUY L%d | HasOrderOnLevel returned true", L));
               continue;
            }
            if(HasOrderAtPrice(POSITION_TYPE_BUY, L, g_adaptiveGap)) {
               Log(2, StringFormat("[PLACE-BLOCKED-PRICE] BUY L%d | HasOrderAtPrice returned true", L));
               continue;
            }
            if(!IsOrderPlacementAllowed(POSITION_TYPE_BUY, L, g_adaptiveGap)) {
               continue;
            }
            
            Log(2, StringFormat("[PLACE-EXECUTE] BUY L%d | Checks passed, placing order...", L));
            double equity = AccountInfoDouble(ACCOUNT_EQUITY);
            double cycleProfit = equity - g_lastCloseEquity;
            double bookedProfit = cycleProfit - g_totalProfit;
            string orderComment = StringFormat("E%.0fBP%.0fB%d", g_lastCloseEquity, bookedProfit, L);
            if(ExecuteOrder(POSITION_TYPE_BUY, g_nextBuyLot, orderComment)) {
               // Track max lot size (intended lot size, not split execution)
               if(g_nextBuyLot > g_maxLotsCycle) g_maxLotsCycle = g_nextBuyLot;
               if(g_nextBuyLot > g_overallMaxLotSize) g_overallMaxLotSize = g_nextBuyLot;
               Log(1, StringFormat("BUY %.2f @ L%d (%.5f)", g_nextBuyLot, L, nowAsk));
            }
         }
      }
   }
   
   // SELL logic - price moving down
   // SELL executes at BID, so trigger should ensure BID crosses level - half spread
   if(nowBid < g_prevBid && allowSell) {
      int Llo = PriceLevelIndex(MathMin(g_prevBid, nowBid), g_adaptiveGap) - 2;
      int Lhi = PriceLevelIndex(MathMax(g_prevBid, nowBid), g_adaptiveGap) + 2;
      
      for(int L = Lhi; L >= Llo; L--) {
         if(!IsOdd(L)) continue;
         
         // SELL trigger: level price - half spread (so BID crosses the level accounting for spread)
         double trigger = LevelPrice(L, g_adaptiveGap) - (spread / 2.0);
         if(g_prevBid >= trigger && nowBid < trigger) {
            Log(2, StringFormat("[PLACE-CHECK] SELL L%d triggered | Trigger=%.5f PrevBid=%.5f NowBid=%.5f", 
                L, trigger, g_prevBid, nowBid));
            
            if(HasOrderOnLevel(POSITION_TYPE_SELL, L, g_adaptiveGap)) {
               Log(2, StringFormat("[PLACE-BLOCKED-LEVEL] SELL L%d | HasOrderOnLevel returned true", L));
               continue;
            }
            if(HasOrderAtPrice(POSITION_TYPE_SELL, L, g_adaptiveGap)) {
               Log(2, StringFormat("[PLACE-BLOCKED-PRICE] SELL L%d | HasOrderAtPrice returned true", L));
               continue;
            }
            if(!IsOrderPlacementAllowed(POSITION_TYPE_SELL, L, g_adaptiveGap)) {
               continue;
            }
            
            Log(2, StringFormat("[PLACE-EXECUTE] SELL L%d | Checks passed, placing order...", L));
            double equity = AccountInfoDouble(ACCOUNT_EQUITY);
            double cycleProfit = equity - g_lastCloseEquity;
            double bookedProfit = cycleProfit - g_totalProfit;
            string orderComment = StringFormat("E%.0fBP%.0fS%d", g_lastCloseEquity, bookedProfit, L);
            if(ExecuteOrder(POSITION_TYPE_SELL, g_nextSellLot, orderComment)) {
               // Track max lot size (intended lot size, not split execution)
               if(g_nextSellLot > g_maxLotsCycle) g_maxLotsCycle = g_nextSellLot;
               if(g_nextSellLot > g_overallMaxLotSize) g_overallMaxLotSize = g_nextSellLot;
               Log(1, StringFormat("SELL %.2f @ L%d (%.5f)", g_nextSellLot, L, nowBid));
            }
         }
      }
   }
   
   g_prevAsk = nowAsk;
   g_prevBid = nowBid;
}

//============================= NEXT LEVEL LINES ===================//
// Resource-intensive function: calculates next available order levels
// Only runs when g_showNextLevelLines is true (controlled by button)
void UpdateNextLevelLines() {
   // Early exit if disabled - no calculations, no display
   if(!g_showNextLevelLines) {
      ObjectDelete(0, "NextBuyLevelUp");
      ObjectDelete(0, "NextBuyLevelDown");
      ObjectDelete(0, "NextSellLevelUp");
      ObjectDelete(0, "NextSellLevelDown");
      return;
   }
   
   double nowAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double nowBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = nowAsk - nowBid;
   
   // Find next available BUY level upward (check for existing orders)
   int nextBuyLevelUp = PriceLevelIndex(nowAsk, g_adaptiveGap);
   if(!IsEven(nextBuyLevelUp)) nextBuyLevelUp++;
   // Skip levels that already have orders (check both exact level and nearby)
   while((HasOrderOnLevel(POSITION_TYPE_BUY, nextBuyLevelUp, g_adaptiveGap) || 
          HasOrderNearLevel(POSITION_TYPE_BUY, nextBuyLevelUp, g_adaptiveGap, 1)) && 
         nextBuyLevelUp < 10000) {
      nextBuyLevelUp += 2; // BUY levels are even, increment by 2
   }
   double nextBuyPriceUp = LevelPrice(nextBuyLevelUp, g_adaptiveGap) + (spread / 2.0);
   
   // Find next available BUY level downward
   int nextBuyLevelDown = PriceLevelIndex(nowAsk, g_adaptiveGap);
   if(!IsEven(nextBuyLevelDown)) nextBuyLevelDown--;
   else nextBuyLevelDown -= 2;
   // Skip levels that already have orders (check both exact level and nearby)
   while((HasOrderOnLevel(POSITION_TYPE_BUY, nextBuyLevelDown, g_adaptiveGap) || 
          HasOrderNearLevel(POSITION_TYPE_BUY, nextBuyLevelDown, g_adaptiveGap, 1)) && 
         nextBuyLevelDown > -10000) {
      nextBuyLevelDown -= 2; // BUY levels are even, decrement by 2
   }
   double nextBuyPriceDown = LevelPrice(nextBuyLevelDown, g_adaptiveGap) + (spread / 2.0);
   
   // Find next available SELL level upward
   int nextSellLevelUp = PriceLevelIndex(nowBid, g_adaptiveGap);
   if(!IsOdd(nextSellLevelUp)) nextSellLevelUp++;
   else nextSellLevelUp += 2;
   // Skip levels that already have orders (check both exact level and nearby)
   while((HasOrderOnLevel(POSITION_TYPE_SELL, nextSellLevelUp, g_adaptiveGap) || 
          HasOrderNearLevel(POSITION_TYPE_SELL, nextSellLevelUp, g_adaptiveGap, 1)) && 
         nextSellLevelUp < 10000) {
      nextSellLevelUp += 2; // SELL levels are odd, increment by 2
   }
   double nextSellPriceUp = LevelPrice(nextSellLevelUp, g_adaptiveGap) - (spread / 2.0);
   
   // Find next available SELL level downward
   int nextSellLevelDown = PriceLevelIndex(nowBid, g_adaptiveGap);
   if(!IsOdd(nextSellLevelDown)) nextSellLevelDown--;
   // Skip levels that already have orders (check both exact level and nearby)
   while((HasOrderOnLevel(POSITION_TYPE_SELL, nextSellLevelDown, g_adaptiveGap) || 
          HasOrderNearLevel(POSITION_TYPE_SELL, nextSellLevelDown, g_adaptiveGap, 1)) && 
         nextSellLevelDown > -10000) {
      nextSellLevelDown -= 2; // SELL levels are odd, decrement by 2
   }
   double nextSellPriceDown = LevelPrice(nextSellLevelDown, g_adaptiveGap) - (spread / 2.0);
   
   // Create/Update BUY level line (upward) - Light Blue
   string buyLineNameUp = "NextBuyLevelUp";
   if(ObjectFind(0, buyLineNameUp) < 0) {
      ObjectCreate(0, buyLineNameUp, OBJ_HLINE, 0, 0, nextBuyPriceUp);
      ObjectSetInteger(0, buyLineNameUp, OBJPROP_COLOR, clrLightBlue);
      ObjectSetInteger(0, buyLineNameUp, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, buyLineNameUp, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, buyLineNameUp, OBJPROP_BACK, true);
      ObjectSetInteger(0, buyLineNameUp, OBJPROP_SELECTABLE, false);
   }
   ObjectSetDouble(0, buyLineNameUp, OBJPROP_PRICE, nextBuyPriceUp);
   ObjectSetString(0, buyLineNameUp, OBJPROP_TEXT, StringFormat("Next BUY ↑ L%d @ %.5f (Gap:%.1f)", nextBuyLevelUp, nextBuyPriceUp, g_adaptiveGap/_Point));
   
   // Create/Update BUY level line (downward) - Light Blue
   string buyLineNameDown = "NextBuyLevelDown";
   if(ObjectFind(0, buyLineNameDown) < 0) {
      ObjectCreate(0, buyLineNameDown, OBJ_HLINE, 0, 0, nextBuyPriceDown);
      ObjectSetInteger(0, buyLineNameDown, OBJPROP_COLOR, clrLightBlue);
      ObjectSetInteger(0, buyLineNameDown, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, buyLineNameDown, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, buyLineNameDown, OBJPROP_BACK, true);
      ObjectSetInteger(0, buyLineNameDown, OBJPROP_SELECTABLE, false);
   }
   ObjectSetDouble(0, buyLineNameDown, OBJPROP_PRICE, nextBuyPriceDown);
   ObjectSetString(0, buyLineNameDown, OBJPROP_TEXT, StringFormat("Next BUY ↓ L%d @ %.5f (Gap:%.1f)", nextBuyLevelDown, nextBuyPriceDown, g_adaptiveGap/_Point));
   
   // Create/Update SELL level line (upward) - Pink
   string sellLineNameUp = "NextSellLevelUp";
   if(ObjectFind(0, sellLineNameUp) < 0) {
      ObjectCreate(0, sellLineNameUp, OBJ_HLINE, 0, 0, nextSellPriceUp);
      ObjectSetInteger(0, sellLineNameUp, OBJPROP_COLOR, clrPink);
      ObjectSetInteger(0, sellLineNameUp, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, sellLineNameUp, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, sellLineNameUp, OBJPROP_BACK, true);
      ObjectSetInteger(0, sellLineNameUp, OBJPROP_SELECTABLE, false);
   }
   ObjectSetDouble(0, sellLineNameUp, OBJPROP_PRICE, nextSellPriceUp);
   ObjectSetString(0, sellLineNameUp, OBJPROP_TEXT, StringFormat("Next SELL ↑ L%d @ %.5f (Gap:%.1f)", nextSellLevelUp, nextSellPriceUp, g_adaptiveGap/_Point));
   
   // Create/Update SELL level line (downward) - Pink
   string sellLineNameDown = "NextSellLevelDown";
   if(ObjectFind(0, sellLineNameDown) < 0) {
      ObjectCreate(0, sellLineNameDown, OBJ_HLINE, 0, 0, nextSellPriceDown);
      ObjectSetInteger(0, sellLineNameDown, OBJPROP_COLOR, clrPink);
      ObjectSetInteger(0, sellLineNameDown, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, sellLineNameDown, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, sellLineNameDown, OBJPROP_BACK, true);
      ObjectSetInteger(0, sellLineNameDown, OBJPROP_SELECTABLE, false);
   }
   ObjectSetDouble(0, sellLineNameDown, OBJPROP_PRICE, nextSellPriceDown);
   ObjectSetString(0, sellLineNameDown, OBJPROP_TEXT, StringFormat("Next SELL ↓ L%d @ %.5f (Gap:%.1f)", nextSellLevelDown, nextSellPriceDown, g_adaptiveGap/_Point));
}

//============================= CLOSE ALL WRAPPER ==================//
void PerformCloseAll(string reason = "Manual") {
   // Calculate cycle stats before closing (for vline info)
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double cycleProfit = equity - g_lastCloseEquity;
   double openProfit = g_totalProfit;
   double bookedCycle = cycleProfit - openProfit;
   
   Log(1, StringFormat("CLOSE ALL (%s): profit=%.2f (open=%.2f booked=%.2f) | Positions: BUY:%d SELL:%d", 
       reason, cycleProfit, openProfit, bookedCycle, g_buyCount, g_sellCount));
   
   // Close all positions
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
   
   Log(1, StringFormat("%d positions closed", closedCount));
   
   // Draw vertical line with trail & profit info at close
   datetime nowTime = TimeCurrent();
   string vlineName = StringFormat("%s_P%.02f_E%.0f", reason, cycleProfit, equity);
   
   // Delete old object if it exists
   ObjectDelete(0, vlineName);
   
   // Create vertical line
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ObjectCreate(0, vlineName, OBJ_VLINE, 0, nowTime, currentPrice)) {
      // Set color based on profit: yellow for -1 to +1, green for > 1, red for < -1
      color lineColor = (cycleProfit > 1.0) ? clrGreen : (cycleProfit < -1.0) ? clrRed : clrYellow;
      ObjectSetInteger(0, vlineName, OBJPROP_COLOR, lineColor);
      
      // Set line width proportional to profit: base 1, +1 for every 5 profit, max 10
      int lineWidth = 1 + (int)(MathAbs(cycleProfit) / 5.0);
      lineWidth = MathMin(lineWidth, 10);
      lineWidth = MathMax(lineWidth, 1);
      ObjectSetInteger(0, vlineName, OBJPROP_WIDTH, lineWidth);
      
      ObjectSetInteger(0, vlineName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, vlineName, OBJPROP_BACK, true);
      ObjectSetInteger(0, vlineName, OBJPROP_SELECTABLE, false);
      string vlinetext = StringFormat("P:%.2f/%.2f/%.2f(L%.2f)ML%.2f/%.2f L%.2f/%.2f", 
            cycleProfit, g_trailFloor, g_trailPeak, bookedCycle, 
            -g_maxLossCycle, -g_overallMaxLoss, g_maxLotsCycle, g_overallMaxLotSize);
      ObjectSetString(0, vlineName, OBJPROP_TEXT, vlinetext);
      ChartRedraw(0);
      
      Log(1, StringFormat("VLine created: %s (color: %s, width: %d) | Text: %s", 
          vlineName, 
          (cycleProfit > 1.0) ? "GREEN" : (cycleProfit < -1.0) ? "RED" : "YELLOW", 
          lineWidth, vlinetext));
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
   g_lastMaxLossVline = 0.0;
   g_trailActive = false;
   g_trailStart = 0.0;
   g_trailGap = 0.0;
   g_trailPeak = 0.0;
   g_trailFloor = 0.0;
   
   // Apply pending button actions (single-click delayed actions)
   if(g_pendingStopNewOrders) {
      g_stopNewOrders = true;
      g_noWork = false; // Ensure mutual exclusivity
      g_pendingStopNewOrders = false;
      UpdateButtonStates();
      Log(1, "Pending Stop New Orders: ENABLED after close-all");
   }
   if(g_pendingNoWork) {
      g_noWork = true;
      g_stopNewOrders = false; // Ensure mutual exclusivity
      g_pendingNoWork = false;
      UpdateButtonStates();
      Log(1, "Pending No Work Mode: ENABLED after close-all");
   }
   
   Log(1, StringFormat("Cycle RESET: new equity=%.2f | Close count=%d", g_lastCloseEquity, g_closeCount));
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
         Log(2, "TT deactivated: insufficient positions");
         g_trailActive = false;
      }
      return;
   }
   
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double cycleProfit = currentEquity - g_lastCloseEquity;
   
   // Calculate trail start level
   double lossStart = g_maxLossCycle * TrailStartPct;
   double profitStart = g_maxProfitCycle * TrailProfitPct;  // Use adjustable profit percentage
   g_trailStart = MathMax(lossStart, profitStart);
   
   if(g_trailStart > 0) {
      g_trailGap = MathMin(g_trailStart * TrailGapPct, MaxTrailGap);
   }
   
   // Debug: show trail decision values
   Log(3, StringFormat("TT: cycleProfit=%.2f | MaxLoss=%.2f(start=%.2f) MaxProfit=%.2f(start=%.2f) | trailStart=%.2f | active=%d", 
       cycleProfit, -g_maxLossCycle, -lossStart, g_maxProfitCycle, profitStart, g_trailStart, g_trailActive ? 1 : 0));
   
   // Start trailing: should activate when cycle profit > (max profit already reached - some buffer)
   // Or when cycle profit exceeds max loss recovery + buffer
   // Also check: net lots must be at least 2x base lot size to avoid balanced positions
   double minNetLots = BaseLotSize * 2.0;
   bool hasSignificantExposure = MathAbs(g_netLots) >= minNetLots;
   
   if(!g_trailActive && cycleProfit > g_trailStart && g_trailStart > 0) {
      if(!hasSignificantExposure) {
         Log(2, StringFormat("TT BLOCKED: Net lots %.2f < minimum %.2f (too balanced)", MathAbs(g_netLots), minNetLots));
      } else {
         g_trailActive = true;
         g_trailPeak = cycleProfit;
         g_trailFloor = g_trailPeak - g_trailGap;
         double lossStart = g_maxLossCycle * TrailStartPct;
         double profitStart = g_maxProfitCycle * 1.0;
         Log(1, StringFormat("TT START: profit=%.2f start=%.2f gap=%.2f floor=%.2f | NetLots=%.2f | MaxLoss=%.2f LossStart=%.2f MaxProfit=%.2f ProfitStart=%.2f", 
             cycleProfit, g_trailStart, g_trailGap, g_trailFloor, MathAbs(g_netLots), g_maxLossCycle, lossStart, g_maxProfitCycle, profitStart));
      }
   }
   
   // Update trail
   if(g_trailActive) {
      if(cycleProfit > g_trailPeak) {
         g_trailPeak = cycleProfit;
         g_trailFloor = g_trailPeak - g_trailGap;
         Log(2, StringFormat("TT UPDATE: peak=%.2f floor=%.2f", g_trailPeak, g_trailFloor));
      }
      
      // Check for close trigger
      if(cycleProfit <= g_trailFloor) {
         Log(1, StringFormat("Trail CLOSE trigger: profit=%.2f <= floor=%.2f | Peak=%.2f Gap=%.2f", 
             cycleProfit, g_trailFloor, g_trailPeak, g_trailGap));
         
         // Call wrapper function to handle all close-all activities
         PerformCloseAll("TrailClose");
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

//============================= GROUP TRAILING (CLOSE TOGETHER) ====//
// Trail combined profit of farthest losing orders + farthest profitable orders
void UpdateGroupTrailing() {
   if(!EnableSingleTrailing) return;
   if(g_trailActive) return; // Skip when total trailing active
   if(g_noWork) return;
   
   // Check if we have minimum GLO orders required
   if(g_orders_in_loss < MinGLOForGroupTrail) {
      Log(3, StringFormat("GT | Skip: Only %d GLO orders (need %d minimum)", g_orders_in_loss, MinGLOForGroupTrail));
      return;
   }
   
   // Find single worst losing order (either BUY or SELL, whichever has more loss)
   ulong worstLossTicket = 0;
   double worstLoss = 0.0;
   int worstLossType = -1;
   
   // Track ALL profitable orders from any side
   struct ProfitableOrder {
      ulong ticket;
      double profit;
      int type;
      double lots;
   };
   ProfitableOrder profitableOrders[];
   int profitableCount = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
      
      int type = (int)PositionGetInteger(POSITION_TYPE);
      double profit = PositionGetDouble(POSITION_PROFIT);
      double lots = PositionGetDouble(POSITION_VOLUME);
      
      if(profit < 0) {
         // Track single worst losing order
         double absLoss = MathAbs(profit);
         if(absLoss > worstLoss) {
            worstLoss = absLoss;
            worstLossTicket = ticket;
            worstLossType = type;
         }
      } else if(profit > 0) {
         // Store profitable orders based on mode
         // CLOSETOGETHER: any side, CLOSETOGETHER_SAMETYPE: same type only
         bool shouldInclude = (SingleTrailMethod == SINGLE_TRAIL_CLOSETOGETHER) || 
                              (SingleTrailMethod == SINGLE_TRAIL_CLOSETOGETHER_SAMETYPE && type == worstLossType);
         
         if(shouldInclude) {
            ArrayResize(profitableOrders, profitableCount + 1);
            profitableOrders[profitableCount].ticket = ticket;
            profitableOrders[profitableCount].profit = profit;
            profitableOrders[profitableCount].type = type;
            profitableOrders[profitableCount].lots = lots;
            profitableCount++;
         }
      }
   }
   
   // Need at least one losing order and some profitable orders to trail
   if(worstLossTicket == 0 || profitableCount == 0) {
      if(worstLossTicket > 0 && profitableCount == 0 && SingleTrailMethod == SINGLE_TRAIL_CLOSETOGETHER_SAMETYPE) {
         string lossTypeStr = (worstLossType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
         Log(3, StringFormat("GT | Skip: Worst loss is %s but no profitable %s orders found", lossTypeStr, lossTypeStr));
      }
      g_groupTrail.active = false;
      return;
   }
   
   // Get exact loss value
   double totalLoss = 0.0;
   if(PositionSelectByTicket(worstLossTicket)) {
      totalLoss = PositionGetDouble(POSITION_PROFIT); // Negative value
   }
   
   // Sort profitable orders by profit (highest first) to select farthest in profit
   for(int i = 0; i < profitableCount - 1; i++) {
      for(int j = i + 1; j < profitableCount; j++) {
         if(profitableOrders[j].profit > profitableOrders[i].profit) {
            ProfitableOrder temp = profitableOrders[i];
            profitableOrders[i] = profitableOrders[j];
            profitableOrders[j] = temp;
         }
      }
   }
   
   // Select only enough farthest profitable orders to cover losses and make group profitable
   double selectedProfit = 0.0;
   int selectedCount = 0;
   ulong selectedTickets[];
   
   for(int i = 0; i < profitableCount; i++) {
      selectedProfit += profitableOrders[i].profit;
      ArrayResize(selectedTickets, selectedCount + 1);
      selectedTickets[selectedCount] = profitableOrders[i].ticket;
      selectedCount++;
      
      // Stop when we have enough profit to cover losses with some margin
      if(selectedProfit + totalLoss > 0) {
         break;
      }
   }
   
   // Calculate combined profit (selected profitable orders + single worst loss order)
   double combinedProfit = selectedProfit + totalLoss;
   int groupCount = selectedCount + 1; // 1 loss order + selected profitable orders
   
   // Calculate threshold and gap if not active
   if(!g_groupTrail.active) {
      double threshold = CalculateSingleThreshold();
      g_groupTrail.threshold = threshold;
      g_groupTrail.gap = threshold * 0.50; // 50% gap like single trailing
      g_groupTrail.peakProfit = 0.0;
      // Store the worst loss ticket in appropriate field based on type
      if(worstLossType == POSITION_TYPE_BUY) {
         g_groupTrail.farthestBuyTicket = worstLossTicket;
         g_groupTrail.farthestSellTicket = 0;
      } else {
         g_groupTrail.farthestBuyTicket = 0;
         g_groupTrail.farthestSellTicket = worstLossTicket;
      }
   }
   
   // Update peak
   if(combinedProfit > g_groupTrail.peakProfit) {
      g_groupTrail.peakProfit = combinedProfit;
   }
   
   // Check if group should start trailing (with activation buffer)
   string worstLossTypeStr = (worstLossType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
   double activationThreshold = g_groupTrail.threshold * (1.0 + GroupActivationBuffer);
   if(!g_groupTrail.active && combinedProfit >= activationThreshold) {
      g_groupTrail.active = true;
      Log(1, StringFormat("GT ACTIVE | Combined=%.2f Peak=%.2f Threshold=%.2f | Loss: %s #%I64u (%.2f) | Selected %d profitable orders (%.2f profit)",
          combinedProfit, g_groupTrail.peakProfit, activationThreshold, worstLossTypeStr, worstLossTicket, totalLoss, selectedCount, selectedProfit));
   }
   
   // Trail logic
   if(g_groupTrail.active) {
      double dropFromPeak = g_groupTrail.peakProfit - combinedProfit;
      
      // Periodic logging (every 10 ticks)
      if((int)GetTickCount() - g_groupTrail.lastLogTick > 10) {
         Log(2, StringFormat("GT | Combined=%.2f Peak=%.2f Drop=%.2f Gap=%.2f | Group: %d orders (%d profitable, 1 loss %s)",
             combinedProfit, g_groupTrail.peakProfit, dropFromPeak, g_groupTrail.gap, groupCount, selectedCount, worstLossTypeStr));
         g_groupTrail.lastLogTick = (int)GetTickCount();
      }
      
      // Close group if profit drops below trail gap AND combined profit is above minimum
      if(dropFromPeak >= g_groupTrail.gap) {
         // Safety check: don't close if combined profit is below minimum threshold
         if(combinedProfit < MinGroupProfitToClose) {
            Log(2, StringFormat("GT HOLD | Combined=%.2f < MinProfit=%.2f | Drop=%.2f >= Gap=%.2f | Waiting for recovery",
                combinedProfit, MinGroupProfitToClose, dropFromPeak, g_groupTrail.gap));
            // Reset peak to current to give it another chance to recover
            g_groupTrail.peakProfit = combinedProfit;
            return;
         }
         
         Log(1, StringFormat("GT CLOSE | Combined=%.2f Peak=%.2f Drop=%.2f >= Gap=%.2f",
             combinedProfit, g_groupTrail.peakProfit, dropFromPeak, g_groupTrail.gap));
         
         int closedCount = 0;
         double closedProfit = 0.0;
         
         // Close the single worst losing order
         if(PositionSelectByTicket(worstLossTicket)) {
            double lots = PositionGetDouble(POSITION_VOLUME);
            double profit = PositionGetDouble(POSITION_PROFIT);
            if(trade.PositionClose(worstLossTicket)) {
               closedCount++;
               closedProfit += profit;
               Log(1, StringFormat("GT CLOSE #%I64u %s %.2f lots | Loss=%.2f",
                   worstLossTicket, worstLossTypeStr, lots, profit));
            }
         }
         
         // Close selected profitable orders - BUT verify they're still profitable NOW
         int profitOrdersClosed = 0;
         double profitFromOrders = 0.0;
         for(int i = 0; i < selectedCount; i++) {
            if(PositionSelectByTicket(selectedTickets[i])) {
               double lots = PositionGetDouble(POSITION_VOLUME);
               double profit = PositionGetDouble(POSITION_PROFIT);
               int type = (int)PositionGetInteger(POSITION_TYPE);
               string typeStr = (type == POSITION_TYPE_BUY) ? "BUY" : "SELL";
               
               // SAFETY: Only close if still in profit at this moment
               if(profit > 0) {
                  if(trade.PositionClose(selectedTickets[i])) {
                     closedCount++;
                     closedProfit += profit;
                     profitOrdersClosed++;
                     profitFromOrders += profit;
                     Log(1, StringFormat("GT CLOSE #%I64u %s %.2f lots | Profit=%.2f (farthest profit)",
                         selectedTickets[i], typeStr, lots, profit));
                  }
               } else {
                  Log(2, StringFormat("GT SKIP #%I64u %s %.2f lots | Changed to loss=%.2f (was profitable when selected)",
                      selectedTickets[i], typeStr, lots, profit));
               }
            }
         }
         
         // Final safety check: If net result is still loss, log warning
         if(closedProfit < 0) {
            Log(1, StringFormat("GT WARNING | Closed at loss %.2f despite safety checks | Closed: 1 loss + %d profit orders",
                closedProfit, profitOrdersClosed));
         }
         
         Log(1, StringFormat("GT CLOSED %d orders together | Net P/L: %.2f | Remaining orders continue trading",
             closedCount, closedProfit));
         
         // Draw vertical line to mark group trail closure
         datetime nowTime = TimeCurrent();
         string vlineName = StringFormat("GT_close_%d_P%.02f", (int)nowTime, closedProfit);
         
         // Delete old object if it exists
         ObjectDelete(0, vlineName);
         
         // Create vertical line
         double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(ObjectCreate(0, vlineName, OBJ_VLINE, 0, nowTime, currentPrice)) {
            // Set color based on profit: orange for group trails
            color lineColor = (closedProfit > 0.0) ? clrOrange : clrRed;
            ObjectSetInteger(0, vlineName, OBJPROP_COLOR, lineColor);
            
            // Set line width proportional to profit
            int lineWidth = 1 + (int)(MathAbs(closedProfit) / 5.0);
            lineWidth = MathMin(lineWidth, 10);
            lineWidth = MathMax(lineWidth, 1);
            ObjectSetInteger(0, vlineName, OBJPROP_WIDTH, lineWidth);
            
            ObjectSetInteger(0, vlineName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, vlineName, OBJPROP_BACK, true);
            ObjectSetInteger(0, vlineName, OBJPROP_SELECTABLE, false);
            
            // Show group trail details in vline text
            string vlinetext = StringFormat("GT: %d closed | Net P/L: %.2f | %d profit (%.2f) + 1 loss %s (%.2f) | Peak: %.2f Drop: %.2f",
                closedCount, closedProfit, selectedCount, selectedProfit, 
                worstLossTypeStr, totalLoss,
                g_groupTrail.peakProfit, dropFromPeak);
            ObjectSetString(0, vlineName, OBJPROP_TEXT, vlinetext);
            ChartRedraw(0);
            
            Log(1, StringFormat("VLine created: %s (color: %s, width: %d) | Text: %s", 
                vlineName, 
                (closedProfit > 0.0) ? "ORANGE" : "RED", 
                lineWidth, vlinetext));
         }
         
         // Reset group trail to recalculate with remaining positions
         g_groupTrail.active = false;
         g_groupTrail.peakProfit = 0.0;
         g_groupTrail.farthestBuyTicket = 0;
         g_groupTrail.farthestSellTicket = 0;
      }
   }
}

//============================= SINGLE TRAILING ===================//
void TrailSinglePositions() {
   if(!EnableSingleTrailing) return;
   
   // Dynamic method: choose based on GLO count
   if(SingleTrailMethod == SINGLE_TRAIL_DYNAMIC) {
      if(g_orders_in_loss >= DynamicGLOThreshold) {
         // GLO count is high - use group trailing
         UpdateGroupTrailing();
         return;
      }
      // GLO count is low - continue with normal single trailing below
   }
   
   // Route to appropriate trailing method
   if(SingleTrailMethod == SINGLE_TRAIL_CLOSETOGETHER || 
      SingleTrailMethod == SINGLE_TRAIL_CLOSETOGETHER_SAMETYPE) {
      UpdateGroupTrailing();
      return;
   }
   
   // Normal single trailing logic below
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
         Log(2, StringFormat("ST START #%I64u PPL=%.2f | Threshold=%.2f Gap=%.2f ActivateAt=%.2f", 
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
            Log(3, StringFormat("ST TRACK #%I64u peak=%.2f | AwaitingActivation", ticket, peak));
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
            Log(1, StringFormat("ST ACTIVE #%I64u peak=%.2f | Current=%.2f | Ready to Trail", 
                ticket, activePeak, profitPer01));
         }
         
         // Update active peak (trail upward after activation)
         if(active && profitPer01 > activePeak) {
            g_trails[idx].activePeak = profitPer01;
            activePeak = profitPer01;
            Log(2, StringFormat("ST PEAK UPDATE #%I64u peak=%.2f", ticket, activePeak));
         }
         
         // Show continuous trail status when active (throttle to avoid spam - every 500ms)
         if(active) {
            double trailFloorValue = activePeak - gap;
            if(currentTick - g_trails[idx].lastLogTick >= 500) {  // Log every 500ms
               Log(3, StringFormat("ST STATUS #%I64u | Peak=%.2f Current=%.2f Floor=%.2f Drop=%.2f", 
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
               
               Log(1, StringFormat("ST CLOSE #%I64u %s %.2f lots | Profit=%.2f | Trail Stats: Peak=%.2f Current=%.2f Drop=%.2f TrailMin=%.2f", 
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
         Log(2, StringFormat("ST CLEANUP #%I64u (position closed)", g_trails[j].ticket));
         RemoveTrail(j);
      }
   }
}

//============================= CHART EVENT HANDLER ================//
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
   if(id == CHARTEVENT_OBJECT_CLICK) {
      // Button 1: Stop New Orders (double-click: immediate, single-click: after next close-all)
      if(sparam == "BtnStopNewOrders") {
         datetime currentTime = TimeCurrent();
         
         // Check if this is a double-click (within 2 seconds of first click)
         if(g_stopNewOrdersClickTime > 0 && (currentTime - g_stopNewOrdersClickTime) <= 2) {
            // Double-click confirmed - apply immediately
            g_stopNewOrders = !g_stopNewOrders;
            g_pendingStopNewOrders = false; // Cancel any pending action
            
            // If activating Stop New Orders, deactivate No Work
            if(g_stopNewOrders && g_noWork) {
               g_noWork = false;
               g_pendingNoWork = false;
            }
            
            g_stopNewOrdersClickTime = 0; // Reset click timer
            UpdateButtonStates();
            Log(1, StringFormat("Stop New Orders (IMMEDIATE): %s", g_stopNewOrders ? "ENABLED" : "DISABLED"));
         } else {
            // First click - schedule for next close-all
            g_stopNewOrdersClickTime = currentTime;
            g_pendingStopNewOrders = !g_stopNewOrders; // Toggle state
            if(g_pendingStopNewOrders) {
               g_pendingNoWork = false; // Cancel conflicting pending action
            }
            Log(1, StringFormat("Stop New Orders: Will %s after next Close-All (click again for immediate)", 
                g_pendingStopNewOrders ? "ENABLE" : "DISABLE"));
         }
      }
      
      // Button 2: No Work Mode (double-click: immediate, single-click: after next close-all)
      if(sparam == "BtnNoWork") {
         datetime currentTime = TimeCurrent();
         
         // Check if this is a double-click (within 2 seconds of first click)
         if(g_noWorkClickTime > 0 && (currentTime - g_noWorkClickTime) <= 2) {
            // Double-click confirmed - apply immediately
            g_noWork = !g_noWork;
            g_pendingNoWork = false; // Cancel any pending action
            
            // If activating No Work, deactivate Stop New Orders
            if(g_noWork && g_stopNewOrders) {
               g_stopNewOrders = false;
               g_pendingStopNewOrders = false;
            }
            
            g_noWorkClickTime = 0; // Reset click timer
            UpdateButtonStates();
            Log(1, StringFormat("No Work Mode (IMMEDIATE): %s", g_noWork ? "ENABLED" : "DISABLED"));
         } else {
            // First click - schedule for next close-all
            g_noWorkClickTime = currentTime;
            g_pendingNoWork = !g_noWork; // Toggle state
            if(g_pendingNoWork) {
               g_pendingStopNewOrders = false; // Cancel conflicting pending action
            }
            Log(1, StringFormat("No Work Mode: Will %s after next Close-All (click again for immediate)", 
                g_pendingNoWork ? "ENABLE" : "DISABLE"));
         }
      }
      
      // Button 3: Close All (double-click protection)
      if(sparam == "BtnCloseAll") {
         datetime currentTime = TimeCurrent();
         
         // Check if this is a double-click (within 2 seconds of first click)
         if(g_closeAllClickTime > 0 && (currentTime - g_closeAllClickTime) <= 2) {
            // Double-click confirmed - call wrapper function to handle all close-all activities
            PerformCloseAll("ButtonClick");
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
            ObjectDelete(0, "Last5DaysSymbolLabel");
            ObjectDelete(0, "Last5DaysOverallLabel");
            ObjectDelete(0, "CenterProfitLabel");
            ObjectDelete(0, "CurrentProfitVLine");
         }
         
         UpdateButtonStates();
         Log(1, StringFormat("Labels Display: %s", g_showLabels ? "ENABLED" : "DISABLED"));
      }
      
      // Button 5: Toggle Next Level Lines
      if(sparam == "BtnToggleNextLines") {
         g_showNextLevelLines = !g_showNextLevelLines;
         
         if(!g_showNextLevelLines) {
            // Lines will be deleted in UpdateNextLevelLines() on next call
            Log(1, "Next Level Lines: DISABLED (calculations stopped)");
         } else {
            Log(1, "Next Level Lines: ENABLED (will show next available order levels)");
         }
         
         UpdateButtonStates();
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
   ArrayInitialize(g_historySymbolDaily, 0.0);
   ArrayInitialize(g_historyOverallDaily, 0.0);
   g_closeCount = 0;
   g_lastDay = -1;
   g_dayIndex = 0;
   
   // Calculate history-based daily profits
   CalculateHistoryDailyProfits();
   
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
   
   // Update next level lines
   UpdateNextLevelLines();
   
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
      
      // Recalculate history-based daily profits
      CalculateHistoryDailyProfits();
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
      
      // Calculate offset based on current timeframe and candles
      int periodSeconds = PeriodSeconds();
      datetime vlineTime = nowTime + (VlineOffsetCandles * periodSeconds);
      
      string vlineName = "CurrentProfitVLine";
      
      // Delete old and create new
      ObjectDelete(0, vlineName);
      
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(ObjectCreate(0, vlineName, OBJ_VLINE, 0, vlineTime, currentPrice)) {
         // Color based on trail state and profit
         color lineColor;
         if(g_trailActive) {
            lineColor = clrBlue; // Blue when trailing is active
         } else {
            lineColor = (cycleProfit > 1.0) ? clrGreen : (cycleProfit < -1.0) ? clrRed : clrYellow;
         }
         ObjectSetInteger(0, vlineName, OBJPROP_COLOR, lineColor);
         
         // Width proportional to profit
         int lineWidth = 1 + (int)(MathAbs(cycleProfit) / 5.0);
         lineWidth = MathMin(lineWidth, 10);
         lineWidth = MathMax(lineWidth, 1);
         ObjectSetInteger(0, vlineName, OBJPROP_WIDTH, lineWidth);
         
         ObjectSetInteger(0, vlineName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, vlineName, OBJPROP_BACK, true);
         ObjectSetInteger(0, vlineName, OBJPROP_SELECTABLE, false);
         
         // Calculate trailing start threshold
         double lossStart = g_maxLossCycle * TrailStartPct;
         double profitStart = g_maxProfitCycle * TrailProfitPct;
         double trailStart = MathMax(lossStart, profitStart);
         
         int totalCount = g_buyCount + g_sellCount;
         double totalLots = g_buyLots + g_sellLots;
         string vlinetext = StringFormat("P:%.2f/%.2f/%.2f/%.2f(L%.2f)ML%.2f/%.2f L%.2f/%.2f N:%d/%.2f/%.2f", 
               cycleProfit, trailStart, g_trailFloor, g_trailPeak, bookedCycle, -g_maxLossCycle, -g_overallMaxLoss, 
               g_maxLotsCycle, g_overallMaxLotSize, totalCount, g_netLots, totalLots);
         ObjectSetString(0, vlineName, OBJPROP_TEXT, vlinetext);
      }
   } else {
      // Remove vline if no positions
      ObjectDelete(0, "CurrentProfitVLine");
   }
   
   // Label 1: Current Profit Label (always show)
   color lineColor = (cycleProfit > 1.0) ? clrGreen : (cycleProfit < -1.0) ? clrRed : clrYellow;
   string modeIndicator = "";
   if(g_noWork) modeIndicator = " [NO WORK]";
   else if(g_stopNewOrders) modeIndicator = " [MANAGE ONLY]";
   
   // Calculate trailing start threshold
   double lossStart = g_maxLossCycle * TrailStartPct;
   double profitStart = g_maxProfitCycle * TrailProfitPct;
   double trailStart = MathMax(lossStart, profitStart);
   
   string vlinetext = StringFormat("P:%.0f/%.0f/%.0f/%.0f(E%.0f)ML%.0f/%.0f L%.2f/%.2f glo %d/%d%s", 
         cycleProfit, trailStart, g_trailFloor, g_trailPeak, bookedCycle, -g_maxLossCycle, -g_overallMaxLoss, 
         g_maxLotsCycle, g_overallMaxLotSize, g_orders_in_loss, g_maxGLOOverall, modeIndicator);
   UpdateOrCreateLabel("CurrentProfitLabel", 10, 30, vlinetext, lineColor, 12, "Arial Bold");
   
   // Label 2: Position Details (always show)
   int totalCount = g_buyCount + g_sellCount;
   double totalLots = g_buyLots + g_sellLots;
   string label2text = StringFormat("N:%d/%.2f/%.0f B:%d/%.2f/%.0f S:%d/%.2f/%.0f NB%.2f/NS%.2f",
         totalCount, g_netLots, totalLots,
         g_buyCount, g_buyLots, g_buyProfit,
         g_sellCount, g_sellLots, g_sellProfit,
         g_nextBuyLot, g_nextSellLot);
   color label2Color = (g_totalProfit >= 0) ? clrLime : clrOrange;
   UpdateOrCreateLabel("PositionDetailsLabel", 10, 50, label2text, label2Color, 10, "Arial Bold");
   
   // Label 3: Spread & Equity (always show)
   double currentSpread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   double inputGapPoints = GapInPoints;
   double effectiveGapPoints = g_adaptiveGap / _Point;
   string label3text = StringFormat("SPR:%.1f/%.1f |Gp:%.0f/%.0f |Eq:%.0f |PR:%.2f/%.2f", 
         currentSpread/_Point, g_maxSpread/_Point, inputGapPoints, effectiveGapPoints, equity,cycleProfit, overallProfit);
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
   
   // Label 5: Last 5 Days Symbol-Specific (from history)
   string label5text = "Last5D Symbol: ";
   for(int i = 0; i < 5; i++) {
      label5text += StringFormat("%.2f", g_historySymbolDaily[i]);
      if(i < 4) label5text += " | ";
   }
   UpdateOrCreateLabel("Last5DaysSymbolLabel", 10, 108, label5text, clrCyan, 9, "Arial");
   
   // Label 6: Last 5 Days Overall (from history)
   string label6text = "Last5D Overall: ";
   for(int i = 0; i < 5; i++) {
      label6text += StringFormat("%.2f", g_historyOverallDaily[i]);
      if(i < 4) label6text += " | ";
   }
   UpdateOrCreateLabel("Last5DaysOverallLabel", 10, 126, label6text, clrYellow, 9, "Arial");
   
   // Label 7: Center Label - Overall Profit & Net Lots
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
   
   // Label 8: Center Label Line 2 - Cycle Profit & Booked Profit
   // bookedCycle is already calculated earlier in this function
   
   // Create cycle/booked label split into two parts for different colors
   string centerName2Cycle = "CenterCycleLabel";
   string centerName2Booked = "CenterBookedLabel";
   int centerY2 = centerY + 45; // Position below main center label
   
   // Calculate text widths for positioning (approximate)
   string cycleText = StringFormat("%.0f", cycleProfit);
   string bookedText = StringFormat("%.0f", bookedCycle);
   int cycleWidth = StringLen(cycleText) * 12; // Approximate pixel width per character
   int bookedWidth = StringLen(bookedText) * 12;
   int totalWidth = cycleWidth + bookedWidth + 20; // 20 for space between
   
   color cycleColor = (cycleProfit >= 0) ? clrLime : clrRed;
   color bookedColor = (bookedCycle >= 0) ? clrLime : clrRed;
   
   // Create/update cycle profit label (left part)
   if(ObjectFind(0, centerName2Cycle) < 0) {
      ObjectCreate(0, centerName2Cycle, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, centerName2Cycle, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, centerName2Cycle, OBJPROP_ANCHOR, ANCHOR_RIGHT);
      ObjectSetInteger(0, centerName2Cycle, OBJPROP_FONTSIZE, 24);
      ObjectSetString(0, centerName2Cycle, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, centerName2Cycle, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, centerName2Cycle, OBJPROP_HIDDEN, false);
      ObjectSetInteger(0, centerName2Cycle, OBJPROP_BACK, false);
      ObjectSetInteger(0, centerName2Cycle, OBJPROP_ZORDER, 0);
   }
   ObjectSetInteger(0, centerName2Cycle, OBJPROP_XDISTANCE, centerX - 10);
   ObjectSetInteger(0, centerName2Cycle, OBJPROP_YDISTANCE, centerY2);
   ObjectSetString(0, centerName2Cycle, OBJPROP_TEXT, cycleText);
   ObjectSetInteger(0, centerName2Cycle, OBJPROP_COLOR, cycleColor);
   
   // Create/update booked profit label (right part)
   if(ObjectFind(0, centerName2Booked) < 0) {
      ObjectCreate(0, centerName2Booked, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, centerName2Booked, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, centerName2Booked, OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetInteger(0, centerName2Booked, OBJPROP_FONTSIZE, 24);
      ObjectSetString(0, centerName2Booked, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, centerName2Booked, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, centerName2Booked, OBJPROP_HIDDEN, false);
      ObjectSetInteger(0, centerName2Booked, OBJPROP_BACK, false);
      ObjectSetInteger(0, centerName2Booked, OBJPROP_ZORDER, 0);
   }
   ObjectSetInteger(0, centerName2Booked, OBJPROP_XDISTANCE, centerX + 10);
   ObjectSetInteger(0, centerName2Booked, OBJPROP_YDISTANCE, centerY2);
   ObjectSetString(0, centerName2Booked, OBJPROP_TEXT, bookedText);
   ObjectSetInteger(0, centerName2Booked, OBJPROP_COLOR, bookedColor);
   
   ChartRedraw(0);
}
void OnDeinit(const int reason) {
   // Clean up buttons and labels
   ObjectDelete(0, "BtnStopNewOrders");
   ObjectDelete(0, "BtnNoWork");
   ObjectDelete(0, "BtnCloseAll");
   ObjectDelete(0, "BtnToggleLabels");
   ObjectDelete(0, "BtnToggleNextLines");
   ObjectDelete(0, "CenterProfitLabel");
   ObjectDelete(0, "CenterCycleLabel");
   ObjectDelete(0, "CenterBookedLabel");
   ObjectDelete(0, "NextBuyLevelUp");
   ObjectDelete(0, "NextBuyLevelDown");
   ObjectDelete(0, "NextSellLevelUp");
   ObjectDelete(0, "NextSellLevelDown");
   
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
   
   // Label 5: Last 5 Days Symbol-Specific (from history)
   string stats5 = "Last5D Symbol: ";
   for(int i = 0; i < 5; i++) {
      stats5 += StringFormat("%.2f", g_historySymbolDaily[i]);
      if(i < 4) stats5 += " | ";
   }
   
   // Label 6: Last 5 Days Overall (from history)
   string stats6 = "Last5D Overall: ";
   for(int i = 0; i < 5; i++) {
      stats6 += StringFormat("%.2f", g_historyOverallDaily[i]);
      if(i < 4) stats6 += " | ";
   }
   
   // Print all stats
   Print("========== FINAL STATISTICS ==========");
   Print(stats1);
   Print(stats2);
   Print(stats3);
   Print(stats4);
   Print(stats5);
   Print(stats6);
   Print("======================================");
}
