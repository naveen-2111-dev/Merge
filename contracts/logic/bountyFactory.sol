// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./bounty.sol";
import "../treatury/privateDao.sol";

contract DAOBountyFactory {
    event DAOBountySystemCreated(
        address indexed dao,
        address indexed treasury,
        address indexed bountyPool,
        address creator
    );

    struct DAOBountySystem {
        address dao;
        address treasury;
        address bountyPool;
    }

    mapping(address => DAOBountySystem[]) public userSystems;

    function createDAOBountySystem(
        address[] memory initialMembers,
        uint256 votingThreshold,
        string memory repoUrl,
        BountyPool.Rule[] memory rules
    )
        external
        payable
        returns (address dao, address treasury, address bountyPool)
    {
        dao = address(new PrivateDAO(initialMembers, votingThreshold));

        treasury = address(new Treasury(dao));

        bountyPool = address(new BountyPool(dao, treasury, repoUrl, rules));

        if (msg.value > 0) {
            Treasury(payable(treasury)).fund{value: msg.value}();
        }

        userSystems[msg.sender].push(
            DAOBountySystem({
                dao: dao,
                treasury: treasury,
                bountyPool: bountyPool
            })
        );

        emit DAOBountySystemCreated(dao, treasury, bountyPool, msg.sender);

        return (dao, treasury, bountyPool);
    }

    function getUserSystems(
        address user
    ) external view returns (DAOBountySystem[] memory) {
        return userSystems[user];
    }
}
