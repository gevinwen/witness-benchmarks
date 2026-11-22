%% Table 1: Witness experiment for circuit
% Reference input: benchmarks/cluster/ex2_circuit.m
% Open this file in MATLAB and click Run.
shiftValues = NaN;
addpath(fileparts(mfilename('fullpath')));
witnessResult = run_witness_benchmark('circuit', @benchmark_definition, ...
    shiftValues);

function problem = benchmark_definition()
    % example: simple
    sdpvar x1 x2;
    vars = [x1, x2];

    % Program body
    %
    % branches
    loop_cond = -x2;

    f1 = [  8/9*x1 - 1/18 *x2;
            0.1*x1 + 0.9*x2];

    f_list = [f1];
    guard_cond_list = [-1];

    % pre-conditions
    pre_cond_eq = [x1,x2];
    pre_cond_ineq = [(x1-0.5)^2 + (x2-0.5)^2-0.25^2 ];
    % post-condtion
    post_cond_ineq = [x2^2-4];

    % invariant template

    a = sdpvar(1,2);
    a_range = [ 0, 1, 0, 1];

    inv = a(1)*x1^2 + a(2)*x2^2 -1;
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
