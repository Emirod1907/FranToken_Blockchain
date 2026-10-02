// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IIdentityRegistry} from "../interfaces/IIdentityRegistry.sol";
import {AgentRole} from "../roles/AgentRole.sol";

/**
 * @title IdentityRegistry
 * @notice Registro de inversores verificados (KYC/AML) de la franquicia.
 *
 *         Versión simplificada del Identity Registry de T-REX: un agente (p. ej. el proveedor
 *         de KYC) da de alta la wallet, su ONCHAINID y su país, y opcionalmente una fecha de
 *         vencimiento del KYC. En T-REX completo, `isVerified` además valida claims firmados por
 *         emisores de confianza (ClaimTopicsRegistry + TrustedIssuersRegistry).
 */
contract IdentityRegistry is IIdentityRegistry, AgentRole {
    struct Investor {
        address identity;
        uint16 country;
        uint64 kycValidUntil; // 0 = sin vencimiento
    }

    mapping(address => Investor) private _investors;

    error AlreadyRegistered(address userAddress);
    error NotRegistered(address userAddress);
    error LengthMismatch();

    constructor(address initialOwner) AgentRole(initialOwner) {}

    function registerIdentity(address userAddress, address identity_, uint16 country) public onlyAgent {
        if (userAddress == address(0) || identity_ == address(0)) revert ZeroAddress();
        if (_investors[userAddress].identity != address(0)) revert AlreadyRegistered(userAddress);
        _investors[userAddress] = Investor(identity_, country, 0);
        emit IdentityRegistered(userAddress, identity_);
    }

    function batchRegisterIdentity(
        address[] calldata userAddresses,
        address[] calldata identities,
        uint16[] calldata countries
    ) external onlyAgent {
        if (userAddresses.length != identities.length || userAddresses.length != countries.length) {
            revert LengthMismatch();
        }
        for (uint256 i = 0; i < userAddresses.length; i++) {
            registerIdentity(userAddresses[i], identities[i], countries[i]);
        }
    }

    function deleteIdentity(address userAddress) external onlyAgent {
        address identity_ = _requireRegistered(userAddress).identity;
        delete _investors[userAddress];
        emit IdentityRemoved(userAddress, identity_);
    }

    function updateCountry(address userAddress, uint16 country) external onlyAgent {
        _requireRegistered(userAddress).country = country;
        emit CountryUpdated(userAddress, country);
    }

    function updateIdentity(address userAddress, address identity_) external onlyAgent {
        if (identity_ == address(0)) revert ZeroAddress();
        Investor storage investor = _requireRegistered(userAddress);
        address oldIdentity = investor.identity;
        investor.identity = identity_;
        emit IdentityUpdated(oldIdentity, identity_);
    }

    function setKycExpiration(address userAddress, uint64 validUntil) external onlyAgent {
        _requireRegistered(userAddress).kycValidUntil = validUntil;
        emit KycExpirationUpdated(userAddress, validUntil);
    }

    function contains(address userAddress) external view returns (bool) {
        return _investors[userAddress].identity != address(0);
    }

    function isVerified(address userAddress) external view returns (bool) {
        Investor storage investor = _investors[userAddress];
        if (investor.identity == address(0)) return false;
        return investor.kycValidUntil == 0 || investor.kycValidUntil >= block.timestamp;
    }

    function identity(address userAddress) external view returns (address) {
        return _investors[userAddress].identity;
    }

    function investorCountry(address userAddress) external view returns (uint16) {
        return _investors[userAddress].country;
    }

    function kycValidUntil(address userAddress) external view returns (uint64) {
        return _investors[userAddress].kycValidUntil;
    }

    function _requireRegistered(address userAddress) private view returns (Investor storage investor) {
        investor = _investors[userAddress];
        if (investor.identity == address(0)) revert NotRegistered(userAddress);
    }
}
