// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract KyeDaoBiddingModel is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public token;
    uint256 public totalSupply;
    uint256 public contributionAmount;
    uint256 public proposalDuration;
    uint256 public totalParticipants;

    struct Participant {
        uint256 balance;
        bool hasReceivedPayout;
        bool isActive;
    }

    struct Proposal {
        address proposer;
        uint256 startTime;
        uint256 endTime;
        address payoutRecipient;
        bool isComplete;
        uint256 totalContributions;
        mapping(address => bool) hasContributed;
    }

    mapping(address => Participant) public participants;
    mapping(uint256 => Proposal) public proposals;
    mapping(address => bool) public isDAOmember;

    uint256 public proposalCount;

    event Deposit(address indexed user, uint256 amount, uint256 proposalId);
    event Withdrawal(address indexed user, uint256 amount);
    event NewProposalCreated(uint256 indexed proposalId, address proposer, uint256 startTime, uint256 endTime);
    event PayoutDistributed(uint256 indexed proposalId, address indexed recipient, uint256 amount);

    modifier onlyDAOmember() {
        require(isDAOmember[msg.sender], "Only DAO members can perform this action");
        _;
    }

    constructor(
        address _tokenAddress,
        uint256 _contributionAmount,
        uint256 _proposalDuration
    ) {
        token = IERC20(_tokenAddress);
        contributionAmount = _contributionAmount;
        proposalDuration = _proposalDuration;
        isDAOmember[msg.sender] = true;
    }

    function joinAssociation() external nonReentrant {
        if (participants[msg.sender].isActive) revert AlreadyParticipant();
        
        token.safeTransferFrom(msg.sender, address(this), contributionAmount);
        participants[msg.sender] = Participant({
            balance: contributionAmount,
            hasReceivedPayout: false,
            isActive: true
        });
        totalParticipants++;
        totalSupply += contributionAmount;

        emit Deposit(msg.sender, contributionAmount);
    }

    function createProposal(address _payoutRecipient) external onlyDAOmember {
        require(_payoutRecipient != address(0), "Invalid payout recipient");
        require(participants[_payoutRecipient].isActive, "Recipient is not an active participant");
        require(!participants[_payoutRecipient].hasReceivedPayout, "Recipient has already received a payout");

        proposalCount++;
        Proposal storage newProposal = proposals[proposalCount];
        newProposal.proposer = msg.sender;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + proposalDuration;
        newProposal.payoutRecipient = _payoutRecipient;

        emit NewProposalCreated(proposalCount, msg.sender, newProposal.startTime, newProposal.endTime);
    }

    function contributeToProposal(uint256 _proposalId) external nonReentrant {
        require(participants[msg.sender].isActive, "Not a participant");
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp < proposal.endTime, "Proposal has ended");
        require(!proposal.hasContributed[msg.sender], "Already contributed to this proposal");

        token.safeTransferFrom(msg.sender, address(this), contributionAmount);
        proposal.hasContributed[msg.sender] = true;
        proposal.totalContributions += contributionAmount;
        totalSupply += contributionAmount;

        emit Deposit(msg.sender, contributionAmount, _proposalId);
    }

    function distributePayout(uint256 _proposalId) external onlyDAOmember {
        Proposal storage proposal = proposals[_proposalId];
        require(!proposal.isComplete, "Proposal already completed");
        require(block.timestamp >= proposal.endTime, "Proposal not ended yet");
        require(proposal.totalContributions == contributionAmount * totalParticipants, "Not all participants have contributed");

        uint256 payoutAmount = proposal.totalContributions;
        proposal.isComplete = true;
        participants[proposal.payoutRecipient].hasReceivedPayout = true;

        token.safeTransfer(proposal.payoutRecipient, payoutAmount);

        emit PayoutDistributed(_proposalId, proposal.payoutRecipient, payoutAmount);
    }

    function getProposalInfo(uint256 _proposalId) external view returns (
        address proposer,
        uint256 startTime,
        uint256 endTime,
        address payoutRecipient,
        bool isComplete,
        uint256 totalContributions
    ) {
        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.proposer,
            proposal.startTime,
            proposal.endTime,
            proposal.payoutRecipient,
            proposal.isComplete,
            proposal.totalContributions
        );
    }

    function hasContributedToProposal(uint256 _proposalId, address _participant) external view returns (bool) {
        return proposals[_proposalId].hasContributed[_participant];
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
