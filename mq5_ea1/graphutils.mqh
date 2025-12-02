//+------------------------------------------------------------------+
//| graphutils.mqh                                                   |
//| Helper functions to draw chart objects (vertical line + text)   |
//+------------------------------------------------------------------+
#property strict

// Draw a vertical line at `atTime` and attach a text label with `text`.
// Returns true on success.
bool fnc_DrawProfitCloseLine(datetime atTime, const string name, const string text, color clr)
{
   if(atTime <= 0) atTime = TimeCurrent();

   string lineName = name;
   // Ensure uniqueness if object exists
   if(ObjectFind(0, lineName) != -1)
      lineName = name + "_" + IntegerToString((int)atTime);

   // Create vertical line
   bool created = ObjectCreate(0, lineName, OBJ_VLINE, 0, atTime);
   if(!created)
      return false;
   ObjectSetInteger(0, lineName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID);

   // Create a text object to show details near the current Ask price
   string txtName = lineName + "_txt";
   double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(price <= 0) price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(price <= 0) price = 0.0;

   bool tcreated = ObjectCreate(0, txtName, OBJ_TEXT, 0, atTime, price);
   if(tcreated)
   {
      ObjectSetString(0, txtName, OBJPROP_TEXT, text);
      ObjectSetInteger(0, txtName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, txtName, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, txtName, OBJPROP_XDISTANCE, 2);
      ObjectSetInteger(0, txtName, OBJPROP_YDISTANCE, 2);
   }

   return true;
}
