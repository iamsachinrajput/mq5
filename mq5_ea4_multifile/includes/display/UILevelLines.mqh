//+------------------------------------------------------------------+
//| UILevelLines.mqh                                                 |
//| Level lines drawing and management                               |
//+------------------------------------------------------------------+

//============================= LEVEL LINES DISPLAY =======================//

// Draw level lines (5 above and 5 below current price, including current)
void DrawLevelLines() {
   if(!g_showLevelLines) return;
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int currentLevel = PriceLevelIndex(currentPrice, g_adaptiveGap);
   
   // Draw 11 lines: current level, 5 above, 5 below
   for(int i = -5; i <= 5; i++) {
      int level = currentLevel + i;
      double levelPrice = LevelPrice(level, g_adaptiveGap);
      
      // Create horizontal line
      string lineName = StringFormat("LevelLine_%d", level);
      if(ObjectFind(0, lineName) < 0) {
         ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, levelPrice);
      }
      ObjectSetDouble(0, lineName, OBJPROP_PRICE, levelPrice);
      
      // Set line properties
      int lineWidth = (i == 0) ? 2 : 1;
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, LevelLineColor);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, lineWidth);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
      ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lineName, OBJPROP_HIDDEN, false);
      ObjectSetInteger(0, lineName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      
      // Create text label
      string labelName = StringFormat("LevelLabel_%d", level);
      if(ObjectFind(0, labelName) < 0) {
         ObjectCreate(0, labelName, OBJ_TEXT, 0, TimeCurrent(), levelPrice);
      }
      ObjectSetInteger(0, labelName, OBJPROP_TIME, TimeCurrent());
      ObjectSetDouble(0, labelName, OBJPROP_PRICE, levelPrice);
      ObjectSetString(0, labelName, OBJPROP_TEXT, StringFormat("L%d", level));
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, LevelLineColor);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, LevelLabelFontSize);
      ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, false);
      ObjectSetInteger(0, labelName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   }
   
   ChartRedraw(0);
}

// Remove all level lines and labels
void RemoveLevelLines() {
   // Remove all objects starting with "LevelLine_" or "LevelLabel_"
   for(int i = ObjectsTotal(0, 0, OBJ_HLINE) - 1; i >= 0; i--) {
      string objName = ObjectName(0, i, 0, OBJ_HLINE);
      if(StringFind(objName, "LevelLine_") >= 0) {
         ObjectDelete(0, objName);
      }
   }
   
   for(int i = ObjectsTotal(0, 0, OBJ_TEXT) - 1; i >= 0; i--) {
      string objName = ObjectName(0, i, 0, OBJ_TEXT);
      if(StringFind(objName, "LevelLabel_") >= 0) {
         ObjectDelete(0, objName);
      }
   }
   
   ChartRedraw(0);
}

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
