function attempt = algo_cluster_matched(benchmark, adeg, timer, timeLimitSeconds)

attempt = struct('problem', NaN, 'info', "", 'parameters', [], ...
    'hValue', NaN, 'polynomial', "", 'boundaryCandidate', false);
yalmip('clear')
caseFile = fullfile(fileparts(mfilename('fullpath')), ['ex2_', benchmark, '.m']);
run(caseFile)

epsilon = 0;
M = -1;

lvars = [a, vars];

% Set p_a template and compute objective function
%
[p_a, coef_p] = polynomial(a, adeg);
a_monomials = monolist(a, adeg);

% Scaling "a" variables
% 
a_scaled = a;
for i = 1:length(a)
    min = a_range(2*i-1);
    max = a_range(2*i);
    a_scaled(i) = (max-min)/2*a_scaled(i)+(max+min)/2;
end

inv = replace(inv, a, a_scaled);

moments = [];
for i = 1:length(a_monomials)
    moments(i) = compute_moment(a, a_monomials(i));
end
obj = dot(moments,coef_p);

% make box constraints for a_var and x_var
for i = 1:length(a)
    a_range_cond(2*i-1) = -1-a(i);
    a_range_cond(2*i) = a(i)-1;
end
range_cond= [a_range_cond, range_cond];
% fprintf(fileID,string(range_cond));
% Encode SOS constraints
%
sdp_var = [coef_p];
constraints = [];
sigma_cell = {};
sigma_coef_cell = {};
tail = 1;

sdp_cons = {lvars, sdp_var, constraints, sigma_cell, sigma_coef_cell, tail};

% pre cond
q = replace(inv, vars, pre_cond_eq);
sdp_cons = translateSOSnew([pre_cond_ineq, range_cond], q - p_a, sdp_cons, sdeg, epsilon,degrees);

% inductive
for j = 1:branch_num
    sdp_cons = translateSOSnew([inv, inv_ineq, loop_cond, guard_cond_list(j), range_cond], replace(inv, vars, f_list(:,j))-p_a, sdp_cons, sdeg, epsilon,degrees);
end

%post
for j = 1:length(post_cond_ineq)
    % -loopcond
    sdp_cons = translateSOSnew([inv, range_cond, -loop_cond], post_cond_ineq(j)-p_a, sdp_cons, sdeg, epsilon,degrees);
end

% M
sdp_cons = translateSOSnew([range_cond], M - p_a, sdp_cons, sdeg, epsilon,degrees);

lvars = sdp_cons{1};
sdp_var = sdp_cons{2};
constraints = sdp_cons{3};
sigma_cell  = sdp_cons{4}; 
sigma_coef_cell = sdp_cons{5};
tail = sdp_cons{6};

options = sdpsettings('solver','mosek','verbose', 0, 'sos.newton',1,'sos.congruence',1);



remainingSeconds = timeLimitSeconds - toc(timer);
if remainingSeconds <= 0
    return
end
options.mosek.MSK_DPAR_OPTIMIZER_MAX_TIME = remainingSeconds;
diagnostics = solvesos(constraints, obj, options, sdp_var);
attempt.problem = diagnostics.problem;
attempt.info = string(diagnostics.info);
if diagnostics.problem ~= 0 || toc(timer) >= timeLimitSeconds
    return
end

% Use full solver coefficients for point selection to avoid mistaking display-rounding artifacts for a zero boundary.
p_val = value(coef_p);
if any(~isfinite(p_val))
    return
end
h = dot(p_val, a_monomials);
s = string(sdisplay(h));
for i = 1:numel(a)
    s = strrep(s, sprintf('a(%d)', i), sprintf('a%d', i));
end
attempt.polynomial = s;
powers = full(degree(a_monomials, a, 'max', 1));
if adeg == 1
    % For a linear polynomial, the minimizing box corner follows from the signs of its coefficients.
    point = -sign((powers.'*p_val).');
else
    point = find_sublevel_point(powers, p_val, timer, timeLimitSeconds);
end
if isempty(point)
    return
end
hValue = double(replace(h, a, point));
if ~isfinite(hValue)
    return
end
if hValue > 0
    if adeg ~= 1
        return
    end
    % Detect zero-boundary cases using the original five-decimal output rule; use integer arithmetic to avoid floating-point sign errors after rounding.
    rounded = round(1e5*p_val);
    corner = -sign((powers.'*rounded).');
    terms = prod(corner.^powers, 2);
    if sum(abs(rounded)) > flintmax || rounded.'*terms ~= 0
        return
    end
    point = corner;
    hValue = double(replace(h, a, point));
    if ~isfinite(hValue)
        return
    end
    attempt.boundaryCandidate = true;
end
lower = a_range(1:2:end);
upper = a_range(2:2:end);
attempt.parameters = lower + (point+1).*(upper-lower)/2;
attempt.hValue = hValue;
end

function moment = compute_moment(a,a_monomial)
    exp_list = degree(a_monomial,a);
    moment = 1;
    for i=1:length(exp_list)
        upper = 1/(exp_list(i)+1);
        lower = (-1)^(exp_list(i)+1)*1/(exp_list(i)+1);
        moment = moment*(upper-lower);
    end
end


function sdp_cons = translateSOSnew(pre_list, post, sdp_cons, sdeg, epsilon, degrees)
    vars = sdp_cons{1};
    sdp_var = sdp_cons{2};
    constraints = sdp_cons{3};
    sigma_cell  = sdp_cons{4}; 
    sigma_coef_cell = sdp_cons{5};
    tail = sdp_cons{6};
    sum = 0;
    for i = 1:length(pre_list)
        [sigma_cell{tail}, sigma_coef_cell{tail}] = polynomial(vars, degrees);    
        sum = sum + sigma_cell{tail} * pre_list(i);
        constraints = [constraints, sos(sigma_cell{tail})];
        sdp_var = [sdp_var; sigma_coef_cell{tail}];
        tail = tail + 1;
    end
    constraints = [constraints, sos( - post + sum + epsilon)];
    sdp_cons = {vars, sdp_var, constraints, sigma_cell, sigma_coef_cell, tail};
end


function point = find_sublevel_point(powers, coefficients, timer, limit)
% Search a fixed grid on the normalized parameter box first, then perform local search with a bounded mapping.
    point = [];
    dimensions = size(powers, 2);
    grids = cell(1, dimensions);
    [grids{:}] = ndgrid(linspace(-1, 1, 9));
    candidates = cell2mat(cellfun(@(g) g(:), grids, 'UniformOutput', false));
    values = zeros(size(candidates, 1), 1);
    for j = 1:numel(coefficients)
        if toc(timer) >= limit
            return
        end
        values = values + coefficients(j)*prod(candidates.^powers(j, :), 2);
    end

    [values, order] = sort(values);
    if values(1) <= 0
        point = candidates(order(1), :);
        return
    end

    clip = @(x) max(-1, min(1, x(:).'));
    evaluate = @(x) coefficients(:).'*prod(clip(x).^powers, 2);
    stop = @(~, values, ~) toc(timer) >= limit || values.fval <= 0;
    options = optimset('Display', 'off', 'MaxFunEvals', 180, ...
        'MaxIter', 120, 'OutputFcn', stop);
    for k = 1:min(3, numel(order))
        if toc(timer) >= limit
            return
        end
        start = candidates(order(k), :);
        solution = fminsearch(evaluate, start, options);
        score = evaluate(solution);
        if score <= 0
            point = clip(solution);
            return
        end
    end
end