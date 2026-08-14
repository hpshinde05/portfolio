# Harsh Shinde — Portfolio

[![Live Portfolio](https://img.shields.io/badge/Live_Site-hpshindeportfolio.framer.website-blue?style=flat-square)](https://hpshindeportfolio.framer.website/)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Harsh_Shinde-0077B5?style=flat-square&logo=linkedin)](https://linkedin.com/in/harsh-shinde-059396371)
[![Email](https://img.shields.io/badge/Email-Contact_Me-red?style=flat-square&logo=gmail)](mailto:hpshinde05@gmail.com)

Welcome! This repository contains source code, RTL architectures, testbenches, simulation waveforms, and validation reports for my hardware and embedded engineering projects.

---

## 🛠 Tech Stack & Core Competencies

- **Hardware & RTL:** Verilog HDL, FSM Design, Pipelining, Fixed-Point Arithmetic (Q16.16), Datapath Architecture
- **Verification & Lab Tools:** RTL Simulation, Waveform Debugging, Logic Analyzers (AD3), Digital Oscilloscopes, Multimeters
- **Embedded Systems & Firmware:** C/C++, MSP430FR2355, ESP32, UART (Interrupt-Driven), ADC, PWM Motor Drivers
- **EDA & Platforms:** Xilinx Vivado, CCStudio, Linux/Ubuntu, Git

---

## 📂 Featured Projects

### 1. [Raytracing Math Accelerator (GF180MCU Tape-Out)](./01-raytracing-math-accelerator)
- **Role:** Team Lead & Digital Design Engineer
- **Summary:** Managed a 5-person team building a ray-sphere intersection hardware accelerator integrated with a shared RISC-V SoC. 
- **Key Contributions:** Designed the 3-stage pipelined multiplier, dot product, and $b^2-ac$ discriminant modules in Q16.16 fixed-point Verilog. Resolved signed-extension bugs and async reset race conditions; fabricated on the GF180MCU open-source PDK and verified on physical PCBs.

### 2. [Line-Following Autonomous Car](./02-line-following-autonomous-car)
- **Role:** Embedded Firmware Engineer (ECE 306)
- **Summary:** Built an autonomous vehicle driven by a TI MSP430FR2355 and an ESP32 wireless interface.
- **Key Contributions:** Wrote modular, bare-metal C firmware. Configured interrupt-driven UART receive logic, calibrated ADC thresholding on IR sensor arrays, and diagnosed baud-rate clock drift using an oscilloscope.

### 3. [Serial BCD ALU](./03-serial-bcd-alu)
- **Role:** RTL Designer (ECE 310)
- **Summary:** Designed a packetized serial arithmetic unit processing operations over a 1-bit input line without back-to-back stalls.
- **Key Highlights:** Implemented a 41-bit shift register detecting the `8'h67` sync header, running parallel BCD addition and 10's complement subtraction, and shifting out a 28-bit frame with an `8'hA5` header.
- **Included Artifacts:** Verilog RTL, testbench source, simulation waveform captures, and formal project report.

### 4. [Vending Machine Controller (Mealy FSM)](./04-vending-machine-fsm)
- **Role:** Digital Logic Designer (PV&V Lab)
- **Summary:** Designed, simulated, and physically built a coin-input Mealy FSM on a breadboard using 7400-series discrete TTL logic ICs.
- **Key Highlights:** Formulated a structured verification test plan, acquired timing waveforms using an Analog Discovery 3 (AD3) logic analyzer, and validated transient response against specification.

### 5. [(A-B)+(C-D) Arithmetic Datapath](./05-arithmetic-datapath)
- **Role:** RTL Designer (ECE 310)
- **Summary:** Structural Verilog datapath controlled by an FSM sequencer coordinating dual subtractions and single addition across a shared ALU.
- **Included Artifacts:** Structural Verilog files, testbench harness, waveform verification plots, and design verification report.

---

## 📬 Contact & Links

- **Email:** [hpshinde05@gmail.com](mailto:hpshinde05@gmail.com)
- **Portfolio:** [hpshindeportfolio.framer.website](https://hpshindeportfolio.framer.website/)
- **LinkedIn:** [linkedin.com/in/harsh-shinde-059396371](https://linkedin.com/in/harsh-shinde-059396371)
