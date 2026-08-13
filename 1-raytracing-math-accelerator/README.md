# Raytracing Math Accelerator — Full-Chip Tape-Out (GF180MCU)

> **Hardware ray-sphere intersection accelerator co-integrated with a shared RISC-V SoC, taken from initial whiteboard microarchitecture through synthesis, DRC/LVS closure, and physical GDSII tape-out.**

---

## 📌 Executive Summary

- **Role:** Team Lead & Digital Design Engineer (The Silicon Den, NC State University)
- **Timeline:** Jan 2026 – May 2026
- **Target Silicon:** GlobalFoundries 180nm MCU (GF180MCU) Open PDK
- **Outcome:** Successfully taped out in June 2026.

In raytracing workloads, computing ray-sphere intersection is a primary computational bottleneck. This project offloads ray-sphere equation calculations from the main RISC-V CPU into a dedicated, pipelined fixed-point coprocessor datapath.

---

## 🧮 Mathematical & Architectural Specification

A ray in 3D space is parameterized as:
$$\mathbf{P}(t) = \mathbf{O} + t\mathbf{D}$$

Intersecting with a sphere centered at $\mathbf{C}$ with radius $r$:
$$|\mathbf{P}(t) - \mathbf{C}|^2 = r^2$$

Expanding into quadratic form $a t^2 + b t + c = 0$ (with normalized ray direction $|\mathbf{D}| = 1 \implies a = 1$):
- **Half-$b$ calculation:** $b' = \mathbf{D} \cdot (\mathbf{O} - \mathbf{C})$
- **$c$ calculation:** $c = (\mathbf{O} - \mathbf{C}) \cdot (\mathbf{O} - \mathbf{C}) - r^2$
- **Discriminant:** $\Delta = (b')^2 - c$

If $\Delta < 0$, the ray misses the sphere; if $\Delta \ge 0$, the ray hits, and the nearest intersection distance is $t = -b' - \sqrt{\Delta}$.

```text
               +-------------------------------------------+
               |           Vector Subtraction              |
               |          vec_diff = Ray_O - Sphere_C      |
               +--------------------+----------------------+
                                    |
            +-----------------------+-----------------------+
            |                                               |
            v                                               v
+-----------------------+                       +-----------------------+
|  Dot Product Unit 1   |                       |  Dot Product Unit 2   |
|   b' = Ray_D . diff   |                       |  diff_sq = diff . diff|
+-----------+-----------+                       +-----------+-----------+
            |                                               |
            v                                               v
+-----------------------+                       +-----------------------+
|  3-Stage Multiplier   |                       |   c = diff_sq - r^2   |
|     (b')^2 Term       |                       +-----------+-----------+
+-----------+-----------+                                   |
            |                                               |
            +-----------------------+-----------------------+
                                    |
                                    v
                        +-----------------------+
                        |  Discriminant Stage   |
                        |     Delta = b'^2 - c  |
                        +-----------+-----------+
                                    |
                                    v
                        +-----------------------+
                        | Hit / Miss & t Result |
                        +-----------------------+
```
## 🔧 Module Overview

- `rtu_top.v` — MMIO wrapper that exposes the accelerator to a CPU (e.g. RocketChip) via a register map and a start/done interrupt interface. Implements a simple round-robin scheduler over three `intersection_controller` instances [19].
- `intersection_controller.v` — Internal top-level controller that instantiates `dot_product`, `fp_multiplier`, `discriminant`, and `sqrt_array`, managing the 8-stage pipeline from L = O − C through discriminant, sqrt, and t calculation [18].
- `dot_product.v` — Q16.16 3D dot product unit with control signals (`ctrl_in`/`ctrl_out`) used to compute a, half_b, and L·L over multiple passes [18].
- `discriminant.v` — Two-cycle Q16.16 discriminant stage (`disc = in1 − in2`) with a 2-bit valid pipeline so `valid_out` aligns exactly with the registered result [15].
- `fp_multiplier.v` / `fp_divider-3.v` — Fixed-point arithmetic blocks reused for r², a·c, half_b², and t calculation.
- `sqrt_unit.v` — Square-root primitive instantiated eight times in `sqrt_array` for pipelined discriminant square root computation [18].
  
---

## ⚙️ Key Technical Contributions

### 1. Q16.16 Fixed-Point Pipelined Multiplier
- Implemented signed Q16.16 (32-bit: 1 sign bit, 15 integer bits, 16 fractional bits) multiplication.
- Architected as a 3-stage pipeline to meet setup-time constraints at target clock frequency without degrading overall throughput.
- Optimized pipeline stage ordering to maximize multiplier hardware reuse, minimizing die area and power budget.

### 2. Intersection Controller & Timing Alignment
- Designed the FSM controlling data dispatch between input registers and the math pipeline.
- Inserted pipeline register stages to ensure mathematical intermediate results aligned perfectly across unequal latency paths.
- Resolved an asynchronous reset race condition and a dual-driver bus conflict discovered during back-to-back operation stress tests.

### 3. Synthesis-to-GDSII Physical Flow
- Configured automated Python/Make build scripts driving the synthesis and physical place-and-route flow.
- Resolved Design Rule Check (DRC) and Layout Versus Schematic (LVS) violations to reach clean GDSII delivery.

### 4. Silicon Bring-Up & Lab Characterization
- Set up custom logic analyzer test fixtures to characterize I/O timing on received silicon dies.
- Measured clock-to-output latencies and validated correct execution against software reference models.

---

## ✅ Verification & UVM Environment

This accelerator was verified in a SystemVerilog UVM environment maintained by our club’s digital lead.

- The UVM testbench instantiates the `rtu_top` module and drives randomized and directed ray/sphere parameters through its MMIO interface.
- A software golden model computes expected hit/miss and `t` values, which are checked against the hardware outputs (`hit`, `t_value`) for each test.
- Scoreboards and monitors track corner cases such as negative discriminants, t ≤ 0 roots, and division-by-zero flags.
- I contributed by integrating my RTL modules (`intersection_controller`, `discriminant`, dot product, and `rtu_top`) into the environment, running regressions, and debugging mismatches between waveforms and golden-model outputs.
