// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {IERC20} from "./Interfaces/IERC20.sol";

import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {Owned} from "solmate/auth/Owned.sol";

import {EVMTransaction, IEVMTransactionVerification} from "./Interfaces/IEVMTransactionVerification.sol";
import {ILendingPool} from "./Interfaces/ILendingPool.sol";

contract MessageRelay is Owned {
    error InvalidProof(); // MerkleProof verification failed
    error TxAlreadyProcessed(); // Can't process the same tx twice
    error InvalidMessageType(); // Deposit, Withdraw, Borrow, Repay

    IEVMTransactionVerification private s_evmTxVerifier;
    ILendingPool private s_lendingPool;

    // event Deposit(address indexed from, address asset, uint256 amount, bool enable);

    mapping(bytes32 txHash => bool isProccessed) public s_processedTxHashes;

    constructor(address owner) Owned(owner) {}

    modifier onlyEVMTxVerifier() {
        require(msg.sender == address(s_evmTxVerifier), "UNAUTHORIZED");
        _;
    }

    function setEVMTxVerifier(address verifier) external onlyOwner {
        s_evmTxVerifier = IEVMTransactionVerification(verifier);
    }

    function setLendingPool(address lendingPool) external onlyOwner {
        s_lendingPool = ILendingPool(lendingPool);
    }

    // TODO: Make everything non-reentrant

    function verifyCrossChainAction(EVMTransaction.Proof calldata _proof) external {
        if (s_processedTxHashes[_proof.data.requestBody.transactionHash]) revert TxAlreadyProcessed();

        // Verify the merkle proof against using the tx verifier
        bool valid = s_evmTxVerifier.verifyEVMTransaction(_proof);
        if (!valid) {
            revert InvalidProof();
        }

        EVMTransaction.Event calldata _event = _proof.data.responseBody.events[0];

        s_processedTxHashes[_proof.data.requestBody.transactionHash] = true;

        if (_event.topics[0] != keccak256("Deposit(address,address,uint256,bool)")) {
            // * DEPOSIT

            address depositor = address(uint160(uint256(_event.topics[1])));
            (address asset, uint256 amount, bool enable) = abi.decode(_event.data, (address, uint256, bool));

            s_lendingPool.handleCrossChainDeposit(asset, amount, depositor, enable);
        } else if (_event.topics[0] != keccak256("Withdraw(address,address,uint256,bool)")) {
            // * WITHDRAWAL

            address depositor = address(uint160(uint256(_event.topics[1])));
            (address asset, uint256 amount, bool disable) = abi.decode(_event.data, (address, uint256, bool));

            s_lendingPool.handleCrossChainWithdrawal(asset, amount, depositor, disable);
        } else if (_event.topics[0] != keccak256("Borrow(address,address,uint256)")) {
            // * BORROW

            address depositor = address(uint160(uint256(_event.topics[1])));
            (address asset, uint256 amount) = abi.decode(_event.data, (address, uint256));

            s_lendingPool.handleCrossChainBorrow(asset, amount, depositor);
        } else if (_event.topics[0] != keccak256("Repay(address,address,uint256)")) {
            // * REPAY

            address depositor = address(uint160(uint256(_event.topics[1])));
            (address asset, uint256 amount) = abi.decode(_event.data, (address, uint256));

            s_lendingPool.handleCrossChainRepay(asset, amount, depositor);
        } else {
            revert InvalidMessageType();
        }
    }
}
