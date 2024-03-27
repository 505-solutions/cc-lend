// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "./Interfaces/IERC20.sol";

contract CcLending {
    mapping(address => mapping(address => uint256)) private balances;
    mapping(address => mapping(address => uint256)) private borrowedBalance; // balance the user has borrowed on flare

    address[] assets;

    function updateBorrowedBalance(
        address user,
        address tokenAddress,
        uint256 amount,
        bool increase
    ) public {
        if (increase) {
            borrowedBalance[user][tokenAddress] += amount;
        } else {
            borrowedBalance[user][tokenAddress] -= amount;
        }
    }

    function depositETH() public payable {
        balances[msg.sender][address(0)] += msg.value;
    }

    function depositERC20(address tokenAddress, uint256 amount) public {
        IERC20 token = IERC20(tokenAddress);

        bool success = token.transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer failed");

        balances[msg.sender][tokenAddress] += amount;
    }

    function withdrawETH(uint256 amount) public {
        require(
            totalBorrowedNominal(msg.sender) == 0,
            "Repay funds on flare before withdrawing"
        );
        require(
            balances[msg.sender][address(0)] >= amount,
            "Insufficient balance"
        );

        balances[msg.sender][address(0)] -= amount;
        payable(msg.sender).transfer(amount);
    }

    function withdrawERC20(address tokenAddress, uint256 amount) public {
        require(
            totalBorrowedNominal(msg.sender) == 0,
            "Repay funds on flare before withdrawing"
        );
        require(
            balances[msg.sender][tokenAddress] >= amount,
            "Insufficient balance"
        );
        balances[msg.sender][tokenAddress] -= amount;

        IERC20 token = IERC20(tokenAddress);
        bool success = token.transfer(msg.sender, amount);
        require(success, "Transfer failed");
    }

    function balanceOf(
        address user,
        address tokenAddress
    ) public view returns (uint256) {
        return balances[user][tokenAddress];
    }

    // UTILS
    function totalBorrowedNominal(
        address user
    ) internal view returns (uint256) {
        uint totalBorrowedValue = 0;
        for (uint256 i = 0; i < assets.length; i++) {
            totalBorrowedValue +=
                getTokenPrice(assets[i]) *
                borrowedBalance[user][assets[i]];
        }

        return totalBorrowedValue;
    }

    // UTILS
    function getTokenPrice(
        address tokenAddress
    ) internal view returns (uint256) {
        return 1;
    }
}
