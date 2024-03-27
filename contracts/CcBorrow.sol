// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "./Interfaces/IERC20.sol";

contract CcBorrow {
    mapping(address => mapping(address => uint256)) private ethBalance; // balance the user has deposited on ethereum
    mapping(address => mapping(address => uint256)) private borrowedBalance;

    address[] assets;

    function updateDepositedBalance(
        address user,
        address tokenAddress,
        uint256 amount,
        bool increase
    ) public {
        if (increase) {
            ethBalance[user][tokenAddress] += amount;
        } else {
            ethBalance[user][tokenAddress] -= amount;
        }
    }

    function borrow(address tokenAddress, uint256 amount) public {
        uint256 totalCollateralValue = totalLentNominal(msg.sender);
        uint256 prevBorrowedValue = totalBorrowedNominal(msg.sender);

        uint256 totalBorrowedValue = amount *
            getTokenPrice(tokenAddress) +
            prevBorrowedValue;

        require(
            totalBorrowedValue < totalCollateralValue / 2,
            "Borrow limit exceeded"
        );

        borrowedBalance[msg.sender][tokenAddress] += amount;

        if (tokenAddress == address(0)) {
            payable(msg.sender).transfer(amount);
        } else {
            IERC20 token = IERC20(tokenAddress);
            bool success = token.transfer(msg.sender, amount);
            require(success, "Transfer failed");
        }

        // ! Send this info back to ethereum
    }

    function repay(address tokenAddress, uint256 amount) public payable {
        borrowedBalance[msg.sender][tokenAddress] -= amount;

        if (tokenAddress == address(0)) {
            require(amount == msg.value, "Incorrect amount");
        } else {
            IERC20 token = IERC20(tokenAddress);
            bool success = token.transferFrom(
                msg.sender,
                address(this),
                amount
            );
            require(success, "Transfer failed");
        }

        // ! Send this info back to ethereum
    }

    // VIEW
    function balanceOf(
        address user,
        address tokenAddress
    ) public view returns (uint256) {
        return ethBalance[user][tokenAddress];
    }

    // UTILS
    function totalLentNominal(address user) internal view returns (uint256) {
        uint totalLentValue = 0;
        for (uint256 i = 0; i < assets.length; i++) {
            totalLentValue +=
                getTokenPrice(assets[i]) *
                ethBalance[user][assets[i]];
        }

        return totalLentValue;
    }

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

    function getTokenPrice(
        address tokenAddress
    ) internal view returns (uint256) {
        return 1;
    }
}
