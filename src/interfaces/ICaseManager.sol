// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ICaseManager {
    enum CaseStatus {
        //未啟動
        Inactivated,
        //啟動
        Activated,
        //投票中
        Voting,
        //放棄
        Abandoned,
        //等待執行
        WaitingForExecution,
        //已執行
        Executed
    }

    struct Case {
        // 案件編號
        uint256 caseNum;
        // 案件名稱
        string caseName;
        // 案件描述
        string caseDescription;
        // 賠償金額
        uint256 compensationA;
        uint256 compensationB;
        // 是否已支付
        bool isPaidA;
        bool isPaidB;
        // 勝者
        address winner;
        // 狀態
        CaseStatus status;
        // 投票開始時間
        uint256 votingStartTime;
        // voting duration
        uint256 votingDuration;
        // 已投票者
        mapping(address => bool) voterIsVoted;
        // 投票者
        address[] voters;
        // 投票紀錄
        mapping(address => uint256) voterVotes;
        // 平手時的勝者
        address winnerIfEqualVotes;
    }

    struct CaseInit {
        // 案件名稱
        string caseName;
        // 案件描述
        string caseDescription;
        // 賠償金額
        uint256 compensationA;
        uint256 compensationB;
        // 平手時的勝者
        address winnerIfEqualVotes;
        // voting duration
        uint256 votingDuration;
    }

    struct CaseResult {
        // 案件編號
        uint256 caseNum;
        // 勝者
        address currentWinner;
        // 賠償金額
        uint256 compensationA;
        uint256 compensationB;
        // 得票數A
        uint256 voteCountA;
        // 得票數B
        uint256 voteCountB;
        bool voteEnded;
    }

    struct CancelCaseRequest {
        uint256 caseNum;
        uint8 approveCount;
        mapping(address => bool) approved;
    }

    function getCaseStatus(uint256 caseNum) external view returns (CaseStatus);

    function getCaseDescription(
        uint256 caseNum
    ) external view returns (string memory);

    function getCaseCompensationA(
        uint256 caseNum
    ) external view returns (uint256);

    function getCaseCompensationB(
        uint256 caseNum
    ) external view returns (uint256);

    function getCaseWinner(uint256 caseNum) external view returns (address);

    function getCaseVotingDuration(
        uint256 caseNum
    ) external view returns (uint256);

    function getCaseVotersCount(
        uint256 caseNum
    ) external view returns (uint256);

    function getCaseVoterVotes(
        uint256 caseNum,
        address voter
    ) external view returns (uint256);

    function getCaseIsPaidA(uint256 caseNum) external view returns (bool);
}
