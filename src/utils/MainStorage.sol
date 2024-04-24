// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

abstract contract MainStorage {
    /*///////////////////////////////////////////////////////////////
                          ACCESS CONTROLS
    //////////////////////////////////////////////////////////////*/
    address s_messageRelay;

    modifier onlyMessageRelay() {
        require(msg.sender == s_messageRelay, "NOT_MESSAGE_RELAY");
        _;
    }

    /*///////////////////////////////////////////////////////////////
                          INTEREST RATE CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Maps ERC20 token addresses to their respective Interest Rate Model.
    mapping(address => address) public interestRateModels;

    /// @notice Emitted when an InterestRateModel is changed.
    /// @param asset The underlying asset whose IRM was modified.
    /// @param newInterestRateModel The new IRM address.
    event InterestRateModelUpdated(address user, address asset, address newInterestRateModel);

    /*///////////////////////////////////////////////////////////////
                          ASSET CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Maps underlying tokens to their configurations.
    mapping(address => Configuration) public configurations;

    /// @notice Maps underlying assets to their base units.
    /// 10**asset.decimals().
    mapping(address => uint256) public baseUnits;

    /// @notice Emitted when a new asset is added to the pool.
    /// @param asset The underlying asset.
    /// @param configuration The lend/borrow factors for the asset.
    event AssetConfigured(address asset, Configuration configuration);

    /// @notice Emitted when an asset configuration is updated.
    /// @param asset The underlying asset.
    /// @param newConfiguration The new lend/borrow factors for the asset.
    event AssetConfigurationUpdated(address asset, Configuration newConfiguration);

    /// @dev Asset configuration struct.
    struct Configuration {
        uint256 lendFactor;
        uint256 borrowFactor;
    }

    /*///////////////////////////////////////////////////////////////
                       DEPOSIT/WITHDRAW INTERFACE
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted after a sucessful deposit.
    /// @param from The address that triggered the deposit.
    /// @param asset The underlying asset.
    /// @param amount The amount being deposited.
    event Deposit(address indexed from, address asset, uint256 amount, bool enable);

    /// @notice Emitted after a successful withdrawal.
    /// @param from The address that triggered the withdrawal.
    /// @param asset The underlying asset.
    /// @param amount The amount being withdrew.
    event Withdraw(address indexed from, address asset, uint256 amount, bool disable);

    /*///////////////////////////////////////////////////////////////
                      BORROW/REPAYMENT INTERFACE
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted after a successful borrow.
    /// @param from The address that triggered the borrow.
    /// @param asset The underlying asset.
    /// @param amount The amount being borrowed.
    event Borrow(address indexed from, address asset, uint256 amount);

    /// @notice Emitted after a successful repayment.
    /// @param from The address that triggered the repayment.
    /// @param asset The underlying asset.
    /// @param amount The amount being repaid.
    event Repay(address indexed from, address asset, uint256 amount);

    /*///////////////////////////////////////////////////////////////
                          LIQUIDATION INTERFACE
    //////////////////////////////////////////////////////////////*/

    // Maximum health factor after liquidation.
    uint256 public constant MAX_HEALTH_FACTOR = 1.25 * 1e18;

    /*///////////////////////////////////////////////////////////////
                      COLLATERALIZATION INTERFACE
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted after an asset has been collateralized.
    /// @param from The address that triggered the enablement.
    /// @param asset The underlying asset.
    event AssetEnabled(address indexed from, address asset);

    /// @notice Emitted after an asset has been disabled.
    /// @param from The address that triggered the disablement.
    /// @param asset The underlying asset.
    event AssetDisabled(address indexed from, address asset);

    /// @notice Maps users to an array of assets they have listed as collateral.
    mapping(address => address[]) public userCollateral;

    /// @notice Maps users to a map from assets to boleans indicating whether they have listed as collateral.
    mapping(address => mapping(address => bool)) public enabledCollateral;

    /*///////////////////////////////////////////////////////////////
                        BALANCE ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev Maps assets to user addresses to their balances, which are not denominated in underlying.
    /// Instead, these values are denominated in internal balance units, which internally account
    /// for user balances, increasing in value as the LendingPool earns more interest.
    mapping(address => mapping(address => uint256)) internal internalBalances;

    /// @dev Maps assets to the total number of internal balance units "distributed" amongst lenders.
    mapping(address => uint256) internal totalInternalBalances;

    /// @dev Maps assets to the total liquidity on the exchange (liquidity on Eth + liquidity on Flare).
    mapping(address => uint256) internal availableLiquidity;

    /*///////////////////////////////////////////////////////////////
                          DEBT ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev Maps assets to user addresses to their debt, which are not denominated in underlying.
    /// Instead, these values are denominated in internal debt units, which internally account
    /// for user debt, increasing in value as the LendingPool earns more interest.
    mapping(address => mapping(address => uint256)) internal internalDebt;

    /// @dev Maps assets to the total number of internal debt units "distributed" amongst borrowers.
    mapping(address => uint256) internal totalInternalDebt;

    /*///////////////////////////////////////////////////////////////
                        INTEREST ACCRUAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev Maps assets to the total number of underlying loaned out to borrowers.
    /// Note that these values are not updated, instead recording the total borrow amount
    /// each time a borrow/repayment occurs.
    mapping(address => uint256) internal cachedTotalBorrows;

    /// @dev Store the block number of the last interest accrual for each asset.
    mapping(address => uint256) internal lastInterestAccrual;

    /*///////////////////////////////////////////////////////////////
                      BORROW ALLOWANCE CHECKS
    //////////////////////////////////////////////////////////////*/

    /// @dev Store account liquidity details whilst avoiding stack depth errors.
    struct AccountLiquidity {
        // A user's total borrow balance in ETH.
        uint256 borrowBalance;
        // A user's maximum borrowable value. If their borrowed value
        // reaches this point, they will get liquidated.
        uint256 maximumBorrowable;
        // A user's borrow balance in ETH multiplied by the average borrow factor.
        // TODO: need a better name for this
        uint256 borrowBalancesTimesBorrowFactors;
        // A user's actual borrowable value. If their borrowed value
        // is greater than or equal to this number, the system will
        // not allow them to borrow any more assets.
        uint256 actualBorrowable;
    }
}
