// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import "../src/HedgehogAuction.sol";

contract AuctionScript is Script {

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Example: Deploy HedgehogAuction
        // HedgehogAuction auctionHouse = new HedgehogAuction(address(0x...), address(0x...));

        vm.stopBroadcast();
    }
}
