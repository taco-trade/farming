# Farming

This repository contains Hardhat Ignition modules for deploying and managing smart contracts.

## Available Modules

### Core Deployment Modules
- **Manager**: Basic manager contract deployment
- **ManagerWithProxy**: Manager contract deployment with transparent proxy pattern and UserVaultFactory
- **MockToken**: Test token deployment for development and testing
- **UniswapV3Strategies**: Collection of UniswapV3 strategy contracts with transparent proxy pattern

### Upgrade Modules
- **ManagerUpgrade**: Upgrade existing Manager contract implementations
- **UpgradeUserVault**: Upgrade UserVault beacon implementation for all user vaults
- **UpgradeStrategies**: Upgrade existing strategy contract implementations

## Quick Deploy Scripts

The project includes pre-configured deployment scripts in `package.json` for major networks:

### Ethereum Mainnet
```shell
# Deploy Manager with Proxy
pnpm run deploy:eth:manager

# Deploy UniswapV3 Strategies
pnpm run deploy:eth:strategies:uniswapv3
```

### Base Network
```shell
# Deploy Manager with Proxy
pnpm run deploy:base:manager

# Deploy UniswapV3 Strategies
pnpm run deploy:base:strategies:uniswapv3
```

## Shell Commands

### Deploy Modules

Deploy modules using Hardhat Ignition with the following command pattern:

```shell
pnpm exec hardhat ignition deploy ./ignition/modules/<ModuleName>.ts \
  --network <network> \
  --parameters ignition/parameters.<network>.json \
  --verify \
  --deployment-id <deployment-id>
```

The `--deployment-id` flag is used to create unique deployments and track different versions of your contracts. This is particularly useful when:
- Deploying multiple instances of the same contract
- Managing different deployment environments

Example:
```shell
# Deploy Manager module
pnpm exec hardhat ignition deploy ./ignition/modules/ManagerWithProxy.ts \
  --network base \
  --parameters ignition/parameters.base.json \
  --verify \
  --deployment-id manager-01
```

### Parameters

All deployments require network-specific parameter files:
- `ignition/parameters.eth.json` - Ethereum mainnet parameters
- `ignition/parameters.base.json` - Base network parameters

Parameters should include:
- `positionManager`: Address of the UniswapV3 position manager contract
- `factory`: Address of the UniswapV3 factory contract (for strategy deployments)
- `router`: Address of the UniswapV3 router contract (for strategy deployments)
- `ManagerProxy`: Address of deployed manager proxy (for upgrade modules)
- `ManagerProxyAdmin`: Address of manager proxy admin (for upgrade modules)
- `UserVaultFactory`: Address of UserVaultFactory beacon (for vault upgrades)

## Contract Architecture

### Proxy Pattern Overview

This project implements the Beacon Proxy pattern for upgradeable user vaults, consisting of three main components:

1. **Manager Contract**: The entry point for users to create and interact with their vaults
2. **UserVaultFactory**: An UpgradeableBeacon contract that holds the implementation address
3. **UserVault**: The implementation contract for user-specific vaults

### Strategy Contracts

The UniswapV3Strategies module deploys six different strategy contracts, each with transparent proxy pattern:

1. **UniswapV3Mint**: Strategy for minting new positions without any calculation or token swap
2. **UniswapV3StrategyAddBaseTokenOnly**: Strategy for minting new positions using a single type of token
3. **UniswapV3DecreaseLiquidity**: Strategy for decreasing position liquidity
4. **UniswapV3ZapMint**: Strategy for zap minting using any amount of two tokens
5. **UniswapV3AddLiquidity**: Strategy for adding liquidity to existing positions
6. **UniswapV3Collect**: Strategy for collecting fees from positions

### Deployment Flow

1. Deploy the initial `UserVault` implementation contract
2. Deploy `UserVaultFactory` with:
   - The `UserVault` implementation address
   - The owner address who can upgrade the implementation
3. Deploy `Manager` contract with:
   - Owner address
   - The deployed `UserVaultFactory` address
4. Deploy UniswapV3 strategy contracts with transparent proxies
5. Approve strategies in the Manager contract

### User Vault Creation Process

1. User calls `createUserVault()` on the Manager contract
2. Manager calls `UserVaultFactory.createUserVault()`
3. UserVaultFactory deploys a new BeaconProxy that:
   - Points to the UserVaultFactory (Beacon) for its implementation
   - Initializes with the user's address and manager's address

### Upgradeability

#### Beacon Proxy Pattern (User Vaults)
The Beacon Proxy pattern allows for upgrading all user vaults simultaneously:

1. Deploy new `UserVault` implementation
2. Use `UpgradeUserVault` module to upgrade the beacon
3. All existing and future user vaults will use the new implementation

#### Transparent Proxy Pattern (Manager & Strategies)
Individual contracts can be upgraded using their respective upgrade modules:

1. Deploy new implementation contract
2. Use appropriate upgrade module (`ManagerUpgrade`, `UpgradeStrategies`)
3. The proxy will point to the new implementation

### Example Deployment Commands

```shell
# 1. Deploy Manager with UserVaultFactory and UserVault implementation
pnpm exec hardhat ignition deploy ./ignition/modules/ManagerWithProxy.ts \
  --network base \
  --parameters ignition/parameters.base.json \
  --verify \
  --deployment-id manager-01

# 2. Deploy UniswapV3 Strategies
pnpm exec hardhat ignition deploy ./ignition/modules/UniswapV3Strategies.ts \
  --network base \
  --parameters ignition/parameters.base.json \
  --verify \
  --deployment-id strategies-01

# 3. Upgrade Manager (if needed)
pnpm exec hardhat ignition deploy ./ignition/modules/ManagerUpgrade.ts \
  --network base \
  --parameters ignition/parameters.base.json \
  --verify \
  --deployment-id manager-upgrade-01
```
