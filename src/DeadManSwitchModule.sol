// SPDX-License-Identifier: MIT
// Dead Man's Switch Safe Module
// Version: 3.0 - Zodiac Module Integration
pragma solidity ^0.8.20;

import {Module} from "zodiac/core/Module.sol";
import {ISafe} from "./interfaces/ISafe.sol";

/**
 * @title DeadManSwitchModule
 * @notice A Zodiac module that enables beneficiaries to claim Safe ownership after a heartbeat timeout
 * @dev Inherits from Zodiac Module for factory compatibility and standard interfaces
 */
contract DeadManSwitchModule is Module {
    // ============ State Variables ============

    address public beneficiary;
    uint256 public heartbeatInterval;
    uint256 public challengePeriod;
    uint256 public lastCheckIn;
    uint256 public claimReadyAt;

    address internal constant SENTINEL = address(0x1);

    // ============ Events ============

    // Original events
    event CheckIn(uint256 timestamp);
    event ClaimStarted(uint256 claimReadyAt);
    event ClaimCancelled(uint256 timestamp);
    event ClaimFinalized(address oldOwner, address newOwner);

    // Parameter update events
    event HeartbeatIntervalUpdated(uint256 oldInterval, uint256 newInterval);
    event ChallengePeriodUpdated(uint256 oldPeriod, uint256 newPeriod);
    event BeneficiaryUpdated(address oldBeneficiary, address newBeneficiary);
    event ModuleInitialized(address safe, address beneficiary, uint256 heartbeatInterval, uint256 challengePeriod);

    // ============ Modifiers ============

    modifier onlySafeOwner() {
        require(ISafe(avatar).isOwner(msg.sender), "NOT_SAFE_OWNER");
        _;
    }

    modifier onlyBeneficiary() {
        require(msg.sender == beneficiary, "NOT_BENEFICIARY");
        _;
    }

    modifier notClaiming() {
        require(claimReadyAt == 0, "CLAIM_IN_PROGRESS");
        _;
    }

    // ============ Initialization ============

    /**
     * @notice Initialize the module via Zodiac ModuleProxyFactory
     * @dev This function is called by the factory when deploying a new proxy
     * @param initializeParams ABI-encoded parameters: (safe, beneficiary, interval, challengePeriod)
     */
    function setUp(bytes memory initializeParams) public override initializer {
        // Decode initialization parameters
        (
            address _safe,
            address _beneficiary,
            uint256 _interval,
            uint256 _challengePeriod
        ) = abi.decode(
            initializeParams,
            (address, address, uint256, uint256)
        );

        // Validation
        require(_safe != address(0), "SAFE_ZERO");
        require(_beneficiary != address(0), "BENE_ZERO");
        require(!ISafe(_safe).isOwner(_beneficiary), "BENEFICIARY_IS_OWNER");

        // Initialize Zodiac Module base contracts
        __Ownable_init();
        setAvatar(_safe);
        setTarget(_safe);

        // Initialize module-specific state
        beneficiary = _beneficiary;
        heartbeatInterval = _interval;
        challengePeriod = _challengePeriod;
        lastCheckIn = block.timestamp;

        emit ModuleInitialized(_safe, _beneficiary, _interval, _challengePeriod);
    }

    // ============ Core Functions ============

    /**
     * @notice Owner checks in to reset the heartbeat timer
     * @dev Resets lastCheckIn to current timestamp and cancels any active claim
     */
    function checkIn() external onlySafeOwner {
        lastCheckIn = block.timestamp;
        claimReadyAt = 0;
        emit CheckIn(lastCheckIn);
    }

    /**
     * @notice Beneficiary starts the claim process after heartbeat expires
     * @dev Sets claimReadyAt to current time + challenge period
     */
    function startClaim() external onlyBeneficiary {
        require(block.timestamp > lastCheckIn + heartbeatInterval, "NOT_EXPIRED");
        claimReadyAt = block.timestamp + challengePeriod;
        emit ClaimStarted(claimReadyAt);
    }

    /**
     * @notice Beneficiary finalizes the claim and becomes the new Safe owner
     * @dev Can only be called after challenge period has passed
     */
    function finalizeClaim() external onlyBeneficiary {
        require(claimReadyAt != 0 && block.timestamp >= claimReadyAt, "NOT_READY");

        address[] memory owners = ISafe(avatar).getOwners();
        require(owners.length > 0, "NO_OWNER");
        address oldOwner = owners[0];

        bytes memory data = abi.encodeWithSignature(
            "swapOwner(address,address,address)",
            SENTINEL,
            oldOwner,
            beneficiary
        );

        bool ok = ISafe(avatar).execTransactionFromModule(avatar, 0, data, 0);
        require(ok, "EXEC_FAIL");

        claimReadyAt = 0;
        emit ClaimFinalized(oldOwner, beneficiary);
    }

    /**
     * @notice Get the current status of the module
     * @return safe_ The Safe address
     * @return owner_ The current Safe owner
     * @return beneficiary_ The beneficiary address
     * @return lastCheckIn_ Last check-in timestamp
     * @return heartbeatInterval_ Heartbeat interval in seconds
     * @return claimReadyAt_ Timestamp when claim can be finalized (0 if no active claim)
     */
    function status()
        external
        view
        returns (
            address safe_,
            address owner_,
            address beneficiary_,
            uint256 lastCheckIn_,
            uint256 heartbeatInterval_,
            uint256 claimReadyAt_
        )
    {
        address[] memory owners = ISafe(avatar).getOwners();
        address owner = owners.length > 0 ? owners[0] : address(0);
        return (avatar, owner, beneficiary, lastCheckIn, heartbeatInterval, claimReadyAt);
    }

    // ============ Parameter Update Functions ============

    /**
     * @notice Update the heartbeat interval
     * @param newInterval The new heartbeat interval in seconds
     * @dev Can be called by Safe owner at any time, even during claim process
     */
    function updateHeartbeatInterval(uint256 newInterval) external onlySafeOwner {
        uint256 oldInterval = heartbeatInterval;
        heartbeatInterval = newInterval;

        emit HeartbeatIntervalUpdated(oldInterval, newInterval);
    }

    /**
     * @notice Update the challenge period
     * @param newPeriod The new challenge period in seconds
     * @dev Cannot be called during active claim process
     */
    function updateChallengePeriod(uint256 newPeriod) external onlySafeOwner notClaiming {
        uint256 oldPeriod = challengePeriod;
        challengePeriod = newPeriod;

        emit ChallengePeriodUpdated(oldPeriod, newPeriod);
    }

    /**
     * @notice Update the beneficiary address
     * @param newBeneficiary The new beneficiary address
     * @dev Cannot be called during active claim process
     */
    function updateBeneficiary(address newBeneficiary) external onlySafeOwner notClaiming {
        require(newBeneficiary != address(0), "ZERO_ADDRESS");
        require(newBeneficiary != beneficiary, "SAME_BENEFICIARY");
        require(!ISafe(avatar).isOwner(newBeneficiary), "BENEFICIARY_IS_OWNER");

        address oldBeneficiary = beneficiary;
        beneficiary = newBeneficiary;

        emit BeneficiaryUpdated(oldBeneficiary, newBeneficiary);
    }

    /**
     * @notice Batch update multiple parameters (gas optimization)
     * @param newInterval The new heartbeat interval (0 to skip)
     * @param newPeriod The new challenge period (0 to skip)
     * @param newBeneficiary The new beneficiary address (address(0) to skip)
     * @dev Cannot be called during active claim process
     */
    function updateParameters(
        uint256 newInterval,
        uint256 newPeriod,
        address newBeneficiary
    ) external onlySafeOwner notClaiming {
        // Update heartbeat interval if provided and different
        if (newInterval > 0 && newInterval != heartbeatInterval) {
            uint256 oldInterval = heartbeatInterval;
            heartbeatInterval = newInterval;
            emit HeartbeatIntervalUpdated(oldInterval, newInterval);
        }

        // Update challenge period if provided and different
        if (newPeriod > 0 && newPeriod != challengePeriod) {
            uint256 oldPeriod = challengePeriod;
            challengePeriod = newPeriod;
            emit ChallengePeriodUpdated(oldPeriod, newPeriod);
        }

        // Update beneficiary if provided and different
        if (newBeneficiary != address(0) && newBeneficiary != beneficiary) {
            require(!ISafe(avatar).isOwner(newBeneficiary), "BENEFICIARY_IS_OWNER");
            address oldBeneficiary = beneficiary;
            beneficiary = newBeneficiary;
            emit BeneficiaryUpdated(oldBeneficiary, newBeneficiary);
        }
    }
}
