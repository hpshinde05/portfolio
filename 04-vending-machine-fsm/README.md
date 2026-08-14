# Vending Machine Controller — Behavioral & Structural Mealy FSM

[![Language](https://img.shields.io/badge/Language-Verilog-8A2BE2?style=flat-square)](#)
[![Architecture](https://img.shields.io/badge/Architecture-Mealy_FSM-blue?style=flat-square)](#)
[![Implementation](https://img.shields.io/badge/Implementation-7400--Series_TTL-green?style=flat-square)](#)

> A Mealy finite-state-machine controller for a water vending machine, implemented in both behavioral Verilog and structural gate-level Verilog modeled after 7400-series TTL ICs.

---

## Overview

This project implements a coin-operated water vending controller. The design tracks deposited credit, accepts a product-selection input, supports coin return, and produces dispense/change outputs according to the current state and input.

I implemented the controller twice:

1. **Behavioral Verilog** — state-transition and output logic expressed as an RTL Mealy FSM.
2. **Structural Verilog** — the same FSM reconstructed with models of 7400-series TTL gates and 7474 D flip-flops, matching the logic used in the physical breadboard implementation.

The original breadboard was disassembled after the lab, but this repository preserves the original RTL, structural implementation, behavioral/structural testbenches, generated VCD waveform files, and validation output.

---

## Interface

```verilog
input  [1:0] x;        // User input
input        init;     // Active-low asynchronous reset
input        clk;      // Clock
output       dispense; // Product dispense signal
output [1:0] change;   // Returned-credit encoding
output [1:0] q;        // Current FSM state
```

### Input Encoding

| `x` | Input |
|---:|---|
| `2'b00` | Select water |
| `2'b01` | Insert nickel |
| `2'b10` | Coin return |

---

## State Behavior

| Current State | Meaning | Input | Next State | Dispense | Change |
|---|---|---|---|---:|---:|
| `00` | No credit | Nickel | `01` | 0 | `00` |
| `01` | One nickel deposited | Nickel | `10` | 0 | `00` |
| `01` | One nickel deposited | Coin return | `00` | 0 | `01` |
| `10` | Fully credited | Select | `00` | 1 | `00` |
| `10` | Fully credited | Coin return | `00` | 0 | `10` |

Because this is a **Mealy FSM**, `dispense` and `change` depend on both the active state and the current input.

---

## Implementation

### Behavioral FSM

`rtl/lab3_behavioral.v` implements state storage with an active-low asynchronous reset and uses combinational logic for next-state and output generation.

### Structural TTL Design

`rtl/lab3_structural.v` recreates the same controller using modeled TTL ICs:

- `SN7404` — inverter
- `SN7408` — quad 2-input AND gate
- `SN7410` — triple 3-input NAND gate
- `SN7432` — quad 2-input OR gate
- `SN7474` — dual D flip-flop

The gate models are included in `rtl/ttl_chip_modules.v`.

---

## Verification

The repository includes original behavioral and structural testbenches plus VCD waveform captures.

### Example: Select From Fully Credited State

```text
Start:    q = 00
Nickel:   q = 01, dispense = 0, change = 00
Nickel:   q = 10, dispense = 0, change = 00
Select:   q = 00, dispense = 1, change = 00
```

### Example: Coin Return From Fully Credited State

```text
Start:       q = 00
Nickel:      q = 01
Nickel:      q = 10
Coin return: q = 00, dispense = 0, change = 10
```

The preserved validation output confirms the coin-return sequence from state `10`: `change=2'b10`, `dispense=0`, followed by a return to state `00`. [50]
