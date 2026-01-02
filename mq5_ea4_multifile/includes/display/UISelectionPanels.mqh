//+------------------------------------------------------------------+
//| UISelectionPanels.mqh                                            |
//| Selection panel creation and destruction                         |
//+------------------------------------------------------------------+


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
      // 3 buttons: Next Lines (next buy/sell indicators), Level Lines (grid levels), Order Labels (text labels)
      string lineTexts[] = {"Next Lines", "Level Lines", "Order Labels"};
      bool lineStates[] = {g_showNextLevelLines, g_showLevelLines, g_showOrderLabelsCtrl};
      int lineCount = 3;

      // Calculate panel height and align background with buttons
      int panelYOffset = yOffset;
      int panelHeight = lineCount * (buttonHeight + 5) + 20;
      ObjectSetInteger(0, bgName, OBJPROP_YSIZE, panelHeight);
      ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, topMargin + panelYOffset);

      // No ALL button for this simplified panel - direct control only

      int btnYOffset = panelYOffset + 10;
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
