// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title PlatformServicesAgreement
 * @notice Términos económicos entre el fideicomiso y FranToken para las compras
 *         de una emisión. Los cobros y la liquidación ocurren fuera de la cadena.
 * @dev Los importes están en unidades mínimas de `currency`, con `currencyDecimals`.
 *      La comisión se redondea hacia abajo y el residual queda para el fideicomiso.
 *      El hash identifica términos externos; no prueba su validez ni su cumplimiento.
 */
contract PlatformServicesAgreement {
    uint256 private constant BPS = 10_000;

    address public immutable trust;
    address public immutable platform;
    bytes3 public immutable currency;
    uint8 public immutable currencyDecimals;
    uint16 public immutable feeBps;
    bytes32 public immutable documentHash;

    bool public trustSigned;
    bool public platformSigned;

    event Signed(address indexed party, bytes32 indexed documentHash);
    event Activated(bytes32 indexed documentHash);

    error ZeroAddress();
    error InvalidTerms();
    error NotParty(address account);
    error AlreadySigned(address account);

    constructor(
        address trust_,
        address platform_,
        bytes3 currency_,
        uint8 currencyDecimals_,
        uint16 feeBps_,
        bytes32 documentHash_
    ) {
        if (trust_ == address(0) || platform_ == address(0)) revert ZeroAddress();
        if (trust_ == platform_ || currency_ == bytes3(0) || feeBps_ >= BPS || documentHash_ == bytes32(0)) {
            revert InvalidTerms();
        }
        trust = trust_;
        platform = platform_;
        currency = currency_;
        currencyDecimals = currencyDecimals_;
        feeBps = feeBps_;
        documentHash = documentHash_;
    }

    function sign() external {
        if (msg.sender == trust) {
            if (trustSigned) revert AlreadySigned(msg.sender);
            trustSigned = true;
        } else if (msg.sender == platform) {
            if (platformSigned) revert AlreadySigned(msg.sender);
            platformSigned = true;
        } else {
            revert NotParty(msg.sender);
        }
        emit Signed(msg.sender, documentHash);
        if (isActive()) emit Activated(documentHash);
    }

    function isActive() public view returns (bool) {
        return trustSigned && platformSigned;
    }

    /// @notice Cálculo contable; no transfiere dinero ni certifica cobros externos.
    function quote(uint256 grossMinor) external view returns (uint256 platformFeeMinor, uint256 trustNetMinor) {
        platformFeeMinor = Math.mulDiv(grossMinor, feeBps, BPS);
        trustNetMinor = grossMinor - platformFeeMinor;
    }
}
