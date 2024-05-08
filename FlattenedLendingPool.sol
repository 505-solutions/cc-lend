// SPDX-License-Identifier: MIT
pragma solidity <0.9.0 >=0.7.0 >=0.8.0;

// node_modules/solmate/src/auth/Owned.sol

/// @notice Simple single owner authorization mixin.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/Owned.sol)
abstract contract Owned {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event OwnershipTransferred(address indexed user, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                            OWNERSHIP STORAGE
    //////////////////////////////////////////////////////////////*/

    address public owner;

    modifier onlyOwner() virtual {
        require(msg.sender == owner, "UNAUTHORIZED");

        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _owner) {
        owner = _owner;

        emit OwnershipTransferred(address(0), _owner);
    }

    /*//////////////////////////////////////////////////////////////
                             OWNERSHIP LOGIC
    //////////////////////////////////////////////////////////////*/

    function transferOwnership(address newOwner) public virtual onlyOwner {
        owner = newOwner;

        emit OwnershipTransferred(msg.sender, newOwner);
    }
}

// node_modules/solmate/src/tokens/ERC20.sol

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol)
/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
abstract contract ERC20 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    uint8 public immutable decimals;

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    /*//////////////////////////////////////////////////////////////
                            EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        balanceOf[msg.sender] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                             EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/

    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        public
        virtual
    {
        require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                value,
                                nonces[owner]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            require(recoveredAddress != address(0) && recoveredAddress == owner, "INVALID_SIGNER");

            allowance[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) internal virtual {
        totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        balanceOf[from] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }
}

// node_modules/solmate/src/utils/FixedPointMathLib.sol

/// @notice Arithmetic library with operations for fixed-point numbers.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/FixedPointMathLib.sol)
/// @author Inspired by USM (https://github.com/usmfum/USM/blob/master/contracts/WadMath.sol)
library FixedPointMathLib {
    /*//////////////////////////////////////////////////////////////
                    SIMPLIFIED FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant MAX_UINT256 = 2 ** 256 - 1;

    uint256 internal constant WAD = 1e18; // The scalar of ETH and most ERC20s.

    function mulWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, y, WAD); // Equivalent to (x * y) / WAD rounded down.
    }

    function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, y, WAD); // Equivalent to (x * y) / WAD rounded up.
    }

    function divWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, WAD, y); // Equivalent to (x * WAD) / y rounded down.
    }

    function divWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, WAD, y); // Equivalent to (x * WAD) / y rounded up.
    }

    /*//////////////////////////////////////////////////////////////
                    LOW LEVEL FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function mulDivDown(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Equivalent to require(denominator != 0 && (y == 0 || x <= type(uint256).max / y))
            if iszero(mul(denominator, iszero(mul(y, gt(x, div(MAX_UINT256, y)))))) { revert(0, 0) }

            // Divide x * y by the denominator.
            z := div(mul(x, y), denominator)
        }
    }

    function mulDivUp(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Equivalent to require(denominator != 0 && (y == 0 || x <= type(uint256).max / y))
            if iszero(mul(denominator, iszero(mul(y, gt(x, div(MAX_UINT256, y)))))) { revert(0, 0) }

            // If x * y modulo the denominator is strictly greater than 0,
            // 1 is added to round up the division of x * y by the denominator.
            z := add(gt(mod(mul(x, y), denominator), 0), div(mul(x, y), denominator))
        }
    }

    function rpow(uint256 x, uint256 n, uint256 scalar) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            switch x
            case 0 {
                switch n
                case 0 {
                    // 0 ** 0 = 1
                    z := scalar
                }
                default {
                    // 0 ** n = 0
                    z := 0
                }
            }
            default {
                switch mod(n, 2)
                case 0 {
                    // If n is even, store scalar in z for now.
                    z := scalar
                }
                default {
                    // If n is odd, store x in z for now.
                    z := x
                }

                // Shifting right by 1 is like dividing by 2.
                let half := shr(1, scalar)

                for {
                    // Shift n right by 1 before looping to halve it.
                    n := shr(1, n)
                } n {
                    // Shift n right by 1 each iteration to halve it.
                    n := shr(1, n)
                } {
                    // Revert immediately if x ** 2 would overflow.
                    // Equivalent to iszero(eq(div(xx, x), x)) here.
                    if shr(128, x) { revert(0, 0) }

                    // Store x squared.
                    let xx := mul(x, x)

                    // Round to the nearest number.
                    let xxRound := add(xx, half)

                    // Revert if xx + half overflowed.
                    if lt(xxRound, xx) { revert(0, 0) }

                    // Set x to scaled xxRound.
                    x := div(xxRound, scalar)

                    // If n is even:
                    if mod(n, 2) {
                        // Compute z * x.
                        let zx := mul(z, x)

                        // If z * x overflowed:
                        if iszero(eq(div(zx, x), z)) {
                            // Revert if x is non-zero.
                            if iszero(iszero(x)) { revert(0, 0) }
                        }

                        // Round to the nearest number.
                        let zxRound := add(zx, half)

                        // Revert if zx + half overflowed.
                        if lt(zxRound, zx) { revert(0, 0) }

                        // Return properly scaled zxRound.
                        z := div(zxRound, scalar)
                    }
                }
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        GENERAL NUMBER UTILITIES
    //////////////////////////////////////////////////////////////*/

    function sqrt(uint256 x) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            let y := x // We start y at x, which will help us make our initial estimate.

            z := 181 // The "correct" value is 1, but this saves a multiplication later.

            // This segment is to get a reasonable initial estimate for the Babylonian method. With a bad
            // start, the correct # of bits increases ~linearly each iteration instead of ~quadratically.

            // We check y >= 2^(k + 8) but shift right by k bits
            // each branch to ensure that if x >= 256, then y >= 256.
            if iszero(lt(y, 0x10000000000000000000000000000000000)) {
                y := shr(128, y)
                z := shl(64, z)
            }
            if iszero(lt(y, 0x1000000000000000000)) {
                y := shr(64, y)
                z := shl(32, z)
            }
            if iszero(lt(y, 0x10000000000)) {
                y := shr(32, y)
                z := shl(16, z)
            }
            if iszero(lt(y, 0x1000000)) {
                y := shr(16, y)
                z := shl(8, z)
            }

            // Goal was to get z*z*y within a small factor of x. More iterations could
            // get y in a tighter range. Currently, we will have y in [256, 256*2^16).
            // We ensured y >= 256 so that the relative difference between y and y+1 is small.
            // That's not possible if x < 256 but we can just verify those cases exhaustively.

            // Now, z*z*y <= x < z*z*(y+1), and y <= 2^(16+8), and either y >= 256, or x < 256.
            // Correctness can be checked exhaustively for x < 256, so we assume y >= 256.
            // Then z*sqrt(y) is within sqrt(257)/sqrt(256) of sqrt(x), or about 20bps.

            // For s in the range [1/256, 256], the estimate f(s) = (181/1024) * (s+1) is in the range
            // (1/2.84 * sqrt(s), 2.84 * sqrt(s)), with largest error when s = 1 and when s = 256 or 1/256.

            // Since y is in [256, 256*2^16), let a = y/65536, so that a is in [1/256, 256). Then we can estimate
            // sqrt(y) using sqrt(65536) * 181/1024 * (a + 1) = 181/4 * (y + 65536)/65536 = 181 * (y + 65536)/2^18.

            // There is no overflow risk here since y < 2^136 after the first branch above.
            z := shr(18, mul(z, add(y, 65536))) // A mul() is saved from starting z at 181.

            // Given the worst case multiplicative error of 2.84 above, 7 iterations should be enough.
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))

            // If x+1 is a perfect square, the Babylonian method cycles between
            // floor(sqrt(x)) and ceil(sqrt(x)). This statement ensures we return floor.
            // See: https://en.wikipedia.org/wiki/Integer_square_root#Using_only_integer_division
            // Since the ceil is rare, we save gas on the assignment and repeat division in the rare case.
            // If you don't care whether the floor or ceil square root is returned, you can remove this statement.
            z := sub(z, lt(div(x, z), z))
        }
    }

    function unsafeMod(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Mod x by y. Note this will return
            // 0 instead of reverting if y is zero.
            z := mod(x, y)
        }
    }

    function unsafeDiv(uint256 x, uint256 y) internal pure returns (uint256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            // Divide x by y. Note this will return
            // 0 instead of reverting if y is zero.
            r := div(x, y)
        }
    }

    function unsafeDivUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Add 1 to x * y if x % y > 0. Note this will
            // return 0 instead of reverting if y is zero.
            z := add(gt(mod(x, y), 0), div(x, y))
        }
    }
}

// node_modules/solmate/src/utils/SafeCastLib.sol

/// @notice Safe unsigned integer casting library that reverts on overflow.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/SafeCastLib.sol)
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeCast.sol)
library SafeCastLib {
    function safeCastTo248(uint256 x) internal pure returns (uint248 y) {
        require(x < 1 << 248);

        y = uint248(x);
    }

    function safeCastTo240(uint256 x) internal pure returns (uint240 y) {
        require(x < 1 << 240);

        y = uint240(x);
    }

    function safeCastTo232(uint256 x) internal pure returns (uint232 y) {
        require(x < 1 << 232);

        y = uint232(x);
    }

    function safeCastTo224(uint256 x) internal pure returns (uint224 y) {
        require(x < 1 << 224);

        y = uint224(x);
    }

    function safeCastTo216(uint256 x) internal pure returns (uint216 y) {
        require(x < 1 << 216);

        y = uint216(x);
    }

    function safeCastTo208(uint256 x) internal pure returns (uint208 y) {
        require(x < 1 << 208);

        y = uint208(x);
    }

    function safeCastTo200(uint256 x) internal pure returns (uint200 y) {
        require(x < 1 << 200);

        y = uint200(x);
    }

    function safeCastTo192(uint256 x) internal pure returns (uint192 y) {
        require(x < 1 << 192);

        y = uint192(x);
    }

    function safeCastTo184(uint256 x) internal pure returns (uint184 y) {
        require(x < 1 << 184);

        y = uint184(x);
    }

    function safeCastTo176(uint256 x) internal pure returns (uint176 y) {
        require(x < 1 << 176);

        y = uint176(x);
    }

    function safeCastTo168(uint256 x) internal pure returns (uint168 y) {
        require(x < 1 << 168);

        y = uint168(x);
    }

    function safeCastTo160(uint256 x) internal pure returns (uint160 y) {
        require(x < 1 << 160);

        y = uint160(x);
    }

    function safeCastTo152(uint256 x) internal pure returns (uint152 y) {
        require(x < 1 << 152);

        y = uint152(x);
    }

    function safeCastTo144(uint256 x) internal pure returns (uint144 y) {
        require(x < 1 << 144);

        y = uint144(x);
    }

    function safeCastTo136(uint256 x) internal pure returns (uint136 y) {
        require(x < 1 << 136);

        y = uint136(x);
    }

    function safeCastTo128(uint256 x) internal pure returns (uint128 y) {
        require(x < 1 << 128);

        y = uint128(x);
    }

    function safeCastTo120(uint256 x) internal pure returns (uint120 y) {
        require(x < 1 << 120);

        y = uint120(x);
    }

    function safeCastTo112(uint256 x) internal pure returns (uint112 y) {
        require(x < 1 << 112);

        y = uint112(x);
    }

    function safeCastTo104(uint256 x) internal pure returns (uint104 y) {
        require(x < 1 << 104);

        y = uint104(x);
    }

    function safeCastTo96(uint256 x) internal pure returns (uint96 y) {
        require(x < 1 << 96);

        y = uint96(x);
    }

    function safeCastTo88(uint256 x) internal pure returns (uint88 y) {
        require(x < 1 << 88);

        y = uint88(x);
    }

    function safeCastTo80(uint256 x) internal pure returns (uint80 y) {
        require(x < 1 << 80);

        y = uint80(x);
    }

    function safeCastTo72(uint256 x) internal pure returns (uint72 y) {
        require(x < 1 << 72);

        y = uint72(x);
    }

    function safeCastTo64(uint256 x) internal pure returns (uint64 y) {
        require(x < 1 << 64);

        y = uint64(x);
    }

    function safeCastTo56(uint256 x) internal pure returns (uint56 y) {
        require(x < 1 << 56);

        y = uint56(x);
    }

    function safeCastTo48(uint256 x) internal pure returns (uint48 y) {
        require(x < 1 << 48);

        y = uint48(x);
    }

    function safeCastTo40(uint256 x) internal pure returns (uint40 y) {
        require(x < 1 << 40);

        y = uint40(x);
    }

    function safeCastTo32(uint256 x) internal pure returns (uint32 y) {
        require(x < 1 << 32);

        y = uint32(x);
    }

    function safeCastTo24(uint256 x) internal pure returns (uint24 y) {
        require(x < 1 << 24);

        y = uint24(x);
    }

    function safeCastTo16(uint256 x) internal pure returns (uint16 y) {
        require(x < 1 << 16);

        y = uint16(x);
    }

    function safeCastTo8(uint256 x) internal pure returns (uint8 y) {
        require(x < 1 << 8);

        y = uint8(x);
    }
}

// src/Interfaces/IERC20.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// src/Interfaces/IIRM.sol

/**
 * @title Interest Rate Module Interface
 * @author Compound
 */
interface InterestRateModel {
    /**
     * @notice Calculates the current borrow interest rate per block
     * @param cash The total amount of cash the market has
     * @param borrows The total amount of borrows the market has outstanding
     * @param reserves The total amount of reserves the market has
     * @return The borrow rate per block (as a percentage, and scaled by 1e18)
     */
    function getBorrowRate(uint256 cash, uint256 borrows, uint256 reserves) external view returns (uint256);

    /**
     * @notice Calculates the current supply interest rate per block
     * @param cash The total amount of cash the market has
     * @param borrows The total amount of borrows the market has outstanding
     * @param reserves The total amount of reserves the market has
     * @param reserveFactorMantissa The current reserve factor the market has
     * @return The supply rate per block (as a percentage, and scaled by 1e18)
     */
    function getSupplyRate(uint256 cash, uint256 borrows, uint256 reserves, uint256 reserveFactorMantissa)
        external
        view
        returns (uint256);
}

// src/Interfaces/IPriceOracle.sol

/// @title Price Oracle Interface.
interface PriceOracle {
    /// @notice Get the price of an asset.
    /// @param asset The address of the underlying asset.
    /// @dev The underlying asset price is scaled by 1e18.
    function getUnderlyingPrice(address asset) external view returns (uint256);
}

// src/utils/MainStorage.sol

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

// node_modules/solmate/src/utils/SafeTransferLib.sol

/// @notice Safe ETH and ERC20 transfer library that gracefully handles missing return values.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// @dev Use with caution! Some functions in this library knowingly create dirty bits at the destination of the free memory pointer.
/// @dev Note that none of the functions in this library check that a token has code at all! That responsibility is delegated to the caller.
library SafeTransferLib {
    /*//////////////////////////////////////////////////////////////
                             ETH OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function safeTransferETH(address to, uint256 amount) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Transfer the ETH and store if it succeeded or not.
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }

        require(success, "ETH_TRANSFER_FAILED");
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function safeTransferFrom(ERC20 token, address from, address to, uint256 amount) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), and(from, 0xffffffffffffffffffffffffffffffffffffffff)) // Append and mask the "from" argument.
            mstore(add(freeMemoryPointer, 36), and(to, 0xffffffffffffffffffffffffffffffffffffffff)) // Append and mask the "to" argument.
            mstore(add(freeMemoryPointer, 68), amount) // Append the "amount" argument. Masking not required as it's a full 32 byte type.

            success :=
                and(
                    // Set success to whether the call reverted, if not we check it either
                    // returned exactly 1 (can't just be non-zero data), or had no return data.
                    or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                    // We use 100 because the length of our calldata totals up like so: 4 + 32 * 3.
                    // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                    // Counterintuitively, this call must be positioned second to the or() call in the
                    // surrounding and() call or else returndatasize() will be zero during the computation.
                    call(gas(), token, 0, freeMemoryPointer, 100, 0, 32)
                )
        }

        require(success, "TRANSFER_FROM_FAILED");
    }

    function safeTransfer(ERC20 token, address to, uint256 amount) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), and(to, 0xffffffffffffffffffffffffffffffffffffffff)) // Append and mask the "to" argument.
            mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument. Masking not required as it's a full 32 byte type.

            success :=
                and(
                    // Set success to whether the call reverted, if not we check it either
                    // returned exactly 1 (can't just be non-zero data), or had no return data.
                    or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                    // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
                    // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                    // Counterintuitively, this call must be positioned second to the or() call in the
                    // surrounding and() call or else returndatasize() will be zero during the computation.
                    call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
                )
        }

        require(success, "TRANSFER_FAILED");
    }

    function safeApprove(ERC20 token, address to, uint256 amount) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), and(to, 0xffffffffffffffffffffffffffffffffffffffff)) // Append and mask the "to" argument.
            mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument. Masking not required as it's a full 32 byte type.

            success :=
                and(
                    // Set success to whether the call reverted, if not we check it either
                    // returned exactly 1 (can't just be non-zero data), or had no return data.
                    or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                    // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
                    // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                    // Counterintuitively, this call must be positioned second to the or() call in the
                    // surrounding and() call or else returndatasize() will be zero during the computation.
                    call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
                )
        }

        require(success, "APPROVE_FAILED");
    }
}

// src/utils/PriceOracle.sol

// import {IERC20} from "../Interfaces/IERC20.sol";

abstract contract InternalPriceOracle {
    /// @notice Address of the price oracle contract.
    address public oracle;

    /// @notice Emitted when the price oracle is changed.
    /// @param user The authorized user who triggered the change.
    /// @param newOracle The new price oracle address.
    event OracleUpdated(address indexed user, address indexed newOracle);

    /// @notice Sets a new oracle contract.
    /// @param newOracle The address of the new oracle.
    function setOracle(address newOracle) external {
        // Update the oracle.
        oracle = newOracle;

        // Emit the event.
        emit OracleUpdated(msg.sender, newOracle);
    }

    /// @notice Gets the price of an asset.
    /// @param asset The underlying asset.
    function getAssetPrice(address asset) internal view returns (uint256) {
        return PriceOracle(oracle).getUnderlyingPrice(asset);
    }
}

// src/utils/Configuration.sol

abstract contract Configuration is MainStorage, Owned {
    using SafeCastLib for uint256;
    using FixedPointMathLib for uint256;

    function setMessageRelay(address relay) public onlyOwner {
        s_messageRelay = relay;
    }

    /*///////////////////////////////////////////////////////////////
                          INTEREST RATE CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets a new Interest Rate Model for a specfic asset.
    /// @param asset The underlying asset.
    /// @param newInterestRateModel The new IRM address.
    function setInterestRateModel(address asset, address newInterestRateModel) external onlyOwner {
        // Update the asset's Interest Rate Model.
        interestRateModels[asset] = newInterestRateModel;

        // Emit the event.
        emit InterestRateModelUpdated(msg.sender, asset, newInterestRateModel);
    }

    /// @notice Adds a new asset to the pool.
    /// @param asset The underlying asset.
    /// @param lendFactor The lend factor for the asset.
    /// @param borrowFactor The borrow factor for the asset.
    function configureAsset(
        address asset,
        uint256 lendFactor,
        uint256 borrowFactor // Configuration memory configuration
    ) external onlyOwner {
        // Ensure that this asset has not been configured.
        require(
            configurations[asset].borrowFactor == 0 && configurations[asset].lendFactor == 0, "ASSET_ALREADY_CONFIGURED"
        );

        Configuration memory configuration = Configuration(lendFactor, borrowFactor);

        configurations[asset] = configuration;
        baseUnits[asset] = 10 ** IERC20(asset).decimals();

        // Emit the event.
        emit AssetConfigured(asset, configuration);
    }

    /// @notice Updates the lend/borrow factors of an asset.
    /// @param asset The underlying asset.
    /// @param newConfiguration The new lend/borrow factors for the asset.
    function updateConfiguration(address asset, Configuration memory newConfiguration) external onlyOwner {
        // Update the asset configuration.
        configurations[asset] = newConfiguration;

        // Emit the event.
        emit AssetConfigurationUpdated(asset, newConfiguration);
    }

    /*///////////////////////////////////////////////////////////////
                      COLLATERALIZATION INTERFACE
    //////////////////////////////////////////////////////////////*/

    /// @notice Enable an asset as collateral.
    function enableAsset(address asset) public {
        _enableAsset(asset, msg.sender);
    }

    function _enableAsset(address asset, address depositor) internal {
        // Ensure the user has not enabled this asset as collateral.
        if (enabledCollateral[depositor][asset]) {
            return;
        }

        // Enable the asset as collateral.
        userCollateral[depositor].push(asset);
        enabledCollateral[depositor][asset] = true;

        // Emit the event.
        emit AssetEnabled(depositor, asset);
    }

    /// @notice Disable an asset as collateral.
    function disableAsset(address asset) public {
        _disableAsset(asset, msg.sender);
    }

    function _disableAsset(address asset, address depositor) internal {
        // Ensure that the user is not borrowing this asset.
        if (internalDebt[asset][depositor] > 0) return;

        // Ensure the user has already enabled this asset as collateral.
        if (!enabledCollateral[depositor][asset]) return;

        // Remove the asset from the user's list of collateral.
        for (uint256 i = 0; i < userCollateral[depositor].length; i++) {
            if (userCollateral[depositor][i] == asset) {
                // Copy the value of the last element in the array.
                address last = userCollateral[depositor][userCollateral[depositor].length - 1];

                // Remove the last element from the array.
                delete userCollateral[depositor][
                    userCollateral[depositor].length - 1
                ];

                // Replace the disabled asset with the new asset.
                userCollateral[depositor][i] = last;
            }
        }

        // Disable the asset as collateral.
        enabledCollateral[depositor][asset] = false;

        // Emit the event.
        emit AssetDisabled(depositor, asset);
    }
}

// src/utils/Accounting.sol

abstract contract Accounting is Configuration, InternalPriceOracle {
    using SafeCastLib for uint256;
    using FixedPointMathLib for uint256;

    /*///////////////////////////////////////////////////////////////
                        LIQUIDITY ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the total amount of underlying tokens held by and owed to the pool.
    /// @param asset The underlying asset.
    function totalUnderlying(address asset) public view returns (uint256) {
        // Return the total amount of underlying tokens in the pool.
        // This includes the LendingPool's currently held assets and all of the assets being borrowed.

        return availableLiquidity[asset] + totalBorrows(asset);
    }

    // /// @notice Returns the amount of underlying tokens held in this contract.
    // /// @param asset The underlying asset.
    // function availableLiquidity(address asset) public view returns (uint256) {
    //     // TODO: Return the LendingPool's underlying balance in the designated ERC4626 vault.
    //     // ERC4626 vault = vaults[asset];
    //     // return vault.convertToAssets(vault.balanceOf(address(this)));
    //     // return IERC20(asset).balanceOf(address(this));
    // }

    /*///////////////////////////////////////////////////////////////
                        BALANCE ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the underlying balance of an address.
    /// @param asset The underlying asset.
    /// @param user The user to get the underlying balance of.
    function balanceOf(address asset, address user) public view returns (uint256) {
        // Multiply the user's internal balance units by the internal exchange rate of the asset.

        return internalBalances[asset][user].mulDivDown(internalBalanceExchangeRate(asset), baseUnits[asset]);
    }

    /// @dev Returns the exchange rate between underlying tokens and internal balance units.
    /// In other words, this function returns the value of one internal balance unit, denominated in underlying.
    function internalBalanceExchangeRate(address asset) internal view returns (uint256) {
        // Retrieve the total internal balance supply.
        uint256 totalInternalBalance = totalInternalBalances[asset];

        // If it is 0, return an exchange rate of 1.
        if (totalInternalBalance == 0) return baseUnits[asset];

        // Otherwise, divide the total supplied underlying by the total internal balance units.
        return totalUnderlying(asset).mulDivDown(baseUnits[asset], totalInternalBalance);
    }

    /*///////////////////////////////////////////////////////////////
                          DEBT ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the underlying borrow balance of an address.
    /// @param asset The underlying asset.
    /// @param user The user to get the underlying borrow balance of.
    function borrowBalance(address asset, address user) public view returns (uint256) {
        // Multiply the user's internal debt units by the internal debt exchange rate of the asset.
        return internalDebt[asset][user].mulDivDown(internalDebtExchangeRate(asset), baseUnits[asset]);
    }

    /// @dev Returns the exchange rate between underlying tokens and internal debt units.
    /// In other words, this function returns the value of one internal debt unit, denominated in underlying.
    function internalDebtExchangeRate(address asset) internal view returns (uint256) {
        // Retrieve the total debt balance supply.
        uint256 totalInternalDebtUnits = totalInternalDebt[asset];

        // If it is 0, return an exchange rate of 1.
        if (totalInternalDebtUnits == 0) return baseUnits[asset];

        // Otherwise, divide the total borrowed underlying by the total amount of internal debt units.
        return totalBorrows(asset).mulDivDown(baseUnits[asset], totalInternalDebtUnits);
    }

    /*///////////////////////////////////////////////////////////////
                        INTEREST ACCRUAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the total amount of underlying tokens being loaned out to borrowers.
    /// @param asset The underlying asset.
    function totalBorrows(address asset) public view returns (uint256) {
        // Retrieve the Interest Rate Model for this asset.
        InterestRateModel interestRateModel = InterestRateModel(interestRateModels[asset]);

        // Ensure the IRM has been set.
        require(address(interestRateModel) != address(0), "INTEREST_RATE_MODEL_NOT_SET");

        // Calculate the LendingPool's current underlying balance.
        // We cannot use totalUnderlying() here, as it calls this function,
        // leading to an infinite loop.
        uint256 underlying = availableLiquidity[asset] + cachedTotalBorrows[asset];

        // Retrieve the per-block interest rate from the IRM.
        uint256 interestRate = interestRateModel.getBorrowRate(underlying, cachedTotalBorrows[asset], 0);

        // Calculate the block number delta between the last accrual and the current block.
        uint256 blockDelta = block.number - lastInterestAccrual[asset];

        // If the delta is equal to the block number (a borrow/repayment has never occured)
        // return a value of 0.
        if (blockDelta == block.number) return cachedTotalBorrows[asset];

        // Calculate the interest accumulator.
        uint256 interestAccumulator = interestRate.rpow(blockDelta, 1e18);

        // Accrue interest.
        return cachedTotalBorrows[asset].mulWadDown(interestAccumulator);
    }

    /// @dev Update the cached total borrow amount for a given asset.
    /// @param asset The underlying asset.
    function accrueInterest(address asset) internal {
        // Set the cachedTotalBorrows to the total borrow amount.
        cachedTotalBorrows[asset] = totalBorrows(asset);

        // Update the block number of the last interest accrual.
        lastInterestAccrual[asset] = block.number;
    }

    /*///////////////////////////////////////////////////////////////
                      BORROW ALLOWANCE CHECKS
    //////////////////////////////////////////////////////////////*/

    /// @dev Calculate the health factor of a user after a borrow occurs.
    /// @param asset The underlying asset.
    /// @param user The user to check.
    /// @param amount The amount of underlying to borrow.
    function calculateHealthFactor(address asset, address user, uint256 amount) public view returns (uint256) {
        // Allocate memory to store the user's account liquidity.
        AccountLiquidity memory liquidity;

        // Retrieve the user's utilized assets.
        address[] memory utilized = userCollateral[user];

        // User's hyptothetical borrow balance.
        uint256 hypotheticalBorrowBalance;

        address currentAsset;

        // Iterate through the user's utilized assets.
        for (uint256 i = 0; i < utilized.length; i++) {
            // Current user utilized asset.
            currentAsset = utilized[i];

            // Calculate the user's maximum borrowable value for this asset.
            // balanceOfUnderlying(asset,user) * ethPrice * collateralFactor.
            liquidity.maximumBorrowable += balanceOf(currentAsset, user).mulDivDown(
                getAssetPrice(currentAsset), baseUnits[currentAsset]
            ).mulDivDown(configurations[currentAsset].lendFactor, 1e18);

            // Check if current asset == underlying asset.
            hypotheticalBorrowBalance = currentAsset == asset ? amount : 0;

            // Calculate the user's hypothetical borrow balance for this asset.
            if (internalDebt[currentAsset][msg.sender] > 0) {
                hypotheticalBorrowBalance += borrowBalance(currentAsset, user);
            }

            // Add the user's borrow balance in this asset to their total borrow balance.
            liquidity.borrowBalance +=
                hypotheticalBorrowBalance.mulDivDown(getAssetPrice(currentAsset), baseUnits[currentAsset]);

            // Multiply the user's borrow balance in this asset by the borrow factor.
            liquidity.borrowBalancesTimesBorrowFactors += hypotheticalBorrowBalance.mulDivDown(
                getAssetPrice(currentAsset), baseUnits[currentAsset]
            ).mulWadDown(configurations[currentAsset].borrowFactor);
        }

        // Calculate the user's actual borrowable value.
        uint256 actualBorrowable = liquidity.borrowBalancesTimesBorrowFactors.divWadDown(liquidity.borrowBalance)
            .mulWadDown(liquidity.maximumBorrowable);

        // Return whether the user's hypothetical borrow value is
        // less than or equal to their borrowable value.
        return actualBorrowable.divWadDown(liquidity.borrowBalance);
    }

    /// @dev Identify whether a user is able to execute a borrow.
    /// @param asset The underlying asset.
    /// @param user The user to check.
    /// @param amount The amount of underlying to borrow.
    function canBorrow(address asset, address user, uint256 amount) internal view returns (bool) {
        // Ensure the user's health factor will be greater than 1.

        return calculateHealthFactor(asset, user, amount) >= 1e18;
    }

    /// @dev Given user's collaterals, calculate the maximum user can borrow.
    function maxBorrowable() external view returns (uint256 maximumBorrowable) {
        // Retrieve the user's utilized assets.
        address[] memory utilized = userCollateral[msg.sender];

        address currentAsset;

        // Iterate through the user's utilized assets.
        for (uint256 i = 0; i < utilized.length; i++) {
            // Current user utilized asset.
            currentAsset = utilized[i];

            // Calculate the user's maximum borrowable value for this asset.
            // balanceOfUnderlying(asset,user) * ethPrice * lendFactor.
            maximumBorrowable += balanceOf(currentAsset, msg.sender).mulDivDown(
                getAssetPrice(currentAsset), baseUnits[currentAsset]
            ).mulDivDown(configurations[currentAsset].lendFactor, 1e18);
        }
    }

    /// @dev Get all user collateral assets.
    /// @param user The user.
    function getCollateral(address user) external view returns (address[] memory) {
        return userCollateral[user];
    }

    /*///////////////////////////////////////////////////////////////
                          LIQUIDATION INTERFACE
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns a boolean indicating whether a user is liquidatable.
    /// @param user The user to check.
    function userLiquidatable(address user) public view returns (bool) {
        // Call canBorrow(), passing in a non-existant asset and a borrow amount of 0.
        // This will just check the contract's current state.

        return !canBorrow(address(address(0)), user, 0);
    }

    /// @dev Calculates the total amount of collateral tokens to be seized on liquidation.
    /// @param borrowedAsset The asset borrowed.
    /// @param collateralAsset The asset used as collateral.
    /// @param repayAmount The amount being repaid.
    function seizeCollateral(address borrowedAsset, address collateralAsset, uint256 repayAmount)
        public
        view
        returns (uint256)
    {
        return 0;
    }
}

// src/LendingPool.sol

contract LendingPool is Accounting {
    using SafeTransferLib for IERC20;
    using SafeCastLib for uint256;
    using FixedPointMathLib for uint256;

    // TODO: Make everything non-reentrant

    constructor(address owner, address messageRelay) Owned(owner) {
        s_messageRelay = messageRelay;
    }

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
    function deposit(address asset, uint256 amount, bool enable) external {
        _deposit(asset, amount, msg.sender, enable);

        // Transfer underlying in from the user.
        IERC20(asset).transferFrom(msg.sender, address(this), amount);

        // Emit the event.
        emit Deposit(msg.sender, asset, amount, enable);
    }

    /// @notice Handle the deposit event passed from the Source Chain by the Message Relay.
    function handleCrossChainDeposit(address asset, uint256 amount, address depositor, bool enable)
        external
        onlyMessageRelay
    {
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

    /// @notice Withdraw underlying tokens from the pool.
    /// @param asset The underlying asset.
    /// @param amount The amount to be withdrawn.
    /// @param disable A boolean indicating whether to disable the underlying asset as collateral.
    function withdraw(address asset, uint256 amount, bool disable) external {
        _withdraw(asset, amount, msg.sender, disable);

        // Transfer underlying to the user.
        IERC20(asset).transfer(msg.sender, amount);

        // Emit the event.
        emit Withdraw(msg.sender, asset, amount, disable);
    }

    /// @notice Handle the withdrawal event passed from the Source Chain by the Message Relay.
    function handleCrossChainWithdrawal(address asset, uint256 amount, address depositor, bool disable)
        external
        onlyMessageRelay
    {
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
    function borrow(address asset, uint256 amount) external {
        _borrow(asset, amount, msg.sender);

        // Transfer tokens to the borrower.
        IERC20(asset).transfer(msg.sender, amount);

        // Emit the event.
        emit Borrow(msg.sender, asset, amount);
    }

    /// @notice Handle the borrow event passed from the Source Chain by the Message Relay.
    function handleCrossChainBorrow(address asset, uint256 amount, address depositor) external onlyMessageRelay {
        _borrow(asset, amount, depositor);
    }

    function _borrow(address asset, uint256 amount, address depositor) internal {
        // Ensure the amount is valid.
        require(amount > 0, "AMOUNT_TOO_LOW");

        // Accrue interest.
        // TODO: is this the right place to accrue interest?
        accrueInterest(asset);

        // Enable the asset, if it is not already enabled.
        enableAsset(asset);

        // Ensure the caller is able to execute this borrow.
        require(canBorrow(asset, depositor, amount));

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

    /// @notice Repay underlying tokens to the pool.
    /// @param asset The underlying asset.
    /// @param amount The amount to repay.
    function repay(address asset, uint256 amount) external {
        _repay(asset, amount, msg.sender);

        // Transfer tokens from the user.
        IERC20(asset).transferFrom(msg.sender, address(this), amount);

        // Emit the event.
        emit Repay(msg.sender, asset, amount);
    }

    /// @notice Handle the repay event passed from the Source Chain by the Message Relay.
    function handleCrossChainRepay(address asset, uint256 amount, address depositor) external onlyMessageRelay {
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
        // TODO: is this the right place to accrue interest?
        accrueInterest(asset);

        // Update the cached debt of the asset.
        cachedTotalBorrows[asset] -= amount;
    }

    // TODO: Periodicaly check the liquidity available on both chains and update the availableLiquidity storage variable

    /*///////////////////////////////////////////////////////////////
                          LIQUIDATION INTERFACE
    //////////////////////////////////////////////////////////////*/

    // TODO: Figure out and Test liquidatio Logic
    function liquidateUser(address borrowedAsset, address collateralAsset, address borrower, uint256 repayAmount)
        external
    {
        require(userLiquidatable(borrower), "CANNOT_LIQUIDATE_HEALTHY_USER");

        // Calculate the number of collateral asset to be seized
        uint256 seizedCollateralAmount = seizeCollateral(borrowedAsset, collateralAsset, repayAmount);

        // Assert user health factor is == MAX_HEALTH_FACTOR
        require(calculateHealthFactor(borrowedAsset, borrower, 0) == MAX_HEALTH_FACTOR, "NOT_HEALTHY");
    }
}
