//+------------------------------------------------------------------+
//|                                    FELIX-Constant_Tick_Chart.mq4 |
//|                                                       Version:1.0|
//|                                           felixsagitta@gmail.com |
//|                                         tioh.wei.lun99@nus.edu.sg|
//|                                           http://mt4.myzeppa.com |
//+------------------------------------------------------------------+
#property copyright "Felix- felixsagitta@gmail.com"
#property link      "http://mt4.myzeppa.com"
#property indicator_chart_window
#property indicator_buffers 1
//+------------------------------------------------------------------+
#include <WinUser32.mqh>
#include <stdlib.mqh>
//+------------------------------------------------------------------+
#import "user32.dll"
int RegisterWindowMessageA(string lpString); 
#import
//+------------------------------------------------------------------+
extern int TickCount = 1;
extern int TimeFrame = 2;
bool EmulateOnLineChart = true;
bool StrangeSymbolName = false;

//+-----System variables----------------------------------------------+
int HstHandle, LastFPos, MT4InternalMsg;
string SymbolName;
int firstbartime;

//------Chart variables------------------------------------------------+
double CurVolume, CurLow, CurHigh, CurOpen, CurClose, price;
datetime PrevTime;


int init()  {
   price = -1;
	HstHandle = -1;
	LastFPos = 0;
	MT4InternalMsg = 0;
	firstbartime = Time[Bars-1]; 
	return(0);
}


//+------------------------------------------------------------------+
int start() {
	if(firstbartime != Time[Bars-1]){
		deinit();
		init();
	}

	// This is only executed ones, then the first tick arives.
	if(HstHandle < 0) {
		if(bootstrap()!=1)
		Comment("cannot run file");	
		else
		{
			if(HstHandle > 0)
			FileFlush(HstHandle);
		}
	}
	//----Begin live data feed----
	Comment("FELIX-Normalized Constant TickChart(" + TickCount  + "): Goto File->Open Offline,then open ", SymbolName, ",M", TimeFrame, " to view chart");
	updatelive(Bid);
	
	return(0);
}
//+------------------------------------------------------------------+
int deinit() {
	if(HstHandle >= 0) {
		FileClose(HstHandle);
		HstHandle = -1;
	}
	Comment("");
	return(0);
}
//+------------------------------------------------------------------+

int bootstrap(){
	// Init

	// Error checking	
	if(!IsConnected()) {
		Print("Waiting for connection...");
		return(0);
	}							
	if(!IsDllsAllowed()) {
		Print("Error: Dll calls must be allowed!");
		return(-1);
	}		
	switch(TimeFrame) {
	case 1: case 5: case 15: case 30: case 60: case 240:
	case 1440: case 10080: case 43200: case 0:
		Print("Error: Invalid time frame used for offline Pf chart (PfTimeFrame)!");
		return(-1);
	}
	if(StrangeSymbolName) SymbolName = StringSubstr(Symbol(), 0, 6);
	else SymbolName = Symbol();
	
	// create / open hst file		
	HstHandle = FileOpenHistory(SymbolName + TimeFrame + ".hst", FILE_BIN|FILE_WRITE);
	if(HstHandle < 0) {
		Print("Error: can\'t create / open history file: " + ErrorDescription(GetLastError()) + ": " + SymbolName + TimeFrame + ".hst");
		return(-1);
	}
	//----
	
	// write hst file header
	int HstUnused[13];
	FileWriteInteger(HstHandle, 400, LONG_VALUE); 			// Version
	FileWriteString(HstHandle, "", 64);					// Copyright
	FileWriteString(HstHandle, SymbolName, 12);			// Symbol
	FileWriteInteger(HstHandle, TimeFrame, LONG_VALUE);	// Period
	FileWriteInteger(HstHandle, Digits, LONG_VALUE);		// Digits
	FileWriteInteger(HstHandle, 0, LONG_VALUE);			// Time Sign
	FileWriteInteger(HstHandle, 0, LONG_VALUE);			// Last Sync
	FileWriteArray(HstHandle, HstUnused, 0, 13);			// Unused
	
	LastFPos = FileTell(HstHandle);
	
	
	return(1);
}

//=====================
//  Main Processing
//=====================

int updatelive(double bid){
   if(price==-1){
      price = bid;
      CurClose = price;
      CurOpen = price;
      CurLow = price;
      CurHigh = price;
      PrevTime = TimeCurrent();
      CurVolume = 1;
   }
   else{
      if(bid>price){
		   price = price + Point;
		}
		else if(bid<price){
		   price = price - Point;
		}
   }
   
	if(CurVolume+1 >= TickCount){
		PrevTime = TimeCurrent();
		CurOpen = price;
		CurClose = price;
		CurHigh = price;
		CurLow = price;
		CurVolume = 1;
		insert(true);
	}
	else{
		CurVolume++;
		CurClose = price;
		CurHigh = MathMax(price,CurHigh);
		CurLow = MathMin(price,CurLow);
		insert(false);
	}
   return(1);
}


//=======END MAIN PROCESSING===========
//third tier abstraction functions

void insert(bool isNew){
	//if new bar,move pointer to new position
	if(isNew){
		LastFPos = FileTell(HstHandle);
	}
	
	FileSeek(HstHandle, LastFPos, SEEK_SET);
	
	FileWriteInteger(HstHandle, PrevTime, LONG_VALUE);		
	FileWriteDouble(HstHandle, NormalizeDouble(CurOpen,Digits), DOUBLE_VALUE);         	
	FileWriteDouble(HstHandle, NormalizeDouble(CurLow,Digits), DOUBLE_VALUE);		
	FileWriteDouble(HstHandle, NormalizeDouble(CurHigh,Digits), DOUBLE_VALUE);		
	FileWriteDouble(HstHandle, NormalizeDouble(CurClose,Digits), DOUBLE_VALUE);		
	FileWriteDouble(HstHandle, MathRound(CurVolume), DOUBLE_VALUE);	
	
	//normally, only when updating on live chart that flush is needed because u want to make it show on chart
}



void UpdateChartWindow() {
	static int hwnd = 0;

	if(hwnd == 0) {
		hwnd = WindowHandle(SymbolName, TimeFrame);
		if(hwnd != 0) Print("Chart window detected");
	}

	if(EmulateOnLineChart && MT4InternalMsg == 0) 
	MT4InternalMsg = RegisterWindowMessageA("MetaTrader4_Internal_Message");

	if(hwnd != 0) if(PostMessageA(hwnd, WM_COMMAND, 0x822c, 0) == 0) hwnd = 0;
	if(hwnd != 0 && MT4InternalMsg != 0) PostMessageA(hwnd, MT4InternalMsg, 2, 1);

	return;
}