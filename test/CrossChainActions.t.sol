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
    LendingPool ethPool;
    LendingPool flarePool;

    /* Mocks */
    MockERC20 testEth;
    MockERC20 testTokenX;

    MockPriceOracle oracle;
    MockFtsoRegistry ftsoRegistry;

    MockInterestRateModel interestRateModel;
    // MockLiquidator liquidator;

    uint256 constant ETH_FTSO_IDX = 10;
    uint256 constant ETH_FTSO_DECIMALS = 5;
    uint256 constant TOKENX_FTSO_IDX = 25;
    uint256 constant TOKENX_FTSO_DECIMALS = 5;

    bool constant ALLOW_DOUBLE_BORROW = false;

    function setUp() public {
        // ! For non upgradable contracts
        // ethPool = new LendingPool(address(this), address(this));
        // flarePool = new LendingPool(address(this), address(this));

        // ! For upgradable contracts
        ethPool = new LendingPool();
        ethPool.initialize(address(this), address(this), ALLOW_DOUBLE_BORROW);
        flarePool = new LendingPool();
        flarePool.initialize(address(this), address(this), ALLOW_DOUBLE_BORROW);

        interestRateModel = new MockInterestRateModel();

        testEth = new MockERC20("Mock Eth", "MKE", 18);
        ethPool.configureAsset(address(testEth), address(testEth), 0.5e18, 0, ETH_FTSO_IDX, true);
        ethPool.setInterestRateModel(address(testEth), address(interestRateModel));
        flarePool.configureAsset(address(testEth), address(testEth), 0.5e18, 0, ETH_FTSO_IDX, true);
        flarePool.setInterestRateModel(address(testEth), address(interestRateModel));

        testTokenX = new MockERC20("Mock TOKENX", "MKU", 18);

        ethPool.configureAsset(address(testTokenX), address(testTokenX), 0, 1e18, TOKENX_FTSO_IDX, false);
        ethPool.setInterestRateModel(address(testTokenX), address(interestRateModel));
        flarePool.configureAsset(address(testTokenX), address(testTokenX), 0, 1e18, TOKENX_FTSO_IDX, false);
        flarePool.setInterestRateModel(address(testTokenX), address(interestRateModel));

        // * ORACLE CONFIGURATIONS

        ftsoRegistry = new MockFtsoRegistry();
        ftsoRegistry.updatePrice(ETH_FTSO_IDX, 3000e5, 5);
        ftsoRegistry.updatePrice(TOKENX_FTSO_IDX, 1e5, 5);

        ethPool.setOracleSource(address(ftsoRegistry));
        flarePool.setOracleSource(address(ftsoRegistry));
    }

    function increaseExchangeLiquidity() internal {
        // NOTE: Funds both pools with enough assets to test crosschain interactions.
        mintAndApprove(testEth, 100 ether, address(ethPool));
        ethPool.increaseAvailableLiquidity(address(testEth), 100 ether);

        mintAndApprove(testTokenX, 100 ether, address(ethPool));
        ethPool.increaseAvailableLiquidity(address(testTokenX), 100 ether);

        mintAndApprove(testEth, 100 ether, address(flarePool));
        flarePool.increaseAvailableLiquidity(address(testEth), 100 ether);

        mintAndApprove(testTokenX, 100 ether, address(flarePool));
        flarePool.increaseAvailableLiquidity(address(testTokenX), 100 ether);
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
        vm.expectRevert("ATTEMPTED DOUBLE_BORROWING");
        flarePool.withdraw(address(testEth), amount, false);

        // // Checks.
        // assertEq(testEth.balanceOf(address(this)), amount, "Incorrect testEth balance");
        // assertApproxEqAbs(
        //     flarePool.balanceOf(address(testEth), address(this)), 100 ether, 100, "Incorrect pool balance"
        // );

        // ethPool.handleCrossChainWithdrawal(address(testEth), amount, address(this), false);

        // assertEq(testEth.balanceOf(address(this)), amount, "Incorrect testEth balance");
        // assertApproxEqAbs(ethPool.balanceOf(address(testEth), address(this)), 100 ether, 100, "Incorrect pool balance");
    }

    function testCrossChainSourceBorrow(uint256 amount) public {
        vm.assume(amount >= 1e5 && amount <= 1e19);

        // Mint, approve, and deposit the testEth.
        testCrossChainDeposit(amount);

        increaseExchangeLiquidity();

        // Update oracle prices
        updateOraclePrices(address(testEth), 4000e18);
        updateOraclePrices(address(testTokenX), 2e18);

        // Borrow the testEth.

        vm.expectRevert("ATTEMPTED DOUBLE_BORROWING");
        ethPool.borrow(address(testTokenX), amount / 4);

        // // Checks.
        // assertEq(testTokenX.balanceOf(address(this)), amount / 4);
        // assertEq(ethPool.borrowBalance(address(testTokenX), address(this)), amount / 4);
        // assertEq(ethPool.totalBorrows(address(testTokenX)), amount / 4);

        // flarePool.handleCrossChainBorrow(address(testTokenX), amount / 4, address(this));

        // assertEq(testTokenX.balanceOf(address(this)), amount / 4);
        // assertEq(flarePool.borrowBalance(address(testTokenX), address(this)), amount / 4);
        // assertEq(flarePool.totalBorrows(address(testTokenX)), amount / 4);
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
        updateOraclePrices(address(testTokenX), 2e18);

        // Borrow the testEth.
        flarePool.borrow(address(testTokenX), amount / 4);

        // Checks.
        assertEq(testTokenX.balanceOf(address(this)), amount / 4);
        assertEq(flarePool.borrowBalance(address(testTokenX), address(this)), amount / 4);
        assertEq(flarePool.totalBorrows(address(testTokenX)), amount / 4);

        ethPool.handleCrossChainBorrow(address(testTokenX), amount / 4, address(this));

        assertEq(testTokenX.balanceOf(address(this)), amount / 4);
        assertEq(ethPool.borrowBalance(address(testTokenX), address(this)), amount / 4);
        assertEq(ethPool.totalBorrows(address(testTokenX)), amount / 4);
    }

    //
    function testCrossChainSourceRepay(uint256 amount) public {
        vm.assume(amount >= 1e5 && amount <= 1e19);

        // uint256 amount = 0.25 ether;

        testCrossChainSourceBorrow(amount);

        // Repay the tokens.
        testTokenX.approve(address(ethPool), amount / 4);

        vm.expectRevert("ATTEMPTED DOUBLE_BORROWING");
        ethPool.repay(address(testTokenX), amount / 4);

        // // Checks.
        // assertApproxEqAbs(testTokenX.balanceOf(address(this)), 0, 100);
        // assertApproxEqAbs(ethPool.borrowBalance(address(testTokenX), address(this)), 0, 100);
        // assertEq(ethPool.totalBorrows(address(testTokenX)), 0);
    }

    function testCrossChainDestRepay(uint256 amount) public {
        vm.assume(amount >= 1e5 && amount <= 1e19);

        testCrossChainDestBorrow(amount);

        // Repay the tokens.
        testTokenX.approve(address(flarePool), amount / 4);
        flarePool.repay(address(testTokenX), amount / 4);

        // Checks.
        assertApproxEqAbs(testTokenX.balanceOf(address(this)), 0, 100);
        assertApproxEqAbs(flarePool.borrowBalance(address(testTokenX), address(this)), 0, 100);
        assertEq(flarePool.totalBorrows(address(testTokenX)), 0);
    }

    // UTILS ================================================================

    function mintAndApprove(MockERC20 underlying, uint256 amount, address poolAddress) internal {
        underlying.mint(address(this), amount);
        underlying.approve(poolAddress, amount);

        // uint256 userBalance = testEth.balanceOf(address(this));
    }

    function updateOraclePrices(address _asset, uint256 price) private {
        if (_asset == address(testEth)) {
            ftsoRegistry.updatePrice(ETH_FTSO_IDX, price / 10 ** (18 - ETH_FTSO_DECIMALS), ETH_FTSO_DECIMALS);
        } else if (_asset == address(testTokenX)) {
            ftsoRegistry.updatePrice(TOKENX_FTSO_IDX, price / 10 ** (18 - TOKENX_FTSO_DECIMALS), TOKENX_FTSO_DECIMALS);
        }
    }
}
