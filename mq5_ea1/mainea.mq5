
#property strict
#include <Trade/Trade.mqh>
CTrade trade;

#include "TradeFunctions.mqh"
#include "Utils.mqh"
#include "DisplayFunctions.mqh"
#include "RiskManagement.mqh"
//#include "CloseFunctions.mqh"
#include "TakeSingleProfit.mqh"
#include "CloseAllOrdersOfType.mqh"
#include "TrailTotalProfit.mqh"

// Inputs
input double GapInPoints = 100.0;
input double LotSize = 0.01;
input int DebugLevel = 2;
input bool EnableDisplay = true;
input int RoundToNearest = 1;

// Risk Inputs
input int MaxPositions = 1000;
input double MaxTotalLots = 500.0;
input double MaxLoss = 5000.0;
input double DailyProfitTarget = 5000.0;

// Performance
input bool EnablePerformance = false;

int OnInit()
{
   fnc_Print(DebugLevel, 1, StringFormat("EA Initialized (DebugLevel=%d)", DebugLevel));
   return(INIT_SUCCEEDED);
}

void OnTick()
{
   ulong startTime = GetMicrosecondCount();

   fnc_GetInfoFromOrdersTraversal();
   fnc_UpdateRiskStatus();
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   fnc_CheckAndPlaceOrders(currentPrice, GapInPoints, DebugLevel);
   //fnc_CloseOrdersIndividually();
   fnc_TrailTotalProfit();
   
   fnc_CloseOrdersBySingleProfit();

   fnc_UpdateChartLabel(EnableDisplay, EnablePerformance);

   //fnc_MeasurePerformance(EnablePerformance, startTime);
}

void OnDeinit(const int reason)
{
   ObjectDelete(0, "EA_Status");
   ObjectDelete(0, "EA_NextLots");
   ObjectDelete(0, "EA_Orders");
   ObjectDelete(0, "EA_Risk");
   ObjectDelete(0, "EA_Perf");
}
