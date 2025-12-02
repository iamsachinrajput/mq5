
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
   g_NextSellLotSize = MathMax(g_NextSellLotSize, minLot);
   g_NextSellLotSize = MathRound(g_NextSellLotSize / stepLot) * stepLot;

   // Comments for display
   g_new_order_coments = StringFormat("%.0f,SC:%.0f,%.2f",
                                      g_total_running_profit,
                                      g_short_close_bytrail_total_profit,
                                      g_netLots);

   // Update cycle max loss touched: track absolute largest negative open-profit seen
   if(g_openTotalCount == 0)
   {
      // No positions -> reset cycle max loss and max profit
      g_max_Loss_touched_this_cycle = 0.0;
      g_max_profit_touched_this_cycle = 0.0;
   }
   else
   {
      if(g_current_open_profit < 0.0)
      {
         double absLoss = MathAbs(g_current_open_profit);
         if(absLoss > g_max_Loss_touched_this_cycle)
            g_max_Loss_touched_this_cycle = absLoss;
      }
      if(g_current_open_profit > 0.0)
      {
         if(g_current_open_profit > g_max_profit_touched_this_cycle)
            g_max_profit_touched_this_cycle = g_current_open_profit;
      }
   }   fnc_Print(2, 1, StringFormat("Next Buy Lot: %.3f, Next Sell Lot: %.3f", g_NextBuyLotSize, g_NextSellLotSize));
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
         int type = (int)PositionGetInteger(POSITION_TYPE);
         double openPrice = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN), _Digits);
         if(type == orderType && openPrice == levelPrice) return true;
      }
   }
   return false;
}

// De-duplication: same type near level
bool fnc_HasSameTypeNearLevel(int orderType, int L, double gapPx, int window)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         int type = (int)PositionGetInteger(POSITION_TYPE);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         int existingIndex = fnc_PriceLevelIndex(openPrice, gapPx);
         if(type == orderType && MathAbs(existingIndex - L) <= window) return true;
      }
   }
   return false;
}
