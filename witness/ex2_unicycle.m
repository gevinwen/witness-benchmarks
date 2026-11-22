%% Table 1: Witness experiment for unicycle
% Reference input: benchmarks/cluster/ex2_unicycle.m
% Open this file in MATLAB and click Run.
shiftValues = NaN;
addpath(fileparts(mfilename('fullpath')));
witnessResult = run_witness_benchmark('unicycle', @benchmark_definition, ...
    shiftValues);

function problem = benchmark_definition()
    % Dubin's car example

    % ----- Program body ------
    %
    sdpvar x1 x2

    vars = [x1, x2];

    % loop condition
    loop_cond = -1;

    % body

    d = 0.01;
    w = 1.0178 + 1.8721 * x1 - 0.0253 * x2;
    f1 = [
           [x1 + d*(1-x2*w), x2 + d*x1*w]
    ];
    f_list = [f1];

    guard_cond_list = [-1];

    % pre-conditions
    pre_cond_eq = [x1,x2];
    pre_cond_ineq = [x1^2 + (x2-1)^2 - 1];

    % post-condtion
    post_cond_ineq = [x1^2 + (x2-1)^2 - 4];

    % ----- Invariant template ------
    %

    a = sdpvar(1,3);
    a_range = [0, 10, -10, 10, -10, 10];

    % invariant template
    inv = x1^2 + a(1)*x2^2 + a(2)*x2 + a(3);
    inv_ineq = [];

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
    problem.shiftIndex = 0;
end
