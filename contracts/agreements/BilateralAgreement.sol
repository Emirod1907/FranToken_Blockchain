// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title BilateralAgreement
 * @notice Base de los contratos entre dos partes del esquema FranToken: firma de una versión
 *         concreta de los términos, vigencia y renovación, cláusulas, períodos de liquidación,
 *         notificaciones de incumplimiento con plazo de subsanación y terminación.
 *
 * @dev El texto legal vive fuera de la cadena (`documentURI`) y su hash queda firmado on-chain.
 *      Mientras el contrato está en borrador cualquier cambio de términos incrementa
 *      `termsVersion` e invalida las firmas previas.
 *      Las causales de terminación son códigos uint8: 1 y 2 son comunes; el resto las define
 *      cada contrato hijo.
 */
abstract contract BilateralAgreement is ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum Status {
        Draft,
        Active,
        Terminated
    }

    enum Party {
        A,
        B,
        Both
    }

    struct BaseTerms {
        address partyA;
        address partyB;
        address paymentToken; // stablecoin en el que se liquidan los pagos
        uint64 duration; // vigencia inicial en segundos
        uint64 periodLength; // duración de cada período de liquidación
        uint64 curePeriod; // plazo de subsanación por defecto tras una notificación
        uint64 renewalTerm; // extensión por renovación (0 = no renovable)
        string documentURI; // contrato legal (IPFS, etc.)
        bytes32 documentHash; // hash del contrato legal
    }

    struct Clause {
        Party responsible;
        uint8 category; // la define cada contrato hijo
        string text;
    }

    struct BreachNotice {
        address notifier;
        uint8 cause;
        bytes32 evidenceHash;
        uint64 issuedAt;
        uint64 cureDeadline;
        bool resolved;
    }

    uint8 public constant CAUSE_EXPIRATION = 1;
    uint8 public constant CAUSE_MUTUAL_AGREEMENT = 2;

    address public immutable partyA;
    address public immutable partyB;
    IERC20 public immutable paymentToken;
    uint64 public immutable duration;
    uint64 public immutable periodLength;
    uint64 public immutable curePeriod;
    uint64 public immutable renewalTerm;

    string public documentURI;
    bytes32 public documentHash;

    Status public status;
    uint256 public termsVersion = 1;
    mapping(address => uint256) public signedVersion;

    uint64 public startDate;
    uint64 public endDate;
    uint256 public renewals;
    /// @dev Cada parte aprueba la renovación para un `endDate` concreto.
    mapping(address => uint64) public renewalApprovedFor;
    mapping(address => bool) public mutualTerminationProposed;

    uint8 public terminationCause;
    address public terminatedBy;
    uint64 public terminatedAt;

    Clause[] private _clauses;
    BreachNotice[] private _breachNotices;

    event TermsChanged(uint256 indexed version);
    event DocumentUpdated(string uri, bytes32 hash);
    event ClauseAdded(uint256 indexed index, Party responsible, uint8 category, string text);
    event Signed(address indexed party, uint256 indexed version);
    event Activated(uint64 startDate, uint64 endDate);
    event RenewalApproved(address indexed party, uint64 forEndDate);
    event Renewed(uint64 newEndDate, uint256 renewals);
    event MutualTerminationProposed(address indexed party, bool proposed);
    event BreachNotified(
        uint256 indexed id,
        address indexed notifier,
        address indexed breaching,
        uint8 cause,
        bytes32 evidenceHash,
        uint64 cureDeadline
    );
    event RemedyReported(uint256 indexed id, bytes32 evidenceHash);
    event BreachResolved(uint256 indexed id);
    event Terminated(uint8 indexed cause, address indexed by, uint64 at);

    error ZeroAddress();
    error InvalidTerms();
    error NotParty(address account);
    error Unauthorized(address account);
    error InvalidStatus(Status current);
    error TermsVersionMismatch(uint256 expected, uint256 current);
    error NotFullySigned();
    error NotRenewable();
    error AgreementExpired();
    error NotExpired();
    error CauseNotAllowed(uint8 cause);
    error UnknownNotice(uint256 id);
    error NoticeResolved(uint256 id);
    error CurePeriodRunning(uint64 cureDeadline);
    error BreachCured(uint256 id);
    error PeriodNotClosed(uint256 period);
    error WrongPeriod(uint256 requested, uint256 expected);

    modifier onlyParty() {
        if (msg.sender != partyA && msg.sender != partyB) revert NotParty(msg.sender);
        _;
    }

    modifier onlyPartyA() {
        if (msg.sender != partyA) revert Unauthorized(msg.sender);
        _;
    }

    modifier onlyPartyB() {
        if (msg.sender != partyB) revert Unauthorized(msg.sender);
        _;
    }

    modifier inStatus(Status expected) {
        if (status != expected) revert InvalidStatus(status);
        _;
    }

    constructor(BaseTerms memory t) {
        if (t.partyA == address(0) || t.partyB == address(0) || t.paymentToken == address(0)) revert ZeroAddress();
        if (t.partyA == t.partyB || t.duration == 0 || t.periodLength == 0) revert InvalidTerms();
        partyA = t.partyA;
        partyB = t.partyB;
        paymentToken = IERC20(t.paymentToken);
        duration = t.duration;
        periodLength = t.periodLength;
        curePeriod = t.curePeriod;
        renewalTerm = t.renewalTerm;
        documentURI = t.documentURI;
        documentHash = t.documentHash;
    }

    // =====================================================================
    // Borrador y firma
    // =====================================================================

    function setDocument(string calldata uri, bytes32 hash) external onlyParty inStatus(Status.Draft) {
        documentURI = uri;
        documentHash = hash;
        emit DocumentUpdated(uri, hash);
        _termsChanged();
    }

    function addClause(
        Party responsible,
        uint8 category,
        string calldata text
    ) external onlyParty inStatus(Status.Draft) {
        _clauses.push(Clause(responsible, category, text));
        emit ClauseAdded(_clauses.length - 1, responsible, category, text);
        _termsChanged();
    }

    /// @notice Firma la versión `version` de los términos (debe ser la vigente).
    function sign(uint256 version) external onlyParty inStatus(Status.Draft) {
        if (version != termsVersion) revert TermsVersionMismatch(version, termsVersion);
        signedVersion[msg.sender] = version;
        emit Signed(msg.sender, version);
    }

    function isFullySigned() public view returns (bool) {
        return signedVersion[partyA] == termsVersion && signedVersion[partyB] == termsVersion;
    }

    /// @notice Inicia la vigencia una vez firmado por ambas partes.
    function activate() external onlyParty inStatus(Status.Draft) nonReentrant {
        if (!isFullySigned()) revert NotFullySigned();
        startDate = uint64(block.timestamp);
        endDate = startDate + duration;
        status = Status.Active;
        _beforeActivation();
        emit Activated(startDate, endDate);
    }

    // =====================================================================
    // Vigencia
    // =====================================================================

    /// @notice true mientras el contrato está activo y dentro de su plazo.
    function isActive() public view returns (bool) {
        return status == Status.Active && block.timestamp < endDate;
    }

    /// @notice Ambas partes deben aprobar antes del vencimiento para renovar.
    function approveRenewal() external onlyParty inStatus(Status.Active) {
        if (renewalTerm == 0) revert NotRenewable();
        if (block.timestamp >= endDate) revert AgreementExpired();
        renewalApprovedFor[msg.sender] = endDate;
        emit RenewalApproved(msg.sender, endDate);

        if (renewalApprovedFor[partyA] == endDate && renewalApprovedFor[partyB] == endDate) {
            endDate += renewalTerm;
            renewals++;
            emit Renewed(endDate, renewals);
        }
    }

    /// @notice Cierra formalmente un contrato vencido. Lo puede llamar cualquiera.
    function expire() external inStatus(Status.Active) {
        if (block.timestamp < endDate) revert NotExpired();
        _terminate(CAUSE_EXPIRATION, msg.sender);
    }

    function proposeMutualTermination(bool proposed) external onlyParty inStatus(Status.Active) {
        mutualTerminationProposed[msg.sender] = proposed;
        emit MutualTerminationProposed(msg.sender, proposed);
        if (mutualTerminationProposed[partyA] && mutualTerminationProposed[partyB]) {
            _terminate(CAUSE_MUTUAL_AGREEMENT, msg.sender);
        }
    }

    // =====================================================================
    // Incumplimientos y terminación por causa
    // =====================================================================

    /// @notice Notifica un incumplimiento de la contraparte. Abre el plazo de subsanación.
    function notifyBreach(
        uint8 cause,
        bytes32 evidenceHash
    ) external onlyParty inStatus(Status.Active) returns (uint256 id) {
        _validateBreach(cause, msg.sender);
        uint64 deadline = uint64(block.timestamp) + _curePeriodFor(cause);
        id = _breachNotices.length;
        _breachNotices.push(BreachNotice(msg.sender, cause, evidenceHash, uint64(block.timestamp), deadline, false));
        emit BreachNotified(id, msg.sender, counterparty(msg.sender), cause, evidenceHash, deadline);
    }

    /// @notice La parte notificada informa (con evidencia) que subsanó el incumplimiento.
    function reportRemedy(uint256 id, bytes32 evidenceHash) external {
        BreachNotice storage notice = _openNotice(id);
        if (msg.sender != counterparty(notice.notifier)) revert Unauthorized(msg.sender);
        emit RemedyReported(id, evidenceHash);
    }

    /// @notice La parte que notificó da por subsanado (o retira) el incumplimiento.
    function resolveBreach(uint256 id) external {
        BreachNotice storage notice = _openNotice(id);
        if (msg.sender != notice.notifier) revert Unauthorized(msg.sender);
        notice.resolved = true;
        emit BreachResolved(id);
    }

    /// @notice Termina el contrato si venció el plazo de subsanación y el incumplimiento persiste.
    function terminateForCause(uint256 id) external inStatus(Status.Active) {
        BreachNotice storage notice = _openNotice(id);
        if (msg.sender != notice.notifier) revert Unauthorized(msg.sender);
        if (block.timestamp < notice.cureDeadline) revert CurePeriodRunning(notice.cureDeadline);
        if (!_breachPersists(notice.cause)) revert BreachCured(id);
        notice.resolved = true;
        _terminate(notice.cause, msg.sender);
    }

    // =====================================================================
    // Períodos de liquidación
    // =====================================================================

    /// @notice Cantidad de períodos de la vigencia (el último puede ser parcial).
    function periodCount() public view returns (uint256) {
        if (startDate == 0) return 0;
        return (uint256(endDate - startDate) + periodLength - 1) / periodLength;
    }

    function periodStart(uint256 period) public view returns (uint64) {
        return uint64(startDate + period * periodLength);
    }

    function periodEnd(uint256 period) public view returns (uint64) {
        uint256 end = startDate + (period + 1) * periodLength;
        return end > endDate ? endDate : uint64(end);
    }

    // =====================================================================
    // Consultas
    // =====================================================================

    function counterparty(address party) public view returns (address) {
        if (party == partyA) return partyB;
        if (party == partyB) return partyA;
        revert NotParty(party);
    }

    function clauseCount() external view returns (uint256) {
        return _clauses.length;
    }

    function clause(uint256 index) external view returns (Clause memory) {
        return _clauses[index];
    }

    function breachNoticeCount() external view returns (uint256) {
        return _breachNotices.length;
    }

    function breachNotice(uint256 id) external view returns (BreachNotice memory) {
        return _breachNotices[id];
    }

    // =====================================================================
    // Internos y ganchos para los contratos hijos
    // =====================================================================

    function _termsChanged() internal {
        termsVersion++;
        emit TermsChanged(termsVersion);
    }

    /// @dev Exige que `period` sea un período de la vigencia ya cerrado.
    function _requireClosedPeriod(uint256 period) internal view {
        if (period >= periodCount() || block.timestamp < periodEnd(period)) revert PeriodNotClosed(period);
    }

    function _pay(address from, address to, uint256 amount) internal {
        if (amount > 0) paymentToken.safeTransferFrom(from, to, amount);
    }

    /// @dev Al terminar antes de plazo se recorta la vigencia para que el último período
    ///      (parcial) quede cerrado y pueda liquidarse.
    function _terminate(uint8 cause, address by) internal {
        status = Status.Terminated;
        terminationCause = cause;
        terminatedBy = by;
        terminatedAt = uint64(block.timestamp);
        if (block.timestamp < endDate) endDate = uint64(block.timestamp);
        emit Terminated(cause, by, terminatedAt);
    }

    function _openNotice(uint256 id) private view returns (BreachNotice storage notice) {
        if (id >= _breachNotices.length) revert UnknownNotice(id);
        notice = _breachNotices[id];
        if (notice.resolved) revert NoticeResolved(id);
    }

    /// @dev Se ejecuta al activar el contrato (p. ej. cobro del canon de entrada).
    function _beforeActivation() internal virtual {}

    /// @dev Debe revertir con `CauseNotAllowed` si `notifier` no puede invocar `cause`.
    function _validateBreach(uint8 cause, address notifier) internal view virtual;

    function _curePeriodFor(uint8 /* cause */) internal view virtual returns (uint64) {
        return curePeriod;
    }

    /// @dev Para causales verificables on-chain, false si el incumplimiento ya se subsanó.
    function _breachPersists(uint8 /* cause */) internal view virtual returns (bool) {
        return true;
    }
}
