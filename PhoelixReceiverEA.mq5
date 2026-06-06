//+------------------------------------------------------------------+
//|                                              PhoelixReceiver.mq5 |
//|                                  Copyright 2026, Phoelix Platforms|
//|                                             https://phoelix.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Phoelix Platforms"
#property link      "https://phoelix.com"
#property version   "0.01"
#property strict

#include <Trade\Trade.mqh>

//--- Input Parameters (HARDCODED USER CREDENTIALS)
input string   InpBotToken         = ""; // Telegram Bot Token
input string   InpChannelID        = ""; // Telegram Channel ID
input int      InpTimerSeconds     = 2;                                                // Telegram Poll Interval

//--- Pure Risk Armour: Advanced 10-Pip Break-Even Shield Only
input bool     InpUseBreakEven     = true;                    // Protect trade at Break-Even
input int      InpBETriggerPips    = 10;                      // Lock entry at +10 pips profit
input int      InpBECushionPips    = 2;                       // Covers commissions & raw spread friction

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
   Print("🚀 Phoelix 10-Pip Shield Core Operational. Milestones Removed. Running Clean.");
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
   ManageSmartRiskProtections();

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
//| Parse JSON string from Telegram to identify signals             |
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

   if(action == "SIGNAL_ENTRY")
   {
      if(IsPositionOpen(active_symbol)) return; 
      
      double stop_loss = (count >= 5) ? StringToDouble(StringTrim(segments[4])) : 0.0;
      double parsed_lot = (count >= 6) ? StringToDouble(StringTrim(segments[5])) : 0.01;
      if(parsed_lot <= 0) parsed_lot = 0.01; 

      if(direction == "BUY")
      {
         double price = SymbolInfoDouble(active_symbol, SYMBOL_ASK);
         trade.Buy(parsed_lot, active_symbol, price, stop_loss, 0, "Phoelix Shield-Sniper");
         Print("🎯 Remote TV Buy Executed: ", active_symbol, " Lots: ", parsed_lot);
      }
      else if(direction == "SELL")
      {
         double price = SymbolInfoDouble(active_symbol, SYMBOL_BID);
         trade.Sell(parsed_lot, active_symbol, price, stop_loss, 0, "Phoelix Shield-Sniper");
         Print("🎯 Remote TV Sell Executed: ", active_symbol, " Lots: ", parsed_lot);
      }
   }
   
   if(action == "SIGNAL_EXIT")
   {
      ClosePositions(active_symbol, direction);
   }
}

//+------------------------------------------------------------------+
//| Isolated Break-Even Risk Protection Module                       |
//+------------------------------------------------------------------+
void ManageSmartRiskProtections()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) > 0)
      {
         string sym = PositionGetString(POSITION_SYMBOL);
         if(PositionGetInteger(POSITION_MAGIC) == MAGIC_NUMBER)
         {
            double current_sl   = PositionGetDouble(POSITION_SL);
            double open_price   = PositionGetDouble(POSITION_PRICE_OPEN);
            long pos_type       = PositionGetInteger(POSITION_TYPE);
            
            double point        = SymbolInfoDouble(sym, SYMBOL_POINT);
            double digits       = SymbolInfoInteger(sym, SYMBOL_DIGITS);
            double pip_factor   = (digits == 3 || digits == 5) ? point * 10 : point;
            
            double be_cushion_dist = InpBECushionPips * pip_factor;
            
            if(pos_type == POSITION_TYPE_BUY)
            {
               double bid = SymbolInfoDouble(sym, SYMBOL_BID);
               double current_profit_pips = (bid - open_price) / pip_factor;
               
               if(InpUseBreakEven && current_profit_pips >= InpBETriggerPips)
               {
                  double target_be = open_price + be_cushion_dist;
                  if(current_sl < open_price)
                  {
                     trade.PositionModify(PositionGetTicket(i), NormalizeDouble(target_be, (int)digits), PositionGetDouble(POSITION_TP));
                     Print("🛡️ Break-Even Protection Engaged for BUY on ", sym);
                  }
               }
            }
            else if(pos_type == POSITION_TYPE_SELL)
            {
               double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
               double current_profit_pips = (open_price - ask) / pip_factor;
               
               if(InpUseBreakEven && current_profit_pips >= InpBETriggerPips)
               {
                  double target_be = open_price - be_cushion_dist;
                  if(current_sl > open_price || current_sl == 0.0)
                  {
                     trade.PositionModify(PositionGetTicket(i), NormalizeDouble(target_be, (int)digits), PositionGetDouble(POSITION_TP));
                     Print("🛡️ Break-Even Protection Engaged for SELL on ", sym);
                  }
               }
            }
         }
      }
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
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == symbol && PositionGetInteger(POSITION_MAGIC) == MAGIC_NUMBER)
      {
         if(PositionGetInteger(POSITION_TYPE) == target_type) trade.PositionClose(PositionGetTicket(i));
      }
   }
}

//+------------------------------------------------------------------+
//| Dynamic Broker Suffix Translation & Routing Matrix               |
//+------------------------------------------------------------------+
string SymbolNormalize(string raw_symbol)
{
   string cleaned = raw_symbol;
   StringToUpper(cleaned);
   
   if(cleaned == "GOLD")   return "XAUUSD";
   if(cleaned == "SILVER") return "XAGUSD";
   
   // EXNESS SPECIFIC ROUTER: Map all TradingView variations of oil directly to Exness USOILm
   if(StringFind(cleaned, "USOIL") != -1 || StringFind(cleaned, "WTI") != -1 || StringFind(cleaned, "CRUDE") != -1) 
      return "USOILm";

   return cleaned;
}
