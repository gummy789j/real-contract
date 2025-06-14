// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/RealContract.sol";
import "../src/Voter.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/interfaces/IRealContract.sol";
import "../src/interfaces/ICaseManager.sol";

// 模擬 ERC20 代幣合約
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }
}

contract RealContractTest is Test {
    RealContract public realContract;
    Voter public voter;
    MockERC20 public compensationToken;
    address public owner;
    address public participantA;
    address public participantB;
    address public voter1;
    address public voter2;
    uint256 public feeRateForStakeCompensation = 100; // 1%
    uint256 public feeRateForExecuteCase = 200; // 2%

    function setUp() public {
        owner = address(this);
        participantA = address(0x1);
        participantB = address(0x2);
        voter1 = address(0x3);
        voter2 = address(0x4);

        compensationToken = new MockERC20();
        voter = new Voter(owner);
        realContract = new RealContract(
            owner,
            address(voter),
            address(compensationToken),
            address(0), // voteToken address (0 for native token)
            participantA,
            participantB,
            feeRateForStakeCompensation,
            feeRateForExecuteCase,
            1 ether // voteTokenAmount
        );

        // 給參與者一些代幣
        compensationToken.transfer(participantA, 1000 * 10 ** 18);
        compensationToken.transfer(participantB, 1000 * 10 ** 18);
        compensationToken.transfer(voter1, 1000 * 10 ** 18);
        compensationToken.transfer(voter2, 1000 * 10 ** 18);

        // 添加投票者
        voter.addVoter(voter1);
        voter.addVoter(voter2);

        vm.deal(voter1, 1000 * 10 ** 18);
        vm.deal(voter2, 1000 * 10 ** 18);
        vm.deal(participantA, 1000 * 10 ** 18);
        vm.deal(participantB, 1000 * 10 ** 18);
        vm.deal(owner, 1000 * 10 ** 18);
    }

    function test_Deployment() public view {
        assertEq(realContract.governance(), owner);
        assertEq(realContract.participantA(), participantA);
        assertEq(realContract.participantB(), participantB);
        assertEq(
            address(realContract.compensationToken()),
            address(compensationToken)
        );
        assertEq(
            realContract.feeRateForStakeCompensation(),
            feeRateForStakeCompensation
        );
        assertEq(realContract.feeRateForExecuteCase(), feeRateForExecuteCase);
        assertTrue(realContract.running());
    }

    function test_AddCase() public {
        vm.startPrank(participantA);
        ICaseManager.CaseInit memory newCase = ICaseManager.CaseInit({
            caseName: "Test Case",
            caseDescription: "Test Description",
            participantA: participantA,
            participantB: participantB,
            compensationA: 100 * 10 ** 18,
            compensationB: 100 * 10 ** 18,
            winnerIfEqualVotes: participantA,
            votingDuration: 1 days
        });
        realContract.addCase(newCase);
        vm.stopPrank();
        assertEq(realContract.getCaseName(0), "Test Case");
        assertEq(
            uint256(realContract.getCaseStatus(0)),
            uint256(ICaseManager.CaseStatus.Inactivated)
        );
    }

    function test_RevertWhen_AddCaseWithInvalidParticipant() public {
        vm.startPrank(participantA);
        ICaseManager.CaseInit memory newCase = ICaseManager.CaseInit({
            caseName: "Test Case",
            caseDescription: "Test Description",
            participantA: address(0x5), // 無效的參與者
            participantB: participantB,
            compensationA: 100 * 10 ** 18,
            compensationB: 100 * 10 ** 18,
            winnerIfEqualVotes: participantA,
            votingDuration: 1 days
        });
        vm.expectRevert("Participant A is not a participant");
        realContract.addCase(newCase);
        vm.stopPrank();
    }

    function test_StakeCompensation() public {
        // 每次 nonReentrant 函數都用新的 prank
        {
            vm.startPrank(participantA);
            ICaseManager.CaseInit memory newCase = ICaseManager.CaseInit({
                caseName: "Test Case",
                caseDescription: "Test Description",
                participantA: participantA,
                participantB: participantB,
                compensationA: 100 * 10 ** 18,
                compensationB: 100 * 10 ** 18,
                winnerIfEqualVotes: participantA,
                votingDuration: 1 days
            });
            realContract.addCase(newCase);
            compensationToken.approve(address(realContract), type(uint256).max);
            vm.expectEmit(true, true, false, false);
            emit IRealContract.CaseStaked(
                0,
                participantA,
                newCase.compensationA
            );
            realContract.stakeCompensation(0, true);
            vm.stopPrank();
        }
        assertTrue(realContract.getCaseIsPaidA(0));
    }

    function test_RevertWhen_StakeCompensationTwice() public {
        vm.startPrank(participantA);
        ICaseManager.CaseInit memory newCase = ICaseManager.CaseInit({
            caseName: "Test Case",
            caseDescription: "Test Description",
            participantA: participantA,
            participantB: participantB,
            compensationA: 100 * 10 ** 18,
            compensationB: 100 * 10 ** 18,
            winnerIfEqualVotes: participantA,
            votingDuration: 1 days
        });
        realContract.addCase(newCase);
        compensationToken.approve(address(realContract), type(uint256).max);
        realContract.stakeCompensation(0, true);
        vm.expectRevert("Participant A has already paid");
        realContract.stakeCompensation(0, true);
        vm.stopPrank();
    }

    function test_Vote() public {
        // 設置案件
        {
            vm.startPrank(participantA);
            ICaseManager.CaseInit memory newCase = ICaseManager.CaseInit({
                caseName: "Test Case",
                caseDescription: "Test Description",
                participantA: participantA,
                participantB: participantB,
                compensationA: 100 * 10 ** 18,
                compensationB: 100 * 10 ** 18,
                winnerIfEqualVotes: participantA,
                votingDuration: 1 days
            });
            realContract.addCase(newCase);
            compensationToken.approve(address(realContract), type(uint256).max);
            realContract.stakeCompensation(0, true);
            vm.stopPrank();
        }
        {
            vm.startPrank(participantB);
            compensationToken.approve(address(realContract), type(uint256).max);
            realContract.stakeCompensation(0, false);
            vm.stopPrank();
        }
        // 開始投票
        vm.prank(participantA);
        realContract.startCaseVoting(0);
        // 投票
        vm.prank(voter1);
        vm.expectEmit(true, true, false, false);
        emit IRealContract.CaseVoted(0, voter1, participantA);
        realContract.vote{value: 1 ether}(0, participantA);
        assertEq(realContract.getCaseVoterVotes(0, participantA), 1);
    }

    function test_RevertWhen_NonVoterVotes() public {
        // 設置案件
        {
            vm.startPrank(participantA);
            ICaseManager.CaseInit memory newCase = ICaseManager.CaseInit({
                caseName: "Test Case",
                caseDescription: "Test Description",
                participantA: participantA,
                participantB: participantB,
                compensationA: 100 * 10 ** 18,
                compensationB: 100 * 10 ** 18,
                winnerIfEqualVotes: participantA,
                votingDuration: 1 days
            });
            realContract.addCase(newCase);
            compensationToken.approve(address(realContract), type(uint256).max);
            realContract.stakeCompensation(0, true);
            vm.stopPrank();
        }
        {
            vm.startPrank(participantB);
            compensationToken.approve(address(realContract), type(uint256).max);
            realContract.stakeCompensation(0, false);
            vm.stopPrank();
        }
        // 開始投票
        vm.prank(participantA);
        realContract.startCaseVoting(0);
        // 非投票者嘗試投票
        vm.prank(participantA); // 非投票者地址
        vm.expectRevert("Sender is not a voter");
        realContract.vote{value: 1 ether}(0, participantA);
    }

    function test_RevertWhen_VoteTwice() public {
        // 設置案件
        vm.startPrank(participantA);
        ICaseManager.CaseInit memory newCase = ICaseManager.CaseInit({
            caseName: "Test Case",
            caseDescription: "Test Description",
            participantA: participantA,
            participantB: participantB,
            compensationA: 100 * 10 ** 18,
            compensationB: 100 * 10 ** 18,
            winnerIfEqualVotes: participantA,
            votingDuration: 1 days
        });
        realContract.addCase(newCase);
        compensationToken.approve(address(realContract), type(uint256).max);
        realContract.stakeCompensation(0, true);
        vm.stopPrank();

        vm.startPrank(participantB);
        compensationToken.approve(address(realContract), type(uint256).max);
        realContract.stakeCompensation(0, false);
        vm.stopPrank();

        vm.prank(participantA);
        realContract.startCaseVoting(0);

        vm.prank(voter1);
        realContract.vote{value: 1 ether}(0, participantA);
        vm.prank(voter1);
        vm.expectRevert("Voter has already voted");
        realContract.vote{value: 1 ether}(0, participantA);
    }

    function test_RevertWhen_InsufficientVoteToken() public {
        // 設置案件
        {
            vm.startPrank(participantA);
            ICaseManager.CaseInit memory newCase = ICaseManager.CaseInit({
                caseName: "Test Case",
                caseDescription: "Test Description",
                participantA: participantA,
                participantB: participantB,
                compensationA: 100 * 10 ** 18,
                compensationB: 100 * 10 ** 18,
                winnerIfEqualVotes: participantA,
                votingDuration: 1 days
            });
            realContract.addCase(newCase);
            compensationToken.approve(address(realContract), type(uint256).max);
            realContract.stakeCompensation(0, true);
            vm.stopPrank();
        }
        {
            vm.startPrank(participantB);
            compensationToken.approve(address(realContract), type(uint256).max);
            realContract.stakeCompensation(0, false);
            vm.stopPrank();
        }
        console.log("check1");
        // 開始投票
        vm.prank(participantA);
        realContract.startCaseVoting(0);
        // 嘗試使用不足的投票代幣
        vm.prank(voter1);
        vm.expectRevert("Insufficient vote token");
        realContract.vote{value: 0.5 ether}(0, participantA);
    }

    function test_ExecuteCase() public {
        // 設置案件
        {
            vm.startPrank(participantA);
            ICaseManager.CaseInit memory newCase = ICaseManager.CaseInit({
                caseName: "Test Case",
                caseDescription: "Test Description",
                participantA: participantA,
                participantB: participantB,
                compensationA: 100 * 10 ** 18,
                compensationB: 100 * 10 ** 18,
                winnerIfEqualVotes: participantA,
                votingDuration: 1 days
            });
            realContract.addCase(newCase);
            compensationToken.approve(address(realContract), type(uint256).max);
            realContract.stakeCompensation(0, true);
            vm.stopPrank();
        }
        {
            vm.startPrank(participantB);
            compensationToken.approve(address(realContract), type(uint256).max);
            realContract.stakeCompensation(0, false);
            vm.stopPrank();
        }
        vm.startPrank(participantA);
        realContract.startCaseVoting(0);
        vm.stopPrank();

        vm.prank(voter1);
        realContract.vote{value: 1 ether}(0, participantA);

        vm.startPrank(participantB);
        vm.warp(block.timestamp + 1 days + 1);
        vm.expectEmit(true, true, false, false);
        emit IRealContract.CaseExecuted(0, participantA);
        realContract.executeCase(0);
        assertEq(
            uint256(realContract.getCaseStatus(0)),
            uint256(ICaseManager.CaseStatus.Executed)
        );
        vm.stopPrank();
    }

    function test_CancelCase() public {
        // 設置案件
        {
            vm.startPrank(participantA);
            ICaseManager.CaseInit memory newCase = ICaseManager.CaseInit({
                caseName: "Test Case",
                caseDescription: "Test Description",
                participantA: participantA,
                participantB: participantB,
                compensationA: 100 * 10 ** 18,
                compensationB: 100 * 10 ** 18,
                winnerIfEqualVotes: participantA,
                votingDuration: 1 days
            });
            realContract.addCase(newCase);
            compensationToken.approve(address(realContract), type(uint256).max);
            realContract.stakeCompensation(0, true);
            vm.stopPrank();
        }
        {
            vm.startPrank(participantB);
            compensationToken.approve(address(realContract), type(uint256).max);
            realContract.stakeCompensation(0, false);
            vm.stopPrank();
        }
        {
            vm.startPrank(participantA);
            realContract.cancelCase(0);
            vm.stopPrank();
        }
        {
            vm.startPrank(participantB);
            realContract.cancelCase(0);
            vm.stopPrank();
        }
        assertEq(
            uint256(realContract.getCaseStatus(0)),
            uint256(ICaseManager.CaseStatus.Abandoned)
        );
    }

    function test_SetRunning() public {
        vm.startPrank(owner);
        vm.expectEmit(false, false, false, true);
        emit IRealContract.ContractStatusChanged(false);
        realContract.setRunning(false);
        vm.stopPrank();

        assertFalse(realContract.running());
    }

    function test_RevertWhen_NonParticipantAddCase() public {
        vm.startPrank(address(0x5)); // 非參與者
        ICaseManager.CaseInit memory newCase = ICaseManager.CaseInit({
            caseName: "Test Case",
            caseDescription: "Test Description",
            participantA: participantA,
            participantB: participantB,
            compensationA: 100 * 10 ** 18,
            compensationB: 100 * 10 ** 18,
            winnerIfEqualVotes: participantA,
            votingDuration: 1 days
        });
        vm.expectRevert("Sender is not a participant");
        realContract.addCase(newCase);
        vm.stopPrank();
    }
}
