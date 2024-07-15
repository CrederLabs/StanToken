// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
require('dotenv').config();

async function sleep(ms) {
  return new Promise(resolve=>{
    setTimeout(resolve,ms)
  })
}

async function main() {
    // owner: 0xDC285F6F4E5eb488BD2b7ec83fD8869f9EA07ac7
    const [owner, otherAccount] = await ethers.getSigners();
    console.log("owner: ", owner.address);

    // contracts/StanToken.sol 배포
    // const StanToken = await hre.ethers.getContractFactory("StanToken");
    // const stanToken = await StanToken.deploy();
    // await stanToken.deployed();

    // const MockERC20Token = await ethers.getContractFactory("StanToken");
    const stanToken = await hre.ethers.deployContract("StanToken");
    await stanToken.waitForDeployment();


    console.log("StanToken deployed to:", stanToken.target);

    console.log("Done");
    return;


//   let tokenGPC;
//   let tokenGHUB;
//   let tokenSTAN;
//   let singleDeposit;

//   if (process.env.NETWORK != "cypress") {
//     // local or baobab
//     // * mockup 용 ERC20 GPC, GHUB, STAN 배포
//     const MockERC20Token = await ethers.getContractFactory("MockERC20Token");
//     tokenGPC = await hre.ethers.deployContract("MockERC20Token", ["Test AAA", "tAAA"]);
//     await tokenGPC.waitForDeployment();
//     console.log("tokenGPC Address: ", tokenGPC.target);
//     tokenGHUB = await hre.ethers.deployContract("MockERC20Token", ["Test BBB", "tBBB"]);
//     await tokenGHUB.waitForDeployment();
//     console.log("tokenGHUB Address: ", tokenGHUB.target);
//     tokenSTAN = await hre.ethers.deployContract("MockERC20Token", ["Test CCC", "tCCC"]);
//     await tokenSTAN.waitForDeployment();
//     console.log("tokenSTAN Address: ", tokenSTAN.target);
//   }

//   // 1705276800(= 2024년 1월 15일 월요일 오전 9:00:00)
//   // const genesisTimestamp = 1705276800;
//   // 1705881600(= 2024년 1월 22일 월요일 오전 9:00:00)
//   const genesisTimestamp = 1705881600;

//   singleDeposit = await hre.ethers.deployContract("SingleDeposit", [genesisTimestamp]);
//   await singleDeposit.waitForDeployment();
//   console.log("SingleDeposit Address: ", singleDeposit.target);

//   // 프론트엔드 개발연동 테스트 주소
//   // 0xd67fA1D561aEFdF1d4CB935AB4290449E4D3bB06
//   // 0xB00B2D1C03153EefcD741637942618Bf49C95001

//   if (process.env.NETWORK != "cypress") {
//     await tokenGPC.transfer("0xd67fA1D561aEFdF1d4CB935AB4290449E4D3bB06", "10000000000000000000000");
//     console.log("첫번째 테스터 주소로 GPC 전송 완료");
//     await tokenGHUB.transfer("0xd67fA1D561aEFdF1d4CB935AB4290449E4D3bB06", "10000000000000000000000");
//     console.log("첫번째 테스터 주소로 GHUB 전송 완료");

//     await tokenGPC.transfer("0xB00B2D1C03153EefcD741637942618Bf49C95001", "10000000000000000000000");
//     console.log("두번째 테스터 주소로 GPC 전송 완료");
//     await tokenGHUB.transfer("0xB00B2D1C03153EefcD741637942618Bf49C95001", "10000000000000000000000");
//     console.log("두번째 테스터 주소로 GHUB 전송 완료");

//     // 미리 리워드(GHUB) 넣어두기. owner -> 컨트랙트 GHUB 보내기(10,000,000 GHUB)
//     await tokenGHUB.transfer(singleDeposit.target, "10000000000000000000000000");
//     console.log("GHUB 미리 충전 완료");
  
//     // --------------------------- GPC 단일예치 설정 ---------------------------
//     // deposit 토큰 설정: GPC
//     await singleDeposit.enableDepositToken(tokenGPC.target);
//     console.log("GPC deposit 토큰 설정 완료");

//     console.log("2초 대기...");
//     await sleep(2000);

//     let response = await singleDeposit.allowedDepositToken(tokenGPC.target);
//     console.log("response: ", response);

//     // 리워드 토큰 설정: GPC->GHUB (epochRewardAmount: 1000 GHUB)
//     await singleDeposit.setEpochRewardToken(
//       tokenGPC.target,
//       tokenGHUB.target,
//       "1000000000000000000000",
//       true
//     );

//     // --------------------------- GHUB 단일예치 설정 ---------------------------
//     // deposit 토큰 설정: GHUB
//     await singleDeposit.enableDepositToken(tokenGHUB.target);

//     console.log("2초 대기...");
//     await sleep(2000);

//     // 리워드 토큰 설정: GHUB->GHUB (epochRewardAmount: 1000 GHUB)
//     await singleDeposit.setEpochRewardToken(
//       tokenGHUB.target,
//       tokenGHUB.target,
//       "2000000000000000000000",
//       true
//     );
//   } else {
//     // cypress

//     // GPC 토큰 주소
//     const tokenGPCAddress = "0x27397bfbefd58a437f2636f80a8e70cfc363d4ff";
//     // GHUB 토큰 주소
//     const tokenGHUBAddress = "0x4836cc1f355bb2a61c210eaa0cd3f729160cd95e";

//     // --------------------------- GPC 단일예치 설정 ---------------------------
//     // deposit 토큰 설정: GPC
//     await singleDeposit.enableDepositToken(tokenGPCAddress);
//     console.log("GPC deposit 토큰 설정 완료");

//     console.log("10초 대기...");
//     await sleep(10000);
    
//     let response = await singleDeposit.allowedDepositToken(tokenGPCAddress);
//     console.log("response: ", response);

//     // 리워드 토큰 설정: GPC->GHUB (epochRewardAmount: 6666.67 GHUB)
//     await singleDeposit.setEpochRewardToken(
//       tokenGPCAddress,
//       tokenGHUBAddress,
//       "6666670000000000000000",
//       true
//     );

//     // --------------------------- GHUB 단일예치 설정: 22일 시작 ---------------------------
//     // deposit 토큰 설정: GHUB
//     await singleDeposit.enableDepositToken(tokenGHUBAddress);

//     console.log("10초 대기...");
//     await sleep(10000);

//     // 리워드 토큰 설정: GHUB->GHUB (epochRewardAmount: 5000 GHUB)
//     await singleDeposit.setEpochRewardToken(
//       tokenGHUBAddress,
//       tokenGHUBAddress,
//       "5000000000000000000000",
//       true
//     );
//   }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});