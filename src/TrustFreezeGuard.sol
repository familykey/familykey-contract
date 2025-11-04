// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.23;

import {BaseGuard} from "@gnosis.pm/safe-contracts/contracts/base/GuardManager.sol";
import {Enum} from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";

/**
 * @title TrustFreezeGuard
 * @notice A Safe Guard that freezes Owner operations for a specified trust period
 * @dev This guard blocks Owner-initiated transactions (via execTransaction) while allowing
 *      Module operations (via execTransactionFromModule) to continue normally.
 *      This enables trust/inheritance scenarios where:
 *      - Owners cannot operate the Safe during the freeze period
 *      - DeadManSwitch and other modules can still function (e.g., for inheritance)
 *
 * @custom:security-note This contract follows Safe official Guard patterns and best practices:
 *      - Inherits from BaseGuard for ERC165 support
 *      - Uses minimal storage and gas-efficient checks
 *      - Provides fallback for upgrade safety
 *      - Follows Safe naming conventions and error handling
 *
 * Architecture:
 *   Owner Transaction:  Owner -> Safe.execTransaction() -> Guard.checkTransaction() -> [BLOCKED if frozen]
 *   Module Transaction: Module -> Safe.execTransactionFromModule() -> [Executed, bypasses Guard]
 *
 * @author Generated with Claude Code
 */
contract TrustFreezeGuard is BaseGuard {
    // ============ Events ============

    /**
     * @notice Emitted when a Safe is frozen until a specific timestamp
     * @param safe The address of the Safe that was frozen
     * @param unfreezeTime The timestamp when the Safe will automatically unfreeze
     */
    event SafeFrozen(address indexed safe, uint256 unfreezeTime);

    /**
     * @notice Emitted when the freeze period for a Safe is updated
     * @param safe The address of the Safe
     * @param oldUnfreezeTime The previous unfreeze timestamp
     * @param newUnfreezeTime The new unfreeze timestamp
     */
    event FreezePeriodUpdated(
        address indexed safe,
        uint256 oldUnfreezeTime,
        uint256 newUnfreezeTime
    );

    // ============ Errors ============

    /// @notice Thrown when a transaction is attempted during the freeze period
    error SafeIsFrozen(address safe, uint256 currentTime, uint256 unfreezeTime);

    /// @notice Thrown when attempting to set an invalid freeze time
    error InvalidFreezeTime(uint256 timestamp);

    /// @notice Thrown when attempting to freeze with a time in the past
    error FreezeTimeInPast(uint256 timestamp, uint256 currentTime);

    // ============ State Variables ============

    /**
     * @notice Mapping of Safe address to the timestamp when it will be unfrozen
     * @dev A value of 0 or timestamp <= block.timestamp means the Safe is not frozen
     */
    mapping(address => uint256) public frozenUntil;

    // ============ Constructor ============

    constructor() {
        // Empty constructor - stateless guard design
    }

    // ============ Fallback ============

    /**
     * @notice Fallback function to prevent Safe lockup during upgrades
     * @dev We don't revert on fallback to avoid issues in case of a Safe upgrade.
     *      If the expected check method changes, the Safe would otherwise be locked.
     *      This follows Safe's official guard patterns.
     */
    fallback() external {
        // Intentionally empty - prevents Safe lockup
    }

    // ============ Guard Interface Implementation ============

    /**
     * @notice Pre-execution check called by Safe before executing an Owner transaction
     * @dev This function is called by the Safe contract via delegatecall when an Owner
     *      initiates a transaction through execTransaction(). Module transactions via
     *      execTransactionFromModule() bypass this check entirely.
     *
     * @param to Target address (unused, required by Guard interface)
     * @param value ETH value (unused, required by Guard interface)
     * @param data Transaction data (unused, required by Guard interface)
     * @param operation Operation type (unused, required by Guard interface)
     * @param safeTxGas Gas for Safe transaction (unused, required by Guard interface)
     * @param baseGas Base gas (unused, required by Guard interface)
     * @param gasPrice Gas price (unused, required by Guard interface)
     * @param gasToken Gas token address (unused, required by Guard interface)
     * @param refundReceiver Refund receiver (unused, required by Guard interface)
     * @param signatures Transaction signatures (unused, required by Guard interface)
     * @param msgSender Original transaction sender (unused, required by Guard interface)
     *
     * @custom:reverts SafeIsFrozen if the Safe is currently frozen
     */
    function checkTransaction(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures,
        address msgSender
    ) external view override {
        // msg.sender is the Safe contract (due to delegatecall from Safe)
        address safe = msg.sender;
        uint256 unfreezeTime = frozenUntil[safe];

        // Check if Safe is currently frozen
        if (block.timestamp < unfreezeTime) {
            revert SafeIsFrozen(safe, block.timestamp, unfreezeTime);
        }

        // Safe is not frozen, allow transaction to proceed
    }

    /**
     * @notice Post-execution check called by Safe after transaction execution
     * @dev Not used in this guard implementation, but required by Guard interface
     * @param txHash Transaction hash (unused)
     * @param success Whether the transaction succeeded (unused)
     */
    function checkAfterExecution(bytes32 txHash, bool success) external view override {
        // No post-execution checks needed for freeze functionality
    }

    // ============ Freeze Management Functions ============

    /**
     * @notice Set the freeze period for the calling Safe
     * @dev This function must be called by the Safe itself (typically via execTransaction).
     *      The Safe's owners must sign a transaction to call this function.
     *
     * Usage pattern:
     *   1. Safe owner(s) create and sign a transaction calling this function
     *   2. Transaction is executed via Safe.execTransaction()
     *   3. This function is called with msg.sender = Safe address
     *
     * @param timestamp The Unix timestamp when the Safe should be unfrozen
     *
     * @custom:reverts InvalidFreezeTime if timestamp is 0
     * @custom:reverts FreezeTimeInPast if timestamp is not in the future
     * @custom:emits SafeFrozen when setting a new freeze period
     * @custom:emits FreezePeriodUpdated when updating an existing freeze period
     */
    function freezeUntil(uint256 timestamp) external {
        // msg.sender is the Safe contract
        address safe = msg.sender;

        // Validate freeze time
        if (timestamp == 0) {
            revert InvalidFreezeTime(timestamp);
        }

        if (timestamp <= block.timestamp) {
            revert FreezeTimeInPast(timestamp, block.timestamp);
        }

        uint256 oldUnfreezeTime = frozenUntil[safe];
        frozenUntil[safe] = timestamp;

        if (oldUnfreezeTime == 0 || oldUnfreezeTime <= block.timestamp) {
            // Setting a new freeze period
            emit SafeFrozen(safe, timestamp);
        } else {
            // Updating an existing freeze period
            emit FreezePeriodUpdated(safe, oldUnfreezeTime, timestamp);
        }
    }

    // ============ View Functions ============

    /**
     * @notice Check if a Safe is currently frozen
     * @param safe The address of the Safe to check
     * @return frozen True if the Safe is frozen, false otherwise
     */
    function isFrozen(address safe) external view returns (bool frozen) {
        return block.timestamp < frozenUntil[safe];
    }

    /**
     * @notice Get the remaining freeze time for a Safe
     * @param safe The address of the Safe to check
     * @return remainingTime The number of seconds until the Safe unfreezes (0 if not frozen)
     */
    function getRemainingFreezeTime(address safe) external view returns (uint256 remainingTime) {
        uint256 unfreezeTime = frozenUntil[safe];
        if (block.timestamp >= unfreezeTime) {
            return 0;
        }
        return unfreezeTime - block.timestamp;
    }

    /**
     * @notice Get the unfreeze timestamp for a Safe
     * @param safe The address of the Safe to check
     * @return timestamp The Unix timestamp when the Safe will unfreeze
     */
    function getUnfreezeTime(address safe) external view returns (uint256 timestamp) {
        return frozenUntil[safe];
    }
}
