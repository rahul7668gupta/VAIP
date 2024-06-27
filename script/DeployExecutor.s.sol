// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Executor} from "../src/Executor.sol";
import {DeployListing} from "./DeployListing.s.sol";
import {DeployPropose} from "./DeployPropose.s.sol";

contract DeployExecutor is Script {
    function run(
        address _listing,
        address _propose
    ) external returns (Executor) {
        vm.startBroadcast();
        Executor executor = new Executor(_listing, _propose);
        vm.stopBroadcast();
        return executor;
    }
}
