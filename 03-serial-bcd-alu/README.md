# Serial BCD ALU

[![Language](https://img.shields.io/badge/Language-Verilog-8A2BE2?style=flat-square)](#)
[![Course](https://img.shields.io/badge/Course-ECE_310-blue?style=flat-square)](#)
[![Verification](https://img.shields.io/badge/Verification-Waveform_Simulation-green?style=flat-square)](#)

> A packet-based serial arithmetic unit that receives two four-digit BCD operands over a 1-bit input, performs parallel BCD addition or subtraction, and returns a five-digit BCD result over a serial output.

---

## Overview

This project implements a serial Binary-Coded Decimal (BCD) Arithmetic Logic Unit in Verilog. The design accepts an input packet containing an 8-bit synchronization header, one operation bit, and two 16-bit BCD operands. After detecting and decoding the packet, the ALU computes the result in parallel and shifts a framed result packet out one bit per clock cycle.

The design uses a **serial-in/parallel-out (SIPO)** input path, a parallel BCD arithmetic core, and a **parallel-in/serial-out (PISO)** result path. It was verified through waveform simulation for addition, subtraction, back-to-back input handling, and reset recovery. [Project Report](docs/Project3_Report.pdf)

---

## Packet Protocol

### Input Packet — 41 bits

```text
| 8-bit header | 1-bit operation | 16-bit operand A | 16-bit operand B |
|    8'h67     | 0 = add, 1 = sub |    4 BCD digits  |    4 BCD digits  |
```

Input data is received **MSB first** on the `din` serial input.

### Output Packet — 28 bits

```text
| 8-bit header | 20-bit result |
|    8'hA5     | 5 BCD digits  |
```

The result is transmitted **MSB first** on the `result` serial output.

---

## Architecture

```text
din
 │
 ▼
┌───────────────────────┐
│  41-bit SIPO Register │
│  + 8'h67 Detection    │
└───────────┬───────────┘
            │ operation, A, B
            ▼
┌───────────────────────┐
│ Parallel BCD ALU Core │
│  -  Add with +6 fixup  │
│  -  10's complement    │
│    subtraction        │
└───────────┬───────────┘
            │ 20-bit BCD result
            ▼
┌───────────────────────┐
│  28-bit PISO Register │
│  + 8'hA5 Output Frame │
└───────────┬───────────┘
            │
            ▼
         result
```

![Serial BCD ALU schematic](images/serial_bcd_alu_schematic.png)

---

## BCD Arithmetic

### Addition

The ALU processes one BCD digit at a time from least significant to most significant. When an intermediate digit sum exceeds decimal 9, the design adds a correction value of 6 to produce a legal BCD digit and propagate carry to the next digit.

### Subtraction

Subtraction uses **10's complement arithmetic**:

1. Convert each digit of operand B to its 9's complement.
2. Add 1 at the least-significant digit to form the 10's complement.
3. Add operand A using the same BCD addition hardware.
4. Discard the final carry; force the fifth output digit to zero.

---

## Verification

The waveform-based Verilog testbench exercises the design using framed serial packets and verifies the output packet format and BCD result.

| Test | Operation | Inputs | Expected Result | Purpose |
|---|---|---:|---:|---|
| 1 | Addition | 3627 + 1287 | 04914 | Basic BCD addition |
| 2 | Subtraction | 0637 − 0459 | 00178 | 10's complement subtraction |
| 3 | Continuous input | 9999 + 0001, then 5000 − 5000 | 10000, then 00000 | Back-to-back packets and carry-out |
| 4 | Reset recovery | Partial packet, reset, then 5555 + 4444 | 09999 | Reset during activity |

![Simulation waveform](sim/waveforms/serial_bcd_alu_waveform.png)

The design clears the input shift register after recognizing a valid packet. This prevents a header sequence appearing within operand data from retriggering detection and enables non-overlapping packet recognition.
