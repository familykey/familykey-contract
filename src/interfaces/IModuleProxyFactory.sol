// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ModuleProxyFactory
 * @notice Interface for Zodiac ModuleProxyFactory
 * @dev This is the standard Zodiac factory used for deploying EIP-1167 minimal proxies
 *
 * Deployed addresses (same across multiple chains via CREATE2):
 * - Ethereum Mainnet: 0x00000000000DC7F163742Eb4aBEf650037b1f588
 * - Base: 0x00000000000DC7F163742Eb4aBEf650037b1f588
 * - Base Sepolia: 0x00000000000DC7F163742Eb4aBEf650037b1f588
 * - Optimism: 0x00000000000DC7F163742Eb4aBEf650037b1f588
 * - Arbitrum: 0x00000000000DC7F163742Eb4aBEf650037b1f588
 *
 * Reference: https://github.com/gnosisguild/zodiac/blob/master/contracts/factory/ModuleProxyFactory.sol
 */
interface IModuleProxyFactory {
    /**
     * @notice Emitted when a new module proxy is created
     * @param proxy Address of the newly created proxy
     * @param masterCopy Address of the implementation contract
     */
    event ModuleProxyCreation(
        address indexed proxy,
        address indexed masterCopy
    );

    /**
     * @notice Deploy a new EIP-1167 minimal proxy pointing to the implementation
     * @param masterCopy Address of the implementation contract
     * @param initializer Encoded initialization data (typically abi.encodeWithSignature("initialize(...)"))
     * @param saltNonce Salt for CREATE2 deployment (enables deterministic addresses)
     * @return proxy Address of the newly created proxy
     *
     * @dev Gas cost: ~100,000 gas for deployment + initialization
     *
     * Example usage:
     *   bytes memory initData = abi.encodeWithSignature(
     *       "initialize(address,address,uint256,uint256)",
     *       safeAddress,
     *       beneficiaryAddress,
     *       7 days,
     *       2 days
     *   );
     *   address module = factory.deployModule(
     *       implementationAddress,
     *       initData,
     *       keccak256(abi.encodePacked("familykey-v1-", safeAddress))
     *   );
     */
    function deployModule(
        address masterCopy,
        bytes memory initializer,
        uint256 saltNonce
    ) external returns (address proxy);
}
