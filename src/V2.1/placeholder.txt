//+------------------------------------------------------------------+
//| TradingDashboard_v2_1.mq5 - quick dashboard                      |
//|                      https://www.mql5.com                        |
//+------------------------------------------------------------------+
#property link      "https://www.mql5.com"
#property version   "2.10"
#property indicator_chart_window
#property indicator_plots 0

// Inputs
input group "Indicators"
input bool EnableRSI = true;     // RSI
input int RSI_Period = 14;
input double RSI_Oversold = 30.0;
input double RSI_Overbought = 70.0;

input bool EnableEMA = true;     // EMA
input int EMA_Fast = 20;
input int EMA_Slow = 50;

input bool EnableBB = true;      // BB
input int BB_Period = 20;
input double BB_Deviation = 2.0;

input bool EnableATR = true;     // ATR
input int ATR_Period = 14;
input double ATR_Multiplier = 1.5;

input bool EnableOBV = true;     // OBV

input group "Timeframes"
input bool UseM1 = false;
input bool UseM5 = false;
input bool UseM15 = true;
input bool UseM30 = false;
input bool UseH1 = true;
input bool UseH4 = true;
input bool UseD1 = true;
input bool UseW1 = false;

input group "Trading"
input double LotSize = 0.01;
input double RiskReward = 2.0;
input int SL_Points = 500;
input bool AutoCloseOpposite = true;
input int MagicNumber = 12345;

input group "Visuals"
input color BuyColor = clrLimeGreen;
input color SellColor = clrRed;
input color NeutralColor = clrGray;
input color PanelColor = clrWhite;
input color HeaderColor = C'240,240,240';
input color TextColor = clrBlack;
input color BorderColor = clrSilver;
input int FontSize = 9;
input int RowHeight = 30;
input int ColWidth = 80;

input group "System"
input int RefreshRate = 5;      // refresh secs
input int MaxBarsLookback = 100;
input int AlertDelay = 120;     // alert delay

// Vars
CTrade trade;
int dash_w = 500;
int dash_h = 400;
int trade_h = 80;
int head_h = 100;
int ind_w = 80;
datetime last_upd = 0;
datetime last_alt = 0;
int alt_idx = 0;

ENUM_TIMEFRAMES tfs[8] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1};
string tf_names[8] = {"M1", "M5", "M15", "M30", "H1", "H4", "D1", "W1"};
bool tf_on[8];
int tf_cnt = 0;
int atr_h[8];
int obv_h[8];

string alerts[5] = {
    "Scanning markets...",
    "Analyzing price...",
    "Watching volatility...",
    "Checking signals...",
    "No alignment"
};

int OnInit()
{
    tf_on[0] = UseM1; tf_on[1] = UseM5; tf_on[2] = UseM15; tf_on[3] = UseM30;
    tf_on[4] = UseH1; tf_on[5] = UseH4; tf_on[6] = UseD1; tf_on[7] = UseW1;
    
    for(int i=0; i<8; i++)
        if(tf_on[i]) tf_cnt++;
    
    if(tf_cnt == 0) {
        Print("No TFs!");
        return INIT_FAILED;
    }
    
    for(int i=0; i<8; i++) {
        if(tf_on[i]) {
            if(EnableATR) {
                atr_h[i] = iATR(Symbol(), tfs[i], ATR_Period);
                if(atr_h[i] == INVALID_HANDLE) {
                    Print("ATR fail: ", tf_names[i]);
                    return INIT_FAILED;
                }
            } else atr_h[i] = INVALID_HANDLE;
            
            if(EnableOBV) {
                obv_h[i] = iOBV(Symbol(), tfs[i], VOLUME_TICK);
                if(obv_h[i] == INVALID_HANDLE) {
                    Print("OBV fail: ", tf_names[i]);
                    return INIT_FAILED;
                }
            } else obv_h[i] = INVALID_HANDLE;
        } else {
            atr_h[i] = INVALID_HANDLE;
            obv_h[i] = INVALID_HANDLE;
        }
    }
    
    dash_w = ind_w + 30 + (tf_cnt * (ColWidth + 5)) + 20;
    
    int ind_cnt = 0;
    if(EnableRSI) ind_cnt++;
    if(EnableEMA) ind_cnt++;
    if(EnableBB) ind_cnt++;
    if(EnableATR) ind_cnt++;
    if(EnableOBV) ind_cnt++;
    
    dash_h = head_h + (ind_cnt * (RowHeight + 5)) + trade_h + 60;
    
    trade.SetExpertMagicNumber(MagicNumber);
    
    CreateDashboard();
    
    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
    ObjectsDeleteAll(0, "Dashboard_");
    
    for(int i=0; i<8; i++) {
        if(atr_h[i] != INVALID_HANDLE)
            IndicatorRelease(atr_h[i]);
        if(obv_h[i] != INVALID_HANDLE)
            IndicatorRelease(obv_h[i]);
    }
    
    ChartRedraw();
}

int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[],
                const double &open[], const double &high[], const double &low[],
                const double &close[], const long &tick_volume[], const long &volume[],
                const int &spread[])
{
    if(TimeCurrent() - last_upd >= RefreshRate) {
        UpdateDashboard();
        last_upd = TimeCurrent();
    }
    
    return(rates_total);
}

void CreateDashboard()
{
    int x = 20;
    int y = 30;
    
    CreateRectangle("Dashboard_MainPanel", x, y, dash_w, dash_h, PanelColor, true);
    CreateRectangle("Dashboard_Border", x-2, y-2, dash_w+4, dash_h+4, BorderColor, false);
    
    CreateHeaderSection(x, y);
    CreateTimeframeHeaders(x, y + head_h - 25);
    CreateIndicatorGrid(x, y + head_h + 5);
    CreateTradePanel(x, y + dash_h - trade_h - 10);
    
    ChartRedraw();
}

void CreateHeaderSection(int x, int y)
{
    CreateRectangle("Dashboard_HeaderBG", x+2, y+2, dash_w-4, head_h-4, HeaderColor, true);
    
    CreateLabel("Dashboard_Title", x+15, y+12, Symbol() + " Trading Dashboard V2.1", TextColor, FontSize+3, "Arial Bold");
    
    string spread = "Spread: " + IntegerToString(SymbolInfoInteger(Symbol(), SYMBOL_SPREAD)) + " pts";
    string equity = "Equity: $" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2);
    string balance = "Balance: $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2);
    
    CreateLabel("Dashboard_Spread", x+15, y+35, spread, TextColor, FontSize);
    CreateLabel("Dashboard_Equity", x+200, y+35, equity, TextColor, FontSize);
    CreateLabel("Dashboard_Balance", x+15, y+52, balance, TextColor, FontSize);
    
    CreateRectangle("Dashboard_AlertBG", x+15, y+70, dash_w-35, 22, clrLightBlue, true);
    CreateLabel("Dashboard_AlertText", x+25, y+77, "Initializing...", clrNavy, FontSize, "Arial");
}

void CreateTimeframeHeaders(int x, int y)
{
    int tf_c = 0;
    for(int j=0; j<8; j++) {
        if(!tf_on[j]) continue;
        
        int x_h = x + ind_w + 25 + (tf_c * (ColWidth + 5));
        CreateRectangle("Dashboard_TFHeader_" + IntegerToString(j), x_h, y, ColWidth, 20, clrLightGray, true);
        CreateLabel("Dashboard_TF_" + IntegerToString(j), x_h + (ColWidth/2 - 10), y+6, tf_names[j], TextColor, FontSize, "Arial Bold");
        tf_c++;
    }
}

void CreateIndicatorGrid(int x, int y_start)
{
    string inds[5] = {"RSI", "EMA", "BB", "ATR", "OBV"};
    bool ind_on[5] = {EnableRSI, EnableEMA, EnableBB, EnableATR, EnableOBV};
    
    int row = 0;
    for(int i=0; i<5; i++) {
        if(!ind_on[i]) continue;
        
        int y_pos = y_start + (row * (RowHeight + 5));
        CreateRectangle("Dashboard_RowBG_" + IntegerToString(i), x+5, y_pos-2, dash_w-15, RowHeight+4, clrWhiteSmoke, true);
        CreateLabel("Dashboard_Indicator_" + IntegerToString(i), x+15, y_pos + (RowHeight/2 - 6), inds[i], TextColor, FontSize+1, "Arial Bold");
        
        int tf_c = 0;
        for(int j=0; j<8; j++) {
            if(!tf_on[j]) continue;
            
            int x_cell = x + ind_w + 25 + (tf_c * (ColWidth + 5));
            CreateRectangle("Dashboard_SignalBorder_" + IntegerToString(i) + "_" + IntegerToString(j), 
                           x_cell-1, y_pos-1, ColWidth+2, RowHeight+2, BorderColor, true);
            CreateRectangle("Dashboard_Signal_" + IntegerToString(i) + "_" + IntegerToString(j), 
                           x_cell, y_pos, ColWidth, RowHeight, NeutralColor, true);
            CreateLabel("Dashboard_SignalText_" + IntegerToString(i) + "_" + IntegerToString(j), 
                       x_cell + (ColWidth/2 - 20), y_pos + (RowHeight/2 - 6), "NEUTRAL", clrWhite, FontSize, "Arial Bold");
            tf_c++;
        }
        row++;
    }
}

void CreateTradePanel(int x, int y)
{
    CreateRectangle("Dashboard_TradePanelBG", x+5, y, dash_w-15, trade_h, HeaderColor, true);
    CreateLabel("Dashboard_TradePanelTitle", x+15, y+8, "Trade Panel:", TextColor, FontSize+1, "Arial Bold");
    
    int btn_w = 70, btn_h = 25, btn_sp = 10;
    int start_x = x+20, btn_y = y+30;
    
    CreateButton("Dashboard_BuyButton", start_x, btn_y, btn_w, btn_h, "BUY", clrWhite, C'34,139,34');
    CreateButton("Dashboard_SellButton", start_x + btn_w + btn_sp, btn_y, btn_w, btn_h, "SELL", clrWhite, C'178,34,34');
    CreateButton("Dashboard_CloseAllButton", start_x + 2*(btn_w + btn_sp), btn_y, btn_w, btn_h, "CLOSE ALL", clrWhite, C'184,134,11');
    CreateButton("Dashboard_CloseOppButton", start_x + 3*(btn_w + btn_sp), btn_y, btn_w, btn_h, "CLOSE OPP", clrWhite, C'30,144,255');
    
    string lot = "Lot: " + DoubleToString(LotSize, 2);
    string rr = "R:R " + DoubleToString(RiskReward, 1) + ":1";
    string sl = "SL: " + IntegerToString(SL_Points) + " pts";
    
    CreateLabel("Dashboard_LotInfo", start_x + 4*(btn_w + btn_sp) + 20, btn_y, lot, TextColor, FontSize);
    CreateLabel("Dashboard_RRInfo", start_x + 4*(btn_w + btn_sp) + 20, btn_y+12, rr, TextColor, FontSize);
}

void UpdateDashboard()
{
    string spread = "Spread: " + IntegerToString(SymbolInfoInteger(Symbol(), SYMBOL_SPREAD)) + " pts";
    string equity = "Equity: $" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2);
    string balance = "Balance: $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2);
    
    ObjectSetString(0, "Dashboard_Spread", OBJPROP_TEXT, spread);
    ObjectSetString(0, "Dashboard_Equity", OBJPROP_TEXT, equity);
    ObjectSetString(0, "Dashboard_Balance", OBJPROP_TEXT, balance);
    
    UpdateAlertMessages();
    UpdateSignalGrid();
    ChartRedraw();
}

void UpdateAlertMessages()
{
    if(TimeCurrent() - last_alt >= AlertDelay) {
        ObjectSetString(0, "Dashboard_AlertText", OBJPROP_TEXT, alerts[alt_idx]);
        alt_idx = (alt_idx + 1) % ArraySize(alerts);
        last_alt = TimeCurrent();
    }
}

void UpdateSignalGrid()
{
    int buys = 0, sells = 0, total = 0;
    
    string inds[5] = {"RSI", "EMA", "BB", "ATR", "OBV"};
    bool ind_on[5] = {EnableRSI, EnableEMA, EnableBB, EnableATR, EnableOBV};
    
    int row = 0;
    for(int i=0; i<5; i++) {
        if(!ind_on[i]) continue;
        
        int tf_c = 0;
        for(int j=0; j<8; j++) {
            if(!tf_on[j]) continue;
            
            int sig = GetIndicatorSignal(i, tfs[j]);
            string txt = "NEUTRAL";
            color clr = NeutralColor;
            
            if(sig > 0) {
                txt = "BUY";
                clr = BuyColor;
                buys++;
            } else if(sig < 0) {
                txt = "SELL";
                clr = SellColor;
                sells++;
            }
            
            total++;
            
            ObjectSetInteger(0, "Dashboard_Signal_" + IntegerToString(i) + "_" + IntegerToString(j), 
                           OBJPROP_BGCOLOR, clr);
            ObjectSetString(0, "Dashboard_SignalText_" + IntegerToString(i) + "_" + IntegerToString(j), 
                          OBJPROP_TEXT, txt);
            tf_c++;
        }
        row++;
    }
    
    CheckSignalAlignment(buys, sells, total);
}

void CheckSignalAlignment(int buys, int sells, int total)
{
    if(total == 0) return;
    
    double buy_pct = (double)buys / total * 100;
    double sell_pct = (double)sells / total * 100;
    
    string txt = "";
    color clr = clrNavy;
    
    if(buy_pct >= 75) {
        txt = "STRONG BUY - " + DoubleToString(buy_pct, 0) + "% bullish";
        clr = BuyColor;
    } else if(sell_pct >= 75) {
        txt = "STRONG SELL - " + DoubleToString(sell_pct, 0) + "% bearish";
        clr = SellColor;
    } else if(buy_pct >= 60) {
        txt = "Bullish bias - " + DoubleToString(buy_pct, 0) + "% buy";
        clr = clrBlue;
    } else if(sell_pct >= 60) {
        txt = "Bearish bias - " + DoubleToString(sell_pct, 0) + "% sell";
        clr = clrOrange;
    }
    
    if(txt != "") {
        ObjectSetString(0, "Dashboard_AlertText", OBJPROP_TEXT, txt);
        ObjectSetInteger(0, "Dashboard_AlertText", OBJPROP_COLOR, clr);
        alt_idx = 4;
    }
}

int GetIndicatorSignal(int type, ENUM_TIMEFRAMES tf)
{
    switch(type) {
        case 0: return GetRSISignal(tf);
        case 1: return GetEMASignal(tf);
        case 2: return GetBBSignal(tf);
        case 3: return GetATRSignal(tf);
        case 4: return GetOBVSignal(tf);
        default: return 0;
    }
}

int GetRSISignal(ENUM_TIMEFRAMES tf)
{
    int h = iRSI(Symbol(), tf, RSI_Period, PRICE_CLOSE);
    if(h == INVALID_HANDLE) return 0;
    
    double rsi[];
    ArraySetAsSeries(rsi, true);
    if(CopyBuffer(h, 0, 0, 2, rsi) <= 0) return 0;
    
    if(rsi[0] < RSI_Oversold) return 1;
    if(rsi[0] > RSI_Overbought) return -1;
    return 0;
}

int GetEMASignal(ENUM_TIMEFRAMES tf)
{
    int fast_h = iMA(Symbol(), tf, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
    int slow_h = iMA(Symbol(), tf, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
    
    if(fast_h == INVALID_HANDLE || slow_h == INVALID_HANDLE) return 0;
    
    double fast[], slow[];
    ArraySetAsSeries(fast, true);
    ArraySetAsSeries(slow, true);
    
    if(CopyBuffer(fast_h, 0, 0, 3, fast) <= 0) return 0;
    if(CopyBuffer(slow_h, 0, 0, 3, slow) <= 0) return 0;
    
    if(fast[0] > slow[0] && fast[1] <= slow[1] && fast[2] <= slow[2]) return 1;
    if(fast[0] < slow[0] && fast[1] >= slow[1] && fast[2] >= slow[2]) return -1;
    
    return 0;
}

int GetBBSignal(ENUM_TIMEFRAMES tf)
{
    int h = iBands(Symbol(), tf, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
    if(h == INVALID_HANDLE) return 0;
    
    double upper[], lower[], middle[];
    ArraySetAsSeries(upper, true);
    ArraySetAsSeries(lower, true);
    ArraySetAsSeries(middle, true);
    
    if(CopyBuffer(h, 1, 0, 2, upper) <= 0) return 0;
    if(CopyBuffer(h, 2, 0, 2, lower) <= 0) return 0;
    if(CopyBuffer(h, 0, 0, 2, middle) <= 0) return 0;
    
    double close = iClose(Symbol(), tf, 0);
    double prev = iClose(Symbol(), tf, 1);
    
    if(prev <= lower[1] && close > lower[0]) return 1;
    if(prev >= upper[1] && close < upper[0]) return -1;
    
    return 0;
}

int GetATRSignal(ENUM_TIMEFRAMES tf)
{
    int idx = GetTimeframeIndex(tf);
    if(idx < 0 || atr_h[idx] == INVALID_HANDLE) return 0;
    
    double atr[];
    ArraySetAsSeries(atr, true);
    if(CopyBuffer(atr_h[idx], 0, 0, 3, atr) <= 0) return 0;
    
    double close = iClose(Symbol(), tf, 0);
    double prev = iClose(Symbol(), tf, 1);
    
    if(close > prev && atr[0] > atr[1]) return 1;
    if(close < prev && atr[0] > atr[1]) return -1;
    if(close > prev) return 1;
    if(close < prev) return -1;
    
    return 0;
}

int GetOBVSignal(ENUM_TIMEFRAMES tf)
{
    int idx = GetTimeframeIndex(tf);
    if(idx < 0 || obv_h[idx] == INVALID_HANDLE) return 0;
    
    double obv[];
    ArraySetAsSeries(obv, true);
    if(CopyBuffer(obv_h[idx], 0, 0, 2, obv) <= 0) return 0;
    
    if(obv[0] > obv[1]) return 1;
    if(obv[0] < obv[1]) return -1;
    
    return 0;
}

int GetTimeframeIndex(ENUM_TIMEFRAMES tf)
{
    for(int i=0; i<8; i++)
        if(tfs[i] == tf) return i;
    return -1;
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    if(id == CHARTEVENT_OBJECT_CLICK) {
        if(StringFind(sparam, "Dashboard_BuyButton") >= 0) {
            ExecuteBuyTrade();
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        } else if(StringFind(sparam, "Dashboard_SellButton") >= 0) {
            ExecuteSellTrade();
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        } else if(StringFind(sparam, "Dashboard_CloseAllButton") >= 0) {
            CloseAllTrades();
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        } else if(StringFind(sparam, "Dashboard_CloseOppButton") >= 0) {
            CloseOppositeTrades();
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        }
        
        ChartRedraw();
    } else if(id == CHARTEVENT_CHART_CHANGE) {
        ObjectsDeleteAll(0, "Dashboard_");
        CreateDashboard();
        UpdateDashboard();
    }
}

void ExecuteBuyTrade()
{
    if(AutoCloseOpposite) ClosePositions(POSITION_TYPE_SELL);
    
    double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double sl = ask - (SL_Points * _Point);
    double tp = ask + (SL_Points * RiskReward * _Point);
    
    if(trade.Buy(LotSize, Symbol(), ask, sl, tp, "Dashboard Buy"))
        Print("BUY: Lot=", LotSize, " SL=", sl, " TP=", tp);
    else
        Print("BUY failed: ", trade.ResultRetcode());
}

void ExecuteSellTrade()
{
    if(AutoCloseOpposite) ClosePositions(POSITION_TYPE_BUY);
    
    double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double sl = bid + (SL_Points * _Point);
    double tp = bid - (SL_Points * RiskReward * _Point);
    
    if(trade.Sell(LotSize, Symbol(), bid, sl, tp, "Dashboard Sell"))
        Print("SELL: Lot=", LotSize, " SL=", sl, " TP=", tp);
    else
        Print("SELL failed: ", trade.ResultRetcode());
}

void CloseAllTrades()
{
    ClosePositions(POSITION_TYPE_BUY);
    ClosePositions(POSITION_TYPE_SELL);
    Print("All closed");
}

void CloseOppositeTrades()
{
    int buys = 0, sells = 0;
    
    for(int i=PositionsTotal()-1; i>=0; i--) {
        if(PositionGetSymbol(i) == Symbol() && PositionGetInteger(POSITION_MAGIC) == MagicNumber) {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) buys++;
            else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) sells++;
        }
    }
    
    if(buys > sells)
        ClosePositions(POSITION_TYPE_SELL);
    else if(sells > buys)
        ClosePositions(POSITION_TYPE_BUY);
    
    Print("Opposite closed");
}

void ClosePositions(ENUM_POSITION_TYPE type)
{
    for(int i=PositionsTotal()-1; i>=0; i--) {
        if(PositionGetSymbol(i) == Symbol() && 
           PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
           PositionGetInteger(POSITION_TYPE) == type) {
            trade.PositionClose(PositionGetTicket(i));
        }
    }
}

void CreateRectangle(string name, int x, int y, int w, int h, color bg, bool fill)
{
    ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
    ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, name, OBJPROP_COLOR, BorderColor);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
    if(fill) ObjectSetInteger(0, name, OBJPROP_FILL, true);
}

void CreateLabel(string name, int x, int y, string txt, color clr, int sz, string font="Arial")
{
    ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, name, OBJPROP_TEXT, txt);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, sz);
    ObjectSetString(0, name, OBJPROP_FONT, font);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void CreateButton(string name, int x, int y, int w, int h, string txt, color txt_clr, color bg)
{
    ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
    ObjectSetString(0, name, OBJPROP_TEXT, txt);
    ObjectSetInteger(0, name, OBJPROP_COLOR, txt_clr);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
    ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, BorderColor);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize);
    ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
    ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, name, OBJPROP_STATE, false);
}
