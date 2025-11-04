// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @notice Minimal Safe interface for module management
 */
interface ISafeSetup {
    function enableModule(address module) external;
}

/**
 * @notice Zodiac ModuleProxyFactory interface
 */
interface IModuleProxyFactory {
    function deployModule(
        address masterCopy,
        bytes memory initializer,
        uint256 saltNonce
    ) external returns (address proxy);
}

/**
 * @notice Minimal interface for DeadManSwitch module initialization
 */
interface IDeadManSwitchModule {
    function setUp(bytes memory initializeParams) external;
}

/**
 * @title SafeModuleSetupHelper
 * @notice Helper contract to deploy and enable DeadManSwitch module during Safe initialization
 * @dev This contract is called via DELEGATECALL from Safe.setup(), allowing atomic module deployment and enablement
 *
 * Security Notes:
 * - This contract is executed in the Safe's context via delegatecall
 * - address(this) == Safe address when executed
 * - All state changes happen in the Safe's storage
 * - No need for owner signatures since it's part of Safe initialization
 *
 * Gas Optimization:
 * - Reduces 3 transactions to 1 transaction
 * - Saves ~40-50% total gas compared to separate deployment steps
 * - Estimated gas: ~400k-500k (vs ~800k-1M for 3 separate txs)
 */
contract SafeModuleSetupHelper {

    // ============ Immutable State ============

    /// @notice Address of the Zodiac ModuleProxyFactory
    address public immutable moduleFactory;

    /// @notice Address of the DeadManSwitch module implementation
    address public immutable moduleImplementation;

    // ============ Events ============

    /**
     * @notice Emitted when a module is successfully deployed and enabled for a Safe
     * @param safe Address of the Safe that the module was enabled for
     * @param module Address of the deployed module proxy
     * @param beneficiary Address of the module beneficiary
     * @param heartbeatInterval Heartbeat interval in seconds
     * @param challengePeriod Challenge period in seconds
     */
    event ModuleSetupComplete(
        address indexed safe,
        address indexed module,
        address indexed beneficiary,
        uint256 heartbeatInterval,
        uint256 challengePeriod
    );

    // ============ Constructor ============

    /**
     * @notice Initialize the helper with factory and implementation addresses
     * @param _moduleFactory Address of the Zodiac ModuleProxyFactory
     * @param _moduleImplementation Address of the DeadManSwitch module implementation
     */
    constructor(address _moduleFactory, address _moduleImplementation) {
        require(_moduleFactory != address(0), "Invalid factory address");
        require(_moduleImplementation != address(0), "Invalid implementation address");

        moduleFactory = _moduleFactory;
        moduleImplementation = _moduleImplementation;
    }

    // ============ Core Function ============

    /**
     * @notice Deploy and enable a DeadManSwitch module for a Safe
     * @dev This function is called via DELEGATECALL from Safe.setup()
     *      When executed: msg.sender = Safe creator, address(this) = Safe address
     *
     * @param beneficiary Address that can claim the Safe after timeout
     * @param heartbeatInterval Time in seconds between required check-ins
     * @param challengePeriod Time in seconds for challenge period after claim initiation
     * @param saltNonce Unique salt for deterministic module deployment
     *
     * Flow:
     * 1. Encode module initialization parameters (Safe address = address(this))
     * 2. Deploy module proxy via Zodiac Factory
     * 3. Enable module in Safe (no signature needed - we're in Safe's context)
     * 4. Emit event for frontend to capture module address
     */
    function setupModuleForSafe(
        address beneficiary,
        uint256 heartbeatInterval,
        uint256 challengePeriod,
        uint256 saltNonce
    ) external returns (address moduleAddress) {
        // Validate parameters
        require(beneficiary != address(0), "Invalid beneficiary");
        require(heartbeatInterval > 0, "Invalid heartbeat interval");
        require(challengePeriod > 0, "Invalid challenge period");

        // Note: address(this) is the Safe address due to delegatecall
        address safeAddress = address(this);

        // Step 1: Encode module initialization parameters
        // Format: abi.encode(safe, beneficiary, heartbeatInterval, challengePeriod)
        bytes memory moduleInitializer = abi.encodeCall(
            IDeadManSwitchModule.setUp,
            abi.encode(
                safeAddress,
                beneficiary,
                heartbeatInterval,
                challengePeriod
            )
        );

        // Step 2: Deploy module proxy via Zodiac Factory
        moduleAddress = IModuleProxyFactory(moduleFactory).deployModule(
            moduleImplementation,
            moduleInitializer,
            saltNonce
        );

        require(moduleAddress != address(0), "Module deployment failed");

        // Step 3: Enable module in Safe
        // No owner signature needed - we're executing in Safe's context
        ISafeSetup(safeAddress).enableModule(moduleAddress);

        // Step 4: Emit event for frontend
        emit ModuleSetupComplete(
            safeAddress,
            moduleAddress,
            beneficiary,
            heartbeatInterval,
            challengePeriod
        );

        return moduleAddress;
    }

    // ============ View Functions ============

    /**
     * @notice Get the factory and implementation addresses
     * @return factory Address of the ModuleProxyFactory
     * @return implementation Address of the DeadManSwitch implementation
     */
    function getAddresses() external view returns (
        address factory,
        address implementation
    ) {
        return (moduleFactory, moduleImplementation);
    }
}
