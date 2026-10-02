// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICompliance} from "../interfaces/ICompliance.sol";
import {IERC3643} from "../interfaces/IERC3643.sol";

interface IHolderCount {
    function holderCount() external view returns (uint256);
}

/**
 * @title FranchiseCompliance
 * @notice Reglas de cumplimiento para la oferta de participaciones de una franquicia:
 *         - Máximo de inversores (p. ej. límites de oferta privada).
 *         - Tenencia máxima por inversor.
 *         - Países bloqueados (jurisdicciones restringidas).
 *         - Período de lock-up: hasta `lockupEnd` sólo se permite emitir, no transferir.
 */
contract FranchiseCompliance is ICompliance, Ownable {
    address private _tokenBound;

    uint256 public maxHolders; // 0 = sin límite
    uint256 public maxBalancePerInvestor; // 0 = sin límite
    uint64 public lockupEnd; // timestamp; 0 = sin lock-up
    mapping(uint16 => bool) public isCountryBlocked;

    event MaxHoldersSet(uint256 maxHolders);
    event MaxBalancePerInvestorSet(uint256 maxBalance);
    event LockupEndSet(uint64 lockupEnd);
    event CountryBlocked(uint16 indexed country, bool blocked);

    error OnlyBoundToken();
    error Unauthorized();
    error TokenAlreadyBound();
    error TokenNotBound(address token);
    error ZeroAddress();

    modifier onlyToken() {
        if (msg.sender != _tokenBound) revert OnlyBoundToken();
        _;
    }

    constructor(address initialOwner) Ownable(initialOwner) {}

    // ---------------------------------------------------------------------
    // Vinculación con el token
    // ---------------------------------------------------------------------

    /// @dev Puede llamarla el owner, o el propio token si el compliance está libre.
    function bindToken(address token) external {
        if (token == address(0)) revert ZeroAddress();
        if (msg.sender != owner() && msg.sender != token) revert Unauthorized();
        if (_tokenBound != address(0)) revert TokenAlreadyBound();
        _tokenBound = token;
        emit TokenBound(token);
    }

    function unbindToken(address token) external {
        if (msg.sender != owner() && msg.sender != _tokenBound) revert Unauthorized();
        if (token != _tokenBound) revert TokenNotBound(token);
        _tokenBound = address(0);
        emit TokenUnbound(token);
    }

    function isTokenBound(address token) external view returns (bool) {
        return token != address(0) && token == _tokenBound;
    }

    function getTokenBound() external view returns (address) {
        return _tokenBound;
    }

    // ---------------------------------------------------------------------
    // Configuración de reglas
    // ---------------------------------------------------------------------

    function setMaxHolders(uint256 maxHolders_) external onlyOwner {
        maxHolders = maxHolders_;
        emit MaxHoldersSet(maxHolders_);
    }

    function setMaxBalancePerInvestor(uint256 maxBalance) external onlyOwner {
        maxBalancePerInvestor = maxBalance;
        emit MaxBalancePerInvestorSet(maxBalance);
    }

    function setLockupEnd(uint64 lockupEnd_) external onlyOwner {
        lockupEnd = lockupEnd_;
        emit LockupEndSet(lockupEnd_);
    }

    function setCountryBlocked(uint16 country, bool blocked) external onlyOwner {
        isCountryBlocked[country] = blocked;
        emit CountryBlocked(country, blocked);
    }

    // ---------------------------------------------------------------------
    // Verificación
    // ---------------------------------------------------------------------

    /// @param from address(0) cuando se trata de una emisión (mint).
    function canTransfer(address from, address to, uint256 amount) external view returns (bool) {
        address token = _tokenBound;
        if (token == address(0)) return false;

        // Lock-up: sólo bloquea transferencias secundarias, no la emisión primaria.
        if (from != address(0) && block.timestamp < lockupEnd) return false;

        uint16 country = IERC3643(token).identityRegistry().investorCountry(to);
        if (isCountryBlocked[country]) return false;

        uint256 toBalance = IERC20(token).balanceOf(to);
        if (maxBalancePerInvestor != 0 && toBalance + amount > maxBalancePerInvestor) return false;

        if (maxHolders != 0 && toBalance == 0 && amount > 0) {
            // Si el emisor transfiere todo su saldo, el número de holders no aumenta.
            bool senderExits = from != address(0) && IERC20(token).balanceOf(from) == amount;
            if (!senderExits && IHolderCount(token).holderCount() >= maxHolders) return false;
        }

        return true;
    }

    // Hooks de estado: las reglas actuales no necesitan estado propio (el conteo de holders
    // lo lleva el token), pero se mantienen para cumplir la interfaz y poder extenderlas.
    function transferred(address, address, uint256) external onlyToken {}

    function created(address, uint256) external onlyToken {}

    function destroyed(address, uint256) external onlyToken {}
}
