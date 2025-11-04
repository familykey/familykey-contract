// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "../src/TrustFreezeGuard.sol";

/**
 * @title DeployTrustFreezeGuard
 * @notice Deployment script for TrustFreezeGuard
 * @dev Deploys a stateless guard contract that can be used by multiple Safes.
 *      The guard freezes Owner operations while allowing Module operations to continue.
 *
 * Usage:
 *   forge script script/DeployTrustFreezeGuard.s.sol:DeployTrustFreezeGuard \
 *     --rpc-url $RPC_URL --broadcast --verify
 *
 * Environment variables required:
 *   - RPC_URL: The RPC endpoint URL
 *   - PRIVATE_KEY: Deployer private key (automatically loaded by foundry)
 *   - ETHERSCAN_API_KEY: For contract verification (optional)
 *
 * Post-deployment steps:
 *   1. Verify the contract on block explorer
 *   2. Update frontend configuration with the guard address
 *   3. For each Safe that wants to use the guard:
 *      a. Call Safe.setGuard(guardAddress) via Safe transaction
 *      b. Call TrustFreezeGuard.freezeUntil(timestamp) via Safe transaction
 */
contract DeployTrustFreezeGuard is Script {
    function run() external {
        // Load deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("===========================================");
        console.log("TrustFreezeGuard Deployment Script");
        console.log("===========================================");
        console.log("");
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance / 1e18, "ETH");
        console.log("Chain ID:", block.chainid);
        console.log("Block number:", block.number);
        console.log("");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy TrustFreezeGuard
        TrustFreezeGuard guard = new TrustFreezeGuard();

        console.log("===========================================");
        console.log("Deployment Successful!");
        console.log("===========================================");
        console.log("");
        console.log("TrustFreezeGuard Address:", address(guard));
        console.log("");
        console.log("===========================================");
        console.log("Integration Instructions:");
        console.log("===========================================");
        console.log("");
        console.log("1. Verify contract on block explorer:");
        console.log("   forge verify-contract %s TrustFreezeGuard --watch", address(guard));
        console.log("");
        console.log("2. Update frontend configuration:");
        console.log("   VITE_TRUST_FREEZE_GUARD_ADDRESS=%s", address(guard));
        console.log("");
        console.log("3. To enable guard on a Safe:");
        console.log("   a. Safe owners sign transaction:");
        console.log("      Safe.setGuard(%s)", address(guard));
        console.log("   b. Safe owners sign transaction to set freeze period:");
        console.log("      Safe.execTransaction(");
        console.log("        to: %s,", address(guard));
        console.log("        data: freezeUntil(timestamp),");
        console.log("        operation: CALL");
        console.log("      )");
        console.log("");
        console.log("4. Verify integration:");
        console.log("   - Check Safe.getGuard() returns:", address(guard));
        console.log("   - Check TrustFreezeGuard.isFrozen(safeAddress)");
        console.log("   - Try Owner transaction (should fail if frozen)");
        console.log("   - Try Module transaction (should succeed even if frozen)");
        console.log("");

        vm.stopBroadcast();

        // Save deployment info to file
        string memory deploymentInfo = string(
            abi.encodePacked(
                "{\n",
                '  "contract": "TrustFreezeGuard",\n',
                '  "address": "',
                vm.toString(address(guard)),
                '",\n',
                '  "chainId": ',
                vm.toString(block.chainid),
                ',\n',
                '  "deployer": "',
                vm.toString(deployer),
                '",\n',
                '  "blockNumber": ',
                vm.toString(block.number),
                ',\n',
                '  "timestamp": ',
                vm.toString(block.timestamp),
                ',\n',
                '  "network": "',
                getNetworkName(block.chainid),
                '"\n',
                "}"
            )
        );

        // Write deployment info to file
        // Note: The deployments directory must exist, or fs_permissions must allow creation
        string memory filename = string(
            abi.encodePacked(
                "./deployments/trustfreezeguard-",
                vm.toString(block.chainid),
                "-latest.json"
            )
        );

        try vm.writeFile(filename, deploymentInfo) {
            console.log("Deployment info saved to:", filename);
        } catch {
            console.log("Warning: Could not save deployment info to file");
            console.log("Please ensure ./deployments directory exists");
        }
        console.log("");
        console.log("===========================================");
        console.log("Guard Features:");
        console.log("===========================================");
        console.log("- Freezes Owner transactions during trust period");
        console.log("- Allows Module transactions (inheritance) to continue");
        console.log("- Stateless design - one guard for all Safes");
        console.log("- Gas efficient - single timestamp comparison");
        console.log("- Follows Safe official Guard patterns");
        console.log("- ERC165 compliant");
        console.log("");
    }

    /**
     * @notice Get human-readable network name from chain ID
     * @param chainId The chain ID
     * @return Network name
     */
    function getNetworkName(uint256 chainId) internal pure returns (string memory) {
        if (chainId == 1) return "ethereum-mainnet";
        if (chainId == 5) return "goerli";
        if (chainId == 11155111) return "sepolia";
        if (chainId == 8453) return "base-mainnet";
        if (chainId == 84532) return "base-sepolia";
        if (chainId == 17000) return "holesky";
        if (chainId == 42161) return "arbitrum-mainnet";
        if (chainId == 421614) return "arbitrum-sepolia";
        if (chainId == 10) return "optimism-mainnet";
        if (chainId == 11155420) return "optimism-sepolia";
        if (chainId == 137) return "polygon-mainnet";
        if (chainId == 80002) return "polygon-amoy";
        return string(abi.encodePacked("unknown-", vm.toString(chainId)));
    }
}
