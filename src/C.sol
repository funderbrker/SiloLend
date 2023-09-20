// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

library C {
    uint256 internal constant FACTOR = 1e18;
    uint256 internal constant FACTOR_INDEX = 1e10;

    uint256 internal constant ETH_DECIMALS = 18;

    address internal constant BEAN = address(0xBEA0000029AD1c77D3d5D23Ba2D8893dB9d1Efab);
    address internal constant BEAN_DEPOSIT = address(0xC1E088fC1323b20BCBee9bd1B9fC9546db5624C5);

    // AUDIT should I use the immutable facet or upgradeable Beanstalk?
    // address internal constant BEANSTALK = address(0xC1E088fC1323b20BCBee9bd1B9fC9546db5624C5);
    address internal constant SILO_FACET = address(0xf4B3629D1aa74eF8ab53Cc22728896B960F3a74E);
}
