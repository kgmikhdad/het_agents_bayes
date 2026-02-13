clear all;

% Extended estimation for heterogeneous household model with richer micro data

model_name = 'hh';

addpath(genpath('./functions'));
addpath(genpath(['./' model_name '_model/auxiliary_functions']));


%% Settings

% Decide what to do
is_run_dynare = true;   % Process Dynare model?
is_data_gen = true;     % Simulate data?
likelihood_type = 1;    % =1: macro + full-info micro (extended)

% ID
serial_id = 1;          % ID number of current run

% Model/data settings
T = 100;                % Number of periods of simulated macro data
ts_micro = 10:10:T;     % Time periods where we observe micro data
N_micro = 1e3;          % Number of households per non-missing time period

% File names
global mat_suff;
mat_suff = sprintf('%s%d%s%d%s%02d', '_N', N_micro, '_liktype', likelihood_type, '_ext_', serial_id);
save_folder = fullfile(pwd, 'results');

% Declare global variables for extended micro parameters
global alpha_c_R beta_c_R gamma_c_R sigma_c_R;
global alpha_f_R beta_f_R gamma_f_R sigma_f_R;
global alpha_c_NR beta_c_NR gamma_c_NR sigma_c_NR;
global alpha_f_NR beta_f_NR gamma_f_NR sigma_f_NR;

% Extended parameter names
param_names = {'bbeta', 'ssigmaMeas', 'mu_l', ...
               'alpha_c_R', 'beta_c_R', 'gamma_c_R', 'sigma_c_R', ...
               'alpha_f_R', 'beta_f_R', 'gamma_f_R', 'sigma_f_R', ...
               'alpha_c_NR', 'beta_c_NR', 'gamma_c_NR', 'sigma_c_NR', ...
               'alpha_f_NR', 'beta_f_NR', 'gamma_f_NR', 'sigma_f_NR'};

% Parameter transformation functions
% bbeta: logit, ssigmaMeas: log, mu_l: log(-x), sigmas: log, alphas/betas/gammas: identity
transf_to_param = @(x) [1/(1+exp(-x(1))), exp(x(2)), -exp(x(3)), ...
                        x(4), x(5), x(6), exp(x(7)), ...
                        x(8), x(9), x(10), exp(x(11)), ...
                        x(12), x(13), x(14), exp(x(15)), ...
                        x(16), x(17), x(18), exp(x(19))];

param_to_transf = @(x) [log(x(1)/(1-x(1))), log(x(2)), log(-x(3)), ...
                        x(4), x(5), x(6), log(x(7)), ...
                        x(8), x(9), x(10), log(x(11)), ...
                        x(12), x(13), x(14), log(x(15)), ...
                        x(16), x(17), x(18), log(x(19))];

% Prior for transformed parameters
prior_logdens_transf = @(x) sum(x) - 2*log(1+exp(x(1))) ...  % bbeta prior
                            - 0.5*sum(x(4:6).^2)/1^2 ...      % N(0,1) for alpha_c_R, beta_c_R-1, gamma_c_R
                            - 0.5*sum(x(8:10).^2)/1^2 ...     % N(0,1) for alpha_f_R, beta_f_R-1, gamma_f_R
                            - 0.5*sum(x(12:14).^2)/1^2 ...    % N(0,1) for alpha_c_NR, beta_c_NR-1, gamma_c_NR
                            - 0.5*sum(x(16:18).^2)/1^2;       % N(0,1) for alpha_f_NR, beta_f_NR-1, gamma_f_NR

% Optimization settings
is_optimize = false;  % Start with false for extended model (can enable later)
optim_grid = [];      % Empty for now

% MCMC settings
% Initial values (transformed space)
mcmc_init = param_to_transf([.9, .06, -1, ...         % bbeta, ssigmaMeas, mu_l
                             -0.5, 0.9, 0.1, 0.15, ... % alpha_c_R, beta_c_R, gamma_c_R, sigma_c_R
                             -1.0, 0.8, 0.05, 0.2, ... % alpha_f_R, beta_f_R, gamma_f_R, sigma_f_R
                             -0.3, 0.95, 0.15, 0.2, ...% alpha_c_NR, beta_c_NR, gamma_c_NR, sigma_c_NR
                             -0.8, 0.75, 0.08, 0.25]); % alpha_f_NR, beta_f_NR, gamma_f_NR, sigma_f_NR

mcmc_num_iter = 1e4;                    % Number of MCMC steps
mcmc_thin = 1;                          % Store every X draws
mcmc_stepsize_init = 1e-3;              % Smaller initial step for more parameters
mcmc_adapt_iter = [50 200 500 1000];    % Iterations for adaptation
mcmc_adapt_diag = false;                % Adapt to full covariance
mcmc_adapt_param = 10;                  % Shrinkage parameter

% Adaptive RWMH
mcmc_c = 0.55;                          % Updating rate parameter
mcmc_ar_tg = 0.3;                       % Target acceptance rate
mcmc_p_adapt = .95;                     % Probability of non-diffuse proposal

% Likelihood settings
num_smooth_draws = 500;                 % Number of smoother draws
num_interp = 100;                       % Interpolation grid points

% Numerical settings
num_burnin_periods = 100;
rng_seed = 20200813 + serial_id;
if likelihood_type == 1
    delete(gcp('nocreate'));
    poolobj = parpool;                  % Parallel computing
end

% Dynare settings
dynare_model = 'firstOrderDynamics_polynomials';


%% Calibrate parameters, execute initial Dynare processing

run_calib_dynare;


%% Simulate extended data

if is_data_gen
    % Run extended simulation script
    simul_data_ext;
    
    % Load the generated extended micro data
    load_mat('simul_data_micro_ext', 'simul_data_micro_ext');
    load_mat('micro_cfg_ext', 'micro_cfg');
    load_mat('micro_true_params', 'micro_true_params');
else
    % Load existing data
    load_mat('simul_data_micro_ext', 'simul_data_micro_ext');
    load_mat('micro_cfg_ext', 'micro_cfg');
end


%% Measurement error

compute_meas_err_const;


%% Log likelihood function

% Create wrapper that converts param vector to param_struct
ll_fct = @(M_, oo_, options_) ll_wrapper_ext(simul_data_micro_ext, ts_micro, micro_cfg, ...
                                              num_smooth_draws, num_burnin_periods, ...
                                              num_interp, likelihood_type, ...
                                              M_, oo_, options_);


%% Find approximate mode (optional)

if is_optimize
    approx_mode;
end


%% Run MCMC iterations

mkdir(save_folder);
mcmc_iter;


%% Save results

save_mat(fullfile(save_folder, [model_name '_ext']));

if likelihood_type == 1
    delete(poolobj);
end


%% Helper function to wrap parameter vector into struct for aux_ll_ext

function [the_loglike, the_loglike_macro, the_loglike_micro] = ...
    ll_wrapper_ext(data_micro, ts_micro, micro_cfg, ...
                   num_smooth_draws, num_burnin_periods, ...
                   num_interp, likelihood_type, ...
                   M_, oo_, options_)
    
    % Extract current parameter values from global scope
    global bbeta ssigmaMeas mu_l;
    global alpha_c_R beta_c_R gamma_c_R sigma_c_R;
    global alpha_f_R beta_f_R gamma_f_R sigma_f_R;
    global alpha_c_NR beta_c_NR gamma_c_NR sigma_c_NR;
    global alpha_f_NR beta_f_NR gamma_f_NR sigma_f_NR;
    
    % Build param_struct
    param_struct = struct();
    param_struct.alpha_c_R = alpha_c_R;
    param_struct.beta_c_R = beta_c_R;
    param_struct.gamma_c_R = gamma_c_R;
    param_struct.sigma_c_R = sigma_c_R;
    param_struct.alpha_f_R = alpha_f_R;
    param_struct.beta_f_R = beta_f_R;
    param_struct.gamma_f_R = gamma_f_R;
    param_struct.sigma_f_R = sigma_f_R;
    param_struct.alpha_c_NR = alpha_c_NR;
    param_struct.beta_c_NR = beta_c_NR;
    param_struct.gamma_c_NR = gamma_c_NR;
    param_struct.sigma_c_NR = sigma_c_NR;
    param_struct.alpha_f_NR = alpha_f_NR;
    param_struct.beta_f_NR = beta_f_NR;
    param_struct.gamma_f_NR = gamma_f_NR;
    param_struct.sigma_f_NR = sigma_f_NR;
    param_struct.micro_cfg = micro_cfg;
    
    % Call aux_ll_ext
    [the_loglike, the_loglike_macro, the_loglike_micro] = ...
        aux_ll_ext(data_micro, ts_micro, ...
                   num_smooth_draws, num_burnin_periods, ...
                   num_interp, likelihood_type, ...
                   M_, oo_, options_, ...
                   true, param_struct);
end
