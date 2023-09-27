// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {ISiloFacet} from "src/interfaces/ISiloFacet.sol";

interface IBeanstalkTest is ISiloFacet {
    function deposit(
        address token,
        uint256 amount,
        uint8 mode
    ) external returns (uint256 depositAmount, uint256 bdv, int96 stem);

    function balanceOf(
        address account, 
        uint256 depositId
    ) external view returns (uint256 amount);
}
