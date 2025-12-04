
#property strict
#include <Trade/Trade.mqh>
CTrade trade;

#include "TradeFunctions.mqh"
#include "TradeFunctions2.mqh"
#include "Utils.mqh"
#include "DisplayFunctions.mqh"
#include "RiskManagement.mqh"
//#include "CloseFunctions.mqh"
#include "TakeSingleProfit.mqh"
#include "CloseAllOrdersOfType.mqh"
#include "TrailTotalProfit.mqh"

// Inputs
input int Magic = 12345; // Global Magic number for all trades
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
input double MaxSingleLotSize = 20.0; // Max lot size per single order

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

   //fnc_CheckAndPlaceOrders(currentPrice, GapInPoints, DebugLevel);
   fnc_PlaceLevelOrders2(currentPrice, DebugLevel);
   //fnc_CloseOrdersIndividually();
   fnc_TrailTotalProfit();
   
   //fnc_CloseOrdersBySingleProfit();
   fnc_TrailAndCloseSingleByProfit();

   fnc_UpdateChartLabel(EnableDisplay, EnablePerformance);

   //fnc_MeasurePerformance(EnablePerformance, startTime);
}

void OnDeinit(const int reason)
{
   // Print comprehensive summary before cleanup
   fnc_PrintDeinitSummary(reason);
   
   // Cleanup chart objects
   ObjectDelete(0, "EA_Status");
   ObjectDelete(0, "EA_NextLots");
   ObjectDelete(0, "EA_Orders");
   ObjectDelete(0, "EA_Risk");
   ObjectDelete(0, "EA_Perf");
   ObjectDelete(0, "EA_Panel");
}
