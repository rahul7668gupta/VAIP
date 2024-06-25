// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Propose} from "../src/Propose.sol";

contract DeployPropose is Script {
    function run() external returns (Propose) {
        vm.startBroadcast();
        Propose proposal = new Propose();
        vm.stopBroadcast();
        return proposal;
    }
}
