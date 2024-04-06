// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {IERC20} from "./IERC20.sol";

/// @title Price Oracle Interface.
interface PriceOracle {
    /// @notice Get the price of an asset.
    /// @param asset The address of the underlying asset.
    /// @dev The underlying asset price is scaled by 1e18.
    function getUnderlyingPrice(IERC20 asset) external view returns (uint256);
}
