// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";

import {LendingPool} from "src/LendingPool.sol";
import {MessageRelay} from "src/MessageRelay.sol";

// // TODO: I should not have to import ERC20 from here.
// import {ERC20} from "solmate/utils/SafeTransferLib.sol";

import {PriceOracle} from "src/Interfaces/IPriceOracle.sol";
import {InterestRateModel} from "src/Interfaces/IIRM.sol";
import {EVMTransaction} from "src/Interfaces/IEVMTransactionVerification.sol";

import {MockERC20} from "./mocks/MockERC20.sol";
import {MockPriceOracle} from "./mocks/MockPriceOracle.sol";
import {MockInterestRateModel} from "./mocks/MockInterestRateModel.sol";
// import {MockLiquidator} from "./mocks/MockLiquidator.sol";

import {LendingPool} from "src/LendingPool.sol";

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

/// @title Configuration Test Contract
contract ConfigurationTest is Test {
    using FixedPointMathLib for uint256;

    /* Lending Pool Contracts */
    LendingPool ethPool;
    LendingPool flarePool;
    MessageRelay messageRelay;

    /* Mocks */
    MockERC20 ethAsset;
    MockERC20 flareAsset;

    MockERC20 ethBorrowAsset;
    MockERC20 flareBorrowAsset;

    MockPriceOracle oracle;
    MockInterestRateModel interestRateModel;
    // MockLiquidator liquidator;

    function setUp() public {
        ethPool = new LendingPool(address(this), address(this));
        flarePool = new LendingPool(address(this), address(this));

        messageRelay = new MessageRelay(address(this));

        interestRateModel = new MockInterestRateModel();

        ethAsset = new MockERC20("Test Weth", "TWETH", 18);
        flareAsset = new MockERC20("Test USDC", "TUSDC", 18);

        ethPool.configureAsset(address(ethAsset), address(0xc89b59096964e48c6A1456c08a94D6b2A0f6Fa5B), 0.5e18, 0);
        ethPool.setInterestRateModel(address(ethAsset), address(interestRateModel));
        flarePool.configureAsset(address(flareAsset), address(0x65d6a4ee7b2a807993b7014247428451aE11a471), 0.5e18, 0);
        flarePool.setInterestRateModel(address(flareAsset), address(interestRateModel));

        oracle = new MockPriceOracle();
        oracle.updatePrice(address(ethAsset), 1e18);
        oracle.updatePrice(address(flareAsset), 1e18);
        ethPool.setOracle(address(oracle));
        flarePool.setOracle(address(oracle));

        ethBorrowAsset = new MockERC20("Test Weth", "TWETH", 18);
        flareBorrowAsset = new MockERC20("Test USDC", "TUSDC", 18);

        ethPool.configureAsset(address(ethBorrowAsset), address(0x013bbC069FdD066009e0701Fe9969d4dDf3c7e4E), 0, 1e18);
        ethPool.setInterestRateModel(address(ethBorrowAsset), address(interestRateModel));
        flarePool.configureAsset(
            address(flareBorrowAsset), address(0x47d8BAC6C022CaC838f814A67e2d7A0344580D6D), 0, 1e18
        );
        flarePool.setInterestRateModel(address(flareBorrowAsset), address(interestRateModel));

        ///////////////////////////////////////////////////////////

        address evmTxVerifier = 0xf37AD1278917c04fb291C75a42e61710964Cb57c;

        flarePool.setMessageRelay(address(messageRelay));

        messageRelay.setLendingPool(address(flarePool));
        messageRelay.setEVMTxVerifier(evmTxVerifier);
    }

    // * VERIFY EVM TRANSACTION PROOF ========================================
    function testVerifyCrossChainAction() public {
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

        messageRelay.verifyCrossChainAction(_proof);

        address depositor = address(0xFA8166634569537ea716b7350383Ab262335994E);
        uint256 amount = 1000000000000000000;

        assertEq(flarePool.balanceOf(address(flareAsset), depositor), amount, "Incorrect Balance");
        assertEq(flarePool.totalUnderlying(address(flareAsset)), amount, "Incorrect Total Underlying");
    }

    // UTILS ================================================================
}
