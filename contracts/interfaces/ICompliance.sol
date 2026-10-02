// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ICompliance
 * @notice Interfaz de cumplimiento normativo de ERC-3643. El token consulta `canTransfer`
 *         antes de cada transferencia/emisión y notifica los movimientos con los hooks.
 */
interface ICompliance {
    event TokenBound(address indexed token);
    event TokenUnbound(address indexed token);

    function bindToken(address token) external;

    function unbindToken(address token) external;

    function isTokenBound(address token) external view returns (bool);

    function getTokenBound() external view returns (address);

    function canTransfer(address from, address to, uint256 amount) external view returns (bool);

    function transferred(address from, address to, uint256 amount) external;

    function created(address to, uint256 amount) external;

    function destroyed(address from, uint256 amount) external;
}
