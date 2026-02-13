function likes = likelihood_micro_ext(smooth_draw_t, data_micro_t, param_struct)

% Extended micro likelihood for household model with consumption and food data
%
% Inputs:
%   smooth_draw_t  - Table row with smoothed macro variables (w, r, lag_mHat_*, lag_moment_*, measureCoefficient_*, logAggregateConsumption)
%   data_micro_t   - Matrix (N, num_cols) with columns defined by param_struct.micro_cfg.col
%                    Expected columns: type, eps (employment), y (income), c (consumption), cf (food consumption)
%   param_struct   - Struct with fields:
%                    - aaBar, mmu, ttau, mu_l, num_mom, num_interp (baseline params)
%                    - alpha_c_R, beta_c_R, gamma_c_R, sigma_c_R (consumption params for Ricardian)
%                    - alpha_f_R, beta_f_R, gamma_f_R, sigma_f_R (food params for Ricardian)
%                    - alpha_c_NR, beta_c_NR, gamma_c_NR, sigma_c_NR (consumption params for Non-Ricardian)
%                    - alpha_f_NR, beta_f_NR, gamma_f_NR, sigma_f_NR (food params for Non-Ricardian)
%                    - micro_cfg (struct with column indices and config)
%
% Outputs:
%   likes          - Vector (N,1) of likelihood contributions

% Extract baseline parameters
aaBar = param_struct.aaBar;
mmu = param_struct.mmu;
ttau = param_struct.ttau;
mu_l = param_struct.mu_l;
num_mom = param_struct.num_mom;
num_interp = param_struct.num_interp;

% Extract micro configuration
micro_cfg = param_struct.micro_cfg;

% Extract type-specific parameters
% Ricardian (type = 1)
alpha_c_R = param_struct.alpha_c_R;
beta_c_R = param_struct.beta_c_R;
gamma_c_R = param_struct.gamma_c_R;
sigma_c_R = param_struct.sigma_c_R;
alpha_f_R = param_struct.alpha_f_R;
beta_f_R = param_struct.beta_f_R;
gamma_f_R = param_struct.gamma_f_R;
sigma_f_R = param_struct.sigma_f_R;

% Non-Ricardian (type = 0)
alpha_c_NR = param_struct.alpha_c_NR;
beta_c_NR = param_struct.beta_c_NR;
gamma_c_NR = param_struct.gamma_c_NR;
sigma_c_NR = param_struct.sigma_c_NR;
alpha_f_NR = param_struct.alpha_f_NR;
beta_f_NR = param_struct.beta_f_NR;
gamma_f_NR = param_struct.gamma_f_NR;
sigma_f_NR = param_struct.sigma_f_NR;

% Extract macro controls if available
if ismember('logAggregateConsumption', smooth_draw_t.Properties.VariableNames)
    logAggC = smooth_draw_t{1,'logAggregateConsumption'};
else
    logAggC = 0; % Default if not available
end

% Initialize likelihood contributions
N = size(data_micro_t, 1);
likes = ones(N, 1); % Start with 1 (log-likelihood will be 0 for missing)

% Extract data columns (handle missing columns gracefully)
col = micro_cfg.col;
type_data = extract_column(data_micro_t, col.type);
eps_data = extract_column(data_micro_t, col.eps);
y_data = extract_column(data_micro_t, col.y);
c_data = extract_column(data_micro_t, col.c);
cf_data = extract_column(data_micro_t, col.cf);

%% Part 1: Employment and Income likelihood (reuse original likelihood_micro logic)

if micro_cfg.use_vars.income
    for eepsilon = 0:1 % For each employment status...
        
        ix = (eps_data == eepsilon) & isfinite(eps_data) & isfinite(y_data); % Valid observations
        
        if sum(ix) == 0
            continue;
        end
        
        % Collect distribution parameters from smoother
        moment = smooth_draw_t{1, str_add_numbers(sprintf('%s%d%s', 'lag_moment_', eepsilon+1, '_'), 1:num_mom)};
        measureCoefficient = smooth_draw_t{1, str_add_numbers(sprintf('%s%d%s', 'measureCoefficient_', eepsilon+1, '_'), 1:num_mom)};
        mHat = smooth_draw_t{1, sprintf('%s%d', 'lag_mHat_', eepsilon+1)};
        
        % Compute normalization constant for asset density
        moment_aux = moment;
        moment_aux(1) = 0;
        g_log = @(a) measureCoefficient*((a-moment(1)).^((1:num_mom)')-moment_aux');
        lastwarn('');
        normalization = integral(@(a) exp(g_log(a)), aaBar, Inf);
        warnMsg = lastwarn;
        if ~isempty(warnMsg)
            warning('Improper asset density for epsilon=%d', eepsilon);
            likes(ix) = eps; % Set to small value
            continue;
        end
        
        % Income parameters
        c = smooth_draw_t{1,'w'}*((1-eepsilon)*mmu+eepsilon*(1-ttau));
        R = smooth_draw_t{1,'r'};
        if R <= 0
            warning('R=%8.4f', R);
            R = eps; % Avoid numerical issues
        end
        
        sigma2 = -2*mu_l;
        
        % Compute income likelihood via grid interpolation
        y_ix = y_data(ix);
        if any(y_ix <= 0)
            warning('Non-positive income values detected');
            y_ix = max(y_ix, eps);
        end
        
        vals = linspace(min(log(y_ix)), max(log(y_ix)), num_interp);
        ints = zeros(1, num_interp);
        for i_in = 1:num_interp
            ints(i_in) = integral(@(a) exp(g_log(a) ...
                -(0.5/sigma2)*((vals(i_in)-mu_l)-log(c+R*a)).^2), ...
                aaBar, Inf);
        end
        
        income_likes = interp1(vals, ints, log(y_ix), 'pchip');
        income_likes = (income_likes ./ y_ix) * ((1-mHat)/(normalization*sqrt(2*pi*sigma2)));
        
        % Add point mass contribution
        income_likes = max(income_likes ...
            + (mHat/sqrt(2*pi*sigma2))*exp(-0.5/sigma2*(log(y_ix)-log(c+R*aaBar)-mu_l).^2)./y_ix, ...
            eps);
        
        likes(ix) = likes(ix) .* income_likes;
    end
end

%% Part 2: Consumption likelihood conditional on income and type

if micro_cfg.use_vars.consumption
    % Valid observations with type, employment, income, and consumption
    ix_valid = isfinite(type_data) & isfinite(eps_data) & isfinite(y_data) & isfinite(c_data) & c_data > 0 & y_data > 0;
    
    if sum(ix_valid) > 0
        % For each type
        for type_val = 0:1
            ix_type = ix_valid & (type_data == type_val);
            
            if sum(ix_type) == 0
                continue;
            end
            
            % Select type-specific parameters
            if type_val == 1 % Ricardian
                alpha_c = alpha_c_R;
                beta_c = beta_c_R;
                gamma_c = gamma_c_R;
                sigma_c = sigma_c_R;
            else % Non-Ricardian
                alpha_c = alpha_c_NR;
                beta_c = beta_c_NR;
                gamma_c = gamma_c_NR;
                sigma_c = sigma_c_NR;
            end
            
            % Log-linear consumption model: log(c) = alpha + beta*log(y) + gamma*eps + delta*macro + u
            log_c_obs = log(c_data(ix_type));
            log_y_obs = log(y_data(ix_type));
            eps_obs = eps_data(ix_type);
            
            % Predicted log consumption (can add macro controls here)
            log_c_pred = alpha_c + beta_c * log_y_obs + gamma_c * eps_obs;
            % Could add: + delta_c * logAggC (if estimated)
            
            % Normal density for log consumption
            consumption_likes = normpdf(log_c_obs, log_c_pred, sigma_c);
            consumption_likes = max(consumption_likes, eps); % Clamp to avoid log(0)
            
            likes(ix_type) = likes(ix_type) .* consumption_likes;
        end
    end
end

%% Part 3: Food consumption likelihood conditional on consumption and type

if micro_cfg.use_vars.food
    if strcmp(micro_cfg.food_mode, 'level')
        % Food level: log(cf) = alpha_f + beta_f*log(c) + gamma_f*eps + u_f
        ix_valid = isfinite(type_data) & isfinite(eps_data) & isfinite(c_data) & isfinite(cf_data) & cf_data > 0 & c_data > 0;
        
        if sum(ix_valid) > 0
            for type_val = 0:1
                ix_type = ix_valid & (type_data == type_val);
                
                if sum(ix_type) == 0
                    continue;
                end
                
                if type_val == 1
                    alpha_f = alpha_f_R;
                    beta_f = beta_f_R;
                    gamma_f = gamma_f_R;
                    sigma_f = sigma_f_R;
                else
                    alpha_f = alpha_f_NR;
                    beta_f = beta_f_NR;
                    gamma_f = gamma_f_NR;
                    sigma_f = sigma_f_NR;
                end
                
                log_cf_obs = log(cf_data(ix_type));
                log_c_obs = log(c_data(ix_type));
                eps_obs = eps_data(ix_type);
                
                log_cf_pred = alpha_f + beta_f * log_c_obs + gamma_f * eps_obs;
                
                food_likes = normpdf(log_cf_obs, log_cf_pred, sigma_f);
                food_likes = max(food_likes, eps);
                
                likes(ix_type) = likes(ix_type) .* food_likes;
            end
        end
    else
        % Food share mode: could implement logit or similar
        % For now, skip or implement as needed
        warning('Food share mode not yet implemented');
    end
end

% Final safeguard
likes = max(likes, eps);

end

%% Helper function to extract column from data
function col_data = extract_column(data_micro_t, col_idx)
    if isnan(col_idx) || col_idx < 1 || col_idx > size(data_micro_t, 2)
        col_data = nan(size(data_micro_t, 1), 1);
    else
        col_data = data_micro_t(:, col_idx);
    end
end
