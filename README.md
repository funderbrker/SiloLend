# SiLend

## What it is
SiLend is a lending system for Beanstalk Silo deposits. It enables users to use their Bean Deposits as collateral to borrow liquid Bean.

## Approach
The protocol is intentionally designed to be as simple as possible. This enables quick and secure shipping of a tool with immediate value.

## How does it is work
SiLend offers a single pool. That pool pairs one supply token to one collateral token. The supply is Beans (ERC20) and the collateral is Bean Deposits (ERC1155). A user can take an undercollateralized Bean loan against their Bean deposit. They will owe interest on their loan, but their deposit will continue to accrue Stalk (i.e. ownership in Beanstalk). The supplier will earn immediate interest, regardless of the performance of the Silo.

A bean deposit can always be converted into a known number of Beans. This means that there is no need to use oracles or external liquidation mechanisms, significantly reducing complexity and smart contract risk. It also allows the pool to offer loans with very high utilization rates (90%). 

## Who will use it?
**Lenders** - Users who are comfortable with exposure to Bean risk but want to see immediate yield on their capital.

**Borrowers** - Users who are long term bullish on Beanstalk but want to unlock their capital investment in the short term.
