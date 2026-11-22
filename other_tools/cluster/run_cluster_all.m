function summary = run_cluster_all(selectedBenchmarks, timeLimitSeconds)
% Run all ten Cluster benchmarks in Table 1, with a default total budget of 600 seconds per instance.
% Use run_cluster_all("Example 1", 30) to try a selected benchmark.
    folder = fileparts(mfilename('fullpath'));
    benchmark = ["freire1-1"; "freire1-2"; "freire1-3"; ...
        "cohencu-1"; "cohencu-2"; "cohencu-3"; ...
        "Example 1"; "circuit"; "unicycle"; "overview"];
    sourceNames = ["freire1"; "freire12"; "freire13"; ...
        "cohencu"; "cohencu2"; "cohencu3"; ...
        "example"; "circuit"; "unicycle"; "overview"];
    fullBatch = nargin == 0;
    if nargin >= 1
        selectedBenchmarks = string(selectedBenchmarks);
        assert(all(ismember(selectedBenchmarks(:), benchmark)), 'Unknown benchmark name.');
        keep = ismember(benchmark, selectedBenchmarks);
        benchmark = benchmark(keep);
        sourceNames = sourceNames(keep);
    end
    if nargin < 2
        timeLimitSeconds = 600;
    end
    validateattributes(timeLimitSeconds, {'numeric'}, {'scalar', 'finite', 'positive'});

    addpath(folder);
    % Configure YALMIP, MOSEK and licensing in MATLAB before running.
    % See the repository README for installation instructions.

    % The original code specifies multiplier degrees by variable. Preserve this modeling behavior and suppress compatibility warnings during timing.
    warningID = 'MATLAB:colon:operandsNotRealScalar';
    previousWarning = warning('query', warningID);
    restoreWarning = onCleanup(@() warning(previousWarning)); %#ok<NASGU>
    warning('off', warningID);

    count = numel(benchmark);
    status = strings(count, 1);
    degree = nan(count, 1);
    searchSeconds = nan(count, 1);
    parameters = strings(count, 1);
    hValue = nan(count, 1);
    polynomial = strings(count, 1);
    notes = strings(count, 1);

    for k = 1:count
        fprintf('\n======== Cluster %d/%d: %s (budget %g seconds)========\n', ...
            k, count, benchmark(k), timeLimitSeconds);
        timer = tic;
        d = 1;
        try
            status(k) = "TO";
            while toc(timer) < timeLimitSeconds
                attempt = algo_cluster_matched(char(sourceNames(k)), d, timer, timeLimitSeconds);
                fprintf('D = %d: YALMIP status %g, cumulative %.3f seconds\n', d, attempt.problem, toc(timer));
                if toc(timer) >= timeLimitSeconds
                    break
                end
                if strlength(attempt.polynomial) > 0
                    polynomial(k) = attempt.polynomial;
                end
                if ~isempty(attempt.parameters)
                    if attempt.boundaryCandidate
                        status(k) = "BoundaryCandidate";
                        notes(k) = "After rounding coefficients to five decimal places, h_D is zero at this point; HValue records its unrounded value. Post-verification is required.";
                    else
                        status(k) = "Candidate";
                    end
                    degree(k) = d;
                    parameters(k) = string(mat2str(attempt.parameters, 15));
                    hValue(k) = attempt.hValue;
                    fprintf('Candidate parameters (original scale): %s, h_D = %.9g\n', parameters(k), hValue(k));
                    break
                end
                if attempt.problem < 0 || ismember(attempt.problem, [7, 14, 16, 20])
                    error('Solver interrupted at D=%d: %s', d, attempt.info);
                end
                d = d + 1;
            end
            if status(k) == "TO"
                notes(k) = "No numerical candidate found from h_D within the budget";
            end
        catch ME
            status(k) = "Error";
            notes(k) = string(ME.message);
            fprintf('Error while running this benchmark: %s\n', ME.message);
        end
        searchSeconds(k) = toc(timer);
        fprintf('Result: %s, cumulative search time %.3f seconds\n', status(k), searchSeconds(k));
    end

    summary = table(benchmark, status, degree, searchSeconds, parameters, ...
        hValue, polynomial, notes, 'VariableNames', {'Benchmark', 'Status', ...
        'Degree', 'SearchSeconds', 'Parameters', 'HValue', 'Polynomial', 'Notes'});
    disp(summary(:, {'Benchmark', 'Status', 'Degree', 'SearchSeconds', 'Parameters'}));

    if fullBatch
        stamp = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
        outputFile = fullfile(folder, "cluster_times_" + stamp + ".csv");
        writetable(summary, outputFile);
        fprintf('Summary saved to: %s\n', outputFile);
    end
end
