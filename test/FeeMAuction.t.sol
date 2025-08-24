// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { FeeMAuction } from "../src/FeeMAuction.sol";
import { MockSonicGasMonetization } from "../src/mocks/MockSonicGasMonetization.sol";

/**
 * @title FeeM Auction Test Contract
 * @dev Comprehensive tests for the FeeM auction system
 */
contract FeeMAuctionTest is Test {
    FeeMAuction public feeMAuction;
    MockSonicGasMonetization public mockSonicGasMonetization;
    
    // Test addresses
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");
    address public owner = makeAddr("owner");
    
    address public feeMToken = address(0x456); // Mock FeeM token address for testing
    
    // Test data
    uint256 public constant MIN_BID = 0.01 ether;
    uint256 public constant START_TIME = 1000;
    uint256 public constant AUCTION_DURATION = 7 days;
    uint256 public constant REWARD_PERIOD = 30 days;

    function setUp() public {
        // Deploy Mock Sonic GasMonetization
        mockSonicGasMonetization = new MockSonicGasMonetization();
        
        // Deploy FeeMAuction with mock Sonic GasMonetization
        feeMAuction = new FeeMAuction(address(mockSonicGasMonetization), feeMToken);
        
        // Transfer ownership to test owner
        feeMAuction.transferOwnership(owner);
        
        // Setup test users with ETH
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
        vm.deal(owner, 100 ether);
        
        // Setup mock projects for testing
        mockSonicGasMonetization.setMockProject(user1, 1);
        mockSonicGasMonetization.setMockProject(user2, 2);
        mockSonicGasMonetization.setMockProject(user3, 3);
    }

    function test_Constructor() public {
        assertEq(address(feeMAuction.sonicGasMonetization()), address(mockSonicGasMonetization));
        assertEq(feeMAuction.feeMToken(), feeMToken);
        assertEq(feeMAuction.owner(), owner);
        assertEq(feeMAuction.auctionCounter(), 0);
        assertEq(feeMAuction.platformFeePercentage(), 2);
    }

    function test_CreateFeeMAuction() public {
        vm.warp(START_TIME - 1);
        
        vm.prank(user1);
        uint256 auctionId = feeMAuction.createFeeMAuction(MIN_BID, START_TIME);
        
        assertEq(auctionId, 0);
        assertEq(feeMAuction.auctionCounter(), 1);
        
        FeeMAuction.FeeMAuctionInfo memory auction = feeMAuction.getFeeMAuction(auctionId);
        assertEq(auction.creator, user1);
        assertEq(auction.minBidAmount, MIN_BID);
        assertEq(auction.startTime, START_TIME);
        assertEq(auction.endTime, START_TIME + AUCTION_DURATION);
        assertEq(auction.rewardPeriodStart, START_TIME + AUCTION_DURATION);
        assertEq(auction.rewardPeriodEnd, START_TIME + AUCTION_DURATION + REWARD_PERIOD);
        assertEq(auction.projectId, 1);
        assertEq(auction.projectMetadataUri, "ipfs://project1");
        assertFalse(auction.isActive);
        assertFalse(auction.isSettled);
    }

    function test_CreateFeeMAuction_InvalidBidAmount() public {
        vm.warp(START_TIME - 1);
        
        vm.expectRevert("Bid amount too low");
        feeMAuction.createFeeMAuction(0.005 ether, START_TIME);
        
        vm.expectRevert("Bid amount too high");
        feeMAuction.createFeeMAuction(2000 ether, START_TIME);
    }

    function test_CreateFeeMAuction_InvalidStartTime() public {
        vm.warp(START_TIME);
        
        vm.expectRevert("Start time must be in future");
        feeMAuction.createFeeMAuction(MIN_BID, START_TIME);
    }

    function test_CreateFeeMAuction_NoFeeMDelegation() public {
        vm.warp(START_TIME - 1);
        
        // Mock user without project
        mockSonicGasMonetization.setMockProject(address(0x999), 0);
        
        vm.expectRevert("Must have registered project in Sonic");
        feeMAuction.createFeeMAuction(MIN_BID, START_TIME);
    }

    function test_StartFeeMAuction() public {
        vm.warp(START_TIME - 1);
        
        vm.prank(user1);
        uint256 auctionId = feeMAuction.createFeeMAuction(MIN_BID, START_TIME);
        
        vm.warp(START_TIME);
        vm.prank(user1);
        feeMAuction.startFeeMAuction(auctionId);
        
        FeeMAuction.FeeMAuctionInfo memory auction = feeMAuction.getFeeMAuction(auctionId);
        assertTrue(auction.isActive);
    }

    function test_StartFeeMAuction_AlreadyActive() public {
        vm.warp(START_TIME - 1);
        
        vm.prank(user1);
        uint256 auctionId = feeMAuction.createFeeMAuction(MIN_BID, START_TIME);
        
        vm.warp(START_TIME);
        vm.prank(user1);
        feeMAuction.startFeeMAuction(auctionId);
        
        vm.expectRevert("Auction already active");
        vm.prank(user1);
        feeMAuction.startFeeMAuction(auctionId);
    }

    function test_StartFeeMAuction_NotCreator() public {
        vm.warp(START_TIME - 1);
        
        vm.prank(user1);
        uint256 auctionId = feeMAuction.createFeeMAuction(MIN_BID, START_TIME);
        
        vm.warp(START_TIME);
        vm.prank(user2);
        vm.expectRevert("Only auction creator can call this");
        feeMAuction.startFeeMAuction(auctionId);
    }

    function test_StartFeeMAuction_StartTimeNotReached() public {
        vm.warp(START_TIME - 1);
        
        vm.prank(user1);
        uint256 auctionId = feeMAuction.createFeeMAuction(MIN_BID, START_TIME);
        
        vm.expectRevert("Start time not reached");
        vm.prank(user1);
        feeMAuction.startFeeMAuction(auctionId);
    }

    function test_PlaceBid() public {
        vm.warp(START_TIME - 1);
        
        vm.prank(user1);
        uint256 auctionId = feeMAuction.createFeeMAuction(MIN_BID, START_TIME);
        
        vm.warp(START_TIME);
        vm.prank(user1);
        feeMAuction.startFeeMAuction(auctionId);
        
        uint256 bidAmount = 1 ether;
        vm.prank(user2);
        feeMAuction.placeBid{value: bidAmount}(auctionId);
        
        FeeMAuction.FeeMAuctionInfo memory auction = feeMAuction.getFeeMAuction(auctionId);
        assertEq(auction.currentHighestBidder, user2);
        assertEq(auction.currentHighestBid, bidAmount);
    }

    function test_PlaceBid_AuctionEnded() public {
        vm.warp(START_TIME - 1);
        
        vm.prank(user1);
        uint256 auctionId = feeMAuction.createFeeMAuction(MIN_BID, START_TIME);
        
        vm.warp(START_TIME);
        vm.prank(user1);
        feeMAuction.startFeeMAuction(auctionId);
        
        vm.warp(START_TIME + AUCTION_DURATION + 1);
        
        vm.prank(user2);
        vm.expectRevert("Auction ended");
        feeMAuction.placeBid{value: 1 ether}(auctionId);
    }

    function test_PlaceBid_AuctionNotActive() public {
        vm.warp(START_TIME - 1);
        
        vm.prank(user1);
        uint256 auctionId = feeMAuction.createFeeMAuction(MIN_BID, START_TIME);
        
        vm.prank(user2);
        vm.expectRevert("Auction not active");
        feeMAuction.placeBid{value: 1 ether}(auctionId);
    }

    function test_PlaceBid_BidNotHigher() public {
        vm.warp(START_TIME - 1);
        
        vm.prank(user1);
        uint256 auctionId = feeMAuction.createFeeMAuction(MIN_BID, START_TIME);
        
        vm.warp(START_TIME);
        vm.prank(user1);
        feeMAuction.startFeeMAuction(auctionId);
        
        uint256 firstBid = 1 ether;
        vm.prank(user2);
        feeMAuction.placeBid{value: firstBid}(auctionId);
        
        uint256 secondBid = 1 ether; // Same amount
        vm.prank(user3);
        vm.expectRevert("Bid must be higher than minimum increment");
        feeMAuction.placeBid{value: secondBid}(auctionId);
    }

    function test_PlaceBid_BidTooLow() public {
        vm.warp(START_TIME - 1);
        
        vm.prank(user1);
        uint256 auctionId = feeMAuction.createFeeMAuction(MIN_BID, START_TIME);
        
        vm.warp(START_TIME);
        vm.prank(user1);
        feeMAuction.startFeeMAuction(auctionId);
        
        vm.prank(user2);
        vm.expectRevert("Bid too low");
        feeMAuction.placeBid{value: 0.005 ether}(auctionId);
    }

    function test_EndFeeMAuction() public {
        vm.warp(START_TIME - 1);
        
        vm.prank(user1);
        uint256 auctionId = feeMAuction.createFeeMAuction(MIN_BID, START_TIME);
        
        vm.warp(START_TIME);
        vm.prank(user1);
        feeMAuction.startFeeMAuction(auctionId);
        
        uint256 bidAmount = 1 ether;
        vm.prank(user2);
        feeMAuction.placeBid{value: bidAmount}(auctionId);
        
        vm.warp(START_TIME + AUCTION_DURATION + 1);
        vm.prank(user1);
        feeMAuction.endFeeMAuction(auctionId);
        
        FeeMAuction.FeeMAuctionInfo memory auction = feeMAuction.getFeeMAuction(auctionId);
        assertTrue(auction.isSettled);
        assertFalse(auction.isActive);
    }

    function test_EndFeeMAuction_NotActive() public {
        vm.warp(START_TIME - 1);
        
        vm.prank(user1);
        uint256 auctionId = feeMAuction.createFeeMAuction(MIN_BID, START_TIME);
        
        vm.expectRevert("Auction not active");
        feeMAuction.endFeeMAuction(auctionId);
    }

    function test_EndFeeMAuction_NotEnded() public {
        vm.warp(START_TIME - 1);
        
        vm.prank(user1);
        uint256 auctionId = feeMAuction.createFeeMAuction(MIN_BID, START_TIME);
        
        vm.warp(START_TIME);
        vm.prank(user1);
        feeMAuction.startFeeMAuction(auctionId);
        
        vm.expectRevert("Auction not ended yet");
        vm.prank(user1);
        feeMAuction.endFeeMAuction(auctionId);
    }

    function test_RequestFeeMRewardClaim() public {
        vm.warp(START_TIME - 1);
        
        vm.prank(user1);
        uint256 auctionId = feeMAuction.createFeeMAuction(MIN_BID, START_TIME);
        
        vm.warp(START_TIME);
        vm.prank(user1);
        feeMAuction.startFeeMAuction(auctionId);
        
        uint256 bidAmount = 1 ether;
        vm.prank(user2);
        feeMAuction.placeBid{value: bidAmount}(auctionId);
        
        vm.warp(START_TIME + AUCTION_DURATION + 1);
        vm.prank(user1);
        feeMAuction.endFeeMAuction(auctionId);
        
        vm.warp(START_TIME + AUCTION_DURATION + REWARD_PERIOD + 1);
        
        vm.prank(user2);
        feeMAuction.requestFeeMRewardClaim(auctionId);
    }

    function test_RequestFeeMRewardClaim_NotSettled() public {
        vm.warp(START_TIME - 1);
        
        vm.prank(user1);
        uint256 auctionId = feeMAuction.createFeeMAuction(MIN_BID, START_TIME);
        
        vm.expectRevert("Auction not settled");
        feeMAuction.requestFeeMRewardClaim(auctionId);
    }

    function test_RequestFeeMRewardClaim_RewardPeriodNotEnded() public {
        vm.warp(START_TIME - 1);
        
        vm.prank(user1);
        uint256 auctionId = feeMAuction.createFeeMAuction(MIN_BID, START_TIME);
        
        vm.warp(START_TIME);
        vm.prank(user1);
        feeMAuction.startFeeMAuction(auctionId);
        
        uint256 bidAmount = 1 ether;
        vm.prank(user2);
        feeMAuction.placeBid{value: bidAmount}(auctionId);
        
        vm.warp(START_TIME + AUCTION_DURATION + 1);
        vm.prank(user1);
        feeMAuction.endFeeMAuction(auctionId);
        
        vm.expectRevert("Reward period not ended");
        vm.prank(user2);
        feeMAuction.requestFeeMRewardClaim(auctionId);
    }

    function test_RequestFeeMRewardClaim_NotWinner() public {
        vm.warp(START_TIME - 1);
        
        vm.prank(user1);
        uint256 auctionId = feeMAuction.createFeeMAuction(MIN_BID, START_TIME);
        
        vm.warp(START_TIME);
        vm.prank(user1);
        feeMAuction.startFeeMAuction(auctionId);
        
        uint256 bidAmount = 1 ether;
        vm.prank(user2);
        feeMAuction.placeBid{value: bidAmount}(auctionId);
        
        vm.warp(START_TIME + AUCTION_DURATION + 1);
        vm.prank(user1);
        feeMAuction.endFeeMAuction(auctionId);
        
        vm.warp(START_TIME + AUCTION_DURATION + REWARD_PERIOD + 1);
        
        vm.prank(user3);
        vm.expectRevert("Only auction winner can request claim");
        feeMAuction.requestFeeMRewardClaim(auctionId);
    }

    function test_CheckFeeMRewardStatus() public {
        vm.warp(START_TIME - 1);
        
        vm.prank(user1);
        uint256 auctionId = feeMAuction.createFeeMAuction(MIN_BID, START_TIME);
        
        vm.warp(START_TIME);
        vm.prank(user1);
        feeMAuction.startFeeMAuction(auctionId);
        
        uint256 bidAmount = 1 ether;
        vm.prank(user2);
        feeMAuction.placeBid{value: bidAmount}(auctionId);
        
        vm.warp(START_TIME + AUCTION_DURATION + 1);
        vm.prank(user1);
        feeMAuction.endFeeMAuction(auctionId);
        
        // Setup mock pending reward claim data
        mockSonicGasMonetization.setMockPendingRewardClaim(1, 100, 3, 5 ether);
        
        (bool isReady, uint256 confirmedAmount, uint256 confirmationsCount) = feeMAuction.checkFeeMRewardStatus(auctionId);
        
        assertTrue(isReady);
        assertEq(confirmedAmount, 5 ether);
        assertEq(confirmationsCount, 3);
    }

    function test_GetUserAuctions() public {
        vm.warp(START_TIME - 1);
        
        vm.prank(user1);
        uint256 auctionId1 = feeMAuction.createFeeMAuction(MIN_BID, START_TIME);
        vm.prank(user1);
        uint256 auctionId2 = feeMAuction.createFeeMAuction(MIN_BID, START_TIME + 100);
        
        uint256[] memory userAuctions = feeMAuction.getUserAuctions(user1);
        assertEq(userAuctions.length, 2);
        assertEq(userAuctions[0], auctionId1);
        assertEq(userAuctions[1], auctionId2);
    }

    function test_GetUserProjectId() public {
        vm.warp(START_TIME - 1);
        vm.prank(user1);
        feeMAuction.createFeeMAuction(MIN_BID, START_TIME);
        
        uint256 projectId = feeMAuction.getUserProjectId(user1);
        assertEq(projectId, 1);
    }

    function test_SetPlatformFeePercentage() public {
        vm.prank(owner);
        feeMAuction.setPlatformFeePercentage(3);
        
        assertEq(feeMAuction.platformFeePercentage(), 3);
    }

    function test_SetPlatformFeePercentage_TooHigh() public {
        vm.prank(owner);
        vm.expectRevert("Fee cannot exceed 10%");
        feeMAuction.setPlatformFeePercentage(15);
    }

    function test_PauseUnpause() public {
        vm.prank(owner);
        feeMAuction.pause();
        assertTrue(feeMAuction.paused());
        
        vm.prank(owner);
        feeMAuction.unpause();
        assertFalse(feeMAuction.paused());
    }

    function test_EmergencyWithdraw() public {
        // Send some ETH to the contract
        vm.deal(address(feeMAuction), 5 ether);
        
        uint256 initialBalance = address(owner).balance;
        
        vm.prank(owner);
        feeMAuction.emergencyWithdraw(address(0), 3 ether, owner);
        
        uint256 finalBalance = address(owner).balance;
        assertEq(finalBalance, initialBalance + 3 ether);
    }

    function test_CompleteAuctionFlow() public {
        vm.warp(START_TIME - 1);
        
        // Create auction
        vm.prank(user1);
        uint256 auctionId = feeMAuction.createFeeMAuction(MIN_BID, START_TIME);
        
        // Start auction
        vm.warp(START_TIME);
        vm.prank(user1);
        feeMAuction.startFeeMAuction(auctionId);
        
        // Place bids
        vm.prank(user2);
        feeMAuction.placeBid{value: 1 ether}(auctionId);
        
        vm.prank(user3);
        feeMAuction.placeBid{value: 1.1 ether}(auctionId);
        
        // End auction
        vm.warp(START_TIME + AUCTION_DURATION + 1);
        vm.prank(user1);
        feeMAuction.endFeeMAuction(auctionId);
        
        // Verify settlement
        FeeMAuction.FeeMAuctionInfo memory auction = feeMAuction.getFeeMAuction(auctionId);
        assertTrue(auction.isSettled);
        assertEq(auction.currentHighestBidder, user3);
        assertEq(auction.currentHighestBid, 1.1 ether);
        
        // Check fees - owner should receive both platform and project fees
        uint256 platformFee = (1.1 ether * 2) / 100; // 2%
        uint256 creatorAmount = 1.1 ether - platformFee;
        
        // Verify the fees were sent to owner (who is also the contract owner)
        assertEq(address(owner).balance, 100 ether + platformFee);
        // Verify user1 received the creator amount (minus the initial 100 ether)
        assertEq(user1.balance, 100 ether + creatorAmount);
    }

    function test_AuctionWithNoBids() public {
        vm.warp(START_TIME - 1);
        
        vm.prank(user1);
        uint256 auctionId = feeMAuction.createFeeMAuction(MIN_BID, START_TIME);
        
        vm.warp(START_TIME);
        vm.prank(user1);
        feeMAuction.startFeeMAuction(auctionId);
        
        vm.warp(START_TIME + AUCTION_DURATION + 1);
        vm.prank(user1);
        feeMAuction.endFeeMAuction(auctionId);
        
        FeeMAuction.FeeMAuctionInfo memory auction = feeMAuction.getFeeMAuction(auctionId);
        assertTrue(auction.isSettled);
        assertFalse(auction.isActive);
        assertEq(auction.currentHighestBidder, address(0));
        assertEq(auction.currentHighestBid, 0);
    }
}
