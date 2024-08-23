// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

contract PooledLendingDao {

    struct Proposal {
        address borrower;
        uint256 amount;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
    }

    struct Loan {
        address borrower;
        uint256 amount;
        uint256 startTime;
        uint256 duration;
        bool repaid;
    }

    address public admin;
    mapping(address => uint256) public poolBalances;
    uint256 public totalPoolBalance;
    uint256 public proposalCount;
    uint256 public loanCount;

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => Loan) public loans;

    mapping(address => uint256) public reputationScores;
    mapping(address => bool) public isDAOmember;
    
    uint256 public minReputation = 50;
    uint256 public maxLoanDuration = 365 days;

    constructor() {
        admin = msg.sender;
        isDAOmember[admin] = true;
    }

    function deposit() external payable {
        require(msg.value > 0, "Must send some ether");
        poolBalances[msg.sender] += msg.value;
        totalPoolBalance += msg.value;
        // emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        require(poolBalances[msg.sender] >= amount, "Insufficient balance");
        poolBalances[msg.sender] -= amount;
        totalPoolBalance -= amount;
        payable(msg.sender).transfer(amount);
        // emit Withdrawal(msg.sender, amount);
    }

    function createProposal(address borrower, uint256 amount, string memory description) external onlyDAOmember {
        require(reputationScores[borrower] >= minReputation, "Borrower lacks sufficient reputation");
        require(amount <= totalPoolBalance / 2, "Cannot borrow more than 50% of the pool");
        
        proposals[proposalCount] = Proposal({
            borrower: borrower,
            amount: amount,
            description: description,
            votesFor: 0,
            votesAgainst: 0,
            executed: false
        });
    }

    function voteOnProposal(uint256 proposalId, bool support) external onlyDAOmember {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Proposal already executed");
        
        if (support) {
            proposal.votesFor++;
        } else {
            proposal.votesAgainst++;
        }
    }

    function executeProposal(uint256 proposalId) external onlyDAOmember {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Proposal already executed");
        require(proposal.votesFor > proposal.votesAgainst, "Proposal not approved");

        proposal.executed = true;
        loans[loanCount] = Loan({
            borrower: proposal.borrower,
            amount: proposal.amount,
            startTime: block.timestamp,
            duration: maxLoanDuration,
            repaid: false
        });

        totalPoolBalance -= proposal.amount;
        loanCount++;
        emit LoanApproval(proposalId);
        emit ProposalExecuted(proposalId);
        
        payable(proposal.borrower).transfer(proposal.amount);
    }

    function repayLoan(uint256 loanId) external payable {
        Loan storage loan = loans[loanId];
        require(msg.sender == loan.borrower, "Not the borrower");
        require(msg.value >= loan.amount, "Repayment amount too low");
        require(!loan.repaid, "Loan already repaid");

        loan.repaid = true;
        poolBalances[address(this)] += msg.value;
        totalPoolBalance += msg.value;
        reputationScores[msg.sender] += 10;  // Reward for timely repayment

        // emit LoanRepaid(loanId);
    }

    function addMember(address newMember) external onlyDAOmember {
        isDAOmember[newMember] = true;
    }

    function removeMember(address member) external onlyDAOmember {
        isDAOmember[member] = false;
    }

    function getReputation(address user) external view returns (uint256) {
        return reputationScores[user];
    }

    function adjustReputation(address user, int256 change) external onlyDAOmember {
        uint256 currentReputation = reputationScores[user];
        if (change < 0) {
            reputationScores[user] = currentReputation - uint256(-change);
        } else {
            reputationScores[user] = currentReputation + uint256(change);
        }
    }

    function getLoanDetails(uint256 loanId) external view returns (Loan memory) {
        return loans[loanId];
    }


    
}
