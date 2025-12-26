//+------------------------------------------------------------------+
//| DisplayFunctions.mqh                                             |
//| Display, UI, buttons, labels, and chart event handling          |
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

//============================= VISIBILITY CONTROL BUTTON (ALWAYS VISIBLE) =======================//

void CreateVisibilityControlButton() {
   // ==== PERMANENT CONTROL BUTTON (Always Visible) ====
   // This button is NEVER hidden by any control and always remains visible
   int ctrlButtonWidth = 150;
   int ctrlButtonHeight = 30;
   
   // Determine corner based on input
   ENUM_BASE_CORNER ctrlCorner;
   switch(CtrlButtonCorner) {
      case CTRL_CORNER_RIGHT_LOWER: ctrlCorner = CORNER_RIGHT_LOWER; break;
      case CTRL_CORNER_RIGHT_UPPER: ctrlCorner = CORNER_RIGHT_UPPER; break;
      case CTRL_CORNER_LEFT_LOWER:  ctrlCorner = CORNER_LEFT_LOWER; break;
      case CTRL_CORNER_LEFT_UPPER:  ctrlCorner = CORNER_LEFT_UPPER; break;
      default: ctrlCorner = CORNER_RIGHT_LOWER;
   }
   
   // Button: Visibility Controls (Show/Hide)
   string btnVisCtrl = "BtnVisibilityControls";
   if(ObjectFind(0, btnVisCtrl) < 0) {
      ObjectCreate(0, btnVisCtrl, OBJ_BUTTON, 0, 0, 0);
      Print("Created visibility control button: ", btnVisCtrl);
   }
   ObjectSetInteger(0, btnVisCtrl, OBJPROP_XDISTANCE, CtrlBtnXDistance);
   ObjectSetInteger(0, btnVisCtrl, OBJPROP_YDISTANCE, CtrlBtnYDistance);
   ObjectSetInteger(0, btnVisCtrl, OBJPROP_XSIZE, ctrlButtonWidth);
   ObjectSetInteger(0, btnVisCtrl, OBJPROP_YSIZE, ctrlButtonHeight);
   ObjectSetString(0, btnVisCtrl, OBJPROP_TEXT, g_showMainButtons ? "HIDE BUTTONS" : "SHOW BUTTONS");
   ObjectSetInteger(0, btnVisCtrl, OBJPROP_CORNER, ctrlCorner);
   ObjectSetInteger(0, btnVisCtrl, OBJPROP_ANCHOR, ctrlCorner);
   ObjectSetInteger(0, btnVisCtrl, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnVisCtrl, OBJPROP_BGCOLOR, g_showMainButtons ? clrDarkRed : clrDarkGreen);
   ObjectSetInteger(0, btnVisCtrl, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, btnVisCtrl, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnVisCtrl, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, btnVisCtrl, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   Print(StringFormat("Button positioned at corner %d, X:%d, Y:%d", ctrlCorner, CtrlBtnXDistance, CtrlBtnYDistance));
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
   
   // Button 1: No Work Mode (CRITICAL)
   string btn2Name = "BtnNoWork";
   if(ObjectFind(0, btn2Name) < 0) {
      ObjectCreate(0, btn2Name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, btn2Name, OBJPROP_XDISTANCE, rightMargin);
      ObjectSetInteger(0, btn2Name, OBJPROP_YDISTANCE, topMargin);
      ObjectSetInteger(0, btn2Name, OBJPROP_XSIZE, buttonWidth);
      ObjectSetInteger(0, btn2Name, OBJPROP_YSIZE, buttonHeight);
      ObjectSetInteger(0, btn2Name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, btn2Name, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, btn2Name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, btn2Name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, btn2Name, OBJPROP_HIDDEN, false);
   }
   
   // Button 2: Stop New Orders (CRITICAL)
   string btn1Name = "BtnStopNewOrders";
   if(ObjectFind(0, btn1Name) < 0) {
      ObjectCreate(0, btn1Name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, btn1Name, OBJPROP_XDISTANCE, rightMargin);
      ObjectSetInteger(0, btn1Name, OBJPROP_YDISTANCE, topMargin + buttonHeight + verticalGap);
      ObjectSetInteger(0, btn1Name, OBJPROP_XSIZE, buttonWidth);
      ObjectSetInteger(0, btn1Name, OBJPROP_YSIZE, buttonHeight);
      ObjectSetInteger(0, btn1Name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, btn1Name, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, btn1Name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, btn1Name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, btn1Name, OBJPROP_HIDDEN, false);
   }
   
   // Button 3: Close All (CRITICAL)
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
   
   // Button 4: Reset Counters (CRITICAL)
   string btn12Name = "BtnResetCounters";
   if(ObjectFind(0, btn12Name) < 0) {
      ObjectCreate(0, btn12Name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, btn12Name, OBJPROP_XDISTANCE, rightMargin);
      ObjectSetInteger(0, btn12Name, OBJPROP_YDISTANCE, topMargin + (buttonHeight + verticalGap) * 3);
      ObjectSetInteger(0, btn12Name, OBJPROP_XSIZE, buttonWidth);
      ObjectSetInteger(0, btn12Name, OBJPROP_YSIZE, buttonHeight);
      ObjectSetInteger(0, btn12Name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetString(0, btn12Name, OBJPROP_TEXT, "Reset (3x click)");
      ObjectSetInteger(0, btn12Name, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, btn12Name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, btn12Name, OBJPROP_BGCOLOR, clrDarkOrange);
      ObjectSetInteger(0, btn12Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn12Name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, btn12Name, OBJPROP_HIDDEN, false);
   }
   
   // Button 5: Lines Control (SHOW) - Opens panel for VLines, HLines, Next Lines, Order Labels
   string btn4Name = "BtnLinesControl";
   if(ObjectFind(0, btn4Name) < 0) {
      ObjectCreate(0, btn4Name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, btn4Name, OBJPROP_XDISTANCE, rightMargin);
      ObjectSetInteger(0, btn4Name, OBJPROP_YDISTANCE, topMargin + (buttonHeight + verticalGap) * 4);
      ObjectSetInteger(0, btn4Name, OBJPROP_XSIZE, buttonWidth);
      ObjectSetInteger(0, btn4Name, OBJPROP_YSIZE, buttonHeight);
      ObjectSetInteger(0, btn4Name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, btn4Name, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, btn4Name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, btn4Name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, btn4Name, OBJPROP_HIDDEN, false);
   }
   
   // Button 6: Toggle Labels (Info Labels)
   string btn11Name = "BtnToggleLabels";
   if(ObjectFind(0, btn11Name) < 0) {
      ObjectCreate(0, btn11Name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, btn11Name, OBJPROP_XDISTANCE, rightMargin);
      ObjectSetInteger(0, btn11Name, OBJPROP_YDISTANCE, topMargin + (buttonHeight + verticalGap) * 5);
      ObjectSetInteger(0, btn11Name, OBJPROP_XSIZE, buttonWidth);
      ObjectSetInteger(0, btn11Name, OBJPROP_YSIZE, buttonHeight);
      ObjectSetInteger(0, btn11Name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, btn11Name, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, btn11Name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, btn11Name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, btn11Name, OBJPROP_HIDDEN, false);
   }
   
   // Button 7: Print Stats (shifted up from position 6)
   string btn6Name = "BtnPrintStats";
   if(ObjectFind(0, btn6Name) < 0) {
      ObjectCreate(0, btn6Name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, btn6Name, OBJPROP_XDISTANCE, rightMargin);
      ObjectSetInteger(0, btn6Name, OBJPROP_YDISTANCE, topMargin + (buttonHeight + verticalGap) * 6);
      ObjectSetInteger(0, btn6Name, OBJPROP_XSIZE, buttonWidth);
      ObjectSetInteger(0, btn6Name, OBJPROP_YSIZE, buttonHeight);
      ObjectSetInteger(0, btn6Name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetString(0, btn6Name, OBJPROP_TEXT, "Print Stats");
      ObjectSetInteger(0, btn6Name, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, btn6Name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, btn6Name, OBJPROP_BGCOLOR, clrDarkBlue);
      ObjectSetInteger(0, btn6Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn6Name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, btn6Name, OBJPROP_HIDDEN, false);
   }
   
   // Button 8: Trail Method Strategy (TRAIL)
   string btn10Name = "BtnTrailMethod";
   if(ObjectFind(0, btn10Name) < 0) {
      ObjectCreate(0, btn10Name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, btn10Name, OBJPROP_XDISTANCE, rightMargin);
      ObjectSetInteger(0, btn10Name, OBJPROP_YDISTANCE, topMargin + (buttonHeight + verticalGap) * 8);
      ObjectSetInteger(0, btn10Name, OBJPROP_XSIZE, buttonWidth);
      ObjectSetInteger(0, btn10Name, OBJPROP_YSIZE, buttonHeight);
      ObjectSetInteger(0, btn10Name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetString(0, btn10Name, OBJPROP_TEXT, "Method: SAMETYPE");
      ObjectSetInteger(0, btn10Name, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, btn10Name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, btn10Name, OBJPROP_BGCOLOR, clrDarkSlateGray);
      ObjectSetInteger(0, btn10Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn10Name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, btn10Name, OBJPROP_HIDDEN, false);
   }
   
   // Button 9: Single Trail Mode (TRAIL)
   string btn8Name = "BtnSingleTrail";
   if(ObjectFind(0, btn8Name) < 0) {
      ObjectCreate(0, btn8Name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, btn8Name, OBJPROP_XDISTANCE, rightMargin);
      ObjectSetInteger(0, btn8Name, OBJPROP_YDISTANCE, topMargin + (buttonHeight + verticalGap) * 9);
      ObjectSetInteger(0, btn8Name, OBJPROP_XSIZE, buttonWidth);
      ObjectSetInteger(0, btn8Name, OBJPROP_YSIZE, buttonHeight);
      ObjectSetInteger(0, btn8Name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetString(0, btn8Name, OBJPROP_TEXT, "STrail: NORMAL");
      ObjectSetInteger(0, btn8Name, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, btn8Name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, btn8Name, OBJPROP_BGCOLOR, clrDarkBlue);
      ObjectSetInteger(0, btn8Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn8Name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, btn8Name, OBJPROP_HIDDEN, false);
   }
   
   // Button 10: Total Trail Mode (TRAIL)
   string btn9Name = "BtnTotalTrail";
   if(ObjectFind(0, btn9Name) < 0) {
      ObjectCreate(0, btn9Name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, btn9Name, OBJPROP_XDISTANCE, rightMargin);
      ObjectSetInteger(0, btn9Name, OBJPROP_YDISTANCE, topMargin + (buttonHeight + verticalGap) * 11);
      ObjectSetInteger(0, btn9Name, OBJPROP_XSIZE, buttonWidth);
      ObjectSetInteger(0, btn9Name, OBJPROP_YSIZE, buttonHeight);
      ObjectSetInteger(0, btn9Name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetString(0, btn9Name, OBJPROP_TEXT, "TTrail: NORMAL");
      ObjectSetInteger(0, btn9Name, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, btn9Name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, btn9Name, OBJPROP_BGCOLOR, clrDarkBlue);
      ObjectSetInteger(0, btn9Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn9Name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, btn9Name, OBJPROP_HIDDEN, false);
   }
   
   // Button 11: Debug Level (LESS CRITICAL)
   string btn7Name = "BtnDebugLevel";
   if(ObjectFind(0, btn7Name) < 0) {
      ObjectCreate(0, btn7Name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, btn7Name, OBJPROP_XDISTANCE, rightMargin);
      ObjectSetInteger(0, btn7Name, OBJPROP_YDISTANCE, topMargin + (buttonHeight + verticalGap) * 12);
      ObjectSetInteger(0, btn7Name, OBJPROP_XSIZE, buttonWidth);
      ObjectSetInteger(0, btn7Name, OBJPROP_YSIZE, buttonHeight);
      ObjectSetInteger(0, btn7Name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetString(0, btn7Name, OBJPROP_TEXT, "Debug: 3");
      ObjectSetInteger(0, btn7Name, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, btn7Name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, btn7Name, OBJPROP_BGCOLOR, clrDarkGreen);
      ObjectSetInteger(0, btn7Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn7Name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, btn7Name, OBJPROP_HIDDEN, false);
   }
   
   // Button 12: Trade Logging Toggle
   string btn13Name = "BtnTradeLogging";
   if(ObjectFind(0, btn13Name) < 0) {
      ObjectCreate(0, btn13Name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, btn13Name, OBJPROP_XDISTANCE, rightMargin);
      ObjectSetInteger(0, btn13Name, OBJPROP_YDISTANCE, topMargin + (buttonHeight + verticalGap) * 13);
      ObjectSetInteger(0, btn13Name, OBJPROP_XSIZE, buttonWidth);
      ObjectSetInteger(0, btn13Name, OBJPROP_YSIZE, buttonHeight);
      ObjectSetInteger(0, btn13Name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetString(0, btn13Name, OBJPROP_TEXT, "Log: OFF");
      ObjectSetInteger(0, btn13Name, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, btn13Name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, btn13Name, OBJPROP_BGCOLOR, clrDarkRed);
      ObjectSetInteger(0, btn13Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn13Name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, btn13Name, OBJPROP_HIDDEN, false);
   }
   
   // Button 13: Level Lines Toggle
   string btn14Name = "BtnLevelLines";
   if(ObjectFind(0, btn14Name) < 0) {
      ObjectCreate(0, btn14Name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, btn14Name, OBJPROP_XDISTANCE, rightMargin);
      ObjectSetInteger(0, btn14Name, OBJPROP_YDISTANCE, topMargin + (buttonHeight + verticalGap) * 14);
      ObjectSetInteger(0, btn14Name, OBJPROP_XSIZE, buttonWidth);
      ObjectSetInteger(0, btn14Name, OBJPROP_YSIZE, buttonHeight);
      ObjectSetInteger(0, btn14Name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetString(0, btn14Name, OBJPROP_TEXT, "Levels: OFF");
      ObjectSetInteger(0, btn14Name, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, btn14Name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, btn14Name, OBJPROP_BGCOLOR, clrDarkGray);
      ObjectSetInteger(0, btn14Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn14Name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, btn14Name, OBJPROP_HIDDEN, false);
      ObjectSetInteger(0, btn14Name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   }
   
   // Button 15: Print Stats (LESS CRITICAL) - Duplicate removed, use position 7 instead
   string btn15Name = "BtnPrintStats";
   if(ObjectFind(0, btn15Name) < 0) {
      ObjectCreate(0, btn15Name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, btn15Name, OBJPROP_XDISTANCE, rightMargin);
      ObjectSetInteger(0, btn15Name, OBJPROP_YDISTANCE, topMargin + (buttonHeight + verticalGap) * 15);
      ObjectSetInteger(0, btn15Name, OBJPROP_XSIZE, buttonWidth);
      ObjectSetInteger(0, btn15Name, OBJPROP_YSIZE, buttonHeight);
      ObjectSetInteger(0, btn15Name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetString(0, btn15Name, OBJPROP_TEXT, "Print Stats");
      ObjectSetInteger(0, btn15Name, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, btn15Name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, btn15Name, OBJPROP_BGCOLOR, clrDarkBlue);
      ObjectSetInteger(0, btn15Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn15Name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, btn15Name, OBJPROP_HIDDEN, false);
   }
   
   // Button 14: History Display Mode
   string btnHistName = "BtnHistoryMode";
   if(ObjectFind(0, btnHistName) < 0) {
      ObjectCreate(0, btnHistName, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, btnHistName, OBJPROP_XDISTANCE, rightMargin);
      ObjectSetInteger(0, btnHistName, OBJPROP_YDISTANCE, topMargin + (buttonHeight + verticalGap) * 14);
      ObjectSetInteger(0, btnHistName, OBJPROP_XSIZE, buttonWidth);
      ObjectSetInteger(0, btnHistName, OBJPROP_YSIZE, buttonHeight);
      ObjectSetInteger(0, btnHistName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetString(0, btnHistName, OBJPROP_TEXT, "Hist:Overall");
      ObjectSetInteger(0, btnHistName, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, btnHistName, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, btnHistName, OBJPROP_BGCOLOR, clrDarkGreen);
      ObjectSetInteger(0, btnHistName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btnHistName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, btnHistName, OBJPROP_HIDDEN, false);
   }
   
   // Button 15: Toggle VLines
   string btnVLinesName = "BtnToggleVLines";
   if(ObjectFind(0, btnVLinesName) < 0) {
      ObjectCreate(0, btnVLinesName, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, btnVLinesName, OBJPROP_XDISTANCE, rightMargin);
      ObjectSetInteger(0, btnVLinesName, OBJPROP_YDISTANCE, topMargin + (buttonHeight + verticalGap) * 15);
      ObjectSetInteger(0, btnVLinesName, OBJPROP_XSIZE, buttonWidth);
      ObjectSetInteger(0, btnVLinesName, OBJPROP_YSIZE, buttonHeight);
      ObjectSetInteger(0, btnVLinesName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetString(0, btnVLinesName, OBJPROP_TEXT, "VLines: ON");
      ObjectSetInteger(0, btnVLinesName, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, btnVLinesName, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, btnVLinesName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, btnVLinesName, OBJPROP_HIDDEN, false);
   }
   
   // Button 16: Toggle HLines
   string btnHLinesName = "BtnToggleHLines";
   if(ObjectFind(0, btnHLinesName) < 0) {
      ObjectCreate(0, btnHLinesName, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, btnHLinesName, OBJPROP_XDISTANCE, rightMargin);
      ObjectSetInteger(0, btnHLinesName, OBJPROP_YDISTANCE, topMargin + (buttonHeight + verticalGap) * 16);
      ObjectSetInteger(0, btnHLinesName, OBJPROP_XSIZE, buttonWidth);
      ObjectSetInteger(0, btnHLinesName, OBJPROP_YSIZE, buttonHeight);
      ObjectSetInteger(0, btnHLinesName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetString(0, btnHLinesName, OBJPROP_TEXT, "HLines: ON");
      ObjectSetInteger(0, btnHLinesName, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, btnHLinesName, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, btnHLinesName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, btnHLinesName, OBJPROP_HIDDEN, false);
   }
   
   UpdateButtonStates();
}

void UpdateButtonStates() {
   // Ensure permanent control button is always visible and update its state
   if(ObjectFind(0, "BtnVisibilityControls") >= 0) {
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_HIDDEN, false);
      ObjectSetString(0, "BtnVisibilityControls", OBJPROP_TEXT, g_showMainButtons ? "HIDE BUTTONS" : "SHOW BUTTONS");
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_BGCOLOR, g_showMainButtons ? clrDarkRed : clrDarkGreen);
   }
   
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
   
   // Update Button 4: Lines Control - Shows panel for line types
   string btn4Name = "BtnLinesControl";
   // Count how many line types are visible
   int lineCount = 0;
   if(g_showVLines) lineCount++;
   if(g_showHLines) lineCount++;
   if(g_showNextLevelLines) lineCount++;
   if(g_showOrderLabelsCtrl) lineCount++;
   
   if(lineCount == 4) {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, "Lines [ALL ON]");
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkGreen);
   } else if(lineCount == 0) {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, "Lines Control");
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkGray);
   } else {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, StringFormat("Lines [%d/4]", lineCount));
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkOrange);
   }
   ObjectSetInteger(0, btn4Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn4Name, OBJPROP_STATE, false);
   
   // Update Button 5: Toggle Labels (Info Labels)
   string btn11Name = "BtnToggleLabels";
   if(g_showLabels) {
      ObjectSetString(0, btn11Name, OBJPROP_TEXT, "Labels [ON]");
      ObjectSetInteger(0, btn11Name, OBJPROP_BGCOLOR, clrGreen);
      ObjectSetInteger(0, btn11Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn11Name, OBJPROP_STATE, true);
   } else {
      ObjectSetString(0, btn11Name, OBJPROP_TEXT, "Show Labels");
      ObjectSetInteger(0, btn11Name, OBJPROP_BGCOLOR, clrDarkGray);
      ObjectSetInteger(0, btn11Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn11Name, OBJPROP_STATE, false);
   }
   
   // Update Button 6: Print Stats (always same appearance)
   string btn6Name = "BtnPrintStats";
   ObjectSetString(0, btn6Name, OBJPROP_TEXT, "Print Stats");
   ObjectSetInteger(0, btn6Name, OBJPROP_BGCOLOR, clrDarkBlue);
   ObjectSetInteger(0, btn6Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn6Name, OBJPROP_STATE, false);
   
   // Update Button 7: Debug Level
   string btn7Name = "BtnDebugLevel";
   string debugText = "";
   color debugColor = clrDarkGray;
   
   switch(g_currentDebugLevel) {
      case 0:
         debugText = "Debug: OFF";
         debugColor = clrDarkGray;
         break;
      case 1:
         debugText = "Debug: CRITICAL";
         debugColor = clrDarkRed;
         break;
      case 2:
         debugText = "Debug: INFO";
         debugColor = clrDarkOrange;
         break;
      case 3:
         debugText = "Debug: VERBOSE";
         debugColor = clrDarkGreen;
         break;
      default:
         debugText = StringFormat("Debug: %d", g_currentDebugLevel);
         debugColor = clrDarkBlue;
         break;
   }
   
   ObjectSetString(0, btn7Name, OBJPROP_TEXT, debugText);
   ObjectSetInteger(0, btn7Name, OBJPROP_BGCOLOR, debugColor);
   ObjectSetInteger(0, btn7Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn7Name, OBJPROP_STATE, false);
   
   // Update Button 8: Single Trail Mode
   string btn8Name = "BtnSingleTrail";
   string trailText = "";
   color trailColor = clrDarkBlue;
   
   switch(g_singleTrailMode) {
      case 0:
         trailText = "STrail: TIGHT";
         trailColor = clrDarkRed;  // Closes sooner
         break;
      case 1:
         trailText = "STrail: NORMAL";
         trailColor = clrDarkBlue;  // Default
         break;
      case 2:
         trailText = "STrail: LOOSE";
         trailColor = clrDarkGreen;  // Trails longer
         break;
      default:
         trailText = StringFormat("STrail: %d", g_singleTrailMode);
         trailColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn8Name, OBJPROP_TEXT, trailText);
   ObjectSetInteger(0, btn8Name, OBJPROP_BGCOLOR, trailColor);
   ObjectSetInteger(0, btn8Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn8Name, OBJPROP_STATE, false);
   
   // Update Button 9: Total Trail Mode
   string btn9Name = "BtnTotalTrail";
   string totalTrailText = "";
   color totalTrailColor = clrDarkBlue;
   
   switch(g_totalTrailMode) {
      case 0:
         totalTrailText = "TTrail: TIGHT";
         totalTrailColor = clrDarkRed;  // Closes sooner
         break;
      case 1:
         totalTrailText = "TTrail: NORMAL";
         totalTrailColor = clrDarkBlue;  // Default
         break;
      case 2:
         totalTrailText = "TTrail: LOOSE";
         totalTrailColor = clrDarkGreen;  // Trails longer
         break;
      default:
         totalTrailText = StringFormat("TTrail: %d", g_totalTrailMode);
         totalTrailColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn9Name, OBJPROP_TEXT, totalTrailText);
   ObjectSetInteger(0, btn9Name, OBJPROP_BGCOLOR, totalTrailColor);
   ObjectSetInteger(0, btn9Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn9Name, OBJPROP_STATE, false);
   
   // Update History Mode button
   switch(g_historyDisplayMode) {
      case 0:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:Overall");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkGreen);
         break;
      case 1:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:SymAll");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkCyan);
         break;
      case 2:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:SymMag");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkOrange);
         break;
      case 3:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:PerSym");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkViolet);
         break;
      default:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:Overall");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkGreen);
         break;
   }
   
   // Update Button 10: Trail Method Strategy
   string btn10Name = "BtnTrailMethod";
   string methodText = "";
   color methodColor = clrDarkSlateGray;
   
   // Show single trail activation status
   string singleStatus = "";
   switch(SingleTrailActivation) {
      case SINGLE_ACTIVATION_IGNORE:  singleStatus = "OFF"; break;
      case SINGLE_ACTIVATION_PROFIT:  singleStatus = "PROFIT"; break;
      case SINGLE_ACTIVATION_LEVEL:   singleStatus = "LEVEL"; break;
      default: singleStatus = "?"; break;
   }
   
   // Show group trail method
   switch(g_currentGroupTrailMethod) {
      case GROUP_TRAIL_IGNORE:
         methodText = StringFormat("S-%s G-OFF", singleStatus);
         methodColor = clrDarkSlateGray;
         break;
      case GROUP_TRAIL_CLOSETOGETHER:
         methodText = StringFormat("S-%s G-ANY", singleStatus);
         methodColor = clrDarkOliveGreen;
         break;
      case GROUP_TRAIL_CLOSETOGETHER_SAMETYPE:
         methodText = StringFormat("S-%s G-SAME", singleStatus);
         methodColor = clrDarkCyan;
         break;
      case GROUP_TRAIL_DYNAMIC:
         methodText = StringFormat("S-%s G-DYN", singleStatus);
         methodColor = clrDarkMagenta;
         break;
      case GROUP_TRAIL_DYNAMIC_SAMETYPE:
         methodText = StringFormat("S-%s G-DYNS", singleStatus);
         methodColor = clrDarkViolet;
         break;
      case GROUP_TRAIL_DYNAMIC_ANYSIDE:
         methodText = StringFormat("S-%s G-DYNA", singleStatus);
         methodColor = clrIndigo;
         break;
      case GROUP_TRAIL_HYBRID_BALANCED:
         methodText = StringFormat("S-%s G-BAL", singleStatus);
         methodColor = clrDarkOrange;
         break;
      case GROUP_TRAIL_HYBRID_ADAPTIVE:
         methodText = StringFormat("S-%s G-ADP", singleStatus);
         methodColor = clrSaddleBrown;
         break;
      case GROUP_TRAIL_HYBRID_SMART:
         methodText = StringFormat("S-%s G-SMT", singleStatus);
         methodColor = clrDarkGoldenrod;
         break;
      case GROUP_TRAIL_HYBRID_COUNT_DIFF:
         methodText = StringFormat("S-%s G-CNT", singleStatus);
         methodColor = clrMaroon;
         break;
      default:
         methodText = StringFormat("S-%s G-%d", singleStatus, g_currentGroupTrailMethod);
         methodColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn10Name, OBJPROP_TEXT, methodText);
   ObjectSetInteger(0, btn10Name, OBJPROP_BGCOLOR, methodColor);
   ObjectSetInteger(0, btn10Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn10Name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btn10Name, OBJPROP_HIDDEN, false);
   
   // Update Button 11: Order Labels (deprecated - now in Lines Control)
   string btnOldOrderLabels = "BtnOrderLabels";
   if(g_showOrderLabels) {
      ObjectSetString(0, btnOldOrderLabels, OBJPROP_TEXT, "Order Labels: ON");
      ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnOldOrderLabels, OBJPROP_TEXT, "Order Labels: OFF");
      ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_HIDDEN, false);
   
   // Update Button 12: Reset Counters (always same appearance)
   string btn12Name = "BtnResetCounters";
   ObjectSetString(0, btn12Name, OBJPROP_TEXT, "Reset (3x click)");
   ObjectSetInteger(0, btn12Name, OBJPROP_BGCOLOR, clrDarkOrange);
   ObjectSetInteger(0, btn12Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn12Name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btn12Name, OBJPROP_HIDDEN, false);
   
   // Update Button 15: Toggle VLines
   string btnVLines = "BtnToggleVLines";
   if(g_showVLines) {
      ObjectSetString(0, btnVLines, OBJPROP_TEXT, "VLines: ON");
      ObjectSetInteger(0, btnVLines, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnVLines, OBJPROP_TEXT, "VLines: OFF");
      ObjectSetInteger(0, btnVLines, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnVLines, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnVLines, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnVLines, OBJPROP_HIDDEN, false);
   
   // Update Button 16: Toggle HLines
   string btnHLines = "BtnToggleHLines";
   if(g_showHLines) {
      ObjectSetString(0, btnHLines, OBJPROP_TEXT, "HLines: ON");
      ObjectSetInteger(0, btnHLines, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnHLines, OBJPROP_TEXT, "HLines: OFF");
      ObjectSetInteger(0, btnHLines, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnHLines, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnHLines, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnHLines, OBJPROP_HIDDEN, false);
   
   UpdateButtonStates();
}

void UpdateButtonStates() {
   // Ensure permanent control button is always visible and update its state
   if(ObjectFind(0, "BtnVisibilityControls") >= 0) {
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_HIDDEN, false);
      ObjectSetString(0, "BtnVisibilityControls", OBJPROP_TEXT, g_showMainButtons ? "HIDE BUTTONS" : "SHOW BUTTONS");
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_BGCOLOR, g_showMainButtons ? clrDarkRed : clrDarkGreen);
   }
   
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
   
   // Update Button 4: Lines Control - Shows panel for line types
   string btn4Name = "BtnLinesControl";
   // Count how many line types are visible
   int lineCount = 0;
   if(g_showVLines) lineCount++;
   if(g_showHLines) lineCount++;
   if(g_showNextLevelLines) lineCount++;
   if(g_showOrderLabelsCtrl) lineCount++;
   
   if(lineCount == 4) {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, "Lines [ALL ON]");
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkGreen);
   } else if(lineCount == 0) {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, "Lines Control");
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkGray);
   } else {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, StringFormat("Lines [%d/4]", lineCount));
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkOrange);
   }
   ObjectSetInteger(0, btn4Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn4Name, OBJPROP_STATE, false);
   
   // Update Button 5: Toggle Labels (Info Labels)
   string btn11Name = "BtnToggleLabels";
   if(g_showLabels) {
      ObjectSetString(0, btn11Name, OBJPROP_TEXT, "Labels [ON]");
      ObjectSetInteger(0, btn11Name, OBJPROP_BGCOLOR, clrGreen);
      ObjectSetInteger(0, btn11Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn11Name, OBJPROP_STATE, true);
   } else {
      ObjectSetString(0, btn11Name, OBJPROP_TEXT, "Show Labels");
      ObjectSetInteger(0, btn11Name, OBJPROP_BGCOLOR, clrDarkGray);
      ObjectSetInteger(0, btn11Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn11Name, OBJPROP_STATE, false);
   }
   
   // Update Button 6: Print Stats (always same appearance)
   string btn6Name = "BtnPrintStats";
   ObjectSetString(0, btn6Name, OBJPROP_TEXT, "Print Stats");
   ObjectSetInteger(0, btn6Name, OBJPROP_BGCOLOR, clrDarkBlue);
   ObjectSetInteger(0, btn6Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn6Name, OBJPROP_STATE, false);
   
   // Update Button 7: Debug Level
   string btn7Name = "BtnDebugLevel";
   string debugText = "";
   color debugColor = clrDarkGray;
   
   switch(g_currentDebugLevel) {
      case 0:
         debugText = "Debug: OFF";
         debugColor = clrDarkGray;
         break;
      case 1:
         debugText = "Debug: CRITICAL";
         debugColor = clrDarkRed;
         break;
      case 2:
         debugText = "Debug: INFO";
         debugColor = clrDarkOrange;
         break;
      case 3:
         debugText = "Debug: VERBOSE";
         debugColor = clrDarkGreen;
         break;
      default:
         debugText = StringFormat("Debug: %d", g_currentDebugLevel);
         debugColor = clrDarkBlue;
         break;
   }
   
   ObjectSetString(0, btn7Name, OBJPROP_TEXT, debugText);
   ObjectSetInteger(0, btn7Name, OBJPROP_BGCOLOR, debugColor);
   ObjectSetInteger(0, btn7Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn7Name, OBJPROP_STATE, false);
   
   // Update Button 8: Single Trail Mode
   string btn8Name = "BtnSingleTrail";
   string trailText = "";
   color trailColor = clrDarkBlue;
   
   switch(g_singleTrailMode) {
      case 0:
         trailText = "STrail: TIGHT";
         trailColor = clrDarkRed;  // Closes sooner
         break;
      case 1:
         trailText = "STrail: NORMAL";
         trailColor = clrDarkBlue;  // Default
         break;
      case 2:
         trailText = "STrail: LOOSE";
         trailColor = clrDarkGreen;  // Trails longer
         break;
      default:
         trailText = StringFormat("STrail: %d", g_singleTrailMode);
         trailColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn8Name, OBJPROP_TEXT, trailText);
   ObjectSetInteger(0, btn8Name, OBJPROP_BGCOLOR, trailColor);
   ObjectSetInteger(0, btn8Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn8Name, OBJPROP_STATE, false);
   
   // Update Button 9: Total Trail Mode
   string btn9Name = "BtnTotalTrail";
   string totalTrailText = "";
   color totalTrailColor = clrDarkBlue;
   
   switch(g_totalTrailMode) {
      case 0:
         totalTrailText = "TTrail: TIGHT";
         totalTrailColor = clrDarkRed;  // Closes sooner
         break;
      case 1:
         totalTrailText = "TTrail: NORMAL";
         totalTrailColor = clrDarkBlue;  // Default
         break;
      case 2:
         totalTrailText = "TTrail: LOOSE";
         totalTrailColor = clrDarkGreen;  // Trails longer
         break;
      default:
         totalTrailText = StringFormat("TTrail: %d", g_totalTrailMode);
         totalTrailColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn9Name, OBJPROP_TEXT, totalTrailText);
   ObjectSetInteger(0, btn9Name, OBJPROP_BGCOLOR, totalTrailColor);
   ObjectSetInteger(0, btn9Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn9Name, OBJPROP_STATE, false);
   
   // Update History Mode button
   switch(g_historyDisplayMode) {
      case 0:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:Overall");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkGreen);
         break;
      case 1:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:SymAll");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkCyan);
         break;
      case 2:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:SymMag");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkOrange);
         break;
      case 3:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:PerSym");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkViolet);
         break;
      default:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:Overall");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkGreen);
         break;
   }
   
   // Update Button 10: Trail Method Strategy
   string btn10Name = "BtnTrailMethod";
   string methodText = "";
   color methodColor = clrDarkSlateGray;
   
   // Show single trail activation status
   string singleStatus = "";
   switch(SingleTrailActivation) {
      case SINGLE_ACTIVATION_IGNORE:  singleStatus = "OFF"; break;
      case SINGLE_ACTIVATION_PROFIT:  singleStatus = "PROFIT"; break;
      case SINGLE_ACTIVATION_LEVEL:   singleStatus = "LEVEL"; break;
      default: singleStatus = "?"; break;
   }
   
   // Show group trail method
   switch(g_currentGroupTrailMethod) {
      case GROUP_TRAIL_IGNORE:
         methodText = StringFormat("S-%s G-OFF", singleStatus);
         methodColor = clrDarkSlateGray;
         break;
      case GROUP_TRAIL_CLOSETOGETHER:
         methodText = StringFormat("S-%s G-ANY", singleStatus);
         methodColor = clrDarkOliveGreen;
         break;
      case GROUP_TRAIL_CLOSETOGETHER_SAMETYPE:
         methodText = StringFormat("S-%s G-SAME", singleStatus);
         methodColor = clrDarkCyan;
         break;
      case GROUP_TRAIL_DYNAMIC:
         methodText = StringFormat("S-%s G-DYN", singleStatus);
         methodColor = clrDarkMagenta;
         break;
      case GROUP_TRAIL_DYNAMIC_SAMETYPE:
         methodText = StringFormat("S-%s G-DYNS", singleStatus);
         methodColor = clrDarkViolet;
         break;
      case GROUP_TRAIL_DYNAMIC_ANYSIDE:
         methodText = StringFormat("S-%s G-DYNA", singleStatus);
         methodColor = clrIndigo;
         break;
      case GROUP_TRAIL_HYBRID_BALANCED:
         methodText = StringFormat("S-%s G-BAL", singleStatus);
         methodColor = clrDarkOrange;
         break;
      case GROUP_TRAIL_HYBRID_ADAPTIVE:
         methodText = StringFormat("S-%s G-ADP", singleStatus);
         methodColor = clrSaddleBrown;
         break;
      case GROUP_TRAIL_HYBRID_SMART:
         methodText = StringFormat("S-%s G-SMT", singleStatus);
         methodColor = clrDarkGoldenrod;
         break;
      case GROUP_TRAIL_HYBRID_COUNT_DIFF:
         methodText = StringFormat("S-%s G-CNT", singleStatus);
         methodColor = clrMaroon;
         break;
      default:
         methodText = StringFormat("S-%s G-%d", singleStatus, g_currentGroupTrailMethod);
         methodColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn10Name, OBJPROP_TEXT, methodText);
   ObjectSetInteger(0, btn10Name, OBJPROP_BGCOLOR, methodColor);
   ObjectSetInteger(0, btn10Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn10Name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btn10Name, OBJPROP_HIDDEN, false);
   
   // Update Button 11: Order Labels (deprecated - now in Lines Control)
   string btnOldOrderLabels = "BtnOrderLabels";
   if(g_showOrderLabels) {
      ObjectSetString(0, btnOldOrderLabels, OBJPROP_TEXT, "Order Labels: ON");
      ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnOldOrderLabels, OBJPROP_TEXT, "Order Labels: OFF");
      ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_HIDDEN, false);
   
   // Update Button 12: Reset Counters (always same appearance)
   string btn12Name = "BtnResetCounters";
   ObjectSetString(0, btn12Name, OBJPROP_TEXT, "Reset (3x click)");
   ObjectSetInteger(0, btn12Name, OBJPROP_BGCOLOR, clrDarkOrange);
   ObjectSetInteger(0, btn12Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn12Name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btn12Name, OBJPROP_HIDDEN, false);
   
   // Update Button 15: Toggle VLines
   string btnVLines = "BtnToggleVLines";
   if(g_showVLines) {
      ObjectSetString(0, btnVLines, OBJPROP_TEXT, "VLines: ON");
      ObjectSetInteger(0, btnVLines, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnVLines, OBJPROP_TEXT, "VLines: OFF");
      ObjectSetInteger(0, btnVLines, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnVLines, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnVLines, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnVLines, OBJPROP_HIDDEN, false);
   
   // Update Button 16: Toggle HLines
   string btnHLines = "BtnToggleHLines";
   if(g_showHLines) {
      ObjectSetString(0, btnHLines, OBJPROP_TEXT, "HLines: ON");
      ObjectSetInteger(0, btnHLines, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnHLines, OBJPROP_TEXT, "HLines: OFF");
      ObjectSetInteger(0, btnHLines, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnHLines, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnHLines, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnHLines, OBJPROP_HIDDEN, false);
   
   UpdateButtonStates();
}

void UpdateButtonStates() {
   // Ensure permanent control button is always visible and update its state
   if(ObjectFind(0, "BtnVisibilityControls") >= 0) {
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_HIDDEN, false);
      ObjectSetString(0, "BtnVisibilityControls", OBJPROP_TEXT, g_showMainButtons ? "HIDE BUTTONS" : "SHOW BUTTONS");
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_BGCOLOR, g_showMainButtons ? clrDarkRed : clrDarkGreen);
   }
   
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
   
   // Update Button 4: Lines Control - Shows panel for line types
   string btn4Name = "BtnLinesControl";
   // Count how many line types are visible
   int lineCount = 0;
   if(g_showVLines) lineCount++;
   if(g_showHLines) lineCount++;
   if(g_showNextLevelLines) lineCount++;
   if(g_showOrderLabelsCtrl) lineCount++;
   
   if(lineCount == 4) {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, "Lines [ALL ON]");
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkGreen);
   } else if(lineCount == 0) {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, "Lines Control");
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkGray);
   } else {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, StringFormat("Lines [%d/4]", lineCount));
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkOrange);
   }
   ObjectSetInteger(0, btn4Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn4Name, OBJPROP_STATE, false);
   
   // Update Button 5: Toggle Labels (Info Labels)
   string btn11Name = "BtnToggleLabels";
   if(g_showLabels) {
      ObjectSetString(0, btn11Name, OBJPROP_TEXT, "Labels [ON]");
      ObjectSetInteger(0, btn11Name, OBJPROP_BGCOLOR, clrGreen);
      ObjectSetInteger(0, btn11Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn11Name, OBJPROP_STATE, true);
   } else {
      ObjectSetString(0, btn11Name, OBJPROP_TEXT, "Show Labels");
      ObjectSetInteger(0, btn11Name, OBJPROP_BGCOLOR, clrDarkGray);
      ObjectSetInteger(0, btn11Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn11Name, OBJPROP_STATE, false);
   }
   
   // Update Button 6: Print Stats (always same appearance)
   string btn6Name = "BtnPrintStats";
   ObjectSetString(0, btn6Name, OBJPROP_TEXT, "Print Stats");
   ObjectSetInteger(0, btn6Name, OBJPROP_BGCOLOR, clrDarkBlue);
   ObjectSetInteger(0, btn6Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn6Name, OBJPROP_STATE, false);
   
   // Update Button 7: Debug Level
   string btn7Name = "BtnDebugLevel";
   string debugText = "";
   color debugColor = clrDarkGray;
   
   switch(g_currentDebugLevel) {
      case 0:
         debugText = "Debug: OFF";
         debugColor = clrDarkGray;
         break;
      case 1:
         debugText = "Debug: CRITICAL";
         debugColor = clrDarkRed;
         break;
      case 2:
         debugText = "Debug: INFO";
         debugColor = clrDarkOrange;
         break;
      case 3:
         debugText = "Debug: VERBOSE";
         debugColor = clrDarkGreen;
         break;
      default:
         debugText = StringFormat("Debug: %d", g_currentDebugLevel);
         debugColor = clrDarkBlue;
         break;
   }
   
   ObjectSetString(0, btn7Name, OBJPROP_TEXT, debugText);
   ObjectSetInteger(0, btn7Name, OBJPROP_BGCOLOR, debugColor);
   ObjectSetInteger(0, btn7Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn7Name, OBJPROP_STATE, false);
   
   // Update Button 8: Single Trail Mode
   string btn8Name = "BtnSingleTrail";
   string trailText = "";
   color trailColor = clrDarkBlue;
   
   switch(g_singleTrailMode) {
      case 0:
         trailText = "STrail: TIGHT";
         trailColor = clrDarkRed;  // Closes sooner
         break;
      case 1:
         trailText = "STrail: NORMAL";
         trailColor = clrDarkBlue;  // Default
         break;
      case 2:
         trailText = "STrail: LOOSE";
         trailColor = clrDarkGreen;  // Trails longer
         break;
      default:
         trailText = StringFormat("STrail: %d", g_singleTrailMode);
         trailColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn8Name, OBJPROP_TEXT, trailText);
   ObjectSetInteger(0, btn8Name, OBJPROP_BGCOLOR, trailColor);
   ObjectSetInteger(0, btn8Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn8Name, OBJPROP_STATE, false);
   
   // Update Button 9: Total Trail Mode
   string btn9Name = "BtnTotalTrail";
   string totalTrailText = "";
   color totalTrailColor = clrDarkBlue;
   
   switch(g_totalTrailMode) {
      case 0:
         totalTrailText = "TTrail: TIGHT";
         totalTrailColor = clrDarkRed;  // Closes sooner
         break;
      case 1:
         totalTrailText = "TTrail: NORMAL";
         totalTrailColor = clrDarkBlue;  // Default
         break;
      case 2:
         totalTrailText = "TTrail: LOOSE";
         totalTrailColor = clrDarkGreen;  // Trails longer
         break;
      default:
         totalTrailText = StringFormat("TTrail: %d", g_totalTrailMode);
         totalTrailColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn9Name, OBJPROP_TEXT, totalTrailText);
   ObjectSetInteger(0, btn9Name, OBJPROP_BGCOLOR, totalTrailColor);
   ObjectSetInteger(0, btn9Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn9Name, OBJPROP_STATE, false);
   
   // Update History Mode button
   switch(g_historyDisplayMode) {
      case 0:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:Overall");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkGreen);
         break;
      case 1:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:SymAll");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkCyan);
         break;
      case 2:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:SymMag");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkOrange);
         break;
      case 3:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:PerSym");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkViolet);
         break;
      default:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:Overall");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkGreen);
         break;
   }
   
   // Update Button 10: Trail Method Strategy
   string btn10Name = "BtnTrailMethod";
   string methodText = "";
   color methodColor = clrDarkSlateGray;
   
   // Show single trail activation status
   string singleStatus = "";
   switch(SingleTrailActivation) {
      case SINGLE_ACTIVATION_IGNORE:  singleStatus = "OFF"; break;
      case SINGLE_ACTIVATION_PROFIT:  singleStatus = "PROFIT"; break;
      case SINGLE_ACTIVATION_LEVEL:   singleStatus = "LEVEL"; break;
      default: singleStatus = "?"; break;
   }
   
   // Show group trail method
   switch(g_currentGroupTrailMethod) {
      case GROUP_TRAIL_IGNORE:
         methodText = StringFormat("S-%s G-OFF", singleStatus);
         methodColor = clrDarkSlateGray;
         break;
      case GROUP_TRAIL_CLOSETOGETHER:
         methodText = StringFormat("S-%s G-ANY", singleStatus);
         methodColor = clrDarkOliveGreen;
         break;
      case GROUP_TRAIL_CLOSETOGETHER_SAMETYPE:
         methodText = StringFormat("S-%s G-SAME", singleStatus);
         methodColor = clrDarkCyan;
         break;
      case GROUP_TRAIL_DYNAMIC:
         methodText = StringFormat("S-%s G-DYN", singleStatus);
         methodColor = clrDarkMagenta;
         break;
      case GROUP_TRAIL_DYNAMIC_SAMETYPE:
         methodText = StringFormat("S-%s G-DYNS", singleStatus);
         methodColor = clrDarkViolet;
         break;
      case GROUP_TRAIL_DYNAMIC_ANYSIDE:
         methodText = StringFormat("S-%s G-DYNA", singleStatus);
         methodColor = clrIndigo;
         break;
      case GROUP_TRAIL_HYBRID_BALANCED:
         methodText = StringFormat("S-%s G-BAL", singleStatus);
         methodColor = clrDarkOrange;
         break;
      case GROUP_TRAIL_HYBRID_ADAPTIVE:
         methodText = StringFormat("S-%s G-ADP", singleStatus);
         methodColor = clrSaddleBrown;
         break;
      case GROUP_TRAIL_HYBRID_SMART:
         methodText = StringFormat("S-%s G-SMT", singleStatus);
         methodColor = clrDarkGoldenrod;
         break;
      case GROUP_TRAIL_HYBRID_COUNT_DIFF:
         methodText = StringFormat("S-%s G-CNT", singleStatus);
         methodColor = clrMaroon;
         break;
      default:
         methodText = StringFormat("S-%s G-%d", singleStatus, g_currentGroupTrailMethod);
         methodColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn10Name, OBJPROP_TEXT, methodText);
   ObjectSetInteger(0, btn10Name, OBJPROP_BGCOLOR, methodColor);
   ObjectSetInteger(0, btn10Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn10Name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btn10Name, OBJPROP_HIDDEN, false);
   
   // Update Button 11: Order Labels (deprecated - now in Lines Control)
   string btnOldOrderLabels = "BtnOrderLabels";
   if(g_showOrderLabels) {
      ObjectSetString(0, btnOldOrderLabels, OBJPROP_TEXT, "Order Labels: ON");
      ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnOldOrderLabels, OBJPROP_TEXT, "Order Labels: OFF");
      ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_HIDDEN, false);
   
   // Update Button 12: Reset Counters (always same appearance)
   string btn12Name = "BtnResetCounters";
   ObjectSetString(0, btn12Name, OBJPROP_TEXT, "Reset (3x click)");
   ObjectSetInteger(0, btn12Name, OBJPROP_BGCOLOR, clrDarkOrange);
   ObjectSetInteger(0, btn12Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn12Name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btn12Name, OBJPROP_HIDDEN, false);
   
   // Update Button 15: Toggle VLines
   string btnVLines = "BtnToggleVLines";
   if(g_showVLines) {
      ObjectSetString(0, btnVLines, OBJPROP_TEXT, "VLines: ON");
      ObjectSetInteger(0, btnVLines, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnVLines, OBJPROP_TEXT, "VLines: OFF");
      ObjectSetInteger(0, btnVLines, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnVLines, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnVLines, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnVLines, OBJPROP_HIDDEN, false);
   
   // Update Button 16: Toggle HLines
   string btnHLines = "BtnToggleHLines";
   if(g_showHLines) {
      ObjectSetString(0, btnHLines, OBJPROP_TEXT, "HLines: ON");
      ObjectSetInteger(0, btnHLines, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnHLines, OBJPROP_TEXT, "HLines: OFF");
      ObjectSetInteger(0, btnHLines, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnHLines, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnHLines, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnHLines, OBJPROP_HIDDEN, false);
   
   UpdateButtonStates();
}

void UpdateButtonStates() {
   // Ensure permanent control button is always visible and update its state
   if(ObjectFind(0, "BtnVisibilityControls") >= 0) {
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_HIDDEN, false);
      ObjectSetString(0, "BtnVisibilityControls", OBJPROP_TEXT, g_showMainButtons ? "HIDE BUTTONS" : "SHOW BUTTONS");
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_BGCOLOR, g_showMainButtons ? clrDarkRed : clrDarkGreen);
   }
   
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
   
   // Update Button 4: Lines Control - Shows panel for line types
   string btn4Name = "BtnLinesControl";
   // Count how many line types are visible
   int lineCount = 0;
   if(g_showVLines) lineCount++;
   if(g_showHLines) lineCount++;
   if(g_showNextLevelLines) lineCount++;
   if(g_showOrderLabelsCtrl) lineCount++;
   
   if(lineCount == 4) {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, "Lines [ALL ON]");
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkGreen);
   } else if(lineCount == 0) {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, "Lines Control");
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkGray);
   } else {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, StringFormat("Lines [%d/4]", lineCount));
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkOrange);
   }
   ObjectSetInteger(0, btn4Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn4Name, OBJPROP_STATE, false);
   
   // Update Button 5: Toggle Labels (Info Labels)
   string btn11Name = "BtnToggleLabels";
   if(g_showLabels) {
      ObjectSetString(0, btn11Name, OBJPROP_TEXT, "Labels [ON]");
      ObjectSetInteger(0, btn11Name, OBJPROP_BGCOLOR, clrGreen);
      ObjectSetInteger(0, btn11Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn11Name, OBJPROP_STATE, true);
   } else {
      ObjectSetString(0, btn11Name, OBJPROP_TEXT, "Show Labels");
      ObjectSetInteger(0, btn11Name, OBJPROP_BGCOLOR, clrDarkGray);
      ObjectSetInteger(0, btn11Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn11Name, OBJPROP_STATE, false);
   }
   
   // Update Button 6: Print Stats (always same appearance)
   string btn6Name = "BtnPrintStats";
   ObjectSetString(0, btn6Name, OBJPROP_TEXT, "Print Stats");
   ObjectSetInteger(0, btn6Name, OBJPROP_BGCOLOR, clrDarkBlue);
   ObjectSetInteger(0, btn6Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn6Name, OBJPROP_STATE, false);
   
   // Update Button 7: Debug Level
   string btn7Name = "BtnDebugLevel";
   string debugText = "";
   color debugColor = clrDarkGray;
   
   switch(g_currentDebugLevel) {
      case 0:
         debugText = "Debug: OFF";
         debugColor = clrDarkGray;
         break;
      case 1:
         debugText = "Debug: CRITICAL";
         debugColor = clrDarkRed;
         break;
      case 2:
         debugText = "Debug: INFO";
         debugColor = clrDarkOrange;
         break;
      case 3:
         debugText = "Debug: VERBOSE";
         debugColor = clrDarkGreen;
         break;
      default:
         debugText = StringFormat("Debug: %d", g_currentDebugLevel);
         debugColor = clrDarkBlue;
         break;
   }
   
   ObjectSetString(0, btn7Name, OBJPROP_TEXT, debugText);
   ObjectSetInteger(0, btn7Name, OBJPROP_BGCOLOR, debugColor);
   ObjectSetInteger(0, btn7Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn7Name, OBJPROP_STATE, false);
   
   // Update Button 8: Single Trail Mode
   string btn8Name = "BtnSingleTrail";
   string trailText = "";
   color trailColor = clrDarkBlue;
   
   switch(g_singleTrailMode) {
      case 0:
         trailText = "STrail: TIGHT";
         trailColor = clrDarkRed;  // Closes sooner
         break;
      case 1:
         trailText = "STrail: NORMAL";
         trailColor = clrDarkBlue;  // Default
         break;
      case 2:
         trailText = "STrail: LOOSE";
         trailColor = clrDarkGreen;  // Trails longer
         break;
      default:
         trailText = StringFormat("STrail: %d", g_singleTrailMode);
         trailColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn8Name, OBJPROP_TEXT, trailText);
   ObjectSetInteger(0, btn8Name, OBJPROP_BGCOLOR, trailColor);
   ObjectSetInteger(0, btn8Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn8Name, OBJPROP_STATE, false);
   
   // Update Button 9: Total Trail Mode
   string btn9Name = "BtnTotalTrail";
   string totalTrailText = "";
   color totalTrailColor = clrDarkBlue;
   
   switch(g_totalTrailMode) {
      case 0:
         totalTrailText = "TTrail: TIGHT";
         totalTrailColor = clrDarkRed;  // Closes sooner
         break;
      case 1:
         totalTrailText = "TTrail: NORMAL";
         totalTrailColor = clrDarkBlue;  // Default
         break;
      case 2:
         totalTrailText = "TTrail: LOOSE";
         totalTrailColor = clrDarkGreen;  // Trails longer
         break;
      default:
         totalTrailText = StringFormat("TTrail: %d", g_totalTrailMode);
         totalTrailColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn9Name, OBJPROP_TEXT, totalTrailText);
   ObjectSetInteger(0, btn9Name, OBJPROP_BGCOLOR, totalTrailColor);
   ObjectSetInteger(0, btn9Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn9Name, OBJPROP_STATE, false);
   
   // Update History Mode button
   switch(g_historyDisplayMode) {
      case 0:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:Overall");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkGreen);
         break;
      case 1:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:SymAll");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkCyan);
         break;
      case 2:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:SymMag");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkOrange);
         break;
      case 3:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:PerSym");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkViolet);
         break;
      default:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:Overall");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkGreen);
         break;
   }
   
   // Update Button 10: Trail Method Strategy
   string btn10Name = "BtnTrailMethod";
   string methodText = "";
   color methodColor = clrDarkSlateGray;
   
   // Show single trail activation status
   string singleStatus = "";
   switch(SingleTrailActivation) {
      case SINGLE_ACTIVATION_IGNORE:  singleStatus = "OFF"; break;
      case SINGLE_ACTIVATION_PROFIT:  singleStatus = "PROFIT"; break;
      case SINGLE_ACTIVATION_LEVEL:   singleStatus = "LEVEL"; break;
      default: singleStatus = "?"; break;
   }
   
   // Show group trail method
   switch(g_currentGroupTrailMethod) {
      case GROUP_TRAIL_IGNORE:
         methodText = StringFormat("S-%s G-OFF", singleStatus);
         methodColor = clrDarkSlateGray;
         break;
      case GROUP_TRAIL_CLOSETOGETHER:
         methodText = StringFormat("S-%s G-ANY", singleStatus);
         methodColor = clrDarkOliveGreen;
         break;
      case GROUP_TRAIL_CLOSETOGETHER_SAMETYPE:
         methodText = StringFormat("S-%s G-SAME", singleStatus);
         methodColor = clrDarkCyan;
         break;
      case GROUP_TRAIL_DYNAMIC:
         methodText = StringFormat("S-%s G-DYN", singleStatus);
         methodColor = clrDarkMagenta;
         break;
      case GROUP_TRAIL_DYNAMIC_SAMETYPE:
         methodText = StringFormat("S-%s G-DYNS", singleStatus);
         methodColor = clrDarkViolet;
         break;
      case GROUP_TRAIL_DYNAMIC_ANYSIDE:
         methodText = StringFormat("S-%s G-DYNA", singleStatus);
         methodColor = clrIndigo;
         break;
      case GROUP_TRAIL_HYBRID_BALANCED:
         methodText = StringFormat("S-%s G-BAL", singleStatus);
         methodColor = clrDarkOrange;
         break;
      case GROUP_TRAIL_HYBRID_ADAPTIVE:
         methodText = StringFormat("S-%s G-ADP", singleStatus);
         methodColor = clrSaddleBrown;
         break;
      case GROUP_TRAIL_HYBRID_SMART:
         methodText = StringFormat("S-%s G-SMT", singleStatus);
         methodColor = clrDarkGoldenrod;
         break;
      case GROUP_TRAIL_HYBRID_COUNT_DIFF:
         methodText = StringFormat("S-%s G-CNT", singleStatus);
         methodColor = clrMaroon;
         break;
      default:
         methodText = StringFormat("S-%s G-%d", singleStatus, g_currentGroupTrailMethod);
         methodColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn10Name, OBJPROP_TEXT, methodText);
   ObjectSetInteger(0, btn10Name, OBJPROP_BGCOLOR, methodColor);
   ObjectSetInteger(0, btn10Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn10Name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btn10Name, OBJPROP_HIDDEN, false);
   
   // Update Button 11: Order Labels (deprecated - now in Lines Control)
   string btnOldOrderLabels = "BtnOrderLabels";
   if(g_showOrderLabels) {
      ObjectSetString(0, btnOldOrderLabels, OBJPROP_TEXT, "Order Labels: ON");
      ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnOldOrderLabels, OBJPROP_TEXT, "Order Labels: OFF");
      ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_HIDDEN, false);
   
   // Update Button 12: Reset Counters (always same appearance)
   string btn12Name = "BtnResetCounters";
   ObjectSetString(0, btn12Name, OBJPROP_TEXT, "Reset (3x click)");
   ObjectSetInteger(0, btn12Name, OBJPROP_BGCOLOR, clrDarkOrange);
   ObjectSetInteger(0, btn12Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn12Name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btn12Name, OBJPROP_HIDDEN, false);
   
   // Update Button 15: Toggle VLines
   string btnVLines = "BtnToggleVLines";
   if(g_showVLines) {
      ObjectSetString(0, btnVLines, OBJPROP_TEXT, "VLines: ON");
      ObjectSetInteger(0, btnVLines, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnVLines, OBJPROP_TEXT, "VLines: OFF");
      ObjectSetInteger(0, btnVLines, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnVLines, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnVLines, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnVLines, OBJPROP_HIDDEN, false);
   
   // Update Button 16: Toggle HLines
   string btnHLines = "BtnToggleHLines";
   if(g_showHLines) {
      ObjectSetString(0, btnHLines, OBJPROP_TEXT, "HLines: ON");
      ObjectSetInteger(0, btnHLines, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnHLines, OBJPROP_TEXT, "HLines: OFF");
      ObjectSetInteger(0, btnHLines, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnHLines, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnHLines, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnHLines, OBJPROP_HIDDEN, false);
   
   UpdateButtonStates();
}

void UpdateButtonStates() {
   // Ensure permanent control button is always visible and update its state
   if(ObjectFind(0, "BtnVisibilityControls") >= 0) {
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_HIDDEN, false);
      ObjectSetString(0, "BtnVisibilityControls", OBJPROP_TEXT, g_showMainButtons ? "HIDE BUTTONS" : "SHOW BUTTONS");
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_BGCOLOR, g_showMainButtons ? clrDarkRed : clrDarkGreen);
   }
   
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
   
   // Update Button 4: Lines Control - Shows panel for line types
   string btn4Name = "BtnLinesControl";
   // Count how many line types are visible
   int lineCount = 0;
   if(g_showVLines) lineCount++;
   if(g_showHLines) lineCount++;
   if(g_showNextLevelLines) lineCount++;
   if(g_showOrderLabelsCtrl) lineCount++;
   
   if(lineCount == 4) {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, "Lines [ALL ON]");
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkGreen);
   } else if(lineCount == 0) {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, "Lines Control");
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkGray);
   } else {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, StringFormat("Lines [%d/4]", lineCount));
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkOrange);
   }
   ObjectSetInteger(0, btn4Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn4Name, OBJPROP_STATE, false);
   
   // Update Button 5: Toggle Labels (Info Labels)
   string btn11Name = "BtnToggleLabels";
   if(g_showLabels) {
      ObjectSetString(0, btn11Name, OBJPROP_TEXT, "Labels [ON]");
      ObjectSetInteger(0, btn11Name, OBJPROP_BGCOLOR, clrGreen);
      ObjectSetInteger(0, btn11Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn11Name, OBJPROP_STATE, true);
   } else {
      ObjectSetString(0, btn11Name, OBJPROP_TEXT, "Show Labels");
      ObjectSetInteger(0, btn11Name, OBJPROP_BGCOLOR, clrDarkGray);
      ObjectSetInteger(0, btn11Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn11Name, OBJPROP_STATE, false);
   }
   
   // Update Button 6: Print Stats (always same appearance)
   string btn6Name = "BtnPrintStats";
   ObjectSetString(0, btn6Name, OBJPROP_TEXT, "Print Stats");
   ObjectSetInteger(0, btn6Name, OBJPROP_BGCOLOR, clrDarkBlue);
   ObjectSetInteger(0, btn6Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn6Name, OBJPROP_STATE, false);
   
   // Update Button 7: Debug Level
   string btn7Name = "BtnDebugLevel";
   string debugText = "";
   color debugColor = clrDarkGray;
   
   switch(g_currentDebugLevel) {
      case 0:
         debugText = "Debug: OFF";
         debugColor = clrDarkGray;
         break;
      case 1:
         debugText = "Debug: CRITICAL";
         debugColor = clrDarkRed;
         break;
      case 2:
         debugText = "Debug: INFO";
         debugColor = clrDarkOrange;
         break;
      case 3:
         debugText = "Debug: VERBOSE";
         debugColor = clrDarkGreen;
         break;
      default:
         debugText = StringFormat("Debug: %d", g_currentDebugLevel);
         debugColor = clrDarkBlue;
         break;
   }
   
   ObjectSetString(0, btn7Name, OBJPROP_TEXT, debugText);
   ObjectSetInteger(0, btn7Name, OBJPROP_BGCOLOR, debugColor);
   ObjectSetInteger(0, btn7Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn7Name, OBJPROP_STATE, false);
   
   // Update Button 8: Single Trail Mode
   string btn8Name = "BtnSingleTrail";
   string trailText = "";
   color trailColor = clrDarkBlue;
   
   switch(g_singleTrailMode) {
      case 0:
         trailText = "STrail: TIGHT";
         trailColor = clrDarkRed;  // Closes sooner
         break;
      case 1:
         trailText = "STrail: NORMAL";
         trailColor = clrDarkBlue;  // Default
         break;
      case 2:
         trailText = "STrail: LOOSE";
         trailColor = clrDarkGreen;  // Trails longer
         break;
      default:
         trailText = StringFormat("STrail: %d", g_singleTrailMode);
         trailColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn8Name, OBJPROP_TEXT, trailText);
   ObjectSetInteger(0, btn8Name, OBJPROP_BGCOLOR, trailColor);
   ObjectSetInteger(0, btn8Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn8Name, OBJPROP_STATE, false);
   
   // Update Button 9: Total Trail Mode
   string btn9Name = "BtnTotalTrail";
   string totalTrailText = "";
   color totalTrailColor = clrDarkBlue;
   
   switch(g_totalTrailMode) {
      case 0:
         totalTrailText = "TTrail: TIGHT";
         totalTrailColor = clrDarkRed;  // Closes sooner
         break;
      case 1:
         totalTrailText = "TTrail: NORMAL";
         totalTrailColor = clrDarkBlue;  // Default
         break;
      case 2:
         totalTrailText = "TTrail: LOOSE";
         totalTrailColor = clrDarkGreen;  // Trails longer
         break;
      default:
         totalTrailText = StringFormat("TTrail: %d", g_totalTrailMode);
         totalTrailColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn9Name, OBJPROP_TEXT, totalTrailText);
   ObjectSetInteger(0, btn9Name, OBJPROP_BGCOLOR, totalTrailColor);
   ObjectSetInteger(0, btn9Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn9Name, OBJPROP_STATE, false);
   
   // Update History Mode button
   switch(g_historyDisplayMode) {
      case 0:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:Overall");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkGreen);
         break;
      case 1:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:SymAll");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkCyan);
         break;
      case 2:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:SymMag");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkOrange);
         break;
      case 3:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:PerSym");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkViolet);
         break;
      default:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:Overall");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkGreen);
         break;
   }
   
   // Update Button 10: Trail Method Strategy
   string btn10Name = "BtnTrailMethod";
   string methodText = "";
   color methodColor = clrDarkSlateGray;
   
   // Show single trail activation status
   string singleStatus = "";
   switch(SingleTrailActivation) {
      case SINGLE_ACTIVATION_IGNORE:  singleStatus = "OFF"; break;
      case SINGLE_ACTIVATION_PROFIT:  singleStatus = "PROFIT"; break;
      case SINGLE_ACTIVATION_LEVEL:   singleStatus = "LEVEL"; break;
      default: singleStatus = "?"; break;
   }
   
   // Show group trail method
   switch(g_currentGroupTrailMethod) {
      case GROUP_TRAIL_IGNORE:
         methodText = StringFormat("S-%s G-OFF", singleStatus);
         methodColor = clrDarkSlateGray;
         break;
      case GROUP_TRAIL_CLOSETOGETHER:
         methodText = StringFormat("S-%s G-ANY", singleStatus);
         methodColor = clrDarkOliveGreen;
         break;
      case GROUP_TRAIL_CLOSETOGETHER_SAMETYPE:
         methodText = StringFormat("S-%s G-SAME", singleStatus);
         methodColor = clrDarkCyan;
         break;
      case GROUP_TRAIL_DYNAMIC:
         methodText = StringFormat("S-%s G-DYN", singleStatus);
         methodColor = clrDarkMagenta;
         break;
      case GROUP_TRAIL_DYNAMIC_SAMETYPE:
         methodText = StringFormat("S-%s G-DYNS", singleStatus);
         methodColor = clrDarkViolet;
         break;
      case GROUP_TRAIL_DYNAMIC_ANYSIDE:
         methodText = StringFormat("S-%s G-DYNA", singleStatus);
         methodColor = clrIndigo;
         break;
      case GROUP_TRAIL_HYBRID_BALANCED:
         methodText = StringFormat("S-%s G-BAL", singleStatus);
         methodColor = clrDarkOrange;
         break;
      case GROUP_TRAIL_HYBRID_ADAPTIVE:
         methodText = StringFormat("S-%s G-ADP", singleStatus);
         methodColor = clrSaddleBrown;
         break;
      case GROUP_TRAIL_HYBRID_SMART:
         methodText = StringFormat("S-%s G-SMT", singleStatus);
         methodColor = clrDarkGoldenrod;
         break;
      case GROUP_TRAIL_HYBRID_COUNT_DIFF:
         methodText = StringFormat("S-%s G-CNT", singleStatus);
         methodColor = clrMaroon;
         break;
      default:
         methodText = StringFormat("S-%s G-%d", singleStatus, g_currentGroupTrailMethod);
         methodColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn10Name, OBJPROP_TEXT, methodText);
   ObjectSetInteger(0, btn10Name, OBJPROP_BGCOLOR, methodColor);
   ObjectSetInteger(0, btn10Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn10Name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btn10Name, OBJPROP_HIDDEN, false);
   
   // Update Button 11: Order Labels (deprecated - now in Lines Control)
   string btnOldOrderLabels = "BtnOrderLabels";
   if(g_showOrderLabels) {
      ObjectSetString(0, btnOldOrderLabels, OBJPROP_TEXT, "Order Labels: ON");
      ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnOldOrderLabels, OBJPROP_TEXT, "Order Labels: OFF");
      ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_HIDDEN, false);
   
   // Update Button 12: Reset Counters (always same appearance)
   string btn12Name = "BtnResetCounters";
   ObjectSetString(0, btn12Name, OBJPROP_TEXT, "Reset (3x click)");
   ObjectSetInteger(0, btn12Name, OBJPROP_BGCOLOR, clrDarkOrange);
   ObjectSetInteger(0, btn12Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn12Name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btn12Name, OBJPROP_HIDDEN, false);
   
   // Update Button 15: Toggle VLines
   string btnVLines = "BtnToggleVLines";
   if(g_showVLines) {
      ObjectSetString(0, btnVLines, OBJPROP_TEXT, "VLines: ON");
      ObjectSetInteger(0, btnVLines, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnVLines, OBJPROP_TEXT, "VLines: OFF");
      ObjectSetInteger(0, btnVLines, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnVLines, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnVLines, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnVLines, OBJPROP_HIDDEN, false);
   
   // Update Button 16: Toggle HLines
   string btnHLines = "BtnToggleHLines";
   if(g_showHLines) {
      ObjectSetString(0, btnHLines, OBJPROP_TEXT, "HLines: ON");
      ObjectSetInteger(0, btnHLines, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnHLines, OBJPROP_TEXT, "HLines: OFF");
      ObjectSetInteger(0, btnHLines, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnHLines, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnHLines, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnHLines, OBJPROP_HIDDEN, false);
   
   UpdateButtonStates();
}

void UpdateButtonStates() {
   // Ensure permanent control button is always visible and update its state
   if(ObjectFind(0, "BtnVisibilityControls") >= 0) {
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_HIDDEN, false);
      ObjectSetString(0, "BtnVisibilityControls", OBJPROP_TEXT, g_showMainButtons ? "HIDE BUTTONS" : "SHOW BUTTONS");
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_BGCOLOR, g_showMainButtons ? clrDarkRed : clrDarkGreen);
   }
   
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
   
   // Update Button 4: Lines Control - Shows panel for line types
   string btn4Name = "BtnLinesControl";
   // Count how many line types are visible
   int lineCount = 0;
   if(g_showVLines) lineCount++;
   if(g_showHLines) lineCount++;
   if(g_showNextLevelLines) lineCount++;
   if(g_showOrderLabelsCtrl) lineCount++;
   
   if(lineCount == 4) {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, "Lines [ALL ON]");
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkGreen);
   } else if(lineCount == 0) {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, "Lines Control");
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkGray);
   } else {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, StringFormat("Lines [%d/4]", lineCount));
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkOrange);
   }
   ObjectSetInteger(0, btn4Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn4Name, OBJPROP_STATE, false);
   
   // Update Button 5: Toggle Labels (Info Labels)
   string btn11Name = "BtnToggleLabels";
   if(g_showLabels) {
      ObjectSetString(0, btn11Name, OBJPROP_TEXT, "Labels [ON]");
      ObjectSetInteger(0, btn11Name, OBJPROP_BGCOLOR, clrGreen);
      ObjectSetInteger(0, btn11Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn11Name, OBJPROP_STATE, true);
   } else {
      ObjectSetString(0, btn11Name, OBJPROP_TEXT, "Show Labels");
      ObjectSetInteger(0, btn11Name, OBJPROP_BGCOLOR, clrDarkGray);
      ObjectSetInteger(0, btn11Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn11Name, OBJPROP_STATE, false);
   }
   
   // Update Button 6: Print Stats (always same appearance)
   string btn6Name = "BtnPrintStats";
   ObjectSetString(0, btn6Name, OBJPROP_TEXT, "Print Stats");
   ObjectSetInteger(0, btn6Name, OBJPROP_BGCOLOR, clrDarkBlue);
   ObjectSetInteger(0, btn6Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn6Name, OBJPROP_STATE, false);
   
   // Update Button 7: Debug Level
   string btn7Name = "BtnDebugLevel";
   string debugText = "";
   color debugColor = clrDarkGray;
   
   switch(g_currentDebugLevel) {
      case 0:
         debugText = "Debug: OFF";
         debugColor = clrDarkGray;
         break;
      case 1:
         debugText = "Debug: CRITICAL";
         debugColor = clrDarkRed;
         break;
      case 2:
         debugText = "Debug: INFO";
         debugColor = clrDarkOrange;
         break;
      case 3:
         debugText = "Debug: VERBOSE";
         debugColor = clrDarkGreen;
         break;
      default:
         debugText = StringFormat("Debug: %d", g_currentDebugLevel);
         debugColor = clrDarkBlue;
         break;
   }
   
   ObjectSetString(0, btn7Name, OBJPROP_TEXT, debugText);
   ObjectSetInteger(0, btn7Name, OBJPROP_BGCOLOR, debugColor);
   ObjectSetInteger(0, btn7Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn7Name, OBJPROP_STATE, false);
   
   // Update Button 8: Single Trail Mode
   string btn8Name = "BtnSingleTrail";
   string trailText = "";
   color trailColor = clrDarkBlue;
   
   switch(g_singleTrailMode) {
      case 0:
         trailText = "STrail: TIGHT";
         trailColor = clrDarkRed;  // Closes sooner
         break;
      case 1:
         trailText = "STrail: NORMAL";
         trailColor = clrDarkBlue;  // Default
         break;
      case 2:
         trailText = "STrail: LOOSE";
         trailColor = clrDarkGreen;  // Trails longer
         break;
      default:
         trailText = StringFormat("STrail: %d", g_singleTrailMode);
         trailColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn8Name, OBJPROP_TEXT, trailText);
   ObjectSetInteger(0, btn8Name, OBJPROP_BGCOLOR, trailColor);
   ObjectSetInteger(0, btn8Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn8Name, OBJPROP_STATE, false);
   
   // Update Button 9: Total Trail Mode
   string btn9Name = "BtnTotalTrail";
   string totalTrailText = "";
   color totalTrailColor = clrDarkBlue;
   
   switch(g_totalTrailMode) {
      case 0:
         totalTrailText = "TTrail: TIGHT";
         totalTrailColor = clrDarkRed;  // Closes sooner
         break;
      case 1:
         totalTrailText = "TTrail: NORMAL";
         totalTrailColor = clrDarkBlue;  // Default
         break;
      case 2:
         totalTrailText = "TTrail: LOOSE";
         totalTrailColor = clrDarkGreen;  // Trails longer
         break;
      default:
         totalTrailText = StringFormat("TTrail: %d", g_totalTrailMode);
         totalTrailColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn9Name, OBJPROP_TEXT, totalTrailText);
   ObjectSetInteger(0, btn9Name, OBJPROP_BGCOLOR, totalTrailColor);
   ObjectSetInteger(0, btn9Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn9Name, OBJPROP_STATE, false);
   
   // Update History Mode button
   switch(g_historyDisplayMode) {
      case 0:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:Overall");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkGreen);
         break;
      case 1:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:SymAll");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkCyan);
         break;
      case 2:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:SymMag");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkOrange);
         break;
      case 3:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:PerSym");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkViolet);
         break;
      default:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:Overall");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkGreen);
         break;
   }
   
   // Update Button 10: Trail Method Strategy
   string btn10Name = "BtnTrailMethod";
   string methodText = "";
   color methodColor = clrDarkSlateGray;
   
   // Show single trail activation status
   string singleStatus = "";
   switch(SingleTrailActivation) {
      case SINGLE_ACTIVATION_IGNORE:  singleStatus = "OFF"; break;
      case SINGLE_ACTIVATION_PROFIT:  singleStatus = "PROFIT"; break;
      case SINGLE_ACTIVATION_LEVEL:   singleStatus = "LEVEL"; break;
      default: singleStatus = "?"; break;
   }
   
   // Show group trail method
   switch(g_currentGroupTrailMethod) {
      case GROUP_TRAIL_IGNORE:
         methodText = StringFormat("S-%s G-OFF", singleStatus);
         methodColor = clrDarkSlateGray;
         break;
      case GROUP_TRAIL_CLOSETOGETHER:
         methodText = StringFormat("S-%s G-ANY", singleStatus);
         methodColor = clrDarkOliveGreen;
         break;
      case GROUP_TRAIL_CLOSETOGETHER_SAMETYPE:
         methodText = StringFormat("S-%s G-SAME", singleStatus);
         methodColor = clrDarkCyan;
         break;
      case GROUP_TRAIL_DYNAMIC:
         methodText = StringFormat("S-%s G-DYN", singleStatus);
         methodColor = clrDarkMagenta;
         break;
      case GROUP_TRAIL_DYNAMIC_SAMETYPE:
         methodText = StringFormat("S-%s G-DYNS", singleStatus);
         methodColor = clrDarkViolet;
         break;
      case GROUP_TRAIL_DYNAMIC_ANYSIDE:
         methodText = StringFormat("S-%s G-DYNA", singleStatus);
         methodColor = clrIndigo;
         break;
      case GROUP_TRAIL_HYBRID_BALANCED:
         methodText = StringFormat("S-%s G-BAL", singleStatus);
         methodColor = clrDarkOrange;
         break;
      case GROUP_TRAIL_HYBRID_ADAPTIVE:
         methodText = StringFormat("S-%s G-ADP", singleStatus);
         methodColor = clrSaddleBrown;
         break;
      case GROUP_TRAIL_HYBRID_SMART:
         methodText = StringFormat("S-%s G-SMT", singleStatus);
         methodColor = clrDarkGoldenrod;
         break;
      case GROUP_TRAIL_HYBRID_COUNT_DIFF:
         methodText = StringFormat("S-%s G-CNT", singleStatus);
         methodColor = clrMaroon;
         break;
      default:
         methodText = StringFormat("S-%s G-%d", singleStatus, g_currentGroupTrailMethod);
         methodColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn10Name, OBJPROP_TEXT, methodText);
   ObjectSetInteger(0, btn10Name, OBJPROP_BGCOLOR, methodColor);
   ObjectSetInteger(0, btn10Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn10Name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btn10Name, OBJPROP_HIDDEN, false);
   
   // Update Button 11: Order Labels (deprecated - now in Lines Control)
   string btnOldOrderLabels = "BtnOrderLabels";
   if(g_showOrderLabels) {
      ObjectSetString(0, btnOldOrderLabels, OBJPROP_TEXT, "Order Labels: ON");
      ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnOldOrderLabels, OBJPROP_TEXT, "Order Labels: OFF");
      ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_HIDDEN, false);
   
   // Update Button 12: Reset Counters (always same appearance)
   string btn12Name = "BtnResetCounters";
   ObjectSetString(0, btn12Name, OBJPROP_TEXT, "Reset (3x click)");
   ObjectSetInteger(0, btn12Name, OBJPROP_BGCOLOR, clrDarkOrange);
   ObjectSetInteger(0, btn12Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn12Name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btn12Name, OBJPROP_HIDDEN, false);
   
   // Update Button 15: Toggle VLines
   string btnVLines = "BtnToggleVLines";
   if(g_showVLines) {
      ObjectSetString(0, btnVLines, OBJPROP_TEXT, "VLines: ON");
      ObjectSetInteger(0, btnVLines, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnVLines, OBJPROP_TEXT, "VLines: OFF");
      ObjectSetInteger(0, btnVLines, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnVLines, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnVLines, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnVLines, OBJPROP_HIDDEN, false);
   
   // Update Button 16: Toggle HLines
   string btnHLines = "BtnToggleHLines";
   if(g_showHLines) {
      ObjectSetString(0, btnHLines, OBJPROP_TEXT, "HLines: ON");
      ObjectSetInteger(0, btnHLines, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnHLines, OBJPROP_TEXT, "HLines: OFF");
      ObjectSetInteger(0, btnHLines, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnHLines, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnHLines, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnHLines, OBJPROP_HIDDEN, false);
   
   UpdateButtonStates();
}

void UpdateButtonStates() {
   // Ensure permanent control button is always visible and update its state
   if(ObjectFind(0, "BtnVisibilityControls") >= 0) {
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_HIDDEN, false);
      ObjectSetString(0, "BtnVisibilityControls", OBJPROP_TEXT, g_showMainButtons ? "HIDE BUTTONS" : "SHOW BUTTONS");
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_BGCOLOR, g_showMainButtons ? clrDarkRed : clrDarkGreen);
   }
   
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
   
   // Update Button 4: Lines Control - Shows panel for line types
   string btn4Name = "BtnLinesControl";
   // Count how many line types are visible
   int lineCount = 0;
   if(g_showVLines) lineCount++;
   if(g_showHLines) lineCount++;
   if(g_showNextLevelLines) lineCount++;
   if(g_showOrderLabelsCtrl) lineCount++;
   
   if(lineCount == 4) {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, "Lines [ALL ON]");
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkGreen);
   } else if(lineCount == 0) {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, "Lines Control");
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkGray);
   } else {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, StringFormat("Lines [%d/4]", lineCount));
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkOrange);
   }
   ObjectSetInteger(0, btn4Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn4Name, OBJPROP_STATE, false);
   
   // Update Button 5: Toggle Labels (Info Labels)
   string btn11Name = "BtnToggleLabels";
   if(g_showLabels) {
      ObjectSetString(0, btn11Name, OBJPROP_TEXT, "Labels [ON]");
      ObjectSetInteger(0, btn11Name, OBJPROP_BGCOLOR, clrGreen);
      ObjectSetInteger(0, btn11Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn11Name, OBJPROP_STATE, true);
   } else {
      ObjectSetString(0, btn11Name, OBJPROP_TEXT, "Show Labels");
      ObjectSetInteger(0, btn11Name, OBJPROP_BGCOLOR, clrDarkGray);
      ObjectSetInteger(0, btn11Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn11Name, OBJPROP_STATE, false);
   }
   
   // Update Button 6: Print Stats (always same appearance)
   string btn6Name = "BtnPrintStats";
   ObjectSetString(0, btn6Name, OBJPROP_TEXT, "Print Stats");
   ObjectSetInteger(0, btn6Name, OBJPROP_BGCOLOR, clrDarkBlue);
   ObjectSetInteger(0, btn6Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn6Name, OBJPROP_STATE, false);
   
   // Update Button 7: Debug Level
   string btn7Name = "BtnDebugLevel";
   string debugText = "";
   color debugColor = clrDarkGray;
   
   switch(g_currentDebugLevel) {
      case 0:
         debugText = "Debug: OFF";
         debugColor = clrDarkGray;
         break;
      case 1:
         debugText = "Debug: CRITICAL";
         debugColor = clrDarkRed;
         break;
      case 2:
         debugText = "Debug: INFO";
         debugColor = clrDarkOrange;
         break;
      case 3:
         debugText = "Debug: VERBOSE";
         debugColor = clrDarkGreen;
         break;
      default:
         debugText = StringFormat("Debug: %d", g_currentDebugLevel);
         debugColor = clrDarkBlue;
         break;
   }
   
   ObjectSetString(0, btn7Name, OBJPROP_TEXT, debugText);
   ObjectSetInteger(0, btn7Name, OBJPROP_BGCOLOR, debugColor);
   ObjectSetInteger(0, btn7Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn7Name, OBJPROP_STATE, false);
   
   // Update Button 8: Single Trail Mode
   string btn8Name = "BtnSingleTrail";
   string trailText = "";
   color trailColor = clrDarkBlue;
   
   switch(g_singleTrailMode) {
      case 0:
         trailText = "STrail: TIGHT";
         trailColor = clrDarkRed;  // Closes sooner
         break;
      case 1:
         trailText = "STrail: NORMAL";
         trailColor = clrDarkBlue;  // Default
         break;
      case 2:
         trailText = "STrail: LOOSE";
         trailColor = clrDarkGreen;  // Trails longer
         break;
      default:
         trailText = StringFormat("STrail: %d", g_singleTrailMode);
         trailColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn8Name, OBJPROP_TEXT, trailText);
   ObjectSetInteger(0, btn8Name, OBJPROP_BGCOLOR, trailColor);
   ObjectSetInteger(0, btn8Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn8Name, OBJPROP_STATE, false);
   
   // Update Button 9: Total Trail Mode
   string btn9Name = "BtnTotalTrail";
   string totalTrailText = "";
   color totalTrailColor = clrDarkBlue;
   
   switch(g_totalTrailMode) {
      case 0:
         totalTrailText = "TTrail: TIGHT";
         totalTrailColor = clrDarkRed;  // Closes sooner
         break;
      case 1:
         totalTrailText = "TTrail: NORMAL";
         totalTrailColor = clrDarkBlue;  // Default
         break;
      case 2:
         totalTrailText = "TTrail: LOOSE";
         totalTrailColor = clrDarkGreen;  // Trails longer
         break;
      default:
         totalTrailText = StringFormat("TTrail: %d", g_totalTrailMode);
         totalTrailColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn9Name, OBJPROP_TEXT, totalTrailText);
   ObjectSetInteger(0, btn9Name, OBJPROP_BGCOLOR, totalTrailColor);
   ObjectSetInteger(0, btn9Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn9Name, OBJPROP_STATE, false);
   
   // Update History Mode button
   switch(g_historyDisplayMode) {
      case 0:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:Overall");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkGreen);
         break;
      case 1:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:SymAll");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkCyan);
         break;
      case 2:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:SymMag");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkOrange);
         break;
      case 3:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:PerSym");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkViolet);
         break;
      default:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:Overall");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkGreen);
         break;
   }
   
   // Update Button 10: Trail Method Strategy
   string btn10Name = "BtnTrailMethod";
   string methodText = "";
   color methodColor = clrDarkSlateGray;
   
   // Show single trail activation status
   string singleStatus = "";
   switch(SingleTrailActivation) {
      case SINGLE_ACTIVATION_IGNORE:  singleStatus = "OFF"; break;
      case SINGLE_ACTIVATION_PROFIT:  singleStatus = "PROFIT"; break;
      case SINGLE_ACTIVATION_LEVEL:   singleStatus = "LEVEL"; break;
      default: singleStatus = "?"; break;
   }
   
   // Show group trail method
   switch(g_currentGroupTrailMethod) {
      case GROUP_TRAIL_IGNORE:
         methodText = StringFormat("S-%s G-OFF", singleStatus);
         methodColor = clrDarkSlateGray;
         break;
      case GROUP_TRAIL_CLOSETOGETHER:
         methodText = StringFormat("S-%s G-ANY", singleStatus);
         methodColor = clrDarkOliveGreen;
         break;
      case GROUP_TRAIL_CLOSETOGETHER_SAMETYPE:
         methodText = StringFormat("S-%s G-SAME", singleStatus);
         methodColor = clrDarkCyan;
         break;
      case GROUP_TRAIL_DYNAMIC:
         methodText = StringFormat("S-%s G-DYN", singleStatus);
         methodColor = clrDarkMagenta;
         break;
      case GROUP_TRAIL_DYNAMIC_SAMETYPE:
         methodText = StringFormat("S-%s G-DYNS", singleStatus);
         methodColor = clrDarkViolet;
         break;
      case GROUP_TRAIL_DYNAMIC_ANYSIDE:
         methodText = StringFormat("S-%s G-DYNA", singleStatus);
         methodColor = clrIndigo;
         break;
      case GROUP_TRAIL_HYBRID_BALANCED:
         methodText = StringFormat("S-%s G-BAL", singleStatus);
         methodColor = clrDarkOrange;
         break;
      case GROUP_TRAIL_HYBRID_ADAPTIVE:
         methodText = StringFormat("S-%s G-ADP", singleStatus);
         methodColor = clrSaddleBrown;
         break;
      case GROUP_TRAIL_HYBRID_SMART:
         methodText = StringFormat("S-%s G-SMT", singleStatus);
         methodColor = clrDarkGoldenrod;
         break;
      case GROUP_TRAIL_HYBRID_COUNT_DIFF:
         methodText = StringFormat("S-%s G-CNT", singleStatus);
         methodColor = clrMaroon;
         break;
      default:
         methodText = StringFormat("S-%s G-%d", singleStatus, g_currentGroupTrailMethod);
         methodColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn10Name, OBJPROP_TEXT, methodText);
   ObjectSetInteger(0, btn10Name, OBJPROP_BGCOLOR, methodColor);
   ObjectSetInteger(0, btn10Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn10Name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btn10Name, OBJPROP_HIDDEN, false);
   
   // Update Button 11: Order Labels (deprecated - now in Lines Control)
   string btnOldOrderLabels = "BtnOrderLabels";
   if(g_showOrderLabels) {
      ObjectSetString(0, btnOldOrderLabels, OBJPROP_TEXT, "Order Labels: ON");
      ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnOldOrderLabels, OBJPROP_TEXT, "Order Labels: OFF");
      ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_HIDDEN, false);
   
   // Update Button 12: Reset Counters (always same appearance)
   string btn12Name = "BtnResetCounters";
   ObjectSetString(0, btn12Name, OBJPROP_TEXT, "Reset (3x click)");
   ObjectSetInteger(0, btn12Name, OBJPROP_BGCOLOR, clrDarkOrange);
   ObjectSetInteger(0, btn12Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn12Name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btn12Name, OBJPROP_HIDDEN, false);
   
   // Update Button 15: Toggle VLines
   string btnVLines = "BtnToggleVLines";
   if(g_showVLines) {
      ObjectSetString(0, btnVLines, OBJPROP_TEXT, "VLines: ON");
      ObjectSetInteger(0, btnVLines, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnVLines, OBJPROP_TEXT, "VLines: OFF");
      ObjectSetInteger(0, btnVLines, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnVLines, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnVLines, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnVLines, OBJPROP_HIDDEN, false);
   
   // Update Button 16: Toggle HLines
   string btnHLines = "BtnToggleHLines";
   if(g_showHLines) {
      ObjectSetString(0, btnHLines, OBJPROP_TEXT, "HLines: ON");
      ObjectSetInteger(0, btnHLines, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnHLines, OBJPROP_TEXT, "HLines: OFF");
      ObjectSetInteger(0, btnHLines, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnHLines, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnHLines, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnHLines, OBJPROP_HIDDEN, false);
   
   UpdateButtonStates();
}

void UpdateButtonStates() {
   // Ensure permanent control button is always visible and update its state
   if(ObjectFind(0, "BtnVisibilityControls") >= 0) {
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_HIDDEN, false);
      ObjectSetString(0, "BtnVisibilityControls", OBJPROP_TEXT, g_showMainButtons ? "HIDE BUTTONS" : "SHOW BUTTONS");
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_BGCOLOR, g_showMainButtons ? clrDarkRed : clrDarkGreen);
   }
   
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
   
   // Update Button 4: Lines Control - Shows panel for line types
   string btn4Name = "BtnLinesControl";
   // Count how many line types are visible
   int lineCount = 0;
   if(g_showVLines) lineCount++;
   if(g_showHLines) lineCount++;
   if(g_showNextLevelLines) lineCount++;
   if(g_showOrderLabelsCtrl) lineCount++;
   
   if(lineCount == 4) {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, "Lines [ALL ON]");
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkGreen);
   } else if(lineCount == 0) {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, "Lines Control");
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkGray);
   } else {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, StringFormat("Lines [%d/4]", lineCount));
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkOrange);
   }
   ObjectSetInteger(0, btn4Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn4Name, OBJPROP_STATE, false);
   
   // Update Button 5: Toggle Labels (Info Labels)
   string btn11Name = "BtnToggleLabels";
   if(g_showLabels) {
      ObjectSetString(0, btn11Name, OBJPROP_TEXT, "Labels [ON]");
      ObjectSetInteger(0, btn11Name, OBJPROP_BGCOLOR, clrGreen);
      ObjectSetInteger(0, btn11Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn11Name, OBJPROP_STATE, true);
   } else {
      ObjectSetString(0, btn11Name, OBJPROP_TEXT, "Show Labels");
      ObjectSetInteger(0, btn11Name, OBJPROP_BGCOLOR, clrDarkGray);
      ObjectSetInteger(0, btn11Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn11Name, OBJPROP_STATE, false);
   }
   
   // Update Button 6: Print Stats (always same appearance)
   string btn6Name = "BtnPrintStats";
   ObjectSetString(0, btn6Name, OBJPROP_TEXT, "Print Stats");
   ObjectSetInteger(0, btn6Name, OBJPROP_BGCOLOR, clrDarkBlue);
   ObjectSetInteger(0, btn6Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn6Name, OBJPROP_STATE, false);
   
   // Update Button 7: Debug Level
   string btn7Name = "BtnDebugLevel";
   string debugText = "";
   color debugColor = clrDarkGray;
   
   switch(g_currentDebugLevel) {
      case 0:
         debugText = "Debug: OFF";
         debugColor = clrDarkGray;
         break;
      case 1:
         debugText = "Debug: CRITICAL";
         debugColor = clrDarkRed;
         break;
      case 2:
         debugText = "Debug: INFO";
         debugColor = clrDarkOrange;
         break;
      case 3:
         debugText = "Debug: VERBOSE";
         debugColor = clrDarkGreen;
         break;
      default:
         debugText = StringFormat("Debug: %d", g_currentDebugLevel);
         debugColor = clrDarkBlue;
         break;
   }
   
   ObjectSetString(0, btn7Name, OBJPROP_TEXT, debugText);
   ObjectSetInteger(0, btn7Name, OBJPROP_BGCOLOR, debugColor);
   ObjectSetInteger(0, btn7Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn7Name, OBJPROP_STATE, false);
   
   // Update Button 8: Single Trail Mode
   string btn8Name = "BtnSingleTrail";
   string trailText = "";
   color trailColor = clrDarkBlue;
   
   switch(g_singleTrailMode) {
      case 0:
         trailText = "STrail: TIGHT";
         trailColor = clrDarkRed;  // Closes sooner
         break;
      case 1:
         trailText = "STrail: NORMAL";
         trailColor = clrDarkBlue;  // Default
         break;
      case 2:
         trailText = "STrail: LOOSE";
         trailColor = clrDarkGreen;  // Trails longer
         break;
      default:
         trailText = StringFormat("STrail: %d", g_singleTrailMode);
         trailColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn8Name, OBJPROP_TEXT, trailText);
   ObjectSetInteger(0, btn8Name, OBJPROP_BGCOLOR, trailColor);
   ObjectSetInteger(0, btn8Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn8Name, OBJPROP_STATE, false);
   
   // Update Button 9: Total Trail Mode
   string btn9Name = "BtnTotalTrail";
   string totalTrailText = "";
   color totalTrailColor = clrDarkBlue;
   
   switch(g_totalTrailMode) {
      case 0:
         totalTrailText = "TTrail: TIGHT";
         totalTrailColor = clrDarkRed;  // Closes sooner
         break;
      case 1:
         totalTrailText = "TTrail: NORMAL";
         totalTrailColor = clrDarkBlue;  // Default
         break;
      case 2:
         totalTrailText = "TTrail: LOOSE";
         totalTrailColor = clrDarkGreen;  // Trails longer
         break;
      default:
         totalTrailText = StringFormat("TTrail: %d", g_totalTrailMode);
         totalTrailColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn9Name, OBJPROP_TEXT, totalTrailText);
   ObjectSetInteger(0, btn9Name, OBJPROP_BGCOLOR, totalTrailColor);
   ObjectSetInteger(0, btn9Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn9Name, OBJPROP_STATE, false);
   
   // Update History Mode button
   switch(g_historyDisplayMode) {
      case 0:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:Overall");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkGreen);
         break;
      case 1:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:SymAll");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkCyan);
         break;
      case 2:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:SymMag");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkOrange);
         break;
      case 3:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:PerSym");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkViolet);
         break;
      default:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:Overall");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkGreen);
         break;
   }
   
   // Update Button 10: Trail Method Strategy
   string btn10Name = "BtnTrailMethod";
   string methodText = "";
   color methodColor = clrDarkSlateGray;
   
   // Show single trail activation status
   string singleStatus = "";
   switch(SingleTrailActivation) {
      case SINGLE_ACTIVATION_IGNORE:  singleStatus = "OFF"; break;
      case SINGLE_ACTIVATION_PROFIT:  singleStatus = "PROFIT"; break;
      case SINGLE_ACTIVATION_LEVEL:   singleStatus = "LEVEL"; break;
      default: singleStatus = "?"; break;
   }
   
   // Show group trail method
   switch(g_currentGroupTrailMethod) {
      case GROUP_TRAIL_IGNORE:
         methodText = StringFormat("S-%s G-OFF", singleStatus);
         methodColor = clrDarkSlateGray;
         break;
      case GROUP_TRAIL_CLOSETOGETHER:
         methodText = StringFormat("S-%s G-ANY", singleStatus);
         methodColor = clrDarkOliveGreen;
         break;
      case GROUP_TRAIL_CLOSETOGETHER_SAMETYPE:
         methodText = StringFormat("S-%s G-SAME", singleStatus);
         methodColor = clrDarkCyan;
         break;
      case GROUP_TRAIL_DYNAMIC:
         methodText = StringFormat("S-%s G-DYN", singleStatus);
         methodColor = clrDarkMagenta;
         break;
      case GROUP_TRAIL_DYNAMIC_SAMETYPE:
         methodText = StringFormat("S-%s G-DYNS", singleStatus);
         methodColor = clrDarkViolet;
         break;
      case GROUP_TRAIL_DYNAMIC_ANYSIDE:
         methodText = StringFormat("S-%s G-DYNA", singleStatus);
         methodColor = clrIndigo;
         break;
      case GROUP_TRAIL_HYBRID_BALANCED:
         methodText = StringFormat("S-%s G-BAL", singleStatus);
         methodColor = clrDarkOrange;
         break;
      case GROUP_TRAIL_HYBRID_ADAPTIVE:
         methodText = StringFormat("S-%s G-ADP", singleStatus);
         methodColor = clrSaddleBrown;
         break;
      case GROUP_TRAIL_HYBRID_SMART:
         methodText = StringFormat("S-%s G-SMT", singleStatus);
         methodColor = clrDarkGoldenrod;
         break;
      case GROUP_TRAIL_HYBRID_COUNT_DIFF:
         methodText = StringFormat("S-%s G-CNT", singleStatus);
         methodColor = clrMaroon;
         break;
      default:
         methodText = StringFormat("S-%s G-%d", singleStatus, g_currentGroupTrailMethod);
         methodColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn10Name, OBJPROP_TEXT, methodText);
   ObjectSetInteger(0, btn10Name, OBJPROP_BGCOLOR, methodColor);
   ObjectSetInteger(0, btn10Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn10Name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btn10Name, OBJPROP_HIDDEN, false);
   
   // Update Button 11: Order Labels (deprecated - now in Lines Control)
   string btnOldOrderLabels = "BtnOrderLabels";
   if(g_showOrderLabels) {
      ObjectSetString(0, btnOldOrderLabels, OBJPROP_TEXT, "Order Labels: ON");
      ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnOldOrderLabels, OBJPROP_TEXT, "Order Labels: OFF");
      ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_HIDDEN, false);
   
   // Update Button 12: Reset Counters (always same appearance)
   string btn12Name = "BtnResetCounters";
   ObjectSetString(0, btn12Name, OBJPROP_TEXT, "Reset (3x click)");
   ObjectSetInteger(0, btn12Name, OBJPROP_BGCOLOR, clrDarkOrange);
   ObjectSetInteger(0, btn12Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn12Name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btn12Name, OBJPROP_HIDDEN, false);
   
   // Update Button 15: Toggle VLines
   string btnVLines = "BtnToggleVLines";
   if(g_showVLines) {
      ObjectSetString(0, btnVLines, OBJPROP_TEXT, "VLines: ON");
      ObjectSetInteger(0, btnVLines, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnVLines, OBJPROP_TEXT, "VLines: OFF");
      ObjectSetInteger(0, btnVLines, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnVLines, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnVLines, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnVLines, OBJPROP_HIDDEN, false);
   
   // Update Button 16: Toggle HLines
   string btnHLines = "BtnToggleHLines";
   if(g_showHLines) {
      ObjectSetString(0, btnHLines, OBJPROP_TEXT, "HLines: ON");
      ObjectSetInteger(0, btnHLines, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnHLines, OBJPROP_TEXT, "HLines: OFF");
      ObjectSetInteger(0, btnHLines, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnHLines, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnHLines, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnHLines, OBJPROP_HIDDEN, false);
   
   UpdateButtonStates();
}

void UpdateButtonStates() {
   // Ensure permanent control button is always visible and update its state
   if(ObjectFind(0, "BtnVisibilityControls") >= 0) {
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_HIDDEN, false);
      ObjectSetString(0, "BtnVisibilityControls", OBJPROP_TEXT, g_showMainButtons ? "HIDE BUTTONS" : "SHOW BUTTONS");
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_BGCOLOR, g_showMainButtons ? clrDarkRed : clrDarkGreen);
   }
   
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
   
   // Update Button 4: Lines Control - Shows panel for line types
   string btn4Name = "BtnLinesControl";
   // Count how many line types are visible
   int lineCount = 0;
   if(g_showVLines) lineCount++;
   if(g_showHLines) lineCount++;
   if(g_showNextLevelLines) lineCount++;
   if(g_showOrderLabelsCtrl) lineCount++;
   
   if(lineCount == 4) {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, "Lines [ALL ON]");
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkGreen);
   } else if(lineCount == 0) {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, "Lines Control");
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkGray);
   } else {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, StringFormat("Lines [%d/4]", lineCount));
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkOrange);
   }
   ObjectSetInteger(0, btn4Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn4Name, OBJPROP_STATE, false);
   
   // Update Button 5: Toggle Labels (Info Labels)
   string btn11Name = "BtnToggleLabels";
   if(g_showLabels) {
      ObjectSetString(0, btn11Name, OBJPROP_TEXT, "Labels [ON]");
      ObjectSetInteger(0, btn11Name, OBJPROP_BGCOLOR, clrGreen);
      ObjectSetInteger(0, btn11Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn11Name, OBJPROP_STATE, true);
   } else {
      ObjectSetString(0, btn11Name, OBJPROP_TEXT, "Show Labels");
      ObjectSetInteger(0, btn11Name, OBJPROP_BGCOLOR, clrDarkGray);
      ObjectSetInteger(0, btn11Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn11Name, OBJPROP_STATE, false);
   }
   
   // Update Button 6: Print Stats (always same appearance)
   string btn6Name = "BtnPrintStats";
   ObjectSetString(0, btn6Name, OBJPROP_TEXT, "Print Stats");
   ObjectSetInteger(0, btn6Name, OBJPROP_BGCOLOR, clrDarkBlue);
   ObjectSetInteger(0, btn6Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn6Name, OBJPROP_STATE, false);
   
   // Update Button 7: Debug Level
   string btn7Name = "BtnDebugLevel";
   string debugText = "";
   color debugColor = clrDarkGray;
   
   switch(g_currentDebugLevel) {
      case 0:
         debugText = "Debug: OFF";
         debugColor = clrDarkGray;
         break;
      case 1:
         debugText = "Debug: CRITICAL";
         debugColor = clrDarkRed;
         break;
      case 2:
         debugText = "Debug: INFO";
         debugColor = clrDarkOrange;
         break;
      case 3:
         debugText = "Debug: VERBOSE";
         debugColor = clrDarkGreen;
         break;
      default:
         debugText = StringFormat("Debug: %d", g_currentDebugLevel);
         debugColor = clrDarkBlue;
         break;
   }
   
   ObjectSetString(0, btn7Name, OBJPROP_TEXT, debugText);
   ObjectSetInteger(0, btn7Name, OBJPROP_BGCOLOR, debugColor);
   ObjectSetInteger(0, btn7Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn7Name, OBJPROP_STATE, false);
   
   // Update Button 8: Single Trail Mode
   string btn8Name = "BtnSingleTrail";
   string trailText = "";
   color trailColor = clrDarkBlue;
   
   switch(g_singleTrailMode) {
      case 0:
         trailText = "STrail: TIGHT";
         trailColor = clrDarkRed;  // Closes sooner
         break;
      case 1:
         trailText = "STrail: NORMAL";
         trailColor = clrDarkBlue;  // Default
         break;
      case 2:
         trailText = "STrail: LOOSE";
         trailColor = clrDarkGreen;  // Trails longer
         break;
      default:
         trailText = StringFormat("STrail: %d", g_singleTrailMode);
         trailColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn8Name, OBJPROP_TEXT, trailText);
   ObjectSetInteger(0, btn8Name, OBJPROP_BGCOLOR, trailColor);
   ObjectSetInteger(0, btn8Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn8Name, OBJPROP_STATE, false);
   
   // Update Button 9: Total Trail Mode
   string btn9Name = "BtnTotalTrail";
   string totalTrailText = "";
   color totalTrailColor = clrDarkBlue;
   
   switch(g_totalTrailMode) {
      case 0:
         totalTrailText = "TTrail: TIGHT";
         totalTrailColor = clrDarkRed;  // Closes sooner
         break;
      case 1:
         totalTrailText = "TTrail: NORMAL";
         totalTrailColor = clrDarkBlue;  // Default
         break;
      case 2:
         totalTrailText = "TTrail: LOOSE";
         totalTrailColor = clrDarkGreen;  // Trails longer
         break;
      default:
         totalTrailText = StringFormat("TTrail: %d", g_totalTrailMode);
         totalTrailColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn9Name, OBJPROP_TEXT, totalTrailText);
   ObjectSetInteger(0, btn9Name, OBJPROP_BGCOLOR, totalTrailColor);
   ObjectSetInteger(0, btn9Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn9Name, OBJPROP_STATE, false);
   
   // Update History Mode button
   switch(g_historyDisplayMode) {
      case 0:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:Overall");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkGreen);
         break;
      case 1:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:SymAll");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkCyan);
         break;
      case 2:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:SymMag");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkOrange);
         break;
      case 3:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:PerSym");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkViolet);
         break;
      default:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:Overall");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkGreen);
         break;
   }
   
   // Update Button 10: Trail Method Strategy
   string btn10Name = "BtnTrailMethod";
   string methodText = "";
   color methodColor = clrDarkSlateGray;
   
   // Show single trail activation status
   string singleStatus = "";
   switch(SingleTrailActivation) {
      case SINGLE_ACTIVATION_IGNORE:  singleStatus = "OFF"; break;
      case SINGLE_ACTIVATION_PROFIT:  singleStatus = "PROFIT"; break;
      case SINGLE_ACTIVATION_LEVEL:   singleStatus = "LEVEL"; break;
      default: singleStatus = "?"; break;
   }
   
   // Show group trail method
   switch(g_currentGroupTrailMethod) {
      case GROUP_TRAIL_IGNORE:
         methodText = StringFormat("S-%s G-OFF", singleStatus);
         methodColor = clrDarkSlateGray;
         break;
      case GROUP_TRAIL_CLOSETOGETHER:
         methodText = StringFormat("S-%s G-ANY", singleStatus);
         methodColor = clrDarkOliveGreen;
         break;
      case GROUP_TRAIL_CLOSETOGETHER_SAMETYPE:
         methodText = StringFormat("S-%s G-SAME", singleStatus);
         methodColor = clrDarkCyan;
         break;
      case GROUP_TRAIL_DYNAMIC:
         methodText = StringFormat("S-%s G-DYN", singleStatus);
         methodColor = clrDarkMagenta;
         break;
      case GROUP_TRAIL_DYNAMIC_SAMETYPE:
         methodText = StringFormat("S-%s G-DYNS", singleStatus);
         methodColor = clrDarkViolet;
         break;
      case GROUP_TRAIL_DYNAMIC_ANYSIDE:
         methodText = StringFormat("S-%s G-DYNA", singleStatus);
         methodColor = clrIndigo;
         break;
      case GROUP_TRAIL_HYBRID_BALANCED:
         methodText = StringFormat("S-%s G-BAL", singleStatus);
         methodColor = clrDarkOrange;
         break;
      case GROUP_TRAIL_HYBRID_ADAPTIVE:
         methodText = StringFormat("S-%s G-ADP", singleStatus);
         methodColor = clrSaddleBrown;
         break;
      case GROUP_TRAIL_HYBRID_SMART:
         methodText = StringFormat("S-%s G-SMT", singleStatus);
         methodColor = clrDarkGoldenrod;
         break;
      case GROUP_TRAIL_HYBRID_COUNT_DIFF:
         methodText = StringFormat("S-%s G-CNT", singleStatus);
         methodColor = clrMaroon;
         break;
      default:
         methodText = StringFormat("S-%s G-%d", singleStatus, g_currentGroupTrailMethod);
         methodColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn10Name, OBJPROP_TEXT, methodText);
   ObjectSetInteger(0, btn10Name, OBJPROP_BGCOLOR, methodColor);
   ObjectSetInteger(0, btn10Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn10Name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btn10Name, OBJPROP_HIDDEN, false);
   
   // Update Button 11: Order Labels (deprecated - now in Lines Control)
   string btnOldOrderLabels = "BtnOrderLabels";
   if(g_showOrderLabels) {
      ObjectSetString(0, btnOldOrderLabels, OBJPROP_TEXT, "Order Labels: ON");
      ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnOldOrderLabels, OBJPROP_TEXT, "Order Labels: OFF");
      ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_HIDDEN, false);
   
   // Update Button 12: Reset Counters (always same appearance)
   string btn12Name = "BtnResetCounters";
   ObjectSetString(0, btn12Name, OBJPROP_TEXT, "Reset (3x click)");
   ObjectSetInteger(0, btn12Name, OBJPROP_BGCOLOR, clrDarkOrange);
   ObjectSetInteger(0, btn12Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn12Name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btn12Name, OBJPROP_HIDDEN, false);
   
   // Update Button 15: Toggle VLines
   string btnVLines = "BtnToggleVLines";
   if(g_showVLines) {
      ObjectSetString(0, btnVLines, OBJPROP_TEXT, "VLines: ON");
      ObjectSetInteger(0, btnVLines, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnVLines, OBJPROP_TEXT, "VLines: OFF");
      ObjectSetInteger(0, btnVLines, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnVLines, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnVLines, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnVLines, OBJPROP_HIDDEN, false);
   
   // Update Button 16: Toggle HLines
   string btnHLines = "BtnToggleHLines";
   if(g_showHLines) {
      ObjectSetString(0, btnHLines, OBJPROP_TEXT, "HLines: ON");
      ObjectSetInteger(0, btnHLines, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnHLines, OBJPROP_TEXT, "HLines: OFF");
      ObjectSetInteger(0, btnHLines, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnHLines, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnHLines, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnHLines, OBJPROP_HIDDEN, false);
   
   UpdateButtonStates();
}

void UpdateButtonStates() {
   // Ensure permanent control button is always visible and update its state
   if(ObjectFind(0, "BtnVisibilityControls") >= 0) {
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_HIDDEN, false);
      ObjectSetString(0, "BtnVisibilityControls", OBJPROP_TEXT, g_showMainButtons ? "HIDE BUTTONS" : "SHOW BUTTONS");
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_BGCOLOR, g_showMainButtons ? clrDarkRed : clrDarkGreen);
   }
   
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
   
   // Update Button 4: Lines Control - Shows panel for line types
   string btn4Name = "BtnLinesControl";
   // Count how many line types are visible
   int lineCount = 0;
   if(g_showVLines) lineCount++;
   if(g_showHLines) lineCount++;
   if(g_showNextLevelLines) lineCount++;
   if(g_showOrderLabelsCtrl) lineCount++;
   
   if(lineCount == 4) {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, "Lines [ALL ON]");
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkGreen);
   } else if(lineCount == 0) {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, "Lines Control");
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkGray);
   } else {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, StringFormat("Lines [%d/4]", lineCount));
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkOrange);
   }
   ObjectSetInteger(0, btn4Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn4Name, OBJPROP_STATE, false);
   
   // Update Button 5: Toggle Labels (Info Labels)
   string btn11Name = "BtnToggleLabels";
   if(g_showLabels) {
      ObjectSetString(0, btn11Name, OBJPROP_TEXT, "Labels [ON]");
      ObjectSetInteger(0, btn11Name, OBJPROP_BGCOLOR, clrGreen);
      ObjectSetInteger(0, btn11Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn11Name, OBJPROP_STATE, true);
   } else {
      ObjectSetString(0, btn11Name, OBJPROP_TEXT, "Show Labels");
      ObjectSetInteger(0, btn11Name, OBJPROP_BGCOLOR, clrDarkGray);
      ObjectSetInteger(0, btn11Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn11Name, OBJPROP_STATE, false);
   }
   
   // Update Button 6: Print Stats (always same appearance)
   string btn6Name = "BtnPrintStats";
   ObjectSetString(0, btn6Name, OBJPROP_TEXT, "Print Stats");
   ObjectSetInteger(0, btn6Name, OBJPROP_BGCOLOR, clrDarkBlue);
   ObjectSetInteger(0, btn6Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn6Name, OBJPROP_STATE, false);
   
   // Update Button 7: Debug Level
   string btn7Name = "BtnDebugLevel";
   string debugText = "";
   color debugColor = clrDarkGray;
   
   switch(g_currentDebugLevel) {
      case 0:
         debugText = "Debug: OFF";
         debugColor = clrDarkGray;
         break;
      case 1:
         debugText = "Debug: CRITICAL";
         debugColor = clrDarkRed;
         break;
      case 2:
         debugText = "Debug: INFO";
         debugColor = clrDarkOrange;
         break;
      case 3:
         debugText = "Debug: VERBOSE";
         debugColor = clrDarkGreen;
         break;
      default:
         debugText = StringFormat("Debug: %d", g_currentDebugLevel);
         debugColor = clrDarkBlue;
         break;
   }
   
   ObjectSetString(0, btn7Name, OBJPROP_TEXT, debugText);
   ObjectSetInteger(0, btn7Name, OBJPROP_BGCOLOR, debugColor);
   ObjectSetInteger(0, btn7Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn7Name, OBJPROP_STATE, false);
   
   // Update Button 8: Single Trail Mode
   string btn8Name = "BtnSingleTrail";
   string trailText = "";
   color trailColor = clrDarkBlue;
   
   switch(g_singleTrailMode) {
      case 0:
         trailText = "STrail: TIGHT";
         trailColor = clrDarkRed;  // Closes sooner
         break;
      case 1:
         trailText = "STrail: NORMAL";
         trailColor = clrDarkBlue;  // Default
         break;
      case 2:
         trailText = "STrail: LOOSE";
         trailColor = clrDarkGreen;  // Trails longer
         break;
      default:
         trailText = StringFormat("STrail: %d", g_singleTrailMode);
         trailColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn8Name, OBJPROP_TEXT, trailText);
   ObjectSetInteger(0, btn8Name, OBJPROP_BGCOLOR, trailColor);
   ObjectSetInteger(0, btn8Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn8Name, OBJPROP_STATE, false);
   
   // Update Button 9: Total Trail Mode
   string btn9Name = "BtnTotalTrail";
   string totalTrailText = "";
   color totalTrailColor = clrDarkBlue;
   
   switch(g_totalTrailMode) {
      case 0:
         totalTrailText = "TTrail: TIGHT";
         totalTrailColor = clrDarkRed;  // Closes sooner
         break;
      case 1:
         totalTrailText = "TTrail: NORMAL";
         totalTrailColor = clrDarkBlue;  // Default
         break;
      case 2:
         totalTrailText = "TTrail: LOOSE";
         totalTrailColor = clrDarkGreen;  // Trails longer
         break;
      default:
         totalTrailText = StringFormat("TTrail: %d", g_totalTrailMode);
         totalTrailColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn9Name, OBJPROP_TEXT, totalTrailText);
   ObjectSetInteger(0, btn9Name, OBJPROP_BGCOLOR, totalTrailColor);
   ObjectSetInteger(0, btn9Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn9Name, OBJPROP_STATE, false);
   
   // Update History Mode button
   switch(g_historyDisplayMode) {
      case 0:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:Overall");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkGreen);
         break;
      case 1:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:SymAll");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkCyan);
         break;
      case 2:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:SymMag");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkOrange);
         break;
      case 3:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:PerSym");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkViolet);
         break;
      default:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:Overall");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkGreen);
         break;
   }
   
   // Update Button 10: Trail Method Strategy
   string btn10Name = "BtnTrailMethod";
   string methodText = "";
   color methodColor = clrDarkSlateGray;
   
   // Show single trail activation status
   string singleStatus = "";
   switch(SingleTrailActivation) {
      case SINGLE_ACTIVATION_IGNORE:  singleStatus = "OFF"; break;
      case SINGLE_ACTIVATION_PROFIT:  singleStatus = "PROFIT"; break;
      case SINGLE_ACTIVATION_LEVEL:   singleStatus = "LEVEL"; break;
      default: singleStatus = "?"; break;
   }
   
   // Show group trail method
   switch(g_currentGroupTrailMethod) {
      case GROUP_TRAIL_IGNORE:
         methodText = StringFormat("S-%s G-OFF", singleStatus);
         methodColor = clrDarkSlateGray;
         break;
      case GROUP_TRAIL_CLOSETOGETHER:
         methodText = StringFormat("S-%s G-ANY", singleStatus);
         methodColor = clrDarkOliveGreen;
         break;
      case GROUP_TRAIL_CLOSETOGETHER_SAMETYPE:
         methodText = StringFormat("S-%s G-SAME", singleStatus);
         methodColor = clrDarkCyan;
         break;
      case GROUP_TRAIL_DYNAMIC:
         methodText = StringFormat("S-%s G-DYN", singleStatus);
         methodColor = clrDarkMagenta;
         break;
      case GROUP_TRAIL_DYNAMIC_SAMETYPE:
         methodText = StringFormat("S-%s G-DYNS", singleStatus);
         methodColor = clrDarkViolet;
         break;
      case GROUP_TRAIL_DYNAMIC_ANYSIDE:
         methodText = StringFormat("S-%s G-DYNA", singleStatus);
         methodColor = clrIndigo;
         break;
      case GROUP_TRAIL_HYBRID_BALANCED:
         methodText = StringFormat("S-%s G-BAL", singleStatus);
         methodColor = clrDarkOrange;
         break;
      case GROUP_TRAIL_HYBRID_ADAPTIVE:
         methodText = StringFormat("S-%s G-ADP", singleStatus);
         methodColor = clrSaddleBrown;
         break;
      case GROUP_TRAIL_HYBRID_SMART:
         methodText = StringFormat("S-%s G-SMT", singleStatus);
         methodColor = clrDarkGoldenrod;
         break;
      case GROUP_TRAIL_HYBRID_COUNT_DIFF:
         methodText = StringFormat("S-%s G-CNT", singleStatus);
         methodColor = clrMaroon;
         break;
      default:
         methodText = StringFormat("S-%s G-%d", singleStatus, g_currentGroupTrailMethod);
         methodColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn10Name, OBJPROP_TEXT, methodText);
   ObjectSetInteger(0, btn10Name, OBJPROP_BGCOLOR, methodColor);
   ObjectSetInteger(0, btn10Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn10Name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btn10Name, OBJPROP_HIDDEN, false);
   
   // Update Button 11: Order Labels (deprecated - now in Lines Control)
   string btnOldOrderLabels = "BtnOrderLabels";
   if(g_showOrderLabels) {
      ObjectSetString(0, btnOldOrderLabels, OBJPROP_TEXT, "Order Labels: ON");
      ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnOldOrderLabels, OBJPROP_TEXT, "Order Labels: OFF");
      ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_HIDDEN, false);
   
   // Update Button 12: Reset Counters (always same appearance)
   string btn12Name = "BtnResetCounters";
   ObjectSetString(0, btn12Name, OBJPROP_TEXT, "Reset (3x click)");
   ObjectSetInteger(0, btn12Name, OBJPROP_BGCOLOR, clrDarkOrange);
   ObjectSetInteger(0, btn12Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn12Name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btn12Name, OBJPROP_HIDDEN, false);
   
   // Update Button 15: Toggle VLines
   string btnVLines = "BtnToggleVLines";
   if(g_showVLines) {
      ObjectSetString(0, btnVLines, OBJPROP_TEXT, "VLines: ON");
      ObjectSetInteger(0, btnVLines, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnVLines, OBJPROP_TEXT, "VLines: OFF");
      ObjectSetInteger(0, btnVLines, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnVLines, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnVLines, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnVLines, OBJPROP_HIDDEN, false);
   
   // Update Button 16: Toggle HLines
   string btnHLines = "BtnToggleHLines";
   if(g_showHLines) {
      ObjectSetString(0, btnHLines, OBJPROP_TEXT, "HLines: ON");
      ObjectSetInteger(0, btnHLines, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnHLines, OBJPROP_TEXT, "HLines: OFF");
      ObjectSetInteger(0, btnHLines, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnHLines, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnHLines, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnHLines, OBJPROP_HIDDEN, false);
   
   UpdateButtonStates();
}

void UpdateButtonStates() {
   // Ensure permanent control button is always visible and update its state
   if(ObjectFind(0, "BtnVisibilityControls") >= 0) {
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_HIDDEN, false);
      ObjectSetString(0, "BtnVisibilityControls", OBJPROP_TEXT, g_showMainButtons ? "HIDE BUTTONS" : "SHOW BUTTONS");
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_BGCOLOR, g_showMainButtons ? clrDarkRed : clrDarkGreen);
   }
   
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
   
   // Update Button 4: Lines Control - Shows panel for line types
   string btn4Name = "BtnLinesControl";
   // Count how many line types are visible
   int lineCount = 0;
   if(g_showVLines) lineCount++;
   if(g_showHLines) lineCount++;
   if(g_showNextLevelLines) lineCount++;
   if(g_showOrderLabelsCtrl) lineCount++;
   
   if(lineCount == 4) {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, "Lines [ALL ON]");
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkGreen);
   } else if(lineCount == 0) {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, "Lines Control");
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkGray);
   } else {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, StringFormat("Lines [%d/4]", lineCount));
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkOrange);
   }
   ObjectSetInteger(0, btn4Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn4Name, OBJPROP_STATE, false);
   
   // Update Button 5: Toggle Labels (Info Labels)
   string btn11Name = "BtnToggleLabels";
   if(g_showLabels) {
      ObjectSetString(0, btn11Name, OBJPROP_TEXT, "Labels [ON]");
      ObjectSetInteger(0, btn11Name, OBJPROP_BGCOLOR, clrGreen);
      ObjectSetInteger(0, btn11Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn11Name, OBJPROP_STATE, true);
   } else {
      ObjectSetString(0, btn11Name, OBJPROP_TEXT, "Show Labels");
      ObjectSetInteger(0, btn11Name, OBJPROP_BGCOLOR, clrDarkGray);
      ObjectSetInteger(0, btn11Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn11Name, OBJPROP_STATE, false);
   }
   
   // Update Button 6: Print Stats (always same appearance)
   string btn6Name = "BtnPrintStats";
   ObjectSetString(0, btn6Name, OBJPROP_TEXT, "Print Stats");
   ObjectSetInteger(0, btn6Name, OBJPROP_BGCOLOR, clrDarkBlue);
   ObjectSetInteger(0, btn6Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn6Name, OBJPROP_STATE, false);
   
   // Update Button 7: Debug Level
   string btn7Name = "BtnDebugLevel";
   string debugText = "";
   color debugColor = clrDarkGray;
   
   switch(g_currentDebugLevel) {
      case 0:
         debugText = "Debug: OFF";
         debugColor = clrDarkGray;
         break;
      case 1:
         debugText = "Debug: CRITICAL";
         debugColor = clrDarkRed;
         break;
      case 2:
         debugText = "Debug: INFO";
         debugColor = clrDarkOrange;
         break;
      case 3:
         debugText = "Debug: VERBOSE";
         debugColor = clrDarkGreen;
         break;
      default:
         debugText = StringFormat("Debug: %d", g_currentDebugLevel);
         debugColor = clrDarkBlue;
         break;
   }
   
   ObjectSetString(0, btn7Name, OBJPROP_TEXT, debugText);
   ObjectSetInteger(0, btn7Name, OBJPROP_BGCOLOR, debugColor);
   ObjectSetInteger(0, btn7Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn7Name, OBJPROP_STATE, false);
   
   // Update Button 8: Single Trail Mode
   string btn8Name = "BtnSingleTrail";
   string trailText = "";
   color trailColor = clrDarkBlue;
   
   switch(g_singleTrailMode) {
      case 0:
         trailText = "STrail: TIGHT";
         trailColor = clrDarkRed;  // Closes sooner
         break;
      case 1:
         trailText = "STrail: NORMAL";
         trailColor = clrDarkBlue;  // Default
         break;
      case 2:
         trailText = "STrail: LOOSE";
         trailColor = clrDarkGreen;  // Trails longer
         break;
      default:
         trailText = StringFormat("STrail: %d", g_singleTrailMode);
         trailColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn8Name, OBJPROP_TEXT, trailText);
   ObjectSetInteger(0, btn8Name, OBJPROP_BGCOLOR, trailColor);
   ObjectSetInteger(0, btn8Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn8Name, OBJPROP_STATE, false);
   
   // Update Button 9: Total Trail Mode
   string btn9Name = "BtnTotalTrail";
   string totalTrailText = "";
   color totalTrailColor = clrDarkBlue;
   
   switch(g_totalTrailMode) {
      case 0:
         totalTrailText = "TTrail: TIGHT";
         totalTrailColor = clrDarkRed;  // Closes sooner
         break;
      case 1:
         totalTrailText = "TTrail: NORMAL";
         totalTrailColor = clrDarkBlue;  // Default
         break;
      case 2:
         totalTrailText = "TTrail: LOOSE";
         totalTrailColor = clrDarkGreen;  // Trails longer
         break;
      default:
         totalTrailText = StringFormat("TTrail: %d", g_totalTrailMode);
         totalTrailColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn9Name, OBJPROP_TEXT, totalTrailText);
   ObjectSetInteger(0, btn9Name, OBJPROP_BGCOLOR, totalTrailColor);
   ObjectSetInteger(0, btn9Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn9Name, OBJPROP_STATE, false);
   
   // Update History Mode button
   switch(g_historyDisplayMode) {
      case 0:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:Overall");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkGreen);
         break;
      case 1:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:SymAll");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkCyan);
         break;
      case 2:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:SymMag");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkOrange);
         break;
      case 3:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:PerSym");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkViolet);
         break;
      default:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:Overall");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkGreen);
         break;
   }
   
   // Update Button 10: Trail Method Strategy
   string btn10Name = "BtnTrailMethod";
   string methodText = "";
   color methodColor = clrDarkSlateGray;
   
   // Show single trail activation status
   string singleStatus = "";
   switch(SingleTrailActivation) {
      case SINGLE_ACTIVATION_IGNORE:  singleStatus = "OFF"; break;
      case SINGLE_ACTIVATION_PROFIT:  singleStatus = "PROFIT"; break;
      case SINGLE_ACTIVATION_LEVEL:   singleStatus = "LEVEL"; break;
      default: singleStatus = "?"; break;
   }
   
   // Show group trail method
   switch(g_currentGroupTrailMethod) {
      case GROUP_TRAIL_IGNORE:
         methodText = StringFormat("S-%s G-OFF", singleStatus);
         methodColor = clrDarkSlateGray;
         break;
      case GROUP_TRAIL_CLOSETOGETHER:
         methodText = StringFormat("S-%s G-ANY", singleStatus);
         methodColor = clrDarkOliveGreen;
         break;
      case GROUP_TRAIL_CLOSETOGETHER_SAMETYPE:
         methodText = StringFormat("S-%s G-SAME", singleStatus);
         methodColor = clrDarkCyan;
         break;
      case GROUP_TRAIL_DYNAMIC:
         methodText = StringFormat("S-%s G-DYN", singleStatus);
         methodColor = clrDarkMagenta;
         break;
      case GROUP_TRAIL_DYNAMIC_SAMETYPE:
         methodText = StringFormat("S-%s G-DYNS", singleStatus);
         methodColor = clrDarkViolet;
         break;
      case GROUP_TRAIL_DYNAMIC_ANYSIDE:
         methodText = StringFormat("S-%s G-DYNA", singleStatus);
         methodColor = clrIndigo;
         break;
      case GROUP_TRAIL_HYBRID_BALANCED:
         methodText = StringFormat("S-%s G-BAL", singleStatus);
         methodColor = clrDarkOrange;
         break;
      case GROUP_TRAIL_HYBRID_ADAPTIVE:
         methodText = StringFormat("S-%s G-ADP", singleStatus);
         methodColor = clrSaddleBrown;
         break;
      case GROUP_TRAIL_HYBRID_SMART:
         methodText = StringFormat("S-%s G-SMT", singleStatus);
         methodColor = clrDarkGoldenrod;
         break;
      case GROUP_TRAIL_HYBRID_COUNT_DIFF:
         methodText = StringFormat("S-%s G-CNT", singleStatus);
         methodColor = clrMaroon;
         break;
      default:
         methodText = StringFormat("S-%s G-%d", singleStatus, g_currentGroupTrailMethod);
         methodColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn10Name, OBJPROP_TEXT, methodText);
   ObjectSetInteger(0, btn10Name, OBJPROP_BGCOLOR, methodColor);
   ObjectSetInteger(0, btn10Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn10Name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btn10Name, OBJPROP_HIDDEN, false);
   
   // Update Button 11: Order Labels (deprecated - now in Lines Control)
   string btnOldOrderLabels = "BtnOrderLabels";
   if(g_showOrderLabels) {
      ObjectSetString(0, btnOldOrderLabels, OBJPROP_TEXT, "Order Labels: ON");
      ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnOldOrderLabels, OBJPROP_TEXT, "Order Labels: OFF");
      ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_HIDDEN, false);
   
   // Update Button 12: Reset Counters (always same appearance)
   string btn12Name = "BtnResetCounters";
   ObjectSetString(0, btn12Name, OBJPROP_TEXT, "Reset (3x click)");
   ObjectSetInteger(0, btn12Name, OBJPROP_BGCOLOR, clrDarkOrange);
   ObjectSetInteger(0, btn12Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn12Name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btn12Name, OBJPROP_HIDDEN, false);
   
   // Update Button 15: Toggle VLines
   string btnVLines = "BtnToggleVLines";
   if(g_showVLines) {
      ObjectSetString(0, btnVLines, OBJPROP_TEXT, "VLines: ON");
      ObjectSetInteger(0, btnVLines, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnVLines, OBJPROP_TEXT, "VLines: OFF");
      ObjectSetInteger(0, btnVLines, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnVLines, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnVLines, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnVLines, OBJPROP_HIDDEN, false);
   
   // Update Button 16: Toggle HLines
   string btnHLines = "BtnToggleHLines";
   if(g_showHLines) {
      ObjectSetString(0, btnHLines, OBJPROP_TEXT, "HLines: ON");
      ObjectSetInteger(0, btnHLines, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnHLines, OBJPROP_TEXT, "HLines: OFF");
      ObjectSetInteger(0, btnHLines, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnHLines, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnHLines, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnHLines, OBJPROP_HIDDEN, false);
   
   UpdateButtonStates();
}

void UpdateButtonStates() {
   // Ensure permanent control button is always visible and update its state
   if(ObjectFind(0, "BtnVisibilityControls") >= 0) {
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_HIDDEN, false);
      ObjectSetString(0, "BtnVisibilityControls", OBJPROP_TEXT, g_showMainButtons ? "HIDE BUTTONS" : "SHOW BUTTONS");
      ObjectSetInteger(0, "BtnVisibilityControls", OBJPROP_BGCOLOR, g_showMainButtons ? clrDarkRed : clrDarkGreen);
   }
   
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
   
   // Update Button 4: Lines Control - Shows panel for line types
   string btn4Name = "BtnLinesControl";
   // Count how many line types are visible
   int lineCount = 0;
   if(g_showVLines) lineCount++;
   if(g_showHLines) lineCount++;
   if(g_showNextLevelLines) lineCount++;
   if(g_showOrderLabelsCtrl) lineCount++;
   
   if(lineCount == 4) {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, "Lines [ALL ON]");
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkGreen);
   } else if(lineCount == 0) {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, "Lines Control");
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkGray);
   } else {
      ObjectSetString(0, btn4Name, OBJPROP_TEXT, StringFormat("Lines [%d/4]", lineCount));
      ObjectSetInteger(0, btn4Name, OBJPROP_BGCOLOR, clrDarkOrange);
   }
   ObjectSetInteger(0, btn4Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn4Name, OBJPROP_STATE, false);
   
   // Update Button 5: Toggle Labels (Info Labels)
   string btn11Name = "BtnToggleLabels";
   if(g_showLabels) {
      ObjectSetString(0, btn11Name, OBJPROP_TEXT, "Labels [ON]");
      ObjectSetInteger(0, btn11Name, OBJPROP_BGCOLOR, clrGreen);
      ObjectSetInteger(0, btn11Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn11Name, OBJPROP_STATE, true);
   } else {
      ObjectSetString(0, btn11Name, OBJPROP_TEXT, "Show Labels");
      ObjectSetInteger(0, btn11Name, OBJPROP_BGCOLOR, clrDarkGray);
      ObjectSetInteger(0, btn11Name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn11Name, OBJPROP_STATE, false);
   }
   
   // Update Button 6: Print Stats (always same appearance)
   string btn6Name = "BtnPrintStats";
   ObjectSetString(0, btn6Name, OBJPROP_TEXT, "Print Stats");
   ObjectSetInteger(0, btn6Name, OBJPROP_BGCOLOR, clrDarkBlue);
   ObjectSetInteger(0, btn6Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn6Name, OBJPROP_STATE, false);
   
   // Update Button 7: Debug Level
   string btn7Name = "BtnDebugLevel";
   string debugText = "";
   color debugColor = clrDarkGray;
   
   switch(g_currentDebugLevel) {
      case 0:
         debugText = "Debug: OFF";
         debugColor = clrDarkGray;
         break;
      case 1:
         debugText = "Debug: CRITICAL";
         debugColor = clrDarkRed;
         break;
      case 2:
         debugText = "Debug: INFO";
         debugColor = clrDarkOrange;
         break;
      case 3:
         debugText = "Debug: VERBOSE";
         debugColor = clrDarkGreen;
         break;
      default:
         debugText = StringFormat("Debug: %d", g_currentDebugLevel);
         debugColor = clrDarkBlue;
         break;
   }
   
   ObjectSetString(0, btn7Name, OBJPROP_TEXT, debugText);
   ObjectSetInteger(0, btn7Name, OBJPROP_BGCOLOR, debugColor);
   ObjectSetInteger(0, btn7Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn7Name, OBJPROP_STATE, false);
   
   // Update Button 8: Single Trail Mode
   string btn8Name = "BtnSingleTrail";
   string trailText = "";
   color trailColor = clrDarkBlue;
   
   switch(g_singleTrailMode) {
      case 0:
         trailText = "STrail: TIGHT";
         trailColor = clrDarkRed;  // Closes sooner
         break;
      case 1:
         trailText = "STrail: NORMAL";
         trailColor = clrDarkBlue;  // Default
         break;
      case 2:
         trailText = "STrail: LOOSE";
         trailColor = clrDarkGreen;  // Trails longer
         break;
      default:
         trailText = StringFormat("STrail: %d", g_singleTrailMode);
         trailColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn8Name, OBJPROP_TEXT, trailText);
   ObjectSetInteger(0, btn8Name, OBJPROP_BGCOLOR, trailColor);
   ObjectSetInteger(0, btn8Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn8Name, OBJPROP_STATE, false);
   
   // Update Button 9: Total Trail Mode
   string btn9Name = "BtnTotalTrail";
   string totalTrailText = "";
   color totalTrailColor = clrDarkBlue;
   
   switch(g_totalTrailMode) {
      case 0:
         totalTrailText = "TTrail: TIGHT";
         totalTrailColor = clrDarkRed;  // Closes sooner
         break;
      case 1:
         totalTrailText = "TTrail: NORMAL";
         totalTrailColor = clrDarkBlue;  // Default
         break;
      case 2:
         totalTrailText = "TTrail: LOOSE";
         totalTrailColor = clrDarkGreen;  // Trails longer
         break;
      default:
         totalTrailText = StringFormat("TTrail: %d", g_totalTrailMode);
         totalTrailColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn9Name, OBJPROP_TEXT, totalTrailText);
   ObjectSetInteger(0, btn9Name, OBJPROP_BGCOLOR, totalTrailColor);
   ObjectSetInteger(0, btn9Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn9Name, OBJPROP_STATE, false);
   
   // Update History Mode button
   switch(g_historyDisplayMode) {
      case 0:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:Overall");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkGreen);
         break;
      case 1:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:SymAll");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkCyan);
         break;
      case 2:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:SymMag");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkOrange);
         break;
      case 3:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:PerSym");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkViolet);
         break;
      default:
         ObjectSetString(0, "BtnHistoryMode", OBJPROP_TEXT, "Hist:Overall");
         ObjectSetInteger(0, "BtnHistoryMode", OBJPROP_BGCOLOR, clrDarkGreen);
         break;
   }
   
   // Update Button 10: Trail Method Strategy
   string btn10Name = "BtnTrailMethod";
   string methodText = "";
   color methodColor = clrDarkSlateGray;
   
   // Show single trail activation status
   string singleStatus = "";
   switch(SingleTrailActivation) {
      case SINGLE_ACTIVATION_IGNORE:  singleStatus = "OFF"; break;
      case SINGLE_ACTIVATION_PROFIT:  singleStatus = "PROFIT"; break;
      case SINGLE_ACTIVATION_LEVEL:   singleStatus = "LEVEL"; break;
      default: singleStatus = "?"; break;
   }
   
   // Show group trail method
   switch(g_currentGroupTrailMethod) {
      case GROUP_TRAIL_IGNORE:
         methodText = StringFormat("S-%s G-OFF", singleStatus);
         methodColor = clrDarkSlateGray;
         break;
      case GROUP_TRAIL_CLOSETOGETHER:
         methodText = StringFormat("S-%s G-ANY", singleStatus);
         methodColor = clrDarkOliveGreen;
         break;
      case GROUP_TRAIL_CLOSETOGETHER_SAMETYPE:
         methodText = StringFormat("S-%s G-SAME", singleStatus);
         methodColor = clrDarkCyan;
         break;
      case GROUP_TRAIL_DYNAMIC:
         methodText = StringFormat("S-%s G-DYN", singleStatus);
         methodColor = clrDarkMagenta;
         break;
      case GROUP_TRAIL_DYNAMIC_SAMETYPE:
         methodText = StringFormat("S-%s G-DYNS", singleStatus);
         methodColor = clrDarkViolet;
         break;
      case GROUP_TRAIL_DYNAMIC_ANYSIDE:
         methodText = StringFormat("S-%s G-DYNA", singleStatus);
         methodColor = clrIndigo;
         break;
      case GROUP_TRAIL_HYBRID_BALANCED:
         methodText = StringFormat("S-%s G-BAL", singleStatus);
         methodColor = clrDarkOrange;
         break;
      case GROUP_TRAIL_HYBRID_ADAPTIVE:
         methodText = StringFormat("S-%s G-ADP", singleStatus);
         methodColor = clrSaddleBrown;
         break;
      case GROUP_TRAIL_HYBRID_SMART:
         methodText = StringFormat("S-%s G-SMT", singleStatus);
         methodColor = clrDarkGoldenrod;
         break;
      case GROUP_TRAIL_HYBRID_COUNT_DIFF:
         methodText = StringFormat("S-%s G-CNT", singleStatus);
         methodColor = clrMaroon;
         break;
      default:
         methodText = StringFormat("S-%s G-%d", singleStatus, g_currentGroupTrailMethod);
         methodColor = clrDarkGray;
         break;
   }
   
   ObjectSetString(0, btn10Name, OBJPROP_TEXT, methodText);
   ObjectSetInteger(0, btn10Name, OBJPROP_BGCOLOR, methodColor);
   ObjectSetInteger(0, btn10Name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn10Name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btn10Name, OBJPROP_HIDDEN, false);
   
   // Update Button 11: Order Labels (deprecated - now in Lines Control)
   string btnOldOrderLabels = "BtnOrderLabels";
   if(g_showOrderLabels) {
      ObjectSetString(0, btnOldOrderLabels, OBJPROP_TEXT, "Order Labels: ON");
      ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnOldOrderLabels, OBJPROP_TEXT, "Order Labels: OFF");
      ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnOldOrderLabels, OBJPROP_HIDDEN, false);
   
   // Update Button 12: Reset Counters (always same appearance)
   string btn12Name = "BtnResetCounters";
   ObjectSet