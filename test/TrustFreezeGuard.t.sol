// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {TrustFreezeGuard} from "../src/TrustFreezeGuard.sol";
import {Enum} from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import {IERC165} from "@gnosis.pm/safe-contracts/contracts/interfaces/IERC165.sol";
import {Guard} from "@gnosis.pm/safe-contracts/contracts/base/GuardManager.sol";

/**
 * @title TrustFreezeGuardTest
 * @notice Comprehensive test suite for TrustFreezeGuard
 * @dev Tests all guard functionality, freeze management, and edge cases
 */
contract TrustFreezeGuardTest is Test {
    TrustFreezeGuard public guard;
    MockSafeWithGuard public safe;
    MockModule public module;

    address public owner = address(0xA11CE);
    address public beneficiary = address(0xBEEF);
    address public stranger = address(0xBAD);

    // Events to test
    event SafeFrozen(address indexed safe, uint256 unfreezeTime);
    event FreezePeriodUpdated(
        address indexed safe,
        uint256 oldUnfreezeTime,
        uint256 newUnfreezeTime
    );

    function setUp() public {
        // Deploy contracts
        guard = new TrustFreezeGuard();
        safe = new MockSafeWithGuard(owner);
        module = new MockModule();

        // Enable module on safe
        vm.prank(owner);
        safe.enableModule(address(module));

        // Set guard on safe
        vm.prank(address(safe));
        safe.setGuard(address(guard));
    }

    // ============ ERC165 Interface Tests ============

    function test_SupportsGuardInterface() public view {
        assertTrue(guard.supportsInterface(type(Guard).interfaceId));
    }

    function test_SupportsERC165Interface() public view {
        assertTrue(guard.supportsInterface(type(IERC165).interfaceId));
    }

    function test_DoesNotSupportInvalidInterface() public view {
        assertFalse(guard.supportsInterface(0xffffffff));
    }

    // ============ Freeze Management Tests ============

    function test_FreezeUntil_Success() public {
        uint256 unfreezeTime = block.timestamp + 365 days;

        vm.expectEmit(true, false, false, true);
        emit SafeFrozen(address(safe), unfreezeTime);

        vm.prank(address(safe));
        guard.freezeUntil(unfreezeTime);

        assertEq(guard.frozenUntil(address(safe)), unfreezeTime);
        assertTrue(guard.isFrozen(address(safe)));
    }

    function test_FreezeUntil_MultipleYears() public {
        uint256 unfreezeTime = block.timestamp + (5 * 365 days);

        vm.prank(address(safe));
        guard.freezeUntil(unfreezeTime);

        assertEq(guard.frozenUntil(address(safe)), unfreezeTime);
        assertEq(guard.getRemainingFreezeTime(address(safe)), 5 * 365 days);
    }

    function test_FreezeUntil_UpdateExistingFreeze() public {
        uint256 firstFreezeTime = block.timestamp + 365 days;
        uint256 secondFreezeTime = block.timestamp + (2 * 365 days);

        // Set initial freeze
        vm.prank(address(safe));
        guard.freezeUntil(firstFreezeTime);

        // Update freeze period
        vm.expectEmit(true, false, false, true);
        emit FreezePeriodUpdated(address(safe), firstFreezeTime, secondFreezeTime);

        vm.prank(address(safe));
        guard.freezeUntil(secondFreezeTime);

        assertEq(guard.frozenUntil(address(safe)), secondFreezeTime);
    }

    function test_FreezeUntil_RevertIfZeroTimestamp() public {
        vm.prank(address(safe));
        vm.expectRevert(
            abi.encodeWithSelector(TrustFreezeGuard.InvalidFreezeTime.selector, 0)
        );
        guard.freezeUntil(0);
    }

    function test_FreezeUntil_RevertIfPastTimestamp() public {
        // Use a clearly past timestamp (not zero, which triggers InvalidFreezeTime first)
        uint256 pastTime = block.timestamp > 1000 ? block.timestamp - 1000 : 1;

        vm.prank(address(safe));
        vm.expectRevert(
            abi.encodeWithSelector(
                TrustFreezeGuard.FreezeTimeInPast.selector,
                pastTime,
                block.timestamp
            )
        );
        guard.freezeUntil(pastTime);
    }

    function test_FreezeUntil_RevertIfCurrentTimestamp() public {
        uint256 currentTime = block.timestamp;

        vm.prank(address(safe));
        vm.expectRevert(
            abi.encodeWithSelector(
                TrustFreezeGuard.FreezeTimeInPast.selector,
                currentTime,
                block.timestamp
            )
        );
        guard.freezeUntil(currentTime);
    }

    // ============ Owner Transaction Tests ============

    function test_CheckTransaction_BlocksWhenFrozen() public {
        // Freeze safe for 1 year
        uint256 unfreezeTime = block.timestamp + 365 days;
        vm.prank(address(safe));
        guard.freezeUntil(unfreezeTime);

        // Owner tries to execute transaction
        vm.prank(address(safe));
        vm.expectRevert(
            abi.encodeWithSelector(
                TrustFreezeGuard.SafeIsFrozen.selector,
                address(safe),
                block.timestamp,
                unfreezeTime
            )
        );
        guard.checkTransaction(
            address(0),
            0,
            "",
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(0),
            "",
            owner
        );
    }

    function test_CheckTransaction_AllowsAfterUnfreeze() public {
        // Freeze safe for 1 day
        uint256 unfreezeTime = block.timestamp + 1 days;
        vm.prank(address(safe));
        guard.freezeUntil(unfreezeTime);

        // Fast forward past freeze period
        vm.warp(unfreezeTime + 1);

        // Owner transaction should succeed
        vm.prank(address(safe));
        guard.checkTransaction(
            address(0),
            0,
            "",
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(0),
            "",
            owner
        );
        // Should not revert
    }

    function test_CheckTransaction_AllowsWhenNotFrozen() public {
        // Safe is not frozen
        vm.prank(address(safe));
        guard.checkTransaction(
            address(0),
            0,
            "",
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(0),
            "",
            owner
        );
        // Should not revert
    }

    // ============ Module Transaction Tests ============

    function test_ModuleTransaction_SucceedsDuringFreeze() public {
        // Freeze safe for 1 year
        uint256 unfreezeTime = block.timestamp + 365 days;
        vm.prank(address(safe));
        guard.freezeUntil(unfreezeTime);

        // Module executes transaction (bypasses guard)
        vm.prank(address(module));
        bool success = safe.execTransactionFromModule(
            address(safe),
            0,
            abi.encodeWithSignature("swapOwner(address,address,address)", address(0x1), owner, beneficiary),
            uint8(Enum.Operation.Call)
        );

        assertTrue(success);
        // Module transaction succeeds even though Safe is frozen
    }

    // ============ Integration Scenario Tests ============

    function test_FullTrustScenario_OwnerBlockedModuleWorks() public {
        // 1. Owner freezes Safe for 5 years
        uint256 freezeDuration = 5 * 365 days;
        uint256 unfreezeTime = block.timestamp + freezeDuration;

        vm.prank(address(safe));
        guard.freezeUntil(unfreezeTime);

        assertTrue(guard.isFrozen(address(safe)));
        assertEq(guard.getRemainingFreezeTime(address(safe)), freezeDuration);

        // 2. Owner tries to execute transaction after 2 years - should fail
        vm.warp(block.timestamp + (2 * 365 days));

        assertTrue(guard.isFrozen(address(safe)));

        vm.prank(address(safe));
        vm.expectRevert();
        guard.checkTransaction(
            beneficiary,
            1 ether,
            "",
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(0),
            "",
            owner
        );

        // 3. Module executes inheritance (DeadManSwitch scenario) - should succeed
        vm.prank(address(module));
        bool success = safe.execTransactionFromModule(
            address(safe),
            0,
            abi.encodeWithSignature("swapOwner(address,address,address)", address(0x1), owner, beneficiary),
            uint8(Enum.Operation.Call)
        );

        assertTrue(success);

        // 4. After 5 years, Safe unfreezes automatically
        vm.warp(unfreezeTime + 1);

        assertFalse(guard.isFrozen(address(safe)));
        assertEq(guard.getRemainingFreezeTime(address(safe)), 0);

        // 5. New owner (beneficiary) can now execute transactions
        vm.prank(address(safe));
        guard.checkTransaction(
            stranger,
            1 ether,
            "",
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(0),
            "",
            beneficiary
        );
        // Should not revert
    }

    function test_ExtendFreezePeriod() public {
        // Initial 1 year freeze
        uint256 firstFreeze = block.timestamp + 365 days;
        vm.prank(address(safe));
        guard.freezeUntil(firstFreeze);

        // Fast forward 6 months
        vm.warp(block.timestamp + 180 days);

        // Owner decides to extend freeze by another year
        uint256 secondFreeze = block.timestamp + 365 days;
        vm.prank(address(safe));
        guard.freezeUntil(secondFreeze);

        assertTrue(guard.isFrozen(address(safe)));
        assertGt(guard.frozenUntil(address(safe)), firstFreeze);
    }

    // ============ View Function Tests ============

    function test_IsFrozen_ReturnsTrueWhenFrozen() public {
        vm.prank(address(safe));
        guard.freezeUntil(block.timestamp + 1 days);

        assertTrue(guard.isFrozen(address(safe)));
    }

    function test_IsFrozen_ReturnsFalseWhenNotFrozen() public {
        assertFalse(guard.isFrozen(address(safe)));
    }

    function test_IsFrozen_ReturnsFalseAfterExpiry() public {
        uint256 unfreezeTime = block.timestamp + 1 days;
        vm.prank(address(safe));
        guard.freezeUntil(unfreezeTime);

        vm.warp(unfreezeTime + 1);
        assertFalse(guard.isFrozen(address(safe)));
    }

    function test_GetRemainingFreezeTime_ReturnsCorrectValue() public {
        uint256 duration = 30 days;
        vm.prank(address(safe));
        guard.freezeUntil(block.timestamp + duration);

        assertEq(guard.getRemainingFreezeTime(address(safe)), duration);

        vm.warp(block.timestamp + 10 days);
        assertEq(guard.getRemainingFreezeTime(address(safe)), 20 days);
    }

    function test_GetRemainingFreezeTime_ReturnsZeroWhenNotFrozen() public {
        assertEq(guard.getRemainingFreezeTime(address(safe)), 0);
    }

    function test_GetUnfreezeTime_ReturnsCorrectTimestamp() public {
        uint256 unfreezeTime = block.timestamp + 365 days;
        vm.prank(address(safe));
        guard.freezeUntil(unfreezeTime);

        assertEq(guard.getUnfreezeTime(address(safe)), unfreezeTime);
    }

    // ============ Multi-Safe Tests ============

    function test_MultipleSafes_IndependentFreezes() public {
        MockSafeWithGuard safe2 = new MockSafeWithGuard(beneficiary);

        // Freeze first safe for 1 year
        vm.prank(address(safe));
        guard.freezeUntil(block.timestamp + 365 days);

        // Freeze second safe for 2 years
        vm.prank(address(safe2));
        guard.freezeUntil(block.timestamp + (2 * 365 days));

        assertTrue(guard.isFrozen(address(safe)));
        assertTrue(guard.isFrozen(address(safe2)));
        assertGt(guard.frozenUntil(address(safe2)), guard.frozenUntil(address(safe)));
    }

    // ============ Edge Case Tests ============

    function test_CheckAfterExecution_DoesNotRevert() public view {
        // Should do nothing and not revert
        guard.checkAfterExecution(bytes32(0), true);
        guard.checkAfterExecution(bytes32(0), false);
    }

    function test_Fallback_DoesNotRevert() public {
        // Call non-existent function
        (bool success,) = address(guard).call(abi.encodeWithSignature("nonExistentFunction()"));
        assertTrue(success); // Fallback should succeed
    }

    function test_FreezeImmediately_MinimumFutureTime() public {
        uint256 minFutureTime = block.timestamp + 1;

        vm.prank(address(safe));
        guard.freezeUntil(minFutureTime);

        assertTrue(guard.isFrozen(address(safe)));
    }

    // ============ Fuzz Tests ============

    function testFuzz_FreezeUntil_ValidTimestamps(uint256 futureTime) public {
        // Bound to reasonable future times (1 second to 100 years)
        futureTime = bound(futureTime, block.timestamp + 1, block.timestamp + (100 * 365 days));

        vm.prank(address(safe));
        guard.freezeUntil(futureTime);

        assertEq(guard.frozenUntil(address(safe)), futureTime);
        assertTrue(guard.isFrozen(address(safe)));
    }

    function testFuzz_CheckTransaction_DifferentTimestamps(uint256 warpTime) public {
        uint256 unfreezeTime = block.timestamp + 365 days;
        vm.prank(address(safe));
        guard.freezeUntil(unfreezeTime);

        // Bound warp time to reasonable range
        warpTime = bound(warpTime, block.timestamp, block.timestamp + (2 * 365 days));
        vm.warp(warpTime);

        if (warpTime < unfreezeTime) {
            // Should revert when frozen
            vm.prank(address(safe));
            vm.expectRevert();
            guard.checkTransaction(
                address(0),
                0,
                "",
                Enum.Operation.Call,
                0,
                0,
                0,
                address(0),
                payable(0),
                "",
                owner
            );
        } else {
            // Should succeed when not frozen
            vm.prank(address(safe));
            guard.checkTransaction(
                address(0),
                0,
                "",
                Enum.Operation.Call,
                0,
                0,
                0,
                address(0),
                payable(0),
                "",
                owner
            );
        }
    }
}

// ============ Mock Contracts ============

/**
 * @notice Mock Safe with Guard support for testing
 */
contract MockSafeWithGuard {
    address public owner;
    address public guard;
    mapping(address => bool) public modules;
    address internal constant SENTINEL = address(0x1);

    event GuardChanged(address indexed guard);
    event ModuleEnabled(address indexed module);

    constructor(address _owner) {
        owner = _owner;
    }

    function setGuard(address _guard) external {
        require(msg.sender == address(this), "Only via Safe transaction");
        guard = _guard;
        emit GuardChanged(_guard);
    }

    function getGuard() external view returns (address) {
        return guard;
    }

    function enableModule(address module) external {
        require(msg.sender == owner, "Not owner");
        modules[module] = true;
        emit ModuleEnabled(module);
    }

    function execTransaction(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures
    ) external returns (bool success) {
        // Call guard check if guard is set
        if (guard != address(0)) {
            Guard(guard).checkTransaction(
                to,
                value,
                data,
                operation,
                safeTxGas,
                baseGas,
                gasPrice,
                gasToken,
                refundReceiver,
                signatures,
                msg.sender
            );
        }

        // Execute transaction
        (success,) = to.call{value: value}(data);

        // Call guard post-check if guard is set
        if (guard != address(0)) {
            Guard(guard).checkAfterExecution(bytes32(0), success);
        }
    }

    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation
    ) external returns (bool success) {
        require(modules[msg.sender], "Module not enabled");
        // Module transactions bypass guard
        (success,) = to.call{value: value}(data);
    }

    function swapOwner(address prevOwner, address oldOwner, address newOwner) external {
        require(msg.sender == address(this), "Only via Safe transaction");
        require(prevOwner == SENTINEL, "Invalid previous owner");
        require(oldOwner == owner, "Invalid old owner");
        owner = newOwner;
    }

    receive() external payable {}
}

/**
 * @notice Mock Module for testing module transactions
 */
contract MockModule {
    // Empty module for testing
}
