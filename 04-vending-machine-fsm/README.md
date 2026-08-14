# Vending Machine Controller — Mealy FSM

[![Language](https://img.shields.io/badge/Language-Verilog-8A2BE2?style=flat-square)](#)
[![Project](https://img.shields.io/badge/Project-PV%26V_Lab-blue?style=flat-square)](#)
[![Hardware](https://img.shields.io/badge/Hardware-7400--Series_TTL-green?style=flat-square)](#)

> A coin-input vending machine controller designed as a Mealy finite-state machine, verified in Verilog simulation, and implemented on a breadboard using 7400-series TTL logic.

---

## Overview

This project implements a vending machine controller that tracks deposited coins, transitions between credit states, and asserts a dispense output when the required price is reached.

I designed the Mealy FSM in Verilog, wrote a structured validation plan covering normal transitions and edge cases, and compared simulation behavior against expected outputs. I then translated the structural logic into a physical breadboard build using 7400-series TTL ICs and validated timing behavior using an Analog Discovery 3 logic analyzer.

---

## Design Approach

The controller is a **Mealy FSM**, meaning the dispense output depends on the current credit state and the incoming coin value.

```text
Coin Input
    │
    ▼
┌─────────────────────────┐
│  Mealy FSM Controller   │
│  -  Track credit state   │
│  -  Decode coin input    │
│  -  Assert dispense      │
└───────────┬─────────────┘
            │
            ▼
     dispense / change
```

> Update the state names, accepted coin types, price, and change behavior here once you add the actual RTL/specification. Avoid publishing assumptions that do not match your lab implementation.

---

## Verification & Validation

Verification was performed at two levels:

- **RTL simulation:** Checked expected state transitions, dispense behavior, reset behavior, and edge cases using a structured test plan.
- **Physical implementation:** Built the logic using 7400-series TTL ICs on a breadboard.
- **Lab instrumentation:** Used an Analog Discovery 3 (AD3) logic analyzer to capture I/O timing, verify signal integrity, and debug faults with waveform analysis.

| Test Category | What Was Checked |
|---|---|
| Reset | FSM returns to its initial credit state |
| Valid coin sequences | State progresses correctly toward dispense |
| Dispense boundary | Output asserts exactly when required credit is reached |
| Extra / invalid inputs | Controller maintains expected state or follows specified behavior |
| Hardware timing | Breadboard I/O behavior matches expected state transitions |

