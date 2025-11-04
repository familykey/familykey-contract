// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/DeadManSwitchModule.sol";

/**
 * @title DeployDeadManSwitch
 * @notice Deployment script for DeadManSwitchModule Implementation
 * @dev Deploy the implementation contract that will be used with ModuleProxyFactory
 *
 * Usage:
 *   forge script script/DeployDeadManSwitch.s.sol:DeployDeadManSwitch --rpc-url $RPC_URL --broadcast --verify
 *
 * Environment variables required:
 *   - RPC_URL: The RPC endpoint URL
 *   - PRIVATE_KEY: Deployer private key (automatically loaded by foundry)
 *   - ETHERSCAN_API_KEY: For contract verification (optional)
 */
contract DeployDeadManSwitch is Script {
    function run() external {
        // Load deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("===========================================");
        console.log("DeadManSwitchModule Deployment Script");
        console.log("===========================================");
        console.log("");
        console.log("Deployer address:", vm.addr(deployerPrivateKey));
        console.log("Chain ID:", block.chainid);
        console.log("");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation contract
        DeadManSwitchModule implementation = new DeadManSwitchModule();

        console.log("===========================================");
        console.log("Deployment Successful!");
        console.log("===========================================");
        console.log("");
        console.log("Implementation Address:", address(implementation));
        console.log("");
        console.log("===========================================");
        console.log("Next Steps:");
        console.log("===========================================");
        console.log("1. Verify the contract on block explorer");
        console.log("2. Update frontend .env with:");
        console.log("   VITE_MODULE_IMPLEMENTATION=%s", address(implementation));
        console.log("3. Use Zodiac ModuleProxyFactory to create instances:");
        console.log("   Factory Address: 0x00000000000DC7F163742Eb4aBEf650037b1f588");
        console.log("");

        vm.stopBroadcast();

        // Output deployment info to file
        string memory deploymentInfo = string(
            abi.encodePacked(
                "{\n",
                '  "implementation": "',
                vm.toString(address(implementation)),
                '",\n',
                '  "chainId": ',
                vm.toString(block.chainid),
                ',\n',
                '  "deployer": "',
                vm.toString(vm.addr(deployerPrivateKey)),
                '",\n',
                '  "timestamp": ',
                vm.toString(block.timestamp),
                "\n}"
            )
        );

        vm.writeFile(
            "./deployments/deadmanswitch-latest.json",
            deploymentInfo
        );

        console.log("Deployment info saved to: ./deployments/deadmanswitch-latest.json");
    }
}
