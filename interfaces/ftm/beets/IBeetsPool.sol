// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";

interface IBeetsPool is IERC20 {
    function getNormalizedWeights() external view returns (uint256[] memory);

    function getPoolId() external view returns (bytes32);

    function getInvariant() external view returns (uint256);

    function getSwapFeePercentage() external view returns (uint256);
}
