//+------------------------------------------------------------------+
//| OrderExecution.mqh                                               |
//| Order execution with lot splitting                               |
//+------------------------------------------------------------------+

//============================= ORDER EXECUTION WITH LOT SPLITTING ==//
bool ExecuteOrder(int orderType, double lotSize, string comment = "") {
   if(lotSize <= 0) {
      Log(1, "ExecuteOrder: Invalid lot size");
      return false;
   }
   
   // Extract level from comment if available (format: "E...BP...B14" or "E...BP...S-15")
   int orderLevel = 0;
   if(StringLen(comment) > 0) {
      int pos = StringFind(comment, orderType == POSITION_TYPE_BUY ? "B" : "S", 0);
      if(pos >= 0 && pos < StringLen(comment) - 1) {
         string levelStr = StringSubstr(comment, pos + 1);
         orderLevel = (int)StringToInteger(levelStr);
      }
   }
   
   double maxLotPerOrder = 20.0;
   int ordersNeeded = (int)MathCeil(lotSize / maxLotPerOrder);
   
   if(ordersNeeded == 1) {
      // Single order - execute directly
      trade.SetExpertMagicNumber(Magic);
      bool result = false;
      if(orderType == POSITION_TYPE_BUY) {
         result = trade.Buy(lotSize, _Symbol, 0, 0, 0, comment);
      } else {
         result = trade.Sell(lotSize, _Symbol, 0, 0, 0, comment);
      }
      
      // Record successful order placement
      if(result && orderLevel != 0) {
         ulong ticket = trade.ResultOrder();
         if(ticket == 0) ticket = trade.ResultDeal();
         
         string typeStr = (orderType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
         datetime currentTime = TimeCurrent();
         
         // Get actual execution price from position
         double price = 0.0;
         datetime openTime = currentTime;
         if(PositionSelectByTicket(ticket)) {
            price = PositionGetDouble(POSITION_PRICE_OPEN);
            openTime = (datetime)PositionGetInteger(POSITION_TIME);
         } else {
            // Fallback to current market price if position not found
            price = (orderType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
         }
         
         // Add to tracking array
         AddOrderToTracking(ticket, orderType, orderLevel, price, lotSize);
         
         // Create open order label with actual execution price
         CreateOpenOrderLabel(ticket, orderLevel, orderType, lotSize, price, openTime);
         
         Log(2, StringFormat("[ORDER-RECORDED] %s L%d @ %s | Lot=%.2f Ticket=%d Price=%.5f", 
             typeStr, orderLevel, TimeToString(currentTime, TIME_SECONDS), lotSize, ticket, price));
         
         // Log trade action
         string reason = (orderType == POSITION_TYPE_BUY) ? g_nextBuyReason : g_nextSellReason;
         LogOrderOpen(ticket, orderType, lotSize, orderLevel, reason);
      }
      
      // Apply delay if configured
      if(result && OrderPlacementDelayMs > 0) {
         Sleep(OrderPlacementDelayMs);
      }
      
      return result;
   }
   
   // Multiple orders needed - split the lot size
   double remainingLots = lotSize;
   int successCount = 0;
   bool firstOrderPlaced = false;
   
   Log(2, StringFormat("ExecuteOrder: Splitting %.2f lots into %d orders (max %.2f per order)",
       lotSize, ordersNeeded, maxLotPerOrder));
   
   for(int i = 0; i < ordersNeeded; i++) {
      double currentLot = MathMin(remainingLots, maxLotPerOrder);
      
      // Normalize to broker requirements
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      
      currentLot = MathMax(currentLot, minLot);
      currentLot = MathRound(currentLot / stepLot) * stepLot;
      currentLot = MathMin(currentLot, maxLot);
      
      string orderComment = comment;
      if(ordersNeeded > 1) {
         orderComment = StringFormat("%s [%d/%d]", comment, i + 1, ordersNeeded);
      }
      
      trade.SetExpertMagicNumber(Magic);
      bool result = false;
      
      if(orderType == POSITION_TYPE_BUY) {
         result = trade.Buy(currentLot, _Symbol, 0, 0, 0, orderComment);
      } else {
         result = trade.Sell(currentLot, _Symbol, 0, 0, 0, orderComment);
      }
      
      if(result) {
         ulong ticket = trade.ResultOrder();
         if(ticket == 0) ticket = trade.ResultDeal();
         
         successCount++;
         remainingLots -= currentLot;
         Log(2, StringFormat("ExecuteOrder: Order %d/%d placed: %.2f lots (%.2f remaining)",
             i + 1, ordersNeeded, currentLot, remainingLots));
         
         // Add to tracking array
         if(orderLevel != 0) {
            // Get actual execution price from position
            double price = 0.0;
            datetime openTime = TimeCurrent();
            if(PositionSelectByTicket(ticket)) {
               price = PositionGetDouble(POSITION_PRICE_OPEN);
               openTime = (datetime)PositionGetInteger(POSITION_TIME);
            } else {
               // Fallback to current market price if position not found
               price = (orderType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
            }
            
            AddOrderToTracking(ticket, orderType, orderLevel, price, currentLot);
            
            // Create open order label for each split order with actual execution price
            CreateOpenOrderLabel(ticket, orderLevel, orderType, currentLot, price, openTime);
            
            if(!firstOrderPlaced) {
               string typeStr = (orderType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
               Log(2, StringFormat("[ORDER-RECORDED-SPLIT] %s L%d Ticket=%d | Lot=%.2f (split %d/%d)", 
                   typeStr, orderLevel, ticket, currentLot, i+1, ordersNeeded));
               firstOrderPlaced = true;
               
               // Log trade action for the first split order
               string reason = (orderType == POSITION_TYPE_BUY) ? g_nextBuyReason : g_nextSellReason;
               LogOrderOpen(ticket, orderType, lotSize, orderLevel, reason);
            }
         }
         
         // Apply delay between split orders if configured
         if(OrderPlacementDelayMs > 0) {
            Sleep(OrderPlacementDelayMs);
         }
      } else {
         Log(1, StringFormat("ExecuteOrder: Failed to place order %d/%d: %.2f lots",
             i + 1, ordersNeeded, currentLot));
      }
   }
   
   bool allSuccess = (successCount == ordersNeeded);
   if(!allSuccess) {
      Log(1, StringFormat("ExecuteOrder: Partial fill - %d/%d orders succeeded",
          successCount, ordersNeeded));
   }
   
   return allSuccess;
}
