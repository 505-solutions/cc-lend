// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

// import {IERC20} from "../Interfaces/IERC20.sol";

import {PriceOracle} from "./Interfaces/IPriceOracle.sol";
import {IFtsoRegistry} from "./Interfaces/IFtsoRegistry.sol";
import "./Interfaces/IERC20.sol";

/// @title Price Oracle Plugin
/// @notice This contract is used to get the price of an asset. We deploy a seperate contract for this
/// because we can have different oracle sources on different chains, but we want the Lending Pool Contracts to be the same.
/// This contract can be implemented in any other way, depending on which oracle source we are using.
/// This contract also translates the price denomination from USD to ETH.
contract PriceOraclePlugin {
    /// @notice Address of the price oracle contract.
    address public oracle;

    address immutable s_wethAddress;
    uint256 immutable s_ethFtsoIndex;

    constructor(address _wethAddress, uint256 _ethFtsoIndex) {
        s_ethFtsoIndex = _ethFtsoIndex;
        s_wethAddress = _wethAddress;
    }

    /// @notice Maps asset to the ftso index on flare.
    mapping(address => uint256) public s_assetFtsoIndex;

    /// @notice Emitted when the price oracle is changed.
    /// @param user The authorized user who triggered the change.
    /// @param newOracle The new price oracle address.
    event OracleUpdated(address indexed user, address indexed newOracle);

    /// @notice Sets a new oracle contract.
    /// @param newOracle The address of the new oracle.
    function setOracleSource(address newOracle) external {
        // Update the oracle.
        oracle = newOracle;

        // Emit the event.
        emit OracleUpdated(msg.sender, newOracle);
    }

    function setFtsoIndex(address asset, uint256 _ftsoIndex) external {
        s_assetFtsoIndex[asset] = _ftsoIndex;
    }

    /// @notice Gets the price of an asset.
    /// @param asset The underlying asset.
    function getAssetPrice(address asset) external view returns (uint256 assetPriceInEth) {
        if (block.chainid != 16) {
            // ! If on Sepolia

            uint256 ethPrice = PriceOracle(oracle).getUnderlyingPrice(s_wethAddress); // Scaled by 1e18

            uint256 price = PriceOracle(oracle).getUnderlyingPrice(asset); // Scaled by 1e18

            // Price in eth = (asset_P /  eth_P) * 1e18
            assetPriceInEth = (price * 1e18) / ethPrice;
        } else {
            // ! If on Flare

            uint256 ftsoIndex = s_assetFtsoIndex[asset];

            if (ftsoIndex == s_ethFtsoIndex) {
                return 1e18;
            } else {
                (uint256 ethPrice,, uint256 ethAssetPriceUsdDecimals) =
                    IFtsoRegistry(oracle).getCurrentPriceWithDecimals(s_ethFtsoIndex);

                if (ftsoIndex == 0) {
                    // ! Stablecoin

                    assetPriceInEth = (1e18 * 10 ** ethAssetPriceUsdDecimals) / (ethPrice);
                } else {
                    // ! Other assets

                    (uint256 price,, uint256 assetPriceUsdDecimals) =
                        IFtsoRegistry(oracle).getCurrentPriceWithDecimals(ftsoIndex);

                    // Price in eth = (asset_P /  eth_P) * 1e18
                    assetPriceInEth =
                        (price * 1e18 * 10 ** ethAssetPriceUsdDecimals) / (ethPrice * 10 ** assetPriceUsdDecimals);
                }
            }
        }
    }
}
