// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

contract RotatingCreditAssociation {

    struct Participant {
        bool isActive;
        uint256 contributionAmount;
        uint256 lastContributionRound;
        bool hasReceivedPayout;
    }

    struct Round {
        uint256 startTime;
        uint256 endTime;
        address payoutRecipient;
        bool isComplete;
        uint256 totalContributions;
    }

    address public admin;
    uint256 public roundDuration;
    uint256 public contributionAmount;
    uint256 public currentRound;
    uint256 public totalParticipants;

    mapping(address => Participant) public participants;
    mapping(uint256 => Round) public rounds;
    mapping(address => bool) public isDAOmember;

    modifier onlyDAOmember() {
        require(isDAOmember[msg.sender], "Only DAO members can perform this action");
        _;
    }

    constructor(uint256 _roundDuration, uint256 _contributionAmount) {
        admin = msg.sender;
        isDAOmember[admin] = true;
        roundDuration = _roundDuration;
        contributionAmount = _contributionAmount;
        currentRound = 0;
    }

    function joinAssociation() external payable {
        require(!participants[msg.sender].isActive, "Already a participant");
        require(msg.value == contributionAmount, "Incorrect contribution amount");

        participants[msg.sender] = Participant({
            isActive: true,
            contributionAmount: contributionAmount,
            lastContributionRound: currentRound,
            hasReceivedPayout: false
        });

        totalParticipants++;
    }

    function contribute() external payable {
        require(participants[msg.sender].isActive, "Not a participant");
        require(msg.value == contributionAmount, "Incorrect contribution amount");
        require(participants[msg.sender].lastContributionRound < currentRound, "Already contributed this round");

        participants[msg.sender].lastContributionRound = currentRound;
        rounds[currentRound].totalContributions += contributionAmount;
    }

    function startNewRound() external onlyDAOmember {
        require(block.timestamp >= rounds[currentRound].endTime, "Current round not finished");
        
        currentRound++;
        rounds[currentRound] = Round({
            startTime: block.timestamp,
            endTime: block.timestamp + roundDuration,
            payoutRecipient: address(0),
            isComplete: false,
            totalContributions: 0
        });
    }

    function distributeFunds() external onlyDAOmember {
        require(rounds[currentRound].totalContributions == contributionAmount * totalParticipants, "Not all participants have contributed");
        require(!rounds[currentRound].isComplete, "Round already completed");

        address payoutRecipient = getNextPayoutRecipient();
        require(payoutRecipient != address(0), "No eligible recipient found");

        rounds[currentRound].payoutRecipient = payoutRecipient;
        rounds[currentRound].isComplete = true;
        participants[payoutRecipient].hasReceivedPayout = true;

        payable(payoutRecipient).transfer(rounds[currentRound].totalContributions);
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
        // This function should be implemented to return the participant address at the given index
        // For simplicity, we're leaving it unimplemented in this example
        revert("Not implemented");
    }

    function addMember(address newMember) external onlyDAOmember {
        isDAOmember[newMember] = true;
    }

    function removeMember(address member) external onlyDAOmember {
        isDAOmember[member] = false;
    }

    function leaveAssociation() external {
        require(participants[msg.sender].isActive, "Not a participant");
        require(participants[msg.sender].hasReceivedPayout, "Cannot leave before receiving payout");

        participants[msg.sender].isActive = false;
        totalParticipants--;
    }

    function getParticipantInfo(address participant) external view returns (Participant memory) {
        return participants[participant];
    }

    function getRoundInfo(uint256 roundNumber) external view returns (Round memory) {
        return rounds[roundNumber];
    }
}
