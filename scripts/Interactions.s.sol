// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";

import {LendingPool} from "../src/LendingPool.sol";
import {MessageRelay} from "../src/MessageRelay.sol";

import {MainStorage} from "../src/utils/MainStorage.sol";

import {MockPriceOracle} from "../test/mocks/MockPriceOracle.sol";
import {MockFtsoRegistry} from "../test/mocks/MockFtsoRegistry.sol";
import {EVMTransaction} from "src/Interfaces/IEVMTransactionVerification.sol";

import {HelperConfig} from "./HelperConfig.s.sol";

contract ConfigurePoolScript is Script {
    uint256 constant ETH_FTSO_IDX = 10;
    uint256 constant USDC_FTSO_IDX = 0;

    function run() external returns (LendingPool) {
        HelperConfig helperConfig = new HelperConfig();

        (
            address lendingPool,
            address messageRelay,
            address sourceOracle,
            address interesRateModel,
            address weth,
            address usdc,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        (address counterWeth, address counterUsdc) = helperConfig.activeCounterAssets();

        LendingPool pool = LendingPool(lendingPool);

        vm.startBroadcast(deployerKey);

        pool.configureAsset(weth, counterWeth, 0.9e18, 0.9e18, ETH_FTSO_IDX, true);
        pool.setInterestRateModel(weth, interesRateModel);

        pool.configureAsset(usdc, counterUsdc, 0.9e18, 0.9e18, USDC_FTSO_IDX, false);
        pool.setInterestRateModel(usdc, interesRateModel);

        pool.setOracleSource(sourceOracle);

        vm.stopBroadcast();

        return (pool);
    }
}

contract UpdateConfigurationPoolScript is Script {
    function run() external returns (LendingPool) {
        HelperConfig helperConfig = new HelperConfig();

        (address lendingPool,,, address interesRateModel, address weth, address usdc, uint256 deployerKey) =
            helperConfig.activeNetworkConfig();

        LendingPool pool = LendingPool(lendingPool);

        vm.startBroadcast(deployerKey);

        MainStorage.Configuration memory newConfiguration = MainStorage.Configuration(0.9e18, 0.9e18);

        pool.updateConfiguration(weth, newConfiguration);
        pool.setInterestRateModel(weth, interesRateModel);

        pool.updateConfiguration(usdc, newConfiguration);
        pool.setInterestRateModel(usdc, interesRateModel);

        vm.stopBroadcast();

        return (pool);
    }
}

contract ConfigureRelayScript is Script {
    function run() external returns (LendingPool) {
        HelperConfig helperConfig = new HelperConfig();

        (address lendingPool, address messageRelay,,,,, uint256 deployerKey) = helperConfig.activeNetworkConfig();

        address evmTxVerifier = helperConfig.getEvmTxVerifier();

        LendingPool pool = LendingPool(lendingPool);
        MessageRelay relay = MessageRelay(messageRelay);

        vm.startBroadcast(deployerKey);

        pool.setMessageRelay(messageRelay);

        relay.setLendingPool(lendingPool);
        relay.setEVMTxVerifier(evmTxVerifier);

        vm.stopBroadcast();

        return (pool);
    }
}

contract VerifyProofScript is Script {
    function run() external {
        HelperConfig helperConfig = new HelperConfig();

        (address lendingPool, address messageRelay,,,,, uint256 deployerKey) = helperConfig.activeNetworkConfig();

        MessageRelay relay = MessageRelay(messageRelay);

        uint32[] memory logIndices = new uint32[](0);

        bytes32[] memory merkleProof = new bytes32[](3);
        merkleProof[0] = bytes32(0x8d5501189ce53aa0c716a1421d2a7db590d5c23b5a2348c1937c0cdf6dd00e2c);
        merkleProof[1] = bytes32(0xdd27985c63d21b20f05877ce6213dda2d736f75e8941171cf60a4ec11a62809a);
        merkleProof[2] = bytes32(0xaf899e7405d671554f1891d0e2e425b070b1649372d26dabb60c44cfd8080f52);

        bytes32[] memory topics1 = new bytes32[](3);
        topics1[0] = bytes32(0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef);
        topics1[1] = bytes32(0x000000000000000000000000fa8166634569537ea716b7350383ab262335994e);
        topics1[2] = bytes32(0x00000000000000000000000084bcb82a356d45d5c6bd91857aa6a3e933fa82a5);

        bytes32[] memory topics2 = new bytes32[](2);
        topics2[0] = bytes32(0xdd160bb401ec5b5e5ca443d41e8e7182f3fe72d70a04b9c0ba844483d212bcb5);
        topics2[1] = bytes32(0x000000000000000000000000fa8166634569537ea716b7350383ab262335994e);

        bytes memory responseInput =
            hex"3edd112800000000000000000000000065d6a4ee7b2a807993b7014247428451ae11a4710000000000000000000000000000000000000000000000000de0b6b3a76400000000000000000000000000000000000000000000000000000000000000000001";
        bytes memory eventData1 = hex"0000000000000000000000000000000000000000000000000de0b6b3a7640000";
        bytes memory eventData2 =
            hex"00000000000000000000000065d6a4ee7b2a807993b7014247428451ae11a4710000000000000000000000000000000000000000000000000de0b6b3a76400000000000000000000000000000000000000000000000000000000000000000001";

        EVMTransaction.Event[] memory events = new EVMTransaction.Event[](2);
        events[0] = EVMTransaction.Event(151, 0x65d6a4ee7b2a807993b7014247428451aE11a471, topics1, eventData1, false);
        events[1] = EVMTransaction.Event(152, 0x84bcB82A356d45D5c6BD91857aA6a3E933Fa82a5, topics2, eventData2, false);

        EVMTransaction.Proof memory _proof = EVMTransaction.Proof(
            merkleProof,
            EVMTransaction.Response(
                bytes32(0x45564d5472616e73616374696f6e000000000000000000000000000000000000),
                bytes32(0x7465737445544800000000000000000000000000000000000000000000000000),
                878923,
                1715173488,
                EVMTransaction.RequestBody(
                    0x46d6fdce170a5698ad93c8b6ae178e75d1cede5d97c2cea0f556c3e3b9dad83f, 0, true, true, logIndices
                ),
                EVMTransaction.ResponseBody(
                    5861276,
                    1715173488,
                    0xFA8166634569537ea716b7350383Ab262335994E,
                    false,
                    0x84bcB82A356d45D5c6BD91857aA6a3E933Fa82a5,
                    0,
                    responseInput,
                    1,
                    events
                )
            )
        );

        vm.startBroadcast(deployerKey);

        relay.verifyCrossChainAction(_proof);
        vm.stopBroadcast();

        return ();
    }
}

contract UpdateOraclePrices is Script {
    uint256 constant ETH_FTSO_IDX = 10;
    uint256 constant ETH_FTSO_DECIMALS = 5;
    uint256 constant USDC_FTSO_IDX = 0;
    uint256 constant USDC_FTSO_DECIMALS = 5;

    function run() external {
        HelperConfig helperConfig = new HelperConfig();

        (,, address sourceOracle,, address weth, address usdc, uint256 deployerKey) = helperConfig.activeNetworkConfig();

        MockFtsoRegistry ftsoRegistry = MockFtsoRegistry(sourceOracle);

        vm.startBroadcast(deployerKey);

        ftsoRegistry.updatePrice(ETH_FTSO_IDX, 3500 * 10 ** ETH_FTSO_DECIMALS, ETH_FTSO_DECIMALS);
        ftsoRegistry.updatePrice(USDC_FTSO_IDX, 1 * 10 ** USDC_FTSO_DECIMALS, USDC_FTSO_DECIMALS);

        vm.stopBroadcast();
    }
}
