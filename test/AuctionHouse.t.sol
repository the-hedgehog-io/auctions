// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "../src/AuctionHouse.sol";
import "../src/interfaces/IAuctionHouse.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock WETH contract
contract MockWETH is ERC20 {
    constructor() ERC20("Wrapped Ether", "WETH") {}
    
    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }
    
    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        payable(msg.sender).transfer(amount);
    }
}

// Mock ERC721 contract for testing
contract MockERC721 is ERC721 {
    constructor() ERC721("Mock NFT", "MNFT") {}
    
    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

// Mock Zora Media contract
contract MockZoraMedia {
    address public marketContract;
    
    constructor(address _marketContract) {
        marketContract = _marketContract;
    }
    
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x80ac58cd; // ERC721 interface
    }
}

// Mock Market contract
contract MockMarket {
    function isValidBid(uint256 tokenId, uint256 amount) external pure returns (bool) {
        return true; // Always return true for testing
    }
}

contract AuctionHouseTest is Test {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
    AuctionHouse public auctionHouse;
    MockWETH public weth;
    MockERC721 public nft;
    MockZoraMedia public zoraMedia;
    MockMarket public market;
    
    address public owner = address(this);
    address public bidder1 = address(0x1);
    address public bidder2 = address(0x2);
    address payable public curator = payable(address(0x3));
    
    uint256 public constant TOKEN_ID = 1;
    uint256 public constant DURATION = 86400; // 1 day
    uint256 public constant RESERVE_PRICE = 0.5 ether;
    uint8 public constant CURATOR_FEE_PERCENTAGE = 5;
    
    event AuctionCreated(
        uint256 indexed auctionId,
        uint256 indexed tokenId,
        address indexed tokenContract,
        uint256 duration,
        uint256 reservePrice,
        address tokenOwner,
        address curator,
        uint8 curatorFeePercentage,
        address auctionCurrency
    );
    
    event AuctionBid(
        uint256 indexed auctionId,
        uint256 indexed tokenId,
        address indexed tokenContract,
        address sender,
        uint256 value,
        bool firstBid,
        bool extended
    );
    
    event AuctionEnded(
        uint256 indexed auctionId,
        uint256 indexed tokenId,
        address indexed tokenContract,
        address tokenOwner,
        address curator,
        address winner,
        uint256 amount,
        uint256 curatorFee,
        address auctionCurrency
    );

    function setUp() public {
        // Deploy mock contracts
        weth = new MockWETH();
        nft = new MockERC721();
        market = new MockMarket();
        zoraMedia = new MockZoraMedia(address(market));
        
        // Deploy auction house
        auctionHouse = new AuctionHouse(address(zoraMedia), address(weth));
        
        // Mint NFT to owner
        nft.mint(owner, TOKEN_ID);
        
        // Setup initial balances
        vm.deal(bidder1, 10 ether);
        vm.deal(bidder2, 10 ether);
        vm.deal(curator, 1 ether);
    }

    function testConstructor() public {
        assertEq(auctionHouse.zora(), address(zoraMedia), "incorrect zora address");
        assertEq(auctionHouse.wethAddress(), address(weth), "incorrect weth address");
        assertEq(auctionHouse.timeBuffer(), 900, "time buffer should equal 900");
        assertEq(uint256(auctionHouse.minBidIncrementPercentage()), 5, "minBidIncrementPercentage should equal 5%");
    }

    function testCreateAuction() public {
        // Approve NFT for auction house
        nft.approve(address(auctionHouse), TOKEN_ID);
        
        vm.expectEmit(true, true, true, true);
        emit AuctionCreated(
            0, // auctionId
            TOKEN_ID,
            address(nft),
            DURATION,
            RESERVE_PRICE,
            owner,
            curator,
            CURATOR_FEE_PERCENTAGE,
            address(0) // ETH currency
        );
        
        uint256 auctionId = auctionHouse.createAuction(
            TOKEN_ID,
            address(nft),
            DURATION,
            RESERVE_PRICE,
            curator,
            CURATOR_FEE_PERCENTAGE,
            address(0) // ETH currency
        );
        
        assertEq(auctionId, 0, "auctionId should be 0");
        
        // Check that NFT was transferred to auction house
        assertEq(nft.ownerOf(TOKEN_ID), address(auctionHouse), "NFT should be transferred to auction house");
    }

    function testCreateBid() public {
        // Create auction
        nft.approve(address(auctionHouse), TOKEN_ID);
        uint256 auctionId = auctionHouse.createAuction(
            TOKEN_ID,
            address(nft),
            DURATION,
            RESERVE_PRICE,
            curator,
            CURATOR_FEE_PERCENTAGE,
            address(0)
        );
        
        // Approve auction
        vm.prank(curator);
        auctionHouse.setAuctionApproval(auctionId, true);
        
        // Create first bid
        vm.prank(bidder1);
        vm.expectEmit(true, true, true, true);
        emit AuctionBid(
            auctionId,
            TOKEN_ID,
            address(nft),
            bidder1,
            RESERVE_PRICE,
            true, // firstBid
            false // extended
        );
        
        auctionHouse.createBid{value: RESERVE_PRICE}(auctionId, RESERVE_PRICE);
        
        // Verify the bid was created by checking the auction state
        // We can't easily access the struct fields, so we'll test the functionality instead
    }

    function testCreateBidWithRefund() public {
        // Create auction
        nft.approve(address(auctionHouse), TOKEN_ID);
        uint256 auctionId = auctionHouse.createAuction(
            TOKEN_ID,
            address(nft),
            DURATION,
            RESERVE_PRICE,
            curator,
            CURATOR_FEE_PERCENTAGE,
            address(0)
        );
        
        // Approve auction
        vm.prank(curator);
        auctionHouse.setAuctionApproval(auctionId, true);
        
        // Create first bid
        vm.prank(bidder1);
        auctionHouse.createBid{value: RESERVE_PRICE}(auctionId, RESERVE_PRICE);
        
        uint256 balanceBefore = bidder1.balance;
        
        // Create second bid (should refund first bidder)
        vm.prank(bidder2);
        uint256 newBidAmount = RESERVE_PRICE + (RESERVE_PRICE * 5) / 100; // 5% increment
        auctionHouse.createBid{value: newBidAmount}(auctionId, newBidAmount);
        
        uint256 balanceAfter = bidder1.balance;
        assertEq(balanceAfter, balanceBefore + RESERVE_PRICE, "first bidder should be refunded");
    }

    function testEndAuction() public {
        // Create auction
        nft.approve(address(auctionHouse), TOKEN_ID);
        uint256 auctionId = auctionHouse.createAuction(
            TOKEN_ID,
            address(nft),
            DURATION,
            RESERVE_PRICE,
            curator,
            CURATOR_FEE_PERCENTAGE,
            address(0)
        );
        
        // Approve auction
        vm.prank(curator);
        auctionHouse.setAuctionApproval(auctionId, true);
        
        // Create bid
        vm.prank(bidder1);
        auctionHouse.createBid{value: RESERVE_PRICE}(auctionId, RESERVE_PRICE);
        
        // Fast forward time
        vm.warp(block.timestamp + DURATION + 1);
        
        // End auction
        vm.expectEmit(true, true, true, true);
        emit AuctionEnded(
            auctionId,
            TOKEN_ID,
            address(nft),
            owner,
            curator,
            bidder1,
            RESERVE_PRICE - (RESERVE_PRICE * CURATOR_FEE_PERCENTAGE) / 100,
            (RESERVE_PRICE * CURATOR_FEE_PERCENTAGE) / 100,
            address(weth)
        );
        
        auctionHouse.endAuction(auctionId);
        
        // Check that NFT was transferred to winner
        assertEq(nft.ownerOf(TOKEN_ID), bidder1, "NFT should be transferred to winner");
    }

    function testCancelAuction() public {
        // Create auction
        nft.approve(address(auctionHouse), TOKEN_ID);
        uint256 auctionId = auctionHouse.createAuction(
            TOKEN_ID,
            address(nft),
            DURATION,
            RESERVE_PRICE,
            curator,
            CURATOR_FEE_PERCENTAGE,
            address(0)
        );
        
        // Cancel auction
        auctionHouse.cancelAuction(auctionId);
        
        // Check that NFT was returned to owner
        assertEq(nft.ownerOf(TOKEN_ID), owner, "NFT should be returned to owner");
    }

    function test_RevertWhen_CreateBidBelowReserve() public {
        // Create auction
        nft.approve(address(auctionHouse), TOKEN_ID);
        uint256 auctionId = auctionHouse.createAuction(
            TOKEN_ID,
            address(nft),
            DURATION,
            RESERVE_PRICE,
            curator,
            CURATOR_FEE_PERCENTAGE,
            address(0)
        );
        
        // Approve auction
        vm.prank(curator);
        auctionHouse.setAuctionApproval(auctionId, true);
        
        // Try to bid below reserve price
        vm.prank(bidder1);
        vm.expectRevert("Must send at least reservePrice");
        auctionHouse.createBid{value: RESERVE_PRICE - 0.1 ether}(auctionId, RESERVE_PRICE - 0.1 ether);
    }

    function test_RevertWhen_CreateBidBelowMinIncrement() public {
        // Create auction
        nft.approve(address(auctionHouse), TOKEN_ID);
        uint256 auctionId = auctionHouse.createAuction(
            TOKEN_ID,
            address(nft),
            DURATION,
            RESERVE_PRICE,
            curator,
            CURATOR_FEE_PERCENTAGE,
            address(0)
        );
        
        // Approve auction
        vm.prank(curator);
        auctionHouse.setAuctionApproval(auctionId, true);
        
        // Create first bid
        vm.prank(bidder1);
        auctionHouse.createBid{value: RESERVE_PRICE}(auctionId, RESERVE_PRICE);
        
        // Try to bid below minimum increment
        vm.prank(bidder2);
        uint256 invalidBidAmount = RESERVE_PRICE + (RESERVE_PRICE * 4) / 100; // 4% increment (below 5%)
        vm.expectRevert("Must send more than last bid by minBidIncrementPercentage amount");
        auctionHouse.createBid{value: invalidBidAmount}(auctionId, invalidBidAmount);
    }

    function test_RevertWhen_EndAuctionBeforeExpiry() public {
        // Create auction
        nft.approve(address(auctionHouse), TOKEN_ID);
        uint256 auctionId = auctionHouse.createAuction(
            TOKEN_ID,
            address(nft),
            DURATION,
            RESERVE_PRICE,
            curator,
            CURATOR_FEE_PERCENTAGE,
            address(0)
        );
        
        // Approve auction
        vm.prank(curator);
        auctionHouse.setAuctionApproval(auctionId, true);
        
        // Create bid
        vm.prank(bidder1);
        auctionHouse.createBid{value: RESERVE_PRICE}(auctionId, RESERVE_PRICE);
        
        // Try to end auction before expiry
        vm.expectRevert("Auction hasn't completed");
        auctionHouse.endAuction(auctionId);
    }
} 