// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IVoter.sol";
import "./interfaces/IRealContract.sol";
import "./Governance.sol";
import "./CaseManager.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract RealContract is
    Governance,
    CaseManager,
    IRealContract,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    IVoter public immutable voter;

    address public participantA;
    address public participantB;

    bool public running;

    IERC20 public immutable compensationToken;

    uint256 public feeRateForStakeCompensation;
    uint256 public feeRateForExecuteCase;

    constructor(
        address _owner,
        address _voter,
        address _compensationToken,
        address _participantA,
        address _participantB,
        uint256 _feeRateForStakeCompensation,
        uint256 _feeRateForExecuteCase
    ) Governance(_owner) {
        voter = IVoter(_voter);
        compensationToken = IERC20(_compensationToken);
        participantA = _participantA;
        participantB = _participantB;
        running = true;
        feeRateForStakeCompensation = _feeRateForStakeCompensation;
        feeRateForExecuteCase = _feeRateForExecuteCase;
    }

    modifier onlyParticipantOrGovernance() {
        require(
            msg.sender == participantA ||
                msg.sender == participantB ||
                msg.sender == governance,
            "Sender is not a participant or governance"
        );
        _;
    }

    modifier onlyParticipant() {
        require(
            msg.sender == participantA || msg.sender == participantB,
            "Sender is not a participant"
        );
        _;
    }

    modifier onlyRunning() {
        require(running, "Contract is not running");
        _;
    }

    function setRunning(bool _running) public onlyGovernance {
        running = _running;
        emit ContractStatusChanged(_running);
    }

    // 添加案件
    function addCases(
        CaseInit[] calldata _cases
    ) public override onlyParticipant onlyRunning {
        for (uint i = 0; i < _cases.length; i++) {
            _checkCase(_cases[i]);
            _addCase(_cases[i]);
        }
    }

    // 添加案件
    function addCase(
        CaseInit calldata _case
    ) public override onlyParticipant onlyRunning {
        _checkCase(_case);
        _addCase(_case);
    }

    // stake compensation
    function stakeCompensation(
        uint256 _caseNum,
        bool _payA
    ) public onlyRunning nonReentrant {
        _stakeCompensation(_caseNum, compensationToken, _payA);

        if (_payA && cases[_caseNum].compensationA > 0) {
            // 收取手續費
            uint256 feeA = (cases[_caseNum].compensationA *
                feeRateForStakeCompensation) / 10000;
            // safeTransferFrom compensationToken to this contract
            compensationToken.safeTransferFrom(msg.sender, address(this), feeA);
            emit CaseStaked(
                _caseNum,
                msg.sender,
                cases[_caseNum].compensationA
            );
        } else if (!_payA && cases[_caseNum].compensationB > 0) {
            // 收取手續費
            uint256 feeB = (cases[_caseNum].compensationB *
                feeRateForStakeCompensation) / 10000;
            // safeTransferFrom compensationToken to this contract
            compensationToken.safeTransferFrom(msg.sender, address(this), feeB);
            emit CaseStaked(
                _caseNum,
                msg.sender,
                cases[_caseNum].compensationB
            );
        }
    }

    // 查詢當前案件結果
    function getCaseResult(
        uint256 _caseNum
    ) external view returns (CaseResult memory) {
        return _getCaseResult(_caseNum, participantA, participantB);
    }

    // 啟動案件投票
    function startCaseVoting(
        uint256 _caseNum
    ) public onlyParticipant onlyRunning {
        require(
            cases[_caseNum].status == CaseStatus.Activated,
            "Case is not activated"
        );
        _startCaseVoting(_caseNum);
        emit CaseVotingStarted(_caseNum);
    }

    // 案件投票
    function vote(uint256 _caseNum, address _voteFor) public onlyRunning {
        require(
            cases[_caseNum].status == CaseStatus.Voting,
            "Case is not voting"
        );

        require(
            block.timestamp <
                cases[_caseNum].votingStartTime +
                    cases[_caseNum].votingDuration,
            "Voting duration has ended"
        );

        require(
            cases[_caseNum].voterIsVoted[msg.sender] == false,
            "Voter has already voted"
        );
        cases[_caseNum].voterIsVoted[msg.sender] = true;
        cases[_caseNum].voters.push(msg.sender);
        cases[_caseNum].voterVotes[_voteFor]++;

        emit CaseVoted(_caseNum, msg.sender, _voteFor);
    }

    // 執行案件
    function executeCase(
        uint256 _caseNum
    ) public onlyParticipantOrGovernance onlyRunning {
        require(
            cases[_caseNum].status == CaseStatus.WaitingForExecution ||
                (cases[_caseNum].status == CaseStatus.Voting &&
                    block.timestamp >
                    cases[_caseNum].votingStartTime +
                        cases[_caseNum].votingDuration),
            "Case is not waiting for execution"
        );

        _executeCase(_caseNum, participantA, participantB);

        // 收取手續費
        uint256 feeA = (cases[_caseNum].compensationA * feeRateForExecuteCase) /
            10000;
        uint256 feeB = (cases[_caseNum].compensationB * feeRateForExecuteCase) /
            10000;

        // 轉移代幣給勝者
        if (cases[_caseNum].winner == participantA) {
            compensationToken.transfer(
                participantA,
                cases[_caseNum].compensationA - feeA
            );
            compensationToken.transfer(
                participantB,
                cases[_caseNum].compensationB - feeB
            );
        } else if (cases[_caseNum].winner == participantB) {
            compensationToken.transfer(
                participantB,
                cases[_caseNum].compensationB - feeB
            );
            compensationToken.transfer(
                participantA,
                cases[_caseNum].compensationA - feeA
            );
        }

        emit CaseExecuted(_caseNum, cases[_caseNum].winner);
    }

    // 檢查案件
    function _checkCase(CaseInit calldata _case) internal view {
        require(
            _case.participantA == participantA ||
                _case.participantA == participantB,
            "Participant A is not a participant"
        );
        require(
            _case.participantB == participantA ||
                _case.participantB == participantB,
            "Participant B is not a participant"
        );
        require(
            _case.compensationA > 0 && _case.compensationB > 0,
            "Compensation must be greater than 0"
        );

        require(
            _case.votingDuration > 0,
            "Voting duration must be greater than 0"
        );

        require(
            _case.winnerIfEqualVotes == _case.participantA ||
                _case.winnerIfEqualVotes == _case.participantB,
            "Winner if equal votes must be a participant"
        );
    }

    function cancelCase(uint256 _caseNum) public onlyParticipantOrGovernance {
        require(
            cases[_caseNum].status == CaseStatus.Activated ||
                cases[_caseNum].status == CaseStatus.Inactivated,
            "Case is not activated or inactivated"
        );

        bool sweepCompensation = _cancelCase(_caseNum);

        if (sweepCompensation) {
            //sweep compensation
            if (cases[_caseNum].isPaidA && cases[_caseNum].compensationA > 0) {
                compensationToken.safeTransfer(
                    participantA,
                    cases[_caseNum].compensationA
                );
            }
            if (cases[_caseNum].isPaidB && cases[_caseNum].compensationB > 0) {
                compensationToken.safeTransfer(
                    participantB,
                    cases[_caseNum].compensationB
                );
            }
        }
        emit CaseCancelled(_caseNum);
    }
}
