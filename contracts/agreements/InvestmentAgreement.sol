// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {FranchiseToken} from "../token/FranchiseToken.sol";
import {PlatformServicesAgreement} from "./PlatformServicesAgreement.sol";

/**
 * @title InvestmentAgreement
 * @notice Aceptación de los términos de una emisión y emisión tras conciliación
 *         externa de una compra. Cada instancia corresponde a un token/emisión.
 * @dev El verificador designado atesta el pago final y su importe. Este contrato
 *      no recibe fondos, no confirma pagos por sí mismo y no gestiona devoluciones.
 *      El contrato debe ser agente de `FranchiseToken` para poder emitir.
 */
contract InvestmentAgreement is Ownable, Pausable, ReentrancyGuard {
    FranchiseToken public immutable token;
    PlatformServicesAgreement public immutable servicesAgreement;
    uint256 public immutable unitPriceMinor;
    bytes32 public immutable rightsDocumentHash;

    address public paymentVerifier;
    mapping(address => bool) public acceptedTerms;
    mapping(bytes32 => bool) public issuedPurchase;
    mapping(bytes32 => bool) public usedPaymentReference;
    uint256 public totalUnitsIssued;

    event TermsAccepted(address indexed investor, bytes32 indexed rightsDocumentHash);
    event PaymentVerifierChanged(address indexed previousVerifier, address indexed newVerifier);
    event PurchaseIssued(
        bytes32 indexed purchaseId,
        address indexed investor,
        bytes32 indexed paymentReference,
        uint256 units,
        uint256 grossMinor,
        uint256 platformFeeMinor,
        uint256 trustNetMinor,
        bytes32 evidenceHash
    );

    error ZeroAddress();
    error InvalidTerms();
    error WrongTrust();
    error NotPaymentVerifier(address account);
    error TermsNotAccepted(address investor);
    error PurchaseAlreadyIssued(bytes32 purchaseId);
    error PaymentAlreadyUsed(bytes32 paymentReference);
    error InvalidPurchase();
    error AmountMismatch(uint256 expected, uint256 provided);
    error ServicesNotActive();
    error IssuanceControllerNotBound();

    modifier onlyPaymentVerifier() {
        if (msg.sender != paymentVerifier) revert NotPaymentVerifier(msg.sender);
        _;
    }

    constructor(
        address trust_,
        address token_,
        address servicesAgreement_,
        address paymentVerifier_,
        uint256 unitPriceMinor_,
        bytes32 rightsDocumentHash_
    ) Ownable(trust_) {
        if (trust_ == address(0) || token_ == address(0) || servicesAgreement_ == address(0) || paymentVerifier_ == address(0)) {
            revert ZeroAddress();
        }
        if (unitPriceMinor_ == 0 || rightsDocumentHash_ == bytes32(0)) revert InvalidTerms();
        if (PlatformServicesAgreement(servicesAgreement_).trust() != trust_) revert WrongTrust();

        token = FranchiseToken(token_);
        servicesAgreement = PlatformServicesAgreement(servicesAgreement_);
        paymentVerifier = paymentVerifier_;
        unitPriceMinor = unitPriceMinor_;
        rightsDocumentHash = rightsDocumentHash_;
    }

    /// @notice La wallet acepta el documento identificado por `rightsDocumentHash`.
    function acceptTerms() external whenNotPaused {
        if (acceptedTerms[msg.sender]) revert InvalidPurchase();
        acceptedTerms[msg.sender] = true;
        emit TermsAccepted(msg.sender, rightsDocumentHash);
    }

    /// @notice El fideicomiso puede rotar el verificador o detener nuevas emisiones.
    function setPaymentVerifier(address newVerifier) external onlyOwner {
        if (newVerifier == address(0)) revert ZeroAddress();
        address previous = paymentVerifier;
        paymentVerifier = newVerifier;
        emit PaymentVerifierChanged(previous, newVerifier);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Emite una vez por compra conciliada por el verificador externo.
     * @param purchaseId Referencia opaca única para esta emisión; nunca un dato personal.
     * @param paymentReference Referencia opaca del pago, única dentro de esta emisión.
     * @param paidAmountMinor Importe de la compra sin gas, en las unidades de `servicesAgreement.currency`.
     * @param evidenceHash Compromiso de la evidencia privada de conciliación, sin publicarla.
     */
    function issueAfterPayment(
        bytes32 purchaseId,
        bytes32 paymentReference,
        address investor,
        uint256 units,
        uint256 paidAmountMinor,
        bytes32 evidenceHash
    ) external onlyPaymentVerifier whenNotPaused nonReentrant {
        if (!servicesAgreement.isActive()) revert ServicesNotActive();
        if (token.issuanceController() != address(this)) revert IssuanceControllerNotBound();
        if (
            purchaseId == bytes32(0) || paymentReference == bytes32(0) || investor == address(0) ||
            units == 0 || evidenceHash == bytes32(0)
        ) {
            revert InvalidPurchase();
        }
        if (issuedPurchase[purchaseId]) revert PurchaseAlreadyIssued(purchaseId);
        if (usedPaymentReference[paymentReference]) revert PaymentAlreadyUsed(paymentReference);
        if (!acceptedTerms[investor]) revert TermsNotAccepted(investor);

        uint256 grossMinor = unitPriceMinor * units;
        if (paidAmountMinor != grossMinor) revert AmountMismatch(grossMinor, paidAmountMinor);
        (uint256 platformFeeMinor, uint256 trustNetMinor) = servicesAgreement.quote(grossMinor);

        issuedPurchase[purchaseId] = true;
        usedPaymentReference[paymentReference] = true;
        totalUnitsIssued += units;
        token.mint(investor, units);
        emit PurchaseIssued(
            purchaseId, investor, paymentReference, units, grossMinor, platformFeeMinor, trustNetMinor, evidenceHash
        );
    }
}
