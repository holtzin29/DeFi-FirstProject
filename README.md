
# **Decentralized Stable Coin (DSC) DeFi Protocol**

## **Overview**

The Decentralized Stable Coin (DSC) Protocol is a DeFi platform designed to create a decentralized stablecoin (DSC) backed by collateral assets. The protocol uses a mechanism for collateral deposits, liquidation, and the minting of DSC, aiming to offer stability, transparency, and efficiency in decentralized finance.

Key Features: 

1. relative stability: anchored stable coin or (pegged) to the USD dolar $1 
   1. Chainlink PriceFeed
   2. Set a function to exchange ETH and BTC to $
2. stability mechanism: minting: algorithmic (decentralized stablecoing)
     1. People can only mint stablecoin with enough collateral(coded)
3. collateral type: exogenous(crypto) (wBtc and wEth)

## **Features**

- **Stablecoin Minting**: Users can mint DSC by depositing collateral in the form of ERC-20 tokens like WETH, WBTC.
- **Collateralized Debt Position (CDP)**: A collateralized debt position allows users to maintain positions backed by their collateral, ensuring stability in the issuance of DSC.
- **Liquidation System**: A liquidation mechanism ensures that undercollateralized positions are automatically liquidated to maintain the solvency of the protocol.
- **Price Feeds**: External price feeds provide real-time token valuations for the protocol.
- **Tests**: The protocol comes with a comprehensive suite of tests to ensure robustness, including edge cases like zero collateral deposits and unapproved tokens.

## **Contracts Overview**

1. **DecentralizedStableCoin (DSC)**: The ERC-20 stablecoin minted by users' collateral deposits.
2. **DSCEngine**: The core logic of the protocol that governs collateral deposits, minting DSC, and liquidation.
3. **HelperConfig**: This script is responsible for network-specific configuration, such as token addresses and price feeds.
4. **MockV3Aggregator**: A mock contract for price feeds, useful for testing without needing an actual external data source.
5. **Handler**: A contract to simulate minting operations and interaction with the `DSCEngine` for testing.
6. **DeployDSC**: A deployment script for the DSC and DSCEngine contracts on a specific network.
7. **Tests**: Unit tests written with Foundry's testing framework ensure the contract behaves as expected.

## **Setup and Installation**

1. **Install Dependencies**

Make sure you have `Foundry` installed for testing and deployment. If you haven’t installed it yet, you can do so via:

- Install Foundry

2. **Clone the Repo**

Clone this repository to your local machine:

- Clone the repo

3. **Install OpenZeppelin Contracts**

The project uses OpenZeppelin's contracts for ERC-20 tokens. Install them using:

- Install OpenZeppelin contracts

4. **Deployment Configuration**

Configure network-specific parameters, such as token addresses and price feed addresses in the `HelperConfig` contract. Make sure to define the `weth`, `wbtc`, and other tokens for the network you are working with.

5. **Deploy Contracts**

To deploy the DSC protocol on your network, run the following script:

- Deployment command

6. **Run Tests**

Test your contracts using Foundry’s testing framework:

- Run tests command

This will run all the unit tests defined in the test files, ensuring everything is functioning properly.

## **Contract Details**

### **1. `DecentralizedStableCoin` (DSC)**

This contract represents the stablecoin of the protocol. It implements the ERC-20 standard and provides the mechanism for minting new DSC tokens based on the collateral deposited by users.

- **Minting DSC**: When collateral is deposited, DSC is minted based on the collateral value.
- **Burning DSC**: DSC can be burned when users repay their debt.

### **2. `DSCEngine`**

The DSCEngine contract contains the core logic of the protocol, managing collateralized positions, minting, and liquidation.

#### **Key Functions:**

- **Deposit Collateral**: Users can deposit approved collateral (e.g., WETH, WBTC).
- **Get Account Info**: Retrieves information on the user's collateral and minted DSC.
- **Mint DSC**: Mint new DSC based on the collateral value.
- **Liquidation**: Automatically liquidates under-collateralized positions.

### **3. `HelperConfig`**

This contract configures the active network parameters, such as token addresses, price feeds, and collateral configurations.

- **Configuration**: Helps link token addresses with their corresponding price feeds.
- **Network Setup**: Configures for different networks (e.g., mainnet, testnet).

### **4. `MockV3Aggregator`**

This mock contract is used in tests to simulate price feeds without relying on external data sources. It allows you to update and query mock price data for testing purposes.

### **5. `Handler`**

This contract facilitates minting DSC and interacting with the DSCEngine for testing. It helps simulate mint operations and track mint count.

### **6. `DeployDSC`**

A deployment script that deploys the `DSC` and `DSCEngine` contracts to the active network, ensuring everything is set up with the correct configuration.

## **Testing**

This project comes with a comprehensive set of tests written in Solidity. Tests are structured to ensure that all edge cases and normal interactions are validated.

### **Test Cases**

1. **Constructor Tests**: Ensures that the length of token addresses matches the length of price feeds. If they don't match, the contract reverts.
   
2. **Price Feeds**: Tests price feed interactions, ensuring correct USD values can be fetched for assets.

3. **Collateral Tests**: Includes various tests for depositing collateral:
   - Tests revert when zero collateral is deposited.
   - Tests revert when unapproved collateral tokens are used.
   - Validates successful deposit of collateral and updates user information accordingly.

4. **Minting and Account Information**: Verifies that the minting logic works and checks the correct account information after collateral deposits.

5. **Edge Cases**: Includes tests to ensure contracts revert with invalid inputs and behave as expected under various scenarios.

## **Invariants**

The protocol must maintain the following invariants:

- **Total Supply < Total Collateral Value**: The total supply of DSC must always be less than or equal to the total value of the collateral.
- **Getters Should Not Revert**: Functions that retrieve information (e.g., get collateral value, token amounts) should never revert under normal circumstances.

## **Roadmap**

1. **Mainnet Launch**: Deploy the contracts on the main Ethereum network and integrate with decentralized exchanges (DEXs).
2. **Price Feed Improvements**: Integrate more assets and external data sources.
3. **User Interface**: Build a user-friendly front-end interface to interact with the protocol.
4. **Governance**: Implement governance for the decentralized control of the protocol.

## **Contributing**

We welcome contributions to improve the DSC protocol. Please feel free to open issues and submit pull requests. 

To contribute:

1. Fork the repository
2. Create a new branch
3. Make your changes
4. Test your changes
5. Submit a pull request

---

## **License**
