// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AcademicFranchiseToken} from "../token/AcademicFranchiseToken.sol";
import {InvestmentAgreement} from "../agreements/InvestmentAgreement.sol";
import {PlatformServicesAgreement} from "../agreements/PlatformServicesAgreement.sol";

// Separar el bytecode de creación mantiene cada contrato por debajo del límite EIP-170.
contract AcademicTokenDeployer {
    address private immutable factory = msg.sender;
    function create(string calldata name_,string calldata symbol_,uint256 supply,address registry,address compliance,address payment) external returns(AcademicFranchiseToken) {
        require(msg.sender == factory, "Only factory");
        return new AcademicFranchiseToken(name_,symbol_,supply,registry,compliance,payment,factory);
    }
}
contract AcademicInvestmentDeployer {
    address private immutable factory = msg.sender;
    function create(address trust,address token,address services,address verifier) external returns(InvestmentAgreement) {
        require(msg.sender == factory, "Only factory");
        return new InvestmentAgreement(trust,token,services,verifier,1000,keccak256("MVP: ingresos variables mensuales, prorrata al distribuir, sin transferencias"));
    }
}

/// @notice Publicación idempotente de proyectos de demostración. Nunca recibe DNI ni datos privados.
contract AcademicProjectFactory is Ownable {
    AcademicTokenDeployer private immutable tokenDeployer;
    AcademicInvestmentDeployer private immutable investmentDeployer;
    address public immutable registry;
    address public immutable payment;
    address public immutable services;
    address public immutable trust;
    address public immutable verifier;
    mapping(bytes32 => address) public projectToken;
    mapping(bytes32 => address) public projectInvestment;
    mapping(bytes32 => bytes32) public configuration;
    event ProjectCreated(bytes32 indexed key, address token, address investment);
    error InvalidConfiguration();
    constructor(address admin_, address registry_, address payment_, address services_, address verifier_) Ownable(admin_) {
        PlatformServicesAgreement c3 = PlatformServicesAgreement(services_);
        if (registry_ == address(0) || payment_ == address(0) || verifier_ == address(0) || c3.currency() != bytes3("USD") || c3.currencyDecimals() != 2) revert InvalidConfiguration();
        tokenDeployer=new AcademicTokenDeployer(); investmentDeployer=new AcademicInvestmentDeployer();
        registry=registry_; payment=payment_; services=services_; trust=c3.trust(); verifier=verifier_;
    }
    function createProject(bytes32 key, string calldata name_, string calldata symbol_, uint256 supply, address compliance) external onlyOwner returns(address, address) {
        if (key == bytes32(0) || bytes(name_).length == 0 || bytes(symbol_).length == 0 || supply == 0 || supply > 1_000_000 || compliance == address(0)) revert InvalidConfiguration();
        bytes32 config=keccak256(abi.encode(name_,symbol_,supply));
        if (projectToken[key] != address(0)) {
            if (configuration[key] != config) revert InvalidConfiguration();
            return(projectToken[key],projectInvestment[key]);
        }
        AcademicFranchiseToken token=tokenDeployer.create(name_,symbol_,supply,registry,compliance,payment);
        InvestmentAgreement investment=investmentDeployer.create(trust,address(token),services,verifier);
        token.addAgent(address(investment)); token.setIssuanceController(address(investment)); token.addAgent(owner());
        token.setProjectStatus(AcademicFranchiseToken.ProjectStatus.Published); token.transferOwnership(owner());
        projectToken[key]=address(token); projectInvestment[key]=address(investment); configuration[key]=config;
        emit ProjectCreated(key,address(token),address(investment));
        return(address(token),address(investment));
    }
}
