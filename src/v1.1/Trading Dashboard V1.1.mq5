//+------------------------------------------------------------------+
//|                                            Trading Dashboard.mq5 |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Trading Systems"
#property link      "https://www.mql5.com"
#property version   "1.1"
#property indicator_chart_window
#property indicator_plots 0

//--- Input parameters
input group "=== Indicator Settings ==="
input bool     EnableRSI = true;                    // Enable RSI signals
input bool     EnableMACD = true;                   // Enable MACD signals  
input bool     EnableEMA = true;                    // Enable EMA crossover
input bool     EnableBB = true;                     // Enable Bollinger Bands
input bool     EnableOBV = true;                    // Enable OBV signals

input group "=== Timeframe Settings ==="
input bool     UseM15 = true;                       // Use M15 timeframe
input bool     UseH1 = true;                        // Use H1 timeframe
input bool     UseH4 = true;                        // Use H4 timeframe
input bool     UseD1 = true;                        // Use Daily timeframe

input group "=== Visual Settings ==="
input color    BuyColor = clrLimeGreen;              // Buy signal color
input color    SellColor = clrRed;                   // Sell signal color
input color    NeutralColor = clrGray;               // Neutral signal color
input color    PanelColor = clrWhite;                // Panel background color
input color    HeaderColor = C'240,240,240';         // Header background color
input color    TextColor = clrBlack;                 // Text color
input color    BorderColor = clrSilver;              // Border color
input int      FontSize = 9;                         // Font size

input group "=== Alert Settings ==="
input bool     EnableSoundAlerts = true;            // Enable sound alerts
input bool     EnablePopupAlerts = true;            // Enable popup alerts
input string   AlertSoundFile = "alert.wav";        // Alert sound file

input group "=== System Settings ==="
input int      RefreshRate = 3;                     // Refresh rate in seconds

//--- Global variables
int dashboard_width = 400;
int dashboard_height = 350;
int cell_width = 75;
int cell_height = 28;
int header_height = 85;
int indicator_name_width = 60;
datetime last_update = 0;
int rsi_handle, macd_handle, ema_fast_handle, ema_slow_handle, bb_handle, obv_handle;
ENUM_TIMEFRAMES timeframes[4] = {PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1};
string tf_names[4] = {"M15", "H1", "H4", "D1"};
bool tf_enabled[4];
int enabled_tf_count = 0;

int OnInit()
{
    // Set up timeframe enablement array and count enabled timeframes
    tf_enabled[0] = UseM15;
    tf_enabled[1] = UseH1;
    tf_enabled[2] = UseH4;
    tf_enabled[3] = UseD1;
    
    for(int i = 0; i < 4; i++)
        if(tf_enabled[i]) enabled_tf_count++;
    
    // Calculate proper dashboard width based on enabled timeframes
    dashboard_width = indicator_name_width + 20 + (enabled_tf_count * (cell_width + 8)) + 20;
    
    // Count enabled indicators for height calculation
    int enabled_indicators = 0;
    if(EnableRSI) enabled_indicators++;
    if(EnableMACD) enabled_indicators++;
    if(EnableEMA) enabled_indicators++;
    if(EnableBB) enabled_indicators++;
    if(EnableOBV) enabled_indicators++;
    
    dashboard_height = header_height + (enabled_indicators * (cell_height + 5)) + 60;
    
    // Initialize indicator handles
    InitializeIndicators();
    
    // Create dashboard objects
    CreateDashboard();
    
    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
    // Remove all dashboard objects
    ObjectsDeleteAll(0, "Dashboard_");
    ChartRedraw();
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    // Update dashboard based on refresh rate
    if(TimeCurrent() - last_update >= RefreshRate)
    {
        UpdateDashboard();
        last_update = TimeCurrent();
    }
    
    return(rates_total);
}

void InitializeIndicators()
{
    rsi_handle = iRSI(Symbol(), PERIOD_CURRENT, 14, PRICE_CLOSE);
    macd_handle = iMACD(Symbol(), PERIOD_CURRENT, 12, 26, 9, PRICE_CLOSE);
    ema_fast_handle = iMA(Symbol(), PERIOD_CURRENT, 20, 0, MODE_EMA, PRICE_CLOSE);
    ema_slow_handle = iMA(Symbol(), PERIOD_CURRENT, 50, 0, MODE_EMA, PRICE_CLOSE);
    bb_handle = iBands(Symbol(), PERIOD_CURRENT, 20, 0, 2.0, PRICE_CLOSE);
    obv_handle = iOBV(Symbol(), PERIOD_CURRENT, VOLUME_TICK);
}

void CreateDashboard()
{
    int x_pos = 20;
    int y_pos = 30;
    
    // Main panel background with border
    CreateRectangle("Dashboard_MainPanel", x_pos, y_pos, dashboard_width, dashboard_height, PanelColor, true);
    CreateRectangle("Dashboard_Border", x_pos - 2, y_pos - 2, dashboard_width + 4, dashboard_height + 4, BorderColor, false);
    
    // Header background
    CreateRectangle("Dashboard_HeaderBG", x_pos + 2, y_pos + 2, dashboard_width - 4, header_height - 4, HeaderColor, true);
    
    // Title
    CreateLabel("Dashboard_Title", x_pos + 15, y_pos + 12, Symbol() + " Trading Dashboard", TextColor, FontSize + 3, "Arial Bold");
    
    // Account info with proper spacing
    string spread_info = "Spread: " + IntegerToString(SymbolInfoInteger(Symbol(), SYMBOL_SPREAD)) + " pts";
    string atr_info = "ATR: " + DoubleToString(GetATR(), _Digits);
    string equity_info = "Equity: $" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2);
    
    CreateLabel("Dashboard_Spread", x_pos + 15, y_pos + 35, spread_info, TextColor, FontSize);
    CreateLabel("Dashboard_ATR", x_pos + 15, y_pos + 52, atr_info, TextColor, FontSize);
    CreateLabel("Dashboard_Equity", x_pos + 200, y_pos + 35, equity_info, TextColor, FontSize);
    
    // Timeframe headers with better positioning
    CreateTimeframeHeaders(x_pos, y_pos + header_height - 5);
    
    // Create indicator rows
    CreateIndicatorRows(x_pos, y_pos + header_height + 20);
    
    // Alert section with background
    int alert_y = y_pos + dashboard_height - 50;
    CreateRectangle("Dashboard_AlertBG", x_pos + 2, alert_y, dashboard_width - 4, 45, HeaderColor, true);
    CreateLabel("Dashboard_AlertTitle", x_pos + 15, alert_y + 8, "Market Alerts:", TextColor, FontSize, "Arial Bold");
    CreateLabel("Dashboard_AlertText", x_pos + 15, alert_y + 25, "Scanning markets...", clrBlue, FontSize);
    
    ChartRedraw();
}

void CreateTimeframeHeaders(int x_start, int y_pos)
{
    int tf_count = 0;
    for(int j = 0; j < 4; j++)
    {
        if(!tf_enabled[j]) continue;
        
        int x_pos = x_start + indicator_name_width + 15 + (tf_count * (cell_width + 8));
        
        // Header background
        CreateRectangle("Dashboard_TFHeader_" + IntegerToString(j), x_pos, y_pos, cell_width, 20, clrLightGray, true);
        
        // Header text perfectly centered
        CreateLabel("Dashboard_TF_" + IntegerToString(j), x_pos + 25, y_pos + 6, tf_names[j], TextColor, FontSize, "Arial Bold");
        
        tf_count++;
    }
}

void CreateIndicatorRows(int x_start, int y_start)
{
    string indicators[5] = {"RSI", "MACD", "EMA", "BB", "OBV"};
    bool indicator_enabled[5] = {EnableRSI, EnableMACD, EnableEMA, EnableBB, EnableOBV};
    
    int row = 0;
    for(int i = 0; i < 5; i++)
    {
        if(!indicator_enabled[i]) continue;
        
        int y_pos = y_start + (row * (cell_height + 5));
        
        // Row background for better separation
        CreateRectangle("Dashboard_RowBG_" + IntegerToString(i), x_start + 5, y_pos - 2, dashboard_width - 10, cell_height + 4, clrWhiteSmoke, true);
        
        // Indicator name with better alignment
        CreateLabel("Dashboard_Indicator_" + IntegerToString(i), x_start + 15, y_pos + 8, indicators[i], TextColor, FontSize + 1, "Arial Bold");
        
        // Timeframe signal boxes
        int tf_count = 0;
        for(int j = 0; j < 4; j++)
        {
            if(!tf_enabled[j]) continue;
            
            int x_pos = x_start + indicator_name_width + 15 + (tf_count * (cell_width + 8));
            
            // Signal box with border
            CreateRectangle("Dashboard_SignalBorder_" + IntegerToString(i) + "_" + IntegerToString(j), 
                          x_pos - 1, y_pos - 1, cell_width + 2, cell_height + 2, BorderColor, true);
            CreateRectangle("Dashboard_Signal_" + IntegerToString(i) + "_" + IntegerToString(j), 
                          x_pos, y_pos, cell_width, cell_height, NeutralColor, true);
            
            // Signal text perfectly centered
            CreateLabel("Dashboard_SignalText_" + IntegerToString(i) + "_" + IntegerToString(j), 
                       x_pos + 10, y_pos + 10, "NEUTRAL", clrWhite, FontSize, "Arial Bold");
            
            tf_count++;
        }
        row++;
    }
}

void UpdateDashboard()
{
    // Update account info
    string spread_info = "Spread: " + IntegerToString(SymbolInfoInteger(Symbol(), SYMBOL_SPREAD)) + " pts";
    string atr_info = "ATR: " + DoubleToString(GetATR(), _Digits);
    string equity_info = "Equity: $" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2);
    
    ObjectSetString(0, "Dashboard_Spread", OBJPROP_TEXT, spread_info);
    ObjectSetString(0, "Dashboard_ATR", OBJPROP_TEXT, atr_info);
    ObjectSetString(0, "Dashboard_Equity", OBJPROP_TEXT, equity_info);
    
    // Track signal alignment for alerts
    int buy_signals = 0, sell_signals = 0, total_signals = 0;
    
    // Update indicator signals
    string indicators[5] = {"RSI", "MACD", "EMA", "BB", "OBV"};
    bool indicator_enabled[5] = {EnableRSI, EnableMACD, EnableEMA, EnableBB, EnableOBV};
    
    int row = 0;
    for(int i = 0; i < 5; i++)
    {
        if(!indicator_enabled[i]) continue;
        
        int tf_count = 0;
        for(int j = 0; j < 4; j++)
        {
            if(!tf_enabled[j]) continue;
            
            int signal = GetIndicatorSignal(i, timeframes[j]);
            string signal_text = "NEUTRAL";
            color signal_color = NeutralColor;
            
            if(signal > 0)
            {
                signal_text = "BUY";
                signal_color = BuyColor;
                buy_signals++;
            }
            else if(signal < 0)
            {
                signal_text = "SELL";
                signal_color = SellColor;
                sell_signals++;
            }
            
            total_signals++;
            
            // Update signal box
            ObjectSetInteger(0, "Dashboard_Signal_" + IntegerToString(i) + "_" + IntegerToString(j), 
                           OBJPROP_BGCOLOR, signal_color);
            ObjectSetString(0, "Dashboard_SignalText_" + IntegerToString(i) + "_" + IntegerToString(j), 
                          OBJPROP_TEXT, signal_text);
            
            tf_count++;
        }
        row++;
    }
    
    // Update alerts section
    UpdateAlerts(buy_signals, sell_signals, total_signals);
    
    ChartRedraw();
}

int GetIndicatorSignal(int indicator_type, ENUM_TIMEFRAMES tf)
{
    switch(indicator_type)
    {
        case 0: return GetRSISignal(tf);
        case 1: return GetMACDSignal(tf);
        case 2: return GetEMASignal(tf);
        case 3: return GetBBSignal(tf);
        case 4: return GetOBVSignal(tf);
        default: return 0;
    }
}

int GetRSISignal(ENUM_TIMEFRAMES tf)
{
    int handle = iRSI(Symbol(), tf, 14, PRICE_CLOSE);
    if(handle == INVALID_HANDLE) return 0;
    
    double rsi[];
    ArraySetAsSeries(rsi, true);
    
    if(CopyBuffer(handle, 0, 0, 2, rsi) <= 0) return 0;
    
    if(rsi[0] < 30) return 1;      // Oversold - Buy
    if(rsi[0] > 70) return -1;     // Overbought - Sell
    return 0;                      // Neutral
}

int GetMACDSignal(ENUM_TIMEFRAMES tf)
{
    int handle = iMACD(Symbol(), tf, 12, 26, 9, PRICE_CLOSE);
    if(handle == INVALID_HANDLE) return 0;
    
    double main[], signal[];
    ArraySetAsSeries(main, true);
    ArraySetAsSeries(signal, true);
    
    if(CopyBuffer(handle, 0, 0, 2, main) <= 0) return 0;
    if(CopyBuffer(handle, 1, 0, 2, signal) <= 0) return 0;
    
    if(main[0] > signal[0] && main[1] <= signal[1]) return 1;   // Bullish crossover
    if(main[0] < signal[0] && main[1] >= signal[1]) return -1;  // Bearish crossover
    return 0;
}

int GetEMASignal(ENUM_TIMEFRAMES tf)
{
    int fast_handle = iMA(Symbol(), tf, 20, 0, MODE_EMA, PRICE_CLOSE);
    int slow_handle = iMA(Symbol(), tf, 50, 0, MODE_EMA, PRICE_CLOSE);
    
    if(fast_handle == INVALID_HANDLE || slow_handle == INVALID_HANDLE) return 0;
    
    double fast[], slow[];
    ArraySetAsSeries(fast, true);
    ArraySetAsSeries(slow, true);
    
    if(CopyBuffer(fast_handle, 0, 0, 2, fast) <= 0) return 0;
    if(CopyBuffer(slow_handle, 0, 0, 2, slow) <= 0) return 0;
    
    if(fast[0] > slow[0] && fast[1] <= slow[1]) return 1;   // Golden cross
    if(fast[0] < slow[0] && fast[1] >= slow[1]) return -1;  // Death cross
    return 0;
}

int GetBBSignal(ENUM_TIMEFRAMES tf)
{
    int handle = iBands(Symbol(), tf, 20, 0, 2.0, PRICE_CLOSE);
    if(handle == INVALID_HANDLE) return 0;
    
    double upper[], lower[];
    ArraySetAsSeries(upper, true);
    ArraySetAsSeries(lower, true);
    
    if(CopyBuffer(handle, 1, 0, 1, upper) <= 0) return 0;
    if(CopyBuffer(handle, 2, 0, 1, lower) <= 0) return 0;
    
    double close_price = iClose(Symbol(), tf, 0);
    
    if(close_price <= lower[0]) return 1;    // Price at lower band - Buy
    if(close_price >= upper[0]) return -1;   // Price at upper band - Sell
    return 0;
}

int GetOBVSignal(ENUM_TIMEFRAMES tf)
{
    int handle = iOBV(Symbol(), tf, VOLUME_TICK);
    if(handle == INVALID_HANDLE) return 0;
    
    double obv[];
    ArraySetAsSeries(obv, true);
    
    if(CopyBuffer(handle, 0, 0, 3, obv) <= 0) return 0;
    
    // Simple OBV trend analysis
    if(obv[0] > obv[1] && obv[1] > obv[2]) return 1;   // Rising trend
    if(obv[0] < obv[1] && obv[1] < obv[2]) return -1;  // Falling trend
    return 0;
}

void UpdateAlerts(int buy_signals, int sell_signals, int total_signals)
{
    string alert_text = "No significant alignment detected";
    color alert_color = clrGray;
    bool trigger_alert = false;
    
    if(total_signals == 0) return;
    
    double buy_percentage = (double)buy_signals / total_signals * 100;
    double sell_percentage = (double)sell_signals / total_signals * 100;
    
    if(buy_percentage >= 70)
    {
        alert_text = "STRONG BUY SIGNAL - " + DoubleToString(buy_percentage, 0) + "% indicators bullish";
        alert_color = BuyColor;
        trigger_alert = true;
    }
    else if(sell_percentage >= 70)
    {
        alert_text = "STRONG SELL SIGNAL - " + DoubleToString(sell_percentage, 0) + "% indicators bearish";
        alert_color = SellColor;
        trigger_alert = true;
    }
    else if(buy_percentage >= 50)
    {
        alert_text = "Moderate bullish bias - " + DoubleToString(buy_percentage, 0) + "% buy signals";
        alert_color = clrBlue;
    }
    else if(sell_percentage >= 50)
    {
        alert_text = "Moderate bearish bias - " + DoubleToString(sell_percentage, 0) + "% sell signals";
        alert_color = clrOrange;
    }
    
    ObjectSetString(0, "Dashboard_AlertText", OBJPROP_TEXT, alert_text);
    ObjectSetInteger(0, "Dashboard_AlertText", OBJPROP_COLOR, alert_color);
    
    // Trigger alerts if conditions met
    if(trigger_alert)
    {
        static datetime last_alert = 0;
        if(TimeCurrent() - last_alert > 300) // Prevent spam, 5 min cooldown
        {
            if(EnableSoundAlerts) PlaySound(AlertSoundFile);
            if(EnablePopupAlerts) Alert(Symbol() + ": " + alert_text);
            last_alert = TimeCurrent();
        }
    }
}

double GetATR()
{
    int atr_handle = iATR(Symbol(), PERIOD_CURRENT, 14);
    if(atr_handle == INVALID_HANDLE) return 0.0;
    
    double atr[];
    ArraySetAsSeries(atr, true);
    
    if(CopyBuffer(atr_handle, 0, 0, 1, atr) <= 0) return 0.0;
    return atr[0];
}

void CreateRectangle(string name, int x, int y, int width, int height, color bg_color, bool filled)
{
    ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg_color);
    ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, name, OBJPROP_COLOR, BorderColor);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
    if(filled) ObjectSetInteger(0, name, OBJPROP_FILL, true);
}

void CreateLabel(string name, int x, int y, string text, color text_color, int font_size, string font_name = "Arial")
{
    ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, text_color);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
    ObjectSetString(0, name, OBJPROP_FONT, font_name);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    if(id == CHARTEVENT_CHART_CHANGE)
    {
        // Redraw dashboard on chart resize
        ObjectsDeleteAll(0, "Dashboard_");
        CreateDashboard();
        UpdateDashboard();
    }
}
