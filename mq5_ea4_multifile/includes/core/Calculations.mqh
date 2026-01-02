//+------------------------------------------------------------------+
//| Calculations.mqh                                                 |
//| ATR calculation, lot sizing, thresholds                          |
//+------------------------------------------------------------------+

//============================= CALCULATIONS =======================//
double CalculateSingleThreshold() {
   // For PROFIT-based activation
   if(SingleTrailActivation == SINGLE_ACTIVATION_PROFIT) {
      if(SingleActivationValue > 0) return SingleActivationValue;
      
      // Auto-calculate from gap
      double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
      double gapDistance = 2.0 * g_adaptiveGap;
      double priceMove = gapDistance - spread;
      
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickSize == 0) tickSize = _Point;
      
      double profitPer01 = (priceMove / tickSize) * tickValue * 0.01;
      if(profitPer01 < 0.01) profitPer01 = 0.01;
      
      Log(3, StringFormat("Auto-calc threshold: Gap=%.1f pts | Distance=%.1f | Spread=%.1f | Threshold=%.2f",
          g_adaptiveGap/_Point, gapDistance/_Point, spread/_Point, profitPer01));
      
      return profitPer01;
   }
   
   // For LEVEL-based activation, return 0 (threshold not used in same way)
   return 0.0;
}

double CalculateSingleTrailGap(double threshold, double profitPer01) {
   switch(SingleTrailGapMethod) {
      case SINGLE_GAP_FIXED:
         // Use helper value as points
         return SingleTrailGapValue * _Point;
         
      case SINGLE_GAP_PERCENTAGE:
         // Use helper value as % of threshold
         if(threshold > 0) {
            return threshold * (SingleTrailGapValue / 100.0);
         }
         // Fallback if threshold is 0
         return g_adaptiveGap * 0.5;
         
      case SINGLE_GAP_DYNAMIC:
         // Calculate based on order profit and lot size
         // Higher profit = wider gap
         if(profitPer01 > 0 && threshold > 0) {
            double ratio = profitPer01 / threshold;
            return threshold * MathMin(0.5, ratio * 0.2); // 20% to 50% of threshold
         }
         // Fallback
         return g_adaptiveGap * 0.5;
         
      default:
         return g_adaptiveGap * 0.5;
   }
}

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

void CalculateHistoryDailyProfits() {
   ArrayInitialize(g_historySymbolDaily, 0.0);
   ArrayInitialize(g_historyOverallDaily, 0.0);
   ArrayResize(g_symbolHistory, 0);
   
   MqlDateTime dtNow;
   TimeCurrent(dtNow);
   datetime today = StringToTime(StringFormat("%04d.%02d.%02d 00:00:00", dtNow.year, dtNow.mon, dtNow.day));
   
   datetime dayStarts[5];
   for(int i = 0; i < 5; i++) {
      dayStarts[i] = today - (i * 86400);
   }
   
   datetime historyStart = dayStarts[4];
   datetime historyEnd = TimeCurrent();
   
   if(!HistorySelect(historyStart, historyEnd)) {
      Log(2, "Failed to load history");
      return;
   }
   
   int totalDeals = HistoryDealsTotal();
   
   for(int i = 0; i < totalDeals; i++) {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      
      long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(dealEntry != DEAL_ENTRY_OUT) continue;
      
      long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
      string dealSymbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
      double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
      datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
      
      MqlDateTime dtDeal;
      TimeToStruct(dealTime, dtDeal);
      datetime dealDay = StringToTime(StringFormat("%04d.%02d.%02d 00:00:00", dtDeal.year, dtDeal.mon, dtDeal.day));
      
      for(int d = 0; d < 5; d++) {
         if(dealDay == dayStarts[d]) {
            g_historyOverallDaily[d] += dealProfit;
            
            if(dealMagic == Magic && dealSymbol == _Symbol) {
               g_historySymbolDaily[d] += dealProfit;
            }
            
            if(dealMagic == Magic) {
               int symIdx = -1;
               for(int s = 0; s < ArraySize(g_symbolHistory); s++) {
                  if(g_symbolHistory[s].symbol == dealSymbol) {
                     symIdx = s;
                     break;
                  }
               }
               if(symIdx == -1) {
                  symIdx = ArraySize(g_symbolHistory);
                  ArrayResize(g_symbolHistory, symIdx + 1);
                  g_symbolHistory[symIdx].symbol = dealSymbol;
                  ArrayInitialize(g_symbolHistory[symIdx].daily, 0.0);
               }
               g_symbolHistory[symIdx].daily[d] += dealProfit;
            }
            break;
         }
      }
   }
   
   Log(3, StringFormat("History Daily Profits - Symbol: %.2f,%.2f,%.2f,%.2f,%.2f | Overall: %.2f,%.2f,%.2f,%.2f,%.2f",
       g_historySymbolDaily[0], g_historySymbolDaily[1], g_historySymbolDaily[2], g_historySymbolDaily[3], g_historySymbolDaily[4],
       g_historyOverallDaily[0], g_historyOverallDaily[1], g_historyOverallDaily[2], g_historyOverallDaily[3], g_historyOverallDaily[4]));
