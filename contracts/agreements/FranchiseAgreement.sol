// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BilateralAgreement} from "./BilateralAgreement.sol";
import {IPaymentObligation} from "../interfaces/IPaymentObligation.sol";

/**
 * @title FranchiseAgreement
 * @notice CONTRATO 1 — Franquiciante (parte A) ↔ Fideicomiso (parte B). Contrato de franquicia.
 *
 *         Regula on-chain:
 *         - Uso de marca: licencia vigente sólo mientras el contrato está activo.
 *         - Know-how: manual operativo versionado; el fideicomiso acusa recibo de cada versión.
 *         - Territorio: descripción, exclusividad y zonas (códigos postales, etc.).
 *         - Duración: vigencia, renovación por acuerdo de ambas partes.
 *         - Royalty: canon de entrada, regalía y fondo de publicidad sobre ventas brutas, con
 *           mínimo por período; liquidación periódica en stablecoin.
 *         - Obligaciones y estándares: cláusulas por parte + manual de estándares versionado
 *           e inspecciones con puntaje mínimo.
 *         - Causales de terminación: vencimiento, mutuo acuerdo y las constantes CAUSE_*.
 *           Las de regalías impagas y estándares se verifican on-chain.
 */
contract FranchiseAgreement is BilateralAgreement, IPaymentObligation {
    struct Brand {
        string name;
        string trademarkRegistration; // registro de la marca (p. ej. INPI / IMPI)
        string brandManualURI; // manual de identidad de marca
        bytes32 brandManualHash;
    }

    struct Territory {
        string description;
        bool exclusive;
        bytes32[] zones;
    }

    struct RoyaltyTerms {
        uint256 entryFee; // canon de entrada, se cobra al activar
        uint16 royaltyBps; // regalía sobre ventas brutas (100 = 1%)
        uint16 advertisingFeeBps; // fondo de publicidad sobre ventas brutas
        uint256 minimumRoyalty; // regalía mínima por período
        uint64 paymentGracePeriod; // plazo de pago tras el cierre del período
    }

    struct ManagedDocument {
        string uri;
        bytes32 hash;
        uint64 version;
        uint64 updatedAt;
    }

    struct FranchiseTerms {
        Brand brand;
        Territory territory;
        RoyaltyTerms royalty;
        ManagedDocument knowHow; // manual operativo
        ManagedDocument standards; // manual de estándares de calidad
        uint8 minimumInspectionScore; // 0-100
    }

    struct SalesReport {
        uint256 grossSales;
        uint256 royaltyDue;
        bytes32 evidenceHash;
        uint64 reportedAt;
        bool paid;
    }

    struct Inspection {
        uint64 date;
        uint8 score;
        bool passed;
        bytes32 reportHash;
    }

    // ---- Causales de terminación ----
    uint8 public constant CAUSE_ROYALTY_DEFAULT = 3; // franquiciante: regalías vencidas (verificable)
    uint8 public constant CAUSE_STANDARDS_BREACH = 4; // franquiciante: última inspección reprobada (verificable)
    uint8 public constant CAUSE_BRAND_MISUSE = 5; // franquiciante: uso indebido de la marca
    uint8 public constant CAUSE_KNOW_HOW_DISCLOSURE = 6; // franquiciante: divulgación del know-how
    uint8 public constant CAUSE_INSOLVENCY = 7; // cualquiera: insolvencia de la contraparte (sin plazo de subsanación)
    uint8 public constant CAUSE_FRANCHISOR_BREACH = 8; // fideicomiso: incumplimiento del franquiciante
    uint8 public constant CAUSE_OTHER_BREACH = 9; // cualquiera: otras obligaciones del contrato

    // ---- Categorías de cláusulas ----
    uint8 public constant CATEGORY_OBLIGATION = 1;
    uint8 public constant CATEGORY_STANDARD = 2;
    uint8 public constant CATEGORY_POST_TERMINATION = 3; // no competencia, devolución de manuales, etc.

    uint16 private constant BPS = 10_000;

    Brand private _brand;
    Territory private _territory;
    mapping(bytes32 => bool) private _inTerritory;
    RoyaltyTerms private _royalty;
    ManagedDocument private _knowHow;
    ManagedDocument private _standards;
    uint8 public immutable minimumInspectionScore;

    uint64 public knowHowAcknowledgedVersion;
    Inspection[] private _inspections;

    mapping(address => bool) public isSalesReporter;
    mapping(uint256 => SalesReport) private _salesReports;
    uint256 public nextPeriodToReport;
    uint256 public nextPeriodToPay;
    uint256 public totalRoyaltiesPaid;

    event KnowHowUpdated(uint64 indexed version, string uri, bytes32 hash);
    event KnowHowAcknowledged(uint64 indexed version);
    event StandardsUpdated(uint64 indexed version, string uri, bytes32 hash);
    event InspectionRecorded(uint256 indexed index, uint8 score, bool passed, bytes32 reportHash);
    event SalesReporterSet(address indexed reporter, bool allowed);
    event SalesReported(uint256 indexed period, uint256 grossSales, uint256 royaltyDue, bytes32 evidenceHash);
    event RoyaltyPaid(uint256 indexed period, address indexed payer, uint256 amount);
    event EntryFeePaid(uint256 amount);

    error InvalidScore(uint8 score);
    error UnknownVersion(uint64 version);
    error PeriodNotReported(uint256 period);

    constructor(BaseTerms memory base, FranchiseTerms memory terms) BilateralAgreement(base) {
        if (
            uint256(terms.royalty.royaltyBps) + terms.royalty.advertisingFeeBps > BPS ||
            terms.minimumInspectionScore > 100
        ) revert InvalidTerms();

        _brand = terms.brand;
        _territory = terms.territory;
        for (uint256 i = 0; i < terms.territory.zones.length; i++) {
            _inTerritory[terms.territory.zones[i]] = true;
        }
        _royalty = terms.royalty;
        minimumInspectionScore = terms.minimumInspectionScore;

        _knowHow = ManagedDocument(terms.knowHow.uri, terms.knowHow.hash, 1, uint64(block.timestamp));
        _standards = ManagedDocument(terms.standards.uri, terms.standards.hash, 1, uint64(block.timestamp));
    }

    // =====================================================================
    // Consultas de términos
    // =====================================================================

    function franchisor() external view returns (address) {
        return partyA;
    }

    function trust() external view returns (address) {
        return partyB;
    }

    function brand() external view returns (Brand memory) {
        return _brand;
    }

    function territory() external view returns (Territory memory) {
        return _territory;
    }

    function isInTerritory(bytes32 zone) external view returns (bool) {
        return _inTerritory[zone];
    }

    function royaltyTerms() external view returns (RoyaltyTerms memory) {
        return _royalty;
    }

    function knowHow() external view returns (ManagedDocument memory) {
        return _knowHow;
    }

    function standards() external view returns (ManagedDocument memory) {
        return _standards;
    }

    /// @notice La licencia de uso de marca y know-how rige sólo durante la vigencia.
    function isBrandLicenseActive() external view returns (bool) {
        return isActive();
    }

    // =====================================================================
    // Know-how y estándares (franquiciante)
    // =====================================================================

    function updateKnowHow(string calldata uri, bytes32 hash) external onlyPartyA inStatus(Status.Active) {
        _knowHow = ManagedDocument(uri, hash, _knowHow.version + 1, uint64(block.timestamp));
        emit KnowHowUpdated(_knowHow.version, uri, hash);
    }

    /// @notice El fideicomiso acusa recibo de una versión del manual operativo.
    function acknowledgeKnowHow(uint64 version) external onlyPartyB {
        if (version == 0 || version > _knowHow.version) revert UnknownVersion(version);
        knowHowAcknowledgedVersion = version;
        emit KnowHowAcknowledged(version);
    }

    function updateStandards(string calldata uri, bytes32 hash) external onlyPartyA inStatus(Status.Active) {
        _standards = ManagedDocument(uri, hash, _standards.version + 1, uint64(block.timestamp));
        emit StandardsUpdated(_standards.version, uri, hash);
    }

    /// @notice Registra una inspección del local contra los estándares de la marca.
    function recordInspection(uint8 score, bytes32 reportHash) external onlyPartyA inStatus(Status.Active) {
        if (score > 100) revert InvalidScore(score);
        bool passed = score >= minimumInspectionScore;
        _inspections.push(Inspection(uint64(block.timestamp), score, passed, reportHash));
        emit InspectionRecorded(_inspections.length - 1, score, passed, reportHash);
    }

    function inspectionCount() external view returns (uint256) {
        return _inspections.length;
    }

    function inspection(uint256 index) external view returns (Inspection memory) {
        return _inspections[index];
    }

    function lastInspectionFailed() public view returns (bool) {
        uint256 n = _inspections.length;
        return n > 0 && !_inspections[n - 1].passed;
    }

    // =====================================================================
    // Ventas y regalías
    // =====================================================================

    /// @notice El fideicomiso puede delegar el reporte de ventas (p. ej. en la operadora).
    function setSalesReporter(address reporter, bool allowed) external onlyPartyB {
        if (reporter == address(0)) revert ZeroAddress();
        isSalesReporter[reporter] = allowed;
        emit SalesReporterSet(reporter, allowed);
    }

    /// @notice Reporta las ventas brutas de un período cerrado. Los períodos se reportan en orden.
    function reportSales(uint256 period, uint256 grossSales, bytes32 evidenceHash) external {
        if (msg.sender != partyB && !isSalesReporter[msg.sender]) revert Unauthorized(msg.sender);
        if (status == Status.Draft) revert InvalidStatus(status);
        if (period != nextPeriodToReport) revert WrongPeriod(period, nextPeriodToReport);
        _requireClosedPeriod(period);

        uint256 due = royaltyFor(grossSales);
        _salesReports[period] = SalesReport(grossSales, due, evidenceHash, uint64(block.timestamp), false);
        nextPeriodToReport++;
        emit SalesReported(period, grossSales, due, evidenceHash);
    }

    /// @notice Paga la regalía de un período reportado. Los períodos se pagan en orden.
    /// @dev Quien paga debe haber hecho `approve` del stablecoin a este contrato.
    function payRoyalty(uint256 period) external nonReentrant {
        if (status == Status.Draft) revert InvalidStatus(status);
        if (period != nextPeriodToPay) revert WrongPeriod(period, nextPeriodToPay);
        if (period >= nextPeriodToReport) revert PeriodNotReported(period);

        SalesReport storage report = _salesReports[period];
        report.paid = true;
        nextPeriodToPay++;
        totalRoyaltiesPaid += report.royaltyDue;
        _pay(msg.sender, partyA, report.royaltyDue);
        emit RoyaltyPaid(period, msg.sender, report.royaltyDue);
    }

    /// @notice Regalía + fondo de publicidad para unas ventas brutas dadas.
    function royaltyFor(uint256 grossSales) public view returns (uint256) {
        uint256 royalty = (grossSales * _royalty.royaltyBps) / BPS;
        if (royalty < _royalty.minimumRoyalty) royalty = _royalty.minimumRoyalty;
        return royalty + (grossSales * _royalty.advertisingFeeBps) / BPS;
    }

    function salesReport(uint256 period) external view returns (SalesReport memory) {
        return _salesReports[period];
    }

    /// @notice Fecha límite de pago de la regalía de un período.
    function royaltyDueDate(uint256 period) public view returns (uint64) {
        return periodEnd(period) + _royalty.paymentGracePeriod;
    }

    /// @inheritdoc IPaymentObligation
    /// @dev Un período sin reportar también cuenta como vencido una vez pasado su plazo de pago.
    function hasOverduePayments() public view returns (bool) {
        if (status == Status.Draft) return false;
        uint256 period = nextPeriodToPay;
        return period < periodCount() && block.timestamp > royaltyDueDate(period);
    }

    // =====================================================================
    // Ganchos de BilateralAgreement
    // =====================================================================

    function _beforeActivation() internal override {
        uint256 fee = _royalty.entryFee;
        if (fee > 0) {
            _pay(partyB, partyA, fee);
            emit EntryFeePaid(fee);
        }
    }

    function _validateBreach(uint8 cause, address notifier) internal view override {
        bool byFranchisor = notifier == partyA;
        bool allowed;
        if (cause == CAUSE_ROYALTY_DEFAULT) {
            allowed = byFranchisor && hasOverduePayments();
        } else if (cause == CAUSE_STANDARDS_BREACH) {
            allowed = byFranchisor && lastInspectionFailed();
        } else if (cause == CAUSE_BRAND_MISUSE || cause == CAUSE_KNOW_HOW_DISCLOSURE) {
            allowed = byFranchisor;
        } else if (cause == CAUSE_FRANCHISOR_BREACH) {
            allowed = !byFranchisor;
        } else {
            allowed = cause == CAUSE_INSOLVENCY || cause == CAUSE_OTHER_BREACH;
        }
        if (!allowed) revert CauseNotAllowed(cause);
    }

    function _curePeriodFor(uint8 cause) internal view override returns (uint64) {
        return cause == CAUSE_INSOLVENCY ? 0 : curePeriod;
    }

    function _breachPersists(uint8 cause) internal view override returns (bool) {
        if (cause == CAUSE_ROYALTY_DEFAULT) return hasOverduePayments();
        if (cause == CAUSE_STANDARDS_BREACH) return lastInspectionFailed();
        return true;
    }
}
