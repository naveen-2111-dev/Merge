// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IDAO {
    function isMember(address account) external view returns (bool);
    function getMemberCount() external view returns (uint256);
    function getVotingThreshold() external view returns (uint256);
}