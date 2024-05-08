// // SPDX-License-Identifier: MIT

// pragma solidity ^0.8.19;

// // Invariants:
// // protocol must never be insolvent / undercollateralized
// // TODO: users cant create stablecoins with a bad health factor
// // TODO: a user should only be able to be liquidated if they have a bad health factor

// import {Test} from "forge-std/Test.sol";
// import {StdInvariant} from "forge-std/StdInvariant.sol";
// import {DSCEngine} from "../../../src/DSCEngine.sol";
// import {DecentralizedStableCoin} from "../../../src/DecentralizedStableCoin.sol";
// import {HelperConfig} from "../../../script/HelperConfig.s.sol";
// import {DeployDSC} from "../../../script/DeployDSC.s.sol";
// // import { ERC20Mock } from "@openzeppelin/contracts/mocks/ERC20Mock.sol"; Updated mock location
// import {ERC20Mock} from "../../mocks/ERC20Mock.sol";
// import {StopOnRevertHandler} from "./StopOnRevertHandler.t.sol";
// import {console} from "forge-std/console.sol";

// contract StopOnRevertInvariants is StdInvariant, Test {
//     using FixedPointMathLib for uint256;

//     /* Lending Pool Contracts */
//     LendingPool ethPool;
//     LendingPool flarePool;

//     /* Mocks */
//     MockERC20 asset;
//     MockERC20 borrowAsset;

//     MockPriceOracle oracle;
//     MockInterestRateModel interestRateModel;

//     StopOnRevertHandler public handler;

//     function setUp() public {
//         pool = new LendingPool(address(this), address(this));

//         interestRateModel = new MockInterestRateModel();

//         asset = new MockERC20("Mock Token", "MKT", 18);

//         pool.configureAsset(address(asset), 0.5e18, 0);
//         pool.setInterestRateModel(address(asset), address(interestRateModel));

//         oracle = new MockPriceOracle();
//         oracle.updatePrice(address(asset), 1e18);
//         pool.setOracle(address(oracle));

//         borrowAsset = new MockERC20("Mock Token", "MKT", 18);

//         pool.configureAsset(address(borrowAsset), 0, 1e18);
//         pool.setInterestRateModel(address(borrowAsset), address(interestRateModel));

//         // liquidator = new MockLiquidator(pool, PriceOracle(address(oracle)));
//     }

//     function invariant_protocolMustHaveMoreValueThatTotalSupplyDollars() public view {
//         uint256 totalSupply = dsc.totalSupply();
//         uint256 wethDeposted = ERC20Mock(weth).balanceOf(address(dsce));
//         uint256 wbtcDeposited = ERC20Mock(wbtc).balanceOf(address(dsce));

//         uint256 wethValue = dsce.getUsdValue(weth, wethDeposted);
//         uint256 wbtcValue = dsce.getUsdValue(wbtc, wbtcDeposited);

//         console.log("wethValue: %s", wethValue);
//         console.log("wbtcValue: %s", wbtcValue);

//         assert(wethValue + wbtcValue >= totalSupply);
//     }

//     function invariant_gettersCantRevert() public view {
//         dsce.getAdditionalFeedPrecision();
//         dsce.getCollateralTokens();
//         dsce.getLiquidationBonus();
//         dsce.getLiquidationBonus();
//         dsce.getLiquidationThreshold();
//         dsce.getMinHealthFactor();
//         dsce.getPrecision();
//         dsce.getDsc();
//         // dsce.getTokenAmountFromUsd();
//         // dsce.getCollateralTokenPriceFeed();
//         // dsce.getCollateralBalanceOfUser();
//         // getAccountCollateralValue();
//     }
// }
