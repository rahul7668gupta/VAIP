// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Propose} from "../src/Propose.sol";
import {DeployListing} from "../script/DeployListing.s.sol";

contract DeployPropose is Script {
    function run(address _listing) external returns (Propose) {
        vm.startBroadcast();
        Propose proposal = new Propose(_listing);
        vm.stopBroadcast();
        return proposal;
    }
}
