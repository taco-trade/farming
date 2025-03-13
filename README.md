# Alpaca Ignition Modules

This repository contains Hardhat Ignition modules for deploying and managing smart contracts.

## Available Modules

- **Manager**: Basic manager contract deployment
- **ManagerWithProxy**: Manager contract deployment with transparent proxy pattern
- **MockToken**: Test token deployment
- **Strategies**: Collection of PancakeSwap V3 strategy contracts
- **StrategiesWithProxy**: PancakeSwap V3 strategy contracts with transparent proxy pattern

## Shell Commands

### Deploy Modules

Deploy modules using Hardhat Ignition with the following command pattern:

```shell
pnpm exec hardhat ignition deploy ./ignition/modules/<ModuleName>.ts \
  --network <network> \
  --parameters ignition/parameters.json \
  --verify \
  --deployment-id <deployment-id>
```

The `--deployment-id` flag is used to create unique deployments and track different versions of your contracts. This is particularly useful when:
- Deploying multiple instances of the same contract
- Managing different deployment environments

Example:
```shell
# Deploy Manager module
pnpm exec hardhat ignition deploy ./ignition/modules/Manager.ts \
  --network bscTestnet \
  --parameters ignition/parameters.bsctest.json \
  --verify \
  --deployment-id manager-01
```

### Parameters

All deployments require a `parameters.json` file that should include:
- `positionManager`: Address of the position manager contract
- `factory`: Address of the factory contract (for strategy deployments)
- `router`: Address of the router contract (for strategy deployments) 