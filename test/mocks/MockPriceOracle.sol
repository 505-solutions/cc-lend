// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

/// @title Mock Price Oracle
/// @dev This contract is used to replicate a Price Oracle contract
/// for unit tests.
contract MockPriceOracle {
    mapping(address => uint256) public prices;

    function updatePrice(address asset, uint256 price) external {
        prices[asset] = price;
    }

    function getUnderlyingPrice(address asset) public view returns (uint256) {
        return prices[asset];
    }
}
