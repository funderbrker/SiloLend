// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface ISiloFacet {
    function getDepositId(address token, int96 stem) external pure returns (uint256);

    function stemTipForToken(address token) external view returns (int96 _stemTip);

    function withdrawDeposit(address token, int96 stem, uint256 amount, uint8 mode) external payable;
}
