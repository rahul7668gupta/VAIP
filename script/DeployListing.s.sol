// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Listing} from "../src/Listing.sol";

contract DeployListing is Script {
    function run() external returns (Listing) {
        vm.startBroadcast();
        Listing listing = new Listing();
        vm.stopBroadcast();
        return listing;
    }
}
