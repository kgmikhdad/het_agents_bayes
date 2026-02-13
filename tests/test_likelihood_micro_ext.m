% Test script for likelihood_micro_ext function
% Smoke test: verifies function runs without errors and produces sensible output

clear all;
addpath(genpath('../program/hh_model/auxiliary_functions'));
addpath(genpath('../program/functions'));

disp('=== Testing likelihood_micro_ext ===');

%% Setup test data

% Create fake smooth_draw_t (table with one row)
smooth_data = struct();
smooth_data.w = 1.0;
smooth_data.r = 1.05;
smooth_data.lag_mHat_1 = 0.1;
smooth_data.lag_mHat_2 = 0.15;
smooth_data.lag_moment_1_1 = 0.5;
smooth_data.lag_moment_1_2 = 0.3;
smooth_data.lag_moment_1_3 = 0.2;
smooth_data.lag_moment_2_1 = 0.6;
smooth_data.lag_moment_2_2 = 0.35;
smooth_data.lag_moment_2_3 = 0.25;
smooth_data.measureCoefficient_1_1 = 1.0;
smooth_data.measureCoefficient_1_2 = 0.5;
smooth_data.measureCoefficient_1_3 = 0.1;
smooth_data.measureCoefficient_2_1 = 1.1;
smooth_data.measureCoefficient_2_2 = 0.6;
smooth_data.measureCoefficient_2_3 = 0.15;
smooth_data.logAggregateConsumption = 0.0;

smooth_draw_t = struct2table(smooth_data);

% Create fake micro data (N=10 households)
N = 10;
data_micro_t = zeros(N, 5);
data_micro_t(:, 1) = [1; 1; 0; 0; 1; 0; 1; 1; 0; 0]; % type (0=NR, 1=R)
data_micro_t(:, 2) = [1; 0; 1; 0; 1; 0; 1; 0; 1; 0]; % employment
data_micro_t(:, 3) = [2.5; 1.8; 2.0; 1.5; 2.3; 1.6; 2.4; 1.9; 2.1; 1.7]; % income
data_micro_t(:, 4) = [2.0; 1.5; 1.8; 1.3; 2.0; 1.4; 2.1; 1.6; 1.9; 1.5]; % consumption
data_micro_t(:, 5) = [0.6; 0.5; 0.55; 0.45; 0.6; 0.48; 0.62; 0.52; 0.57; 0.5]; % food consumption

% Setup micro_cfg
micro_cfg = struct();
micro_cfg.col = struct();
micro_cfg.col.type = 1;
micro_cfg.col.eps = 2;
micro_cfg.col.y = 3;
micro_cfg.col.c = 4;
micro_cfg.col.cf = 5;
micro_cfg.col.share = NaN;
micro_cfg.col.wt = NaN;
micro_cfg.use_vars = struct('income', true, 'consumption', true, 'food', true);
micro_cfg.food_mode = 'level';
micro_cfg.log_mode = true;

% Setup param_struct
param_struct = struct();
param_struct.aaBar = 0.0;
param_struct.mmu = 0.15;
param_struct.ttau = 0.2;
param_struct.mu_l = -0.5;
param_struct.num_mom = 3;
param_struct.num_interp = 20; % Use fewer points for faster test

% Ricardian parameters
param_struct.alpha_c_R = -0.5;
param_struct.beta_c_R = 0.9;
param_struct.gamma_c_R = 0.1;
param_struct.sigma_c_R = 0.15;
param_struct.alpha_f_R = -1.0;
param_struct.beta_f_R = 0.8;
param_struct.gamma_f_R = 0.05;
param_struct.sigma_f_R = 0.2;

% Non-Ricardian parameters
param_struct.alpha_c_NR = -0.3;
param_struct.beta_c_NR = 0.95;
param_struct.gamma_c_NR = 0.15;
param_struct.sigma_c_NR = 0.2;
param_struct.alpha_f_NR = -0.8;
param_struct.beta_f_NR = 0.75;
param_struct.gamma_f_NR = 0.08;
param_struct.sigma_f_NR = 0.25;

param_struct.micro_cfg = micro_cfg;

%% Run likelihood function

try
    likes = likelihood_micro_ext(smooth_draw_t, data_micro_t, param_struct);
    
    % Check output
    assert(isvector(likes), 'Output should be a vector');
    assert(length(likes) == N, 'Output should have N elements');
    assert(all(isfinite(likes)), 'All likelihoods should be finite');
    assert(all(likes > 0), 'All likelihoods should be positive');
    assert(all(likes < 1e10), 'Likelihoods should be reasonable magnitude');
    
    disp('✓ likelihood_micro_ext test PASSED');
    disp(['  Output size: ', num2str(size(likes))]);
    disp(['  Mean likelihood: ', num2str(mean(likes))]);
    disp(['  Min/Max: ', num2str(min(likes)), ' / ', num2str(max(likes))]);
    
catch ME
    disp('✗ likelihood_micro_ext test FAILED');
    disp(['  Error: ', ME.message]);
    rethrow(ME);
end

%% Test with missing values

disp('Testing with missing values...');
data_micro_missing = data_micro_t;
data_micro_missing(1:3, 4) = NaN; % Missing consumption for first 3
data_micro_missing(5:7, 5) = NaN; % Missing food for 3 others

try
    likes_missing = likelihood_micro_ext(smooth_draw_t, data_micro_missing, param_struct);
    
    assert(all(isfinite(likes_missing)), 'Should handle missing values');
    assert(all(likes_missing > 0), 'Should produce positive likelihoods with missing data');
    
    disp('✓ Missing value handling test PASSED');
    
catch ME
    disp('✗ Missing value handling test FAILED');
    disp(['  Error: ', ME.message]);
    rethrow(ME);
end

disp(' ');
disp('All tests PASSED!');
