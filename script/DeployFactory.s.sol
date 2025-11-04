// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "zodiac/factory/ModuleProxyFactory.sol";

/**
 * @title DeployFactory
 * @notice Deploy Zodiac ModuleProxyFactory to Base Sepolia / Base Mainnet
 * @dev This factory is used to deploy minimal proxy instances of DeadManSwitchModule
 *
 * Usage:
 *   # Deploy to Base Sepolia
 *   forge script script/DeployFactory.s.sol:DeployFactory --rpc-url $SEPOLIA_RPC_URL --broadcast --legacy
 *
 *   # Deploy to Base Mainnet
 *   forge script script/DeployFactory.s.sol:DeployFactory --rpc-url $BASE_RPC_URL --broadcast --legacy
 *
 * IMPORTANT:
 *   - This factory contract is STATELESS and DETERMINISTIC
 *   - It's safe to deploy on any network
 *   - The same factory can be used by multiple projects
 *   - Gas cost: ~200k-300k
 */
contract DeployFactory is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("===========================================");
        console.log("Zodiac ModuleProxyFactory Deployment");
        console.log("===========================================");
        console.log("");
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("Chain ID:", block.chainid);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the factory - no initialization needed!
        ModuleProxyFactory factory = new ModuleProxyFactory();

        vm.stopBroadcast();

        console.log("===========================================");
        console.log("Deployment Successful!");
        console.log("===========================================");
        console.log("");
        console.log("Factory Address:", address(factory));
        console.log("");
        console.log("===========================================");
        console.log("How to Use:");
        console.log("===========================================");
        console.log("");
        console.log("1. Update your frontend .env:");
        console.log("   VITE_ZODIAC_FACTORY=%s", address(factory));
        console.log("   VITE_MODULE_IMPLEMENTATION=0xbcc3b6f2e4745678f6496ab5eaeeca1b391b4907");
        console.log("");
        console.log("2. Frontend code to deploy a module:");
        console.log("");
        console.log("   const initParams = ethers.utils.defaultAbiCoder.encode(");
        console.log("     ['address', 'address', 'uint256', 'uint256'],");
        console.log("     [safeAddress, beneficiary, heartbeat, challengePeriod]");
        console.log("   );");
        console.log("");
        console.log("   const tx = await factory.deployModule(");
        console.log("     '0xbcc3b6f2e4745678f6496ab5eaeeca1b391b4907', // implementation");
        console.log("     initParams,");
        console.log("     saltNonce  // unique number for each deployment");
        console.log("   );");
        console.log("");
        console.log("3. Listen for ModuleProxyCreation event to get proxy address");
        console.log("");

        // Save deployment info
        string memory deploymentInfo = string(
            abi.encodePacked(
                "{\n",
                '  "factoryAddress": "',
                vm.toString(address(factory)),
                '",\n',
                '  "implementationAddress": "0xbcc3b6f2e4745678f6496ab5eaeeca1b391b4907",\n',
                '  "chainId": ',
                vm.toString(block.chainid),
                ',\n',
                '  "deployer": "',
                vm.toString(vm.addr(deployerPrivateKey)),
                '",\n',
                '  "timestamp": ',
                vm.toString(block.timestamp),
                ',\n',
                '  "network": "',
                block.chainid == 84532 ? "Base Sepolia" : block.chainid == 8453 ? "Base Mainnet" : "Unknown",
                '"\n}'
            )
        );

        vm.writeFile("./deployments/factory-latest.json", deploymentInfo);
        console.log("Deployment info saved to: ./deployments/factory-latest.json");
    }
}
