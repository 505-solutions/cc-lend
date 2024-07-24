// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {IERC20} from "./Interfaces/IERC20.sol";

import {Accounting} from "./utils/Accounting.sol";

import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {Owned} from "solmate/auth/Owned.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract LendingPool is ReentrancyGuardUpgradeable, OwnableUpgradeable, UUPSUpgradeable, Accounting {
    using SafeTransferLib for IERC20;
    using SafeCastLib for uint256;
    using FixedPointMathLib for uint256;

    // constructor(address owner, address messageRelay) Owned(owner) {
    //     s_messageRelay = messageRelay;
    // }

    bool private s_allowDoubleBorrowing;

    /// @param initialOwner The owner of the contract.
    /// @param messageRelay The message relay contract.
    /// @param _allowDoubleBorrowing Can be used for more sophisticated borrowing strategies. (!!Should default to false!!)
    function initialize(address initialOwner, address messageRelay, bool _allowDoubleBorrowing) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        s_messageRelay = messageRelay;

        s_allowDoubleBorrowing = _allowDoubleBorrowing;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    /*///////////////////////////////////////////////////////////////
                       DEPOSIT/WITHDRAW INTERFACE
    //////////////////////////////////////////////////////////////*/

    // NOTE: Helper function for testing and possibly rebalancing the available liquidity.
    function increaseAvailableLiquidity(address asset, uint256 amount) external {
        // Transfer underlying in from the user.
        IERC20(asset).transferFrom(msg.sender, address(this), amount);

        availableLiquidity[asset] += amount;
    }

    // * DEPOSITS * //

    /// @notice Deposit underlying tokens into the pool.
    /// @param asset The underlying asset.
    /// @param amount The amount to be deposited.
    /// @param enable A boolean indicating whether to enable the underlying asset as collateral.
    function deposit(address asset, uint256 amount, bool enable) external nonReentrant {
        ActivityStatus status = s_activityStatus[msg.sender];
        require(
            status == ActivityStatus.NONE || status == ActivityStatus.LENDING || s_allowDoubleBorrowing,
            "ATTEMPTED DOUBLE_BORROWING"
        );

        _deposit(asset, amount, msg.sender, enable);

        // This flag is used to prevent double borrowing on ETH and Flare.
        s_activityStatus[msg.sender] = ActivityStatus.LENDING;

        // Transfer underlying in from the user.
        IERC20(asset).transferFrom(msg.sender, address(this), amount);

        // Emit the event.
        emit Deposit(msg.sender, asset, amount, enable);
    }

    /// @notice Handle the deposit event passed from the Source Chain by the Message Relay.
    function handleCrossChainDeposit(address counterpartAsset, uint256 amount, address depositor, bool enable)
        external
        onlyMessageRelay
        nonReentrant
    {
        address asset = fromAssetCounterpart[counterpartAsset];

        _deposit(asset, amount, depositor, enable);
    }

    function _deposit(address asset, uint256 amount, address depositor, bool enable) internal {
        // Ensure the amount is valid.
        require(amount > 0, "INVALID_AMOUNT");

        // Calculate the amount of internal balance units to be stored.
        uint256 shares = amount.mulDivDown(baseUnits[asset], internalBalanceExchangeRate(asset));

        // Modify the internal balance of the sender.
        // Cannot overflow because the sum of all user
        // balances won't be greater than type(uint256).max
        unchecked {
            internalBalances[asset][depositor] += shares;
        }

        // Add to the asset's total internal supply.
        totalInternalBalances[asset] += shares;

        // Add to the available liquidity of the asset in the system (on Eth + on Flare).
        availableLiquidity[asset] += amount;

        // If `enable` is set to true, enable the asset as collateral.
        if (enable) _enableAsset(asset, depositor);
    }

    // * WITDHRAWALS * //

    /// @notice Any amount smaller than this can be considered as zero.
    uint256 constant SHARES_BALANCE_DUST_AMOUT = 100;

    /// @notice Withdraw underlying tokens from the pool.
    /// @param asset The underlying asset.
    /// @param amount The amount to be withdrawn.
    /// @param disable A boolean indicating whether to disable the underlying asset as collateral.
    function withdraw(address asset, uint256 amount, bool disable) external nonReentrant {
        ActivityStatus status = s_activityStatus[msg.sender];
        require(status == ActivityStatus.LENDING || s_allowDoubleBorrowing, "ATTEMPTED DOUBLE_BORROWING");

        _withdraw(asset, amount, msg.sender, disable);

        if (internalBalances[asset][msg.sender] < SHARES_BALANCE_DUST_AMOUT) {
            // This flag is used to prevent double borrowing on ETH and Flare.
            s_activityStatus[msg.sender] = ActivityStatus.NONE;
        }

        // Transfer underlying to the user.
        IERC20(asset).transfer(msg.sender, amount);

        // Emit the event.
        emit Withdraw(msg.sender, asset, amount, disable);
    }

    /// @notice Handle the withdrawal event passed from the Source Chain by the Message Relay.
    function handleCrossChainWithdrawal(address counterpartAsset, uint256 amount, address depositor, bool disable)
        external
        onlyMessageRelay
        nonReentrant
    {
        address asset = fromAssetCounterpart[counterpartAsset];

        _withdraw(asset, amount, depositor, disable);
    }

    function _withdraw(address asset, uint256 amount, address depositor, bool disable) internal {
        // Ensure the amount is valid.
        require(amount > 0, "AMOUNT_TOO_LOW");

        // Calculate the amount of internal balance units to be subtracted.
        uint256 shares = amount.mulDivDown(baseUnits[asset], internalBalanceExchangeRate(asset));

        // Modify the internal balance of the sender.
        internalBalances[asset][depositor] -= shares;

        // Subtract from the asset's total internal supply.
        // Cannot undeflow because the user balance will
        // never be greater than the total suuply.
        unchecked {
            totalInternalBalances[asset] -= shares;
        }

        // Remove from the available liquidity of the asset in the system (on Eth + on Flare).
        availableLiquidity[asset] -= amount;

        // If `disable` is set to true, disable the asset as collateral.
        if (disable) _disableAsset(asset, depositor);
    }

    /*///////////////////////////////////////////////////////////////
                      BORROW/REPAYMENT INTERFACE
    //////////////////////////////////////////////////////////////*/

    /// @notice Borrow underlying tokens from the pool.
    /// @param asset The underlying asset.
    /// @param amount The amount to borrow.
    function borrow(address asset, uint256 amount) external nonReentrant {
        ActivityStatus status = s_activityStatus[msg.sender];
        require(
            status == ActivityStatus.NONE || status == ActivityStatus.BORROWING || s_allowDoubleBorrowing,
            "ATTEMPTED DOUBLE_BORROWING"
        );

        _borrow(asset, amount, msg.sender);

        // This flag is used to prevent double borrowing on ETH and Flare.
        s_activityStatus[msg.sender] = ActivityStatus.BORROWING;

        // Transfer tokens to the borrower.
        IERC20(asset).transfer(msg.sender, amount);

        // Emit the event.
        emit Borrow(msg.sender, asset, amount);
    }

    /// @notice Handle the borrow event passed from the Source Chain by the Message Relay.
    function handleCrossChainBorrow(address counterpartAsset, uint256 amount, address depositor)
        external
        onlyMessageRelay
        nonReentrant
    {
        address asset = fromAssetCounterpart[counterpartAsset];

        _borrow(asset, amount, depositor);
    }

    function _borrow(address asset, uint256 amount, address depositor) internal {
        // Ensure the amount is valid.
        require(amount > 0, "AMOUNT_TOO_LOW");

        // Accrue interest.
        // ?: is this the right place to accrue interest?
        accrueInterest(asset);

        // Enable the asset, if it is not already enabled.
        enableAsset(asset);

        // Ensure the caller is able to execute this borrow.
        require(canBorrow(asset, depositor, amount), "USER BORROW LIMIT EXCEEDED");

        // Calculate the amount of internal debt units to be stored.
        uint256 debtUnits = amount.mulDivDown(baseUnits[asset], internalDebtExchangeRate(asset));

        // Update the internal borrow balance of the borrower.
        // Cannot overflow because the sum of all user
        // balances won't be greater than type(uint256).max
        unchecked {
            internalDebt[asset][depositor] += debtUnits;
        }

        // Add to the asset's total internal debt.
        totalInternalDebt[asset] += debtUnits;

        // Remove from the available liquidity of the asset in the system (on Eth + on Flare).
        availableLiquidity[asset] -= amount;

        // Update the cached debt of the asset.
        cachedTotalBorrows[asset] += amount;
    }

    /// @notice Any amount smaller than this can be considered as zero.
    uint256 constant DEBT_DUST_AMOUT = 100;

    /// @notice Repay underlying tokens to the pool.
    /// @param asset The underlying asset.
    /// @param amount The amount to repay.
    function repay(address asset, uint256 amount) external nonReentrant {
        ActivityStatus status = s_activityStatus[msg.sender];
        require(status == ActivityStatus.BORROWING || s_allowDoubleBorrowing, "ATTEMPTED DOUBLE_BORROWING");

        _repay(asset, amount, msg.sender);

        if (internalDebt[asset][msg.sender] <= DEBT_DUST_AMOUT) {
            // This flag is used to prevent double borrowing on ETH and Flare.
            s_activityStatus[msg.sender] = ActivityStatus.NONE;
        }

        // Transfer tokens from the user.
        IERC20(asset).transferFrom(msg.sender, address(this), amount);

        // Emit the event.
        emit Repay(msg.sender, asset, amount);
    }

    /// @notice Handle the repay event passed from the Source Chain by the Message Relay.
    function handleCrossChainRepay(address counterpartAsset, uint256 amount, address depositor)
        external
        onlyMessageRelay
        nonReentrant
    {
        address asset = fromAssetCounterpart[counterpartAsset];

        _repay(asset, amount, depositor);
    }

    function _repay(address asset, uint256 amount, address depositor) internal {
        // Ensure the amount is valid.
        require(amount > 0, "AMOUNT_TOO_LOW");

        // Calculate the amount of internal debt units to be stored.
        uint256 debtUnits = amount.mulDivDown(baseUnits[asset], internalDebtExchangeRate(asset));

        // Update the internal borrow balance of the borrower.
        internalDebt[asset][depositor] -= debtUnits;

        // Add to the asset's total internal debt.
        // Cannot undeflow because the user balance will
        // never be greater than the total suuply.
        unchecked {
            totalInternalDebt[asset] -= debtUnits;
        }

        // Add to the available liquidity of the asset in the system (on Eth + on Flare).
        availableLiquidity[asset] += amount;

        // Accrue interest.
        // ?: is this the right place to accrue interest?
        accrueInterest(asset);

        // Update the cached debt of the asset.
        cachedTotalBorrows[asset] -= amount;
    }

    /*///////////////////////////////////////////////////////////////
                          LIQUIDATION INTERFACE
    //////////////////////////////////////////////////////////////*/

    // TODO: Figure out and Test liquidatio Logic
    function liquidateUser(address borrowedAsset, address collateralAsset, address borrower, uint256 repayAmount)
        external
        nonReentrant
    {
        require(userLiquidatable(borrower), "CANNOT_LIQUIDATE_HEALTHY_USER");

        // Calculate the number of collateral asset to be seized
        uint256 seizedCollateralAmount = seizeCollateral(borrowedAsset, collateralAsset, repayAmount);

        // Assert user health factor is == MAX_HEALTH_FACTOR
        require(calculateHealthFactor(borrowedAsset, borrower, 0) == MAX_HEALTH_FACTOR, "NOT_HEALTHY");
    }
}
