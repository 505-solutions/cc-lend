// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

// import {IERC20} from "../Interfaces/IERC20.sol";

abstract contract PriceOracle {
    /// @notice Gets the price of an asset.
    /// @param asset The underlying asset.
    function getAssetPrice(address asset) internal view returns (uint256) {
        //TODO

        return 0;
    }
}
