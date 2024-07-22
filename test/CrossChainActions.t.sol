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

import {PriceOraclePlugin} from "src/PriceOraclePlugin.sol";

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
    LendingPool ethPool;
    LendingPool flarePool;

    /* Mocks */
    MockERC20 testEth;
    MockERC20 testUsdc;

    MockPriceOracle oracle;
    MockFtsoRegistry ftsoRegistry;

    MockInterestRateModel interestRateModel;
    // MockLiquidator liquidator;

    PriceOraclePlugin priceOraclePlugin;

    uint256 constant ETH_FTSO_IDX = 10;
    uint256 constant ETH_FTSO_DECIMALS = 5;
    uint256 constant USDC_FTSO_IDX = 25;
    uint256 constant USDC_FTSO_DECIMALS = 5;

    function setUp() public {
        // ! For non upgradable contracts
        // ethPool = new LendingPool(address(this), address(this));
        // flarePool = new LendingPool(address(this), address(this));

        // ! For upgradable contracts
        ethPool = new LendingPool();
        ethPool.initialize(address(this), address(this));
        flarePool = new LendingPool();
        flarePool.initialize(address(this), address(this));

        interestRateModel = new MockInterestRateModel();

        testEth = new MockERC20("Mock Eth", "MKE", 18);

        ethPool.configureAsset(address(testEth), address(testEth), 0.5e18, 0);
        ethPool.setInterestRateModel(address(testEth), address(interestRateModel));
        flarePool.configureAsset(address(testEth), address(testEth), 0.5e18, 0);
        flarePool.setInterestRateModel(address(testEth), address(interestRateModel));

        testUsdc = new MockERC20("Mock USDC", "MKU", 18);

        ethPool.configureAsset(address(testUsdc), address(testUsdc), 0, 1e18);
        ethPool.setInterestRateModel(address(testUsdc), address(interestRateModel));
        flarePool.configureAsset(address(testUsdc), address(testUsdc), 0, 1e18);
        flarePool.setInterestRateModel(address(testUsdc), address(interestRateModel));

        // * ORACLE CONFIGURATIONS

        priceOraclePlugin = new PriceOraclePlugin(address(testEth), ETH_FTSO_IDX);
        priceOraclePlugin.setOracleSource(address(this));

        ethPool.setPriceOraclePlugin(address(priceOraclePlugin));
        flarePool.setPriceOraclePlugin(address(priceOraclePlugin));

        if (block.chainid != 16) {
            // ! On Sepolia
            oracle = new MockPriceOracle();
            oracle.updatePrice(address(testEth), 3000e18);
            oracle.updatePrice(address(testUsdc), 1e18);
            priceOraclePlugin.setOracleSource(address(oracle));
        } else {
            // ! If on Flare

            priceOraclePlugin.setFtsoIndex(address(testEth), ETH_FTSO_IDX);
            priceOraclePlugin.setFtsoIndex(address(testUsdc), USDC_FTSO_IDX);

            ftsoRegistry = new MockFtsoRegistry();
            ftsoRegistry.updatePrice(ETH_FTSO_IDX, 3000e5, ETH_FTSO_DECIMALS);
            ftsoRegistry.updatePrice(USDC_FTSO_IDX, 1e5, USDC_FTSO_DECIMALS);

            priceOraclePlugin.setOracleSource(address(ftsoRegistry));
        }
    }

    function increaseExchangeLiquidity() internal {
        // NOTE: Funds both pools with enough assets to test crosschain interactions.
        mintAndApprove(testEth, 100 ether, address(ethPool));
        ethPool.increaseAvailableLiquidity(address(testEth), 100 ether);

        mintAndApprove(testUsdc, 100 ether, address(ethPool));
        ethPool.increaseAvailableLiquidity(address(testUsdc), 100 ether);

        mintAndApprove(testEth, 100 ether, address(flarePool));
        flarePool.increaseAvailableLiquidity(address(testEth), 100 ether);

        mintAndApprove(testUsdc, 100 ether, address(flarePool));
        flarePool.increaseAvailableLiquidity(address(testUsdc), 100 ether);
    }

    function testCrossChainDeposit(uint256 amount) public {
        vm.assume(amount >= 1e5 && amount <= 1e19);

        // Mint, approve, and deposit the testEth.
        mintAndApprove(testEth, amount, address(ethPool));

        ethPool.deposit(address(testEth), amount, true);

        // Checks. Note that the default exchange rate is 1,
        // so the values should be equal to the input amount.
        assertEq(ethPool.balanceOf(address(testEth), address(this)), amount, "Incorrect Balance");
        assertEq(ethPool.totalUnderlying(address(testEth)), amount, "Incorrect Total Underlying");

        flarePool.handleCrossChainDeposit(address(testEth), amount, address(this), true);

        // The message was relayed and the balance was updated.
        assertEq(flarePool.balanceOf(address(testEth), address(this)), amount, "Incorrect Balance");
        assertEq(flarePool.totalUnderlying(address(testEth)), amount, "Incorrect Total Underlying");
    }

    function testCrossChainSourceWithdrawal(uint256 amount) public {
        vm.assume(amount >= 1e12 && amount <= 1e19);

        // Mint, approve, and deposit the testEth.
        testCrossChainDeposit(amount);

        // Withdraw the testEth.
        ethPool.withdraw(address(testEth), amount, false);

        // Checks.
        assertEq(testEth.balanceOf(address(this)), amount, "Incorrect testEth balance");
        assertEq(ethPool.balanceOf(address(testEth), address(this)), 0, "Incorrect pool balance");

        flarePool.handleCrossChainWithdrawal(address(testEth), amount, address(this), false);

        assertEq(testEth.balanceOf(address(this)), amount, "Incorrect testEth balance");
        assertEq(flarePool.balanceOf(address(testEth), address(this)), 0, "Incorrect pool balance");
    }

    function testCrossChainDestWithdrawal(uint256 amount) public {
        vm.assume(amount >= 1e12 && amount <= 1e19);

        // Mint, approve, and deposit the testEth.
        testCrossChainDeposit(amount);

        increaseExchangeLiquidity();

        // Withdraw the testEth.
        flarePool.withdraw(address(testEth), amount, false);

        // Checks.
        assertEq(testEth.balanceOf(address(this)), amount, "Incorrect testEth balance");
        assertApproxEqAbs(
            flarePool.balanceOf(address(testEth), address(this)), 100 ether, 100, "Incorrect pool balance"
        );

        ethPool.handleCrossChainWithdrawal(address(testEth), amount, address(this), false);

        assertEq(testEth.balanceOf(address(this)), amount, "Incorrect testEth balance");
        assertApproxEqAbs(ethPool.balanceOf(address(testEth), address(this)), 100 ether, 100, "Incorrect pool balance");
    }

    function testCrossChainSourceBorrow(uint256 amount) public {
        vm.assume(amount >= 1e5 && amount <= 1e19);

        // Mint, approve, and deposit the testEth.
        testCrossChainDeposit(amount);

        increaseExchangeLiquidity();

        // Set the price of collateral to 1 ETH.
        updateOraclePrices(address(testEth), 1e18);

        // Set the price of the borrow testEth to 2 ETH.
        // This means that with a 0.5 lend factor, we should be able to borrow 0.25 ETH.
        updateOraclePrices(address(testUsdc), 2e18);

        // Borrow the testEth.
        ethPool.borrow(address(testUsdc), amount / 4);

        // Checks.
        assertEq(testUsdc.balanceOf(address(this)), amount / 4);
        assertEq(ethPool.borrowBalance(address(testUsdc), address(this)), amount / 4);
        assertEq(ethPool.totalBorrows(address(testUsdc)), amount / 4);

        flarePool.handleCrossChainBorrow(address(testUsdc), amount / 4, address(this));

        assertEq(testUsdc.balanceOf(address(this)), amount / 4);
        assertEq(flarePool.borrowBalance(address(testUsdc), address(this)), amount / 4);
        assertEq(flarePool.totalBorrows(address(testUsdc)), amount / 4);
    }

    function testCrossChainDestBorrow(uint256 amount) public {
        vm.assume(amount >= 1e5 && amount <= 1e19);

        // uint256 amount = 1e18;

        // Mint, approve, and deposit the testEth.
        testCrossChainDeposit(amount);

        increaseExchangeLiquidity();

        updateOraclePrices(address(testEth), 4000e18);

        // Set the price of the borrow testEth to 2 ETH.
        // This means that with a 0.5 lend factor, we should be able to borrow 0.25 ETH.
        updateOraclePrices(address(testUsdc), 2e18);

        // Borrow the testEth.
        flarePool.borrow(address(testUsdc), amount / 4);

        // Checks.
        assertEq(testUsdc.balanceOf(address(this)), amount / 4);
        assertEq(flarePool.borrowBalance(address(testUsdc), address(this)), amount / 4);
        assertEq(flarePool.totalBorrows(address(testUsdc)), amount / 4);

        ethPool.handleCrossChainBorrow(address(testUsdc), amount / 4, address(this));

        assertEq(testUsdc.balanceOf(address(this)), amount / 4);
        assertEq(ethPool.borrowBalance(address(testUsdc), address(this)), amount / 4);
        assertEq(ethPool.totalBorrows(address(testUsdc)), amount / 4);
    }

    //
    function testCrossChainSourceRepay(uint256 amount) public {
        vm.assume(amount >= 1e5 && amount <= 1e19);

        // uint256 amount = 0.25 ether;

        testCrossChainSourceBorrow(amount);

        // Repay the tokens.
        testUsdc.approve(address(ethPool), amount / 4);
        ethPool.repay(address(testUsdc), amount / 4);

        // Checks.

        assertApproxEqAbs(testUsdc.balanceOf(address(this)), 0, 100);
        assertApproxEqAbs(ethPool.borrowBalance(address(testUsdc), address(this)), 0, 100);
        assertEq(ethPool.totalBorrows(address(testUsdc)), 0);
    }

    function testCrossChainDestRepay(uint256 amount) public {
        vm.assume(amount >= 1e5 && amount <= 1e19);

        testCrossChainDestBorrow(amount);

        // Repay the tokens.
        testUsdc.approve(address(flarePool), amount / 4);
        flarePool.repay(address(testUsdc), amount / 4);

        // Checks.
        assertApproxEqAbs(testUsdc.balanceOf(address(this)), 0, 100);
        assertApproxEqAbs(flarePool.borrowBalance(address(testUsdc), address(this)), 0, 100);
        assertEq(flarePool.totalBorrows(address(testUsdc)), 0);
    }

    // UTILS ================================================================

    function mintAndApprove(MockERC20 underlying, uint256 amount, address poolAddress) internal {
        underlying.mint(address(this), amount);
        underlying.approve(poolAddress, amount);

        // uint256 userBalance = testEth.balanceOf(address(this));
    }

    function updateOraclePrices(address _asset, uint256 price) private {
        if (block.chainid != 16) {
            oracle.updatePrice(_asset, price);
        } else {
            if (_asset == address(testEth)) {
                ftsoRegistry.updatePrice(ETH_FTSO_IDX, price / 10 ** (18 - ETH_FTSO_DECIMALS), ETH_FTSO_DECIMALS);
            } else if (_asset == address(testUsdc)) {
                ftsoRegistry.updatePrice(USDC_FTSO_IDX, price / 10 ** (18 - USDC_FTSO_DECIMALS), USDC_FTSO_DECIMALS);
            }
        }
    }
}
