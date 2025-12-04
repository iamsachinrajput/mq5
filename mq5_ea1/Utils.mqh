
#property strict

//============================= Inputs =============================//
input int switchmodecount = 10;

//============================= Existing Globals =============================//
double g_short_close_bytrail_total_profit = 0.0;
int    g_short_close_bytrail_total_orders = 0;
double g_short_close_bytrail_total_lots   = 0.0;

double g_TotalNetLots = 0.0;
double g_TotalProfit = 0.0;
double g_TotalBuyLots = 0.0;
double g_TotalSellLots = 0.0;
int g_CountBuyOrders = 0;
int g_CountSellOrders = 0;
double g_NextBuyLotSize = 0.0;
double g_NextSellLotSize = 0.0;

// Performance globals
double g_LastTickTime = 0.0;
double g_AvgTickTime = 0.0;
int g_TickCount = 0;

// Origin price for level calculations
double g_originPrice = 0;

//============================= Migrated Globals from MQ4 =============================//
string g_current_orders_seq = "";
string g_current_orders_seq_recovery = "";
double g_total_running_profit = 0.0;
double g_current_open_profit = 0.0;
int g_openTotalCount = 0;
int g_openBuyCount = 0;
int g_openSellCount = 0;
double g_deepest_sell_price = 0.0;
double g_deepest_buy_price = 0.0;
int g_preferred_direction = -1;
double g_max_Loss_touched = -1;
double g_max_trail_benifit = 0.0;
double g_equity_profit = 0.0;
double g_lastOrderPrice = 0.0;
int g_lastOrderType = -1;
double g_openBuyLots = 0.0;
double g_openSellLots = 0.0;
double g_total_running_lots = 0.0;
double g_netLots = 0.0;
string g_new_order_coments = "";
string g_text_LR = "";
int GPO = 0; // profitable orders count
int GLO = 0; // losing orders count
// Max loss (absolute) touched in current cycle (after last close-all)
double g_max_Loss_touched_this_cycle = 0.0;
// Max profit touched in current cycle (after last close-all)
double g_max_profit_touched_this_cycle = 0.0;
// Track equity at last closeall event to calculate cycle profit
double g_last_closeall_equity = 0.0;
// Track opening balance for total profit calculation
double g_opening_balance = 0.0;
// Track max loss overall (from beginning)
double g_max_loss_overall = 0.0;
// Track max loss of current cycle (resets on closeall)
double g_max_loss_current_cycle = 0.0;
// Track max profit overall (from beginning)
double g_max_profit_overall = 0.0;
// Track max profit of current cycle (resets on closeall)
double g_max_profit_current_cycle = 0.0;

//============================= Spread Tracking =============================//
double g_current_spread_px = 0.0; // Current spread in price
double g_max_spread_px = 0.0;     // Max spread touched

//============================= Last 10 Closeall Profits =============================//
#define MAX_CLOSEALL_HISTORY 10
double g_closeall_profits[MAX_CLOSEALL_HISTORY] = {0};  // Circular buffer of last 10 closeall profits
int g_closeall_count = 0;                               // Total closeall count (for circular indexing)

//============================= Helpers =============================//
bool IsEven(int L){ return (L % 2 == 0); }
bool IsOdd(int L){ return (L % 2 != 0); }

int fnc_PipFactor(){ return (_Digits == 3 || _Digits == 5) ? 10 : 1; }
double fnc_PipsToPrice(double p){ return p * fnc_PipFactor() * _Point; }
double fnc_PriceToPips(double px){ return (_Point > 0 ? px / (_Point * fnc_PipFactor()) : 0.0); }
double fnc_CurrSpreadPx(){ return SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID); }
double fnc_CurrSpreadPips(){ return fnc_PriceToPips(fnc_CurrSpreadPx()); }
double fnc_SafeDiv(double a, double b){ return (b == 0.0) ? 0.0 : (a / b); }

// Calculate level index based on price and gap
int fnc_PriceLevelIndex(double price, double gapPx)
{
   double idx = (gapPx != 0) ? (price - g_originPrice) / gapPx : 0 + 1e-9;
   return (int)MathFloor(idx);
}

// Calculate nearest level index
int fnc_NearestLevelIndex(double price, double gapPx)
{
   double idx = (price - g_originPrice) / gapPx;
   return (int)MathRound(idx);
}

// Get price for a given level index
double fnc_LevelPrice(int L, double gapPx)
{
   return g_originPrice + gapPx * L;
}

// Debug print
void fnc_Print(int debugLevel, int level, string message)
{
   if(level <= debugLevel) Print(StringFormat("[DEBUG-%d] %s", level, message));
}

//============================= Traversal & Stats =============================//
void fnc_GetInfoFromOrdersTraversal()
{
   // Reset all totals
   g_TotalNetLots = g_TotalProfit = g_TotalBuyLots = g_TotalSellLots = 0.0;
   g_CountBuyOrders = g_CountSellOrders = 0;

   // Track current spread
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   g_current_spread_px = (ask > 0 && bid > 0) ? (ask - bid) : 0.0;
   if(g_current_spread_px > g_max_spread_px)
      g_max_spread_px = g_current_spread_px;

   // Reset migrated stats
   g_current_orders_seq = "";
   g_current_orders_seq_recovery = "";
   g_current_open_profit = 0.0;
   g_openTotalCount = 0;
   g_openBuyCount = 0;
   g_openSellCount = 0;
   g_deepest_buy_price = 0.0;
   g_deepest_sell_price = 0.0;
   g_lastOrderType = -1;
   g_lastOrderPrice = 0.0;
   GPO = 0;
   GLO = 0;

   double bLots = 0.0, sLots = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;

         double lots = PositionGetDouble(POSITION_VOLUME);
         double profit = PositionGetDouble(POSITION_PROFIT);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         int type = (int)PositionGetInteger(POSITION_TYPE);

         g_TotalProfit += profit;
         g_current_open_profit += profit;

         if(type == POSITION_TYPE_BUY)
         {
            g_TotalBuyLots += lots;
            g_CountBuyOrders++;
            g_openBuyCount++;
            bLots += lots;
            g_deepest_buy_price = MathMax(g_deepest_buy_price, openPrice);
            g_TotalNetLots += lots;
         }
         else if(type == POSITION_TYPE_SELL)
         {
            g_TotalSellLots += lots;
            g_CountSellOrders++;
            g_openSellCount++;
            sLots += lots;
            g_deepest_sell_price = (g_deepest_sell_price == 0.0) ? openPrice : MathMin(g_deepest_sell_price, openPrice);
            g_TotalNetLots -= lots;
         }

         if(profit < 0) GLO++; else GPO++;

         string t = (type == POSITION_TYPE_BUY) ? "b" : "s";
         g_current_orders_seq += StringFormat("%s%.2f,", t, lots);
      }
   }

   g_openTotalCount = g_openBuyCount + g_openSellCount;
   g_openBuyLots = bLots;
   g_openSellLots = sLots;
   g_total_running_lots = bLots + sLots;
   g_netLots = bLots - sLots;
   g_total_running_profit = g_current_open_profit + g_short_close_bytrail_total_profit;

   // Preferred direction
   g_preferred_direction = (g_netLots > 0) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;

   // Equity profit approximation
   g_equity_profit = AccountInfoDouble(ACCOUNT_EQUITY) - AccountInfoDouble(ACCOUNT_BALANCE);

   // Next lot size logic (existing)
   int maxOrders = MathMax(g_CountBuyOrders, g_CountSellOrders);
   g_NextSellLotSize = LotSize * (maxOrders + 1);
   g_NextBuyLotSize = LotSize * (maxOrders + 1);

   if(g_TotalNetLots > 0)
      g_NextBuyLotSize = 2*g_NextSellLotSize + (g_TotalNetLots / 2);
   else if(g_TotalNetLots < 0)
      g_NextSellLotSize = 2*g_NextBuyLotSize + (MathAbs(g_TotalNetLots) / 2);

   if(maxOrders >= switchmodecount && g_TotalNetLots != 0)
   {
      double midlot = g_NextSellLotSize;
      g_NextSellLotSize = g_NextBuyLotSize;
      g_NextBuyLotSize = midlot;
   }

   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   g_NextBuyLotSize = MathMax(g_NextBuyLotSize, minLot);
   g_NextBuyLotSize = MathRound(g_NextBuyLotSize / stepLot) * stepLot;
   g_NextBuyLotSize = MathMin(g_NextBuyLotSize, MaxSingleLotSize); // Cap max lot size
   g_NextSellLotSize = MathMax(g_NextSellLotSize, minLot);
   g_NextSellLotSize = MathRound(g_NextSellLotSize / stepLot) * stepLot;
   g_NextSellLotSize = MathMin(g_NextSellLotSize, MaxSingleLotSize); // Cap max lot size

   // Comments for display
   g_new_order_coments = StringFormat("%.0f,SC:%.0f,%.2f",
                                      g_total_running_profit,
                                      g_short_close_bytrail_total_profit,
                                      g_netLots);

   // Track max loss/profit from open profit (used for trail start calculation)
   if(g_openTotalCount > 0)
   {
      // Track max loss from negative open profit
      if(g_current_open_profit < 0.0)
      {
         double absLoss = MathAbs(g_current_open_profit);
         if(absLoss > g_max_Loss_touched_this_cycle)
            g_max_Loss_touched_this_cycle = absLoss;
      }
      // Track max profit from positive open profit
      if(g_current_open_profit > 0.0)
      {
         if(g_current_open_profit > g_max_profit_touched_this_cycle)
            g_max_profit_touched_this_cycle = g_current_open_profit;
      }
      
      // Initialize max loss/profit on first positions opened
      if(g_max_Loss_touched_this_cycle == 0.0 && g_max_profit_touched_this_cycle == 0.0)
      {
         if(g_current_open_profit > 0.0)
            g_max_profit_touched_this_cycle = g_current_open_profit;
         else if(g_current_open_profit < 0.0)
            g_max_Loss_touched_this_cycle = MathAbs(g_current_open_profit);
      }
   }

   // Initialize opening balance on first run
   if(g_opening_balance == 0.0)
      g_opening_balance = AccountInfoDouble(ACCOUNT_BALANCE);

   // Initialize last closeall equity on first run (if not set)
   if(g_last_closeall_equity == 0.0)
      g_last_closeall_equity = AccountInfoDouble(ACCOUNT_EQUITY);

   // Track max loss and max profit - overall and current cycle (based on equity)
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Track max loss (negative equity movements)
   double currentDrawdown = currentEquity - g_opening_balance;
   if(currentDrawdown < 0.0)
   {
      double absDrawdown = MathAbs(currentDrawdown);
      if(absDrawdown > g_max_loss_overall)
         g_max_loss_overall = absDrawdown;
   }
   
   double cycleDrawdown = currentEquity - g_last_closeall_equity;
   if(cycleDrawdown < 0.0)
   {
      double absCycleDrawdown = MathAbs(cycleDrawdown);
      if(absCycleDrawdown > g_max_loss_current_cycle)
         g_max_loss_current_cycle = absCycleDrawdown;
   }
   
   // Track max profit (positive equity movements)
   double currentProfitFromStart = currentEquity - g_opening_balance;
   if(currentProfitFromStart > 0.0)
   {
      if(currentProfitFromStart > g_max_profit_overall)
         g_max_profit_overall = currentProfitFromStart;
   }
   
   double cycleProfitFromLastClose = currentEquity - g_last_closeall_equity;
   if(cycleProfitFromLastClose > 0.0)
   {
      if(cycleProfitFromLastClose > g_max_profit_current_cycle)
         g_max_profit_current_cycle = cycleProfitFromLastClose;
   }
   
   // Ensure overall values are always >= current cycle values
   if(g_max_loss_current_cycle > g_max_loss_overall)
      g_max_loss_overall = g_max_loss_current_cycle;
   if(g_max_profit_current_cycle > g_max_profit_overall)
      g_max_profit_overall = g_max_profit_current_cycle;

   fnc_Print(2, 1, StringFormat("Next Buy Lot: %.3f, Next Sell Lot: %.3f", g_NextBuyLotSize, g_NextSellLotSize));
}

// Function to reset cycle tracking when closeall is triggered
void fnc_ResetCycleTracking()
{
   // Record the closeall profit before resetting
   double closeallProfit = AccountInfoDouble(ACCOUNT_EQUITY) - g_last_closeall_equity;
   int historyIndex = g_closeall_count % MAX_CLOSEALL_HISTORY;
   g_closeall_profits[historyIndex] = closeallProfit;
   g_closeall_count++;
   
   fnc_Print(DebugLevel, 1, StringFormat("[Utils] Cycle reset: Profit=%.2f | History Index=%d | Total Closealls=%d", 
                                         closeallProfit, historyIndex, g_closeall_count));
   
   g_last_closeall_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_max_Loss_touched_this_cycle = 0.0;
   g_max_profit_touched_this_cycle = 0.0;
   g_max_loss_current_cycle = 0.0;
   g_max_profit_current_cycle = 0.0;
   g_short_close_bytrail_total_profit = 0.0;
   g_short_close_bytrail_total_orders = 0;
   g_short_close_bytrail_total_lots = 0.0;
   fnc_Print(DebugLevel, 1, StringFormat("[Utils] Cycle reset: LastCloseAllEquity=%.2f", g_last_closeall_equity));
}

// Format last 10 closeall profits for display
string fnc_GetLast10CloseallProfits()
{
   string result = "Last 10 Closealls: ";
   
   // If no closealls yet
   if(g_closeall_count == 0)
      return result + "None yet";
   
   // Determine how many to show (max 10)
   int count = MathMin(g_closeall_count, MAX_CLOSEALL_HISTORY);
   
   // Show oldest to newest
   for(int i = 0; i < count; i++)
   {
      // Calculate index in circular buffer (oldest first)
      int idx;
      if(g_closeall_count < MAX_CLOSEALL_HISTORY)
      {
         // Buffer not full yet, show from start
         idx = i;
      }
      else
      {
         // Buffer is full, start from oldest (next position after latest)
         idx = (g_closeall_count + i) % MAX_CLOSEALL_HISTORY;
      }
      
      double profit = g_closeall_profits[idx];
      result += StringFormat("%.0f", profit);
      if(i < count - 1)
         result += " | ";
   }
   
   return result;
}

//============================= Performance =============================//
void fnc_MeasurePerformance(bool enablePerf, ulong startTime)
{
   if(!enablePerf) return;
   ulong endTime = GetMicrosecondCount();
   double elapsed = (double)(endTime - startTime) / 1000.0; // ms
   g_LastTickTime = elapsed;
   g_TickCount++;
   g_AvgTickTime = ((g_AvgTickTime * (g_TickCount - 1)) + elapsed) / g_TickCount;
}


// Original base level functions
double fnc_GetBaseLevel(double currentPrice, double gap)
{
   return fnc_GetBasePrice(currentPrice, gap);
}

double fnc_GetBasePrice(double price, double gap)
{
   return MathRound(price / RoundToNearest) * RoundToNearest;
}

int fnc_GetNearestOrderLevelIndex(double currentPrice, double gap)
{
   if(PositionsTotal() == 0) return 0;
   double nearestPrice = currentPrice;
   double minDiff = DBL_MAX;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double diff = MathAbs(openPrice - currentPrice);
         if(diff < minDiff)
         {
            minDiff = diff;
            nearestPrice = openPrice;
         }
      }
   }
   return (int)MathRound((nearestPrice - fnc_GetBasePrice(currentPrice, gap)) / gap);
}

// Duplicate check by price
bool fnc_IsOrderAtLevel(double levelPrice)
{
   double normalizedLevel = NormalizeDouble(levelPrice, _Digits);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         double openPrice = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN), _Digits);
         if(openPrice == normalizedLevel) return true;
      }
   }
   return false;
}

// De-duplication: same type on level
bool fnc_HasSameTypeOnLevel(int orderType, int L, double gapPx)
{
   double levelPrice = NormalizeDouble(fnc_LevelPrice(L, gapPx), _Digits);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         // Check symbol and magic to avoid false duplicates
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
         
         int type = (int)PositionGetInteger(POSITION_TYPE);
         double openPrice = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN), _Digits);
         
         // Only check same parity levels: BUYs on even levels, SELLs on odd levels
         int existingLevel = fnc_PriceLevelIndex(openPrice, gapPx);
         bool sameParity = ((L % 2) == (existingLevel % 2));
         
         if(type == orderType && openPrice == levelPrice && sameParity) return true;
      }
   }
   return false;
}

// De-duplication: same type near level
bool fnc_HasSameTypeNearLevel(int orderType, int L, double gapPx, int window, int debugLevel = 2)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         // Check symbol and magic to avoid false duplicates
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
         
         int type = (int)PositionGetInteger(POSITION_TYPE);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         int existingIndex = fnc_PriceLevelIndex(openPrice, gapPx);
         int levelDistance = (int)MathAbs(existingIndex - L);
         
         // Only check same parity levels: BUYs on even levels, SELLs on odd levels
         bool sameParity = ((L % 2) == (existingIndex % 2));
         
         if(type == orderType && levelDistance <= window && sameParity)
         {
            double checkingPrice = fnc_LevelPrice(L, gapPx);
            double priceDistance = MathAbs(openPrice - checkingPrice);
            double gapPoints = gapPx / _Point;
            fnc_Print(debugLevel, 1, StringFormat("⚠️ DUPLICATE FOUND: Ticket #%I64u | Type:%s | OpenPrice:%.5f | ExistingLevel:%d | CheckingLevel:%d (Price:%.5f) | LevelDist:%d (window:%d) | PriceDist:%.2f pts (gap:%.2f)",
                                                   ticket, 
                                                   (type == POSITION_TYPE_BUY ? "BUY" : "SELL"),
                                                   openPrice,
                                                   existingIndex,
                                                   L,
                                                   checkingPrice,
                                                   levelDistance,
                                                   window,
                                                   priceDistance / _Point,
                                                   gapPoints));
            return true;
         }
      }
   }
   return false;
}
