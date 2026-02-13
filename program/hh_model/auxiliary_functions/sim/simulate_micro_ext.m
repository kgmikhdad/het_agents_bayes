function simul_data_micro_ext = simulate_micro_ext(simul_data_micro_aux, sim_struct, ts_micro, micro_true_params, micro_cfg)

% Extended micro data simulation with type labels, consumption, and food consumption
%
% Inputs:
%   simul_data_micro_aux - Output from simulate_micro_aux: (T_micro, N_micro, 3) = [eps, y_normalized, assets]
%   sim_struct           - Struct with simulated macro variables
%   ts_micro             - Time periods for micro data
%   micro_true_params    - Struct with true parameters for data generation:
%                          .pi_true (type share for Ricardian)
%                          .alpha_c_R, .beta_c_R, .gamma_c_R, .sigma_c_R
%                          .alpha_f_R, .beta_f_R, .gamma_f_R, .sigma_f_R
%                          .alpha_c_NR, .beta_c_NR, .gamma_c_NR, .sigma_c_NR
%                          .alpha_f_NR, .beta_f_NR, .gamma_f_NR, .sigma_f_NR
%   micro_cfg            - Struct with configuration (column indices, etc.)
%
% Outputs:
%   simul_data_micro_ext - Cell array (T_micro, 1), each cell is (N_t, num_cols) with columns:
%                          [type, eps, y, c, cf] (based on micro_cfg.col)

global mu_l;

disp('Simulating extended household data (type, employment, income, consumption, food)...');

T_micro = length(ts_micro);
simul_data_micro_ext = cell(T_micro, 1);

% First generate base micro data with employment and income using existing functions
simul_data_micro_base = simulate_micro(simul_data_micro_aux);
% simul_data_micro_base is (T_micro, N_micro, 2) with [eps, y]

[T_micro_check, N_micro, ~] = size(simul_data_micro_base);
if T_micro_check ~= T_micro
    error('Dimension mismatch in micro data');
end

% Extract true parameters
pi_true = micro_true_params.pi_true;
alpha_c_R = micro_true_params.alpha_c_R;
beta_c_R = micro_true_params.beta_c_R;
gamma_c_R = micro_true_params.gamma_c_R;
sigma_c_R = micro_true_params.sigma_c_R;
alpha_f_R = micro_true_params.alpha_f_R;
beta_f_R = micro_true_params.beta_f_R;
gamma_f_R = micro_true_params.gamma_f_R;
sigma_f_R = micro_true_params.sigma_f_R;

alpha_c_NR = micro_true_params.alpha_c_NR;
beta_c_NR = micro_true_params.beta_c_NR;
gamma_c_NR = micro_true_params.gamma_c_NR;
sigma_c_NR = micro_true_params.sigma_c_NR;
alpha_f_NR = micro_true_params.alpha_f_NR;
beta_f_NR = micro_true_params.beta_f_NR;
gamma_f_NR = micro_true_params.gamma_f_NR;
sigma_f_NR = micro_true_params.sigma_f_NR;

for it = 1:T_micro
    t = ts_micro(it);
    fprintf('t = %4d\n', t);
    
    % Extract employment and income from base simulation
    eps_it = simul_data_micro_base(it, :, 1)';  % (N_micro, 1)
    y_it = simul_data_micro_base(it, :, 2)';    % (N_micro, 1)
    
    % Generate type labels (Bernoulli)
    type_it = (rand(N_micro, 1) < pi_true) + 0;  % 1 = Ricardian, 0 = Non-Ricardian
    
    % Get aggregate consumption for macro control (optional)
    if isfield(sim_struct, 'logAggregateConsumption')
        logAggC_t = sim_struct.logAggregateConsumption(t);
    else
        logAggC_t = 0;
    end
    
    % Initialize consumption and food
    c_it = nan(N_micro, 1);
    cf_it = nan(N_micro, 1);
    
    % Generate consumption for each type
    for type_val = 0:1
        ix_type = (type_it == type_val);
        n_type = sum(ix_type);
        
        if n_type == 0
            continue;
        end
        
        % Select type-specific parameters
        if type_val == 1  % Ricardian
            alpha_c = alpha_c_R;
            beta_c = beta_c_R;
            gamma_c = gamma_c_R;
            sigma_c = sigma_c_R;
            alpha_f = alpha_f_R;
            beta_f = beta_f_R;
            gamma_f = gamma_f_R;
            sigma_f = sigma_f_R;
        else  % Non-Ricardian
            alpha_c = alpha_c_NR;
            beta_c = beta_c_NR;
            gamma_c = gamma_c_NR;
            sigma_c = sigma_c_NR;
            alpha_f = alpha_f_NR;
            beta_f = beta_f_NR;
            gamma_f = gamma_f_NR;
            sigma_f = sigma_f_NR;
        end
        
        % Generate consumption: log(c) = alpha + beta*log(y) + gamma*eps + u
        log_y_type = log(y_it(ix_type));
        eps_type = eps_it(ix_type);
        u_c = sigma_c * randn(n_type, 1);
        log_c_type = alpha_c + beta_c * log_y_type + gamma_c * eps_type + u_c;
        c_it(ix_type) = exp(log_c_type);
        
        % Generate food consumption: log(cf) = alpha_f + beta_f*log(c) + gamma_f*eps + u_f
        u_f = sigma_f * randn(n_type, 1);
        log_cf_type = alpha_f + beta_f * log_c_type + gamma_f * eps_type + u_f;
        cf_it(ix_type) = exp(log_cf_type);
    end
    
    % Assemble data matrix with columns: [type, eps, y, c, cf]
    data_it = [type_it, eps_it, y_it, c_it, cf_it];
    
    simul_data_micro_ext{it} = data_it;
end

disp('Extended micro data simulation complete.');

end
