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

    // if (process.env.NETWORK != "snowtrace") {
    //     console.log("NETWORK is not snowtrace");
    //     return;
    // }

    const stanTokenAddress = "0xcFB2324F5b2241ac8df3d4A77B53D7840B795b90";
    const stanToken = await ethers.getContractAt("StanToken", stanTokenAddress);

    // let result = await stanToken.totalLocks("0xd67fA1D561aEFdF1d4CB935AB4290449E4D3bB06");
    // console.log("totalLocks: ", result.toString());

    // 특정 주소에 대해 vesting 추가(wormhole study 테스트 계정)
    // const userAddress = "0xcF7f1535CCb3fF8acdbE2D44087996285D3a9B1B";

    // 재원 주소
    const userAddress = "0xd67fA1D561aEFdF1d4CB935AB4290449E4D3bB06";

    // 미리 approve 해야함

    // vesting 10 STAN 10개. 현재 시간 기준으로 10분 간격
    let vestingAmount = ethers.parseUnits("10", 18);

    let currentTimestamp = Math.floor(Date.now() / 1000);

    for (let i = 0; i < 10; i++) {
      console.log(i + "번째 vesting");

      let tx = await stanToken.lock(userAddress, vestingAmount, currentTimestamp + 600 + 60 * 10 * i);
      await tx.wait();
      console.log(vestingAmount + " STAN is locked until " + new Date((currentTimestamp + 600 + 60 * 10 * i) * 1000).toUTCString());
    }

    // 2일 후
    console.log("2일 후");
    for (let i = 0; i < 10; i++) {
      console.log(i + "번째 vesting");

      let tx = await stanToken.lock(userAddress, vestingAmount, currentTimestamp + 86400 + 600 + 60 * 10 * i);
      await tx.wait();
      console.log(vestingAmount + " STAN is locked until " + new Date((currentTimestamp + 86400 + 600 + 60 * 10 * i) * 1000).toUTCString());
    }

    // 3일 후
    console.log("3일 후");
    for (let i = 0; i < 10; i++) {
      console.log(i + "번째 vesting");

      let tx = await stanToken.lock(userAddress, vestingAmount, currentTimestamp + 86400 * 2 + 600 + 60 * 10 * i);
      await tx.wait();
      console.log(vestingAmount + " STAN is locked until " + new Date((currentTimestamp + 86400 * 2 + 600 + 60 * 10 * i) * 1000).toUTCString());
    }




    // // 1. vesting 추가
    // let vestingAmount = ethers.parseUnits("10", 18);
    // // 6개월 후
    // let releaseTime = Math.floor(Date.now() / 1000) + 60*60*24*30*6; // 6개월 후
    // let tx = await stanToken.lock(userAddress, vestingAmount, releaseTime);
    // await tx.wait();
    // console.log(vestingAmount + " STAN is locked until " + new Date(releaseTime * 1000).toUTCString());

    // // 1년 후
    // vestingAmount = ethers.parseUnits("200", 18);
    // releaseTime = Math.floor(Date.now() / 1000) + 60*60*24*365; // 1년 후
    // tx = await stanToken.lock(userAddress, vestingAmount, releaseTime);
    // await tx.wait();
    // console.log(vestingAmount + " STAN is locked until " + new Date(releaseTime * 1000).toUTCString());

    console.log("All done");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});