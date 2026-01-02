//+------------------------------------------------------------------+
//| UIOrderLabels.mqh                                                |
//| Order label creation and management                              |
//+------------------------------------------------------------------+

      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, horizontalOffset);
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
      
      Log(3, StringFormat("[LABEL-OPEN] Created label %s at L%d %s %.2f", labelName, level, typeStr, lotSize));
   }
}

void CreateCloseOrderLabel(ulong ticket, int level, int orderType, double profit, double price, datetime time) {
   if(!g_showOrderLabels || !g_showOrderLabelsCtrl) return;
   
   string typeStr = (orderType == POSITION_TYPE_BUY) ? "B" : "S";
   
   // Label name includes all details: ticket, level, type, profit, price, time
   MqlDateTime dt;
   TimeToStruct(time, dt);
   string timeStr = StringFormat("%04d%02d%02d_%02d%02d%02d", dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec);
   string labelName = StringFormat("OrderClose_T%I64u_L%d_%s_P%.2f_Price%.5f_%s", 
                                    ticket, level, typeStr, profit, price, timeStr);
   
   // Format profit: show decimal only if absolute value < 1
   string profitStr;
   if(MathAbs(profit) < 1.0) {
      profitStr = StringFormat("%.1f", profit);
   } else {
      profitStr = StringFormat("%.0f", profit);
   }
   
   // Format: "B 123" or "S -45" (no + symbol, no level)
   string labelText = StringFormat("%s %s", typeStr, profitStr);
   color labelColor = profit >= 0 ? clrLime : clrRed;
   
   // Add horizontal offset for BUY orders to prevent overlap
   int horizontalOffset = (orderType == POSITION_TYPE_BUY) ? -30 : 0;
   
   if(ObjectFind(0, labelName) < 0) {
      ObjectCreate(0, labelName, OBJ_TEXT, 0, time, price);
      ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, labelColor);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_RIGHT);
      ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, horizontalOffset);
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
      
      Log(3, StringFormat("[LABEL-CLOSE] Created label %s %s %s", labelName, typeStr, profitStr));
   }
}

void HideAllOrderLabels() {
   // Hide all order open labels
   for(int i = ObjectsTotal(0, 0, OBJ_TEXT) - 1; i >= 0; i--) {
      string objName = ObjectName(0, i, 0, OBJ_TEXT);
      if(StringFind(objName, "OrderOpen_") >= 0 || StringFind(objName, "OrderClose_") >= 0) {
         ObjectDelete(0, objName);
      }
   }
   Log(2, "[LABEL-HIDE] All order labels hidden");
}

void ShowAllOrderLabels() {
   // Recreate labels for existing positions (open labels only, close labels are created on close)
   for(int i = 0; i < g_orderCount; i++) {
      if(g_orders[i].isValid) {
         CreateOpenOrderLabel(
            g_orders[i].ticket,
            g_orders[i].level,
            g_orders[i].type,
            g_orders[i].lotSize,
            g_orders[i].openPrice,
            g_orders[i].openTime
         );
      }
   }
   Log(2, StringFormat("[LABEL-SHOW] Recreated %d order open labels", g_orderCount));
}

// Helper function to create close label before closing position
void CreateCloseLabelBeforeClose(ulong ticket) {
   if(!g_showOrderLabels) return;
   
   if(!PositionSelectByTicket(ticket)) return;
   
   // Get order info from tracking array
   int level = 0;
   int orderType = 0;
   for(int i = 0; i < g_orderCount; i++) {
      if(g_orders[i].ticket == ticket && g_orders[i].isValid) {
         level = g_orders[i].level;
         orderType = g_orders[i].type;
         break;
      }
   }
   
   if(level == 0) return; // Not found in tracking
   
   double profit = PositionGetDouble(POSITION_PROFIT);
   double closePrice = (orderType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   datetime closeTime = TimeCurrent();
   
   CreateCloseOrderLabel(ticket, level, orderType, profit, closePrice, closeTime);
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
