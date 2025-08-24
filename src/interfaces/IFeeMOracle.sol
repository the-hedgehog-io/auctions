// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

/**
 * @title Interface for FeeM Oracle
 * @dev Interface for interacting with Sonic blockchain's FeeM system
 * Based on Sonic FeeM documentation: https://docs.soniclabs.com/funding/fee-monetization
 */
interface IFeeMOracle {
    /**
     * @dev Struct containing FeeM delegation information
     */
    struct FeeMDelegation {
        address delegator;           // Address of the project/contract owner
        address delegate;            // Address where FeeM rewards are delegated (can be the same as delegator)
        uint256 delegationAmount;    // Amount of FeeM rewards delegated
        uint256 startTime;           // When the delegation starts
        uint256 endTime;             // When the delegation ends (0 for indefinite)
        bool isActive;               // Whether delegation is currently active
    }

    /**
     * @dev Struct containing FeeM reward information
     */
    struct FeeMReward {
        address projectContract;     // The contract address registered for FeeM
        uint256 gasConsumed;         // Total gas consumed by this contract
        uint256 feeMRewards;         // FeeM rewards earned
        uint256 lastClaimTime;       // Last time rewards were claimed
        uint256 epoch;               // Current epoch for reward calculation
    }

    /**
     * @dev Struct containing contract registration information
     */
    struct ContractRegistration {
        address contractAddress;     // Address of the contract to register
        address owner;               // Owner of the contract
        bool isRegistered;           // Whether the contract is registered for FeeM
        uint256 registrationTime;    // When the contract was registered
        uint256 totalGasConsumed;    // Total gas consumed since registration
    }

    /**
     * @notice Check if a user has FeeM delegation capability
     * @param user Address to check
     * @return canDelegate Whether the user can delegate FeeM
     * @return maxDelegation Maximum amount that can be delegated
     */
    function canDelegateFeeM(address user) external view returns (bool canDelegate, uint256 maxDelegation);

    /**
     * @notice Get estimated FeeM rewards for a specific time period
     * @param projectContract Address of the project contract
     * @param startTime Start of the period
     * @param endTime End of the period
     * @return estimatedRewards Estimated FeeM rewards for the period
     * @return gasConsumed Total gas consumed during the period
     */
    function getEstimatedFeeMRewards(
        address projectContract, 
        uint256 startTime, 
        uint256 endTime
    ) external view returns (uint256 estimatedRewards, uint256 gasConsumed);

    /**
     * @notice Check if FeeM delegation is supported for a contract
     * @return isSupported Whether FeeM delegation is supported
     */
    function isFeeMDelegationSupported() external view returns (bool isSupported);

    /**
     * @notice Get the current FeeM delegation target for a user
     * @param user Address to check
     * @return delegate Current delegation target
     * @return amount Amount currently delegated
     */
    function getFeeMDelegationTarget(address user) external view returns (address delegate, uint256 amount);

    /**
     * @notice Set the FeeM delegation target
     * @param delegate Address to delegate FeeM rewards to
     * @param amount Amount to delegate
     */
    function setFeeMDelegationTarget(address delegate, uint256 amount) external;

    /**
     * @notice Get historical FeeM rewards for a contract
     * @param projectContract Address of the project contract
     * @param epochs Number of epochs to look back
     * @return rewards Array of historical rewards
     */
    function getHistoricalFeeMRewards(
        address projectContract, 
        uint256 epochs
    ) external view returns (FeeMReward[] memory rewards);

    /**
     * @notice Check if a contract is registered for FeeM
     * @param contractAddress Address of the contract to check
     * @return isRegistered Whether the contract is registered
     * @return owner Owner of the contract
     */
    function isContractRegistered(address contractAddress) external view returns (bool isRegistered, address owner);

    /**
     * @notice Get current epoch information
     * @return currentEpoch Current epoch number
     * @return epochStartTime When the current epoch started
     * @return epochDuration Duration of each epoch
     */
    function getCurrentEpoch() external view returns (uint256 currentEpoch, uint256 epochStartTime, uint256 epochDuration);

    /**
     * @notice Check if oracle quorum has been reached for a reward claim
     * @param projectContract Address of the project contract
     * @param epoch Epoch to check
     * @return quorumReached Whether quorum has been reached
     * @return confirmations Number of oracle confirmations
     * @return requiredConfirmations Number of confirmations required for quorum
     */
    function checkOracleQuorum(
        address projectContract, 
        uint256 epoch
    ) external view returns (bool quorumReached, uint256 confirmations, uint256 requiredConfirmations);
}
