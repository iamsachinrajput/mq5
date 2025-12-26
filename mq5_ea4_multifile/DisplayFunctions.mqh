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
   
   // Update Button: Trade Logging Toggle
   string btnLogging = "BtnTradeLogging";
   if(g_tradeLoggingActive) {
      ObjectSetString(0, btnLogging, OBJPROP_TEXT, "Log: ON");
      ObjectSetInteger(0, btnLogging, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnLogging, OBJPROP_TEXT, "Log: OFF");
      ObjectSetInteger(0, btnLogging, OBJPROP_BGCOLOR, clrDarkRed);
   }
   ObjectSetInteger(0, btnLogging, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnLogging, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnLogging, OBJPROP_HIDDEN, false);
   
   // Update Button: Level Lines Toggle
   string btnLevels = "BtnLevelLines";
   if(g_showLevelLines) {
      ObjectSetString(0, btnLevels, OBJPROP_TEXT, "Levels: ON");
      ObjectSetInteger(0, btnLevels, OBJPROP_BGCOLOR, clrDarkGreen);
   } else {
      ObjectSetString(0, btnLevels, OBJPROP_TEXT, "Levels: OFF");
      ObjectSetInteger(0, btnLevels, OBJPROP_BGCOLOR, clrDarkGray);
   }
   ObjectSetInteger(0, btnLevels, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnLevels, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnLevels, OBJPROP_HIDDEN, false);
   
   ChartRedraw(0);
}

//============================= SELECTION PANEL FUNCTIONS ==========//
void CreateSelectionPanel(string panelType) {
   // Remove any existing selection panel first
   DestroySelectionPanel();
   
   // Get chart dimensions
   long chartWidth = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   long chartHeight = ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   
   int buttonWidth = 150;
   int buttonHeight = 30;
   int rightMargin = BtnXDistance;
   int topMargin = BtnYDistance;
   int verticalGap = 5;
   
   // Panel background (semi-transparent dark background)
   string bgName = "SelectionPanelBG";
   ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, rightMargin + buttonWidth + 10);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, topMargin);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, 180);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
   ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, bgName, OBJPROP_HIDDEN, true);
   
   int yOffset = 10;
   
   if(panelType == "DebugLevel") {
      g_activeSelectionPanel = "DebugLevel";
      ObjectSetInteger(0, bgName, OBJPROP_YSIZE, 4 * (buttonHeight + 5) + 20);
      
      string options[] = {"OFF", "CRITICAL", "INFO", "VERBOSE"};
      color colors[] = {clrDarkGray, clrDarkRed, clrDarkOrange, clrDarkGreen};
      
      for(int i = 0; i < 4; i++) {
         string btnName = StringFormat("SelectDebug_%d", i);
         ObjectCreate(0, btnName, OBJ_BUTTON, 0, 0, 0);
         ObjectSetInteger(0, btnName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
         ObjectSetInteger(0, btnName, OBJPROP_XDISTANCE, rightMargin + buttonWidth + 20);
         ObjectSetInteger(0, btnName, OBJPROP_YDISTANCE, topMargin + yOffset);
         ObjectSetInteger(0, btnName, OBJPROP_XSIZE, 160);
         ObjectSetInteger(0, btnName, OBJPROP_YSIZE, buttonHeight);
         ObjectSetString(0, btnName, OBJPROP_TEXT, options[i]);
         ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, colors[i]);
         ObjectSetInteger(0, btnName, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, btnName, OBJPROP_FONTSIZE, 10);
         ObjectSetInteger(0, btnName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, btnName, OBJPROP_HIDDEN, true);
         yOffset += buttonHeight + 5;
      }
   }
   else if(panelType == "SingleTrail") {
      g_activeSelectionPanel = "SingleTrail";
      ObjectSetInteger(0, bgName, OBJPROP_YSIZE, 3 * (buttonHeight + 5) + 20);
      
      string options[] = {"TIGHT (0.5x)", "NORMAL (1.0x)", "LOOSE (2.0x)"};
      color colors[] = {clrDarkRed, clrDarkBlue, clrDarkGreen};
      
      for(int i = 0; i < 3; i++) {
         string btnName = StringFormat("SelectSTrail_%d", i);
         ObjectCreate(0, btnName, OBJ_BUTTON, 0, 0, 0);
         ObjectSetInteger(0, btnName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
         ObjectSetInteger(0, btnName, OBJPROP_XDISTANCE, rightMargin + buttonWidth + 20);
         ObjectSetInteger(0, btnName, OBJPROP_YDISTANCE, topMargin + (buttonHeight + verticalGap) + yOffset);
         ObjectSetInteger(0, btnName, OBJPROP_XSIZE, 160);
         ObjectSetInteger(0, btnName, OBJPROP_YSIZE, buttonHeight);
         ObjectSetString(0, btnName, OBJPROP_TEXT, options[i]);
         ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, colors[i]);
         ObjectSetInteger(0, btnName, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, btnName, OBJPROP_FONTSIZE, 10);
         ObjectSetInteger(0, btnName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, btnName, OBJPROP_HIDDEN, true);
         yOffset += buttonHeight + 5;
      }
   }
   else if(panelType == "TotalTrail") {
      g_activeSelectionPanel = "TotalTrail";
      ObjectSetInteger(0, bgName, OBJPROP_YSIZE, 3 * (buttonHeight + 5) + 20);
      
      string options[] = {"TIGHT (0.5x)", "NORMAL (1.0x)", "LOOSE (2.0x)"};
      color colors[] = {clrDarkRed, clrDarkBlue, clrDarkGreen};
      
      for(int i = 0; i < 3; i++) {
         string btnName = StringFormat("SelectTTrail_%d", i);
         ObjectCreate(0, btnName, OBJ_BUTTON, 0, 0, 0);
         ObjectSetInteger(0, btnName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
         ObjectSetInteger(0, btnName, OBJPROP_XDISTANCE, rightMargin + buttonWidth + 20);
         ObjectSetInteger(0, btnName, OBJPROP_YDISTANCE, topMargin + 2 * (buttonHeight + verticalGap) + yOffset);
         ObjectSetInteger(0, btnName, OBJPROP_XSIZE, 160);
         ObjectSetInteger(0, btnName, OBJPROP_YSIZE, buttonHeight);
         ObjectSetString(0, btnName, OBJPROP_TEXT, options[i]);
         ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, colors[i]);
         ObjectSetInteger(0, btnName, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, btnName, OBJPROP_FONTSIZE, 10);
         ObjectSetInteger(0, btnName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, btnName, OBJPROP_HIDDEN, true);
         yOffset += buttonHeight + 5;
      }
   }
   else if(panelType == "TrailMethod") {
      g_activeSelectionPanel = "TrailMethod";
      ObjectSetInteger(0, bgName, OBJPROP_YSIZE, 10 * (buttonHeight + 5) + 20);
      
      string options[] = {
         "NORMAL", "ANYSIDE", "SAMETYPE", "DYNAMIC", "DYN-SAME",
         "DYN-ANY", "HYB-BAL", "HYB-ADP", "HYB-SMART", "HYB-CNT"
      };
      color colors[] = {
         clrDarkSlateGray, clrDarkOliveGreen, clrDarkCyan, clrDarkMagenta, clrDarkViolet,
         clrIndigo, clrDarkOrange, clrSaddleBrown, clrDarkGoldenrod, clrMaroon
      };
      
      for(int i = 0; i < 10; i++) {
         string btnName = StringFormat("SelectMethod_%d", i);
         ObjectCreate(0, btnName, OBJ_BUTTON, 0, 0, 0);
         ObjectSetInteger(0, btnName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
         ObjectSetInteger(0, btnName, OBJPROP_XDISTANCE, rightMargin + buttonWidth + 20);
         ObjectSetInteger(0, btnName, OBJPROP_YDISTANCE, topMargin + 3 * (buttonHeight + verticalGap) + yOffset);
         ObjectSetInteger(0, btnName, OBJPROP_XSIZE, 160);
         ObjectSetInteger(0, btnName, OBJPROP_YSIZE, buttonHeight);
         ObjectSetString(0, btnName, OBJPROP_TEXT, options[i]);
         ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, colors[i]);
         ObjectSetInteger(0, btnName, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, btnName, OBJPROP_FONTSIZE, 10);
         ObjectSetInteger(0, btnName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, btnName, OBJPROP_HIDDEN, true);
         yOffset += buttonHeight + 5;
      }
   }
   else if(panelType == "HistoryMode") {
      g_activeSelectionPanel = "HistoryMode";
      ObjectSetInteger(0, bgName, OBJPROP_YSIZE, 4 * (buttonHeight + 5) + 20);
      
      string options[] = {
         "Overall (All/All)", "CurSym (AllMagic)", "CurSym (CurMagic)", "Per-Symbol"
      };
      color colors[] = {clrDarkGreen, clrDarkCyan, clrDarkOrange, clrDarkViolet};
      
      for(int i = 0; i < 4; i++) {
         string btnName = StringFormat("SelectHistory_%d", i);
         ObjectCreate(0, btnName, OBJ_BUTTON, 0, 0, 0);
         ObjectSetInteger(0, btnName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
         ObjectSetInteger(0, btnName, OBJPROP_XDISTANCE, rightMargin + buttonWidth + 20);
         ObjectSetInteger(0, btnName, OBJPROP_YDISTANCE, topMargin + 10 * (buttonHeight + verticalGap) + yOffset);
         ObjectSetInteger(0, btnName, OBJPROP_XSIZE, 160);
         ObjectSetInteger(0, btnName, OBJPROP_YSIZE, buttonHeight);
         ObjectSetString(0, btnName, OBJPROP_TEXT, options[i]);
         ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, colors[i]);
         ObjectSetInteger(0, btnName, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, btnName, OBJPROP_FONTSIZE, 9);
         ObjectSetInteger(0, btnName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, btnName, OBJPROP_HIDDEN, true);
         yOffset += buttonHeight + 5;
      }
   }
   
   // Label Control Panel - Individual label show/hide
   else if(panelType == "LabelControl") {
      g_activeSelectionPanel = "LabelControl";
      
      string labelTexts[] = {
         "CurrentProfit", "PositionDetails", "SpreadEquity", "NextLotCalc",
         "SingleTrail", "GroupTrail", "TotalTrail", "LevelInfo",
         "NearbyOrders", "Last5Closes", "HistoryDisplay",
         "CenterProfit", "CenterCycle", "CenterBooked", "CenterNetLots"
      };
      bool labelStates[] = {
         g_showCurrentProfitLabel, g_showPositionDetailsLabel, g_showSpreadEquityLabel, g_showNextLotCalcLabel,
         g_showSingleTrailLabel, g_showGroupTrailLabel, g_showTotalTrailLabel, g_showLevelInfoLabel,
         g_showNearbyOrdersLabel, g_showLast5ClosesLabel, g_showHistoryDisplayLabel,
         g_showCenterProfitLabel, g_showCenterCycleLabel, g_showCenterBookedLabel, g_showCenterNetLotsLabel
      };
      
      int labelCount = 15;
      // Panel height: 1 ALL button + 15 label buttons + padding
      ObjectSetInteger(0, bgName, OBJPROP_YSIZE, (labelCount + 1) * (buttonHeight + 5) + 20);
      
      // Create ALL button at the top
      string btnAllName = "SelectLabel_ALL";
      // Check if all labels are currently shown
      bool allVisible = g_showCurrentProfitLabel && g_showPositionDetailsLabel && g_showSpreadEquityLabel && g_showNextLotCalcLabel &&
                        g_showSingleTrailLabel && g_showGroupTrailLabel && g_showTotalTrailLabel && g_showLevelInfoLabel &&
                        g_showNearbyOrdersLabel && g_showLast5ClosesLabel && g_showHistoryDisplayLabel &&
                        g_showCenterProfitLabel && g_showCenterCycleLabel && g_showCenterBookedLabel && g_showCenterNetLotsLabel;
      
      ObjectCreate(0, btnAllName, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, btnAllName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, btnAllName, OBJPROP_XDISTANCE, rightMargin + buttonWidth + 20);
      ObjectSetInteger(0, btnAllName, OBJPROP_YDISTANCE, topMargin + yOffset);
      ObjectSetInteger(0, btnAllName, OBJPROP_XSIZE, 160);
      ObjectSetInteger(0, btnAllName, OBJPROP_YSIZE, buttonHeight);
      ObjectSetString(0, btnAllName, OBJPROP_TEXT, allVisible ? "✓ ALL" : "✗ ALL");
      ObjectSetInteger(0, btnAllName, OBJPROP_BGCOLOR, allVisible ? clrDarkGreen : clrDarkRed);
      ObjectSetInteger(0, btnAllName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btnAllName, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, btnAllName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, btnAllName, OBJPROP_HIDDEN, true);
      yOffset += buttonHeight + 5;
      
      for(int i = 0; i < labelCount; i++) {
         string btnName = StringFormat("SelectLabel_%d", i);
         ObjectCreate(0, btnName, OBJ_BUTTON, 0, 0, 0);
         ObjectSetInteger(0, btnName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
         ObjectSetInteger(0, btnName, OBJPROP_XDISTANCE, rightMargin + buttonWidth + 20);
         ObjectSetInteger(0, btnName, OBJPROP_YDISTANCE, topMargin + yOffset);
         ObjectSetInteger(0, btnName, OBJPROP_XSIZE, 160);
         ObjectSetInteger(0, btnName, OBJPROP_YSIZE, buttonHeight);
         string btnText = labelStates[i] ? ("✓ " + labelTexts[i]) : ("✗ " + labelTexts[i]);
         ObjectSetString(0, btnName, OBJPROP_TEXT, btnText);
         ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, labelStates[i] ? clrDarkGreen : clrDarkRed);
         ObjectSetInteger(0, btnName, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, btnName, OBJPROP_FONTSIZE, 9);
         ObjectSetInteger(0, btnName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, btnName, OBJPROP_HIDDEN, true);
         yOffset += buttonHeight + 5;
      }
   }
   
   // Lines Control Panel - Individual line type show/hide
   else if(panelType == "LinesControl") {
      g_activeSelectionPanel = "LinesControl";
      // Add a separate button for Label Lines and Level Lines
      string lineTexts[] = {"VLines", "HLines", "Next Lines", "Label Lines", "Level Lines", "Order Labels"};
      bool lineStates[] = {g_showVLines, g_showHLines, g_showNextLevelLines, g_showLabelLines, g_showLevelLines, g_showOrderLabelsCtrl};
      int lineCount = 6;

      // Calculate panel height and align background with buttons
      int panelYOffset = yOffset;
      int panelHeight = (lineCount + 1) * (buttonHeight + 5) + 20;
      ObjectSetInteger(0, bgName, OBJPROP_YSIZE, panelHeight);
      ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, topMargin + panelYOffset);

      // Create ALL button at the top
      string btnAllName = "SelectLine_ALL";
      bool allVisible = g_showVLines && g_showHLines && g_showNextLevelLines && g_showLabelLines && g_showLevelLines && g_showOrderLabelsCtrl;

      ObjectCreate(0, btnAllName, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, btnAllName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, btnAllName, OBJPROP_XDISTANCE, rightMargin + buttonWidth + 20);
      ObjectSetInteger(0, btnAllName, OBJPROP_YDISTANCE, topMargin + panelYOffset + 5);
      ObjectSetInteger(0, btnAllName, OBJPROP_XSIZE, 160);
      ObjectSetInteger(0, btnAllName, OBJPROP_YSIZE, buttonHeight);
      ObjectSetString(0, btnAllName, OBJPROP_TEXT, allVisible ? "✓ ALL" : "✗ ALL");
      ObjectSetInteger(0, btnAllName, OBJPROP_BGCOLOR, allVisible ? clrDarkGreen : clrDarkRed);
      ObjectSetInteger(0, btnAllName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btnAllName, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, btnAllName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, btnAllName, OBJPROP_HIDDEN, true);

      int btnYOffset = panelYOffset + buttonHeight + 10;
      for(int i = 0; i < lineCount; i++) {
         string btnName = StringFormat("SelectLine_%d", i);
         ObjectCreate(0, btnName, OBJ_BUTTON, 0, 0, 0);
         ObjectSetInteger(0, btnName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
         ObjectSetInteger(0, btnName, OBJPROP_XDISTANCE, rightMargin + buttonWidth + 20);
         ObjectSetInteger(0, btnName, OBJPROP_YDISTANCE, topMargin + btnYOffset);
         ObjectSetInteger(0, btnName, OBJPROP_XSIZE, 160);
         ObjectSetInteger(0, btnName, OBJPROP_YSIZE, buttonHeight);
         string btnText = lineStates[i] ? ("✓ " + lineTexts[i]) : ("✗ " + lineTexts[i]);
         ObjectSetString(0, btnName, OBJPROP_TEXT, btnText);
         ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, lineStates[i] ? clrDarkGreen : clrDarkRed);
         ObjectSetInteger(0, btnName, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, btnName, OBJPROP_FONTSIZE, 10);
         ObjectSetInteger(0, btnName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, btnName, OBJPROP_HIDDEN, true);
         btnYOffset += buttonHeight + 5;
      }
   }
   
   // Unified Visibility Controls Panel (only Buttons show/hide)
   else if(panelType == "VisibilityControls") {
      g_activeSelectionPanel = "VisibilityControls";
      
      int buttonWidth = 80;
      
      ObjectSetInteger(0, bgName, OBJPROP_YSIZE, 1 * (buttonHeight + 5) + 20);
      ObjectSetInteger(0, bgName, OBJPROP_XSIZE, buttonWidth * 2 + 30);  // Width for 2 columns
      
      // Fixed position: Left-Upper corner at 200x, 200y
      ENUM_BASE_CORNER panelCorner = CORNER_LEFT_UPPER;
      int panelX = 200;
      int panelY = 200;
      
      ObjectSetInteger(0, bgName, OBJPROP_CORNER, panelCorner);
      ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, panelX);
      ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, panelY);
      
      yOffset = 10;
      
      // Show button (left column)
      string showBtnName = "SelectShow_0";
      ObjectCreate(0, showBtnName, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, showBtnName, OBJPROP_CORNER, panelCorner);
      ObjectSetInteger(0, showBtnName, OBJPROP_XDISTANCE, panelX + 10);
      ObjectSetInteger(0, showBtnName, OBJPROP_YDISTANCE, panelY + yOffset);
      ObjectSetInteger(0, showBtnName, OBJPROP_XSIZE, buttonWidth);
      ObjectSetInteger(0, showBtnName, OBJPROP_YSIZE, buttonHeight);
      ObjectSetString(0, showBtnName, OBJPROP_TEXT, "✓ Buttons");
      ObjectSetInteger(0, showBtnName, OBJPROP_BGCOLOR, clrDarkGreen);
      ObjectSetInteger(0, showBtnName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, showBtnName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, showBtnName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, showBtnName, OBJPROP_HIDDEN, false);
      
      // Hide button (right column)
      string hideBtnName = "SelectHide_0";
      ObjectCreate(0, hideBtnName, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, hideBtnName, OBJPROP_CORNER, panelCorner);
      ObjectSetInteger(0, hideBtnName, OBJPROP_XDISTANCE, panelX + 10 + buttonWidth + 5);
      ObjectSetInteger(0, hideBtnName, OBJPROP_YDISTANCE, panelY + yOffset);
      ObjectSetInteger(0, hideBtnName, OBJPROP_XSIZE, buttonWidth);
      ObjectSetInteger(0, hideBtnName, OBJPROP_YSIZE, buttonHeight);
      ObjectSetString(0, hideBtnName, OBJPROP_TEXT, "✗ Buttons");
      ObjectSetInteger(0, hideBtnName, OBJPROP_BGCOLOR, clrDarkRed);
      ObjectSetInteger(0, hideBtnName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, hideBtnName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, hideBtnName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, hideBtnName, OBJPROP_HIDDEN, false);
   }
   
   ChartRedraw(0);
}

void DestroySelectionPanel() {
   if(g_activeSelectionPanel == "") return;
   
   // Delete background
   ObjectDelete(0, "SelectionPanelBG");
   
   // Delete all selection buttons based on panel type
   if(g_activeSelectionPanel == "DebugLevel") {
      for(int i = 0; i < 4; i++) {
         ObjectDelete(0, StringFormat("SelectDebug_%d", i));
      }
   }
   else if(g_activeSelectionPanel == "SingleTrail") {
      for(int i = 0; i < 3; i++) {
         ObjectDelete(0, StringFormat("SelectSTrail_%d", i));
      }
   }
   else if(g_activeSelectionPanel == "TotalTrail") {
      for(int i = 0; i < 3; i++) {
         ObjectDelete(0, StringFormat("SelectTTrail_%d", i));
      }
   }
   else if(g_activeSelectionPanel == "TrailMethod") {
      for(int i = 0; i < 10; i++) {
         ObjectDelete(0, StringFormat("SelectMethod_%d", i));
      }
   }
   else if(g_activeSelectionPanel == "HistoryMode") {
      for(int i = 0; i < 4; i++) {
         ObjectDelete(0, StringFormat("SelectHistory_%d", i));
      }
   }
   else if(g_activeSelectionPanel == "VisibilityControls") {
      // Delete both Show and Hide buttons from unified panel
      ObjectDelete(0, "SelectShow_0");
      ObjectDelete(0, "SelectHide_0");
   }
   else if(g_activeSelectionPanel == "LabelControl") {
      // Delete ALL button
      ObjectDelete(0, "SelectLabel_ALL");
      // Delete all 15 label selection buttons
      for(int i = 0; i < 15; i++) {
         ObjectDelete(0, StringFormat("SelectLabel_%d", i));
      }
   }
   else if(g_activeSelectionPanel == "LinesControl") {
      // Delete ALL button
      ObjectDelete(0, "SelectLine_ALL");
      // Delete all 6 line selection buttons (VLines, HLines, Next Lines, Label Lines, Level Lines, Order Labels)
      for(int i = 0; i < 6; i++) {
         ObjectDelete(0, StringFormat("SelectLine_%d", i));
      }
   }
   
   ObjectDelete(0, "SelectionPanelBg");
   g_activeSelectionPanel = "";
   ChartRedraw(0);
}

//============================= VISIBILITY CONTROL FUNCTIONS =======//
void ApplyVisibilitySettings() {
   // Apply main button visibility
   string mainButtons[] = {
      "BtnStopNewOrders", "BtnNoWork", "BtnCloseAll", "BtnResetCounters",
      "BtnCloseProfit", "BtnSingleTrail", "BtnTotalTrail", "BtnLinesControl", 
      "BtnToggleLabels", "BtnTrailMethod", "BtnHistoryMode", 
      "BtnDebugLevel", "BtnPrintStats", "BtnToggleVLines", "BtnToggleHLines", "BtnTradeLogging", "BtnLevelLines"
   };
   
   if(g_showMainButtons) {
      // Show buttons - recreate them if they don't exist
      CreateButtons();
      UpdateButtonStates();
   } else {
      // Hide buttons - delete them
      for(int i = 0; i < ArraySize(mainButtons); i++) {
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
      ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
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
      
      // Button 5: Lines Control - Show selection panel for line types
      if(sparam == "BtnLinesControl") {
         if(g_activeSelectionPanel == "LinesControl") {
            DestroySelectionPanel();
         } else {
            CreateSelectionPanel("LinesControl");
         }
         return;
      }
      
      // Button 6: Toggle Labels - Show selection panel for individual label control
      if(sparam == "BtnToggleLabels") {
         if(g_activeSelectionPanel == "LabelControl") {
            DestroySelectionPanel();
         } else {
            CreateSelectionPanel("LabelControl");
         }
         return;
      }
      
      // Button 7: Print Stats
      if(sparam == "BtnPrintStats") {
         PrintCurrentStats();
         Log(1, "Stats printed to log");
      }
      
      // Button 11: History Display Mode (show selection panel)
      if(sparam == "BtnHistoryMode") {
         if(g_activeSelectionPanel == "HistoryMode") {
            DestroySelectionPanel();
         } else {
            CreateSelectionPanel("HistoryMode");
         }
      }
      
      // Button 15: Toggle VLines
      if(sparam == "BtnToggleVLines") {
         g_showVLines = !g_showVLines;
         UpdateButtonStates();
         ApplyVisibilitySettings();
         Log(1, StringFormat("VLines Display: %s", g_showVLines ? "ENABLED" : "DISABLED"));
      }
      
      // Button 16: Toggle HLines
      if(sparam == "BtnToggleHLines") {
         g_showHLines = !g_showHLines;
         UpdateButtonStates();
         ApplyVisibilitySettings();
         Log(1, StringFormat("HLines Display: %s", g_showHLines ? "ENABLED" : "DISABLED"));
      }
      
      // Permanent Control Button (Always Visible) - Direct Toggle
      if(sparam == "BtnVisibilityControls") {
         g_showMainButtons = !g_showMainButtons;
         ApplyVisibilitySettings();
         UpdateButtonStates();
         Log(1, StringFormat("Main Buttons: %s", g_showMainButtons ? "SHOWN" : "HIDDEN"));
      }
      
      // Handle Show Control selections
      if(StringFind(sparam, "SelectShow_") >= 0) {
         int selectedOption = (int)StringToInteger(StringSubstr(sparam, 11));
         switch(selectedOption) {
            case 0: g_showMainButtons = true; break;       // Buttons
            case 1: g_showInfoLabels = true; break;        // InfoLabels
            case 2: g_showOrderLabelsCtrl = true; break;   // OrderLabels
            case 3: g_showVLines = true; break;            // VLines
            case 4: g_showHLines = true; break;            // HLines
         }
         DestroySelectionPanel();
         ApplyVisibilitySettings();
         Log(2, StringFormat("Show control activated: option %d", selectedOption));
      }
      
      // Handle Hide Control selections
      if(StringFind(sparam, "SelectHide_") >= 0) {
         int selectedOption = (int)StringToInteger(StringSubstr(sparam, 11));
         switch(selectedOption) {
            case 0: g_showMainButtons = false; break;      // Buttons
            case 1: g_showInfoLabels = false; break;       // InfoLabels
            case 2: g_showOrderLabelsCtrl = false; break;  // OrderLabels
            case 3: g_showVLines = false; break;           // VLines
            case 4: g_showHLines = false; break;           // HLines
         }
         DestroySelectionPanel();
         ApplyVisibilitySettings();
         Log(2, StringFormat("Hide control activated: option %d", selectedOption));
      }
      
      // Button 7: Debug Level (show selection panel)
      if(sparam == "BtnDebugLevel") {
         if(g_activeSelectionPanel == "DebugLevel") {
            DestroySelectionPanel();
         } else {
            CreateSelectionPanel("DebugLevel");
         }
      }
      
      // Button: Trade Logging Toggle
      if(sparam == "BtnTradeLogging") {
         g_tradeLoggingActive = !g_tradeLoggingActive;
         if(g_tradeLoggingActive) {
            InitializeTradeLog();  // Initialize log file when enabled
         }
         UpdateButtonStates();
         Log(1, StringFormat("Trade Logging: %s", g_tradeLoggingActive ? "ENABLED" : "DISABLED"));
      }
      
      // Button: Level Lines Toggle
      if(sparam == "BtnLevelLines") {
         g_showLevelLines = !g_showLevelLines;
         if(g_showLevelLines) {
            DrawLevelLines();
         } else {
            RemoveLevelLines();
         }
         UpdateButtonStates();
         Log(1, StringFormat("Level Lines: %s", g_showLevelLines ? "SHOWN" : "HIDDEN"));
      }
      
      // Handle Debug Level selections
      if(StringFind(sparam, "SelectDebug_") >= 0) {
         int selectedLevel = (int)StringToInteger(StringSubstr(sparam, 12)); // Extract number from "SelectDebug_X"
         g_currentDebugLevel = selectedLevel;
         DestroySelectionPanel();
         UpdateButtonStates();
         string levelName = "";
         switch(g_currentDebugLevel) {
            case 0: levelName = "OFF"; break;
            case 1: levelName = "CRITICAL"; break;
            case 2: levelName = "INFO"; break;
            case 3: levelName = "VERBOSE"; break;
         }
         Log(1, StringFormat("Debug Level changed to: %d (%s)", g_currentDebugLevel, levelName));
      }
      
      // Handle History Mode selections
      if(StringFind(sparam, "SelectHistory_") >= 0) {
         int selectedMode = (int)StringToInteger(StringSubstr(sparam, 14)); // Extract number from "SelectHistory_X"
         g_historyDisplayMode = selectedMode;
         DestroySelectionPanel();
         UpdateButtonStates();
         string modeName = "";
         switch(g_historyDisplayMode) {
            case 0: modeName = "Overall (All Symbols/All Magic)"; break;
            case 1: modeName = "Current Symbol (All Magic)"; break;
            case 2: modeName = "Current Symbol (Current Magic)"; break;
            case 3: modeName = "Per-Symbol Breakdown"; break;
         }
         Log(2, StringFormat("History Display Mode changed to: %d (%s)", g_historyDisplayMode, modeName));
      }
      
      // Handle Label Control selections
      // Handle Lines Control selections
      // Handle ALL lines toggle
      if(sparam == "SelectLine_ALL") {
         bool allVisible = g_showVLines && g_showHLines && g_showNextLevelLines && g_showOrderLabelsCtrl;
         
         // Toggle all lines to opposite of current state
         bool newState = !allVisible;
         g_showVLines = newState;
         g_showHLines = newState;
         g_showNextLevelLines = newState;
         g_showLevelLines = newState;  // Sync level lines with next lines
         g_showOrderLabelsCtrl = newState;
         
         // Apply visibility changes
         if(!g_showNextLevelLines) {
            RemoveLevelLines();
         } else {
            DrawLevelLines();
         }
         ApplyVisibilitySettings();
         
         // Update ALL button appearance
         ObjectSetInteger(0, "SelectLine_ALL", OBJPROP_BGCOLOR, newState ? clrDarkGreen : clrDarkRed);
         ObjectSetString(0, "SelectLine_ALL", OBJPROP_TEXT, newState ? "✓ ALL" : "✗ ALL");
         
         // Update all individual line buttons
         string lineNames[] = {"VLines", "HLines", "Next Lines", "Order Labels"};
         for(int i = 0; i < 4; i++) {
            string btnName = StringFormat("SelectLine_%d", i);
            ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, newState ? clrDarkGreen : clrDarkRed);
            ObjectSetString(0, btnName, OBJPROP_TEXT, newState ? ("✓ " + lineNames[i]) : ("✗ " + lineNames[i]));
         }
         
         Log(2, StringFormat("All lines toggled: %s", newState ? "VISIBLE" : "HIDDEN"));
      }
      
      if(StringFind(sparam, "SelectLine_") >= 0 && sparam != "SelectLine_ALL") {
         int selectedLine = (int)StringToInteger(StringSubstr(sparam, 11));
         
         // Toggle the selected line type
         switch(selectedLine) {
            case 0: // VLines
               g_showVLines = !g_showVLines;
               ApplyVisibilitySettings();
               Log(1, StringFormat("VLines: %s", g_showVLines ? "VISIBLE" : "HIDDEN"));
               break;
            case 1: // HLines
               g_showHLines = !g_showHLines;
               ApplyVisibilitySettings();
               Log(1, StringFormat("HLines: %s", g_showHLines ? "VISIBLE" : "HIDDEN"));
               break;
            case 2: // Next Lines
               g_showNextLevelLines = !g_showNextLevelLines;
               g_showLevelLines = g_showNextLevelLines;  // Sync level lines
               if(!g_showNextLevelLines) {
                  RemoveLevelLines();
               } else {
                  DrawLevelLines();
               }
               Log(1, StringFormat("Next Lines: %s", g_showNextLevelLines ? "VISIBLE" : "HIDDEN"));
               break;
            case 3: // Order Labels
               g_showOrderLabelsCtrl = !g_showOrderLabelsCtrl;
               if(!g_showOrderLabelsCtrl) {
                  HideAllOrderLabels();
               } else {
                  ShowAllOrderLabels();
               }
               Log(1, StringFormat("Order Labels: %s", g_showOrderLabelsCtrl ? "VISIBLE" : "HIDDEN"));
               break;
         }
         
         // Update button appearance
         string btnName = StringFormat("SelectLine_%d", selectedLine);
         bool isVisible = false;
         string lineNames[] = {"VLines", "HLines", "Next Lines", "Order Labels"};
         
         switch(selectedLine) {
            case 0: isVisible = g_showVLines; break;
            case 1: isVisible = g_showHLines; break;
            case 2: isVisible = g_showNextLevelLines; break;
            case 3: isVisible = g_showOrderLabelsCtrl; break;
         }
         
         ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, isVisible ? clrDarkGreen : clrDarkRed);
         ObjectSetString(0, btnName, OBJPROP_TEXT, isVisible ? ("✓ " + lineNames[selectedLine]) : ("✗ " + lineNames[selectedLine]));
      }
      
      // Handle Label Control selections
      // Handle ALL labels toggle
      if(sparam == "SelectLabel_ALL") {
         // Check current state - if any label is hidden, show all; if all are shown, hide all
         bool allVisible = g_showCurrentProfitLabel && g_showPositionDetailsLabel && g_showSpreadEquityLabel && g_showNextLotCalcLabel &&
                          g_showSingleTrailLabel && g_showGroupTrailLabel && g_showTotalTrailLabel && g_showLevelInfoLabel &&
                          g_showNearbyOrdersLabel && g_showLast5ClosesLabel && g_showHistoryDisplayLabel &&
                          g_showCenterProfitLabel && g_showCenterCycleLabel && g_showCenterBookedLabel && g_showCenterNetLotsLabel;
         
         // Toggle all labels to opposite of current state
         bool newState = !allVisible;
         g_showCurrentProfitLabel = newState;
         g_showPositionDetailsLabel = newState;
         g_showSpreadEquityLabel = newState;
         g_showNextLotCalcLabel = newState;
         g_showSingleTrailLabel = newState;
         g_showGroupTrailLabel = newState;
         g_showTotalTrailLabel = newState;
         g_showLevelInfoLabel = newState;
         g_showNearbyOrdersLabel = newState;
         g_showLast5ClosesLabel = newState;
         g_showHistoryDisplayLabel = newState;
         g_showCenterProfitLabel = newState;
         g_showCenterCycleLabel = newState;
         g_showCenterBookedLabel = newState;
         g_showCenterNetLotsLabel = newState;
         
         // Update ALL button appearance
         ObjectSetInteger(0, "SelectLabel_ALL", OBJPROP_BGCOLOR, newState ? clrDarkGreen : clrDarkRed);
         ObjectSetString(0, "SelectLabel_ALL", OBJPROP_TEXT, newState ? "✓ ALL" : "✗ ALL");
         
         // Update all individual label buttons
         string labelNames[] = {
            "CurrentProfit", "PositionDetails", "SpreadEquity", "NextLotCalc",
            "SingleTrail", "GroupTrail", "TotalTrail", "LevelInfo",
            "NearbyOrders", "Last5Closes", "HistoryDisplay",
            "CenterProfit", "CenterCycle", "CenterBooked", "CenterNetLots"
         };
         
         for(int i = 0; i < 15; i++) {
            string btnName = StringFormat("SelectLabel_%d", i);
            if(newState) {
               ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, clrDarkGreen);
               ObjectSetString(0, btnName, OBJPROP_TEXT, "✓ " + labelNames[i]);
            } else {
               ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, clrDarkRed);
               ObjectSetString(0, btnName, OBJPROP_TEXT, "✗ " + labelNames[i]);
            }
         }
         
         Log(2, StringFormat("All labels toggled: %s", newState ? "VISIBLE" : "HIDDEN"));
      }
      
      if(StringFind(sparam, "SelectLabel_") >= 0 && sparam != "SelectLabel_ALL") {
         int selectedLabel = (int)StringToInteger(StringSubstr(sparam, 12)); // Extract number from "SelectLabel_X"
         
         // Toggle the selected label
         switch(selectedLabel) {
            case 0: g_showCurrentProfitLabel = !g_showCurrentProfitLabel; break;
            case 1: g_showPositionDetailsLabel = !g_showPositionDetailsLabel; break;
            case 2: g_showSpreadEquityLabel = !g_showSpreadEquityLabel; break;
            case 3: g_showNextLotCalcLabel = !g_showNextLotCalcLabel; break;
            case 4: g_showSingleTrailLabel = !g_showSingleTrailLabel; break;
            case 5: g_showGroupTrailLabel = !g_showGroupTrailLabel; break;
            case 6: g_showTotalTrailLabel = !g_showTotalTrailLabel; break;
            case 7: g_showLevelInfoLabel = !g_showLevelInfoLabel; break;
            case 8: g_showNearbyOrdersLabel = !g_showNearbyOrdersLabel; break;
            case 9: g_showLast5ClosesLabel = !g_showLast5ClosesLabel; break;
            case 10: g_showHistoryDisplayLabel = !g_showHistoryDisplayLabel; break;
            case 11: g_showCenterProfitLabel = !g_showCenterProfitLabel; break;
            case 12: g_showCenterCycleLabel = !g_showCenterCycleLabel; break;
            case 13: g_showCenterBookedLabel = !g_showCenterBookedLabel; break;
            case 14: g_showCenterNetLotsLabel = !g_showCenterNetLotsLabel; break;
         }
         
         // Update button appearance to show current state
         string btnName = StringFormat("SelectLabel_%d", selectedLabel);
         bool isVisible = false;
         string labelNames[] = {
            "CurrentProfit", "PositionDetails", "SpreadEquity", "NextLotCalc",
            "SingleTrail", "GroupTrail", "TotalTrail", "LevelInfo",
            "NearbyOrders", "Last5Closes", "HistoryDisplay",
            "CenterProfit", "CenterCycle", "CenterBooked", "CenterNetLots"
         };
         
         switch(selectedLabel) {
            case 0: isVisible = g_showCurrentProfitLabel; break;
            case 1: isVisible = g_showPositionDetailsLabel; break;
            case 2: isVisible = g_showSpreadEquityLabel; break;
            case 3: isVisible = g_showNextLotCalcLabel; break;
            case 4: isVisible = g_showSingleTrailLabel; break;
            case 5: isVisible = g_showGroupTrailLabel; break;
            case 6: isVisible = g_showTotalTrailLabel; break;
            case 7: isVisible = g_showLevelInfoLabel; break;
            case 8: isVisible = g_showNearbyOrdersLabel; break;
            case 9: isVisible = g_showLast5ClosesLabel; break;
            case 10: isVisible = g_showHistoryDisplayLabel; break;
            case 11: isVisible = g_showCenterProfitLabel; break;
            case 12: isVisible = g_showCenterCycleLabel; break;
            case 13: isVisible = g_showCenterBookedLabel; break;
            case 14: isVisible = g_showCenterNetLotsLabel; break;
         }
         
         string labelName = (selectedLabel >= 0 && selectedLabel < 15) ? labelNames[selectedLabel] : "Unknown";
         if(isVisible) {
            ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, clrDarkGreen);
            ObjectSetString(0, btnName, OBJPROP_TEXT, "✓ " + labelName);
         } else {
            ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, clrDarkRed);
            ObjectSetString(0, btnName, OBJPROP_TEXT, "✗ " + labelName);
         }
         
         // Update ALL button state based on whether all labels are now visible
         bool allVisible = g_showCurrentProfitLabel && g_showPositionDetailsLabel && g_showSpreadEquityLabel && g_showNextLotCalcLabel &&
                          g_showSingleTrailLabel && g_showGroupTrailLabel && g_showTotalTrailLabel && g_showLevelInfoLabel &&
                          g_showNearbyOrdersLabel && g_showLast5ClosesLabel && g_showHistoryDisplayLabel &&
                          g_showCenterProfitLabel && g_showCenterCycleLabel && g_showCenterBookedLabel && g_showCenterNetLotsLabel;
         ObjectSetInteger(0, "SelectLabel_ALL", OBJPROP_BGCOLOR, allVisible ? clrDarkGreen : clrDarkRed);
         ObjectSetString(0, "SelectLabel_ALL", OBJPROP_TEXT, allVisible ? "✓ ALL" : "✗ ALL");
      }
      
      // Button 8: Single Trail Mode (show selection panel)
      if(sparam == "BtnSingleTrail") {
         if(g_activeSelectionPanel == "SingleTrail") {
            DestroySelectionPanel();
         } else {
            CreateSelectionPanel("SingleTrail");
         }
      }
      
      // Handle Single Trail selections
      if(StringFind(sparam, "SelectSTrail_") >= 0) {
         int selectedMode = (int)StringToInteger(StringSubstr(sparam, 13)); // Extract number from "SelectSTrail_X"
         g_singleTrailMode = selectedMode;
         DestroySelectionPanel();
         UpdateButtonStates();
         string modeName = "";
         double multiplier = 1.0;
         switch(g_singleTrailMode) {
            case 0: modeName = "TIGHT"; multiplier = 0.5; break;
            case 1: modeName = "NORMAL"; multiplier = 1.0; break;
            case 2: modeName = "LOOSE"; multiplier = 2.0; break;
         }
         Log(1, StringFormat("Single Trail Mode changed to: %d (%s, gap multiplier=%.1fx)", g_singleTrailMode, modeName, multiplier));
      }
      
      // Button 9: Total Trail Mode (show selection panel)
      if(sparam == "BtnTotalTrail") {
         if(g_activeSelectionPanel == "TotalTrail") {
            DestroySelectionPanel();
         } else {
            CreateSelectionPanel("TotalTrail");
         }
      }
      
      // Handle Total Trail selections
      if(StringFind(sparam, "SelectTTrail_") >= 0) {
         int selectedMode = (int)StringToInteger(StringSubstr(sparam, 13)); // Extract number from "SelectTTrail_X"
         g_totalTrailMode = selectedMode;
         DestroySelectionPanel();
         UpdateButtonStates();
         
         // Remove all single trail and group trail lines when switching to total trail
         RemoveAllSingleAndGroupTrailLines();
         
         string modeName = "";
         double multiplier = 1.0;
         switch(g_totalTrailMode) {
            case 0: modeName = "TIGHT"; multiplier = 0.5; break;
            case 1: modeName = "NORMAL"; multiplier = 1.0; break;
            case 2: modeName = "LOOSE"; multiplier = 2.0; break;
         }
         Log(1, StringFormat("Total Trail Mode changed to: %d (%s, gap multiplier=%.1fx)", g_totalTrailMode, modeName, multiplier));
      }
      
      // Button 10: Trail Method Strategy (show selection panel)
      if(sparam == "BtnTrailMethod") {
         if(g_activeSelectionPanel == "TrailMethod") {
            DestroySelectionPanel();
         } else {
            CreateSelectionPanel("TrailMethod");
         }
      }
      
      // Handle Trail Method selections (now for group trail method)
      if(StringFind(sparam, "SelectMethod_") >= 0) {
         int selectedMethod = (int)StringToInteger(StringSubstr(sparam, 13)); // Extract number from "SelectMethod_X"
         g_currentGroupTrailMethod = selectedMethod;
         DestroySelectionPanel();
         UpdateButtonStates();
         string methodName = "";
         switch(g_currentGroupTrailMethod) {
            case 0: methodName = "IGNORE (no group trail)"; break;
            case 1: methodName = "CLOSETOGETHER (group any-side)"; break;
            case 2: methodName = "CLOSETOGETHER_SAMETYPE (group same-side)"; break;
            case 3: methodName = "DYNAMIC (GLO-based switch)"; break;
            case 4: methodName = "DYNAMIC_SAMETYPE (GLO-based same-side)"; break;
            case 5: methodName = "DYNAMIC_ANYSIDE (GLO-based any-side)"; break;
            case 6: methodName = "HYBRID_BALANCED (net exposure based)"; break;
            case 7: methodName = "HYBRID_ADAPTIVE (GLO% + profit based)"; break;
            case 8: methodName = "HYBRID_SMART (multi-factor analysis)"; break;
            case 9: methodName = "HYBRID_COUNT_DIFF (order count difference based)"; break;
         }
         Log(1, StringFormat("Group Trail Method changed to: %d (%s)", g_currentGroupTrailMethod, methodName));
      }
      
      // Button 11: Toggle Order Labels
      if(sparam == "BtnOrderLabels") {
         g_showOrderLabels = !g_showOrderLabels;
         
         if(!g_showOrderLabels) {
            HideAllOrderLabels();
         } else {
            ShowAllOrderLabels();
         }
         
         UpdateButtonStates();
         Log(1, StringFormat("Order Labels Display: %s", g_showOrderLabels ? "ENABLED" : "DISABLED"));
      }
      
      // Button 12: Reset Counters (triple-click protection)
      if(sparam == "BtnResetCounters") {
         datetime currentTime = TimeCurrent();
         
         // Check if this is within 3 seconds of first click
         if(g_resetCountersClickTime > 0 && (currentTime - g_resetCountersClickTime) <= 3) {
            g_resetCountersClickCount++;
            
            if(g_resetCountersClickCount >= 3) {
               // Triple-click confirmed - reset all counters
               ResetAllCounters();
               g_resetCountersClickTime = 0;
               g_resetCountersClickCount = 0;
               Log(1, "Reset Counters: ALL COUNTERS RESET");
            } else {
               Log(1, StringFormat("Reset Counters: Click %d/3 - Click %d more time(s) within 3 seconds", 
                   g_resetCountersClickCount, 3 - g_resetCountersClickCount));
            }
         } else {
            // First click or timeout - restart counter
            g_resetCountersClickTime = currentTime;
            g_resetCountersClickCount = 1;
            Log(1, "Reset Counters: Click 1/3 - Click 2 more times within 3 seconds to reset");
         }
      }
   }
}

//============================= LABEL UPDATE FUNCTION ==============//
void UpdateOrCreateLabel(string name, int xDist, int yDist, string text, color textColor, int fontSize, string font) {
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
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
}

//============================= CURRENT PROFIT VLINE ==============//
void UpdateCurrentProfitVline() {
   // Get current stats
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity == 0) return;
   
   double cycleProfit = equity - g_lastCloseEquity;
   double openProfit = g_totalProfit;
   double bookedCycle = cycleProfit - openProfit;
   double overallProfit = equity - g_startingEquity;
   
   // Update vline only if we have positions and labels are shown
   if((g_buyCount + g_sellCount) > 0 && g_showLabels) {
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
         string vlinetext = StringFormat("P:%.2f/%.2f/%.2f/%.2f/%.2f(L%.2f)ML%.2f/%.2f L%.2f/%.2f N:%d/%.2f/%.2f", 
               cycleProfit, g_maxProfitCycle, trailStart, g_trailFloor, g_trailPeak, bookedCycle, -g_maxLossCycle, -g_overallMaxLoss, 
               g_maxLotsCycle, g_overallMaxLotSize, totalCount, g_netLots, totalLots);
         ObjectSetString(0, vlineName, OBJPROP_TEXT, vlinetext);
      }
   } else {
      // Remove vline if no positions
      ObjectDelete(0, "CurrentProfitVLine");
   }
   
   // All labels controlled by show labels button
   if(g_showLabels) {
      // Label 1: Current Profit Label
      if(g_showCurrentProfitLabel) {
         color lineColor = (cycleProfit > 1.0) ? clrGreen : (cycleProfit < -1.0) ? clrRed : clrYellow;
         string modeIndicator = "";
         if(g_noWork) modeIndicator = " [NO WORK]";
         else if(g_stopNewOrders) modeIndicator = " [MANAGE ONLY]";
         
         // Calculate trailing start threshold
         double lossStart = g_maxLossCycle * TrailStartPct;
         double profitStart = g_maxProfitCycle * TrailProfitPct;
         double trailStart = MathMax(lossStart, profitStart);
         
         string vlinetext = StringFormat("P:%.0f/%.0f/%.0f/%.0f/%.0f(E%.0f)ML%.0f/%.0f L%.2f/%.2f glo %d/%d%s", 
               cycleProfit, g_maxProfitCycle, trailStart, g_trailFloor, g_trailPeak, bookedCycle, -g_maxLossCycle, -g_overallMaxLoss, 
               g_maxLotsCycle, g_overallMaxLotSize, g_orders_in_loss, g_maxGLOOverall, modeIndicator);
         UpdateOrCreateLabel("CurrentProfitLabel", 10, 30, vlinetext, lineColor, 12, "Arial Bold");
      } else {
         ObjectDelete(0, "CurrentProfitLabel");
      }
      
      // Label 2: Position Details
      if(g_showPositionDetailsLabel) {
         int totalCount = g_buyCount + g_sellCount;
         double totalLots = g_buyLots + g_sellLots;
         string label2text = StringFormat("N:%d/%.2f/%.0f B:%d/%.2f/%.0f S:%d/%.2f/%.0f NB%.2f/NS%.2f",
               totalCount, g_netLots, totalLots,
               g_buyCount, g_buyLots, g_buyProfit,
               g_sellCount, g_sellLots, g_sellProfit,
               g_nextBuyLot, g_nextSellLot);
         color label2Color = (g_totalProfit >= 0) ? clrLime : clrOrange;
         UpdateOrCreateLabel("PositionDetailsLabel", 10, 55, label2text, label2Color, 10, "Arial Bold");
      } else {
         ObjectDelete(0, "PositionDetailsLabel");
      }
      
      // Label 3: Spread & Equity
      if(g_showSpreadEquityLabel) {
         double currentSpread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
         double inputGapPoints = GapInPoints;
         double effectiveGapPoints = g_adaptiveGap / _Point;
         string label3text = StringFormat("SPR:%.1f/%.1f |Gp:%.0f/%.0f |Eq:%.0f |PR:%.2f/%.2f", 
               currentSpread/_Point, g_maxSpread/_Point, inputGapPoints, effectiveGapPoints, equity,cycleProfit, overallProfit);
         color label3Color = (overallProfit >= 0) ? clrGreen : clrRed;
         UpdateOrCreateLabel("SpreadEquityLabel", 10, 80, label3text, label3Color, 10, "Arial Bold");
      } else {
         ObjectDelete(0, "SpreadEquityLabel");
      }
      
      // Label NEW: Next Lot Calculation Details
      if(g_showNextLotCalcLabel) {
         string scenarioNames[] = {"Bndry", "Dir", "Rev", "GPO>GLO", "GLO>GPO", "Cntrd", "Sided"};
         string buyScenarioName = (g_nextBuyScenario >= 0 && g_nextBuyScenario < 7) ? scenarioNames[g_nextBuyScenario] : "?";
         string sellScenarioName = (g_nextSellScenario >= 0 && g_nextSellScenario < 7) ? scenarioNames[g_nextSellScenario] : "?";
         
         // Format: "NextLot: B 0.05[Dir-Diff:S-loss>B-loss] S 0.03[Rev-GPO:S-loss>B-loss] | GLO:3 GPO:5"
         string nextLotText = StringFormat("NextLot: B %.2f[%s-%s:%s] S %.2f[%s-%s:%s] | GLO:%d GPO:%d",
               g_nextBuyLot, buyScenarioName, g_nextBuyMethod, g_nextBuyReason,
               g_nextSellLot, sellScenarioName, g_nextSellMethod, g_nextSellReason,
               g_orders_in_loss, g_orders_in_profit);
         color nextLotColor = clrLightSkyBlue;
         UpdateOrCreateLabel("NextLotCalcLabel", 10, 105, nextLotText, nextLotColor, 8, "Arial Bold");
      } else {
         ObjectDelete(0, "NextLotCalcLabel");
      }
      
      // Label 4: Single Trail Status
      if(g_showSingleTrailLabel) {
         string singleTrailStatus = GetSingleTrailStatusInfo();
         color singleTrailColor = clrCyan;
         if(StringFind(singleTrailStatus, "ACTIVE") >= 0) singleTrailColor = clrYellow;
         else if(StringFind(singleTrailStatus, "READY") >= 0 || StringFind(singleTrailStatus, "RDY") >= 0) singleTrailColor = clrLimeGreen;
         else if(StringFind(singleTrailStatus, "NOT-USED") >= 0 || StringFind(singleTrailStatus, "OFF") >= 0) singleTrailColor = clrGray;
         else if(StringFind(singleTrailStatus, "Disabled") >= 0) singleTrailColor = clrRed;
         else if(StringFind(singleTrailStatus, "Skipped") >= 0 || StringFind(singleTrailStatus, "Skip") >= 0) singleTrailColor = clrOrange;
         UpdateOrCreateLabel("SingleTrailStatusLabel", 10, 130, singleTrailStatus, singleTrailColor, 10, "Arial Bold");
      } else {
         ObjectDelete(0, "SingleTrailStatusLabel");
      }
      
      // Label 5: Group Trail Status
      if(g_showGroupTrailLabel) {
         string groupTrailStatus = GetGroupTrailStatusInfo();
         color groupTrailColor = clrCyan;
         if(StringFind(groupTrailStatus, "ACTIVE") >= 0 || StringFind(groupTrailStatus, "ON") >= 0) groupTrailColor = clrOrange;
         else if(StringFind(groupTrailStatus, "READY") >= 0 || StringFind(groupTrailStatus, "RDY") >= 0) groupTrailColor = clrLimeGreen;
         else if(StringFind(groupTrailStatus, "NOT-USED") >= 0 || StringFind(groupTrailStatus, "OFF") >= 0) groupTrailColor = clrGray;
         else if(StringFind(groupTrailStatus, "Disabled") >= 0) groupTrailColor = clrRed;
         else if(StringFind(groupTrailStatus, "Skipped") >= 0 || StringFind(groupTrailStatus, "Skip") >= 0) groupTrailColor = clrOrange;
         UpdateOrCreateLabel("GroupTrailStatusLabel", 10, 155, groupTrailStatus, groupTrailColor, 10, "Arial Bold");
      } else {
         ObjectDelete(0, "GroupTrailStatusLabel");
      }
      
      // Label 6: Total Trail Status
      if(g_showTotalTrailLabel) {
         string totalTrailStatus = GetTotalTrailStatusInfo();
         color totalTrailColor = clrCyan;
         if(StringFind(totalTrailStatus, "ACTIVE") >= 0 || StringFind(totalTrailStatus, "ON") >= 0) totalTrailColor = clrBlue;
         else if(StringFind(totalTrailStatus, "READY") >= 0 || StringFind(totalTrailStatus, "RDY") >= 0) totalTrailColor = clrLimeGreen;
         else if(StringFind(totalTrailStatus, "WAIT") >= 0) totalTrailColor = clrGray;
         else if(StringFind(totalTrailStatus, "BLOCKED") >= 0 || StringFind(totalTrailStatus, "BLOCK") >= 0) totalTrailColor = clrRed;
         else if(StringFind(totalTrailStatus, "Disabled") >= 0) totalTrailColor = clrRed;
         UpdateOrCreateLabel("TotalTrailStatusLabel", 10, 205, totalTrailStatus, totalTrailColor, 10, "Arial Bold");
      } else {
         ObjectDelete(0, "TotalTrailStatusLabel");
      }
      
      // Calculate current level (used by multiple labels below)
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      int currentLevel = PriceLevelIndex(currentPrice, g_adaptiveGap);
      
      // Label 7: Current Level Info
      if(g_showLevelInfoLabel) {
         // Find nearest BUY order (even level closest to current level)
         int nearestBuyLevel = -999999;
      double nearestBuyLot = 0.0;
      ulong nearestBuyTicket = 0;
      int minBuyDistance = 999999;
      for(int i = 0; i < g_orderCount; i++) {
         if(g_orders[i].isValid && g_orders[i].type == POSITION_TYPE_BUY) {
            int distance = MathAbs(g_orders[i].level - currentLevel);
            if(distance < minBuyDistance) {
               minBuyDistance = distance;
               nearestBuyLevel = g_orders[i].level;
               nearestBuyLot = g_orders[i].lotSize;
               nearestBuyTicket = g_orders[i].ticket;
            }
         }
      }
      
      // Find nearest SELL order (odd level closest to current level)
      int nearestSellLevel = -999999;
      double nearestSellLot = 0.0;
      ulong nearestSellTicket = 0;
      int minSellDistance = 999999;
      for(int i = 0; i < g_orderCount; i++) {
         if(g_orders[i].isValid && g_orders[i].type == POSITION_TYPE_SELL) {
            int distance = MathAbs(g_orders[i].level - currentLevel);
            if(distance < minSellDistance) {
               minSellDistance = distance;
               nearestSellLevel = g_orders[i].level;
               nearestSellLot = g_orders[i].lotSize;
               nearestSellTicket = g_orders[i].ticket;
            }
         }
      }
      
      // Get comments from server positions
      string buyComment = "";
      string sellComment = "";
      
      if(nearestBuyTicket > 0) {
         if(PositionSelectByTicket(nearestBuyTicket)) {
            buyComment = PositionGetString(POSITION_COMMENT);
         }
      }
      
      if(nearestSellTicket > 0) {
         if(PositionSelectByTicket(nearestSellTicket)) {
            sellComment = PositionGetString(POSITION_COMMENT);
         }
      }
      
      string buyInfo = (nearestBuyLevel != -999999) ? StringFormat("%dB%.2f[%s]", nearestBuyLevel, nearestBuyLot, buyComment) : "-";
      string sellInfo = (nearestSellLevel != -999999) ? StringFormat("%dS%.2f[%s]", nearestSellLevel, nearestSellLot, sellComment) : "-";
         string label4text = StringFormat("Lvl: C%d %s %s", currentLevel, buyInfo, sellInfo);
         color label4Color = clrWhite;
         UpdateOrCreateLabel("LevelInfoLabel", 10, 230, label4text, label4Color, 10, "Arial Bold");
      } else {
         ObjectDelete(0, "LevelInfoLabel");
      }
      
      // Label 8: Nearby Orders
      if(g_showNearbyOrdersLabel) {
         string nearbyText = GetNearbyOrdersText(currentLevel, 5); // 5 up, 5 down = 10 total
         string label5text = StringFormat("Orders: %s", nearbyText);
         color label5Color = clrCyan;
         UpdateOrCreateLabel("NearbyOrdersLabel", 10, 255, label5text, label5Color, 10, "Arial Bold");
      } else {
         ObjectDelete(0, "NearbyOrdersLabel");
      }
      
      // Label 9: Last 5 Closes
      if(g_showLast5ClosesLabel) {
         string label6text = "Last5 Closes: ";
         for(int i = 0; i < 5; i++) {
            if(i < g_closeCount) {
               label6text += StringFormat("%.2f", g_last5Closes[i]);
            } else {
               label6text += "-";
            }
            if(i < 4) label6text += " | ";
         }
         UpdateOrCreateLabel("Last5ClosesLabel", 10, 280, label6text, clrYellow, 9, "Arial");
      } else {
         ObjectDelete(0, "Last5ClosesLabel");
      }
      
      // Label 10: History Display (based on mode)
      if(g_showHistoryDisplayLabel) {
         string historyLabel = "";
         color historyColor = clrYellow;
      
      if(g_historyDisplayMode == 0) {
         // Overall (All Symbols/All Magic)
         historyLabel = "Last5D Overall: ";
         for(int i = 0; i < 5; i++) {
            historyLabel += StringFormat("%.0f", g_historyOverallDaily[i]);
            if(i < 4) historyLabel += " | ";
         }
         historyColor = clrLightGreen;
      }
      else if(g_historyDisplayMode == 1) {
         // Current Symbol (All Magic)
         historyLabel = StringFormat("Last5D %s(AllMag): ", _Symbol);
         for(int i = 0; i < 5; i++) {
            historyLabel += StringFormat("%.0f", g_historySymbolDaily[i]);
            if(i < 4) historyLabel += " | ";
         }
         historyColor = clrCyan;
      }
      else if(g_historyDisplayMode == 2) {
         // Current Symbol (Current Magic) - for now show same as mode 1
         historyLabel = StringFormat("Last5D %s(M%d): ", _Symbol, Magic);
         for(int i = 0; i < 5; i++) {
            historyLabel += StringFormat("%.0f", g_historySymbolDaily[i]);
            if(i < 4) historyLabel += " | ";
         }
         historyColor = clrOrange;
      }
      else if(g_historyDisplayMode == 3) {
         // Per-Symbol Breakdown (show first symbol or summary)
         if(ArraySize(g_symbolHistory) > 0) {
            historyLabel = "Last5D: ";
            for(int s = 0; s < MathMin(2, ArraySize(g_symbolHistory)); s++) {
               if(s > 0) historyLabel += " ";
               historyLabel += StringFormat("%s:%.0f", g_symbolHistory[s].symbol, g_symbolHistory[s].daily[0]);
            }
            if(ArraySize(g_symbolHistory) > 2) {
               historyLabel += StringFormat(" +%d more", ArraySize(g_symbolHistory) - 2);
            }
         } else {
            historyLabel = "Last5D: No data";
         }
         historyColor = clrViolet;
      }
      
      UpdateOrCreateLabel("HistoryDisplayLabel", 10, 303, historyLabel, historyColor, 9, "Arial Bold");
      } else {
         ObjectDelete(0, "HistoryDisplayLabel");
      }
   } else {
      // Delete all labels when show labels is OFF
      ObjectDelete(0, "CurrentProfitLabel");
      ObjectDelete(0, "PositionDetailsLabel");
      ObjectDelete(0, "SpreadEquityLabel");
      ObjectDelete(0, "NextLotCalcLabel");
      ObjectDelete(0, "SingleTrailStatusLabel");
      ObjectDelete(0, "GroupTrailStatusLabel");
      ObjectDelete(0, "TotalTrailStatusLabel");
      ObjectDelete(0, "LevelInfoLabel");
      ObjectDelete(0, "NearbyOrdersLabel");
      ObjectDelete(0, "Last5ClosesLabel");
      ObjectDelete(0, "HistoryDisplayLabel");
   }
   
   // Center Panel Labels - controlled by show labels button
   if(g_showLabels) {
      // Calculate center positions
      long chartWidth = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
      long chartHeight = ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
      int centerX = (int)(chartWidth / 2);
      int centerY = (int)(chartHeight / 2);
      
      // Line 1: Cycle Profit (centered)
      if(g_showCenterCycleLabel) {
         // Calculate trail start for display
         double lossStart = g_maxLossCycle * TrailStartPct;
         double profitStart = g_maxProfitCycle * TrailProfitPct;
         double trailStart = MathMax(lossStart, profitStart);
         
         // Format: P{cycleProfit}/{trailStart}/{floorPrice}
         string cycleText;
         if(g_trailActive) {
            cycleText = StringFormat("P%.0f/%.0f/%.0f", cycleProfit, trailStart, g_trailFloor);
         } else {
            cycleText = StringFormat("P%.0f/%.0f", cycleProfit, trailStart);
         }
         color cycleColor = (cycleProfit >= 0) ? clrLime : clrRed;
         
         string centerName = "CenterCycleLabel";
         if(ObjectFind(0, centerName) < 0) {
            ObjectCreate(0, centerName, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(0, centerName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, centerName, OBJPROP_ANCHOR, ANCHOR_CENTER);
            ObjectSetInteger(0, centerName, OBJPROP_XDISTANCE, centerX);
            ObjectSetInteger(0, centerName, OBJPROP_YDISTANCE, centerY);
            ObjectSetInteger(0, centerName, OBJPROP_FONTSIZE, CenterPanelFontSize);
            ObjectSetString(0, centerName, OBJPROP_FONT, "Arial Bold");
            ObjectSetInteger(0, centerName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, centerName, OBJPROP_HIDDEN, false);
            ObjectSetInteger(0, centerName, OBJPROP_BACK, false);
            ObjectSetInteger(0, centerName, OBJPROP_ZORDER, 0);
         } else {
            ObjectSetInteger(0, centerName, OBJPROP_XDISTANCE, centerX);
            ObjectSetInteger(0, centerName, OBJPROP_YDISTANCE, centerY);
            ObjectSetInteger(0, centerName, OBJPROP_FONTSIZE, CenterPanelFontSize);
         }
         
         ObjectSetString(0, centerName, OBJPROP_TEXT, cycleText);
         ObjectSetInteger(0, centerName, OBJPROP_COLOR, cycleColor);
      } else {
         ObjectDelete(0, "CenterCycleLabel");
      }
      
      // Line 2: Total Overall Profit (centered)
      int centerY2 = centerY + (int)(CenterPanelFontSize * 1.25);
      
      if(g_showCenterProfitLabel) {
         string centerText = StringFormat("T%.0f/%.0f", overallProfit, equity);
         color centerColor = (overallProfit >= 0) ? clrLime : clrRed;
         
         string centerName = "CenterProfitLabel";
         if(ObjectFind(0, centerName) < 0) {
            ObjectCreate(0, centerName, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(0, centerName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, centerName, OBJPROP_ANCHOR, ANCHOR_CENTER);
            ObjectSetInteger(0, centerName, OBJPROP_XDISTANCE, centerX);
            ObjectSetInteger(0, centerName, OBJPROP_YDISTANCE, centerY2);
            ObjectSetInteger(0, centerName, OBJPROP_FONTSIZE, CenterPanel2FontSize);
            ObjectSetString(0, centerName, OBJPROP_FONT, "Arial Bold");
            ObjectSetInteger(0, centerName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, centerName, OBJPROP_HIDDEN, false);
            ObjectSetInteger(0, centerName, OBJPROP_BACK, false);
            ObjectSetInteger(0, centerName, OBJPROP_ZORDER, 0);
         } else {
            ObjectSetInteger(0, centerName, OBJPROP_XDISTANCE, centerX);
            ObjectSetInteger(0, centerName, OBJPROP_YDISTANCE, centerY2);
            ObjectSetInteger(0, centerName, OBJPROP_FONTSIZE, CenterPanel2FontSize);
         }
         
         ObjectSetString(0, centerName, OBJPROP_TEXT, centerText);
         ObjectSetInteger(0, centerName, OBJPROP_COLOR, centerColor);
      } else {
         ObjectDelete(0, "CenterProfitLabel");
      }
      
      // Line 3: Booked Profit + Open Profit (centered)
      int centerY3 = centerY2 + (int)(CenterPanel2FontSize * 1.25);
      
      if(g_showCenterBookedLabel) {
         string centerName2Booked = "CenterBookedLabel";
         string bookedText = StringFormat("E%.0f %.0f", bookedCycle, openProfit);
         color bookedColor = (bookedCycle >= 0) ? clrLime : clrRed;
         
         // Create/update booked profit label (centered)
         if(ObjectFind(0, centerName2Booked) < 0) {
            ObjectCreate(0, centerName2Booked, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(0, centerName2Booked, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, centerName2Booked, OBJPROP_ANCHOR, ANCHOR_CENTER);
            ObjectSetInteger(0, centerName2Booked, OBJPROP_FONTSIZE, CenterPanel2FontSize);
            ObjectSetString(0, centerName2Booked, OBJPROP_FONT, "Arial Bold");
            ObjectSetInteger(0, centerName2Booked, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, centerName2Booked, OBJPROP_HIDDEN, false);
            ObjectSetInteger(0, centerName2Booked, OBJPROP_BACK, false);
            ObjectSetInteger(0, centerName2Booked, OBJPROP_ZORDER, 0);
         }
         ObjectSetInteger(0, centerName2Booked, OBJPROP_XDISTANCE, centerX);
         ObjectSetInteger(0, centerName2Booked, OBJPROP_YDISTANCE, centerY3);
         ObjectSetInteger(0, centerName2Booked, OBJPROP_FONTSIZE, CenterPanel2FontSize);
         ObjectSetString(0, centerName2Booked, OBJPROP_TEXT, bookedText);
         ObjectSetInteger(0, centerName2Booked, OBJPROP_COLOR, bookedColor);
      } else {
         ObjectDelete(0, "CenterBookedLabel");
      }
      
      // Line 4: Net Lots / Order Count Difference / GLO / GPO (centered)
      int centerY4 = centerY3 + (int)(CenterPanel2FontSize * 1.25);
      
      if(g_showCenterNetLotsLabel) {
         string centerName3 = "CenterNetLotsLabel";
         
         // Determine which side has more orders and by how much
         int orderCountDiff = MathAbs(g_buyCount - g_sellCount);
         string orderDiffStr = "";
         if(g_sellCount > g_buyCount) {
            orderDiffStr = StringFormat("S%d", orderCountDiff);
         } else if(g_buyCount > g_sellCount) {
            orderDiffStr = StringFormat("B%d", orderCountDiff);
         } else {
            orderDiffStr = "E0"; // Equal
         }
         
         string netLotsText = StringFormat("N%.2f/%s/%d/%d", g_netLots, orderDiffStr, g_orders_in_loss, g_orders_in_profit);
         color netLotsColor = clrWhite;
         
         // Create/update net lots label (centered)
         if(ObjectFind(0, centerName3) < 0) {
            ObjectCreate(0, centerName3, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(0, centerName3, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, centerName3, OBJPROP_ANCHOR, ANCHOR_CENTER);
            ObjectSetInteger(0, centerName3, OBJPROP_FONTSIZE, CenterPanel2FontSize);
            ObjectSetString(0, centerName3, OBJPROP_FONT, "Arial Bold");
            ObjectSetInteger(0, centerName3, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, centerName3, OBJPROP_HIDDEN, false);
            ObjectSetInteger(0, centerName3, OBJPROP_BACK, false);
            ObjectSetInteger(0, centerName3, OBJPROP_ZORDER, 0);
         }
         ObjectSetInteger(0, centerName3, OBJPROP_XDISTANCE, centerX);
         ObjectSetInteger(0, centerName3, OBJPROP_YDISTANCE, centerY4);
         ObjectSetInteger(0, centerName3, OBJPROP_FONTSIZE, CenterPanel2FontSize);
         ObjectSetString(0, centerName3, OBJPROP_TEXT, netLotsText);
         ObjectSetInteger(0, centerName3, OBJPROP_COLOR, netLotsColor);
      } else {
         ObjectDelete(0, "CenterNetLotsLabel");
      }
   } else {
      // Delete center panel labels when hidden
      ObjectDelete(0, "CenterProfitLabel");
      ObjectDelete(0, "CenterCycleLabel");
      ObjectDelete(0, "CenterBookedLabel");
      ObjectDelete(0, "CenterNetLotsLabel");
   }
   
   ChartRedraw(0);
}
