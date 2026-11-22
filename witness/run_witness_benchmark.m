function result = run_witness_benchmark(benchmarkName, makeProblem, shiftValues, timeLimitSeconds)
% Search successive orders for Witness SOS certificates on the benchmark state box.
    if nargin < 4
        timeLimitSeconds = 600;
    end
    validateattributes(timeLimitSeconds, {'numeric'}, {'scalar', 'finite', 'positive'});
    % Configure YALMIP, MOSEK and licensing in MATLAB before running.
    % See the repository README for installation instructions.
    options = sdpsettings('solver', 'mosek', 'verbose', 0);

    result = struct('benchmark', benchmarkName, 'status', "no_candidate", ...
        'degree', [], 'parameters', [], 'candidateText', "", ...
        'searchSeconds', NaN, 'timeLimitSeconds', timeLimitSeconds, 'attempts', []);
    attempts = struct('degree', {}, 'shift', {}, 'statusCode', {}, 'seconds', {});

    fprintf('\n=== %s | Witness ===\n', benchmarkName);
    fprintf('The checking domains use the benchmark state box; timing ends at a numerical candidate, with post-verification timed separately.\n');
    fprintf('Total time budget per benchmark: %g seconds; search starts at d = 1 and increases the order.\n', timeLimitSeconds);
    searchTimer = tic;
    d = 1;
    while result.status == "no_candidate"
        degreeTimer = tic;
        firstAttempt = numel(attempts) + 1;
        for shift = shiftValues
            if toc(searchTimer) >= timeLimitSeconds
                result.status = "timeout";
                break
            end
            attemptTimer = tic;
            yalmip('clear');
            problem = makeProblem();
            [constraints, freeParameters, freeIndex] = witness_model(problem, d, shift);

            % Each MOSEK call uses only the remaining time for the current benchmark.
            remainingSeconds = timeLimitSeconds - toc(searchTimer);
            if remainingSeconds <= 0
                result.status = "timeout";
                break
            end
            options.mosek.MSK_DPAR_OPTIMIZER_MAX_TIME = remainingSeconds;
            diagnostics = optimize(constraints, [], options);
            attempts(end + 1) = struct('degree', d, 'shift', shift, ... %#ok<AGROW>
                'statusCode', diagnostics.problem, 'seconds', toc(attemptTimer));

            if toc(searchTimer) >= timeLimitSeconds
                result.status = "timeout";
                break
            end
            if diagnostics.problem == 0
                parameters = zeros(size(problem.parameters));
                parameters(freeIndex) = value(freeParameters);
                if ~isnan(shift)
                    parameters(problem.shiftIndex) = shift;
                end
                if all(isfinite(parameters)) && passes_residual_check(constraints) && ...
                        passes_point_checks(problem, parameters)
                    candidate = replace(problem.template, problem.parameters, parameters);
                    displayText = sdisplay(candidate);
                    if toc(searchTimer) >= timeLimitSeconds
                        result.status = "timeout";
                        break
                    end
                    result.status = "numerical_candidate";
                    result.degree = d;
                    result.parameters = parameters;
                    result.candidateText = string(displayText{1});
                    break
                end
                fprintf('d = %d: The solver reported success, but the candidate failed the numerical checks; continuing the search.\n', d);
            end
            if diagnostics.problem < 0 || ismember(diagnostics.problem, [7, 14, 16, 20])
                error('Solver interrupted at d=%d: %s', d, diagnostics.info);
            end
        end
        result.searchSeconds = toc(searchTimer);
        fprintf('d = %d: %.3f seconds, solver status codes %s\n', d, toc(degreeTimer), ...
            mat2str([attempts(firstAttempt:end).statusCode]));
        d = d + 1;
    end

    result.attempts = attempts;
    fprintf('Cumulative search time starting at d = 1: %.3f seconds\n', result.searchSeconds);
    if result.status == "numerical_candidate"
        fprintf('First numerical candidate: d = %d, parameters %s\n', result.degree, ...
            mat2str(result.parameters, 12));
        fprintf('Candidate template: %s <= 0\n', result.candidateText);
        if ~isempty(problem.extra)
            fprintf('The candidate template also includes the following fixed inequalities (each <= 0):\n');
            disp(sdisplay(problem.extra));
        end
    else
        fprintf('Result: TO (total budget of %g seconds exhausted without a numerical candidate).\n', ...
            timeLimitSeconds);
    end
end

function passed = passes_residual_check(constraints)
    tolerance = 1e-6;
    residuals = check(constraints);
    sosConstraints = logical(is(constraints, 'sos'));
    % YALMIP returns decomposition errors for SOS constraints and signed feasibility margins for other constraints.
    passed = all(isfinite(residuals)) && ...
        all(residuals(sosConstraints) <= tolerance) && ...
        all(residuals(~sosConstraints) >= -tolerance);
end

function passed = passes_point_checks(problem, parameters)
% Check the original polynomials at state-box endpoints and midpoints to supplement coefficient-residual checks.
    x = problem.state;
    radius = problem.boxRadius;
    template = replace(problem.template, problem.parameters, parameters);
    invariantValues = [template, problem.extra];
    post = problem.post;
    post = post(~arrayfun(@(j) isempty(depends(post(j))) && double(post(j)) <= 0, ...
        1:numel(post)));
    afterUpdate = replace(invariantValues, x, problem.nextState);
    afterInit = replace(invariantValues, x, problem.initialState);
    initialPre = replace(problem.pre, x, problem.initialState);

    % Combine substitutions and evaluate in the original state units without relying on the SOS expansion.
    expressions = [problem.initialState, initialPre, afterInit, ...
        problem.guard, problem.branch, invariantValues, afterUpdate, post];
    initialEnd = numel(problem.initialState);
    preEnd = initialEnd + numel(initialPre);
    invariantCount = numel(invariantValues);
    initEnd = preEnd + invariantCount;
    loopIndex = initEnd + 1;
    branchIndex = initEnd + 2;
    current = branchIndex + (1:invariantCount);
    updated = current + invariantCount;
    postIndex = updated(end) + (1:numel(post));

    n = numel(x);
    levels = [-radius, 0, radius];
    grid = cell(1, n);
    [grid{:}] = ndgrid(levels);
    points = cell2mat(cellfun(@(g) g(:), grid, 'UniformOutput', false));
    tolerance = 1e-6;
    passed = false;
    for k = 1:size(points, 1)
        v = double(replace(expressions, x, points(k, :)));
        if any(~isfinite(v))
            return
        end
        if all(abs(v(1:initialEnd)) <= radius) && all(v(initialEnd+1:preEnd) <= 0) && ...
                any(v(preEnd+1:initEnd) > tolerance)
            return
        end
        if all(v(current(2:end)) <= 0)
            if v(loopIndex) <= 0 && v(branchIndex) <= 0 && ...
                    (v(updated(1)) - v(current(1)) > tolerance || ...
                     any(v(updated(2:end)) > tolerance))
                return
            end
            if v(loopIndex) >= 0 && any(v(postIndex) - v(current(1)) > tolerance)
                return
            end
        end
    end
    passed = true;
end

function [constraints, freeParameters, freeIndex] = witness_model(problem, d, shift)
    x = problem.state;
    a = problem.parameters;
    freeIndex = true(size(a));
    template = problem.template;
    if ~isnan(shift)
        idx = problem.shiftIndex;
        assert(problem.lower(idx) <= shift && shift <= problem.upper(idx), ...
            'The fixed shift parameter is outside the original parameter domain.');
        template = replace(template, a(idx), shift);
        freeIndex(idx) = false;
    end
    freeParameters = a(freeIndex);
    constraints = [problem.lower(freeIndex) <= freeParameters, ...
        freeParameters <= problem.upper(freeIndex)];

    % The reference linear box constraints and these quadratic generators describe the same symmetric box.
    box = problem.boxRadius^2 - x.^2;
    init = problem.initialState;
    initialDomain = -replace(problem.pre, x, init);
    if ~isempty(depends(init))
        initialDomain = [initialDomain(:).', replace(box, x, init)];
    else
        assert(all(abs(init) <= problem.boxRadius), 'The reference initial point is outside the state box.');
    end
    constraints = certify(constraints, -replace(template, x, init), ...
        initialDomain, x, d);
    for j = 1:numel(problem.extra)
        constraints = certify(constraints, -replace(problem.extra(j), x, init), ...
            initialDomain, x, d);
    end

    % Each of the ten programs in Table 1 has one update branch. Fixed template inequalities can define checking domains,
    % and are proved to hold at initialization and after each update.
    loopDomain = [box, -problem.guard, -problem.branch, -problem.extra];
    nextState = problem.nextState;
    constraints = certify(constraints, template - replace(template, x, nextState), ...
        loopDomain, x, d);
    for j = 1:numel(problem.extra)
        constraints = certify(constraints, -replace(problem.extra(j), x, nextState), ...
            loopDomain, x, d);
    end

    % Use guard >= 0 to cover the strict exit condition; a constant negative guard gives an empty exit domain.
    if isempty(depends(problem.guard)) && double(problem.guard) < 0
        return
    end
    exitDomain = [box, problem.guard, -problem.extra];
    for j = 1:numel(problem.post)
        post = problem.post(j);
        if isempty(depends(post)) && double(post) <= 0
            continue
        end
        constraints = certify(constraints, template - post, exitDomain, x, d);
    end
end

function constraints = certify(constraints, target, generators, x, d)
% target = sigma0 + sum(sigma_i * g_i), with all g_i interpreted as >= 0.
    [certificate, ~] = polynomial(x, 2*d);
    constraints = [constraints, sos(certificate)];
    for k = 1:numel(generators)
        g = generators(k);
        if isempty(depends(g))
            if double(g) < 0
                return
            end
            continue
        end
        multiplierDegree = 2*d - degree(g);
        if multiplierDegree < 0
            continue
        end
        [sigma, ~] = polynomial(x, multiplierDegree);
        constraints = [constraints, sos(sigma)];
        certificate = certificate + sigma*g;
    end
    constraints = [constraints, coefficients(target - certificate, x) == 0];
end
