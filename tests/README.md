# Tests for Extended Household Micro Block

This directory contains smoke tests for the extended micro functionality.

## Test Files

### test_likelihood_micro_ext.m
Tests the extended likelihood function `likelihood_micro_ext.m`:
- Creates fake smooth draw and micro data
- Calls the likelihood function
- Verifies output is finite, positive, and correct size
- Tests missing value handling

### test_simulate_micro_ext.m
Tests the extended simulation function `simulate_micro_ext.m`:
- Creates fake auxiliary micro data
- Calls the simulation function
- Verifies output cell array structure
- Checks data dimensions and validity

## Running Tests

### From MATLAB/Octave
```matlab
cd tests
test_likelihood_micro_ext
test_simulate_micro_ext
```

### Requirements
- MATLAB R2016b or later (or compatible Octave version)
- Path to parent `program/` directory must be added (tests do this automatically)

## Test Output

Tests print success/failure messages with diagnostic information:
- ✓ indicates test passed
- ✗ indicates test failed (with error details)

## Notes

These are **smoke tests** - they verify basic functionality but do not:
- Test integration with full MCMC pipeline
- Validate numerical accuracy
- Test all edge cases

For full integration testing, use the main estimation scripts:
- `program/run_mcmc_hh.m` (baseline)
- `program/run_mcmc_hh_ext.m` (extended)
