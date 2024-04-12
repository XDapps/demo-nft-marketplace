import { config as dotenvConfig } from "dotenv";
import { resolve } from "path";
dotenvConfig({ path: resolve(__dirname, "./.env") });

import { HardhatUserConfig } from "hardhat/types";
import { NetworkUserConfig } from "hardhat/types";
import "@nomicfoundation/hardhat-verify";
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-network-helpers";
import "@openzeppelin/hardhat-upgrades";
import "@typechain/hardhat";
import "hardhat-gas-reporter";

const MNEMONIC = process.env.MNEMONIC || "";
const INFURA_API_KEY = process.env.INFURA_API_KEY || "";

function createInfuraConfig(network: string, chainId: number): NetworkUserConfig {
	const url: string = "https://" + network + ".infura.io/v3/" + INFURA_API_KEY;
	return {
		accounts: {
			count: 10,
			initialIndex: 0,
			mnemonic: MNEMONIC,
			path: "m/44'/60'/0'/0",
		},
		chainId: chainId,
		url,
		gas: 2100000,
		gasPrice: 200000000000,
	};
}
function createInfuraForkConfig(network: string): NetworkUserConfig {
	const url: string = "https://" + network + ".infura.io/v3/" + INFURA_API_KEY;
	return {
		forking: {
			url: url
		},
		accounts: {
			count: 10,
			initialIndex: 0,
			mnemonic: MNEMONIC,
			path: "m/44'/60'/0'/0",
		},
		chainId: 31337,
		gas: 2100000,
		url,
		gasPrice: 200000000000,
	};
}
const config: HardhatUserConfig = {
	defaultNetwork: "hardhat",
	networks: {
		hardhat: {
			// forking: {
			// 	url: "https://polygon-mainnet.infura.io/v3/" + INFURA_API_KEY,
			// },
			accounts: {
				mnemonic: MNEMONIC,
			},
			chainId: 31337,
		},
		eth: createInfuraConfig("mainnet", 1),
		ethfork: createInfuraForkConfig("mainnet"),
		mumbai: createInfuraConfig("polygon-mumbai", 80001),
		mumbaifork: createInfuraForkConfig("polygon-mumbai"),
		polygon: createInfuraConfig("polygon-mainnet", 137),
		polygonfork: createInfuraForkConfig("polygon-mainnet"),
		sepolia: createInfuraConfig("sepolia", 11155111),
		sepoliafork: createInfuraForkConfig("sepolia"),
	},
	solidity: {
		compilers: [
			{
				version: "0.8.24",
				settings: {
					optimizer: {
						enabled: true,
						runs: 1000
					}
				}
			}
		],
	},
	gasReporter: {
		currency: "USD",
		gasPrice: 100,
		enabled: process.env.REPORT_GAS ? true : false,
	},
	etherscan: {
		apiKey: {
			polygon: process.env.POLYGON_SCAN_API_KEY ? process.env.POLYGON_SCAN_API_KEY : "",
			mumbai: process.env.POLYGON_SCAN_API_KEY ? process.env.POLYGON_SCAN_API_KEY : "",
		},
		customChains: [
			{
				network: "mumbai",
				chainId: 80001,
				urls: {
					apiURL: "https://api-testnet.polygonscan.com/api",
					browserURL: "https://mumbai.polygonscan.com/"
				}
			}
		]
	},
	sourcify: {
		// Disabled by default
		// Doesn't need an API key
		enabled: true
	}
};

export default config;
