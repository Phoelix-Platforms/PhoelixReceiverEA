//+------------------------------------------------------------------+
//|                                              PhoelixReceiver.mq5 |
//|                                  Copyright 2026, Phoelix Platforms Ltd|
//|                                              https://phoelix.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Phoelix Platforms Ltd"
#property link      "https://phoelix.com"
#property version   "6.10"
#property strict

#include <Trade\Trade.mqh>

//--- Input Parameters (HARDCODED USER CREDENTIALS)
input string   InpBotToken         = "89xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxI2p"; // Telegram Bot Token
input string   InpChannelID        = "-100xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx001";                                 // Telegram Channel ID
input int      InpTimerSeconds     = 2;                                                // Telegram Poll Interval
input double   SlPaddingPips       = 3.0;                                              // Safety Buffer (Pips)

//--- Global Objects & Variables
CTrade         trade;
long           last_update_id    = 0;
datetime       ea_start_time;
const int      MAGIC_NUMBER      = 77711;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   ea_start_time = TimeCurrent();
   trade.SetExpertMagicNumber(MAGIC_NUMBER);
   
   EventSetTimer(InpTimerSeconds);
   Print("🚀 Phoelix Raw-Ride Engine Online. Pure execution mode armed with Method 1 SL Padding.");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   Print("🛑 Phoelix Master Copier Offline.");
}

//+------------------------------------------------------------------+
//| Timer event function                                             |
//+------------------------------------------------------------------+
void OnTimer()
{
   string url = "https://api.telegram.org/bot" + InpBotToken + "/getUpdates?offset=" + IntegerToString(last_update_id + 1);
   string headers = "";
   char post[], result[];
   string result_headers;
   
   ResetLastError();
   int res = WebRequest("GET", url, headers, 3000, post, result, result_headers);
   
   if(res == 200)
   {
      string json_response = CharArrayToString(result);
      ParseTelegramJSON(json_response);
   }
}

//+------------------------------------------------------------------+
//| Parse JSON string from Telegram to identify signals              |
//+------------------------------------------------------------------+
void ParseTelegramJSON(string json)
{
   int text_pos = 0;
   while((text_pos = StringFind(json, "\"text\":\"SIGNAL_", text_pos)) != -1)
   {
      int id_pos = StringFind(json, "\"update_id\":", text_pos - 300);
      if(id_pos != -1)
      {
         long current_id = StringToInteger(StringSubstr(json, id_pos + 12, 9));
         if(current_id > last_update_id) last_update_id = current_id;
      }

      int start_quote = StringFind(json, "\"", text_pos + 7);
      int end_quote = StringFind(json, "\"", start_quote + 1);
      string msg_text = StringSubstr(json, start_quote + 1, end_quote - start_quote - 1);
      
      ExecuteSignal(msg_text);
      text_pos = end_quote + 1;
   }
}

//+------------------------------------------------------------------+
//| Process Parsed Signal Rules Safely                               |
//+------------------------------------------------------------------+
void ExecuteSignal(string message)
{
   string segments[];
   int count = StringSplit(message, '|', segments);
   if(count < 3) return;
   
   string action    = StringTrim(segments[0]);
   string symbol    = StringTrim(segments[1]);
   string direction = StringTrim(segments[2]);
   
   string active_symbol = SymbolNormalize(symbol);

   if(!SymbolInfoInteger(active_symbol, SYMBOL_VISIBLE))
   {
      SymbolSelect(active_symbol, true);
   }

   // Handle Signal Entries
   if(action == "SIGNAL_ENTRY")
   {
      if(IsPositionOpen(active_symbol)) return; 
      
      double raw_sl = (count >= 5) ? StringToDouble(StringTrim(segments[4])) : 0.0;
      double parsed_lot = (count >= 6) ? StringToDouble(StringTrim(segments[5])) : 0.01;
      if(parsed_lot <= 0) parsed_lot = 0.01; 

      // --- METHOD 1: DYNAMIC SL PADDING CALCULATION SYSTEM ---
      double price_delta = 0.0;
      
      if(StringFind(active_symbol, "JPY") != -1)           price_delta = SlPaddingPips * 0.01; 
      else if(StringFind(active_symbol, "XAU") != -1 || active_symbol == "GOLD") price_delta = SlPaddingPips * 0.1; 
      else if(StringFind(active_symbol, "XAG") != -1 || active_symbol == "SILVER" || StringFind(active_symbol, "OIL") != -1) price_delta = SlPaddingPips * 0.01;
      else                                                 price_delta = SlPaddingPips * 0.0001; 

      double padded_sl = raw_sl;

      if(direction == "BUY")
      {
         if(raw_sl > 0.0) padded_sl = raw_sl - price_delta; // Push SL down for buys
         
         double price = SymbolInfoDouble(active_symbol, SYMBOL_ASK);
         trade.Buy(parsed_lot, active_symbol, price, padded_sl, 0, "Phoelix Raw-Sniper");
         Print("🎯 Remote TV Buy Executed: ", active_symbol, " Lots: ", parsed_lot, " | Raw SL: ", raw_sl, " | Padded SL: ", padded_sl);
      }
      else if(direction == "SELL")
      {
         if(raw_sl > 0.0) padded_sl = raw_sl + price_delta; // Push SL up for sells
         
         double price = SymbolInfoDouble(active_symbol, SYMBOL_BID);
         trade.Sell(parsed_lot, active_symbol, price, padded_sl, 0, "Phoelix Raw-Sniper");
         Print("🎯 Remote TV Sell Executed: ", active_symbol, " Lots: ", parsed_lot, " | Raw SL: ", raw_sl, " | Padded SL: ", padded_sl);
      }
   }
   
   // Handle Signal Exits (Gracefully skips if already hit SL via broker)
   if(action == "SIGNAL_EXIT")
   {
      ClosePositions(active_symbol, direction);
   }
}

//+------------------------------------------------------------------+
//| Check tracking positions matrix                                 |
//+------------------------------------------------------------------+
bool IsPositionOpen(string symbol)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == symbol && PositionGetInteger(POSITION_MAGIC) == MAGIC_NUMBER) return(true);
   }
   return(false);
}

//+------------------------------------------------------------------+
//| Target Close Positions                                           |
//+------------------------------------------------------------------+
void ClosePositions(string symbol, string direction)
{
   ENUM_POSITION_TYPE target_type = (direction == "LONG") ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   bool found = false;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == symbol && PositionGetInteger(POSITION_MAGIC) == MAGIC_NUMBER)
      {
         if(PositionGetInteger(POSITION_TYPE) == target_type) 
         {
            trade.PositionClose(PositionGetTicket(i));
            found = true;
         }
      }
   }
   
   if(!found)
   {
      Print("ℹ️ Phoelix Sync: Exit received for ", symbol, " (", direction, ") but no live positions were found. Guard skip passed successfully.");
   }
}

//+------------------------------------------------------------------+
//| Dynamic Broker Suffix Translation & Routing Matrix               |
//+------------------------------------------------------------------+
string SymbolNormalize(string raw_symbol)
{
   string cleaned = raw_symbol;
   StringToUpper(cleaned);
   
   if(cleaned == "GOLD" || cleaned == "XAUUSD")   return "XAUUSDm";
   if(cleaned == "SILVER" || cleaned == "XAGUSD") return "XAGUSDm";
   
   if(StringFind(cleaned, "USOIL") != -1 || StringFind(cleaned, "WTI") != -1 || StringFind(cleaned, "CRUDE") != -1) 
      return "USOILm";

   // Match standard Exness 'm' suffixes for regular Forex pairs
   if(StringLen(cleaned) == 6)
   {
      return cleaned + "m";
   }

   return cleaned;
}
