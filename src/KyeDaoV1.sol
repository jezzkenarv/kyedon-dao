// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract KyeDaoRotatingRound is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public token;
    uint256 public totalSupply;
    uint256 public contributionAmount;
    uint256 public roundDuration;
    uint256 public currentRound;
    uint256 public totalParticipants;

    struct Participant {
        uint256 balance;
        uint256 lastContributionRound;
        bool hasReceivedPayout;
        bool isActive;
    }

    struct Round {
        uint256 startTime;
        uint256 endTime;
        address payoutRecipient;
        bool isComplete;
        uint256 totalContributions;
    }

    mapping(address => Participant) public participants;
    mapping(uint256 => Round) public rounds;
    mapping(address => bool) public isDAOmember;

    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event NewRoundStarted(uint256 indexed roundNumber, uint256 startTime, uint256 endTime);
    event PayoutDistributed(address indexed recipient, uint256 amount);

    modifier onlyDAOmember() {
        require(isDAOmember[msg.sender], "Only DAO members can perform this action");
        _;
    }

    constructor(
        address _tokenAddress,
        uint256 _contributionAmount,
        uint256 _roundDuration
    ) {
        token = IERC20(_tokenAddress);
        contributionAmount = _contributionAmount;
        roundDuration = _roundDuration;
        currentRound = 0;
        isDAOmember[msg.sender] = true;

        startNewRound();
    }

    function joinAssociation() external nonReentrant {
        if (participants[msg.sender].isActive) revert AlreadyParticipant();
        
        token.safeTransferFrom(msg.sender, address(this), contributionAmount);
        participants[msg.sender] = Participant({
            balance: contributionAmount,
            lastContributionRound: currentRound,
            hasReceivedPayout: false,
            isActive: true
        });
        totalParticipants++;
        totalSupply += contributionAmount;

        emit Deposit(msg.sender, contributionAmount);
    }

    function contribute() external nonReentrant {
        require(participants[msg.sender].isActive, "Not a participant");
        require(participants[msg.sender].lastContributionRound < currentRound, "Already contributed this round");

        token.safeTransferFrom(msg.sender, address(this), contributionAmount);
        participants[msg.sender].lastContributionRound = currentRound;
        rounds[currentRound].totalContributions += contributionAmount;
        totalSupply += contributionAmount;

        emit Deposit(msg.sender, contributionAmount);
    }

    function startNewRound() public onlyDAOmember {
        require(block.timestamp >= rounds[currentRound].endTime, "Current round not finished");
        
        currentRound++;
        rounds[currentRound] = Round({
            startTime: block.timestamp,
            endTime: block.timestamp + roundDuration,
            payoutRecipient: address(0),
            isComplete: false,
            totalContributions: 0
        });

        emit NewRoundStarted(currentRound, rounds[currentRound].startTime, rounds[currentRound].endTime);
    }

    function distributePayout() external onlyDAOmember {
        require(!rounds[currentRound].isComplete, "Round already completed");
        require(rounds[currentRound].totalContributions == contributionAmount * totalParticipants, "Not all participants have contributed");

        address payoutRecipient = getNextPayoutRecipient();
        require(payoutRecipient != address(0), "No eligible recipient found");

        uint256 payoutAmount = rounds[currentRound].totalContributions;
        rounds[currentRound].payoutRecipient = payoutRecipient;
        rounds[currentRound].isComplete = true;
        participants[payoutRecipient].hasReceivedPayout = true;

        token.safeTransfer(payoutRecipient, payoutAmount);

        emit PayoutDistributed(payoutRecipient, payoutAmount);
    }

    function getNextPayoutRecipient() internal view returns (address) {
        for (uint256 i = 0; i < totalParticipants; i++) {
            address participant = getParticipantAtIndex(i);
            if (participants[participant].isActive && !participants[participant].hasReceivedPayout) {
                return participant;
            }
        }
        return address(0);
    }

    function getParticipantAtIndex(uint256 index) internal view returns (address) {
        // Implementation left as an exercise
        revert("Not implemented");
    }

    function leaveAssociation() external nonReentrant {
        require(participants[msg.sender].isActive, "Not a participant");
        require(participants[msg.sender].hasReceivedPayout, "Cannot leave before receiving payout");

        uint256 balance = participants[msg.sender].balance;
        participants[msg.sender].isActive = false;
        participants[msg.sender].balance = 0;
        totalParticipants--;
        totalSupply -= balance;

        token.safeTransfer(msg.sender, balance);

        emit Withdrawal(msg.sender, balance);
    }

    function addMember(address newMember) external onlyOwner {
        isDAOmember[newMember] = true;
    }

    function removeMember(address member) external onlyOwner {
        isDAOmember[member] = false;
    }

    function setContributionAmount(uint256 _newAmount) external onlyOwner {
        require(_newAmount > 0, "Invalid contribution amount");
        contributionAmount = _newAmount;
    }

    function setRoundDuration(uint256 _newDuration) external onlyOwner {
        require(_newDuration > 0, "Invalid round duration");
        roundDuration = _newDuration;
    }

    function getParticipantInfo(address participant) external view returns (Participant memory) {
        return participants[participant];
    }

    function getRoundInfo(uint256 roundNumber) external view returns (Round memory) {
        return rounds[roundNumber];
    }
}
