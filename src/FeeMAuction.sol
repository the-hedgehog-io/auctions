// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ISonicGasMonetization } from "./interfaces/ISonicGasMonetization.sol";

/**
 * @title FeeM Auction Contract
 * @dev This contract allows users to auction their future FeeM rewards from Sonic blockchain
 * Users can auction off 1-month periods of FeeM rewards, with the project getting funding upfront
 * and the auction winner receiving the actual FeeM rewards when they're distributed
 * 
 * Integrates with real Sonic GasMonetization contract: 0x0B5f073135dF3f5671710F08b08C0c9258aECc35
 */
contract FeeMAuction is ReentrancyGuard, Pausable, Ownable {
    using SafeERC20 for IERC20;

    // Constants
    uint256 public constant AUCTION_DURATION = 7 days;        // Auction runs for 7 days
    uint256 public constant REWARD_PERIOD = 30 days;          // FeeM rewards period is 1 month
    uint256 public constant MIN_AUCTION_AMOUNT = 0.01 ether;  // Minimum auction amount
    uint256 public constant MAX_AUCTION_AMOUNT = 1000 ether;  // Maximum auction amount

    // State variables
    ISonicGasMonetization public immutable sonicGasMonetization;
    address public immutable feeMToken;                       // FeeM token address (S token on Sonic)
    
    uint256 public auctionCounter;
    uint256 public totalFeeMRewardsDistributed;
    uint256 public totalProjectFunding;
    
    // Fee structure
    uint256 public platformFeePercentage = 2;                 // 2% platform fee
    
    // Mapping from auction ID to FeeM auction details
    mapping(uint256 => FeeMAuctionInfo) public feeMAuctions;
    
    // Mapping from user to their active auctions
    mapping(address => uint256[]) public userAuctions;
    
    // Mapping from user to their registered project ID in Sonic
    mapping(address => uint256) public userProjectIds;

    /**
     * @dev Struct containing FeeM auction information
     */
    struct FeeMAuctionInfo {
        address creator;                 // Address creating the auction
        uint256 minBidAmount;            // Minimum bid amount
        uint256 startTime;               // When auction starts
        uint256 endTime;                 // When auction ends
        uint256 rewardPeriodStart;       // When FeeM reward period starts
        uint256 rewardPeriodEnd;         // When FeeM reward period ends
        bool isActive;                   // Whether auction is active
        bool isSettled;                  // Whether auction has been settled
        address currentHighestBidder;    // Current highest bidder
        uint256 currentHighestBid;       // Current highest bid amount
        uint256 projectId;               // Sonic project ID for this auction
        string projectMetadataUri;       // Project metadata URI
    }

    // Events
    event FeeMAuctionCreated(
        uint256 indexed auctionId,
        address indexed creator,
        uint256 minBidAmount,
        uint256 startTime,
        uint256 endTime,
        uint256 rewardPeriodStart,
        uint256 rewardPeriodEnd,
        uint256 projectId
    );
    
    event FeeMAuctionStarted(uint256 indexed auctionId);
    event FeeMAuctionEnded(uint256 indexed auctionId);
    event FeeMAuctionSettled(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 winningBid,
        uint256 feeMRewards
    );
    
    event BidPlaced(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount,
        address indexed previousBidder,
        uint256 refundAmount
    );
    
    event FeeMRewardsClaimed(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 amount
    );
    
    event ProjectRegistered(
        uint256 indexed auctionId,
        uint256 indexed projectId,
        address indexed creator,
        string metadataUri
    );
    
    event PlatformFeeUpdated(uint256 newPercentage);

    // Modifiers
    modifier onlyFeeMAuctionCreator(uint256 auctionId) {
        require(feeMAuctions[auctionId].creator == msg.sender, "Only auction creator can call this");
        _;
    }
    
    modifier onlyActiveAuction(uint256 auctionId) {
        require(feeMAuctions[auctionId].isActive, "Auction not active");
        _;
    }
    
    modifier onlySettledAuction(uint256 auctionId) {
        require(feeMAuctions[auctionId].isSettled, "Auction not settled");
        _;
    }

    /**
     * @notice Constructor
     * @param _sonicGasMonetization Address of Sonic GasMonetization contract
     * @param _feeMToken Address of FeeM token (S token on Sonic)
     */
    constructor(
        address _sonicGasMonetization,
        address _feeMToken
    ) Ownable(msg.sender) {
        require(_sonicGasMonetization != address(0), "Invalid gas monetization address");
        require(_feeMToken != address(0), "Invalid FeeM token address");
        
        sonicGasMonetization = ISonicGasMonetization(_sonicGasMonetization);
        feeMToken = _feeMToken;
    }

    /**
     * @notice Create a new FeeM auction
     * @param minBidAmount Minimum bid amount in ETH
     * @param startTime When the auction should start
     * @return auctionId ID of the created auction
     */
    function createFeeMAuction(
        uint256 minBidAmount,
        uint256 startTime
    ) external whenNotPaused returns (uint256 auctionId) {
        require(minBidAmount >= MIN_AUCTION_AMOUNT, "Bid amount too low");
        require(minBidAmount <= MAX_AUCTION_AMOUNT, "Bid amount too high");
        require(startTime > block.timestamp, "Start time must be in future");
        
        // Check if user has a registered project in Sonic
        uint256 projectId = sonicGasMonetization.ownedProject(msg.sender);
        require(projectId > 0, "Must have registered project in Sonic");
        
        // Check if project is active
        ISonicGasMonetization.Project memory project = sonicGasMonetization.projects(projectId);
        require(project.activeToEpoch == 0, "Project is suspended");
        
        auctionId = auctionCounter++;
        
        feeMAuctions[auctionId] = FeeMAuctionInfo({
            creator: msg.sender,
            minBidAmount: minBidAmount,
            startTime: startTime,
            endTime: startTime + AUCTION_DURATION,
            rewardPeriodStart: startTime + AUCTION_DURATION,
            rewardPeriodEnd: startTime + AUCTION_DURATION + REWARD_PERIOD,
            isActive: false,
            isSettled: false,
            currentHighestBidder: address(0),
            currentHighestBid: 0,
            projectId: projectId,
            projectMetadataUri: project.metadataUri
        });
        
        userAuctions[msg.sender].push(auctionId);
        userProjectIds[msg.sender] = projectId;
        
        emit FeeMAuctionCreated(
            auctionId,
            msg.sender,
            minBidAmount,
            startTime,
            startTime + AUCTION_DURATION,
            startTime + AUCTION_DURATION,
            startTime + AUCTION_DURATION + REWARD_PERIOD,
            projectId
        );
    }

    /**
     * @notice Start a FeeM auction
     * @param auctionId ID of the auction to start
     */
    function startFeeMAuction(uint256 auctionId) 
        external 
        whenNotPaused 
        onlyFeeMAuctionCreator(auctionId) 
    {
        FeeMAuctionInfo storage auction = feeMAuctions[auctionId];
        require(block.timestamp >= auction.startTime, "Start time not reached");
        require(!auction.isActive, "Auction already active");
        require(!auction.isSettled, "Auction already settled");
        
        auction.isActive = true;
        
        emit FeeMAuctionStarted(auctionId);
    }

    /**
     * @notice Place a bid on an active FeeM auction
     * @param auctionId ID of the auction to bid on
     */
    function placeBid(uint256 auctionId) 
        external 
        payable 
        nonReentrant 
        whenNotPaused 
        onlyActiveAuction(auctionId) 
    {
        FeeMAuctionInfo storage auction = feeMAuctions[auctionId];
        require(block.timestamp < auction.endTime, "Auction ended");
        require(msg.value >= auction.minBidAmount, "Bid too low");
        
        address previousBidder = auction.currentHighestBidder;
        uint256 previousBid = auction.currentHighestBid;
        
        // Calculate minimum bid increment (5% of current highest bid)
        uint256 minIncrement = previousBid > 0 ? (previousBid * 5) / 100 : 0;
        uint256 minBid = previousBid + minIncrement;
        
        require(msg.value >= minBid, "Bid must be higher than minimum increment");
        
        // Refund previous bidder if exists
        if (previousBidder != address(0)) {
            payable(previousBidder).transfer(previousBid);
        }
        
        // Update auction state
        auction.currentHighestBidder = msg.sender;
        auction.currentHighestBid = msg.value;
        
        emit BidPlaced(auctionId, msg.sender, msg.value, previousBidder, previousBid);
    }

    /**
     * @notice End a FeeM auction and settle it
     * @param auctionId ID of the auction to end
     */
    function endFeeMAuction(uint256 auctionId) 
        external 
        nonReentrant 
        whenNotPaused 
        onlyActiveAuction(auctionId) 
    {
        FeeMAuctionInfo storage auction = feeMAuctions[auctionId];
        require(block.timestamp >= auction.endTime, "Auction not ended yet");

        // Get auction results from our stored data
        address winner = auction.currentHighestBidder;
        uint256 winningBid = auction.currentHighestBid;
        
        if (winner != address(0)) {
            // Auction was successful
            auction.isSettled = true;
            auction.isActive = false;
            
            // Calculate fees
            uint256 platformFee = (winningBid * platformFeePercentage) / 100;
            uint256 creatorAmount = winningBid - platformFee;

            // Transfer funds
            if (platformFee > 0) {
                payable(owner()).transfer(platformFee);
            }
            
            if (creatorAmount > 0) {
                payable(auction.creator).transfer(creatorAmount);
            }

            totalProjectFunding += creatorAmount;

            emit FeeMAuctionSettled(
                auctionId,
                winner,
                winningBid,
                0 // FeeM rewards will be claimed later
            );
        } else {
            // Auction failed - no bids
            auction.isActive = false;
            auction.isSettled = true;
        }
    }

    /**
     * @notice Request FeeM reward claim for an auction (called by auction winner)
     * @param auctionId ID of the FeeM auction
     */
    function requestFeeMRewardClaim(uint256 auctionId) 
        external 
        nonReentrant 
        whenNotPaused 
        onlySettledAuction(auctionId) 
    {
        FeeMAuctionInfo storage auction = feeMAuctions[auctionId];
        require(block.timestamp >= auction.rewardPeriodEnd, "Reward period not ended");
        require(auction.currentHighestBidder == msg.sender, "Only auction winner can request claim");
        
        // Check if project is still active
        ISonicGasMonetization.Project memory project = sonicGasMonetization.projects(auction.projectId);
        require(project.activeToEpoch == 0, "Project is suspended");
        
        // Request reward claim from Sonic GasMonetization
        sonicGasMonetization.newRewardClaim(auction.projectId);
        
        emit FeeMRewardsClaimed(auctionId, msg.sender, 0); // Amount will be known after oracle confirmation
    }

    /**
     * @notice Check if FeeM rewards are ready to be claimed for an auction
     * @param auctionId ID of the FeeM auction
     * @return isReady Whether rewards are ready
     * @return confirmedAmount Amount confirmed by oracles
     * @return confirmationsCount Number of oracle confirmations
     */
    function checkFeeMRewardStatus(uint256 auctionId) 
        external 
        view 
        returns (bool isReady, uint256 confirmedAmount, uint256 confirmationsCount) 
    {
        FeeMAuctionInfo storage auction = feeMAuctions[auctionId];
        require(auction.isSettled, "Auction not settled");
        
        uint256 projectId = auction.projectId;
        uint256 pendingEpoch = sonicGasMonetization.getPendingRewardClaimEpoch(projectId);
        
        if (pendingEpoch > 0) {
            confirmationsCount = sonicGasMonetization.getPendingRewardClaimConfirmationsCount(projectId);
            confirmedAmount = sonicGasMonetization.getPendingRewardClaimConfirmedAmount(projectId);
            
            // Check if enough confirmations (this would need to be configured based on Sonic's requirements)
            isReady = confirmationsCount >= 3; // Assuming 3 confirmations required
        }
    }

    /**
     * @notice Get user's active auctions
     * @param user Address to check
     * @return Array of auction IDs
     */
    function getUserAuctions(address user) external view returns (uint256[] memory) {
        return userAuctions[user];
    }

    /**
     * @notice Get auction information
     * @param auctionId ID of the auction
     * @return Auction information
     */
    function getFeeMAuction(uint256 auctionId) external view returns (FeeMAuctionInfo memory) {
        return feeMAuctions[auctionId];
    }

    /**
     * @notice Get user's Sonic project ID
     * @param user Address to check
     * @return Project ID in Sonic system
     */
    function getUserProjectId(address user) external view returns (uint256) {
        return userProjectIds[user];
    }

    /**
     * @notice Update platform fee percentage (only owner)
     * @param newFeePercentage New fee percentage
     */
    function setPlatformFeePercentage(uint256 newFeePercentage) external onlyOwner {
        require(newFeePercentage <= 10, "Fee cannot exceed 10%");
        platformFeePercentage = newFeePercentage;
        emit PlatformFeeUpdated(newFeePercentage);
    }

    /**
     * @notice Pause the contract (only owner)
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the contract (only owner)
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Emergency withdraw function (only owner)
     * @param token Token to withdraw (address(0) for ETH)
     * @param amount Amount to withdraw
     * @param to Recipient address
     */
    function emergencyWithdraw(address token, uint256 amount, address to) external onlyOwner {
        require(to != address(0), "Invalid recipient");
        
        if (token == address(0)) {
            require(amount <= address(this).balance, "Insufficient ETH balance");
            payable(to).transfer(amount);
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    // Receive function to accept ETH
    receive() external payable {}
}
