// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {LendingPool} from "../src/LendingPool.sol";

// import {HelperConfig} from "./HelperConfig.s.sol";
// import {Raffle} from "../src/Raffle.sol";
// import {AddConsumer, CreateSubscription, FundSubscription} from "./Interactions.s.sol";

contract DeployPoolScript is Script {
    address constant owner =
        address(0xaCEdF8742eDC7d923e1e6462852cCE136ee9Fb56);
    address constant messageRelay =
        address(0xaCEdF8742eDC7d923e1e6462852cCE136ee9Fb56);

    function run() external returns (LendingPool) {
        // address owner, address messageRelay

        vm.startBroadcast();
        LendingPool pool = new LendingPool(owner, messageRelay);
        vm.stopBroadcast();

        return (pool);
    }
}
