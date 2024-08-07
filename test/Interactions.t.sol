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

import {MockERC20} from "./mocks/MockERC20.sol";
import {MockPriceOracle} from "./mocks/MockPriceOracle.sol";
import {MockFtsoRegistry} from "./mocks/MockFtsoRegistry.sol";
import {MockInterestRateModel} from "./mocks/MockInterestRateModel.sol";
// import {MockLiquidator} from "./mocks/MockLiquidator.sol";

import {LendingPool} from "src/LendingPool.sol";

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

/// @title Configuration Test Contract
contract InteractionsTest is Test {
    using FixedPointMathLib for uint256;

    /* Lending Pool Contracts */
    LendingPool pool;

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

    bool constant ALLOW_DOUBLE_BORROW = true;

    function setUp() public {
        pool = new LendingPool();
        pool.initialize(address(this), address(this), ALLOW_DOUBLE_BORROW);

        interestRateModel = new MockInterestRateModel();

        testEth = new MockERC20("Mock ETH", "MKE", 18);
        pool.configureAsset(address(testEth), address(testEth), 0.5e18, 0, ETH_FTSO_IDX, true);
        pool.setInterestRateModel(address(testEth), address(interestRateModel));

        testTokenX = new MockERC20("Mock TOKENX", "MKU", 18);

        pool.configureAsset(address(testTokenX), address(testTokenX), 0, 1e18, TOKENX_FTSO_IDX, false);
        pool.setInterestRateModel(address(testTokenX), address(interestRateModel));

        // * ORACLE CONFIGURATIONS
        ftsoRegistry = new MockFtsoRegistry();
        ftsoRegistry.updatePrice(ETH_FTSO_IDX, 3000e5, 5);
        ftsoRegistry.updatePrice(TOKENX_FTSO_IDX, 1e5, 5);

        pool.setOracleSource(address(ftsoRegistry));
    }

    function testDeposit(uint256 amount) public {
        vm.assume(amount >= 1e5 && amount <= 1e27);

        // Mint, approve, and deposit the testEth.
        mintAndApprove(testEth, amount);

        uint256 userBalance = testEth.balanceOf(address(this));
        uint256 poolBalance = testEth.balanceOf(address(pool));

        pool.deposit(address(testEth), amount, false);

        uint256 userBalance2 = testEth.balanceOf(address(this));
        uint256 poolBalance2 = testEth.balanceOf(address(pool));

        // Checks. Note that the default exchange rate is 1,
        // so the values should be equal to the input amount.
        assertEq(pool.balanceOf(address(testEth), address(this)), amount, "Incorrect Balance");
        assertEq(pool.totalUnderlying(address(testEth)), amount, "Incorrect Total Underlying");
    }

    function testWithdrawal(uint256 amount) public {
        vm.assume(amount >= 1e5 && amount <= 1e27);

        // Mint, approve, and deposit the testEth.
        testDeposit(amount);

        // Withdraw the testEth.
        pool.withdraw(address(testEth), amount, false);

        // Checks.
        assertEq(testEth.balanceOf(address(this)), amount, "Incorrect testEth balance");
        assertEq(pool.balanceOf(address(testEth), address(this)), 0, "Incorrect pool balance");
    }

    /*///////////////////////////////////////////////////////////////
                  DEPOSIT/WITHDRAWAL SANITY CHECK TESTS
    //////////////////////////////////////////////////////////////*/

    function testFailDepositAssetNotInPool() public {
        // Mock token.
        MockERC20 mockAsset = new MockERC20("Mock Token", "MKT", 18);

        // Mint tokens.
        mockAsset.mint(address(this), 1e18);

        // Approve the pool to spend half of the tokens.
        mockAsset.approve(address(pool), 0.5e18);

        // Attempt to deposit the tokens.
        pool.deposit(address(mockAsset), 1e18, false);
    }

    function testFailDepositWithNotEnoughApproval() public {
        // Mint tokens.
        testEth.mint(address(this), 1e18);

        // Approve the pool to spend half of the tokens.
        testEth.approve(address(pool), 0.5e18);

        // Attempt to deposit the tokens.
        pool.deposit(address(testEth), 1e18, false);
    }

    function testFailWithdrawAssetNotInPool() public {
        // Mock token.
        MockERC20 mockAsset = new MockERC20("Mock Token", "MKT", 18);

        // Mint tokens.
        testDeposit(1e18);

        // Attempt to withdraw the tokens.
        pool.withdraw(address(mockAsset), 1e18, false);
    }

    function testFailWithdrawWithNotEnoughBalance() public {
        // Mint tokens.
        testDeposit(1e18);

        // Attempt to withdraw the tokens.
        pool.withdraw(address(testEth), 2e18, false);
    }

    function testFailWithdrawWithNoBalance() public {
        // Attempt to withdraw tokens.
        pool.withdraw(address(testEth), 1e18, false);
    }

    function testFailWithNoApproval() public {
        // Attempt to deposit tokens.
        pool.deposit(address(testEth), 1e18, false);
    }

    /*///////////////////////////////////////////////////////////////
                         COLLATERALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testEnableCollateral() public {
        // Enable testEth as collateral.
        pool.enableAsset(address(testEth));

        // Checks.
        assertTrue(pool.enabledCollateral(address(this), address(testEth)));
    }

    function testDisableCollateral() external {
        // Enable the testEth as collateral.
        testEnableCollateral();

        // Disable the testEth as collateral.
        pool.disableAsset(address(testEth));

        // Checks.
        assertFalse(pool.enabledCollateral(address(this), address(testEth)));
    }

    /*///////////////////////////////////////////////////////////////
                         BORROW/REPAYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function testBorrow(uint256 amount) public {
        vm.assume(amount >= 1e5 && amount <= 1e27);

        // Deposit tokens and enable them as collateral.
        mintAndApprove(testEth, amount);
        pool.deposit(address(testEth), amount, true);

        // Mint borrow tokens and supply them to the pool.
        mintAndApprove(testTokenX, amount / 4);
        pool.deposit(address(testTokenX), amount / 4, false);

        // Set the price of collateral to 1 ETH.
        updateOraclePrices(address(testEth), 1e18);

        // Set the price of the borrow testEth to 2 ETH.
        // This means that with a 0.5 lend factor, we should be able to borrow 0.25 ETH.
        updateOraclePrices(address(testTokenX), 2e18);

        // Borrow the testEth.
        pool.borrow(address(testTokenX), amount / 4);

        // Checks.
        assertEq(testTokenX.balanceOf(address(this)), amount / 4);
        assertEq(pool.borrowBalance(address(testTokenX), address(this)), amount / 4);
        assertEq(pool.totalBorrows(address(testTokenX)), amount / 4);
        assertEq(pool.totalUnderlying(address(testTokenX)), amount / 4);
    }

    function testBorrow2(uint256 amount) public {
        vm.assume(amount >= 1e5 && amount <= 1e27);

        uint256 amount = 1 ether;
        uint256 borrowAmount = 1200 ether;

        // Deposit tokens and enable them as collateral.
        mintAndApprove(testEth, amount);
        pool.deposit(address(testEth), amount, true);

        // Mint borrow tokens and supply them to the pool.
        mintAndApprove(testTokenX, borrowAmount);
        pool.deposit(address(testTokenX), borrowAmount, false);

        // Set the price of collateral to 1 ETH.
        updateOraclePrices(address(testEth), 1e18);

        updateOraclePrices(address(testTokenX), 0.0003 ether);

        // Borrow the testEth.
        pool.borrow(address(testTokenX), borrowAmount);

        console.log(pool.totalBorrows(address(testTokenX)));

        // Checks.
        assertEq(testTokenX.balanceOf(address(this)), borrowAmount);
        assertEq(pool.borrowBalance(address(testTokenX), address(this)), borrowAmount);
        assertEq(pool.totalBorrows(address(testTokenX)), borrowAmount);
        assertEq(pool.totalUnderlying(address(testTokenX)), borrowAmount);
    }

    function testRepay(uint256 amount) public {
        vm.assume(amount >= 1e5 && amount <= 1e27);

        // Borrow tokens.
        testBorrow(amount);

        // Repay the tokens.
        testTokenX.approve(address(pool), amount / 4);
        pool.repay(address(testTokenX), amount / 4);
    }

    function testInterestAccrual() public {
        uint256 amount = 1e18;

        // block number is 1.

        // Borrow tokens.
        testBorrow(amount);

        // Warp block number to 6.
        vm.roll(block.number + 5);

        // Calculate the expected amount (after interest).
        // The borrow rate is constant, so the interest is always 5% per block.
        // expected = borrowed * interest ^ (blockDelta)
        uint256 expected = (amount / 4).mulWadDown(uint256(interestRateModel.getBorrowRate(0, 0, 0)).rpow(5, 1e18));

        // Checks.
        assertEq(pool.borrowBalance(address(testTokenX), address(this)), expected);
        assertEq(pool.totalBorrows(address(testTokenX)), expected);
        assertEq(pool.totalUnderlying(address(testTokenX)), expected);
        assertEq(pool.balanceOf(address(testTokenX), address(this)), expected);
    }

    // /*///////////////////////////////////////////////////////////////
    //                BORROW/REPAYMENT SANITY CHECK TESTS
    // //////////////////////////////////////////////////////////////*/

    function testFailBorrowAssetNotInPool() public {
        // Mock token.
        MockERC20 mockAsset = new MockERC20("Mock Token", "MKT", 18);

        // Amount to mint.
        uint256 amount = 1e18;

        // Deposit tokens and enable them as collateral.
        mintAndApprove(testEth, amount);
        pool.deposit(address(testEth), amount, true);

        // Mint borrow tokens and supply them to the pool.
        mintAndApprove(testTokenX, amount / 4);
        pool.deposit(address(testTokenX), amount / 4, false);

        // Set the price of collateral to 1 ETH.
        updateOraclePrices(address(testEth), 1e18);

        // Set the price of the borrow testEth to 2 ETH.
        // This means that with a 0.5 lend factor, we should be able to borrow 0.25 ETH.
        updateOraclePrices(address(testTokenX), 2e18);

        // Borrow the testEth.
        pool.borrow(address(mockAsset), amount / 4);
    }

    function testFailBorrowWithCollateralDisabled(uint256 amount) public {
        vm.assume(amount >= 1e5 && amount <= 1e27);

        // Deposit tokens and enable them as collateral.
        mintAndApprove(testEth, amount);
        pool.deposit(address(testEth), amount, false);

        // Mint borrow tokens and supply them to the pool.
        mintAndApprove(testTokenX, amount / 2);
        pool.deposit(address(testTokenX), amount / 2, false);

        // Set the price of collateral to 1 ETH.
        updateOraclePrices(address(testEth), 1e18);

        // Set the price of the borrow testEth to 2 ETH.
        // This means that with a 0.5 lend factor, we should be able to borrow 0.25 ETH.
        updateOraclePrices(address(testTokenX), 2e18);

        // Borrow the testEth.
        pool.borrow(address(testTokenX), amount / 4);
    }

    function testFailBorrowWithNoCollateral(uint256 amount) public {
        vm.assume(amount >= 1e5 && amount <= 1e27);

        // Mint borrow tokens and supply them to the pool.
        mintAndApprove(testTokenX, amount);
        pool.deposit(address(testTokenX), amount, false);

        // Set the price of collateral to 1 ETH.
        updateOraclePrices(address(testEth), 1e18);

        // Set the price of the borrow testEth to 2 ETH.
        // This means that with a 0.5 lend factor, we should be able to borrow 0.25 ETH.
        updateOraclePrices(address(testTokenX), 2e18);

        // Borrow the testEth.
        pool.borrow(address(testTokenX), amount);
    }

    function testFailBorrowWithNotEnoughCollateral(uint256 amount) public {
        vm.assume(amount >= 1e5 && amount <= 1e27);

        // Deposit tokens and enable them as collateral.
        mintAndApprove(testEth, amount);
        pool.deposit(address(testEth), amount, true);

        // Mint borrow tokens and supply them to the pool.
        mintAndApprove(testTokenX, amount / 2);
        pool.deposit(address(testTokenX), amount / 2, false);

        // Set the price of collateral to 1 ETH.
        updateOraclePrices(address(testEth), 1e18);

        // Set the price of the borrow testEth to 2 ETH.
        // This means that with a 0.5 lend factor, we should be able to borrow 0.25 ETH.
        updateOraclePrices(address(testTokenX), 2e18);

        // Borrow the testEth.
        pool.borrow(address(testTokenX), amount / 2);
    }

    function testCannotDisableIfBeingBorrowed() public {
        // Borrow testEth.
        testBorrow(1e18);

        // Attempt to disable the testEth as collateral.
        pool.disableAsset(address(testTokenX));

        // Checks.
        assertTrue(pool.enabledCollateral(address(this), address(testTokenX)));
    }

    // UTILS ================================================================

    function mintAndApprove(MockERC20 underlying, uint256 amount) internal {
        underlying.mint(address(this), amount);
        underlying.approve(address(pool), amount);

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
