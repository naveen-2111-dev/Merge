// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../interface/interface.sol";

contract Treasury {
    enum ProposalType {
        Withdraw
    }

    struct WithdrawProposal {
        uint256 id;
        address proposer;
        address to;
        uint256 amount;
        string reason;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 deadline;
        bool executed;
        mapping(address => bool) hasVoted;
    }

    IDAO public dao;
    mapping(uint256 => WithdrawProposal) public withdrawProposals;
    uint256 public proposalCounter;
    uint256 public votingPeriod = 3 days;

    event Funded(address indexed funder, uint256 amount);
    event WithdrawProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        address to,
        uint256 amount
    );
    event WithdrawVoted(
        uint256 indexed proposalId,
        address indexed voter,
        bool support
    );
    event WithdrawExecuted(
        uint256 indexed proposalId,
        address to,
        uint256 amount
    );

    modifier onlyDAOMember() {
        require(dao.isMember(msg.sender), "Only DAO members can call this");
        _;
    }

    constructor(address _dao) {
        dao = IDAO(_dao);
    }

    function fund() external payable {
        emit Funded(msg.sender, msg.value);
    }

    function proposeWithdraw(
        address to,
        uint256 amount,
        string memory reason
    ) external onlyDAOMember returns (uint256) {
        require(to != address(0), "Invalid address");
        require(
            amount > 0 && amount <= address(this).balance,
            "Invalid amount"
        );

        uint256 proposalId = proposalCounter++;
        WithdrawProposal storage proposal = withdrawProposals[proposalId];

        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.to = to;
        proposal.amount = amount;
        proposal.reason = reason;
        proposal.deadline = block.timestamp + votingPeriod;

        emit WithdrawProposalCreated(proposalId, msg.sender, to, amount);
        return proposalId;
    }

    function voteWithdraw(
        uint256 proposalId,
        bool support
    ) external onlyDAOMember {
        WithdrawProposal storage proposal = withdrawProposals[proposalId];
        require(proposal.id == proposalId, "Proposal does not exist");
        require(block.timestamp <= proposal.deadline, "Proposal expired");
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.hasVoted[msg.sender], "Already voted");

        proposal.hasVoted[msg.sender] = true;

        if (support) {
            proposal.votesFor++;
        } else {
            proposal.votesAgainst++;
        }

        emit WithdrawVoted(proposalId, msg.sender, support);

        if (proposal.votesFor >= dao.getVotingThreshold()) {
            _executeWithdraw(proposalId);
        }
    }

    function executeWithdraw(uint256 proposalId) external {
        WithdrawProposal storage proposal = withdrawProposals[proposalId];
        require(proposal.id == proposalId, "Proposal does not exist");
        require(
            block.timestamp > proposal.deadline ||
                proposal.votesFor >= dao.getVotingThreshold(),
            "Cannot execute yet"
        );
        require(!proposal.executed, "Already executed");
        require(
            proposal.votesFor >= dao.getVotingThreshold(),
            "Not enough votes"
        );

        _executeWithdraw(proposalId);
    }

    function _executeWithdraw(uint256 proposalId) internal {
        WithdrawProposal storage proposal = withdrawProposals[proposalId];
        proposal.executed = true;

        if (proposal.amount <= address(this).balance) {
            payable(proposal.to).transfer(proposal.amount);
            emit WithdrawExecuted(proposalId, proposal.to, proposal.amount);
        }
    }

    function getWithdrawProposal(
        uint256 proposalId
    )
        external
        view
        returns (
            uint256 id,
            address proposer,
            address to,
            uint256 amount,
            string memory reason,
            uint256 votesFor,
            uint256 votesAgainst,
            uint256 deadline,
            bool executed
        )
    {
        WithdrawProposal storage proposal = withdrawProposals[proposalId];
        return (
            proposal.id,
            proposal.proposer,
            proposal.to,
            proposal.amount,
            proposal.reason,
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.deadline,
            proposal.executed
        );
    }
}
