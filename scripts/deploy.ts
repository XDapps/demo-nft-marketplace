import { ethers } from "hardhat";

async function main() {

	const NFTMarketplaceFactory = await ethers.getContractFactory("NFTMarketplace");
	const feeCollectorAddress = "";
	const feeAmount = 300; // 3%
	const name = "Demo NFT Marketplace";

	try {
		const marketplaceContract = await NFTMarketplaceFactory.deploy(name, feeCollectorAddress, feeAmount);
		const marketplaceContractAddress = await marketplaceContract.getAddress();
		console.log("NFT Marketplace deployed to:", marketplaceContractAddress);
	} catch (error) {
		console.error("Error deploying contract", error);
	}
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
	console.error(error);
	process.exitCode = 1;
});
