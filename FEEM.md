# FeeM Auction System

A decentralized auction system that allows users to auction their future FeeM rewards from the Sonic blockchain. This system enables projects to get funding upfront while auction winners receive the actual FeeM rewards when they're distributed.

## Overview

The FeeM Auction System consists of three main components:

1. **FeeMAuction Contract** - The main contract that manages FeeM auctions
2. **FeeM Oracle Interface** - Interface for interacting with Sonic blockchain's FeeM system
3. **HedgehogAuction Integration** - Leverages the existing auction infrastructure

## How It Works

### 1. Auction Creation
- Users create auctions for future FeeM rewards (1-month periods)
- Auctions run for 7 days
- Users must have FeeM delegation capability on Sonic blockchain

### 2. Auction Process
- Bidders place bids in S
- Highest bidder wins the auction
- Project receives funding immediately (minus fees)

### 3. FeeM Delegation
- After auction ends, creator delegates FeeM to the auction contract
- FeeM rewards are collected for the 1-month period
- Auction winner claims the actual FeeM rewards

### 4. Reward Distribution
- Platform fee: 2% (configurable)
- Project fee: 5% (configurable)
- Creator receives: 93% of winning bid

## Key Features

- **Time-based Auctions**: 7-day auction duration, 1-month reward periods
- **FeeM Delegation**: Automatic delegation checking and management
- **Oracle Integration**: Flexible oracle interface for Sonic blockchain data
- **Security**: Reentrancy protection, pausable functionality, access controls
- **Fee Management**: Configurable platform and project fees
- **Emergency Functions**: Withdrawal capabilities for contract owner

## Usage Examples

### Creating an Auction

```solidity
// Create a FeeM auction with minimum bid of 1 S
uint256 auctionId = feeMAuction.createFeeMAuction(
    1 ether,           // minBidAmount
    block.timestamp + 1   // startTime
);
```

### Starting an Auction

```solidity
// Start the auction (creates Hedgehog auction)
feeMAuction.startFeeMAuction(auctionId);
```

### Placing a Bid

```solidity
// Place a bid with 1 ETH
feeMAuction.placeBid{value: 1 ether}(auctionId);
```

### Ending an Auction

```solidity
// End the auction and settle
feeMAuction.endFeeMAuction(auctionId);
```

### Delegating FeeM

```solidity
// Delegate FeeM for the auction
feeMAuction.delegateFeeM(auctionId);
```

### Claiming Rewards

```solidity
// Claim FeeM rewards (only auction winner)
feeMAuction.claimFeeMRewards(auctionId);
```

## Security Considerations

### Access Controls
- Only auction creators can start/end their auctions
- Only auction winners can claim rewards
- Only contract owner can modify fees and pause contract

### Reentrancy Protection
- All external calls are protected against reentrancy attacks
- Safe transfer patterns for token operations

### Pausable Functionality
- Contract can be paused in emergency situations
- Only owner can pause/unpause

### Emergency Functions
- Owner can withdraw stuck tokens/ETH
- Useful for contract upgrades or emergency situations

## Testing

The system includes comprehensive tests covering:

- Auction creation and management
- Bidding functionality
- FeeM delegation
- Reward claiming
- Error conditions and edge cases
- Access control validation
- Fee calculations

Run tests with:
```bash
forge test
```

## Deployment

### Prerequisites
- Foundry installed
- Private key set in environment
- Target network configured

### Deploy Script
```bash
forge script script/DeployFeeMAuction.s.sol --rpc-url <RPC_URL> --broadcast
```

### Environment Variables
```bash
export PRIVATE_KEY=your_private_key_here
```

## Integration with Sonic Blockchain

### FeeM Delegation
The system integrates with Sonic blockchain's FeeM delegation mechanism:

1. **Delegation Checking**: Verifies user's ability to delegate FeeM
2. **Reward Estimation**: Calculates expected FeeM rewards for auction periods
3. **Automatic Delegation**: Handles delegation to auction contract
4. **Reward Collection**: Collects and distributes actual FeeM rewards

## License

GPL-3.0 License
