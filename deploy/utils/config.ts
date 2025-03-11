import TestnetConfig from "../../config/.testnet.json";

export interface Config {
    Tokens: Tokens
    PancakeSwapV3: PancakeSwapV3
}

export interface Tokens {
    WBNB?: string
    CAKE?: string
    MockToken0?: string
    MockToken1?: string
}

export interface PancakeSwapV3 {
    NonfungiblePositionManager: string
    SwapRouter: string
    PancakeV3Factory: string
    Manager: string
    Strategies: Strategies
}

export interface Strategies {
    AddBaseTokenOnly?: string
    AddBaseTokenOnlyWithCalculate?: string
}

export function getConfig(): Config {
    return TestnetConfig
}
