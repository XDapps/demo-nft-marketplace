import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import exp from "constants";
import { bignumber } from "mathjs";
//import { MockERC721, NFTMarketplace } from "../typechain-types";


let marketplaceAddress = "";
let erc721CollectionAddress = "";
let feeCollectorAddress = "";
const feeBasisPoints = 300; // 3%

describe("Test NFT Marketplace", async function () {
	it("Deploy, Mint, Sell", async function () {
		const [deployer, user1, user2] = await ethers.getSigners();
		feeCollectorAddress = user2.address;
		//****************Deploy Contracts****************//

		const MockERC721Factory = await ethers.getContractFactory("MockERC721");
		const NFTMarketplaceFactory = await ethers.getContractFactory("NFTMarketplace");

		const collectionName = "ERC-721 Mock Test";
		const collectionSymbol = "MT";
		const collectionContract = await MockERC721Factory.deploy(collectionName, collectionSymbol);
		erc721CollectionAddress = await collectionContract.getAddress();

		expect(await collectionContract.name()).to.equal(collectionName);
		expect(await collectionContract.symbol()).to.equal(collectionSymbol);
		const marketplaceName = "NFT Marketplace";
		const marketplaceContract = await NFTMarketplaceFactory.deploy(marketplaceName, feeCollectorAddress, feeBasisPoints);
		marketplaceAddress = await marketplaceContract.getAddress();

		expect(await marketplaceContract.name()).to.equal(marketplaceName);

		//**************** Mint Initial NFT *****************//
		await collectionContract.mint(deployer.address);
		expect(await collectionContract.balanceOf(deployer.address)).to.equal(1);

		//***************** List for Sale *******************//
		const tokenId = 1;
		const price = ethers.parseUnits("100", 18);
		const paymentToken = ethers.ZeroAddress;
		expect(marketplaceContract.listItemForSale(erc721CollectionAddress, tokenId, paymentToken, price)).to.be.revertedWith("Error: must own the token and have transfer approval");
		expect(marketplaceContract.listItemForSale(erc721CollectionAddress, tokenId, paymentToken, 0)).to.be.revertedWith("Error: Asking price must be greater than 0");
		expect(marketplaceContract.listItemForSale(erc721CollectionAddress, tokenId, feeCollectorAddress, price)).to.be.revertedWith("Error: must be an ERC721 token");
		await collectionContract.approve(marketplaceAddress, tokenId);
		await marketplaceContract.listItemForSale(erc721CollectionAddress, tokenId, paymentToken, price);
		expect(await marketplaceContract.isForSale(erc721CollectionAddress, tokenId)).to.equal(true);
		expect(await marketplaceContract.getAskingPrice(erc721CollectionAddress, tokenId)).to.equal(price);


		//********************* Test Price Change ************************//
		const newPrice = ethers.parseUnits("50", 18);
		await marketplaceContract.changePrice(erc721CollectionAddress, tokenId, ethers.ZeroAddress, newPrice);
		expect(await marketplaceContract.getAskingPrice(erc721CollectionAddress, tokenId)).to.equal(newPrice);

		//************************* Test Buy ****************************//
		const buyer = user1;
		const buyerBalanceBefore = await buyer.provider.getBalance(buyer.address);
		const buyerBalBeforeBN = BigInt(buyerBalanceBefore.toString());
		const sellerBalanceBefore = await deployer.provider.getBalance(deployer.address);

		const feeCollectorBalanceBefore = await buyer.provider.getBalance(feeCollectorAddress);
		const newPriceBN = BigInt(newPrice.toString());
		const feeBasisPointsBN = BigInt(feeBasisPoints.toString());
		const feeAmount = ((newPriceBN * feeBasisPointsBN) / BigInt(10000));
		const marketplaceAsBuyer = marketplaceContract.connect(buyer);
		const tx = await marketplaceAsBuyer.buyItem(erc721CollectionAddress, tokenId, newPrice, { value: newPrice });
		const receipt = await tx.wait(); 
		if (!receipt || !receipt.gasUsed) throw new Error("Transaction failed");
		const gasUsed = BigInt(receipt.gasUsed.toString());
		const gasPrice = BigInt(tx.gasPrice.toString());
		const totalGasCostBN = BigInt(gasPrice * gasUsed);
		const sellerBalanceAfter = await deployer.provider.getBalance(deployer.address);
		const buyerBalanceAfter = await buyer.provider.getBalance(buyer.address);

		expect(await collectionContract.balanceOf(buyer.address)).to.equal(1);
		expect(await collectionContract.balanceOf(deployer.address)).to.equal(0);

		const buyerBalAfterBN = BigInt(buyerBalanceAfter.toString());

		const feeCollectorBalanceAfter = await buyer.provider.getBalance(feeCollectorAddress);
		const feeCollectorBalBeforeBN = BigInt(feeCollectorBalanceBefore.toString());
		const feeCollectorBalAfterBN = BigInt(feeCollectorBalanceAfter.toString());
		expect(feeCollectorBalAfterBN).to.equal(feeCollectorBalBeforeBN + feeAmount);

		expect(buyerBalAfterBN).to.equal(buyerBalBeforeBN - newPriceBN - totalGasCostBN);
		const sellerBalBeforeBN = BigInt(sellerBalanceBefore.toString());
		expect(sellerBalanceAfter).to.equal(sellerBalBeforeBN + newPriceBN - feeAmount);

		//************************ Relist Token ****************************//
		expect(await marketplaceContract.isForSale(erc721CollectionAddress, tokenId)).to.equal(false); 
		const collectionContractAsBuyer = collectionContract.connect(buyer);
		await collectionContractAsBuyer.approve(marketplaceAddress, tokenId);
		await marketplaceAsBuyer.listItemForSale(erc721CollectionAddress, tokenId, paymentToken, newPrice);
		expect(await marketplaceContract.isForSale(erc721CollectionAddress, tokenId)).to.equal(true);

		//********************* Test Remove Listing ************************//
		await marketplaceAsBuyer.removeListing(erc721CollectionAddress, tokenId);
		expect(await marketplaceContract.isForSale(erc721CollectionAddress, tokenId)).to.equal(false);



	});
});
