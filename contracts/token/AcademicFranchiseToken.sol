// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {FranchiseToken} from "./FranchiseToken.sol";

/// @notice MVP académico: suscripción simulada y reparto mensual; sin dinero real.
contract AcademicFranchiseToken is FranchiseToken {
    enum ProjectStatus { Draft, Published, Operating, Closed }
    ProjectStatus public projectStatus;
    mapping(uint32 => bool) public distributedPeriod;

    event ProjectStatusChanged(ProjectStatus status);
    event MonthlyRevenueDistributed(uint32 indexed period, uint256 amount, uint256 supplyAtDistribution);
    error InvalidProjectTransition();
    error ProjectNotPurchasable();
    error ProjectNotOperating();
    error TransfersDisabled();
    error UseMonthlyDistribution();
    error InvalidPeriod();
    error PeriodAlreadyDistributed(uint32 period);

    constructor(
        string memory name_, string memory symbol_, uint256 maxSupply_,
        address registry_, address compliance_, address payment_, address owner_
    ) FranchiseToken(name_, symbol_, 0, maxSupply_, registry_, compliance_, payment_, address(0), owner_) {}

    function setProjectStatus(ProjectStatus next) external onlyOwner {
        ProjectStatus current = projectStatus;
        bool allowed = (current == ProjectStatus.Draft && next == ProjectStatus.Published)
            || (current == ProjectStatus.Published && (next == ProjectStatus.Operating || next == ProjectStatus.Closed))
            || (current == ProjectStatus.Operating && next == ProjectStatus.Closed);
        if (!allowed) revert InvalidProjectTransition();
        projectStatus = next;
        emit ProjectStatusChanged(next);
    }

    function mint(address to, uint256 amount) public override whenNotPaused {
        if (issuanceController == address(0)) revert InvalidIssuanceController(address(0));
        if (projectStatus != ProjectStatus.Published && projectStatus != ProjectStatus.Operating) revert ProjectNotPurchasable();
        if (this.isFrozen(to)) revert AddressIsFrozen(to);
        super.mint(to, amount);
    }

    function transfer(address, uint256) public pure override returns (bool) { revert TransfersDisabled(); }
    function transferFrom(address, address, uint256) public pure override returns (bool) { revert TransfersDisabled(); }

    /// @dev No se puede eludir el período usando la entrada heredada.
    function distributeRevenue(uint256, string memory) public pure override { revert UseMonthlyDistribution(); }

    function distributeMonthly(uint32 period, uint256 amount) external onlyAgent whenNotPaused {
        if (projectStatus != ProjectStatus.Operating) revert ProjectNotOperating();
        if (period / 100 < 2000 || period / 100 > 9999 || period % 100 == 0 || period % 100 > 12) revert InvalidPeriod();
        if (distributedPeriod[period]) revert PeriodAlreadyDistributed(period);
        distributedPeriod[period] = true;
        uint256 supply = totalSupply();
        super.distributeRevenue(amount, "Academic monthly revenue");
        emit MonthlyRevenueDistributed(period, amount, supply);
    }
}
