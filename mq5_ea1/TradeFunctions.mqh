
#property strict
#include <Trade/Trade.mqh>
#include "Utils.mqh"
#include "RiskManagement.mqh"

input int Magic = 12345; // Global Magic number for all trades

void fnc_CheckAndPlaceOrders(double currentPrice, double gapPx, int debugLevel)
{
   if(!g_TradingAllowed)
   {
      fnc_Print(debugLevel, 1, "Trading stopped due to risk limits");
      return;
   }

   if(g_originPrice == 0)
      g_originPrice = currentPrice;

   double sprPx = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   double nowAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double nowBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   static double prevAsk = nowAsk;
   static double prevBid = nowBid;

   fnc_Print(debugLevel, 2, StringFormat("PrevAsk: %.5f NowAsk: %.5f | PrevBid: %.5f NowBid: %.5f", prevAsk, nowAsk, prevBid, nowBid));

   // BUY logic
   if(nowAsk > prevAsk)
   {
      int Llo = fnc_PriceLevelIndex(MathMin(prevAsk, nowAsk) - sprPx, gapPx) - 2;
      int Lhi = fnc_PriceLevelIndex(MathMax(prevAsk, nowAsk) - sprPx, gapPx) + 2;

      for(int L = Llo; L <= Lhi; L++)
      {
         if(!IsEven(L)) continue;
         double trig = fnc_LevelPrice(L, gapPx) + sprPx;
         if(prevAsk <= trig && nowAsk > trig)
         {
            fnc_Print(debugLevel, 1, StringFormat("[BUY Check] Level:%d Price:%.5f Trigger:%.5f", L, fnc_LevelPrice(L, gapPx), trig));

            if(fnc_HasSameTypeOnLevel(POSITION_TYPE_BUY, L, gapPx))
            {
               fnc_Print(debugLevel, 1, StringFormat("Skipped BUY at Level:%d (duplicate on same level)", L));
               continue;
            }
            if(fnc_HasSameTypeNearLevel(POSITION_TYPE_BUY, L, gapPx, 1))
            {
               fnc_Print(debugLevel, 1, StringFormat("Skipped BUY at Level:%d (duplicate near level)", L));
               continue;
            }

            fnc_OpenBuy(fnc_LevelPrice(L, gapPx), g_NextBuyLotSize);
            fnc_Print(debugLevel, 1, StringFormat("BUY placed at Level:%d Price:%.5f", L, fnc_LevelPrice(L, gapPx)));
         }
      }
   }

   // SELL logic
   if(nowBid < prevBid)
   {
      int Llo = fnc_PriceLevelIndex(MathMin(prevBid, nowBid) + sprPx, gapPx) - 2;
      int Lhi = fnc_PriceLevelIndex(MathMax(prevBid, nowBid) + sprPx, gapPx) + 2;

      for(int L = Lhi; L >= Llo; L--)
      {
         if(!IsOdd(L)) continue;
         double trig = fnc_LevelPrice(L, gapPx) - sprPx;
         if(prevBid >= trig && nowBid < trig)
         {
            fnc_Print(debugLevel, 1, StringFormat("[SELL Check] Level:%d Price:%.5f Trigger:%.5f", L, fnc_LevelPrice(L, gapPx), trig));

            if(fnc_HasSameTypeOnLevel(POSITION_TYPE_SELL, L, gapPx))
            {
               fnc_Print(debugLevel, 1, StringFormat("Skipped SELL at Level:%d (duplicate on same level)", L));
               continue;
            }
            if(fnc_HasSameTypeNearLevel(POSITION_TYPE_SELL, L, gapPx, 1))
            {
               fnc_Print(debugLevel, 1, StringFormat("Skipped SELL at Level:%d (duplicate near level)", L));
               continue;
            }

            fnc_OpenSell(fnc_LevelPrice(L, gapPx), g_NextSellLotSize);
            fnc_Print(debugLevel, 1, StringFormat("SELL placed at Level:%d Price:%.5f", L, fnc_LevelPrice(L, gapPx)));
         }
      }
   }

   prevAsk = nowAsk;
   prevBid = nowBid;
}

void fnc_OpenBuy(double price, double lot)
{
   trade.SetExpertMagicNumber(Magic);
   trade.Buy(lot, _Symbol);
}

void fnc_OpenSell(double price, double lot)
{
   trade.SetExpertMagicNumber(Magic);
   trade.Sell(lot, _Symbol);
}
