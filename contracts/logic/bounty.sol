// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interface/interface.sol";
import "../treatury/treatury.sol";

contract BountyPool {
    enum PRStatus {
        Submitted,
        Approved,
        Rejected,
        Paid
    }
    enum RuleType {
        PRMerged,
        HasLabel,
        ToBranch
    }

    struct Rule {
        RuleType ruleType;
        string value;
    }

    struct Contribution {
        address contributor;
        string prUrl;
        string prTitle;
        string commitHash;
        uint256 timestamp;
        uint256 reward;
        PRStatus status;
    }

    IDAO public dao;
    Treasury public treasury;
    string public repoUrl;
    Rule[] public rules;
    mapping(bytes32 => Contribution) public contributions;
    uint256 public totalPaid;

    event ContributionSubmitted(
        bytes32 prKey,
        address indexed contributor,
        uint256 reward
    );
    event ContributionApproved(bytes32 prKey, uint256 reward);
    event ContributionRejected(bytes32 prKey);

    modifier onlyDAOMember() {
        require(dao.isMember(msg.sender), "Only DAO members can call this");
        _;
    }

    constructor(
        address _dao,
        address _treasury,
        string memory _repoUrl,
        Rule[] memory _rules
    ) {
        dao = IDAO(_dao);
        treasury = Treasury(payable(_treasury));
        repoUrl = _repoUrl;

        for (uint256 i = 0; i < _rules.length; i++) {
            rules.push(_rules[i]);
        }
    }

    function submitPR(
        string memory prUrl,
        string memory prTitle,
        string memory commitHash,
        address contributor,
        uint256 reward
    ) external onlyDAOMember {
        bytes32 prKey = keccak256(abi.encodePacked(prUrl));
        require(contributions[prKey].timestamp == 0, "PR already submitted");

        contributions[prKey] = Contribution({
            contributor: contributor,
            prUrl: prUrl,
            prTitle: prTitle,
            commitHash: commitHash,
            timestamp: block.timestamp,
            reward: reward,
            status: PRStatus.Submitted
        });

        emit ContributionSubmitted(prKey, contributor, reward);
    }

    function approveAndPayPR(bytes32 prKey) external onlyDAOMember {
        Contribution storage c = contributions[prKey];
        require(c.status == PRStatus.Submitted, "Not in submitted state");
        require(
            c.reward <= address(treasury).balance,
            "Insufficient treasury balance"
        );

        c.status = PRStatus.Paid;
        totalPaid += c.reward;

        // Request payment from treasury
        treasury.proposeWithdraw(c.contributor, c.reward, "Bounty payment");

        emit ContributionApproved(prKey, c.reward);
    }

    function rejectPR(bytes32 prKey) external onlyDAOMember {
        Contribution storage c = contributions[prKey];
        require(c.status == PRStatus.Submitted, "Not in submitted state");

        c.status = PRStatus.Rejected;
        emit ContributionRejected(prKey);
    }

    function getRules() external view returns (Rule[] memory) {
        return rules;
    }

    function getContribution(
        bytes32 prKey
    ) external view returns (Contribution memory) {
        return contributions[prKey];
    }
}
