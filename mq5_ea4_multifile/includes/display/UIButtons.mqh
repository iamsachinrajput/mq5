//+------------------------------------------------------------------+
//| UIButtons.mqh                                                    |
//| Button creation and state management                             |
//+------------------------------------------------------------------+


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
