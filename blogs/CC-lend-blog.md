# Crosschain lending enabled by State connector

### Introduction

The rapid expansion of decentralized finance (DeFi) has underscored the need for interoperability among diverse blockchain networks. Cross-chain lending protocols, which enable seamless asset lending and borrowing across different blockchains, are at the forefront of this innovation. Flare Network, with its robust State Connector protocol and Flare Time Series Oracle, provides a powerful solution for implementing these cross-chain lending mechanisms. By leveraging Flare's State Connector and Time Series Oracle, we can create secure and efficient lending protocols that bridge assets from multiple chains, enhancing liquidity and user accessibility in the DeFi ecosystem. In this blog, we will delve into the step-by-step process of implementing a cross-chain lending protocol using Flare's State Connector and Time Series Oracle, highlighting its advantages and practical applications.

### About Flare

Flare is Layer 1 EVM-based blockchain for developers to build on. Flare, being a data-focused network, currently has two core data acquisition protocols: the State Connector and Flare Time Series Oracle (FTSO). FTSO provides decentralized on-chain price data, and the State Connector provides data from other chains. Furthermore, Flare offers developers four networks: Flare (main network) and Songbird (canary network), with both having public test networks called Coston and Coston2. All our source code repositories are [public](https://github.com/flare-foundation/).

### What is State Connector?

The cross-chain lending solution presented in this demo is built on top of State Connector. The application leverages the State Connector's ability to query data from other blockchains outside of Flare, enabling seamless asset transfers and lending operations across multiple chains. The process is decentralized, secure, and cost-effective, with independent attestation providers transferring information from other blockchains to Flare. When the State Connector smart contract confirms the required consensus among the provided information, the data is successfully transferred, facilitating the lending transaction. Flare's State Connector eliminates the need for all participants to operate on the same blockchain, removing utility barriers and streamlining the process. This innovation provides a competitive advantage for dApps and other financial products built on Flare by enhancing interoperability and efficiency in the DeFi ecosystem.

You can learn more about the State Connector system [here](https://docs.flare.network/tech/state-connector/).

### What is Flare time series oracle (FTSO)

The cross-chain lending solution presented in this demo also leverages the Flare Time Series Oracle (FTSO). FTSO provides decentralized, real-time data feeds from external sources, which are crucial for determining accurate and up-to-date asset prices. This process is secure, reliable, and cost-effective, utilizing independent data providers to gather and validate information. When the FTSO smart contract provides price feed data, it ensures the integrity and accuracy of the information used in lending transactions. By integrating FTSO, Flare eliminates the need for centralized oracles, reducing risk and enhancing the reliability of price data. This capability offers a competitive edge to dApps and financial products built on Flare, as it ensures real-time, accurate data for seamless lending activities.

You can learn more about the Flare Time Series Oracle [here](https://flare.network/ftso/).

### Dapp Architecture

We are using [Nextjs](https://nextjs.org/) and [React](https://react.dev/) with [Typescript](https://www.typescriptlang.org/) for frontend, [MantineUI](https://mantine.dev/) for UI components and [Foundry](https://book.getfoundry.sh/) for Solidity development environment.

The entire code for the application is available on the [**main github repo**](https://git.aflabs.org/flare-external/flare-demos-general), all smart contracts are available on the [**smart contract github repo**](https://github.com/505-solutions/cc-lend).

To bootstrap your Flare development journey you can use [Flare Hardhat starter](https://github.com/flare-foundation/flare-hardhat-starter) for Hardhat or [Flare Foundry starter](https://github.com/flare-foundation/flare-foundry-starter). For the purpose of this demo we will use Foundry.

The initial steps are straightforward. We set up the folder structure, initial components and install all the necessary packages. Wallet connection is handled by [WalletConnect](https://walletconnect.com/) and we use [typechain-ethers](https://www.npmjs.com/search?q=typechain-ethers) package for type-safe interactions with smart contracts. Communication with the State Connector verifiers and attestation clients is achieved through [OpenAPI](https://swagger.io/specification/) specification and we use [swagger-typescript-api](https://www.npmjs.com/package/swagger-typescript-api) package to appropriate type-signatures for the client.


### Lending

In a cross-chain lending scenario on Flare, a user provides collateral in ETH on the Ethereum blockchain. This ETH is securely locked in a smart contract on Ethereum, and in return, the user receives an equivalent amount of USDC on the Flare network. This process allows the user to leverage their ETH assets to obtain liquidity in USDC without selling their ETH. When the user is ready to repay the loan, they send the borrowed USDC to a designated Flare smart contract. Upon receiving the repayment, the smart contract triggers the release of the collateralized ETH on Ethereum, returning it to the user's wallet. This seamless cross-chain lending mechanism ensures that users can access liquidity across different blockchains in a decentralized and efficient manner.

The lending process can be broken down in steps:

- Providing collateral in ETH on Ethereum
- Relaying the transaction with collateral from Ethereum to Flare
- Receiving USDC loan from Flare smart contract
- Repaying the loan on Flare
- Unlocking collateral on Ethereum

### Collateral provision

Since most of modern DeFi systems work with ERC20 tokens we deploy 4 different mock ERC20 tokens on both Ethereum testnet Sepolia and Flare testnet Coston for test wrapped ETH (TWETH) and test USDC (TUSDC). We display balances of **sepoliaTWETH**, **sepoliaTUSDC**, **costonTWETH**, **costonTUSDC** on the frontend using `balanceOf` ERC20 function. Since all the tokens are mock tokens we allow user to mint them infinitely.

To provide collateral we ensure that we have selected Sepolia in the network tab and call `LendingPool.deposit` function.

```typescript
const tx: ethers.ContractTransaction = await depositCollateral(
  account,
  provider,
  collateral,
  chainId
);
const receipt: any = await tx.wait();
const event: DelegatedEventObject = receipt.events.filter(
  (e: any) => e?.event === "Deposit"
)[0].args;
setAttestTransaction(tx.hash);
```

We record the transaction hash to relay the transaction to Flare.

### <a id="relayingTx"></a> Relaying the transaction with collateral from Ethereum to Flare

Firstly we have to create attestation request. We use one of the State connector verifiers. We achieve this with an API call to `{{VERIFIER_URL}}/verifier/eth/EVMTransaction/prepareRequest` with parameters:

```json
{
  // EVM transaction
  "attestationType": "0x45564d5472616e73616374696f6e000000000000000000000000000000000000",
  // Sepolia
  "sourceId": "0x7465737445544800000000000000000000000000000000000000000000000000",
  "requestBody": {
    "transactionHash": "0xf032f6a100f3f7ef25428ea68621272d059c21cb52d5c62e3a3bd0e6afdc69a3",
    "requiredConfirmations": "0",
    "provideInput": true,
    "listEvents": true,
    // Extract all events
    "logIndices": []
  }
}
```

The response we get contains `abiEncodedRequest` — binary request for attestation. The encoded request contains data about the required transaction together with a message integrity check, that forces the attestation clients check the correctness of the transaction information.

```json
{
  "status": "VALID",
  "abiEncodedRequest": "0x45564d5472616e73616374696f6e0000000000000000000000000000000000007465737445544800000000000000000000000000000000000000000000000000d68cf10e63f7a8b10ec08f8e77429f3b2e14df77e5cab9cd8b39b9438960bc270000000000000000000000000000000000000000000000000000000000000020f032f6a100f3f7ef25428ea68621272d059c21cb52d5c62e3a3bd0e6afdc69a300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000000"
}
```

We use `abiEncodedRequest` from earlier to request attestation on Coston [**State Connector contract**](https://coston-explorer.flare.network/address/0x0c13aDA1C7143Cf0a0795FFaB93eEBb6FAD6e4e3) by calling `requestAttestations(abiEncodedRequest)`. This will let the entire set of attestation providers know, that we wish to have a proof that the transaction with all attached data such as hash, transmitted events, block id etc. has happened on Ethereum.

In the State Connector requests and answers are submitted sequentially in attestation rounds. Each attestation round has 4 consecutive phases called Collect, Choose, Commit and Reveal. You can learn more about Flare’s CCCR (Collect, Choose, Commit, Reveal) protocol [here](https://docs.flare.network/tech/state-connector/). Once we request attestation our request is part of a specific round numbered with `roundId`. RoundId is calculated based on the timestamp of the block in which attestation request contract call is made.

Next, you have to wait 6 minutes during which the attestation providers verify the validity of the transaction on their own nodes and vote on which transactions are valid (consensus). If our transaction is marked as valid by votes it is included in the Merkle tree for that round. When the round has been finalized, Merkle root for that round gets submitted and stored in State Connector smart contract.

After the round in which we requested attestation has been finalised we are ready to retrieve our Merkle proof that we will use to prove the validity of our ETH transaction. Each attestation provider holds a copy of the entire merkle tree for the round and is thus able to produce Merkle proof for each specific transaction. We retrieve the Merkle proof by calling `/attestation-client/api/proof/get-specific-proof` with the calldata from before:

```json
{
  "roundId": 689667,
  "requestBytes": "0x45564d5472616e73616374696f6e0000000000000000000000000000000000007465737445544800000000000000000000000000000000000000000000000000d68cf10e63f7a8b10ec08f8e77429f3b2e14df77e5cab9cd8b39b9438960bc270000000000000000000000000000000000000000000000000000000000000020f032f6a100f3f7ef25428ea68621272d059c21cb52d5c62e3a3bd0e6afdc69a300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000000"
}
```

If everything goes as expected, the attestation provider response JSON should contain `merkleProof` that cryptographically proves that the hash of our Payment struct is indeed present in this round’s Merkle tree. The response should also contain the list of EVM `events` that the transaction has emitted. Here is the structure of the expected JSON response:

```json
{
  "status": "OK",
  "data": {
    "roundId": 878923,
    "hash": "0x740bbb3b2ada5811e1f54dd17f036530248ad8b3cc5b3132109996cce4053023",
    "requestBytes": "0x45564d5472616e73616374696f6e00000000000000000000000000000000000074657374455448000000000000000000000000000000000000000000000000003c6780e666a894cd4d16299192168fcf5000e22cb38f138051f36ee3d5660a1c000000000000000000000000000000000000000000000000000000000000002046d6fdce170a5698ad93c8b6ae178e75d1cede5d97c2cea0f556c3e3b9dad83f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000000",
    "request": {
      "attestationType": "0x45564d5472616e73616374696f6e000000000000000000000000000000000000",
      "messageIntegrityCode": "0x3c6780e666a894cd4d16299192168fcf5000e22cb38f138051f36ee3d5660a1c",
      "requestBody": {
        "listEvents": true,
        "logIndices": [],
        "provideInput": true,
        "requiredConfirmations": "0",
        "transactionHash": "0x46d6fdce170a5698ad93c8b6ae178e75d1cede5d97c2cea0f556c3e3b9dad83f"
      },
      "sourceId": "0x7465737445544800000000000000000000000000000000000000000000000000"
    },
    "response": {
      "attestationType": "0x45564d5472616e73616374696f6e000000000000000000000000000000000000",
      "lowestUsedTimestamp": "1715173488",
      "requestBody": {
        "listEvents": true,
        "logIndices": [],
        "provideInput": true,
        "requiredConfirmations": "0",
        "transactionHash": "0x46d6fdce170a5698ad93c8b6ae178e75d1cede5d97c2cea0f556c3e3b9dad83f"
      },
      "responseBody": {
        "blockNumber": "5861276",
        "events": [
          {
            "data": "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000",
            "emitterAddress": "0x65d6a4ee7b2a807993b7014247428451aE11a471",
            "logIndex": "151",
            "removed": false,
            "topics": [
              "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
              "0x000000000000000000000000fa8166634569537ea716b7350383ab262335994e",
              "0x00000000000000000000000084bcb82a356d45d5c6bd91857aa6a3e933fa82a5"
            ]
          },
          {
            "data": "0x00000000000000000000000065d6a4ee7b2a807993b7014247428451ae11a4710000000000000000000000000000000000000000000000000de0b6b3a76400000000000000000000000000000000000000000000000000000000000000000001",
            "emitterAddress": "0x84bcB82A356d45D5c6BD91857aA6a3E933Fa82a5",
            "logIndex": "152",
            "removed": false,
            "topics": [
              "0xdd160bb401ec5b5e5ca443d41e8e7182f3fe72d70a04b9c0ba844483d212bcb5",
              "0x000000000000000000000000fa8166634569537ea716b7350383ab262335994e"
            ]
          }
        ],
        "input": "0x3edd112800000000000000000000000065d6a4ee7b2a807993b7014247428451ae11a4710000000000000000000000000000000000000000000000000de0b6b3a76400000000000000000000000000000000000000000000000000000000000000000001",
        "isDeployment": false,
        "receivingAddress": "0x84bcB82A356d45D5c6BD91857aA6a3E933Fa82a5",
        "sourceAddress": "0xFA8166634569537ea716b7350383Ab262335994E",
        "status": "1",
        "timestamp": "1715173488",
        "value": "0"
      },
      "sourceId": "0x7465737445544800000000000000000000000000000000000000000000000000",
      "votingRound": "878923"
    },
    "merkleProof": [
      "0x8d5501189ce53aa0c716a1421d2a7db590d5c23b5a2348c1937c0cdf6dd00e2c",
      "0xdd27985c63d21b20f05877ce6213dda2d736f75e8941171cf60a4ec11a62809a",
      "0xaf899e7405d671554f1891d0e2e425b070b1649372d26dabb60c44cfd8080f52"
    ]
  }
}
```

### Receiving USDC loan from smart contract on Flare

### Relaying Messages Using the Flare State Connector

When an action occurs on a source network, we need to relay this information to the destination network to maintain the shared state and take appropriate actions based on this data. In our example, this means a user can lock up collateral on Ethereum and borrow funds against this collateral on Flare. Using the information described in the [previous step](#relayingTx) , we can obtain an attestation proof for this transaction from the state connector. This proof updates the state of the system on Flare, proving the collateral is locked on Ethereum. To relay this proof, we use the `MessageRelay.sol` contract, which verifies the proof, decodes and parses the information, and then updates the system's state.

Now, let's examine the code to understand how this works. Anyone can obtain the proof from the `State Connector` and call the `verifyCrossChainAction` function on our `MessageRelay` contract. This function first ensures the proof has not been previously verified to prevent exploits. We then call Flare's `evmTxVerifier` to verify the inclusion of our transaction in the Merkle state root. Once the proof is validated, we extract the events of that transaction stored in `_proof.data.responseBody.events`.

```js
function verifyCrossChainAction(EVMTransaction.Proof calldata _proof) external {
        if (s_processedTxHashes[_proof.data.requestBody.transactionHash]) revert TxAlreadyProcessed();

        // Verify the merkle proof against using the tx verifier
        bool valid = s_evmTxVerifier.verifyEVMTransaction(_proof);
        if (!valid) {
            revert InvalidProof();
        }

        EVMTransaction.Event calldata _event = _proof.data.responseBody.events[1];

        s_processedTxHashes[_proof.data.requestBody.transactionHash] = true;

        ...
```

<br>

There are four events we care about: `Deposit`, `Withdrawal`, `Borrow`, and `Repay`. In Solidity, the first topic of an event is the hash of the event selector. To determine which action we are relaying, we use the following code. We also need to decode all other fields of the event as shown below. For reference, in Solidity, event fields that are indexed are stored in topics for easier indexing, whereas other fields are ABI-encoded and stored in `event.data`. Once we have all the necessary fields, the `MessageRelay` contract will call the `LendingPool` contract to update the state, meaning your collateral deposit on Ethereum is recognised, and you can borrow against it on Flare.

```js
        ...

        if (_event.topics[0] == keccak256("Deposit(address,address,uint256,bool)")) {
            // DEPOSIT

            address depositor = address(uint160(uint256(_event.topics[1])));
            (address asset, uint256 amount, bool enable) = abi.decode(_event.data, (address, uint256, bool));

            s_lendingPool.handleCrossChainDeposit(asset, amount, depositor, enable);

        } else if (_event.topics[0] == keccak256("Withdraw(address,address,uint256,bool)")) {
            // WITHDRAWAL

            address depositor = address(uint160(uint256(_event.topics[1])));
            (address asset, uint256 amount, bool disable) = abi.decode(_event.data, (address, uint256, bool));

            s_lendingPool.handleCrossChainWithdrawal(asset, amount, depositor, disable);

        } else if (_event.topics[0] == keccak256("Borrow(address,address,uint256)")) {
            // BORROW

            ...

        } else if (_event.topics[0] == keccak256("Repay(address,address,uint256)")) {
            // REPAY

            ...

        } else {
            revert InvalidMessageType();
        }
    }
```

### Using FTSO to calculate price conversion

We allow users to borrow 90% of the locked collateral value. We use FTSO to get up-to-date price of ETH in USD so that our smart contract can provide sufficient amount of USDC. To get the price of an asset in the current timeframe we call `getCurrentPriceWithDecimals` on FTSO smart contract.

```js
function getAssetPrice(address asset) public view returns (uint256 assetPriceInEth) {
        uint256 ftsoIndex = s_assetFtsoIndex[asset];

        uint256 ethFtsoIndex = s_assetFtsoIndex[s_wethAddress];
        if (ftsoIndex == ethFtsoIndex) {
            return 1e18;
        } else {
            (uint256 ethPrice,, uint256 ethAssetPriceUsdDecimals) =
                IFtsoRegistry(oracleSource).getCurrentPriceWithDecimals(ethFtsoIndex);

            if (ftsoIndex == 0) {
                // ! Stablecoin

                assetPriceInEth = (1e18 * 10 ** ethAssetPriceUsdDecimals) / (ethPrice);
            } else {
                // ! Other assets

                (uint256 price,, uint256 assetPriceUsdDecimals) =
                    IFtsoRegistry(oracleSource).getCurrentPriceWithDecimals(ftsoIndex);

                // Price in eth = (asset_P /  eth_P) * 1e18
                assetPriceInEth =
                    (price * 1e18 * 10 ** ethAssetPriceUsdDecimals) / (ethPrice * 10 ** assetPriceUsdDecimals);
            }
        }
    }
  ```

### Repaying the loan on Flare

Once we are ready to repay the loan we call `repay` function on the Flare smart contract. The contract than records that the loan has been repayed and allows us to release collateral on Ethereum.

### Unlocking collateral on Ethereum

TODO: relaying transactions from Flare to ETH not yet supported

### Conclusion

In this blog, we implemented a cross-chain lending protocol utilizing Flare Network's State Connector and Flare Time Series Oracle (FTSO). The integration of these components allowed us to create a decentralized, secure, and efficient lending mechanism that bridges assets across different blockchains. By leveraging the State Connector, we enabled the transfer and validation of data between Ethereum and Flare, facilitating seamless collateralization and lending processes. The FTSO provided real-time, decentralized price data, ensuring accurate asset valuations within our protocol. Through the step-by-step guide, we explored the architecture, collateral provision, transaction relaying, and message verification processes essential for cross-chain lending. Ultimately, this approach enhances the interoperability and liquidity in the DeFi ecosystem, showcasing Flare's capability to power next-generation decentralized applications.
