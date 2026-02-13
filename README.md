# Estimation of heterogeneous agent models using macro and micro data

Matlab code for full-information Bayesian inference in heterogeneous agent models using both (i) macro time series data and (ii) repeated cross sections of micro data

**Reference:**
[Liu, Laura](https://laurayuliu.com/), and [Mikkel Plagborg-Møller](https://www.mikkelpm.com) (2022), "Full-Information Estimation of Heterogeneous Agent Models Using Macro and Micro Data", [arXiv:2101.04771](https://arxiv.org/abs/2101.04771)

**Requirements:**
[Dynare](https://www.dynare.org/) version 4.6.x

Tested in: Matlab R2020a on Windows 10 PC and Linux servers (64-bit) with Dynare 4.6.1

## Contents

**[doc](doc):** documentation
- [hh.md](doc/hh.md): documentation of code for heterogeneous household model
- [hh_ext.md](doc/hh_ext.md): documentation of **extended household model** with richer micro data
- [firm.md](doc/firm.md): documentation of code for heterogeneous firm model

**[program](program):** Matlab routines
- [run_mcmc_hh.m](program/run_mcmc_hh.m): simulate and estimate heterogeneous household model
- [run_mcmc_hh_ext.m](program/run_mcmc_hh_ext.m): **extended estimation** with type labels, consumption, and food data
- [run_mcmc_firm.m](program/run_mcmc_firm.m): simulate and estimate heterogeneous firm model
- [plot_mcmc.m](program/plot_mcmc.m): plot estimation output
- [run_likelihood_hh.m](program/run_likelihood_hh.m): compute likelihood functions (for various observables) in heterogeneous household model
- [plot_likelihood.m](program/plot_likelihood.m): plot likelihood functions

**[program/functions](program/functions):** general functions for MCMC, likelihood evaluation, simulations, and plotting
- [likelihood/loglike_compute.m](program/functions/likelihood/loglike_compute.m): main function for numerically unbiased likelihood estimate (supports both baseline and extended formats)

**[program/hh_model](program/hh_model):** files specific to the heterogeneous household model
- [dynare](program/hh_model/dynare): sub-folder with Dynare model files adapted from Winberry (2018)
- [auxiliary_functions/likelihood/likelihood_micro.m](program/hh_model/auxiliary_functions/likelihood/likelihood_micro.m): micro likelihood function (baseline)
- [auxiliary_functions/likelihood/likelihood_micro_ext.m](program/hh_model/auxiliary_functions/likelihood/likelihood_micro_ext.m): **extended micro likelihood** with consumption and food
- [auxiliary_functions/sim/simulate_micro_ext.m](program/hh_model/auxiliary_functions/sim/simulate_micro_ext.m): **extended micro simulation**

**[program/firm_model](program/firm_model):** files specific to the heterogeneous firm model
- [dynare](program/firm_model/dynare): sub-folder with Dynare model files adapted from Winberry (2018)
- [auxiliary_functions/likelihood/likelihood_micro.m](program/firm_model/auxiliary_functions/likelihood/likelihood_micro.m): micro likelihood function

**[tests](tests):** test files for extended functionality
- [test_likelihood_micro_ext.m](tests/test_likelihood_micro_ext.m): smoke test for extended likelihood
- [test_simulate_micro_ext.m](tests/test_simulate_micro_ext.m): smoke test for extended simulation
- [README.md](tests/README.md): testing documentation

## Extended Household Model

The repository now includes an **extension** to the household model that supports:
- **Type labels**: Ricardian vs Non-Ricardian household classifications
- **Consumption data**: Total consumption expenditure
- **Food consumption**: Food consumption (level or share)
- **Variable sample sizes**: Different numbers of households per time period

The extension is **fully backward compatible** - all original functionality remains unchanged.

### Quick Start with Extended Model
```matlab
cd program
run_mcmc_hh_ext  % Run extended estimation
```

See [doc/hh_ext.md](doc/hh_ext.md) for detailed documentation.

## Acknowledgements

We build on the excellent Dynare code kindly made available by [Thomas Winberry](http://www.thomaswinberry.com/research/index.html) (see also [Winberry, QE 2018](https://qeconomics.org/ojs/index.php/qe/article/view/617)).

Plagborg-Møller acknowledges that this material is based upon work supported by the National Science Foundation under Grant #1851665.
