%% Table 1: Witness experiment for freire1-2
% Reference input: benchmarks/cluster/ex2_freire12.m
% Open this file in MATLAB and click Run.
shiftValues = [0, reshape([0.25:0.25:2; -0.25:-0.25:-2], 1, [])];
addpath(fileparts(mfilename('fullpath')));
witnessResult = run_witness_benchmark('freire1-2', @benchmark_definition, ...
    shiftValues);

function problem = benchmark_definition()
    sdpvar x r y;
    vars = [x, r, y];

    % loop condition
    loop_cond = r - x;

    % while body
    f1 = [  x - r ; % x
            r + 1 ; % r
            y       % a
    ];

    f_list = [f1];

    % guard conditions
    guard_cond_list = [-1];

    % pre-condition
    pre_cond_eq = [y/2, 0, y];
    pre_cond_ineq = [-y];

    % post-condtion
    post_cond_ineq = [-1];

    % invariant
    a = sdpvar(1,2);
    a_range = [-2,2,-2,2];

    inv = 2*x + a(2)*(r+a(1))^2 - y;
    inv_ineq = [-x, -r];

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
    problem.shiftIndex = 1;
end
