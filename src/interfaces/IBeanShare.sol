// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IBeanShare {
    function addSupply(uint256 amount) external;

    function removeSupply(uint256 amount) external;

    function addBorrow(uint256 amount) external;

    function removeBorrow(uint256 amount) external;

    function addCollateral(uint256[] calldata ids, uint256[] calldata values) external;

    function removeCollateral(uint256[] calldata ids, uint256[] calldata values) external;

    function terminate(address borrower, uint256[] calldata depositIds) external;

    function withdrawReserves(address to, uint256 amount) external;

    function getUserSupplyBalance(address user) external view returns (uint256);

    function getUserBorrowBalance(address user) external view returns (uint256);

    function getUserCollateralBalance(address user) external view returns (uint256);

    function getSupplyRate(uint256 utilization) external view returns (uint256);

    function getBorrowRate(uint256 utilization) external view returns (uint256);

    function getUtilization() external view returns (uint256);

    function getReserves() external view returns (uint256);
}
