// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title Interface for Sonic GasMonetization Contract
 * @dev Interface for the real Sonic blockchain gas monetization system
 * Contract address: 0x0B5f073135dF3f5671710F08b08C0c9258aECc35
 */
interface ISonicGasMonetization {
    // Structs
    struct Project {
        address owner;
        address rewardsRecipient;
        string metadataUri;
        uint256 lastClaimEpoch;
        uint256 activeFromEpoch;
        uint256 activeToEpoch;
    }

    struct PendingRewardClaimRequest {
        uint256 requestedOnEpoch;
        uint256 confirmationsCount;
        uint256 confirmedAmount;
        address[] confirmedBy;
    }

    // Events
    event ProjectAdded(
        uint256 indexed projectId,
        address indexed owner,
        address indexed rewardsRecipient,
        string metadataUri,
        uint256 activeFromEpoch,
        address[] contracts
    );
    event ProjectContractAdded(uint256 indexed projectId, address indexed contractAddress);
    event ProjectContractRemoved(uint256 indexed projectId, address indexed contractAddress);
    event ProjectRewardsRecipientUpdated(uint256 indexed projectId, address recipient);
    event RewardClaimRequested(uint256 indexed projectId, uint256 requestEpochNumber);
    event RewardClaimCompleted(uint256 indexed projectId, uint256 epochNumber, uint256 amount);
    event RewardClaimCanceled(uint256 indexed projectId, uint256 epochNumber);

    // View functions
    function projects(uint256 projectId) external view returns (Project memory);
    function contracts(address contractAddress) external view returns (uint256 projectId);
    function ownedProject(address owner) external view returns (uint256 projectId);
    function lastProjectId() external view returns (uint256);
    function pendingRewardClaims(uint256 projectId) external view returns (PendingRewardClaimRequest memory);
    function hasPendingRewardClaim(uint256 projectId, uint256 epochId) external view returns (bool);
    function getProjectOwner(uint256 projectId) external view returns (address);
    function getProjectRewardsRecipient(uint256 projectId) external view returns (address);
    function getProjectMetadataUri(uint256 projectId) external view returns (string memory);
    function getProjectLastClaimEpoch(uint256 projectId) external view returns (uint256);
    function getProjectActiveFromEpoch(uint256 projectId) external view returns (uint256);
    function getProjectActiveToEpoch(uint256 projectId) external view returns (uint256);
    function getProjectIdOfContract(address contractAddress) external view returns (uint256);
    function getPendingRewardClaimEpoch(uint256 projectId) external view returns (uint256);
    function getPendingRewardClaimConfirmationsCount(uint256 projectId) external view returns (uint256);
    function getPendingRewardClaimConfirmedAmount(uint256 projectId) external view returns (uint256);
    function getPendingRewardClaimConfirmedBy(uint256 projectId) external view returns (address[] memory);

    // State-changing functions
    function newRewardClaim(uint256 projectId) external;
    function cancelRewardClaim(uint256 projectId, uint256 epochNumber) external;
    function addProject(
        address owner,
        address rewardsRecipient,
        string calldata metadataUri,
        address[] calldata projectContracts
    ) external;
    function addProjectContract(uint256 projectId, address contractAddress) external;
    function removeProjectContract(uint256 projectId, address contractAddress) external;
    function updateProjectRewardsRecipient(uint256 projectId, address recipient) external;
}
