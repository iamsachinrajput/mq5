//+------------------------------------------------------------------+
//| GlobalsAndInputs.mqh                                             |
//| All inputs, enums, globals, structs for xau_ea4_multifile       |
//+------------------------------------------------------------------+
#property strict

//============================= INPUTS =============================//

//==================== CORE SETTINGS ====================//
input group "═══════════════ CORE SETTINGS ═══════════════"
input int    Magic = 12345;               // Magic number
input double GapInPoints = 300;         // Gap xau100 btc1000
input double BaseLotSize = 0.01;          // Starting lot size
input int    DebugLevel = 1;              // Debug level (0=off, 1=critical, 2=info, 3=verbose)

//==================== LOT SIZE MANAGEMENT ====================//
input group "═══════════════ LOT SIZE MANAGEMENT ═══════════════"
// Lot Calculation Methods (applied per scenario)
enum ENUM_LOT_CALC_METHOD {
   LOT_CALC_BASE = 0,           // Base lot size only
   LOT_CALC_GLO = 1,            // Base * GLO (orders in loss)
   LOT_CALC_GPO = 2,            // Base * GPO (orders in profit)
   LOT_CALC_GLO_GPO_DIFF = 3,   // Base * abs(GLO - GPO)
   LOT_CALC_TOTAL_ORDERS = 4,   // Base * total order count
   LOT_CALC_BUY_SELL_DIFF = 5,  // Base * abs(buy count - sell count)
   LOT_CALC_IGNORE = 99         // Ignore this case (do not apply)
};

// Scenario-Based Lot Sizing
input string LotCalc_PrioritySequence = "1,2,3,4,5,6,7";              // Priority sequence for overlapping scenarios (comma-separated: 1-7)
input ENUM_LOT_CALC_METHOD LotCalc_Boundary = LOT_CALC_TOTAL_ORDERS;          // Case 1: Boundary orders (topmost BUY, bottommost SELL)
input ENUM_LOT_CALC_METHOD LotCalc_Direction = LOT_CALC_GLO_GPO_DIFF;          // Case 2: Direction orders (towards movement, opposite to accumulation)
input ENUM_LOT_CALC_METHOD LotCalc_Counter = LOT_CALC_GPO;           // Case 3: Counter-direction orders (against movement)
input ENUM_LOT_CALC_METHOD LotCalc_GPO_More = LOT_CALC_IGNORE;          // Case 4: When GPO > GLO (more profit than loss)
input ENUM_LOT_CALC_METHOD LotCalc_GLO_More = LOT_CALC_IGNORE;           // Case 5: When GLO > GPO (more loss than profit)
input ENUM_LOT_CALC_METHOD LotCalc_Centered = LOT_CALC_GLO;          // Case 6: Centered position (balanced buy/sell distribution)
input ENUM_LOT_CALC_METHOD LotCalc_Sided = LOT_CALC_IGNORE;              // Case 7: Sided position (unbalanced distribution)
input int CenteredThreshold = 2;  // Max buy/sell count difference to consider centered (Case 6 vs Case 7)

//==================== ORDER PLACEMENT ====================//
input group "═══════════════ ORDER PLACEMENT ═══════════════"
enum ENUM_ORDER_STRATEGY {
   ORDER_STRATEGY_NONE = 0,                // No checks - always allow orders
   ORDER_STRATEGY_BOUNDARY_DIRECTIONAL = 1, // Wait for direction change - BUY needs N SELLs below, SELL needs N BUYs above
   ORDER_STRATEGY_FAR_ADJACENT = 2         // Flexible adjacent check (Distance=start point, Depth=how many levels)
};
input ENUM_ORDER_STRATEGY OrderPlacementStrategy = ORDER_STRATEGY_FAR_ADJACENT; // Order placement strategy
input int BoundaryDirectionalCount = 5;  // Number of opposite orders required for BOUNDARY_DIRECTIONAL (waiting for direction change)
input int FarAdjacentDistance = 3;       // Starting distance for FAR_ADJACENT (1=adjacent, 3=skip 1 level, 5=skip 2 levels)
input int FarAdjacentDepth = 5;          // Number of opposite-type levels to check from starting distance (1=strict, higher=flexible)

// Boundary Order Placement Strategy (topmost BUY, bottommost SELL)
enum ENUM_BOUNDARY_STRATEGY {
   BOUNDARY_STRATEGY_ALWAYS = 0,           // Always allow boundary orders
   BOUNDARY_STRATEGY_TRAIL_LAST = 1,       // Only when last same-type boundary order is in trail
   BOUNDARY_STRATEGY_ORDER_COUNT = 2,      // Only when total orders count < helper threshold
   BOUNDARY_STRATEGY_NO_TOTAL_TRAIL = 3,   // Only when total trail is not active
   BOUNDARY_STRATEGY_GLO_MORE = 4          // Only when GLO > GPO
};
input ENUM_BOUNDARY_STRATEGY BoundaryOrderStrategy = BOUNDARY_STRATEGY_ALWAYS; // Strategy for boundary orders (topmost BUY, bottommost SELL)
input int BoundaryStrategyHelper = 10;   // Helper value for boundary strategies (e.g., max order count for strategy 2)

enum ENUM_ORDER_PLACEMENT_TYPE {
   ORDER_PLACEMENT_NORMAL = 0,    // Normal - only place orders when price crosses
   ORDER_PLACEMENT_FLEXIBLE = 1   // Flexible - also fill missed adjacent level orders
};
input ENUM_ORDER_PLACEMENT_TYPE OrderPlacementType = ORDER_PLACEMENT_NORMAL; // Order placement type
input int OrderPlacementDelayMs = 0;  // Delay between orders in milliseconds (0 = no delay)

enum ENUM_NO_POSITIONS_ACTION {
   NO_POS_NONE = 0,           // None - no intervention
   NO_POS_NEAREST_LEVEL = 1,  // Open single order at nearest level
   NO_POS_BOTH_LEVELS = 2     // Open both BUY and SELL at nearest levels
};
input ENUM_NO_POSITIONS_ACTION NoPositionsAction = NO_POS_NEAREST_LEVEL; // Action when no open positions

//==================== SINGLE TRAIL CLOSING ====================//
input group "═══════════════ SINGLE TRAIL CLOSING ═══════════════"
bool   EnableSingleTrailing = true; // Enable single position trailing

// Single Trail Activation Method (when to start trailing individual orders)
enum ENUM_SINGLE_TRAIL_ACTIVATION {
   SINGLE_ACTIVATION_IGNORE = 0,      // Ignore - no single trail
   SINGLE_ACTIVATION_PROFIT = 1,      // Profit Based - trail when profit per 0.01 lot reaches threshold
   SINGLE_ACTIVATION_LEVEL = 2        // Level Based - trail when order is N levels in profit
};
input ENUM_SINGLE_TRAIL_ACTIVATION SingleTrailActivation = SINGLE_ACTIVATION_PROFIT; // When to start single trail
input double SingleActivationValue = -1; // Activation helper: profit per 0.01 lot OR level count (negative = auto-calc from gap for profit)

// Single Trail Gap Method (how much to trail)
enum ENUM_SINGLE_TRAIL_GAP {
   SINGLE_GAP_FIXED = 0,           // Fixed - use helper value as points
   SINGLE_GAP_PERCENTAGE = 1,      // Percentage - use helper value as % of threshold (e.g., 50 = 50% of activation threshold)
   SINGLE_GAP_DYNAMIC = 2          // Dynamic - calculate based on order profit and lot size
};
input ENUM_SINGLE_TRAIL_GAP SingleTrailGapMethod = SINGLE_GAP_PERCENTAGE; // Trail gap calculation method
input double SingleTrailGapValue = 50.0; // Gap helper: points, percentage, or multiplier depending on method

//==================== GROUP TRAIL CLOSING ====================//
input group "═══════════════ GROUP TRAIL CLOSING ═══════════════"
enum ENUM_GROUP_TRAIL_METHOD {
   GROUP_TRAIL_IGNORE = 0,            // Ignore - no group trail
   GROUP_TRAIL_CLOSETOGETHER = 1,     // Close Together - trail worst loss with profitable orders (any side)
   GROUP_TRAIL_CLOSETOGETHER_SAMETYPE = 2, // Close Together Same Type - trail worst loss with profitable orders (same side only)
   GROUP_TRAIL_DYNAMIC = 3,           // Dynamic - switch between single and group trail based on GLO count (uses any side mode when group trailing)
   GROUP_TRAIL_DYNAMIC_SAMETYPE = 4,  // Dynamic Same Type - switch based on GLO, use same-side mode when group trailing
   GROUP_TRAIL_DYNAMIC_ANYSIDE = 5,   // Dynamic Any Side - switch based on GLO, use any-side mode when group trailing
   GROUP_TRAIL_HYBRID_BALANCED = 6,   // Hybrid Balanced - switches based on net exposure imbalance
   GROUP_TRAIL_HYBRID_ADAPTIVE = 7,   // Hybrid Adaptive - switches based on GLO ratio and profit state
   GROUP_TRAIL_HYBRID_SMART = 8,      // Hybrid Smart - uses multiple factors (net exposure, GLO ratio, cycle profit)
   GROUP_TRAIL_HYBRID_COUNT_DIFF = 9  // Hybrid Count Diff - switches based on buy/sell order count difference
};
input ENUM_GROUP_TRAIL_METHOD GroupTrailMethod = GROUP_TRAIL_IGNORE; // Group trail closing method
input int MinGLOForGroupTrail = 10; // Minimum GLO orders to activate group trailing
input int DynamicGLOThreshold = 5; // GLO threshold for dynamic method (< threshold = single trail, >= threshold = group trail)
input double MinGroupProfitToClose = 0.0; // Minimum combined profit to close group (prevents closing at loss)
input double GroupActivationBuffer = 0.5; // Extra profit above threshold to activate (0.5 = 50% of threshold)

// Hybrid Trail Parameters
input double HybridNetLotsThreshold = 3.0;  // Net lots threshold to switch to group close (for HYBRID_BALANCED)
input double HybridGLOPercentage = 0.4;     // GLO ratio threshold to switch (0.4 = 40% of orders in loss)
input double HybridBalanceFactor = 2.0;     // Imbalance factor for smart switching (buyLots/sellLots or vice versa)
input int    HybridCountDiffThreshold = 5;  // Order count difference threshold (for HYBRID_COUNT_DIFF)

//==================== TOTAL TRAIL CLOSING ====================//
input group "═══════════════ TOTAL TRAIL CLOSING ═══════════════"
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

enum ENUM_TRAIL_LOT_MODE {
   TRAIL_LOT_BASE = 0,              // Base lot size only
   TRAIL_LOT_GLO = 1,               // Base lot size * GLO count
   TRAIL_LOT_GPO = 2,               // Base lot size * GPO count
   TRAIL_LOT_DIFF = 3,              // Base lot size * abs(GPO - GLO)
   TRAIL_LOT_TOTAL = 4              // Base lot size * total order count
};
input ENUM_TRAIL_LOT_MODE TrailLotMode = TRAIL_LOT_BASE;  // Lot size calculation during total trailing

//==================== RISK MANAGEMENT ====================//
input group "═══════════════ RISK MANAGEMENT ═══════════════"
input int    MaxPositions = 9999999;         // Maximum open positions
input double MaxTotalLots = 9999999;        // Maximum total lot exposure
input double MaxLossLimit = 9999999;       // Maximum loss limit
input double DailyProfitTarget = 9999999;  // Daily profit target to stop trading

//==================== ADAPTIVE GAP ====================//
input group "═══════════════ ADAPTIVE GAP ═══════════════"
input bool   UseAdaptiveGap = false;       // Use ATR-based adaptive gap
int    ATRPeriod = 14;              // ATR period for adaptive gap
double ATRMultiplier = 1.5;         // ATR multiplier
double MinGapPoints = GapInPoints/2;         // Minimum gap points
double MaxGapPoints = GapInPoints*1.10;        // Maximum gap points

//==================== DISPLAY SETTINGS ====================//
input group "═══════════════ DISPLAY SETTINGS ═══════════════"
input bool   ShowLabels = true;         // Show chart labels (disable for performance)
input bool   ShowOrderLabels = false;   // Show order open/close labels on chart
input bool   ShowNextLevelLines = false; // Show next level lines on chart
input color  LevelLineColor = clrWhite; // Color for level lines
input int    LevelLabelFontSize = 8;    // Font size for level line labels
input double MaxLossVlineThreshold = 100.0;  // Min loss to show max loss vline (0 = always show)
input int    VlineOffsetCandles = 2;   // Current profit vline offset in candles from current time
input int    CenterPanelFontSize = 36;   // Font size for main center label (Overall Profit & Net Lots)
input int    CenterPanel2FontSize = 24;  // Font size for second center label (Cycle & Booked Profit)

//==================== BUTTON POSITIONING ====================//
input group "═══════════════ BUTTON POSITIONING ═══════════════"
input int    BtnXDistance = 200;         // Button X distance from right edge
input int    BtnYDistance = 60;         // Button Y distance from top edge

//==================== CONTROL PANEL POSITIONING ====================//
input group "═══════════════ CONTROL PANEL POSITIONING ═══════════════"
// Control Buttons (Show/Hide) Positioning
enum ENUM_CTRL_CORNER {
   CTRL_CORNER_RIGHT_LOWER = 0,  // Right Lower
   CTRL_CORNER_RIGHT_UPPER = 1,  // Right Upper
   CTRL_CORNER_LEFT_LOWER = 2,   // Left Lower
   CTRL_CORNER_LEFT_UPPER = 3    // Left Upper
};
input ENUM_CTRL_CORNER CtrlButtonCorner = CTRL_CORNER_RIGHT_UPPER; // Control buttons corner position
input int    CtrlBtnXDistance = 200;      // Control buttons X distance from edge
input int    CtrlBtnYDistance = 20;      // Control buttons Y distance from edge

// Selection Panel Positioning (exact position like control buttons)
input ENUM_CTRL_CORNER CtrlPanelCorner = CTRL_CORNER_RIGHT_UPPER; // Panel corner position
input int    CtrlPanelXDistance = 200;   // Panel X distance from edge
input int    CtrlPanelYDistance = 10;    // Panel Y distance from edge

//==================== INITIAL STATES ====================//
input group "═══════════════ INITIAL STATES ═══════════════"
input bool   InitialStopNewOrders = false; // Initial state for Stop New Orders button
input bool   InitialNoWork = false;        // Initial state for No Work button
input int    InitialSingleTrailMode = 2;   // Initial Single Trail Mode (0=Tight, 1=Normal, 2=Loose)
input int    InitialTotalTrailMode = 1;    // Initial Total Trail Mode (0=Tight, 1=Normal, 2=Loose)
input bool   InitialShowButtons = false;   // Initial state for main buttons visibility (false = hidden at start)
input bool   InitialShowLevelLines = false; // Initial state for level lines display (false = hidden at start)

//==================== LOGGING & TRACKING ====================//
input group "═══════════════ LOGGING & TRACKING ═══════════════"
input bool   EnableTradeLogging = false;  // Enable trade activity logging to CSV file
input double StartingEquityInput = 0.0; // Starting equity (0 = use current equity at init)
input double LastCloseEquityInput = 0.0; // Last close equity (0 = use current equity at init)

//============================= GLOBALS ============================//
CTrade trade;

// Price & Grid
double g_originPrice = 0.0;
double g_adaptiveGap = 0.0;

// Lot Calculation Priority Sequence
int g_lotCalcPriority[7];        // Parsed priority sequence from input (1-7)

// Position Stats
int    g_buyCount = 0;
int    g_sellCount = 0;
double g_buyLots = 0.0;
double g_sellLots = 0.0;
double g_netLots = 0.0;
double g_totalProfit = 0.0;
double g_nextBuyLot = 0.01;
double g_nextSellLot = 0.01;
int    g_nextBuyScenario = 0;       // Store current buy scenario index
int    g_nextSellScenario = 0;      // Store current sell scenario index
string g_nextBuyMethod = "Base";    // Store current buy method name
string g_nextSellMethod = "Base";   // Store current sell method name
string g_nextBuyReason = "";        // Store reason/condition for buy lot calculation
string g_nextSellReason = "";       // Store reason/condition for sell lot calculation
int    g_orders_in_loss = 0;    // Count of orders currently in loss (for GLO method)
int    g_orders_in_profit = 0;  // Count of orders currently in profit (for GPO method)

// Trade Logging State
bool   g_tradeLoggingActive = false;  // Current state of trade logging (can be toggled at runtime)

// Additional position profit tracking
double g_buyProfit = 0.0;
double g_sellProfit = 0.0;

// Risk Status
bool g_tradingAllowed = true;

// Button Control States
bool g_stopNewOrders = false;    // If true: no new orders, only manage existing
bool g_noWork = false;           // If true: no new orders, no closing, only display
datetime g_closeAllClickTime = 0; // Track first click time for double-click protection
datetime g_stopNewOrdersClickTime = 0; // Track first click time for Stop New Orders
datetime g_noWorkClickTime = 0;   // Track first click time for No Work
datetime g_resetCountersClickTime = 0; // Track first click time for Reset Counters (triple-click)
int g_resetCountersClickCount = 0; // Count clicks for Reset Counters button
bool g_pendingStopNewOrders = false; // Pending action after next close-all
bool g_pendingNoWork = false;    // Pending action after next close-all
bool g_showLabels = true;        // If true: show all labels, if false: hide for performance
bool g_showNextLevelLines = false; // If true: show and calculate next level lines (toggle via button)
bool g_showLevelLines = false;    // If true: show 5 level lines above and below current price (toggle via button)
bool g_showOrderLabels = false;  // If true: show order open/close labels on chart
int  g_currentDebugLevel = 0;    // Current debug level (modifiable at runtime, initialized from DebugLevel input)
int  g_singleTrailMode = 2;      // Single trail sensitivity: 0=Tight, 1=Normal, 2=Loose
int  g_totalTrailMode = 2;       // Total trail sensitivity: 0=Tight, 1=Normal, 2=Loose
int  g_currentGroupTrailMethod = 0;   // Current group trail method (modifiable at runtime, initialized from GroupTrailMethod input)
int  g_historyDisplayMode = 2;   // History display mode: 0=Overall, 1=CurSymAllMagic, 2=CurSymCurMagic, 3=PerSymbol
string g_activeSelectionPanel = ""; // Track active selection panel (empty = none active)

// Master visibility controls (controlled by bottom-right buttons, never hidden)
bool g_showMainButtons = false;  // Show/hide main control buttons (top-right) - initialized from InitialShowButtons input
bool g_showInfoLabels = true;    // Show/hide info panel labels (left side)
bool g_showOrderLabelsCtrl = true; // Show/hide order labels on chart
bool g_showVLines = true;        // Show/hide vertical lines
bool g_showHLines = true;        // Show/hide horizontal lines

// Individual label visibility controls
bool g_showCurrentProfitLabel = true;
bool g_showPositionDetailsLabel = true;
bool g_showSpreadEquityLabel = true;
bool g_showNextLotCalcLabel = true;
bool g_showSingleTrailLabel = true;
bool g_showGroupTrailLabel = true;
bool g_showTotalTrailLabel = true;
bool g_showLevelInfoLabel = true;
bool g_showNearbyOrdersLabel = true;
bool g_showLast5ClosesLabel = true;
bool g_showHistoryDisplayLabel = true;
bool g_showCenterProfitLabel = true;
bool g_showCenterCycleLabel = true;
bool g_showCenterBookedLabel = true;
bool g_showCenterNetLotsLabel = true;

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

// Per-symbol history tracking
struct SymbolDailyProfit {
   string symbol;
   double daily[5];
};
SymbolDailyProfit g_symbolHistory[];

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

// Order tracking system (prevent duplicates and track orders internally)
struct OrderInfo {
   ulong ticket;
   int type;           // POSITION_TYPE_BUY or POSITION_TYPE_SELL
   int level;          // Grid level
   double openPrice;
   double lotSize;
   double profit;
   datetime openTime;
   bool isValid;       // Track if order still exists on server
};
OrderInfo g_orders[];   // Primary order tracking array
int g_orderCount = 0;   // Active order count in array
