//+------------------------------------------------------------------+
//|                                            BB 2Bands Project.mq4 |
//|                                                         Valantis |
//|                                             https://www.test.com |
//+------------------------------------------------------------------+
#property copyright "Valantis"
#property link      "https://www.Test.com"
#property version   "1.00"
#property strict
#property show_inputs
#include  <CustomFunctions01.mqh>

int magicNB = 11111;
input int bbPeriod = 50;
input int bandStdEntry = 2; // If you change the 2, change int to double.
input int bandStdProfitExit = 1; // Exit 
input int bandStdLossExit = 6; // Exit
int rsiPeriod = 14;
input double riskPerTrade = 0.02;
input int rsiLowerLevel = 40;
input int rsiUpperLevel = 60;

int openOrderID;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   Alert("");
   Alert("Starting Strategy BB 2Bands Project");
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Alert("Stopping Strategy BB 2Bands Project");
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   double stopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;  // Minimum stop level for the symbol   *

   // Entry
   double bbLowerEntry = iBands(NULL,0,bbPeriod,bandStdEntry,0,PRICE_CLOSE,MODE_LOWER,0);
   double bbUpperEntry = iBands(NULL,0,bbPeriod,bandStdEntry,0,PRICE_CLOSE,MODE_UPPER,0);
   double bbMid = iBands(NULL,0,bbPeriod,bandStdEntry,0,PRICE_CLOSE,0,0);

   // Exit With Profit
   double bbLowerProfitExit = iBands(NULL,0,bbPeriod,bandStdProfitExit,0,PRICE_CLOSE,MODE_LOWER,0);
   double bbUpperProfitExit = iBands(NULL,0,bbPeriod,bandStdProfitExit,0,PRICE_CLOSE,MODE_UPPER,0);

   // Exit Stop Loss
   double bbLowerLossExit = iBands(NULL,0,bbPeriod,bandStdLossExit,0,PRICE_CLOSE,MODE_LOWER,0);
   double bbUpperLossExit = iBands(NULL,0,bbPeriod,bandStdLossExit,0,PRICE_CLOSE,MODE_UPPER,0);

   double rsiValue = iRSI(NULL,0,rsiPeriod,PRICE_CLOSE,0);

   if(!CheckIfOpenOrdersByMagicNB(magicNB)) // If no open orders, try to enter new position
   {
      if(Ask < bbLowerEntry && Open[0] > bbLowerEntry && rsiValue < rsiLowerLevel) // Buying
      {
         Print("Price is below bbLower and rsiValue is lower than " + DoubleToStr(rsiLowerLevel) + " , Sending buy order");
         double stopLossPrice = NormalizeDouble(bbLowerLossExit, Digits);
         double takeProfitPrice = NormalizeDouble(bbUpperProfitExit, Digits);

         // Check if stop-loss and take-profit are within allowed distance   *
         if(MathAbs(Ask - stopLossPrice) < stopLevel || MathAbs(Ask - takeProfitPrice) < stopLevel)
         {
            Alert("Stop-loss or take-profit is too close to the current price.");
            return;
         }

         Print("Entry Price = " + DoubleToStr(Ask));
         Print("Stop Loss Price = " + DoubleToStr(stopLossPrice));
         Print("Take Profit Price = " + DoubleToStr(takeProfitPrice));

         double lotSize = OptimalLotSize(riskPerTrade, Ask, stopLossPrice);
         //   *
         openOrderID = OrderSend(Symbol(), OP_BUY, lotSize, Ask, 3, stopLossPrice, takeProfitPrice, NULL, magicNB, 0, clrNONE);
         if(openOrderID < 0) 
         {
            Alert("Order rejected. Order error: " + DoubleToStr(GetLastError()));
         }
      }
      else if(Bid > bbUpperEntry && Open[0] < bbUpperEntry && rsiValue > rsiUpperLevel) // Shorting
      {
         Print("Price is above bbUpper and rsiValue is above " + DoubleToStr(rsiUpperLevel) + " Sending short order");
         double stopLossPrice = NormalizeDouble(bbUpperLossExit, Digits);
         double takeProfitPrice = NormalizeDouble(bbLowerProfitExit, Digits);

         // Check if stop-loss and take-profit are within allowed distance
         if(MathAbs(Bid - stopLossPrice) < stopLevel || MathAbs(Bid - takeProfitPrice) < stopLevel)
         {
            Print("Stop-loss or take-profit is too close to the current price.");
            return;
         }

         Print("Entry Price = " + DoubleToStr(Bid));
         Print("Stop Loss Price = " + DoubleToStr(stopLossPrice));
         Print("Take Profit Price = " + DoubleToStr(takeProfitPrice));

         double lotSize = OptimalLotSize(riskPerTrade, Bid, stopLossPrice);

         openOrderID = OrderSend(Symbol(), OP_SELL, lotSize, Bid, 3, stopLossPrice, takeProfitPrice, NULL, magicNB, 0, clrNONE);
         if(openOrderID < 0) 
         {
            Alert("Order rejected. Order error: " + DoubleToStr(GetLastError()));
         }
      }
   }
   else // If you already have a position, update orders if needed
   {
      if(OrderSelect(openOrderID, SELECT_BY_TICKET))
      {
         int orderType = OrderType(); // Short = 1, Long = 0

         double optimalTakeProfit;

         if(orderType == 0) // Long position
         {
            optimalTakeProfit = NormalizeDouble(bbUpperProfitExit, Digits);
         }
         else // If short
         {
            optimalTakeProfit = NormalizeDouble(bbLowerProfitExit, Digits);
         }

         double TP = OrderTakeProfit();
         double TPdistance = MathAbs(TP - optimalTakeProfit);
         if(TP != optimalTakeProfit && TPdistance > 0.0001)
         {
            bool Ans = OrderModify(openOrderID, OrderOpenPrice(), OrderStopLoss(), optimalTakeProfit, 0);

            if(Ans == true)
            {
               Print("Order modified: ", openOrderID);
            }
            else
            {
               Print("Unable to modify order: ", openOrderID);
            }
         }
      }
   }
}
//+------------------------------------------------------------------+







//  CustomFunction 

//+------------------------------------------------------------------+
//|                                            CustomFunctions01.mqh |
//|                                                         Valantis |
//|                                             https://www.test.com |
//+------------------------------------------------------------------+
#property copyright "Valantis"
#property link      "https://www.Test.com"
#property strict



double CalculateTakeProfit(bool isLong, double entryPrice, int pips)
{  

   
   double takeProfit;
   if(isLong)
   {
      takeProfit = entryPrice + pips * GetPipValue();
   }
   else
   {
      takeProfit = entryPrice - pips * GetPipValue();
   }
   
   return takeProfit;
}

double CalculateStopLoss(bool isLong, double entryPrice, int pips)
{
   double stopLoss;
   if(isLong)
   {
      stopLoss = entryPrice - pips * GetPipValue();
   }
   else
   {
      stopLoss = entryPrice + pips * GetPipValue();
   }
   return stopLoss;
}




double GetPipValue()
{
   if(_Digits >=4)
   {
      return 0.0001;
   }
   else
   {
      return 0.01;
   }
}


void DayOfWeekAlert()
{

   Alert("");
   
   int dayOfWeek = DayOfWeek();
   
   switch (dayOfWeek)
   {
      case 1 : Alert("We are Monday. Let's try to enter new trades"); break;
      case 2 : Alert("We are tuesday. Let's try to enter new trades or close existing trades");break;
      case 3 : Alert("We are wednesday. Let's try to enter new trades or close existing trades");break;
      case 4 : Alert("We are thursday. Let's try to enter new trades or close existing trades");break;
      case 5 : Alert("We are friday. Close existing trades");break;
      case 6 : Alert("It's the weekend. No Trading.");break;
      case 0 : Alert("It's the weekend. No Trading.");break;
      default : Alert("Error. No such day in the week.");
   }
}


double GetStopLossPrice(bool bIsLongPosition, double entryPrice, int maxLossInPips)
{
   double stopLossPrice;
   if (bIsLongPosition)
   {
      stopLossPrice = entryPrice - maxLossInPips * 0.0001;
   }
   else
   {
      stopLossPrice = entryPrice + maxLossInPips * 0.0001;
   }
   return stopLossPrice;
}


bool IsTradingAllowed()
{
   if(!IsTradeAllowed())
   {
      Print("Expert Advisor is NOT Allowed to Trade. Check AutoTrading.");
      return false;
   }
   
   if(!IsTradeAllowed(Symbol(), TimeCurrent()))
   {
      Print("Trading NOT Allowed for specific Symbol and Time");
      return false;
   }
   
   return true;
}
  
  
double OptimalLotSize(double maxRiskPrc, int maxLossInPips)
{

  double accEquity = AccountEquity();
  Print("accEquity: " + DoubleToStr(accEquity));
  
  double lotSize = MarketInfo(NULL,MODE_LOTSIZE);
  Print("lotSize: " + DoubleToStr(lotSize));
  
  double tickValue = MarketInfo(NULL,MODE_TICKVALUE);
  
  if(Digits <= 3)
  {
   tickValue = tickValue /100;
  }
  
  Print("tickValue: " + DoubleToStr(tickValue));
  
  double maxLossDollar = accEquity * maxRiskPrc;
  Print("maxLossDollar: " + DoubleToStr(maxLossDollar));
  
  double maxLossInQuoteCurr = maxLossDollar / tickValue;
  Print("maxLossInQuoteCurr: " + DoubleToStr(maxLossInQuoteCurr));
  
  double optimalLotSize = NormalizeDouble(maxLossInQuoteCurr /(maxLossInPips * GetPipValue())/lotSize,2);
  
  return optimalLotSize;
 
}


double OptimalLotSize(double maxRiskPrc, double entryPrice, double stopLoss)
{
    //int maxLossInPips = MathAbs(entryPrice - stopLoss)/GetPipValue();
    int maxLossInPips = (int)MathRound(MathAbs(entryPrice - stopLoss)/GetPipValue());
   return OptimalLotSize(maxRiskPrc,maxLossInPips);
}



bool CheckIfOpenOrdersByMagicNB(int magicNB)
{
   int openOrders = OrdersTotal();
   
   for(int i = 0; i < openOrders; i++)
   {
      if(OrderSelect(i,SELECT_BY_POS)==true)
      {
         if(OrderMagicNumber() == magicNB) 
         {
            return true;
         }  
      }
   }
   return false;
}






