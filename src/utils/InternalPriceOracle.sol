// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

// import {IERC20} from "../Interfaces/IERC20.sol";

import {PriceOracle} from "../Interfaces/IPriceOracle.sol";
import {IFtsoRegistry} from "../Interfaces/IFtsoRegistry.sol";
import "../Interfaces/IERC20.sol";

import "./MainStorage.sol";

/// @title Price Oracle Plugin
/// @notice This contract is used to get the price of an asset.
/// We use the Flare Time Series Oracle (FTSO) to get the price of an asset
/// and convert it to the price of the asset denominated in ETH and scale it to 1e18 decimals.
abstract contract InternalPriceOracle is MainStorage {
    /// @notice Address of the price oracle contract.
    address public oracleSource;

    /// @notice Emitted when the price oracle is changed.
    /// @param user The authorized user who triggered the change.
    /// @param newOracle The new price oracle address.
    event OracleUpdated(address indexed user, address indexed newOracle);

    /// @notice Sets a new oracle contract.
    /// @param newOracle The address of the new oracle.
    function setOracleSource(address newOracle) external {
        // Update the oracle.
        oracleSource = newOracle;

        // Emit the event.
        emit OracleUpdated(msg.sender, newOracle);
    }

    /// @notice Gets the price of an asset.
    /// @param asset The underlying asset.
    /// @return assetPriceInEth The price of the asset denominated in eth.
    // TODO: SHould be marked as internal after testing
    function getAssetPrice(address asset) public view returns (uint256 assetPriceInEth) {
        uint256 ftsoIndex = s_assetFtsoIndex[asset];

        uint256 ethFtsoIndex = s_assetFtsoIndex[s_wethAddress];
        if (ftsoIndex == ethFtsoIndex) {
            return 1e18;
        } else {
            (uint256 ethPrice,, uint256 ethAssetPriceUsdDecimals) =
                IFtsoRegistry(oracleSource).getCurrentPriceWithDecimals(ethFtsoIndex);

            if (ftsoIndex == 0) {
                // ! Stablecoin

                assetPriceInEth = (1e18 * 10 ** ethAssetPriceUsdDecimals) / (ethPrice);
            } else {
                // ! Other assets

                (uint256 price,, uint256 assetPriceUsdDecimals) =
                    IFtsoRegistry(oracleSource).getCurrentPriceWithDecimals(ftsoIndex);

                // Price in eth = (asset_P /  eth_P) * 1e18
                assetPriceInEth =
                    (price * 1e18 * 10 ** ethAssetPriceUsdDecimals) / (ethPrice * 10 ** assetPriceUsdDecimals);
            }
        }
    }
}
