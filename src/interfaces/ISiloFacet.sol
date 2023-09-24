// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface ISiloFacet {
    function getDepositId(address token, int96 stem) external pure returns (uint256);

    function stemTipForToken(address token) external view returns (int96 _stemTip);

    function withdrawDeposit(
        address token,
        int96 stem,
        uint256 amount,
        uint8 mode
    ) external payable;

    // APPROVAL FACET.
    // Beanstalk implements this but doesn't actually use it.
    // function setApprovalForAll(address spender, bool approved) external;

    // APPROVAL FACET.
    function approveDeposit(address spender, address token, uint256 amount) external;
}
