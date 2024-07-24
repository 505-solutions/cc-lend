// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";

import {LendingPool} from "src/LendingPool.sol";

// // TODO: I should not have to import ERC20 from here.
// import {ERC20} from "solmate/utils/SafeTransferLib.sol";

import {PriceOracle} from "src/Interfaces/IPriceOracle.sol";
import {InterestRateModel} from "src/Interfaces/IIRM.sol";
import {EVMTransaction} from "src/Interfaces/IEVMTransactionVerification.sol";

import {MockERC20} from "./mocks/MockERC20.sol";
import {MockPriceOracle} from "./mocks/MockPriceOracle.sol";
import {MockInterestRateModel} from "./mocks/MockInterestRateModel.sol";
// import {MockLiquidator} from "./mocks/MockLiquidator.sol";
import {MockFtsoRegistry} from "./mocks/MockFtsoRegistry.sol";

import {LendingPool} from "src/LendingPool.sol";

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

/// @title Configuration Test Contract
contract CrossChainActionsTest is Test {
    using FixedPointMathLib for uint256;

    /* Lending Pool Contracts */
    LendingPool pool;

    /* Mocks */
    MockERC20 testEth;
    MockERC20 testTokenX;

    MockFtsoRegistry ftsoRegistry;

    uint256 constant ETH_FTSO_IDX = 10;
    uint256 constant ETH_FTSO_DECIMALS = 5;
    uint256 constant TOKENX_FTSO_IDX = 25;
    uint256 constant TOKENX_FTSO_DECIMALS = 5;

    bool constant ALLOW_DOUBLE_BORROW = true;

    function setUp() public {
        pool = new LendingPool();
        pool.initialize(address(this), address(this), ALLOW_DOUBLE_BORROW);

        testEth = new MockERC20("Mock ETH", "MKE", 18);
        pool.configureAsset(address(testEth), address(testEth), 0.5e18, 0, ETH_FTSO_IDX, true);

        testTokenX = new MockERC20("Mock TOKENX", "MKU", 18);

        pool.configureAsset(address(testTokenX), address(testTokenX), 0, 1e18, TOKENX_FTSO_IDX, false);

        // * ORACLE CONFIGURATIONS
        ftsoRegistry = new MockFtsoRegistry();
        ftsoRegistry.updatePrice(ETH_FTSO_IDX, 3000e5, 5);
        ftsoRegistry.updatePrice(TOKENX_FTSO_IDX, 1e5, 5);

        pool.setOracleSource(address(ftsoRegistry));
    }

    function testGetOraclePrice() public view {
        if (block.chainid != 16) {
            uint256 ethPrice = pool.getAssetPrice(address(testEth));
            uint256 usdcPrice = pool.getAssetPrice(address(testTokenX));

            console.log("Eth Price in eth (should be 1e18): ", ethPrice);
            console.log("TokenX Price in eth: ", usdcPrice);
        } else {
            uint256 ethPrice = pool.getAssetPrice(address(testEth));
            uint256 usdcPrice = pool.getAssetPrice(address(testTokenX));

            console.log("Eth Price in eth (should be 1e18): ", ethPrice);
            console.log("TokenX Price in eth: ", usdcPrice);
        }
    }

    function testUpdateOraclePrice() public {
        if (block.chainid != 16) {
            updateOraclePrices(address(testEth), 4000e18);
            updateOraclePrices(address(testTokenX), 2e18);

            testGetOraclePrice();
        } else {
            updateOraclePrices(address(testEth), 4000e18);
            updateOraclePrices(address(testTokenX), 2e18);

            testGetOraclePrice();
        }
    }

    // UTILS ================================================================

    function updateOraclePrices(address _asset, uint256 price) private {
        if (_asset == address(testEth)) {
            ftsoRegistry.updatePrice(ETH_FTSO_IDX, price / 10 ** (18 - ETH_FTSO_DECIMALS), ETH_FTSO_DECIMALS);
        } else if (_asset == address(testTokenX)) {
            ftsoRegistry.updatePrice(TOKENX_FTSO_IDX, price / 10 ** (18 - TOKENX_FTSO_DECIMALS), TOKENX_FTSO_DECIMALS);
        }
    }
}
