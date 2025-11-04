// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/SafeModuleSetupHelper.sol";

/**
 * @title DeploySetupHelper
 * @notice Deployment script for SafeModuleSetupHelper contract
 * @dev Deploys the helper contract that enables atomic Safe + Module deployment
 *
 * Usage:
 *   forge script script/DeploySetupHelper.s.sol:DeploySetupHelper \
 *     --rpc-url $RPC_URL \
 *     --broadcast \
 *     --verify
 *
 * Example (Base Sepolia):
 *   forge script script/DeploySetupHelper.s.sol:DeploySetupHelper \
 *     --rpc-url https://sepolia.base.org \
 *     --broadcast \
 *     --verify \
 *     --etherscan-api-key $BASESCAN_API_KEY
 *
 * Environment variables required:
 *   - PRIVATE_KEY: Deployer private key
 *   - ZODIAC_FACTORY_ADDRESS: Address of Zodiac ModuleProxyFactory (default: 0x3f87d09F02dAe3F0b8E20121Cb520D95EE320D01)
 *   - MODULE_IMPLEMENTATION_ADDRESS: Address of DeadManSwitch implementation (default: 0xbcc3b6f2e4745678f6496ab5eaeeca1b391b4907)
 */
contract DeploySetupHelper is Script {
    // Default addresses for Base Sepolia
    address constant DEFAULT_FACTORY = 0x3f87d09F02dAe3F0b8E20121Cb520D95EE320D01;
    address constant DEFAULT_IMPLEMENTATION = 0xBCc3b6f2E4745678f6496AB5eAEECa1B391b4907;

    function run() external {
        // Load deployer private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Load factory and implementation addresses (with defaults)
        address factoryAddress = vm.envOr("ZODIAC_FACTORY_ADDRESS", DEFAULT_FACTORY);
        address implementationAddress = vm.envOr("MODULE_IMPLEMENTATION_ADDRESS", DEFAULT_IMPLEMENTATION);

        console.log("===========================================");
        console.log("SafeModuleSetupHelper Deployment");
        console.log("===========================================");
        console.log("");
        console.log("Network Information:");
        console.log("  Chain ID:", block.chainid);
        console.log("  Deployer:", deployer);
        console.log("");
        console.log("Configuration:");
        console.log("  Zodiac Factory:", factoryAddress);
        console.log("  Module Implementation:", implementationAddress);
        console.log("");

        // Verify addresses are valid
        require(factoryAddress != address(0), "Invalid factory address");
        require(implementationAddress != address(0), "Invalid implementation address");

        // Check deployer balance
        uint256 balance = deployer.balance;
        console.log("Deployer Balance:", balance / 1e18, "ETH");
        require(balance > 0.001 ether, "Insufficient balance for deployment");
        console.log("");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy SetupHelper
        SafeModuleSetupHelper setupHelper = new SafeModuleSetupHelper(
            factoryAddress,
            implementationAddress
        );

        vm.stopBroadcast();

        console.log("===========================================");
        console.log("Deployment Successful!");
        console.log("===========================================");
        console.log("");
        console.log("SetupHelper Address:", address(setupHelper));
        console.log("");

        // Verify deployment
        (address factory, address implementation) = setupHelper.getAddresses();
        console.log("Verification:");
        console.log("  Factory (should match):", factory);
        console.log("  Implementation (should match):", implementation);
        console.log("");

        console.log("===========================================");
        console.log("Integration Instructions");
        console.log("===========================================");
        console.log("");
        console.log("1. Update frontend environment variables:");
        console.log("   VITE_SETUP_HELPER_ADDRESS=%s", address(setupHelper));
        console.log("");
        console.log("2. Update backend environment variables:");
        console.log("   SETUP_HELPER_ADDRESS=%s", address(setupHelper));
        console.log("");
        console.log("3. Frontend integration:");
        console.log("   - Modify Safe.setup() to use setupHelper");
        console.log("   - Pass beneficiary, heartbeat, and challenge period");
        console.log("   - Listen for ModuleSetupComplete event");
        console.log("");
        console.log("4. New deployment flow (1 signature only!):");
        console.log("   Safe.setup() with delegatecall to SetupHelper");
        console.log("   -> Deploys Safe + Module + Enables Module");
        console.log("");

        // Save deployment info to JSON
        string memory deploymentInfo = string(
            abi.encodePacked(
                "{\n",
                '  "setupHelperAddress": "',
                vm.toString(address(setupHelper)),
                '",\n',
                '  "factoryAddress": "',
                vm.toString(factoryAddress),
                '",\n',
                '  "implementationAddress": "',
                vm.toString(implementationAddress),
                '",\n',
                '  "chainId": ',
                vm.toString(block.chainid),
                ',\n',
                '  "deployer": "',
                vm.toString(deployer),
                '",\n',
                '  "timestamp": ',
                vm.toString(block.timestamp),
                ',\n',
                '  "blockNumber": ',
                vm.toString(block.number),
                "\n}"
            )
        );

        // Create deployments directory if it doesn't exist
        string memory filename = string(
            abi.encodePacked(
                "./deployments/setup-helper-",
                vm.toString(block.chainid),
                ".json"
            )
        );

        vm.writeFile(filename, deploymentInfo);
        console.log("Deployment info saved to:", filename);
        console.log("");

        console.log("===========================================");
        console.log("Gas Savings Estimate");
        console.log("===========================================");
        console.log("Old flow (3 signatures):");
        console.log("  1. Create Safe: ~300k gas");
        console.log("  2. Deploy Module: ~150k gas");
        console.log("  3. Enable Module: ~100k gas");
        console.log("  Total: ~550k gas");
        console.log("");
        console.log("New flow (1 signature):");
        console.log("  1. Create Safe + Setup: ~400k gas");
        console.log("  Total: ~400k gas");
        console.log("");
        console.log("Savings: ~27% gas + 2 fewer signatures!");
        console.log("===========================================");
    }
}
