// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IPaymentObligation
 * @notice Contrato con pagos periódicos que el fideicomiso debe cubrir antes de repartir
 *         ingresos a los inversores (regalías al franquiciante, honorarios a la operadora, ...).
 */
interface IPaymentObligation {
    /// @notice true si hay algún pago vencido e impago.
    function hasOverduePayments() external view returns (bool);
}
