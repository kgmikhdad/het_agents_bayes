# Extended Household Micro Block Documentation

## Overview

This extension adds support for richer micro data to the household model, including:
- **Type labels**: Ricardian vs Non-Ricardian household types (from clustering)
- **Consumption data**: Total consumption expenditure
- **Food consumption data**: Food consumption (level or share)
- **Variable sample sizes**: Supports different number of households per time period

The extension maintains full backward compatibility with the existing pipeline and does not modify core functionality.

## Architecture

### Key Components

#### 1. Extended Likelihood Function
**File**: `program/hh_model/auxiliary_functions/likelihood/likelihood_micro_ext.m`

Computes the joint likelihood for household observations:
```
p_i = p(eps_i | z_t) * p(y_i | eps_i, z_t) * p(c_i | y_i, eps_i, z_t, type_i) * p(food_i | c_i, y_i, eps_i, z_t, type_i)
```

- **Part 1**: Reuses the original structural income density for `(eps, y)` from `likelihood_micro.m`
  - Integrates over latent asset distribution and permanent heterogeneity
  - Uses exponential family asset density and lognormal productivity shocks
  
- **Part 2**: Adds consumption model conditional on income and type
  - Log-linear regression: `log c = alpha_c + beta_c * log y + gamma_c * eps + u_c`
  - Type-specific parameters for Ricardian and Non-Ricardian households
  
- **Part 3**: Adds food consumption model
  - Log-linear regression: `log cf = alpha_f + beta_f * log c + gamma_f * eps + u_f`
  - Type-specific parameters

**Signature**:
```matlab
likes = likelihood_micro_ext(smooth_draw_t, data_micro_t, param_struct)
```

**Inputs**:
- `smooth_draw_t`: Table row with smoothed macro variables (w, r, moments, etc.)
- `data_micro_t`: Matrix (N, num_cols) with household-level data
- `param_struct`: Struct containing all parameters (baseline + extended)

**Outputs**:
- `likes`: Vector (N, 1) of likelihood contributions

#### 2. Auxiliary Likelihood Wrapper
**File**: `program/hh_model/auxiliary_functions/likelihood/aux_ll_ext.m`

Wraps the extended likelihood and interfaces with the core likelihood engine:
- Defines smoother variables including `logAggregateConsumption`
- Packages parameters into `param_struct`
- Calls `loglike_compute` with function handle to `likelihood_micro_ext`

#### 3. Extended Simulation
**Files**: 
- `program/hh_model/auxiliary_functions/sim/simulate_micro_ext.m` (function)
- `program/hh_model/auxiliary_functions/sim/simul_data_ext.m` (script)

Generates synthetic micro data with extended variables:
- Reuses existing `simulate_micro_aux` and `simulate_micro` for `(eps, y)` generation
- Draws type labels from Bernoulli(pi_true)
- Generates consumption using type-specific measurement equations
- Generates food consumption conditional on consumption
- Returns cell array format for variable sample sizes

#### 4. Extended MCMC Script
**File**: `program/run_mcmc_hh_ext.m`

Main estimation script for the extended model:
- Defines 19 parameters: `bbeta`, `ssigmaMeas`, `mu_l`, plus 16 micro parameters
- Implements parameter transformations (logit for beta, log for sigmas)
- Sets priors for new parameters (N(0,1) for regression coefficients)
- Configures MCMC with smaller initial step size (more parameters)
- Uses wrapper function to convert parameter vector to struct

### Modified Core Files

#### loglike_compute.m (Minimal Changes)
**File**: `program/functions/likelihood/loglike_compute.m`

Backward-compatible modifications:
1. Accepts optional `micro_lik_fct` function handle argument
2. Converts 3D numeric arrays to cell arrays internally
3. Uses function handle to call likelihood function

**Key changes**:
```matlab
% Parse optional function handle (line ~27)
micro_lik_fct = @likelihood_micro; % Default
if nargin >= 11 && ~isempty(varargin) && isa(varargin{1}, 'function_handle')
    micro_lik_fct = varargin{1};
end

% Convert to cell format (line ~33)
if isnumeric(data_micro) && ndims(data_micro) == 3
    data_micro_cell = cell(size(data_micro,1), 1);
    for it = 1:size(data_micro,1)
        data_micro_cell{it} = permute(data_micro(it,:,:), [2 3 1]);
    end
    data_micro = data_micro_cell;
end

% Use function handle (line ~86)
the_likes = micro_lik_fct(the_smooth_draw_tab(it,:), data_micro{it}, param);
```

## Data Format

### Micro Configuration Structure
```matlab
micro_cfg = struct();
micro_cfg.col.type = 1;    % Column index for type (1=R, 0=NR)
micro_cfg.col.eps = 2;     % Column index for employment
micro_cfg.col.y = 3;       % Column index for income
micro_cfg.col.c = 4;       % Column index for consumption
micro_cfg.col.cf = 5;      % Column index for food consumption
micro_cfg.col.share = NaN; % Column index for food share (alternative)
micro_cfg.col.wt = NaN;    % Column index for weights (optional)
micro_cfg.use_vars = struct('income', true, 'consumption', true, 'food', true);
micro_cfg.food_mode = 'level';  % 'level' or 'share'
micro_cfg.log_mode = true;      % Use log transformations
```

### Cell Array Format
Extended micro data is stored as a cell array for variable sample sizes:
```matlab
simul_data_micro_ext = cell(T_micro, 1);
% Each cell: simul_data_micro_ext{t} is a matrix (N_t, num_cols)
% Columns: [type, eps, y, c, cf]
```

## Parameters

### Baseline Parameters (from original model)
- `bbeta`: Discount factor
- `ssigmaMeas`: Measurement error std dev
- `mu_l`: Mean of log productivity
- `aaBar`: Asset constraint
- `mmu`: Benefit level (unemployed)
- `ttau`: Tax rate (employed)

### Extended Micro Parameters

#### Ricardian Type (type = 1)
**Consumption**:
- `alpha_c_R`: Intercept in log consumption equation
- `beta_c_R`: Elasticity of consumption to income
- `gamma_c_R`: Employment effect on consumption
- `sigma_c_R`: Std dev of consumption shock

**Food**:
- `alpha_f_R`: Intercept in log food equation
- `beta_f_R`: Elasticity of food to consumption
- `gamma_f_R`: Employment effect on food
- `sigma_f_R`: Std dev of food shock

#### Non-Ricardian Type (type = 0)
Same structure as Ricardian: `alpha_c_NR`, `beta_c_NR`, `gamma_c_NR`, `sigma_c_NR`, `alpha_f_NR`, `beta_f_NR`, `gamma_f_NR`, `sigma_f_NR`

## Usage

### Running Extended Estimation

```matlab
% From program directory
run_mcmc_hh_ext
```

This will:
1. Run Dynare preprocessing
2. Simulate extended macro and micro data
3. Run MCMC estimation with extended likelihood
4. Save results to `results/` folder

### Using Extended Likelihood in Custom Code

```matlab
% Setup parameters
param_struct = struct();
param_struct.aaBar = 0.0;
param_struct.mmu = 0.15;
% ... (set all parameters)
param_struct.micro_cfg = micro_cfg;

% Call likelihood
likes = likelihood_micro_ext(smooth_draw_t, data_micro_t, param_struct);
```

### Simulating Extended Micro Data

```matlab
% After running simulate_micro_aux
simul_data_micro_ext = simulate_micro_ext(simul_data_micro_aux, sim_struct, ...
                                          ts_micro, micro_true_params, micro_cfg);
```

## Testing

Run smoke tests from the `tests/` directory:

```matlab
cd tests
test_likelihood_micro_ext  % Test extended likelihood
test_simulate_micro_ext    % Test extended simulation
```

Tests verify:
- Functions run without errors
- Output has correct dimensions
- Results are finite and positive
- Missing value handling works correctly

## Backward Compatibility

The extension is fully backward compatible:
- Original `likelihood_micro.m` is **unchanged**
- Original `aux_ll.m` is **unchanged**  
- Original `run_mcmc_hh.m` works as before
- `loglike_compute.m` handles both old (3D array) and new (cell array) formats
- Default behavior unchanged when function handle not provided

## Future Extensions

Potential enhancements (not yet implemented):
1. **Correlated shocks**: Allow `corr(u_c, u_f)` within type
2. **Misclassification**: Model for noisy type labels
3. **Mixture model**: Estimate type shares when labels unavailable
4. **Food share**: Implement logit/probit for food share
5. **Additional macro controls**: Include more smoothed variables in measurement equations
6. **Time-varying parameters**: Allow parameters to vary over time

## Files Summary

### New Files
- `program/hh_model/auxiliary_functions/likelihood/likelihood_micro_ext.m`
- `program/hh_model/auxiliary_functions/likelihood/aux_ll_ext.m`
- `program/hh_model/auxiliary_functions/sim/simulate_micro_ext.m`
- `program/hh_model/auxiliary_functions/sim/simul_data_ext.m`
- `program/run_mcmc_hh_ext.m`
- `tests/test_likelihood_micro_ext.m`
- `tests/test_simulate_micro_ext.m`
- `doc/hh_ext.md` (this file)

### Modified Files
- `program/functions/likelihood/loglike_compute.m` (backward-compatible changes)

## References

The extension follows the architecture described in:
- Winberry (2018) for asset distribution approximation
- Paper's full-information Bayesian framework for joint macro-micro inference
- Simulation smoother for numerically unbiased likelihood estimation
