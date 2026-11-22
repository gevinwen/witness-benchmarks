%% Table 1: Witness experiment for Example 1
% Reference input: benchmarks/cluster/ex2_example.m
% Open this file in MATLAB and click Run.
shiftValues = NaN;
addpath(fileparts(mfilename('fullpath')));
witnessResult = run_witness_benchmark('Example 1', @benchmark_definition, ...
    shiftValues);

function problem = benchmark_definition()
    % example: simple
    sdpvar x1 x2;
    vars = [x1, x2];

    % Program body
    %
    % branches
    loop_cond = x1^2-0.81;

    f1 = [  0.95 * ( x1 - 0.1 * x2^2);
            0.95 * ( x2 + 0.2 * x1*x2)];
    f_list = [f1];
    guard_cond_list = [-1];

    % pre-conditions
    pre_cond_eq = [x1, x2];
    pre_cond_ineq = [x1^2 + x2^2 - 1];
    % post-condtion
    post_cond_ineq = [1/4 - x1^2 - (x2-1.5)^2];

    % invariant template

    a = sdpvar(1,2);
    a_range = [ -10, 10, -10, 10];
    inv = x1^2 + a(1)*x2^2 + a(2);
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
    problem.boxRadius = 2;
    problem.shiftIndex = 0;
end
