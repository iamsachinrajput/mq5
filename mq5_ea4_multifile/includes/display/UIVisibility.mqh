//+------------------------------------------------------------------+
//| UIVisibility.mqh                                                 |
//| Visibility control functions                                     |
//+------------------------------------------------------------------+

         if(ObjectFind(0, mainButtons[i]) >= 0) {
            ObjectDelete(0, mainButtons[i]);
         }
      }
   }
   
   // Apply info label visibility (prevent auto-creation by only hiding existing ones)
   string infoLabels[] = {
      "OverallProfitLabel", "CycleBookedLabel", "LevelInfoLabel", "NearbyOrdersLabel",
      "Last5ClosesLabel", "HistoryDisplayLabel", "CurrentProfitLabel", "PositionDetailsLabel",
      "SpreadEquityLabel", "NextLotCalcLabel", "SingleTrailStatusLabel", "GroupTrailStatusLabel", "TotalTrailStatusLabel"
   };
   
   for(int i = 0; i < ArraySize(infoLabels); i++) {
      if(ObjectFind(0, infoLabels[i]) >= 0) {
         ObjectSetInteger(0, infoLabels[i], OBJPROP_TIMEFRAMES, g_showInfoLabels ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
      }
   }
   
   // Apply order label visibility (by prefix)
   if(!g_showOrderLabelsCtrl) {
      for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--) {
         string objName = ObjectName(0, i, 0, -1);
         if(StringFind(objName, "OrderOpen_") >= 0 || StringFind(objName, "OrderClose_") >= 0) {
            ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
         }
      }
   } else {
      for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--) {
         string objName = ObjectName(0, i, 0, -1);
         if(StringFind(objName, "OrderOpen_") >= 0 || StringFind(objName, "OrderClose_") >= 0) {
            ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
         }
      }
   }
   
   // Apply VLine visibility
   if(!g_showVLines) {
      for(int i = ObjectsTotal(0, 0, OBJ_VLINE) - 1; i >= 0; i--) {
         string objName = ObjectName(0, i, 0, OBJ_VLINE);
         ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
      }
   } else {
      for(int i = ObjectsTotal(0, 0, OBJ_VLINE) - 1; i >= 0; i--) {
         string objName = ObjectName(0, i, 0, OBJ_VLINE);
         ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      }
   }
   
   // Apply HLine visibility
   if(!g_showHLines) {
      for(int i = ObjectsTotal(0, 0, OBJ_HLINE) - 1; i >= 0; i--) {
         string objName = ObjectName(0, i, 0, OBJ_HLINE);
         ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
      }
   } else {
      for(int i = ObjectsTotal(0, 0, OBJ_HLINE) - 1; i >= 0; i--) {
         string objName = ObjectName(0, i, 0, OBJ_HLINE);
         ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      }
   }
   
   // Ensure permanent control button stays visible (never hide this!)
   if(ObjectFind(0, "BtnVisibilityControls") >= 0) {
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_HIDDEN, false);
   }
   
   ChartRedraw(0);
   Log(2, StringFormat("Visibility applied: Buttons=%s, Labels=%s, OrderLabels=%s, VLines=%s, HLines=%s",
       g_showMainButtons ? "ON" : "OFF",
       g_showInfoLabels ? "ON" : "OFF",
       g_showOrderLabelsCtrl ? "ON" : "OFF",
       g_showVLines ? "ON" : "OFF",
       g_showHLines ? "ON" : "OFF"));
}

//============================= ORDER LABEL FUNCTIONS ==============//
void CreateOpenOrderLabel(ulong ticket, int level, int orderType, double lotSize, double price, datetime time) {
   if(!g_showOrderLabels || !g_showOrderLabelsCtrl) return;
   
   string typeStr = (orderType == POSITION_TYPE_BUY) ? "B" : "S";
   string labelName = StringFormat("OrderOpen_%I64u", ticket);
   string labelText = StringFormat("L%d %s %.2f", level, typeStr, lotSize);
   
   // Add horizontal offset for BUY orders to prevent overlap with SELL labels
   int horizontalOffset = (orderType == POSITION_TYPE_BUY) ? -30 : 0;
   
   if(ObjectFind(0, labelName) < 0) {
      ObjectCreate(0, labelName, OBJ_TEXT, 0, time, price);
      ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrLightBlue);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
