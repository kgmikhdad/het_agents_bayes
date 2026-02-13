function [the_loglike, the_loglike_macro, the_loglike_micro] = ...
         aux_ll_ext(data_micro, ts_micro, ...
                num_smooth_draws, num_burnin_periods, ...
                num_interp, likelihood_type, ...
                M_, oo_, options_, ...
                update_param, param_struct, varargin)
			
% Extended auxiliary likelihood for household model with richer micro data
% Handles type labels, consumption, and food consumption in addition to employment and income

global mat_suff;

saveParameters;         % Save parameter values to files
if update_param
    setDynareParameters;    % Update Dynare parameters in model struct
    compute_steady_state;   % Compute steady state
end
compute_meas_err;       % Update measurement error

% Macro state variables used in micro likelihood
num_mom = 3;
smooth_vars = [{'w'; 'r'; 'lag_mHat_1' ; 'lag_mHat_2'};
               str_add_numbers('lag_moment_1_', 1:num_mom);
               str_add_numbers('lag_moment_2_', 1:num_mom);
               str_add_numbers('measureCoefficient_1_', 1:num_mom);
               str_add_numbers('measureCoefficient_2_', 1:num_mom);
               {'logAggregateConsumption'}]; % Add aggregate consumption for extended model

% Add baseline parameters to param_struct
param_struct.aaBar = aaBar;
param_struct.mmu = mmu;
param_struct.ttau = ttau;
param_struct.mu_l = mu_l;
param_struct.num_mom = num_mom;
param_struct.num_interp = num_interp;

% Create function handle for extended likelihood
micro_lik_fct = @(smooth_draw_t, data_micro_t, param) likelihood_micro_ext(smooth_draw_t, data_micro_t, param);

% Log likelihood computation
switch likelihood_type
    case 1 % Macro + full info micro (extended)
        [the_loglike, the_loglike_macro, the_loglike_micro] = ...
            loglike_compute(strcat('simul', mat_suff, '.mat'), ...
                           num_burnin_periods, smooth_vars, num_smooth_draws, ...
                           M_, oo_, options_, ...
                           data_micro, ts_micro, param_struct, ...
                           micro_lik_fct, varargin{:});
    case 2 % Macro only
        [the_loglike, the_loglike_macro, the_loglike_micro] = ...
            loglike_compute(strcat('simul', mat_suff, '.mat'), ...
                           num_burnin_periods, smooth_vars, 0, ...
                           M_, oo_, options_, ...
                           [], [], param_struct);
    case 6 % Extended micro with moments (if needed later)
        [the_loglike, the_loglike_macro, the_loglike_micro] = ...
            loglike_compute(strcat('simul_moments', mat_suff, '.mat'), ...
                           num_burnin_periods, smooth_vars, 0, ...
                           M_, oo_, options_, ...
                           [], [], param_struct);
end

end
