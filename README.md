# Phoelix: Algorithmic Trading Bridge

<p align="center">
  <img src="/assets/phoelix-Algo.png" alt="Phoelix Algo Img" width="auto" height="140" />
</p>

<p align="center">
  <strong>High-efficiency algorithmic trading pipeline cross-compiling TradingView signals into native execution routines on MetaTrader 5.</strong>
</p>

<p align="center">
  <a href="#-system-architecture"><img src="https://img.shields.io/badge/Architecture-Asynchronous%20Bridge-blueviolet?style=flat-square" alt="Architecture"></a>
  <a href="#-core-infrastructure-modules"><img src="https://img.shields.io/badge/Stack-PineScript%20%7C%20MQL5-007ACC?style=flat-square" alt="Stack"></a>
  <a href="#-devops--security-governance"><img src="https://img.shields.io/badge/Security-Gated%20Encapsulation-107C41?style=flat-square" alt="Security"></a>
</p>

---

## 📈 System Architecture Overview

The **Phoelix Sniper Engine** is a proprietary, low-latency cross-platform transaction network designed to track, isolate, and execute trade orders across high-volatility commodities and financial markets (specifically optimized for `XAUUSD`, `XAGUSD`, and `USOIL`).

The framework completely avoids latency overhead by eliminating intermediary commercial webhook-to-MT5 subscription apps. Instead, it utilizes a highly direct execution routing map:

[ TradingView Engine ] <br>
│ (Pine Script v6 Algorithm running on a 15-Minute Cycle) <br>
▼ <br>
[ Telegram API Pipeline ]<br>
│ (Asynchronous, secure string payloads passing structure state parameters)<br>
▼<br>
[ PhoelixReceiver (EA) ]<br>
│ (Native MQL5 WebRequest long-polling loop inside MetaTrader 5 terminal)<br>
▼<br>
[ Broker Execution Layer ] (Bespoke broker suffix translation matrix -> e.g., Exness USOILm)<br>

---

## 🗂️ Core Infrastructure Modules

This repository houses the native MetaTrader 5 Expert Advisor transaction processor (PhoelixReceiverEA.mq5), designed for continuous background data processing and order execution:

### 1. The Alert Generator (`Phoelix_Sniper_Bot.pine`)
A high-precision technical analysis matrix running natively on TradingView charts using Pine Script v6.
* **Premium Intraday Softwares:** One of our finest algorithmic trading engines, explicitly optimized for rapid intraday trading setups on the 15-minute timeframe.
* **Dual-Filter Confirmation:** Merges an aggressive tracking engine ("Sniper Line") with a long-term direction matrix ("Anchor Line") to guarantee executions only occur with macro-trend alignment.
* **Algorithmic Lot-Sizing Engine:** Automatically routes asset-specific volumes (`tv_gold_lot`, `tv_usoil_lot`) based on localized risk settings.
* **New York Session Cutoff Guard:** Forces hard state exits exactly at the 15:45 NY session boundary to protect open capital from toxic market-close spreads and swap fees.

> 🔒 **Intellectual Property Notice:** The Pine Script code and strategy logic powering this generator represent proprietary Phoelix core intellectual property. **The codebase is strictly closed-source as of now**

### 2. The Transaction Processor (`PhoelixReceiver.mq5`)
A native MetaTrader 5 Expert Advisor (EA) designed for continuous background data processing.
* **String Parser Matrix:** Scans the incoming Telegram payload buffers, instantly separating operational commands (`SIGNAL_ENTRY`, `SIGNAL_EXIT`), direction configurations, and precise lot requirements.
* **Pure Risk Armour:** Activates an advanced, continuous Break-Even Protection loop. The moment a position ticks to **+10 Pips** of net profit, the stop-loss is dynamically updated to lock entry plus a cushion metric to absorb raw spread friction and commission decay.
* **Dynamic Suffix Translation:** Contains a custom routing matrix to normalize varied string values (like converting `GOLD` -> `XAUUSD`, or routing crude oil naming conventions directly to the Exness platform counterpart: `USOILm`).

---

## ⚙️ Setup & Operational Integrity

To maintain high security and proper operational health when loading the systems onto your trading terminal or VPS:

### MetaTrader 5 Environment Configurations
1. Open MT5 Terminal, navigate to **Tools > Options > Expert Advisors**.
2. Check the box to **"Allow WebRequest for listed URL:"**.
3. Add the exact secure Telegram endpoint address: 
```text
   [https://api.telegram.org](https://api.telegram.org)
