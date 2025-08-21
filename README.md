# Zora Auction House with Bid Rebates

This project implements a **Bid Rebate Auction** system based on Zora's Auction House, enhanced with automatic rebate distribution for outbid users.

## Features

- **English Auction System**: Traditional highest-bidder-wins auction mechanism
- **Automatic Bid Rebates**: Outbid users automatically receive rebates when someone places a higher bid
- **Configurable Rebate Percentage**: Contract owner can set the rebate percentage (default: 10%)
- **Smart Rebate Capping**: Rebates are automatically capped to ensure contract solvency
- **Multi-Currency Support**: Supports both ETH and ERC20 tokens
- **Curator System**: Curators can approve/reject auctions and receive fees
- **Comprehensive test coverage** using Foundry
- **Security**: Built on audited Zora contracts with additional safety measures

## How Bid Rebates Work

When a user is outbid:

1. **Rebate Calculation**: The outbid user receives a rebate calculated as a percentage of their previous bid amount
2. **Automatic Distribution**: Rebates are automatically sent along with the refund of their original bid
3. **Smart Capping**: Rebates are capped to ensure the contract never tries to send more funds than available
4. **Event Emission**: All rebate distributions are logged as events for transparency

### Example Scenario

- **First bid**: 0.5 ETH
- **Second bid**: 0.525 ETH (5% increment)
- **Rebate**: 10% of 0.5 ETH = 0.05 ETH (capped to 0.025 ETH due to available funds)
- **Total refund to first bidder**: 0.5 ETH + 0.025 ETH = 0.525 ETH

## Installation

```bash
# Clone the repository
git clone <repository-url>
cd auctions

# Install dependencies
forge install

# Build the project
forge build
```

## Usage

### Setting Rebate Percentage

```solidity
// Only contract owner can call this
auctionHouse.setRebatePercentage(15); // Set to 15%
```

### Creating an Auction

```solidity
uint256 auctionId = auctionHouse.createAuction(
    tokenId,           // NFT token ID
    tokenContract,     // NFT contract address
    duration,          // Auction duration in seconds
    reservePrice,      // Minimum bid amount
    curator,           // Curator address (can be zero)
    curatorFee,        // Curator fee percentage (0-99)
    auctionCurrency    // Currency address (zero for ETH)
);
```

### Placing a Bid

```solidity
// For ETH auctions
auctionHouse.createBid{value: bidAmount}(auctionId, bidAmount);

// For ERC20 auctions
auctionHouse.createBid(auctionId, bidAmount);
```

## Testing

```bash
# Run all tests
forge test

# Run with verbose output
forge test -vvv

# Run specific test
forge test --match-test testCreateBidWithRefund
```

## Security Features

- **Reentrancy Protection**: Uses OpenZeppelin's ReentrancyGuard
- **Safe Math**: Built-in overflow protection (Solidity 0.8.30+)
- **Access Control**: Only owner can modify rebate percentage
- **Fund Safety**: Rebates are capped to prevent contract insolvency
- **Event Logging**: All rebate distributions are logged for transparency

## Customization for Rebates

The rebate system is designed to be flexible and secure:

- **Configurable Percentage**: Set rebate percentage from 0% to 100%
- **Automatic Capping**: Rebates are automatically capped to available funds
- **Transparent Events**: All rebate distributions emit events for tracking
- **Owner Control**: Only contract owner can modify rebate settings

## Audit Status

- **Base Contracts**: Based on audited Zora Auction House contracts
- **OpenZeppelin**: Uses audited OpenZeppelin contracts v5.4.0
- **Additional Security**: Enhanced with rebate-specific safety measures

## License

GPL-3.0
