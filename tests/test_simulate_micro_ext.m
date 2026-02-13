% Test script for simulate_micro_ext function
% Smoke test: verifies function runs and produces correct structure

clear all;
addpath(genpath('../program/hh_model/auxiliary_functions'));
addpath(genpath('../program/functions'));

disp('=== Testing simulate_micro_ext ===');

%% Setup test data

% Set global parameters needed by simulate_micro
global mu_l;
mu_l = -0.5;

% Create fake simul_data_micro_aux (T_micro=2, N_micro=50, 3 dims)
T_micro = 2;
N_micro = 50;
simul_data_micro_aux = zeros(T_micro, N_micro, 3);

% Random employment (0 or 1)
simul_data_micro_aux(:, :, 1) = (rand(T_micro, N_micro) > 0.5);

% Random normalized income (positive)
simul_data_micro_aux(:, :, 2) = 1.0 + 0.5*randn(T_micro, N_micro);
simul_data_micro_aux(:, :, 2) = max(simul_data_micro_aux(:, :, 2), 0.1); % Ensure positive

% Random assets
simul_data_micro_aux(:, :, 3) = 0.5 + 0.3*randn(T_micro, N_micro);
simul_data_micro_aux(:, :, 3) = max(simul_data_micro_aux(:, :, 3), 0); % Non-negative

% Create fake sim_struct
sim_struct = struct();
sim_struct.w = ones(100, 1);
sim_struct.r = 1.05 * ones(100, 1);
sim_struct.logAggregateConsumption = zeros(100, 1);

ts_micro = [10; 20];

% Setup micro_cfg
micro_cfg = struct();
micro_cfg.col = struct();
micro_cfg.col.type = 1;
micro_cfg.col.eps = 2;
micro_cfg.col.y = 3;
micro_cfg.col.c = 4;
micro_cfg.col.cf = 5;
micro_cfg.use_vars = struct('income', true, 'consumption', true, 'food', true);
micro_cfg.food_mode = 'level';

% Setup micro_true_params
micro_true_params = struct();
micro_true_params.pi_true = 0.6;
micro_true_params.alpha_c_R = -0.5;
micro_true_params.beta_c_R = 0.9;
micro_true_params.gamma_c_R = 0.1;
micro_true_params.sigma_c_R = 0.15;
micro_true_params.alpha_f_R = -1.0;
micro_true_params.beta_f_R = 0.8;
micro_true_params.gamma_f_R = 0.05;
micro_true_params.sigma_f_R = 0.2;
micro_true_params.alpha_c_NR = -0.3;
micro_true_params.beta_c_NR = 0.95;
micro_true_params.gamma_c_NR = 0.15;
micro_true_params.sigma_c_NR = 0.2;
micro_true_params.alpha_f_NR = -0.8;
micro_true_params.beta_f_NR = 0.75;
micro_true_params.gamma_f_NR = 0.08;
micro_true_params.sigma_f_NR = 0.25;

%% Run simulation function

try
    simul_data_micro_ext = simulate_micro_ext(simul_data_micro_aux, sim_struct, ts_micro, micro_true_params, micro_cfg);
    
    % Check output structure
    assert(iscell(simul_data_micro_ext), 'Output should be a cell array');
    assert(length(simul_data_micro_ext) == T_micro, 'Cell array should have T_micro elements');
    
    % Check each cell
    for it = 1:T_micro
        data_it = simul_data_micro_ext{it};
        
        assert(ismatrix(data_it), sprintf('Cell %d should contain a matrix', it));
        assert(size(data_it, 1) == N_micro, sprintf('Cell %d should have N_micro rows', it));
        assert(size(data_it, 2) == 5, sprintf('Cell %d should have 5 columns', it));
        
        % Check column contents
        type_col = data_it(:, 1);
        eps_col = data_it(:, 2);
        y_col = data_it(:, 3);
        c_col = data_it(:, 4);
        cf_col = data_it(:, 5);
        
        assert(all(type_col == 0 | type_col == 1), 'Type should be 0 or 1');
        assert(all(eps_col == 0 | eps_col == 1), 'Employment should be 0 or 1');
        assert(all(y_col > 0), 'Income should be positive');
        assert(all(c_col > 0), 'Consumption should be positive');
        assert(all(cf_col > 0), 'Food consumption should be positive');
        
        % Check that type distribution is reasonable
        type_share = mean(type_col);
        assert(type_share > 0.3 && type_share < 0.9, 'Type share should be reasonable');
    end
    
    disp('✓ simulate_micro_ext test PASSED');
    disp(['  Output: Cell array of size ', num2str(size(simul_data_micro_ext))]);
    disp(['  Each cell: Matrix of size (', num2str(N_micro), ', 5)']);
    disp(['  Type share (Ricardian): ', num2str(mean(simul_data_micro_ext{1}(:,1)))]);
    disp(['  Mean income: ', num2str(mean(simul_data_micro_ext{1}(:,3)))]);
    disp(['  Mean consumption: ', num2str(mean(simul_data_micro_ext{1}(:,4)))]);
    disp(['  Mean food: ', num2str(mean(simul_data_micro_ext{1}(:,5)))]);
    
catch ME
    disp('✗ simulate_micro_ext test FAILED');
    disp(['  Error: ', ME.message]);
    disp(getReport(ME));
    rethrow(ME);
end

disp(' ');
disp('All tests PASSED!');
