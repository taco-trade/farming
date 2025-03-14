/**
 * Gets the deployed addresses file for a specific chain ID
 * @param chainId The chain ID to get addresses for
 * @returns The deployed addresses for the specified chain
 * @throws Error if no deployment file exists for the chain ID
 */
function getDeployedAddressesForChain(chainId: number) {
    try {
        // Dynamic import of the JSON file based on chain ID
        const addresses = require(`../../ignition/deployments/chain-${chainId}/deployed_addresses.json`);
        return addresses;
    } catch (error) {
        throw new Error(`No deployment addresses found for chain ID: ${chainId}`);
    }
}

/**
 * Gets the deployed address for a specific contract on a specific chain
 * @param contractName The name of the contract
 * @param chainId The chain ID where the contract is deployed
 * @returns The deployed address of the contract
 * @throws Error if the contract name is not found or if chain ID is invalid
 */
export function getDeployedAddress(contractName: string, chainId: number): string {
    const deployedAddresses = getDeployedAddressesForChain(chainId);
    const address = deployedAddresses[contractName];
    if (!address) {
        throw new Error(`No deployed address found for contract: ${contractName} on chain: ${chainId}`);
    }
    return address;
}

type ModuleContractKey = `${string}#${string}`;

/**
 * Creates a properly formatted key for accessing deployed addresses
 * @param moduleName The name of the module
 * @param contractName The name of the contract
 * @returns Formatted string key (e.g., "ModuleName#ContractName")
 */
export function createContractKey(moduleName: string, contractName: string): ModuleContractKey {
    return `${moduleName}#${contractName}`;
}

/**
 * Gets the deployed address for a specific contract on a specific chain
 * @param moduleName The name of the module
 * @param contractName The name of the contract
 * @param chainId The chain ID where the contract is deployed
 * @returns The deployed address of the contract
 */
export function getDeployedAddressByModule(
    moduleName: string,
    contractName: string,
    chainId: number
): string {
    const key = createContractKey(moduleName, contractName);
    return getDeployedAddress(key, chainId);
}

/**
 * Gets all deployed contract addresses grouped by module
 * @param chainId The chain ID to get all addresses for
 * @returns An object containing addresses grouped by module
 */
export function getGroupedDeployedAddresses(chainId: number): Record<string, Record<string, string>> {
    const addresses = getDeployedAddressesForChain(chainId);
    const grouped: Record<string, Record<string, string>> = {};

    Object.entries(addresses).forEach(([key, address]) => {
        const [moduleName, contractName] = key.split('#');
        if (!grouped[moduleName]) {
            grouped[moduleName] = {};
        }
        grouped[moduleName][contractName] = address as string;
    });

    return grouped;
}
