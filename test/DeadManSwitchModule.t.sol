// SPDX-License-Identifier: MIT
// DeadManSwitchModule Test Suite - Zodiac Module Version
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {DeadManSwitchModule} from "../src/DeadManSwitchModule.sol";
import {MockSafe} from "../src/mocks/MockSafe.sol";

contract DeadManSwitchModuleTest is Test {
    address Owner = address(0xA11CE);
    address bene = address(0xBEEF);
    address newBene = address(0xCAFE);
    MockSafe safe;
    DeadManSwitchModule mod;

    function setUp() public {
        safe = new MockSafe(Owner);
        mod = new DeadManSwitchModule();

        // Encode initialization parameters for Zodiac setUp
        bytes memory initParams = abi.encode(
            address(safe),
            bene,
            7 days,
            2 days
        );

        mod.setUp(initParams);

        vm.prank(Owner);
        safe.enableModule(address(mod));
    }

    // ========== Original Tests ==========

    function testHappyPath() public {
        vm.prank(Owner);
        mod.checkIn();
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(bene);
        mod.startClaim();
        vm.warp(block.timestamp + 2 days + 1);
        vm.prank(bene);
        mod.finalizeClaim();
        address[] memory Owners = safe.getOwners();
        assertEq(Owners[0], bene);
    }

    function testCheckIn() public {
        uint256 initialCheckIn = mod.lastCheckIn();

        vm.warp(block.timestamp + 1 days);
        vm.prank(Owner);
        mod.checkIn();

        assertGt(mod.lastCheckIn(), initialCheckIn);
    }

    function testStartClaimTooEarly() public {
        vm.prank(Owner);
        mod.checkIn();

        vm.warp(block.timestamp + 5 days); // Less than 7 days
        vm.prank(bene);
        vm.expectRevert("NOT_EXPIRED");
        mod.startClaim();
    }

    function testFinalizeClaimTooEarly() public {
        vm.prank(Owner);
        mod.checkIn();

        vm.warp(block.timestamp + 8 days);
        vm.prank(bene);
        mod.startClaim();

        vm.warp(block.timestamp + 1 days); // Less than 2 days challenge period
        vm.prank(bene);
        vm.expectRevert("NOT_READY");
        mod.finalizeClaim();
    }

    // ========== Zodiac Module Tests ==========

    function testSetUp() public {
        DeadManSwitchModule newMod = new DeadManSwitchModule();
        bytes memory initParams = abi.encode(address(safe), bene, 7 days, 2 days);

        newMod.setUp(initParams);

        assertEq(newMod.avatar(), address(safe));
        assertEq(newMod.target(), address(safe));
        assertEq(newMod.beneficiary(), bene);
        assertEq(newMod.heartbeatInterval(), 7 days);
        assertEq(newMod.challengePeriod(), 2 days);
    }

    function testCannotReinitialize() public {
        bytes memory initParams = abi.encode(address(safe), bene, 7 days, 2 days);

        vm.expectRevert();
        mod.setUp(initParams);
    }

    function testSetUpWithInvalidInterval() public {
        DeadManSwitchModule newMod = new DeadManSwitchModule();

        // Too short
        bytes memory initParams1 = abi.encode(address(safe), bene, 1 hours, 2 days);
        vm.expectRevert("INVALID_INTERVAL");
        newMod.setUp(initParams1);

        // Too long
        DeadManSwitchModule newMod2 = new DeadManSwitchModule();
        bytes memory initParams2 = abi.encode(address(safe), bene, 400 days, 2 days);
        vm.expectRevert("INVALID_INTERVAL");
        newMod2.setUp(initParams2);
    }

    function testSetUpWithInvalidPeriod() public {
        DeadManSwitchModule newMod = new DeadManSwitchModule();

        // Too short
        bytes memory initParams1 = abi.encode(address(safe), bene, 7 days, 1 hours);
        vm.expectRevert("INVALID_PERIOD");
        newMod.setUp(initParams1);

        // Too long
        DeadManSwitchModule newMod2 = new DeadManSwitchModule();
        bytes memory initParams2 = abi.encode(address(safe), bene, 7 days, 100 days);
        vm.expectRevert("INVALID_PERIOD");
        newMod2.setUp(initParams2);
    }

    function testSetUpWithBeneficiaryAsOwner() public {
        DeadManSwitchModule newMod = new DeadManSwitchModule();
        bytes memory initParams = abi.encode(address(safe), Owner, 7 days, 2 days);

        vm.expectRevert("BENEFICIARY_IS_OWNER");
        newMod.setUp(initParams);
    }

    // ========== Parameter Update Tests ==========

    function testUpdateHeartbeatInterval() public {
        vm.prank(Owner);
        mod.updateHeartbeatInterval(30 days);

        assertEq(mod.heartbeatInterval(), 30 days);
    }

    function testUpdateHeartbeatIntervalInvalidRange() public {
        // Too short
        vm.prank(Owner);
        vm.expectRevert("INVALID_INTERVAL");
        mod.updateHeartbeatInterval(1 hours);

        // Too long
        vm.prank(Owner);
        vm.expectRevert("INVALID_INTERVAL");
        mod.updateHeartbeatInterval(400 days);
    }

    function testUpdateChallengePeriod() public {
        vm.prank(Owner);
        mod.updateChallengePeriod(7 days);

        assertEq(mod.challengePeriod(), 7 days);
    }

    function testUpdateChallengePeriodInvalidRange() public {
        // Too short
        vm.prank(Owner);
        vm.expectRevert("INVALID_PERIOD");
        mod.updateChallengePeriod(1 hours);

        // Too long
        vm.prank(Owner);
        vm.expectRevert("INVALID_PERIOD");
        mod.updateChallengePeriod(100 days);
    }

    function testUpdateBeneficiary() public {
        vm.prank(Owner);
        mod.updateBeneficiary(newBene);

        assertEq(mod.beneficiary(), newBene);
    }

    function testUpdateBeneficiaryToZeroAddress() public {
        vm.prank(Owner);
        vm.expectRevert("ZERO_ADDRESS");
        mod.updateBeneficiary(address(0));
    }

    function testUpdateBeneficiaryToSameAddress() public {
        vm.prank(Owner);
        vm.expectRevert("SAME_BENEFICIARY");
        mod.updateBeneficiary(bene);
    }

    function testUpdateBeneficiaryToOwner() public {
        vm.prank(Owner);
        vm.expectRevert("BENEFICIARY_IS_OWNER");
        mod.updateBeneficiary(Owner);
    }

    function testCannotUpdateBeneficiaryDuringClaim() public {
        // Trigger claim
        vm.warp(block.timestamp + 8 days);
        vm.prank(bene);
        mod.startClaim();

        // Try to update beneficiary
        vm.prank(Owner);
        vm.expectRevert("CLAIM_IN_PROGRESS");
        mod.updateBeneficiary(newBene);
    }

    function testCannotUpdateChallengePeriodDuringClaim() public {
        // Trigger claim
        vm.warp(block.timestamp + 8 days);
        vm.prank(bene);
        mod.startClaim();

        // Try to update challenge period
        vm.prank(Owner);
        vm.expectRevert("CLAIM_IN_PROGRESS");
        mod.updateChallengePeriod(7 days);
    }

    function testCanUpdateHeartbeatIntervalDuringClaim() public {
        // Trigger claim
        vm.warp(block.timestamp + 8 days);
        vm.prank(bene);
        mod.startClaim();

        // Should succeed
        vm.prank(Owner);
        mod.updateHeartbeatInterval(30 days);

        assertEq(mod.heartbeatInterval(), 30 days);
    }

    function testOnlyOwnerCanUpdateParameters() public {
        vm.prank(bene);
        vm.expectRevert("NOT_SAFE_OWNER");
        mod.updateHeartbeatInterval(30 days);

        vm.prank(bene);
        vm.expectRevert("NOT_SAFE_OWNER");
        mod.updateChallengePeriod(7 days);

        vm.prank(bene);
        vm.expectRevert("NOT_SAFE_OWNER");
        mod.updateBeneficiary(newBene);
    }

    function testBatchUpdateParameters() public {
        vm.prank(Owner);
        mod.updateParameters(30 days, 7 days, newBene);

        assertEq(mod.heartbeatInterval(), 30 days);
        assertEq(mod.challengePeriod(), 7 days);
        assertEq(mod.beneficiary(), newBene);
    }

    function testBatchUpdateParametersSkipUnchanged() public {
        vm.prank(Owner);
        // Only update interval (pass 0 for period, address(0) for beneficiary)
        mod.updateParameters(30 days, 0, address(0));

        assertEq(mod.heartbeatInterval(), 30 days);
        assertEq(mod.challengePeriod(), 2 days); // Unchanged
        assertEq(mod.beneficiary(), bene); // Unchanged
    }

    // ========== Event Tests ==========

    function testUpdateBeneficiaryEmitsEvent() public {
        vm.prank(Owner);

        vm.expectEmit(true, true, false, false);
        emit DeadManSwitchModule.BeneficiaryUpdated(bene, newBene);

        mod.updateBeneficiary(newBene);
    }

    function testUpdateHeartbeatIntervalEmitsEvent() public {
        vm.prank(Owner);

        vm.expectEmit(true, true, false, false);
        emit DeadManSwitchModule.HeartbeatIntervalUpdated(7 days, 30 days);

        mod.updateHeartbeatInterval(30 days);
    }

    function testUpdateChallengePeriodEmitsEvent() public {
        vm.prank(Owner);

        vm.expectEmit(true, true, false, false);
        emit DeadManSwitchModule.ChallengePeriodUpdated(2 days, 7 days);

        mod.updateChallengePeriod(7 days);
    }

    // ========== Integration Test: Update Then Claim ==========

    function testUpdateBeneficiaryThenNewBeneficiaryClaim() public {
        // Update beneficiary
        vm.prank(Owner);
        mod.updateBeneficiary(newBene);

        // Time passes
        vm.warp(block.timestamp + 8 days);

        // Old beneficiary cannot claim
        vm.prank(bene);
        vm.expectRevert("NOT_BENEFICIARY");
        mod.startClaim();

        // New beneficiary can claim
        vm.prank(newBene);
        mod.startClaim();

        vm.warp(block.timestamp + 3 days);
        vm.prank(newBene);
        mod.finalizeClaim();

        address[] memory Owners = safe.getOwners();
        assertEq(Owners[0], newBene);
    }

    function testOwnerCanCancelClaimThenUpdateBeneficiary() public {
        // Time passes, beneficiary starts claim
        vm.warp(block.timestamp + 8 days);
        vm.prank(bene);
        mod.startClaim();

        // Owner checks in to cancel claim
        vm.prank(Owner);
        mod.checkIn();

        // Now owner can update beneficiary
        vm.prank(Owner);
        mod.updateBeneficiary(newBene);

        assertEq(mod.beneficiary(), newBene);
    }

    // ========== Zodiac Avatar/Target Tests ==========

    function testAvatarAndTargetSet() public {
        assertEq(mod.avatar(), address(safe));
        assertEq(mod.target(), address(safe));
    }

    function testStatusReturnsCorrectValues() public {
        (
            address safe_,
            address owner_,
            address beneficiary_,
            uint256 lastCheckIn_,
            uint256 heartbeatInterval_,
            uint256 claimReadyAt_
        ) = mod.status();

        assertEq(safe_, address(safe));
        assertEq(owner_, Owner);
        assertEq(beneficiary_, bene);
        assertGt(lastCheckIn_, 0);
        assertEq(heartbeatInterval_, 7 days);
        assertEq(claimReadyAt_, 0);
    }
}
