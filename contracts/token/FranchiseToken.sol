// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {IERC3643} from "../interfaces/IERC3643.sol";
import {IIdentityRegistry} from "../interfaces/IIdentityRegistry.sol";
import {ICompliance} from "../interfaces/ICompliance.sol";
import {IPaymentObligation} from "../interfaces/IPaymentObligation.sol";
import {AgentRole} from "../roles/AgentRole.sol";

/**
 * @title FranchiseToken
 * @notice Security token ERC-3643 que representa participaciones en una franquicia.
 *
 *         - Sólo inversores verificados en el IdentityRegistry pueden recibir tokens.
 *         - Cada transferencia se valida contra el módulo de Compliance.
 *         - Los agentes pueden emitir, quemar, congelar, forzar transferencias y recuperar
 *           wallets perdidas (requisitos regulatorios de ERC-3643).
 *         - Los ingresos/regalías de la franquicia se reparten a prorrata entre los holders
 *           en un token de pago (p. ej. USDC) mediante un modelo "pull" (cada holder reclama).
 *         - Los pagos senior (regalías al franquiciante, honorarios de la operadora, ...) van
 *           antes que los inversores: no se reparte mientras alguno esté vencido.
 */
contract FranchiseToken is IERC3643, ERC20, Pausable, ReentrancyGuard, AgentRole {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using SafeCast for int256;

    struct FranchiseInfo {
        string franchiseName; // p. ej. "Café Central - Sucursal Polanco"
        string brand; // marca franquiciante
        string location; // ubicación del local
        string legalDocumentURI; // contrato/prospecto (IPFS, etc.)
        bytes32 legalDocumentHash; // hash del documento legal para verificar integridad
        uint256 valuation; // valuación de la franquicia en unidades del token de pago
    }

    string private constant TOKEN_VERSION = "4.1.3-franchise.1";
    uint256 private constant MAGNITUDE = 2 ** 128;
    uint256 private constant MAX_SENIOR_OBLIGATIONS = 10;

    string private _tokenName;
    string private _tokenSymbol;
    uint8 private immutable _tokenDecimals;
    address private _onchainID;

    IIdentityRegistry private _identityRegistry;
    ICompliance private _compliance;

    /// @notice Máximo de participaciones emitibles (0 = sin límite).
    uint256 public immutable maxSupply;
    /// @notice Número de wallets con saldo > 0.
    uint256 public holderCount;

    mapping(address => bool) private _frozen;
    mapping(address => uint256) private _frozenTokens;

    FranchiseInfo private _franchiseInfo;

    // ---- Reparto de ingresos ----
    IERC20 public immutable paymentToken;
    uint256 public totalRevenueDistributed;
    uint256 private _magnifiedRevenuePerShare;
    mapping(address => int256) private _magnifiedRevenueCorrections;
    mapping(address => uint256) private _withdrawnRevenue;
    IPaymentObligation[] private _seniorObligations;

    event FranchiseInfoUpdated(string franchiseName, string brand, string location, uint256 valuation);
    event RevenueDistributed(address indexed distributor, uint256 amount, string memo);
    event RevenueClaimed(address indexed holder, uint256 amount);
    event SeniorObligationAdded(address indexed obligation);
    event SeniorObligationRemoved(address indexed obligation);

    error AddressIsFrozen(address account);
    error InsufficientFreeBalance(address account, uint256 requested, uint256 available);
    error InsufficientBalance(address account, uint256 requested, uint256 balance);
    error RecipientNotVerified(address account);
    error ComplianceCheckFailed(address from, address to, uint256 amount);
    error MaxSupplyExceeded(uint256 requested, uint256 maxSupply);
    error InsufficientFrozenTokens(address account, uint256 requested, uint256 frozen);
    error NoTokensToRecover();
    error IdentityMismatch();
    error LengthMismatch();
    error NoHolders();
    error ZeroAmount();
    error NothingToClaim();
    error SeniorPaymentsOverdue(address obligation);
    error TooManyObligations();
    error ObligationAlreadyAdded(address obligation);
    error ObligationNotFound(address obligation);

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 maxSupply_,
        address identityRegistry_,
        address compliance_,
        address paymentToken_,
        address onchainID_,
        address initialOwner
    ) ERC20(name_, symbol_) AgentRole(initialOwner) {
        if (identityRegistry_ == address(0) || compliance_ == address(0) || paymentToken_ == address(0)) {
            revert ZeroAddress();
        }
        _tokenName = name_;
        _tokenSymbol = symbol_;
        _tokenDecimals = decimals_;
        maxSupply = maxSupply_;
        _onchainID = onchainID_;
        paymentToken = IERC20(paymentToken_);

        _setIdentityRegistry(identityRegistry_);
        _setCompliance(compliance_);

        emit UpdatedTokenInformation(name_, symbol_, decimals_, TOKEN_VERSION, onchainID_);
    }

    // =====================================================================
    // Metadatos ERC-20 / ERC-3643
    // =====================================================================

    function name() public view override returns (string memory) {
        return _tokenName;
    }

    function symbol() public view override returns (string memory) {
        return _tokenSymbol;
    }

    function decimals() public view override returns (uint8) {
        return _tokenDecimals;
    }

    function version() external pure returns (string memory) {
        return TOKEN_VERSION;
    }

    function onchainID() external view returns (address) {
        return _onchainID;
    }

    function identityRegistry() external view returns (IIdentityRegistry) {
        return _identityRegistry;
    }

    function compliance() external view returns (ICompliance) {
        return _compliance;
    }

    function paused() public view override(IERC3643, Pausable) returns (bool) {
        return super.paused();
    }

    function isFrozen(address userAddress) external view returns (bool) {
        return _frozen[userAddress];
    }

    function getFrozenTokens(address userAddress) external view returns (uint256) {
        return _frozenTokens[userAddress];
    }

    function franchiseInfo() external view returns (FranchiseInfo memory) {
        return _franchiseInfo;
    }

    // =====================================================================
    // Configuración (owner)
    // =====================================================================

    function setName(string calldata name_) external onlyOwner {
        _tokenName = name_;
        emit UpdatedTokenInformation(name_, _tokenSymbol, _tokenDecimals, TOKEN_VERSION, _onchainID);
    }

    function setSymbol(string calldata symbol_) external onlyOwner {
        _tokenSymbol = symbol_;
        emit UpdatedTokenInformation(_tokenName, symbol_, _tokenDecimals, TOKEN_VERSION, _onchainID);
    }

    function setOnchainID(address onchainID_) external onlyOwner {
        _onchainID = onchainID_;
        emit UpdatedTokenInformation(_tokenName, _tokenSymbol, _tokenDecimals, TOKEN_VERSION, onchainID_);
    }

    function setIdentityRegistry(address identityRegistry_) external onlyOwner {
        _setIdentityRegistry(identityRegistry_);
    }

    function setCompliance(address compliance_) external onlyOwner {
        _setCompliance(compliance_);
    }

    function setFranchiseInfo(FranchiseInfo calldata info) external onlyOwner {
        _franchiseInfo = info;
        emit FranchiseInfoUpdated(info.franchiseName, info.brand, info.location, info.valuation);
    }

    /// @notice Registra un contrato cuyos pagos deben estar al día antes de repartir ingresos
    ///         (p. ej. FranchiseAgreement u OperatingAgreement).
    function addSeniorObligation(address obligation) external onlyOwner {
        if (obligation == address(0)) revert ZeroAddress();
        if (_seniorObligations.length >= MAX_SENIOR_OBLIGATIONS) revert TooManyObligations();
        for (uint256 i = 0; i < _seniorObligations.length; i++) {
            if (address(_seniorObligations[i]) == obligation) revert ObligationAlreadyAdded(obligation);
        }
        _seniorObligations.push(IPaymentObligation(obligation));
        emit SeniorObligationAdded(obligation);
    }

    function removeSeniorObligation(address obligation) external onlyOwner {
        uint256 n = _seniorObligations.length;
        for (uint256 i = 0; i < n; i++) {
            if (address(_seniorObligations[i]) == obligation) {
                _seniorObligations[i] = _seniorObligations[n - 1];
                _seniorObligations.pop();
                emit SeniorObligationRemoved(obligation);
                return;
            }
        }
        revert ObligationNotFound(obligation);
    }

    function seniorObligations() external view returns (IPaymentObligation[] memory) {
        return _seniorObligations;
    }

    // =====================================================================
    // Pausa (agente)
    // =====================================================================

    function pause() external onlyAgent {
        _pause();
    }

    function unpause() external onlyAgent {
        _unpause();
    }

    // =====================================================================
    // Transferencias de inversores
    // =====================================================================

    function transfer(address to, uint256 amount) public override(IERC20, ERC20) whenNotPaused returns (bool) {
        _checkTransfer(msg.sender, to, amount);
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override(IERC20, ERC20) whenNotPaused returns (bool) {
        _checkTransfer(from, to, amount);
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function batchTransfer(address[] calldata toList, uint256[] calldata amounts) external {
        if (toList.length != amounts.length) revert LengthMismatch();
        for (uint256 i = 0; i < toList.length; i++) {
            transfer(toList[i], amounts[i]);
        }
    }

    // =====================================================================
    // Operaciones de agente
    // =====================================================================

    function mint(address to, uint256 amount) public onlyAgent {
        if (maxSupply != 0 && totalSupply() + amount > maxSupply) {
            revert MaxSupplyExceeded(totalSupply() + amount, maxSupply);
        }
        if (!_identityRegistry.isVerified(to)) revert RecipientNotVerified(to);
        if (!_compliance.canTransfer(address(0), to, amount)) revert ComplianceCheckFailed(address(0), to, amount);
        _mint(to, amount);
    }

    function burn(address userAddress, uint256 amount) public onlyAgent {
        uint256 balance = balanceOf(userAddress);
        if (amount > balance) revert InsufficientBalance(userAddress, amount, balance);
        _releaseFrozenIfNeeded(userAddress, amount, balance);
        _burn(userAddress, amount);
    }

    function forcedTransfer(address from, address to, uint256 amount) public onlyAgent returns (bool) {
        uint256 balance = balanceOf(from);
        if (amount > balance) revert InsufficientBalance(from, amount, balance);
        if (!_identityRegistry.isVerified(to)) revert RecipientNotVerified(to);
        _releaseFrozenIfNeeded(from, amount, balance);
        _transfer(from, to, amount);
        return true;
    }

    function setAddressFrozen(address userAddress, bool freeze) public onlyAgent {
        _frozen[userAddress] = freeze;
        emit AddressFrozen(userAddress, freeze, msg.sender);
    }

    function freezePartialTokens(address userAddress, uint256 amount) public onlyAgent {
        uint256 free = balanceOf(userAddress) - _frozenTokens[userAddress];
        if (amount > free) revert InsufficientFreeBalance(userAddress, amount, free);
        _frozenTokens[userAddress] += amount;
        emit TokensFrozen(userAddress, amount);
    }

    function unfreezePartialTokens(address userAddress, uint256 amount) public onlyAgent {
        uint256 frozen = _frozenTokens[userAddress];
        if (amount > frozen) revert InsufficientFrozenTokens(userAddress, amount, frozen);
        _frozenTokens[userAddress] = frozen - amount;
        emit TokensUnfrozen(userAddress, amount);
    }

    /**
     * @notice Recupera los tokens de una wallet perdida hacia una nueva wallet del mismo inversor.
     * @dev El token debe ser agente del IdentityRegistry para registrar la nueva wallet.
     *      Se trasladan saldo, tokens congelados, estado de congelamiento e ingresos sin reclamar.
     */
    function recoveryAddress(
        address lostWallet,
        address newWallet,
        address investorOnchainID
    ) external onlyAgent returns (bool) {
        uint256 balance = balanceOf(lostWallet);
        if (balance == 0) revert NoTokensToRecover();
        if (investorOnchainID == address(0) || _identityRegistry.identity(lostWallet) != investorOnchainID) {
            revert IdentityMismatch();
        }

        if (!_identityRegistry.contains(newWallet)) {
            _identityRegistry.registerIdentity(
                newWallet,
                investorOnchainID,
                _identityRegistry.investorCountry(lostWallet)
            );
        } else if (_identityRegistry.identity(newWallet) != investorOnchainID) {
            revert IdentityMismatch();
        }

        // Ingresos pendientes de la wallet perdida -> nueva wallet.
        uint256 pendingRevenue = withdrawableRevenueOf(lostWallet);
        if (pendingRevenue > 0) {
            int256 magnifiedPending = (pendingRevenue * MAGNITUDE).toInt256();
            _magnifiedRevenueCorrections[lostWallet] -= magnifiedPending;
            _magnifiedRevenueCorrections[newWallet] += magnifiedPending;
        }

        uint256 frozenTokens = _frozenTokens[lostWallet];
        _frozenTokens[lostWallet] = 0;
        _transfer(lostWallet, newWallet, balance);

        if (frozenTokens > 0) {
            _frozenTokens[newWallet] += frozenTokens;
            emit TokensFrozen(newWallet, frozenTokens);
        }
        if (_frozen[lostWallet]) {
            _frozen[newWallet] = true;
            emit AddressFrozen(newWallet, true, msg.sender);
        }

        _identityRegistry.deleteIdentity(lostWallet);
        emit RecoverySuccess(lostWallet, newWallet, investorOnchainID);
        return true;
    }

    // ---- Lotes ----

    function batchForcedTransfer(
        address[] calldata fromList,
        address[] calldata toList,
        uint256[] calldata amounts
    ) external {
        if (fromList.length != toList.length || fromList.length != amounts.length) revert LengthMismatch();
        for (uint256 i = 0; i < fromList.length; i++) {
            forcedTransfer(fromList[i], toList[i], amounts[i]);
        }
    }

    function batchMint(address[] calldata toList, uint256[] calldata amounts) external {
        if (toList.length != amounts.length) revert LengthMismatch();
        for (uint256 i = 0; i < toList.length; i++) {
            mint(toList[i], amounts[i]);
        }
    }

    function batchBurn(address[] calldata userAddresses, uint256[] calldata amounts) external {
        if (userAddresses.length != amounts.length) revert LengthMismatch();
        for (uint256 i = 0; i < userAddresses.length; i++) {
            burn(userAddresses[i], amounts[i]);
        }
    }

    function batchSetAddressFrozen(address[] calldata userAddresses, bool[] calldata freeze) external {
        if (userAddresses.length != freeze.length) revert LengthMismatch();
        for (uint256 i = 0; i < userAddresses.length; i++) {
            setAddressFrozen(userAddresses[i], freeze[i]);
        }
    }

    function batchFreezePartialTokens(address[] calldata userAddresses, uint256[] calldata amounts) external {
        if (userAddresses.length != amounts.length) revert LengthMismatch();
        for (uint256 i = 0; i < userAddresses.length; i++) {
            freezePartialTokens(userAddresses[i], amounts[i]);
        }
    }

    function batchUnfreezePartialTokens(address[] calldata userAddresses, uint256[] calldata amounts) external {
        if (userAddresses.length != amounts.length) revert LengthMismatch();
        for (uint256 i = 0; i < userAddresses.length; i++) {
            unfreezePartialTokens(userAddresses[i], amounts[i]);
        }
    }

    // =====================================================================
    // Reparto de ingresos / regalías de la franquicia
    // =====================================================================

    /**
     * @notice Deposita ingresos de la franquicia para repartir a prorrata entre los holders.
     * @dev El agente debe haber hecho `approve` del token de pago a este contrato.
     *      Revierte si alguna obligación senior tiene pagos vencidos.
     */
    function distributeRevenue(uint256 amount, string calldata memo) external onlyAgent nonReentrant {
        if (amount == 0) revert ZeroAmount();
        uint256 supply = totalSupply();
        if (supply == 0) revert NoHolders();
        for (uint256 i = 0; i < _seniorObligations.length; i++) {
            if (_seniorObligations[i].hasOverduePayments()) {
                revert SeniorPaymentsOverdue(address(_seniorObligations[i]));
            }
        }

        paymentToken.safeTransferFrom(msg.sender, address(this), amount);
        _magnifiedRevenuePerShare += (amount * MAGNITUDE) / supply;
        totalRevenueDistributed += amount;
        emit RevenueDistributed(msg.sender, amount, memo);
    }

    function claimRevenue() external nonReentrant whenNotPaused returns (uint256 amount) {
        if (_frozen[msg.sender]) revert AddressIsFrozen(msg.sender);
        amount = withdrawableRevenueOf(msg.sender);
        if (amount == 0) revert NothingToClaim();
        _withdrawnRevenue[msg.sender] += amount;
        paymentToken.safeTransfer(msg.sender, amount);
        emit RevenueClaimed(msg.sender, amount);
    }

    function accumulativeRevenueOf(address holder) public view returns (uint256) {
        int256 magnified = (_magnifiedRevenuePerShare * balanceOf(holder)).toInt256() +
            _magnifiedRevenueCorrections[holder];
        return magnified.toUint256() / MAGNITUDE;
    }

    function withdrawableRevenueOf(address holder) public view returns (uint256) {
        return accumulativeRevenueOf(holder) - _withdrawnRevenue[holder];
    }

    function withdrawnRevenueOf(address holder) external view returns (uint256) {
        return _withdrawnRevenue[holder];
    }

    // =====================================================================
    // Internos
    // =====================================================================

    function _checkTransfer(address from, address to, uint256 amount) internal view {
        if (_frozen[from]) revert AddressIsFrozen(from);
        if (_frozen[to]) revert AddressIsFrozen(to);
        uint256 free = balanceOf(from) - _frozenTokens[from];
        if (amount > free) revert InsufficientFreeBalance(from, amount, free);
        if (!_identityRegistry.isVerified(to)) revert RecipientNotVerified(to);
        if (!_compliance.canTransfer(from, to, amount)) revert ComplianceCheckFailed(from, to, amount);
    }

    /// @dev Si `amount` excede el saldo libre, descongela la diferencia (comportamiento T-REX).
    function _releaseFrozenIfNeeded(address account, uint256 amount, uint256 balance) private {
        uint256 frozen = _frozenTokens[account];
        uint256 free = balance - frozen;
        if (amount > free) {
            uint256 toUnfreeze = amount - free;
            _frozenTokens[account] = frozen - toUnfreeze;
            emit TokensUnfrozen(account, toUnfreeze);
        }
    }

    /// @dev Hook único para todo movimiento de saldo: corrige el reparto de ingresos,
    ///      actualiza el conteo de holders y notifica al módulo de compliance.
    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value);

        int256 magnifiedCorrection = (_magnifiedRevenuePerShare * value).toInt256();
        if (from != address(0)) _magnifiedRevenueCorrections[from] += magnifiedCorrection;
        if (to != address(0)) _magnifiedRevenueCorrections[to] -= magnifiedCorrection;

        if (value > 0 && from != to) {
            if (to != address(0) && balanceOf(to) == value) holderCount++;
            if (from != address(0) && balanceOf(from) == 0) holderCount--;
        }

        if (from == address(0)) {
            _compliance.created(to, value);
        } else if (to == address(0)) {
            _compliance.destroyed(from, value);
        } else {
            _compliance.transferred(from, to, value);
        }
    }

    function _setIdentityRegistry(address identityRegistry_) private {
        if (identityRegistry_ == address(0)) revert ZeroAddress();
        _identityRegistry = IIdentityRegistry(identityRegistry_);
        emit IdentityRegistryAdded(identityRegistry_);
    }

    function _setCompliance(address compliance_) private {
        if (compliance_ == address(0)) revert ZeroAddress();
        if (address(_compliance) != address(0)) {
            _compliance.unbindToken(address(this));
        }
        _compliance = ICompliance(compliance_);
        _compliance.bindToken(address(this));
        emit ComplianceAdded(compliance_);
    }
}
