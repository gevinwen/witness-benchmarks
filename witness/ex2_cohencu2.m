%% Table 1: Witness experiment for cohencu-2
% Reference input: benchmarks/cluster/ex2_cohencu2.m
% Open this file in MATLAB and click Run.
shiftValues = [0, reshape([0.25:0.25:2; -0.25:-0.25:-2], 1, [])];
addpath(fileparts(mfilename('fullpath')));
witnessResult = run_witness_benchmark('cohencu-2', @benchmark_definition, ...
    shiftValues);

function problem = benchmark_definition()
    sdpvar n x;
    vars = [n, x];

    % loop condition
    loop_cond = n-5;

    % while body
    f1 = [  n + 1,
            x + 6*n + 6,
    ];
    f_list = [f1];
    % guard conditions
    guard_cond_list = [-1];

    % pre-condition
    pre_cond_eq = [0, 0];
    pre_cond_ineq = [-1]; % -a<=0

    % post-condtion
    post_cond_ineq = [2.5*n^2+4*n-x, x-3.5*n^2-3*n];

    a = sdpvar(1,3);
    a_range = [-2, 3, -2, 2, -2, 2]; % Additional experiment: relax only the upper bound of the first parameter

    inv = a(1)*(n+a(2))^2 + a(3) - x;
    inv_ineq = [-n]; % -a<=0

    problem.state = vars(:).';
    problem.parameters = a(:).';
    problem.lower = a_range(1:2:end);
    problem.upper = a_range(2:2:end);
    problem.template = inv;
    problem.extra = inv_ineq(:).';
    problem.initialState = pre_cond_eq(:).';
    problem.pre = pre_cond_ineq(:).';
    problem.post = post_cond_ineq(:).';
    problem.guard = loop_cond;
    problem.branch = guard_cond_list(1);
    problem.nextState = f_list(:).';
    problem.boxRadius = 5;
    problem.shiftIndex = 2;
end
