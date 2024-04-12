# NFT Marketplace Demo

This is a demo of a simple NFT Marketplace for ERC-721 tokens. It's very basic, but has functionality to add, change, remove, or purchase NFT listings. Using the network's native currency or an ERC-20 token.

## Installation

1. Please see .example.env file and recreate a .env in the same format.
2. Navigate to your project directory and run:

```shell
yarn
```

```shell
npx hardhat test
```

## Deployment

1. Update Fee Collector Address in scripts/deploy.ts.
2. Update Fee Amount in scripts/deploy.ts. (Max 3% currently in contract).
3. Update Name if you choose in scripts/deploy.ts.

*Example of how to deploy on Polygon*

*See hardhat.config.ts to add networks*

```shell
npx hardhat run scripts/deploy --network polygon
```

## How to Use

### Listing a Token

To list a token a user would call the function below.

-**_tokenAddress**: the address of the ERC-721 token contract of the item being listed.

-**_tokenId**: the tokenId of the item being listed.

-**_paymentToken**: the payment token the listing is denominated in. (Zero address for native currency).

-**_askingPrice**: listing price in _paymentToken's smallest unit(typically wei).

> [!NOTE]
> A user must first approve the marketplace contract to transfer their ERC-721 token or the listing will revert.

```solidity
function listItemForSale(
        address _tokenAddress,
        uint256 _tokenId,
        address _paymentToken,
        uint256 _askingPrice
    ) external
```
