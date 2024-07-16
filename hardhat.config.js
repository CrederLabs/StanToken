require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config();
require("@nomicfoundation/hardhat-verify");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.24",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      }
    ]
  },
  etherscan: {
    apiKey: {
      snowtrace: "snowtrace", // apiKey is not required, just set a placeholder
    },
    customChains: [
      // * Avalanche Testnet verify 참고: https://testnet.snowtrace.io/documentation/recipes/hardhat-verification
      {
        network: "snowtrace",
        chainId: 43113,
        urls: {
          apiURL: "https://api.routescan.io/v2/network/testnet/evm/43113/etherscan",
          browserURL: "https://avalanche.testnet.localhost:8080"
        }
      },
      // * Avalanche Mainnet verify 참고: https://snowtrace.io/documentation/recipes/hardhat-verification
      // {
      //   network: "snowtrace",
      //   chainId: 43114,
      //   urls: {
      //     apiURL: "https://api.routescan.io/v2/network/mainnet/evm/43114/etherscan",
      //     browserURL: "https://avalanche.routescan.io"
      //   }
      // }
    ]
  },
  networks: {
    snowtrace: {
      url: "https://api.avax-test.network/ext/bc/C/rpc",
      accounts: [
        process.env.PRIVATE_KEY || ''
      ],
    },
    // snowtrace: {
    //   url: "https://api.avax.network/ext/bc/C/rpc",
    //   chainId: 43114,
    //   accounts: [
    //     process.env.PRIVATE_KEY || ''
    //   ],
    // },
  }
};
