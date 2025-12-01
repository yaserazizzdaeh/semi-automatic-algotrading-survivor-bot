#property copyright "Copyright 2025, Yaser Azizzadeh"
#property link      " "
#property version   "7.25"

#include <Trade/Trade.mqh>

#define bull "bull"
#define bear "bear"
#define nosignal "nosignal"
input group      "--------------Trade Settings ---------------"
input bool tradeallow=true;         // Allow Trade
input double riskpercent = 1.0;   // Trade Risk (%)
 int takeprofit = 20;        // Take Profit (pips)
 int stoploss   = 1;       // Stop Loss (pips)micro sl
int slippage   = 5;      // Slippage (points)
int magicseed  = 10002; // Magic Seed
input double entry_ratio=0.3;  // Pos Entry Price Ratio (0><=1)
input group      "-------------- Candle Sets ---------------"

//input double bodyratio=2.0; //  Body Size Ratio

input double verify_distance=5; // verify distance (points)
input int bullret=5; // Max Retrace Candles (bull)
input int bearret=5; // Max Retrace Candles (bear)
input group      "-------------- MA Confirmations ---------------"
input bool use_ma=false;                            // Use MA
input ENUM_TIMEFRAMES tf_ma=PERIOD_H1;                              //  Time Frame
input ENUM_MA_METHOD ma_method=MODE_EMA;         // MA Method
input int faster_ma=20;                          // Faster MA Period
input int slower_ma=50;                        //  Slower MA Period
int ma_val_candle_count=2;            //   MA Validation Candles Count
input group      "--------------- Risk Free Settings ---------------"
input bool useriskfree   = false; // Using Risk Free
input int whentoriskfree = 10;   // When To Risk Free (pips)
input int pipstolock     = 0;   // Pips To Lock In (pips)
input group "--------------- Trade Timing Settings ---------------";
input bool    timecontrol    = false;        // Valid Trading Times
input int     starthour      = 15;          // Start Time (hours)
input int     startminute    = 0;          // Start Time (minutes)
input int     endhour        = 19;         // End Time (hours)
input int     endminute      = 0;        // End Time (minutes)
input group      "-------------- RSI ---------------"
input bool use_rsi=false;      // Use RSI
input ENUM_TIMEFRAMES frame =PERIOD_H1;        //  Time Frame
input int rsiup    =80;     //     Rsi Upper Treshold
input int rsilow   =20;    //      Rsi Lower Treshold
input int rsiperiod=14;   //    Rsi Period


//++--------------------
double pips=0;
input ulong magicnumber=1111111; // magic number
int copied=0;
int signal=0;
double candle_a[4]; //OHLC
string signaltype=nosignal; // just for use in retrace check
bool issignal=false;
datetime candle_a_time;
//+---------------
CTrade trade;
CPositionInfo posinfo;
COrderInfo orderinfo;

MqlTick tick;
MqlRates rates[];
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   if(!CreateDeleteOrderButton())
   {
      Print("Error creating button: ", GetLastError());
      return INIT_FAILED;
   }
   TesterHideIndicators(true);
   ArrayInitialize(candle_a,0);
   ArraySetAsSeries(rates,true);
   Atr(nosignal);
   MA(nosignal);
   
   copied=CopyRates(_Symbol,_Period,0,7,rates);
   SymbolPointCalculate();
   //magicnumber=MagicNumberGenerator();
   trade.SetExpertMagicNumber(magicnumber);
   trade.SetDeviationInPoints(slippage);    
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Object_Delete();
   ObjectDelete(0, "Btn_DeleteOrder");
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    copied=CopyRates(_Symbol,_Period,0,7,rates);
    if(IsNewBar())
    {
      //zero for nosignal 1 for bull and 2 for bear signal      
      if(TotalOpenPosition()==0&&!issignal)CheckSignal(); 
    }
    SignalVerify(signal);
    if(useriskfree)MoveToBreakEven();  
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SignalVerify(const int type)
{
   // candle a/b[4]:[open][high][low][close]
   //type=1 : bull
   //type=2 : bear
   if(type==0)return;
   if(type==1)//type is bull
     {
         if(rates[1].close-candle_a[1]>verify_distance*_Point)
         {
             signal=0; 
             Print("signal is valid,distance verify");            
             EnterTrade(ORDER_TYPE_BUY_LIMIT);
             signaltype=bull;
             
         }
         else if(rates[1].close<candle_a[2])
         {
            Print("signal not valid,distance verify issue");
            signal=0;
            issignal=false;
            signaltype=nosignal;  
         }
     }
   if(type==2)//type is bear
     {
         if(candle_a[2]-rates[1].close>=verify_distance*_Point)
         {
             signal=0;
             Print("signal is valid,distance verify");
             EnterTrade(ORDER_TYPE_SELL_LIMIT);
             signaltype=bear;
                         
         }
         else if(rates[1].close>candle_a[1])
         {
            Print("signal not valid,distance verify issue");
            signal=0;
            issignal=false;     
            signaltype=nosignal;         
         }
     }
}

//+------------------------------------------------------------------+
void CheckSignal()
{
   if(OrdersTotal()>0)return;
   double close1=rates[1].close,
          close2=rates[2].close,
          open1=rates[1].open,
          open2=rates[2].open,
          body1=MathAbs(open1-close1),
          body2=MathAbs(open2-close2);
          //ratio=NormalizeDouble(body1/body2,_Digits);
   
   if(body1<Atr("min")||body1>Atr("max")||body2<Atr("regular"))return; //||body2<Atr("regular")
   
   bool bulleng=(open1<close1)&&
                (open2>close2)&&
                (open1<=close2)&&
                (close1>open2),
                
        beareng=(open1>close1)&&
                (open2<close2)&&
                (open1>=close2)&&
                (close1<open2);
   
                
   if(bulleng&&!MA(bull)&&RSI(bull))
   {
      signal=1;  // 1 means there is bull signal
      candle_a[0]=rates[1].open;
      candle_a[1]=rates[1].high;
      candle_a[2]=rates[1].low;
      candle_a[3]=rates[1].close;
      candle_a_time=rates[1].time;
      issignal=true;
      Object_Delete();
      ArrowCheckCreate(0,bull,0,rates[1].time,close1+2*pips,clrGreen);
      Print("there is bull pattern detected");
      return;
   }
   else if(beareng&&!MA(bear)&&RSI(bear))
   {
      signal=2; // 2 means there is bear signal
      issignal=true;
      candle_a[0]=rates[1].open;
      candle_a[1]=rates[1].high;
      candle_a[2]=rates[1].low;
      candle_a[3]=rates[1].close;  
      candle_a_time=rates[1].time;          
      Object_Delete();
      ArrowCheckCreate(0,bear,0,rates[1].time,close1-2*pips,clrGreen); 
      Print("there is bear pattern detected"); 
      return; 
   }
     
   signal=0; // zero means there is no pattern signal
}
//++----------------------------------------------
bool RSI(const string type)
{
    if(use_rsi==false)return true;
    
    
    int rsi_handle=iRSI(_Symbol,frame,rsiperiod,PRICE_CLOSE);
    double rsibuffer[];
    ArraySetAsSeries(rsibuffer,true);
    int copy=CopyBuffer(rsi_handle,0,1,1,rsibuffer);
    if(type==bear){if(rsibuffer[0]>=rsiup)return true;}
    else if(type==bull){if(rsibuffer[0]<=rsilow)return true;}  
    return false;
}
//+------------------------------------------------------------------+
//| atr                                                              |
//+------------------------------------------------------------------+
double Atr(const string type)
{
   // Use ATR to adjust candle size range dynamically
   int atr_handle = iATR(_Symbol,_Period,14);
   double atrbuffer[];
   ArraySetAsSeries(atrbuffer,true);
   int copy=CopyBuffer(atr_handle,0,1,2,atrbuffer);
   double min_body=atrbuffer[0]*0.7,
          max_body=atrbuffer[0]*6.0,
          regular=atrbuffer[1]/2.5;
   //Print("atr is: "+DoubleToString(atrbuffer[0]));
   double result=0;
   if(type=="max")result=max_body;
   else if(type=="min")result=min_body;
   else if(type=="regular")result=regular;
   return result;

}
//++----------------------------------------------
bool Comfirmation(const string type)
{ 
   if(!MA(type))return true;
   return false;
}
//++----------------------------------------------
bool MA(const string type)
{
   if(use_ma==false)return false;
   int fast_ma_handler=iMA(_Symbol,tf_ma,faster_ma,0,ma_method,PRICE_CLOSE),
       slow_ma_handler=iMA(_Symbol,tf_ma,slower_ma,0,ma_method,PRICE_CLOSE);
   double slow_buffer[],
          fast_buffer[];
   ArraySetAsSeries(fast_buffer,true);
   ArraySetAsSeries(slow_buffer,true);
   int copy0=CopyBuffer(fast_ma_handler,0,1,ma_val_candle_count,fast_buffer),
       copy1=CopyBuffer(slow_ma_handler,0,1,ma_val_candle_count,slow_buffer);  
   Print("fast ma "+DoubleToString(fast_buffer[1]));
   Print("slow ma "+DoubleToString(slow_buffer[1]));
          
   if(type==bull)for(int i=0;i<ma_val_candle_count;i++){if(slow_buffer[i]<fast_buffer[i])return false;}
   else if(type==bear)for(int i=0;i<ma_val_candle_count;i++){if(slow_buffer[i]>fast_buffer[i])return false;}  
   return true;
}


//++----------------------------------------------
void EnterTrade(ENUM_ORDER_TYPE type)
{
   if(TimeControl()==false)return;
   if(tradeallow==false)return;
   string order_comment=type==ORDER_TYPE_BUY_LIMIT?"buy":"sell";
   double sl=0,
          tp=0,        
          lot=NormalizeDouble(LotSizeCalculate(),2),       
          price=0,
          body=MathAbs(candle_a[1]-candle_a[2]),
          body_mul_tp=NormalizeDouble(2.0*body*(1+entry_ratio),_Digits),
          body_mul_sl=NormalizeDouble(body_mul_tp/2,_Digits),
          body_entry=MathAbs(candle_a[0]-candle_a[3]);
          body_entry=NormalizeDouble(body_entry*entry_ratio,_Digits);
          int time_multiple=type==ORDER_TYPE_BUY_LIMIT?bullret:bearret;  
          datetime timi= iTime(_Symbol, _Period, 0)+time_multiple*PeriodSeconds(PERIOD_CURRENT);            
       if(type==ORDER_TYPE_BUY_LIMIT)
       {
            price=candle_a[3]-body_entry;
           //sl=NormalizeDouble(openprice-stoploss*pips,_Digits);
           sl=0;//NormalizeDouble(price-body_mul_sl,_Digits);
           tp=0;//NormalizeDouble(price+body_mul_tp,_Digits); 
           //tp=NormalizeDouble(openprice+takeprofit*pips,_Digits);
             
           trade.OrderOpen(_Symbol,ORDER_TYPE_BUY_LIMIT,lot,NULL,price,sl,tp,
                           ORDER_TIME_SPECIFIED,timi,_Symbol);
           Alert("sell limit order on ",_Symbol);
                          
           //Print("expiration date is : "+timi)  ;            
       }
       else if(type==ORDER_TYPE_SELL_LIMIT)
       {
           price=candle_a[3]+body_entry;
           //sl=NormalizeDouble(openprice+stoploss*pips,_Digits);
           sl=0;//NormalizeDouble(price+body_mul_sl,_Digits);
           tp=0;//NormalizeDouble(price-body_mul_tp,_Digits);
           //tp=NormalizeDouble(openprice-takeprofit*pips,_Digits); 
           trade.OrderOpen(_Symbol,ORDER_TYPE_SELL_LIMIT,lot,NULL,price,sl,tp,
                           ORDER_TIME_SPECIFIED,timi,_Symbol);
           Alert("sell limit order on ",_Symbol);                                               
       }                                
       
   issignal=false;
   ArrayInitialize(candle_a,0);
     
}
//+------------------------------------------------------------------+
//|  DeletePendingsAll()                                             |
//+------------------------------------------------------------------+
void DeleteOrder()
{
   for(int i=OrdersTotal()-1;i>=0;i--) 
     {
         if(orderinfo.SelectByIndex(i)&&orderinfo.Magic()==magicnumber&&orderinfo.Symbol()==_Symbol)trade.OrderDelete(orderinfo.Ticket());
     }
}
//+------------------------------------------------------------------+
//| Create Delete Order Button                                       |
//+------------------------------------------------------------------+
bool CreateDeleteOrderButton()
{
   string name = "Btn_DeleteOrder";
   int x = 2;  // Right offset from corner
   int y = 25;  // Top offset from corner
   int width = 100;
   int height = 24;
   
   // Create button
   if(!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0))
      return false;
   
   // Set button properties
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetString(0, name, OBJPROP_TEXT, "Delete Order");
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrRoyalBlue);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
   
   ChartRedraw();
   return true;
}

//+------------------------------------------------------------------+
//| Handle button click event                                        |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                 const long &lparam,
                 const double &dparam,
                 const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == "Btn_DeleteOrder")
      {
         
         ChartRedraw();
         DeleteOrder(); // Your delete order function
         Print("order had been delete");
      }
   }
}

//+------------------------------------------------------------------+
//|  Object_Delete()                                                 |
//+------------------------------------------------------------------+
void Object_Delete()
{
     ObjectDelete(ChartID(),bull);
     ObjectDelete(ChartID(),bear);      
}

//+------------------------------------------------------------------+
//|  TotalOpenOrder()                                                |
//+------------------------------------------------------------------+
int TotalOpenPosition()
{    
    int total=0;
    for(int i=0;i<PositionsTotal();i++)
    {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC)==magicnumber&&
            PositionGetString(POSITION_SYMBOL)==_Symbol)total++;
      }
         
    }
    return total;
}
//+------------------------------------------------------------------+
//|   LotSizeCalculate()                                             |
//+------------------------------------------------------------------+
double LotSizeCalculate()
{
    double balance=AccountInfoDouble(ACCOUNT_BALANCE);
    double minlot= SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
    double maxlot= SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);  
    double baselot=NormalizeDouble(((balance*(riskpercent/100.0))/1000.0),2);
    if(baselot<=0)baselot=minlot;
    else if(baselot>maxlot)baselot=maxlot;
    Print("Current lot size is : ",baselot);
    return baselot;
}
//+------------------------------------------------------------------+
//|  MagicNumberGenerator()                                          |
//+------------------------------------------------------------------+
ulong MagicNumberGenerator()
{
     ulong GenerateNumber = 0;
     int PairNumber = 1;    
          if(_Symbol=="XAUUSD") PairNumber=2;
     else if(_Symbol=="EURUSD") PairNumber=3;
     else if(_Symbol=="AUDUSD") PairNumber=4;
     else if(_Symbol=="GBPUSD") PairNumber=5;
     else if(_Symbol=="NZDUSD") PairNumber=6;
     else if(_Symbol=="USDCAD") PairNumber=7;
     else if(_Symbol=="USDCHF") PairNumber=8;
     else if(_Symbol=="USDJPY") PairNumber=9;     
     GenerateNumber = magicseed+(PairNumber * 1000)+_Period;     
     return GenerateNumber;
}
//+------------------------------------------------------------------+
//|   IsNewBar()                                                     |
//+------------------------------------------------------------------+
bool IsNewBar()
{
    static datetime recenttime = 0;
    
    if(recenttime!=iTime(_Symbol,PERIOD_CURRENT,0))
    {
        recenttime=iTime(_Symbol,PERIOD_CURRENT,0);
        return true;        
    }   
    return false;
}
//+------------------------------------------------------------------+
//|   IsNewBar()                                                     |
//+------------------------------------------------------------------+
bool IsNewBar1()
{
    static datetime recenttimee = 0;
    
    if(recenttimee!=iTime(_Symbol,PERIOD_CURRENT,0))
    {
        recenttimee=iTime(_Symbol,PERIOD_CURRENT,0);
        return true;        
    }   
    return false;
}

//+------------------------------------------------------------------+
//|  SymbolPointCalculate()                                          |
//+------------------------------------------------------------------+
void SymbolPointCalculate()
{
         if(_Digits==5||_Digits==3)pips=_Point*10;
    else if(_Digits==2)pips= _Point*10;
    else if(_Digits==4||_Digits==1)pips=_Point;
    else if(_Digits==0)pips=1;
}

//+------------------------------------------------------------------+
//|  TimeControl                                                     |
//+------------------------------------------------------------------+
bool TimeControl()
{
    if(!timecontrol)return true;   
    MqlDateTime time_struct;
    TimeCurrent(time_struct);
    long starttime=(starthour*3600+startminute*60);
    long endtime=(endhour*3600+endminute*60);
    long time_current_sec=(time_struct.hour*3600)+(time_struct.min*60);
    if(starttime>endtime)
    {
        if(time_current_sec>=starttime||time_current_sec<endtime)
            return true;
    }
    else if(starttime<endtime)
        {
            if(time_current_sec>=starttime&&time_current_sec<endtime)
                return true;
        }
    return false;
}
//+------------------------------------------------------------------+ 
//| Create Check sign                                                | 
//+------------------------------------------------------------------+ 
bool ArrowCheckCreate(const long              chart_ID=0,           // chart's ID 
                      const string            name="ArrowCheck",    // sign name 
                      const int               sub_window=0,         // subwindow index 
                      datetime                time=0,               // anchor point time 
                      double                  price=0,              // anchor point price 
                      const color             clr=clrRed,           // sign color 
                      const ENUM_ARROW_ANCHOR anchor=ANCHOR_BOTTOM, // anchor type 
                      
                      const ENUM_LINE_STYLE   style=STYLE_SOLID,    // border line style 
                      const int               width=3,              // sign size 
                      const bool              back=false,           // in the background 
                      const bool              selection=false,       // highlight to move 
                      const bool              hidden=true,          // hidden in the object list 
                      const long              z_order=0)            // priority for mouse click 
  { 
//--- set anchor point coordinates if they are not set 
//--- reset the error value 
   ResetLastError(); 
//--- create the sign 
   if(!ObjectCreate(chart_ID,name,OBJ_ARROW_CHECK,sub_window,time,price)) 
     { 
      Print(__FUNCTION__, 
            ": failed to create \"Check\" sign! Error code = ",GetLastError()); 
      return(false); 
     } 
//--- set anchor type 
   ObjectSetInteger(chart_ID,name,OBJPROP_ANCHOR,anchor); 
//--- set a sign color 
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr); 
//--- set the border line style 
   ObjectSetInteger(chart_ID,name,OBJPROP_STYLE,style); 
//--- set the sign size 
   ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH,width); 
//--- display in the foreground (false) or background (true) 
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back); 
//--- enable (true) or disable (false) the mode of moving the sign by mouse 
//--- when creating a graphical object using ObjectCreate function, the object cannot be 
//--- highlighted and moved by default. Inside this method, selection parameter 
//--- is true by default making it possible to highlight and move the object 
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection); 
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection); 
//--- hide (true) or display (false) graphical object name in the object list 
   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden); 
//--- set the priority for receiving the event of a mouse click in the chart 
   ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order); 
//--- successful execution 
   return(true); 
  }
  
  
  

//+------------------------------------------------------------------+
//|     MoveToBreakEven()                                            |
//+------------------------------------------------------------------+
void MoveToBreakEven()
{
    if(!SymbolInfoTick(_Symbol,tick))Print("Could not get current tick data ");
    int totalpos= PositionsTotal();
    int err=0;
    for(int i=0;i<totalpos;i++)
      {
            ulong ticket=PositionGetTicket(i);
            if(PositionSelectByTicket(ticket))
              {
                  if(PositionGetString(POSITION_SYMBOL)==_Symbol)
                    {
                        if(PositionGetInteger(POSITION_MAGIC)==magicnumber)
                          {
                              double openprice=PositionGetDouble(POSITION_PRICE_OPEN);
                              double pos_sl=PositionGetDouble(POSITION_SL);
                              double pos_tp=PositionGetDouble(POSITION_TP);                                                                  
                              if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
                                {
                                    if(tick.bid-openprice>whentoriskfree*pips)
                                      {
                                          if(pos_sl<openprice)
                                            {
                                                 if(!trade.PositionModify(ticket,openprice+pipstolock*pips,pos_tp))  
                                                 {err=GetLastError();Print("could not risk free buy position due to : ",err);}  
                                                 else{Print("Buy position risk free done!");}                                                   
                                            }
                                      }
                                }
                              else if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
                                {
                                     if(openprice-tick.ask>whentoriskfree*pips)
                                       {
                                            if(pos_sl>openprice||pos_sl==0)
                                              {
                                                  if(!trade.PositionModify(ticket,openprice-pipstolock*pips,pos_tp))
                                                  {err=GetLastError();Print("could not risk free sell position due to : ",err);}                                                                                                            
                                                  else{Print("Sell position risk free done!");}
                                              }
                                       }
                                }
                          }
                    } 
              }       
      }
} 
//+------------------------------------------------------------------+
//|   lot size calculater                                            |
//+------------------------------------------------------------------+

double LotSizeCalculate1()
{
   double lotsize = 0;
  // double tickvalue = MarketBookGet(_Symbol, * PointToPip; 
   double accuontsize = AccountInfoDouble(ACCOUNT_BALANCE);;
    
   double risk = accuontsize * riskpercent * 0.01;
      
  // lotsize = (risk / (Stop_Loss * 1.0)) / tickvalue;
   lotsize = NormalizeDouble(lotsize, 2);
   
   double minlot =  SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxlot =  SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   
   if( lotsize <= 0) lotsize = minlot;
   
   else if(lotsize > maxlot) lotsize = maxlot;
   
   return lotsize;
}