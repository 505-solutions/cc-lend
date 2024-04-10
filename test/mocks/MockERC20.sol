// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

// import {MockERC20} from "forge-std/mocks/MockERC20.sol";

import {MockERC20 as ForgeMockERC20} from "forge-std/mocks/MockERC20.sol";

contract MockERC20 is ForgeMockERC20 {
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
