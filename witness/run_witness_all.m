folder = fileparts(mfilename('fullpath'));

benchmark = [
    "freire1-1"; "freire1-2"; "freire1-3";
    "cohencu-1"; "cohencu-2"; "cohencu-3";
    "Example 1"; "circuit"; "unicycle"; "overview"
];

scripts = [
    "ex2_freire1.m"; "ex2_freire12.m"; "ex2_freire13.m";
    "ex2_cohencu.m"; "ex2_cohencu2.m"; "ex2_cohencu3.m";
    "ex2_example.m"; "ex2_circuit.m";
    "ex2_unicycle.m"; "ex2_overview.m"
];

n = numel(scripts);
status = strings(n, 1);
degree = nan(n, 1);
seconds = nan(n, 1);
notes = strings(n, 1);
allResults = cell(n, 1);

for k = 1:n
    fprintf('\n======== Benchmark %d/%d: %s ========\n', k, n, benchmark(k));

    try
        run(fullfile(folder, scripts(k)));
        allResults{k} = witnessResult;
        seconds(k) = witnessResult.searchSeconds;

        if witnessResult.status == "numerical_candidate"
            status(k) = "Candidate";
            degree(k) = witnessResult.degree;
        elseif witnessResult.status == "timeout"
            status(k) = "TO";
        else
            status(k) = witnessResult.status;
        end
    catch ME
        status(k) = "Error";
        notes(k) = string(ME.message);
        fprintf('Error while running this benchmark: %s\n', ME.message);
    end
end

summary = table(benchmark, status, degree, seconds, notes, ...
    'VariableNames', {'Benchmark', 'Status', 'Degree', 'SearchSeconds', 'Notes'});
disp(summary);

stamp = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outputFile = fullfile(folder, "witness_times_" + stamp + ".csv");
writetable(summary, outputFile);
fprintf('Summary saved to: %s\n', outputFile);