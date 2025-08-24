// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ISonicGasMonetization } from "../interfaces/ISonicGasMonetization.sol";

/**
 * @title Mock Sonic GasMonetization Contract
 * @dev Mock implementation for testing purposes
 */
contract MockSonicGasMonetization is ISonicGasMonetization {
    // Mock data storage
    mapping(address => uint256) private _ownedProjects;
    mapping(uint256 => Project) private _projects;
    mapping(address => uint256) private _contracts;
    mapping(uint256 => PendingRewardClaimRequest) private _pendingRewardClaims;
    
    uint256 private _lastProjectId = 3; // Start with 3 projects for testing

    constructor() {
        // Projects will be set up in tests using setMockProject
    }

    // Mock setter functions for testing
    function setMockProject(address user, uint256 projectId) external {
        _ownedProjects[user] = projectId;
        if (projectId > 0) {
            _projects[projectId] = Project({
                owner: user,
                rewardsRecipient: user,
                metadataUri: string(abi.encodePacked("ipfs://project", _toString(projectId))),
                lastClaimEpoch: 0,
                activeFromEpoch: 1,
                activeToEpoch: 0
            });
        }
    }

    function setMockPendingRewardClaim(
        uint256 projectId, 
        uint256 epoch, 
        uint256 confirmations, 
        uint256 amount
    ) external {
        _pendingRewardClaims[projectId] = PendingRewardClaimRequest({
            requestedOnEpoch: epoch,
            confirmationsCount: confirmations,
            confirmedAmount: amount,
            confirmedBy: new address[](0)
        });
    }
    
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    // Interface implementations
    function projects(uint256 projectId) external view override returns (Project memory) {
        return _projects[projectId];
    }

    function contracts(address contractAddress) external view override returns (uint256 projectId) {
        return _contracts[contractAddress];
    }

    function ownedProject(address owner) external view override returns (uint256 projectId) {
        return _ownedProjects[owner];
    }

    function lastProjectId() external view override returns (uint256) {
        return _lastProjectId;
    }

    function pendingRewardClaims(uint256 projectId) external view override returns (PendingRewardClaimRequest memory) {
        return _pendingRewardClaims[projectId];
    }

    function hasPendingRewardClaim(uint256 projectId, uint256 epochId) external view override returns (bool) {
        return _pendingRewardClaims[projectId].requestedOnEpoch == epochId;
    }

    function getProjectOwner(uint256 projectId) external view override returns (address) {
        return _projects[projectId].owner;
    }

    function getProjectRewardsRecipient(uint256 projectId) external view override returns (address) {
        return _projects[projectId].rewardsRecipient;
    }

    function getProjectMetadataUri(uint256 projectId) external view override returns (string memory) {
        return _projects[projectId].metadataUri;
    }

    function getProjectLastClaimEpoch(uint256 projectId) external view override returns (uint256) {
        return _projects[projectId].lastClaimEpoch;
    }

    function getProjectActiveFromEpoch(uint256 projectId) external view override returns (uint256) {
        return _projects[projectId].activeFromEpoch;
    }

    function getProjectActiveToEpoch(uint256 projectId) external view override returns (uint256) {
        return _projects[projectId].activeToEpoch;
    }

    function getProjectIdOfContract(address contractAddress) external view override returns (uint256) {
        return _contracts[contractAddress];
    }

    function getPendingRewardClaimEpoch(uint256 projectId) external view override returns (uint256) {
        return _pendingRewardClaims[projectId].requestedOnEpoch;
    }

    function getPendingRewardClaimConfirmationsCount(uint256 projectId) external view override returns (uint256) {
        return _pendingRewardClaims[projectId].confirmationsCount;
    }

    function getPendingRewardClaimConfirmedAmount(uint256 projectId) external view override returns (uint256) {
        return _pendingRewardClaims[projectId].confirmedAmount;
    }

    function getPendingRewardClaimConfirmedBy(uint256 projectId) external view override returns (address[] memory) {
        return _pendingRewardClaims[projectId].confirmedBy;
    }

    // State-changing functions (mock implementations)
    function newRewardClaim(uint256 projectId) external override {
        // Mock implementation - just emit event
        emit RewardClaimRequested(projectId, block.timestamp);
    }

    function cancelRewardClaim(uint256 projectId, uint256 epochNumber) external override {
        // Mock implementation - just emit event
        emit RewardClaimCanceled(projectId, epochNumber);
    }

    function addProject(
        address owner,
        address rewardsRecipient,
        string calldata metadataUri,
        address[] calldata projectContracts
    ) external override {
        // Mock implementation - just emit event
        emit ProjectAdded(_lastProjectId + 1, owner, rewardsRecipient, metadataUri, block.timestamp, projectContracts);
    }

    function addProjectContract(uint256 projectId, address contractAddress) external override {
        // Mock implementation - just emit event
        emit ProjectContractAdded(projectId, contractAddress);
    }

    function removeProjectContract(uint256 projectId, address contractAddress) external override {
        // Mock implementation - just emit event
        emit ProjectContractRemoved(projectId, contractAddress);
    }

    function updateProjectRewardsRecipient(uint256 projectId, address recipient) external override {
        // Mock implementation - just emit event
        emit ProjectRewardsRecipientUpdated(projectId, recipient);
    }
}
