# XAlpaca Ignition Modules

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


## deployments

## Contract Architecture

### Proxy Pattern Overview

This project implements the Beacon Proxy pattern for upgradeable user vaults, consisting of three main components:

1. **Manager Contract**: The entry point for users to create and interact with their vaults
2. **UserVaultFactory**: An UpgradeableBeacon contract that holds the implementation address
3. **UserVault**: The implementation contract for user-specific vaults

### Deployment Flow

1. Deploy the initial `UserVault` implementation contract
2. Deploy `UserVaultFactory` with:
   - The `UserVault` implementation address
   - The owner address who can upgrade the implementation
3. Deploy `Manager` contract with:
   - Owner address
   - NFT Position Manager address
   - The deployed `UserVaultFactory` address

### User Vault Creation Process

1. User calls `createUserVault()` on the Manager contract
2. Manager calls `UserVaultFactory.createUserVault()`
3. UserVaultFactory deploys a new BeaconProxy that:
   - Points to the UserVaultFactory (Beacon) for its implementation
   - Initializes with the user's address and manager's address

### Upgradeability

The Beacon Proxy pattern allows for upgrading all user vaults simultaneously:

1. Deploy new `UserVault` implementation
2. Owner calls `upgradeTo(newImplementation)` on UserVaultFactory
3. All existing and future user vaults will use the new implementation

### Example Deployment Commands

```shell
# 1. Deploy UserVault implementation
pnpm exec hardhat ignition deploy ./ignition/modules/UserVault.ts \
  --network <network> \
  --verify \
  --deployment-id vault-impl-01

# 2. Deploy UserVaultFactory with implementation
pnpm exec hardhat ignition deploy ./ignition/modules/UserVaultFactory.ts \
  --network <network> \
  --parameters ignition/parameters.json \
  --verify \
  --deployment-id vault-factory-01

# 3. Deploy Manager
pnpm exec hardhat ignition deploy ./ignition/modules/Manager.ts \
  --network <network> \
  --parameters ignition/parameters.json \
  --verify \
  --deployment-id manager-01
```
