// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BilateralAgreement} from "./BilateralAgreement.sol";
import {IPaymentObligation} from "../interfaces/IPaymentObligation.sol";

/**
 * @title OperatingAgreement
 * @notice CONTRATO 2 — Fideicomiso (parte A) ↔ Operadora (parte B). Contrato de operación.
 *
 *         Regula on-chain:
 *         - Administración del local: datos del local y póliza de seguro vigente.
 *         - Personal, ventas e indicadores: reporte por período (ventas, costos, nómina,
 *           dotación, tickets) que el fideicomiso aprueba u observa; si no lo observa dentro
 *           del plazo de revisión queda aprobado. KPIs: ventas mínimas y ratio de costos máximo.
 *         - Compras y proveedores: registro de proveedores aprobados por el fideicomiso;
 *           compras por encima de un umbral requieren aprobación.
 *         - Honorarios: fijo por período + porcentaje del resultado operativo positivo.
 *         - Responsabilidades: cláusulas por parte (heredado de BilateralAgreement).
 *         - Controles: auditores designados por el fideicomiso, auditorías registradas y
 *           causales de terminación verificables (reportes atrasados, KPIs, auditoría
 *           reprobada, honorarios impagos, franquicia terminada).
 */
contract OperatingAgreement is BilateralAgreement, IPaymentObligation {
    struct Store {
        string name;
        string location;
    }

    struct FeeTerms {
        uint256 fixedFee; // honorario fijo por período
        uint16 successFeeBps; // % sobre el resultado operativo positivo del período
        uint64 reviewPeriod; // plazo del fideicomiso para observar un reporte
        uint64 paymentGracePeriod; // plazo de pago una vez vencida la revisión
    }

    struct KpiTargets {
        uint256 minGrossSales; // ventas mínimas por período
        uint16 maxCostRatioBps; // costos totales / ventas máximo (10_000 = 100%)
        uint8 maxConsecutiveMisses; // períodos seguidos fuera de objetivo que habilitan terminar (0 = no aplica)
    }

    struct ControlTerms {
        uint64 reportDeadline; // plazo para presentar el reporte tras el cierre del período
        uint256 purchaseApprovalThreshold; // compras mayores requieren aprobación del fideicomiso
    }

    struct OperatingTerms {
        Store store;
        FeeTerms fees;
        KpiTargets kpis;
        ControlTerms controls;
        address franchiseAgreement; // CONTRATO 1 asociado (opcional)
    }

    struct PeriodReport {
        uint256 grossSales;
        uint256 costOfGoods;
        uint256 payroll;
        uint256 otherExpenses;
        uint32 headcount;
        uint32 transactions;
        bytes32 reportHash; // estados contables / respaldo off-chain
    }

    enum ReportStatus {
        None,
        Submitted,
        Approved,
        Disputed
    }

    struct ReportRecord {
        PeriodReport data;
        ReportStatus status;
        uint64 submittedAt;
        bool kpiMet;
        uint256 feeDue;
        bool feePaid;
    }

    struct Supplier {
        string name;
        string taxId;
        bool registered;
        bool approved;
    }

    enum PurchaseStatus {
        Pending,
        Approved,
        Rejected
    }

    struct Purchase {
        bytes32 supplierId;
        uint256 amount;
        bytes32 invoiceHash;
        uint64 date;
        PurchaseStatus status;
    }

    struct Audit {
        address auditor;
        uint64 date;
        bool passed;
        bytes32 findingsHash;
    }

    struct Insurance {
        string policyURI;
        bytes32 policyHash;
        uint64 expiresAt;
    }

    // ---- Causales de terminación ----
    uint8 public constant CAUSE_FEE_DEFAULT = 3; // operadora: honorarios vencidos (verificable)
    uint8 public constant CAUSE_REPORTING_DEFAULT = 4; // fideicomiso: reporte atrasado (verificable)
    uint8 public constant CAUSE_KPI_UNDERPERFORMANCE = 5; // fideicomiso: KPIs incumplidos (verificable)
    uint8 public constant CAUSE_AUDIT_FAILURE = 6; // fideicomiso: última auditoría reprobada (verificable)
    uint8 public constant CAUSE_MISCONDUCT = 7; // fideicomiso: fraude, negligencia grave
    uint8 public constant CAUSE_INSOLVENCY = 8; // cualquiera, sin plazo de subsanación
    uint8 public constant CAUSE_FRANCHISE_TERMINATED = 9; // fideicomiso: el CONTRATO 1 dejó de estar vigente (verificable, sin plazo)
    uint8 public constant CAUSE_OTHER_BREACH = 10; // cualquiera

    // ---- Categorías de cláusulas ----
    uint8 public constant CATEGORY_RESPONSIBILITY = 1;
    uint8 public constant CATEGORY_STAFF = 2;
    uint8 public constant CATEGORY_PURCHASING = 3;
    uint8 public constant CATEGORY_CONTROL = 4;

    uint16 private constant BPS = 10_000;

    Store private _store;
    FeeTerms private _fees;
    KpiTargets private _kpis;
    ControlTerms private _controls;
    BilateralAgreement public immutable franchiseAgreement;

    mapping(uint256 => ReportRecord) private _reports;
    uint256 public nextPeriodToReport;
    uint256 public nextPeriodToPay;
    uint256 public totalFeesPaid;

    mapping(bytes32 => Supplier) private _suppliers;
    Purchase[] private _purchases;

    mapping(address => bool) public isAuditor;
    Audit[] private _audits;
    Insurance private _insurance;

    event StoreUpdated(string name, string location);
    event ReportSubmitted(uint256 indexed period, uint256 grossSales, uint256 feeDue, bool kpiMet, bytes32 reportHash);
    event ReportApproved(uint256 indexed period);
    event ReportDisputed(uint256 indexed period, bytes32 reasonHash);
    event FeesPaid(uint256 indexed period, address indexed payer, uint256 amount);
    event SupplierRegistered(bytes32 indexed id, string name, string taxId, bool approved);
    event SupplierApprovalSet(bytes32 indexed id, bool approved);
    event PurchaseRecorded(uint256 indexed id, bytes32 indexed supplierId, uint256 amount, PurchaseStatus status);
    event PurchaseReviewed(uint256 indexed id, bool approved);
    event AuditorSet(address indexed auditor, bool allowed);
    event AuditRecorded(uint256 indexed index, address indexed auditor, bool passed, bytes32 findingsHash);
    event InsuranceUpdated(string policyURI, bytes32 policyHash, uint64 expiresAt);

    error ReportNotAccepted(uint256 period);
    error ReviewPeriodOver(uint256 period);
    error InvalidReportStatus(uint256 period, ReportStatus current);
    error SupplierAlreadyRegistered(bytes32 id);
    error SupplierNotApproved(bytes32 id);
    error UnknownSupplier(bytes32 id);
    error PurchaseNotPending(uint256 id);

    modifier onlyAuditorOrPartyA() {
        if (msg.sender != partyA && !isAuditor[msg.sender]) revert Unauthorized(msg.sender);
        _;
    }

    constructor(BaseTerms memory base, OperatingTerms memory terms) BilateralAgreement(base) {
        if (terms.fees.successFeeBps > BPS) revert InvalidTerms();
        _store = terms.store;
        _fees = terms.fees;
        _kpis = terms.kpis;
        _controls = terms.controls;
        franchiseAgreement = BilateralAgreement(terms.franchiseAgreement);
    }

    // =====================================================================
    // Consultas de términos
    // =====================================================================

    function trust() external view returns (address) {
        return partyA;
    }

    function operator() external view returns (address) {
        return partyB;
    }

    function store() external view returns (Store memory) {
        return _store;
    }

    function feeTerms() external view returns (FeeTerms memory) {
        return _fees;
    }

    function kpiTargets() external view returns (KpiTargets memory) {
        return _kpis;
    }

    function controlTerms() external view returns (ControlTerms memory) {
        return _controls;
    }

    // =====================================================================
    // Administración del local
    // =====================================================================

    function updateStore(string calldata name_, string calldata location) external onlyPartyA {
        _store = Store(name_, location);
        emit StoreUpdated(name_, location);
    }

    /// @notice La operadora registra la póliza de seguro del local.
    function setInsurance(string calldata policyURI, bytes32 policyHash, uint64 expiresAt) external onlyPartyB {
        _insurance = Insurance(policyURI, policyHash, expiresAt);
        emit InsuranceUpdated(policyURI, policyHash, expiresAt);
    }

    function insurance() external view returns (Insurance memory) {
        return _insurance;
    }

    function isInsuranceValid() external view returns (bool) {
        return block.timestamp < _insurance.expiresAt;
    }

    // =====================================================================
    // Reportes: ventas, personal e indicadores
    // =====================================================================

    /// @notice La operadora presenta el reporte de un período cerrado. Se presentan en orden.
    function submitReport(uint256 period, PeriodReport calldata data) external onlyPartyB {
        if (status == Status.Draft) revert InvalidStatus(status);
        if (period != nextPeriodToReport) revert WrongPeriod(period, nextPeriodToReport);
        _requireClosedPeriod(period);
        nextPeriodToReport++;
        _storeReport(period, data);
    }

    /// @notice Vuelve a presentar un reporte observado por el fideicomiso.
    function resubmitReport(uint256 period, PeriodReport calldata data) external onlyPartyB {
        ReportStatus current = _reports[period].status;
        if (current != ReportStatus.Disputed) revert InvalidReportStatus(period, current);
        _storeReport(period, data);
    }

    function approveReport(uint256 period) external onlyPartyA {
        ReportStatus current = _reports[period].status;
        if (current != ReportStatus.Submitted) revert InvalidReportStatus(period, current);
        _reports[period].status = ReportStatus.Approved;
        emit ReportApproved(period);
    }

    /// @notice Observa un reporte dentro del plazo de revisión. La operadora debe corregirlo.
    function disputeReport(uint256 period, bytes32 reasonHash) external onlyPartyA {
        ReportRecord storage record = _reports[period];
        if (record.status != ReportStatus.Submitted) revert InvalidReportStatus(period, record.status);
        if (block.timestamp >= record.submittedAt + _fees.reviewPeriod) revert ReviewPeriodOver(period);
        record.status = ReportStatus.Disputed;
        emit ReportDisputed(period, reasonHash);
    }

    /// @notice Aprobado expresamente o sin observaciones dentro del plazo de revisión.
    function isReportAccepted(uint256 period) public view returns (bool) {
        ReportRecord storage record = _reports[period];
        return
            record.status == ReportStatus.Approved ||
            (record.status == ReportStatus.Submitted && block.timestamp >= record.submittedAt + _fees.reviewPeriod);
    }

    function report(uint256 period) external view returns (ReportRecord memory) {
        return _reports[period];
    }

    /// @notice Ventas menos costo de mercadería, nómina y otros gastos (puede ser negativo).
    function operatingResult(PeriodReport memory data) public pure returns (int256) {
        return int256(data.grossSales) - int256(data.costOfGoods + data.payroll + data.otherExpenses);
    }

    function feeFor(PeriodReport memory data) public view returns (uint256) {
        int256 result = operatingResult(data);
        uint256 success = result > 0 ? (uint256(result) * _fees.successFeeBps) / BPS : 0;
        return _fees.fixedFee + success;
    }

    function meetsKpis(PeriodReport memory data) public view returns (bool) {
        if (data.grossSales < _kpis.minGrossSales) return false;
        uint256 costs = data.costOfGoods + data.payroll + data.otherExpenses;
        if (data.grossSales == 0) return costs == 0;
        return costs * BPS <= uint256(_kpis.maxCostRatioBps) * data.grossSales;
    }

    /// @notice Períodos consecutivos (hasta el último reportado) fuera de objetivo, con tope
    ///         en `maxConsecutiveMisses`.
    function consecutiveKpiMisses() public view returns (uint256 misses) {
        uint256 limit = _kpis.maxConsecutiveMisses;
        uint256 period = nextPeriodToReport;
        while (period > 0 && misses < limit) {
            period--;
            if (_reports[period].kpiMet) break;
            misses++;
        }
    }

    function isKpiBreached() public view returns (bool) {
        return _kpis.maxConsecutiveMisses > 0 && consecutiveKpiMisses() >= _kpis.maxConsecutiveMisses;
    }

    function isReportOverdue() public view returns (bool) {
        if (status == Status.Draft) return false;
        uint256 period = nextPeriodToReport;
        return period < periodCount() && block.timestamp > periodEnd(period) + _controls.reportDeadline;
    }

    // =====================================================================
    // Honorarios
    // =====================================================================

    /// @notice Paga los honorarios de un período con reporte aceptado. Se pagan en orden.
    /// @dev Quien paga debe haber hecho `approve` del stablecoin a este contrato.
    function payFees(uint256 period) external nonReentrant {
        if (period != nextPeriodToPay) revert WrongPeriod(period, nextPeriodToPay);
        if (!isReportAccepted(period)) revert ReportNotAccepted(period);
        ReportRecord storage record = _reports[period];
        record.feePaid = true;
        nextPeriodToPay++;
        totalFeesPaid += record.feeDue;
        _pay(msg.sender, partyB, record.feeDue);
        emit FeesPaid(period, msg.sender, record.feeDue);
    }

    /// @inheritdoc IPaymentObligation
    function hasOverduePayments() public view returns (bool) {
        ReportRecord storage record = _reports[nextPeriodToPay];
        if (record.status != ReportStatus.Submitted && record.status != ReportStatus.Approved) return false;
        return block.timestamp > record.submittedAt + _fees.reviewPeriod + _fees.paymentGracePeriod;
    }

    // =====================================================================
    // Compras y proveedores
    // =====================================================================

    /// @notice Alta de proveedor. Si lo registra el fideicomiso queda aprobado; si lo propone
    ///         la operadora queda pendiente de aprobación.
    function registerSupplier(bytes32 id, string calldata name_, string calldata taxId) external onlyParty {
        if (_suppliers[id].registered) revert SupplierAlreadyRegistered(id);
        bool approved = msg.sender == partyA;
        _suppliers[id] = Supplier(name_, taxId, true, approved);
        emit SupplierRegistered(id, name_, taxId, approved);
    }

    function setSupplierApproval(bytes32 id, bool approved) external onlyPartyA {
        if (!_suppliers[id].registered) revert UnknownSupplier(id);
        _suppliers[id].approved = approved;
        emit SupplierApprovalSet(id, approved);
    }

    function supplier(bytes32 id) external view returns (Supplier memory) {
        return _suppliers[id];
    }

    /// @notice La operadora registra una compra a un proveedor aprobado.
    function recordPurchase(
        bytes32 supplierId,
        uint256 amount,
        bytes32 invoiceHash
    ) external onlyPartyB inStatus(Status.Active) returns (uint256 id) {
        if (!_suppliers[supplierId].approved) revert SupplierNotApproved(supplierId);
        PurchaseStatus purchaseStatus = amount > _controls.purchaseApprovalThreshold
            ? PurchaseStatus.Pending
            : PurchaseStatus.Approved;
        id = _purchases.length;
        _purchases.push(Purchase(supplierId, amount, invoiceHash, uint64(block.timestamp), purchaseStatus));
        emit PurchaseRecorded(id, supplierId, amount, purchaseStatus);
    }

    function reviewPurchase(uint256 id, bool approved) external onlyPartyA {
        Purchase storage purchase_ = _purchases[id];
        if (purchase_.status != PurchaseStatus.Pending) revert PurchaseNotPending(id);
        purchase_.status = approved ? PurchaseStatus.Approved : PurchaseStatus.Rejected;
        emit PurchaseReviewed(id, approved);
    }

    function purchaseCount() external view returns (uint256) {
        return _purchases.length;
    }

    function purchase(uint256 id) external view returns (Purchase memory) {
        return _purchases[id];
    }

    // =====================================================================
    // Controles
    // =====================================================================

    function setAuditor(address auditor, bool allowed) external onlyPartyA {
        if (auditor == address(0)) revert ZeroAddress();
        isAuditor[auditor] = allowed;
        emit AuditorSet(auditor, allowed);
    }

    function recordAudit(bool passed, bytes32 findingsHash) external onlyAuditorOrPartyA inStatus(Status.Active) {
        _audits.push(Audit(msg.sender, uint64(block.timestamp), passed, findingsHash));
        emit AuditRecorded(_audits.length - 1, msg.sender, passed, findingsHash);
    }

    function auditCount() external view returns (uint256) {
        return _audits.length;
    }

    function audit(uint256 index) external view returns (Audit memory) {
        return _audits[index];
    }

    function lastAuditFailed() public view returns (bool) {
        uint256 n = _audits.length;
        return n > 0 && !_audits[n - 1].passed;
    }

    function isFranchiseTerminated() public view returns (bool) {
        return address(franchiseAgreement) != address(0) && !franchiseAgreement.isActive();
    }

    // =====================================================================
    // Internos y ganchos de BilateralAgreement
    // =====================================================================

    function _storeReport(uint256 period, PeriodReport calldata data) private {
        bool kpiMet = meetsKpis(data);
        uint256 fee = feeFor(data);
        _reports[period] = ReportRecord(data, ReportStatus.Submitted, uint64(block.timestamp), kpiMet, fee, false);
        emit ReportSubmitted(period, data.grossSales, fee, kpiMet, data.reportHash);
    }

    function _validateBreach(uint8 cause, address notifier) internal view override {
        bool byTrust = notifier == partyA;
        bool allowed;
        if (cause == CAUSE_FEE_DEFAULT) {
            allowed = !byTrust && hasOverduePayments();
        } else if (cause == CAUSE_REPORTING_DEFAULT) {
            allowed = byTrust && isReportOverdue();
        } else if (cause == CAUSE_KPI_UNDERPERFORMANCE) {
            allowed = byTrust && isKpiBreached();
        } else if (cause == CAUSE_AUDIT_FAILURE) {
            allowed = byTrust && lastAuditFailed();
        } else if (cause == CAUSE_FRANCHISE_TERMINATED) {
            allowed = byTrust && isFranchiseTerminated();
        } else if (cause == CAUSE_MISCONDUCT) {
            allowed = byTrust;
        } else {
            allowed = cause == CAUSE_INSOLVENCY || cause == CAUSE_OTHER_BREACH;
        }
        if (!allowed) revert CauseNotAllowed(cause);
    }

    function _curePeriodFor(uint8 cause) internal view override returns (uint64) {
        return cause == CAUSE_INSOLVENCY || cause == CAUSE_FRANCHISE_TERMINATED ? 0 : curePeriod;
    }

    function _breachPersists(uint8 cause) internal view override returns (bool) {
        if (cause == CAUSE_FEE_DEFAULT) return hasOverduePayments();
        if (cause == CAUSE_REPORTING_DEFAULT) return isReportOverdue();
        if (cause == CAUSE_KPI_UNDERPERFORMANCE) return isKpiBreached();
        if (cause == CAUSE_AUDIT_FAILURE) return lastAuditFailed();
        return true;
    }
}
