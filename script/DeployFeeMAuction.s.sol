// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

import { Script, console } from "forge-std/Script.sol";
import { FeeMAuction } from "../src/FeeMAuction.sol";
import { ISonicGasMonetization } from "../src/interfaces/ISonicGasMonetization.sol";

/**
 * @title FeeM Auction Deployment Script
 * @dev This script deploys the complete FeeM auction system
 * Integrates with real Sonic GasMonetization contract: 0x0B5f073135dF3f5671710F08b08C0c9258aECc35
 */
contract DeployFeeMAuction is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying FeeM Auction System...");
        console.log("Deployer:", deployer);

        // Real Sonic GasMonetization contract address
        address sonicGasMonetization = 0x0B5f073135dF3f5671710F08b08C0c9258aECc35;
        console.log("Sonic GasMonetization contract:", sonicGasMonetization);

        // Deploy FeeMAuction
        // Note: FeeM token on Sonic is the native S token, so we use address(0) for ETH
        address feeMToken = address(0); // S token (native token on Sonic)
        FeeMAuction feeMAuction = new FeeMAuction(
            sonicGasMonetization,
            feeMToken
        );
        console.log("FeeMAuction deployed at:", address(feeMAuction));

        console.log("\nFeeM Auction System deployed successfully!");
        console.log("==========================================");
        console.log("Sonic GasMonetization:", sonicGasMonetization);
        console.log("FeeMAuction:", address(feeMAuction));
        console.log("FeeM Token: S (native token on Sonic)");
        console.log("==========================================");
        console.log("\nNext steps:");
        console.log("1. Verify contracts on Sonic block explorer");
        console.log("2. Ensure your project is registered in Sonic GasMonetization");
        console.log("3. Test the system with real transactions");
        console.log("4. Monitor auction activity and FeeM reward distribution");

        vm.stopBroadcast();
    }
}
