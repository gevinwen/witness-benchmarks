# Witness Benchmark Experiments

Benchmark code for **Invariant Parameter Set Synthesis for Polynomial Loop Programs via Certificate-Parameterized Projection**, covering the ten Witness and Cluster instances in Section 4.1 (Table 3).

## Basic Setup

1. Install MATLAB. The manuscript uses MATLAB R2024b.
2. Install [YALMIP](https://yalmip.github.io/tutorial/installation/) and add its required directories to the MATLAB search path.
3. Install the [MOSEK Optimization Toolbox for MATLAB](https://docs.mosek.com/latest/toolbox/install-interface.html) and configure a valid license following the [licensing guide](https://docs.mosek.com/latest/licensing/client-setup.html).
4. Download this repository and set the MATLAB Current Folder to its root directory. Software paths and licensing should be configured in your own environment.

## Running Commands

Run the following commands from the repository root:

```matlab
% Witness: all ten benchmarks
run(fullfile('witness', 'run_witness_all.m'));

% Cluster: all ten benchmarks
addpath(fullfile(pwd, 'other_tools', 'cluster'));
clusterSummary = run_cluster_all();
```

Each instance has a default cumulative search budget of 600 seconds. The runners save CSV summaries in their respective method directories. Witness reports the SOS relaxation order; Cluster reports the upper-bound polynomial degree. Returned parameters are numerical candidates and require certificate verification before use as rigorous safety proofs.

## Other Tools and Source

PolySynth and Z3 comparison materials are provided in `other_tools/PolySynth` and `other_tools/z3`. Run them separately with the corresponding tools; the PolySynth engine is not included.

