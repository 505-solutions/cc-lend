// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

// import "forge-std/Test.sol";
// import "forge-std/console.sol";
// import "forge-std/Vm.sol";

// import {LendingPool} from "src/LendingPool.sol";

// // // TODO: I should not have to import ERC20 from here.
// // import {ERC20} from "solmate/utils/SafeTransferLib.sol";

// import {PriceOracle} from "src/Interfaces/IPriceOracle.sol";
// import {InterestRateModel} from "src/Interfaces/IIRM.sol";

// import {MockERC20} from "./mocks/MockERC20.sol";
// import {MockPriceOracle} from "./mocks/MockPriceOracle.sol";
// import {MockInterestRateModel} from "./mocks/MockInterestRateModel.sol";
// // import {MockLiquidator} from "./mocks/MockLiquidator.sol";

// import {LendingPool} from "src/LendingPool.sol";

// import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

// /// @title Configuration Test Contract
// contract ConfigurationTest is Test {
//     using FixedPointMathLib for uint256;

//     /* Lending Pool Contracts */
//     LendingPool pool;

//     /* Mocks */
//     MockERC20 asset;
//     MockERC20 borrowAsset;

//     MockPriceOracle oracle;
//     MockInterestRateModel interestRateModel;
//     // MockLiquidator liquidator;

//     function setUp() public {
//         pool = new LendingPool(address(this));

//         interestRateModel = new MockInterestRateModel();

//         asset = new MockERC20();
//         asset.initialize("Test Token", "TEST", 18);

//         pool.configureAsset(address(asset), 0.5e18, 0);
//         pool.setInterestRateModel(address(asset), address(interestRateModel));

//         oracle = new MockPriceOracle();
//         oracle.updatePrice(address(asset), 1e18);
//         pool.setOracle(address(oracle));

//         borrowAsset = new MockERC20();
//         borrowAsset.initialize("Borrow Test Token", "TBT", 18);

//         pool.configureAsset(address(borrowAsset), 0, 1e18);
//         pool.setInterestRateModel(
//             address(borrowAsset),
//             address(interestRateModel)
//         );

//         liquidator = new MockLiquidator(pool, PriceOracle(address(oracle)));
//     }

//     /*///////////////////////////////////////////////////////////////
//                             LIQUIDATION TESTS
//     //////////////////////////////////////////////////////////////*/

//     function testUserLiquidatable(uint256 amount) public {
//         // TODO: do test with variable prices
//         vm.assume(amount >= 1e5 && amount <= 1e27);

//         // Deposit tokens and enable them as collateral.
//         mintAndApprove(asset, amount);
//         pool.deposit(address(asset), amount, true);

//         // Mint borrow tokens and supply them to the pool.
//         mintAndApprove(borrowAsset, amount);
//         pool.deposit(address(borrowAsset), amount, true);

//         // Update borrow Asset configuration
//         pool.updateConfiguration(
//             address(borrowAsset),
//             LendingPool.Configuration(0.5e18, 1e18)
//         );

//         // Set the price of collateral.
//         oracle.updatePrice(address(asset), 1e18);

//         // Set the price of the borrow asset.
//         oracle.updatePrice(address(borrowAsset), 1e18);

//         // Borrow the maximum available of `borrowAsset`.
//         pool.borrow(address(borrowAsset), pool.maxBorrowable());

//         // Current Health factor should be 1.00.
//         assertEq(
//             pool.calculateHealthFactor(ERC20(address(0)), address(this), 0),
//             1e18
//         );

//         // drop the price of asset by 10%.
//         oracle.updatePrice(address(asset), 0.9e18);

//         // Assert User can be liquidated.
//         assertTrue(pool.userLiquidatable(address(this)));
//     }

//     function testLiquidateUser() public {
//         uint256 amount = 1e18;

//         testUserLiquidatable(amount);

//         uint256 health = pool.calculateHealthFactor(
//             ERC20(address(0)),
//             address(this),
//             0
//         );

//         uint256 repayAmount = liquidator.calculateRepayAmount(
//             address(this),
//             health
//         );

//         mintAndApprove(borrowAsset, repayAmount);
//         pool.deposit(address(borrowAsset), repayAmount, true);

//         assertEq(
//             pool.calculateHealthFactor(ERC20(address(0)), address(this), 0),
//             pool.MAX_HEALTH_FACTOR()
//         );
//     }

//     /*///////////////////////////////////////////////////////////////
//                     LIQUIDATION SANITY CHECK TESTS
//     //////////////////////////////////////////////////////////////*/

//     // Cases where liquidation must not work.

//     /*///////////////////////////////////////////////////////////////
//                         COLLATERALIZATION TESTS
//     //////////////////////////////////////////////////////////////*/

//     function testEnableAsset(uint256 amount) public {
//         vm.assume(amount >= 1e5 && amount <= 1e27);

//         mintAndApprove(asset, amount);
//         pool.deposit(address(asset), amount, false);

//         pool.enableAsset(address(asset));

//         assertTrue(pool.enabledCollateral(address(this), address(asset)));
//     }

//     function testDisableAsset(uint256 amount) public {
//         vm.assume(amount >= 1e5 && amount <= 1e27);

//         mintAndApprove(asset, amount);
//         pool.deposit(address(asset), amount, true);

//         pool.disableAsset(address(asset));

//         assertFalse(pool.enabledCollateral(address(this), address(asset)));
//     }

//     /*///////////////////////////////////////////////////////////////
//                                  UTILS
//     //////////////////////////////////////////////////////////////*/

//     // Mint and approve assets.
//     function mintAndApprove(MockERC20 underlying, uint256 amount) internal {
//         underlying.mint(address(this), amount);
//         underlying.approve(address(pool), amount);
//     }
// }
