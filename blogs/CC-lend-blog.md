# Crosschain lending enabled by State connector

### Introduction

The rapid expansion of decentralized finance (DeFi) has underscored the need for interoperability among diverse blockchain networks. Cross-chain lending protocols, which enable seamless asset lending and borrowing across different blockchains, are at the forefront of this innovation. Flare Network, with its robust State Connector protocol and Time Series Oracle, provides a powerful solution for implementing these cross-chain lending mechanisms. By leveraging Flare's State Connector and Time Series Oracle, developers can create secure and efficient lending protocols that bridge assets from multiple chains, enhancing liquidity and user accessibility in the DeFi ecosystem. In this blog, we will delve into the step-by-step process of implementing a cross-chain lending protocol using Flare's State Connector and Time Series Oracle, highlighting its advantages and practical applications.

### About Flare

Flare is Layer 1 EVM-based blockchain for developers to build on. Flare, being a data-focused network, currently has two core data acquisition protocols: the State Connector and Flare Time Series Oracle (FTSO). FTSO provides decentralized on-chain price data, and the State Connector provides data from other chains. Furthermore, Flare offers developers four networks: Flare (main network) and Songbird (canary network), with both having public test networks called Coston and Coston2. All our source code repositories are [public](https://github.com/flare-foundation/).

### What is State Connector?

The cross-chain lending solution presented in this demo is built on top of State Connector. This protocol leverages the State Connector's ability to query data from other blockchains outside of Flare, enabling seamless asset transfers and lending operations across multiple chains. The process is decentralized, secure, and cost-effective, with independent attestation providers transferring information from other blockchains to Flare. When the State Connector smart contract confirms the required consensus among the provided information, the data is successfully transferred, facilitating the lending transaction. Flare's State Connector eliminates the need for all participants to operate on the same blockchain, removing utility barriers and streamlining the process. This innovation provides a competitive advantage for dApps and other financial products built on Flare by enhancing interoperability and efficiency in the DeFi ecosystem.

You can learn more about the State Connector system [here](https://docs.flare.network/tech/state-connector/).

### What is Flare time series oracle (FTSO)

The cross-chain lending solution presented in this demo also leverages the Flare Time Series Oracle (FTSO). FTSO provides decentralized, real-time data feeds from external sources, which are crucial for determining accurate and up-to-date asset prices. This process is secure, reliable, and cost-effective, utilizing independent data providers to gather and validate information. When the FTSO smart contract confirms the provided data, it ensures the integrity and accuracy of the information used in lending transactions. By integrating FTSO, Flare eliminates the need for centralized oracles, reducing risk and enhancing the reliability of cross-chain operations. This capability offers a competitive edge to dApps and financial products built on Flare, as it ensures real-time, accurate data for seamless lending activities.

You can learn more about the Flare Time Series Oracle [here](https://flare.network/ftso/).

### Dapp Architecture

We are using [Nextjs](https://nextjs.org/) and [React](https://react.dev/) with [Typescript](https://www.typescriptlang.org/) for frontend, [MantineUI](https://mantine.dev/) for UI components and [Foundry](https://book.getfoundry.sh/) for Solidity development environment.

The entire code for the application is available on the [**main github repo**](https://git.aflabs.org/flare-external/flare-demos-general), all smart contracts are available on the [**smart contract github repo**](https://github.com/505-solutions/identity-link-contracts/tree/luka-develop).

To bootstrap your Flare development journey you can use [Flare Hardhat starter](https://github.com/flare-foundation/flare-hardhat-starter) for Hardhat or [Flare Foundry starter](https://github.com/flare-foundation/flare-foundry-starter). For the purpose of this demo we will use Foundry.

The initial steps are straightforward. We set up the folder structure, initial components and install all the necessary packages. Wallet connection is handled by [WalletConnect](https://walletconnect.com/) and we use [typechain-ethers](https://www.npmjs.com/search?q=typechain-ethers) package for type-safe interactions with smart contracts. Communication with the State Connector verifiers and attestation clients is achieved through [OpenAPI](https://swagger.io/specification/) specification and we use [swagger-typescript-api](https://www.npmjs.com/package/swagger-typescript-api) package to appropriate type-signatures for the client.

TODO: Manjka: Smart contracts

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

To provide collateral we ensure that we select Sepolia in the network tab and call `LendingPool.deposit` function.

```typescript
const tx: ethers.ContractTransaction = await depositCollateral(
    account,
    provider,
    collateral,
    chainId,
);
const receipt: any = await tx.wait();
const event: DelegatedEventObject = receipt.events.filter(
    (e: any) => e?.event === "Deposit",
)[0].args;
setAttestTransaction(tx.hash);
```

We record the transaction hash to relay the transaction to Flare.


### Relaying the transaction with collateral from Ethereum to Flare

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

The response we get contains `abiEncodedRequest` — binary request for attestation. The encoded request contains data about the required transaction together with a message integrity check, that forces the attestation clients to really check the

```json
{
    "status": "VALID",
    "abiEncodedRequest": "0x45564d5472616e73616374696f6e0000000000000000000000000000000000007465737445544800000000000000000000000000000000000000000000000000d68cf10e63f7a8b10ec08f8e77429f3b2e14df77e5cab9cd8b39b9438960bc270000000000000000000000000000000000000000000000000000000000000020f032f6a100f3f7ef25428ea68621272d059c21cb52d5c62e3a3bd0e6afdc69a300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000000"
}
```

We use `abiEncodedRequest` from earlier to request attestation on Coston [**State Connector contract**](https://coston-explorer.flare.network/address/0x0c13aDA1C7143Cf0a0795FFaB93eEBb6FAD6e4e3) by calling `requestAttestations(abiEncodedRequest)`. This will let the entire set of attestation providers know, that you wish to have proof that the transaction with the attached payment reference has happened.

In the State Connector requests and answers are submitted sequentially in attestation rounds. Each attestation round has 4 consecutive phases called Collect, Choose, Commit and Reveal. You can learn more about Flare’s CCCR (Collect, Choose, Commit, Reveal) protocol [here](https://docs.flare.network/tech/state-connector/). Once we request attestation our request is part of a specific round numbered with `roundId`. RoundId is calculated based on the timestamp of the block in which attestation request contract call is made.

Next, you have to wait 6 minutes during which the attestation providers verify the validity of the transaction on their own nodes and vote on which transactions are valid (consensus). If our transaction is marked as valid by votes it is included in the Merkle tree for that round. When the round has been finalized, Merkle root for that round gets submitted and stored in State Connector smart contract.

After the round in which we requested attestation has been finalised we are ready to retrieve our Merkle proof that we will use to prove the validity of our XRP transaction. Each attestation provider holds a copy of the entire merkle tree for the round and is thus able to produce merkle proof for each specific transaction. We retrieve the Merkle proof by calling `/attestation-client/api/proof/get-specific-proof` with the calldata from before:

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

### Receiving USDC loan from Flare smart contract

TODO: kaj se zgodi na smart contractu

