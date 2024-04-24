// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

/**
 * @title Lending Pool Interface
 * @author Snojj25
 */
interface ILendingPool {
    // * DEPOSITS * //

    /// @notice Deposit underlying tokens into the pool.
    /// @param asset The underlying asset.
    /// @param amount The amount to be deposited.
    /// @param enable A boolean indicating whether to enable the underlying asset as collateral.
    function deposit(address asset, uint256 amount, bool enable) external;

    /// @notice Handle the deposit event passed from the Source Chain by the Message Relay.
    function handleCrossChainDeposit(address asset, uint256 amount, address depositor, bool enable) external;

    // * WITDHRAWALS * //

    /// @notice Withdraw underlying tokens from the pool.
    /// @param asset The underlying asset.
    /// @param amount The amount to be withdrawn.
    /// @param disable A boolean indicating whether to disable the underlying asset as collateral.
    function withdraw(address asset, uint256 amount, bool disable) external;

    /// @notice Handle the withdrawal event passed from the Source Chain by the Message Relay.
    function handleCrossChainWithdrawal(address asset, uint256 amount, address depositor, bool disable) external;

    // * BORROW * //

    /// @notice Borrow underlying tokens from the pool.
    /// @param asset The underlying asset.
    /// @param amount The amount to borrow.
    function borrow(address asset, uint256 amount) external;

    /// @notice Handle the borrow event passed from the Source Chain by the Message Relay.
    function handleCrossChainBorrow(address asset, uint256 amount, address depositor) external;

    // * REPAY * //

    /// @notice Repay underlying tokens to the pool.
    /// @param asset The underlying asset.
    /// @param amount The amount to repay.
    function repay(address asset, uint256 amount) external;

    /// @notice Handle the repay event passed from the Source Chain by the Message Relay.
    function handleCrossChainRepay(address asset, uint256 amount, address depositor) external;
}
