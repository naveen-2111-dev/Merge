// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract PrivateDAO {
    enum ProposalType { AddMember, RemoveMember, ChangeThreshold }

    struct Proposal {
        uint256 id;
        ProposalType proposalType;
        address proposer;
        address targetAddress;
        uint256 newThreshold;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 deadline;
        bool executed;
        mapping(address => bool) hasVoted;
    }

    mapping(address => bool) public members;
    address[] public membersList;
    uint256 public memberCount;
    uint256 public votingThreshold;
    uint256 public votingPeriod = 3 days;

    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCounter;

    event MemberAdded(address indexed member, address indexed addedBy);
    event MemberRemoved(address indexed member, address indexed removedBy);
    event ProposalCreated(uint256 indexed proposalId, ProposalType proposalType, address indexed proposer);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support);
    event ProposalExecuted(uint256 indexed proposalId, bool success);
    event ThresholdChanged(uint256 oldThreshold, uint256 newThreshold);

    modifier onlyMember() {
        require(members[msg.sender], "Only DAO members can call this");
        _;
    }

    modifier proposalExists(uint256 proposalId) {
        require(proposalId < proposalCounter, "Proposal does not exist");
        _;
    }

    modifier proposalActive(uint256 proposalId) {
        require(block.timestamp <= proposals[proposalId].deadline, "Proposal expired");
        require(!proposals[proposalId].executed, "Proposal already executed");
        _;
    }

    constructor(address[] memory _initialMembers, uint256 _votingThreshold) {
        require(_initialMembers.length > 0, "Must have at least one member");
        require(_votingThreshold > 0 && _votingThreshold <= _initialMembers.length, "Invalid threshold");
        
        for (uint256 i = 0; i < _initialMembers.length; i++) {
            require(_initialMembers[i] != address(0), "Invalid member address");
            require(!members[_initialMembers[i]], "Duplicate member");
            
            members[_initialMembers[i]] = true;
            membersList.push(_initialMembers[i]);
        }
        
        memberCount = _initialMembers.length;
        votingThreshold = _votingThreshold;
    }

    function proposeAddMember(address newMember) external onlyMember returns (uint256) {
        require(newMember != address(0), "Invalid member address");
        require(!members[newMember], "Already a member");

        uint256 proposalId = proposalCounter++;
        Proposal storage proposal = proposals[proposalId];
        
        proposal.id = proposalId;
        proposal.proposalType = ProposalType.AddMember;
        proposal.proposer = msg.sender;
        proposal.targetAddress = newMember;
        proposal.deadline = block.timestamp + votingPeriod;

        emit ProposalCreated(proposalId, ProposalType.AddMember, msg.sender);
        return proposalId;
    }

    function proposeRemoveMember(address memberToRemove) external onlyMember returns (uint256) {
        require(members[memberToRemove], "Not a member");
        require(memberCount > 1, "Cannot remove last member");

        uint256 proposalId = proposalCounter++;
        Proposal storage proposal = proposals[proposalId];
        
        proposal.id = proposalId;
        proposal.proposalType = ProposalType.RemoveMember;
        proposal.proposer = msg.sender;
        proposal.targetAddress = memberToRemove;
        proposal.deadline = block.timestamp + votingPeriod;

        emit ProposalCreated(proposalId, ProposalType.RemoveMember, msg.sender);
        return proposalId;
    }

    function proposeChangeThreshold(uint256 newThreshold) external onlyMember returns (uint256) {
        require(newThreshold > 0 && newThreshold <= memberCount, "Invalid threshold");

        uint256 proposalId = proposalCounter++;
        Proposal storage proposal = proposals[proposalId];
        
        proposal.id = proposalId;
        proposal.proposalType = ProposalType.ChangeThreshold;
        proposal.proposer = msg.sender;
        proposal.newThreshold = newThreshold;
        proposal.deadline = block.timestamp + votingPeriod;

        emit ProposalCreated(proposalId, ProposalType.ChangeThreshold, msg.sender);
        return proposalId;
    }

    function vote(uint256 proposalId, bool support) external 
        onlyMember 
        proposalExists(proposalId) 
        proposalActive(proposalId) 
    {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.hasVoted[msg.sender], "Already voted");

        proposal.hasVoted[msg.sender] = true;
        
        if (support) {
            proposal.votesFor++;
        } else {
            proposal.votesAgainst++;
        }

        emit Voted(proposalId, msg.sender, support);

        if (proposal.votesFor >= votingThreshold) {
            _executeProposal(proposalId);
        }
    }

    function executeProposal(uint256 proposalId) external proposalExists(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp > proposal.deadline || proposal.votesFor >= votingThreshold, "Cannot execute yet");
        require(!proposal.executed, "Already executed");
        require(proposal.votesFor >= votingThreshold, "Not enough votes");

        _executeProposal(proposalId);
    }

    function _executeProposal(uint256 proposalId) internal {
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;

        bool success = false;

        if (proposal.proposalType == ProposalType.AddMember) {
            members[proposal.targetAddress] = true;
            membersList.push(proposal.targetAddress);
            memberCount++;
            emit MemberAdded(proposal.targetAddress, proposal.proposer);
            success = true;

        } else if (proposal.proposalType == ProposalType.RemoveMember) {
            members[proposal.targetAddress] = false;
            
            for (uint256 i = 0; i < membersList.length; i++) {
                if (membersList[i] == proposal.targetAddress) {
                    membersList[i] = membersList[membersList.length - 1];
                    membersList.pop();
                    break;
                }
            }
            
            memberCount--;
            
            if (votingThreshold > memberCount) {
                uint256 oldThreshold = votingThreshold;
                votingThreshold = memberCount;
                emit ThresholdChanged(oldThreshold, votingThreshold);
            }
            
            emit MemberRemoved(proposal.targetAddress, proposal.proposer);
            success = true;

        } else if (proposal.proposalType == ProposalType.ChangeThreshold) {
            uint256 oldThreshold = votingThreshold;
            votingThreshold = proposal.newThreshold;
            emit ThresholdChanged(oldThreshold, proposal.newThreshold);
            success = true;
        }

        emit ProposalExecuted(proposalId, success);
    }

    function isMember(address account) external view returns (bool) {
        return members[account];
    }

    function getMemberCount() external view returns (uint256) {
        return memberCount;
    }

    function getVotingThreshold() external view returns (uint256) {
        return votingThreshold;
    }

    function getMembers() external view returns (address[] memory) {
        return membersList;
    }

    function getProposal(uint256 proposalId) external view returns (
        uint256 id,
        ProposalType proposalType,
        address proposer,
        address targetAddress,
        uint256 newThreshold,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 deadline,
        bool executed
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.id,
            proposal.proposalType,
            proposal.proposer,
            proposal.targetAddress,
            proposal.newThreshold,
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.deadline,
            proposal.executed
        );
    }

    function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }
}