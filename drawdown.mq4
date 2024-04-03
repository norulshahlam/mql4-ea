//+------------------------------------------------------------------+
//|                                                   MaxDDLogger.mq4|
//|                        Copyright 2024, Your Company             |
//|                                       https://www.yourwebsite.com|
//+------------------------------------------------------------------+
#property strict

// Structure to hold trade information
struct TradeInfo {
   double entryPrice;
   double profitLoss;
   double drawdownPips;
   int orderId;
   double lotSize;
   string symbol;
   double swap;
};

// Array to store information about each trade
TradeInfo trades[]; // Declare trades array without specifying size

// Initialize variables to track smallest drawdownPips, total drawdown, and total profitLoss
double largestDrawdownPips = DBL_MAX; // Initialize to maximum possible value
TradeInfo existingTrade[];
double existingTotalDrawdownPips = 0;
double totalProfitLoss = 0;
double totalDrawdownPips = 0;
int indexLargestDrawdown = -1;
int indexMinimumPL = -1;

// To manually manage onTick()
bool runOnTick = false;


//+------------------------------------------------------------------+
//| Input parameter                                                  |
//+------------------------------------------------------------------+
input int timerIntervalSeconds = 5; // Tick interval (in seconds)
input int writeFrequencyMin = 15; // Frequency to write to excel (in minutes)
input int timeZoneOffUtc = 8.00; // Timezoneoffset - Default at SGT (+0800)
input int offSetDiffProfitLoss = 5; // Offset for Pips difference
int loopBeforeWrite = writeFrequencyMin * 60 / timerIntervalSeconds; // writeFrequencyMin * 60 / timerIntervalSeconds; 
int initLoopBeforeWrite = 0;

// Timezone setting
double timeZoneOffset = TimeGMTOffset()/60/60;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    Print("Initializing...timezone offset: ",timeZoneOffset, " hours", ", TimeGMT: ", TimeGMT(), ", TimeLocal: ", TimeLocal());
    EventSetTimer(timerIntervalSeconds); // Set timer to trigger every specified interval
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   EventKillTimer(); // Kill the timer
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   if(runOnTick){
   
   // Clear existing trades array
   ArrayResize(trades, 0);
   
   totalProfitLoss = 0;
   totalDrawdownPips = 0;
   indexLargestDrawdown = -1;
   largestDrawdownPips = 0;
   indexMinimumPL = -1;
   double minPL = DBL_MAX;
      
   // Loop through all open positions
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && (OrderType() == OP_BUY || OrderType() == OP_SELL)) {
         
         // Retrieve trade information
         int orderId = OrderTicket(); // Get order ID
         double entryPrice = OrderOpenPrice();
         double currentPrice = MarketInfo(OrderSymbol(), MODE_BID);
         double lotSize = OrderLots(); // Get lot size
         string symbol = OrderSymbol(); // Get order symbol
         double point = MarketInfo(OrderSymbol(), MODE_POINT); // Retrieve pip value
   
         // Calculate drawdown in pips
         double drawdownPips = (currentPrice - entryPrice) / point / 10;
         drawdownPips = NormalizeDouble(drawdownPips, 2); // Round to nearest pip
   
         // Calculate profit/loss
         double profitLoss = NormalizeDouble(OrderProfit(), 2); // Round to two decimal places
               
         // Retrieve swap value for the current trade
         double swap = OrderSwap();
         
         // Get accumulated P/L & pips drawdown for the current tick
         totalProfitLoss += profitLoss + swap;
         totalDrawdownPips += drawdownPips;
         
         // Get index of the largest drawdown in pips
         if(drawdownPips < largestDrawdownPips) {
            largestDrawdownPips = drawdownPips;
            indexLargestDrawdown = i;
         }    
         
          // Get index of the smallest P&L
         if(profitLoss < minPL) {
            minPL = profitLoss;
            indexMinimumPL = i;
         }  
   
         // Log trade information
         // Print("Order ID: ", orderId, ", Symbol: ", symbol, ", Lot Size: ", lotSize, ", Drawdown (pips): ", drawdownPips, ", Profit/Loss: ", profitLoss);
   
         // Store trade information in the array
         TradeInfo trade;
         trade.orderId = orderId;
         trade.drawdownPips = drawdownPips; // Store drawdown in pips
         trade.profitLoss = profitLoss; // Store rounded P/L value   
         trade.lotSize = lotSize; // Store lot size
         trade.symbol = symbol; // Store order symbol
         trade.swap = swap;
   
         // Add trade information to the array
         ArrayResize(trades, ArraySize(trades) + 1);
         trades[ArraySize(trades) - 1] = trade;
         }
      }
      runOnTick = false;
   }
}

//+------------------------------------------------------------------+
//| Timer function to log maximum drawdown and total drawdown        |
//+------------------------------------------------------------------+
void OnTimer() {

   // Print("loopBeforeWrite: ",loopBeforeWrite, ", initLoopBeforeWrite: ",initLoopBeforeWrite);

   // Wait indefinitely until runOnTick is true
   while (!runOnTick) {

      if(initLoopBeforeWrite == loopBeforeWrite){
         Print("Reset counter for the next batch...");
         initLoopBeforeWrite = 0;
         existingTotalDrawdownPips = 0;
         writeToCsv();
      }

      // Log the Largest drawdownPips and its associated information IF it is the new high
      if (indexLargestDrawdown != -1 && totalDrawdownPips < existingTotalDrawdownPips - offSetDiffProfitLoss) {
         existingTotalDrawdownPips = totalDrawdownPips;

         // Log total drawdown in pips and total profit/loss
         // Print("Largest single drawdown (Pips): ", trades[indexLargestDrawdown].drawdownPips, ", Order ID: ", trades[indexLargestDrawdown].orderId, ", Symbol: ", trades[indexLargestDrawdown].symbol, ", P/L: ", trades[indexLargestDrawdown].profitLoss);  
         // Print("Smallest single P&L: ", trades[indexMinimumPL].profitLoss, ", Order ID: ", trades[indexMinimumPL].orderId, ", Symbol: ",  trades[indexMinimumPL].symbol, ", Pips: ", trades[indexMinimumPL].drawdownPips);        
         Print(TimeGMT() + (timeZoneOffUtc*60*60), " - New highest Total Drawdown (Pips): ", totalDrawdownPips, ", Total Profit/Loss: ", totalProfitLoss);
         
         // Display information on the chart
         string info = TimeToString(TimeGMT() + (timeZoneOffUtc*60*60)) + " HRS\nLargest single drawdown (Pips): " + DoubleToStr(trades[indexLargestDrawdown].drawdownPips, 2) + ", Order ID: " + IntegerToString(trades[indexLargestDrawdown].orderId) + ", Symbol: " + trades[indexLargestDrawdown].symbol + ", P/L: " + DoubleToStr(trades[indexLargestDrawdown].profitLoss, 2) + "\nSmallest single P&L: " + DoubleToStr(trades[indexMinimumPL].profitLoss, 2) + ", Order ID: " + IntegerToString(trades[indexMinimumPL].orderId) + ", Symbol: " + trades[indexMinimumPL].symbol + ", Pips: " + DoubleToStr(trades[indexMinimumPL].drawdownPips, 2) + "\nTotal Drawdown (Pips): " + DoubleToStr(totalDrawdownPips, 2) + ", Total Profit/Loss: " + DoubleToStr(totalProfitLoss, 2);
      
         Comment(info);
      
         // Resize the destination array to match the size of the source array
         ArrayResize(existingTrade, ArraySize(trades));
         
         // Copy elements from the source array to the destination array. This is to compare the next tick()
         for (int i = 0; i < ArraySize(trades); i++) {
            existingTrade[i] = trades[i];
         }
      }
   runOnTick = true;
   initLoopBeforeWrite++;
   }
}

void writeToCsv(){
      
   // Open file for read and write
   int fileHandleNew = FileOpen("drawdown.csv", FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI,',');

   // Check if the file was opened successfully
   if (fileHandleNew != INVALID_HANDLE){
      
      // Move the file pointer to the end of the file
      FileSeek(fileHandleNew, 0, SEEK_END);

      // Init file with header if file is not present
      if (FileTell(fileHandleNew) == 0){

         // Write the header line to the file
         FileWrite(fileHandleNew, "Timestamp","Total trades", "Total Drawdown (Pips)","Total Profit/Loss","Largest single drawdown (Pips)", "Order ID", "Symbol", "P/L", "Smallest single P&L", "Order ID", "Symbol", "Pips");
      }
      // Write the data line to the file
      FileWrite(fileHandleNew, TimeToString(TimeGMT() + (timeZoneOffUtc*60*60), TIME_DATE | TIME_SECONDS), ArraySize(trades) ,DoubleToStr(totalDrawdownPips, 2),DoubleToStr(totalProfitLoss, 2), DoubleToStr(trades[indexLargestDrawdown].drawdownPips, 2), IntegerToString(trades[indexLargestDrawdown].orderId), trades[indexLargestDrawdown].symbol, DoubleToStr(trades[indexLargestDrawdown].profitLoss, 2), DoubleToStr(trades[indexMinimumPL].profitLoss, 2), IntegerToString(trades[indexMinimumPL].orderId), trades[indexMinimumPL].symbol, DoubleToStr(trades[indexMinimumPL].drawdownPips, 2));
   
      // Close the file
      FileClose(fileHandleNew);

      Print("Write success!");
      return;
   }
   Print("Fail to read or init file!");
}
