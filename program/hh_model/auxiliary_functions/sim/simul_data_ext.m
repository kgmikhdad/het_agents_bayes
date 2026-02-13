% Simulate extended macro and micro data with type labels, consumption, and food consumption

% Simulate macro data (same as original)
sim_struct = simulate_model(T, num_burnin_periods, M_, oo_, options_);
for i_Epsilon = 1:nEpsilon
    for i_Measure = 1:nMeasure
        sim_struct.(sprintf('%s%d%d', 'smpl_m', i_Epsilon, i_Measure)) = nan(T,1); 
    end
end

% Add measurement error to aggregate output
sim_struct.logAggregateOutput_noerror = sim_struct.logAggregateOutput;
sim_struct.logAggregateOutput = sim_struct.logAggregateOutput + ssigmaMeas*randn(T,1);
save_mat('simul', '-struct', 'sim_struct');

% Draw normalized individual incomes (employment + assets)
simul_data_micro_aux = simulate_micro_aux(sim_struct, ts_micro, N_micro);

% Draw individual productivities and incomes
simul_data_micro_base = simulate_micro(simul_data_micro_aux);
save_mat('simul_data_micro', 'simul_data_micro_base');

% Define micro configuration
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

% Define true micro parameters for data generation
micro_true_params = struct();
micro_true_params.pi_true = 0.6;  % 60% Ricardian

% Ricardian consumption parameters
micro_true_params.alpha_c_R = -0.5;
micro_true_params.beta_c_R = 0.9;
micro_true_params.gamma_c_R = 0.1;
micro_true_params.sigma_c_R = 0.15;

% Ricardian food parameters
micro_true_params.alpha_f_R = -1.0;
micro_true_params.beta_f_R = 0.8;
micro_true_params.gamma_f_R = 0.05;
micro_true_params.sigma_f_R = 0.2;

% Non-Ricardian consumption parameters
micro_true_params.alpha_c_NR = -0.3;
micro_true_params.beta_c_NR = 0.95;
micro_true_params.gamma_c_NR = 0.15;
micro_true_params.sigma_c_NR = 0.2;

% Non-Ricardian food parameters
micro_true_params.alpha_f_NR = -0.8;
micro_true_params.beta_f_NR = 0.75;
micro_true_params.gamma_f_NR = 0.08;
micro_true_params.sigma_f_NR = 0.25;

% Generate extended micro data
simul_data_micro_ext = simulate_micro_ext(simul_data_micro_aux, sim_struct, ts_micro, micro_true_params, micro_cfg);
save_mat('simul_data_micro_ext', 'simul_data_micro_ext');

% Also save configuration and true parameters
save_mat('micro_cfg_ext', 'micro_cfg');
save_mat('micro_true_params', 'micro_true_params');

disp('Extended micro data simulation complete and saved.');
