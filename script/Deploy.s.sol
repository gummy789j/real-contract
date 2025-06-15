// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/RealContract.sol";
import "../src/Voter.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000000000000 * 10 ** 18);
    }
}

contract DeployScript is Script {
    function run() public {
        // 從環境變數讀取私鑰
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer address:", deployer);

        // 開始廣播交易
        vm.startBroadcast(deployerPrivateKey);

        // 部署假的ERC20
        MockERC20 fakeERC20 = new MockERC20("FakeERC20", "FERC20");
        console.log("FakeERC20 deployed to:", address(fakeERC20));

        address participantA = address(
            0x565d490806A6D8eF532f4d29eC00EF6aAC71A17A
        );
        address participantB = address(
            0x8d521dCae9C1f7353a96D1510B3B4F9f83413bC9
        );

        // 轉移代幣給參與者
        fakeERC20.transfer(participantA, 10000000 * 10 ** 18);
        fakeERC20.transfer(participantB, 10000000 * 10 ** 18);
        console.log("Transferred tokens to participants");

        // 部署 Voter 合約
        Voter voter = new Voter(deployer);
        console.log("Voter deployed to:", address(voter));

        // 部署 RealContract 合約
        RealContract realContract = new RealContract(
            deployer, // governance
            address(voter), // voter
            address(fakeERC20), // compensationToken
            address(fakeERC20), // voteToken
            participantA, // participantA
            participantB, // participantB
            100, // feeRateForStakeCompensation (1%)
            200, // feeRateForExecuteCase (2%)
            100 // 100 wei
        );
        console.log("RealContract deployed to:", address(realContract));

        // 添加投票者
        voter.addVoter(deployer);
        console.log("Added deployer as voter");

        // 停止廣播交易
        vm.stopBroadcast();

        // 打印部署摘要
        console.log("\n=== Deployment Summary ===");
        console.log("Network: Sepolia");
        console.log("Deployer:", deployer);
        console.log("\nContract Addresses:");
        console.log("FakeERC20:", address(fakeERC20));
        console.log("Voter:", address(voter));
        console.log("RealContract:", address(realContract));
        console.log("\nParticipants:");
        console.log("Participant A:", participantA);
        console.log("Participant B:", participantB);
        console.log("\nToken Balances:");
        console.log(
            "Participant A Balance:",
            fakeERC20.balanceOf(participantA)
        );
        console.log(
            "Participant B Balance:",
            fakeERC20.balanceOf(participantB)
        );
        console.log("Deployer Balance:", fakeERC20.balanceOf(deployer));
        console.log("\nContract Parameters:");
        console.log("Fee Rate for Stake Compensation: 1%");
        console.log("Fee Rate for Execute Case: 2%");
        console.log("Stake Amount: 100 wei");
        console.log("========================\n");
    }
}
