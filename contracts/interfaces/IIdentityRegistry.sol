// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IIdentityRegistry
 * @notice Registro de identidades de inversores (KYC/AML) usado por el token ERC-3643.
 *         Vincula cada wallet con su identidad on-chain (ONCHAINID) y su país (ISO-3166 numérico).
 */
interface IIdentityRegistry {
    event IdentityRegistered(address indexed investorAddress, address indexed identity);
    event IdentityRemoved(address indexed investorAddress, address indexed identity);
    event IdentityUpdated(address indexed oldIdentity, address indexed newIdentity);
    event CountryUpdated(address indexed investorAddress, uint16 indexed country);
    event KycExpirationUpdated(address indexed investorAddress, uint64 validUntil);

    function registerIdentity(address userAddress, address identity, uint16 country) external;

    function deleteIdentity(address userAddress) external;

    function updateCountry(address userAddress, uint16 country) external;

    function updateIdentity(address userAddress, address identity) external;

    function setKycExpiration(address userAddress, uint64 validUntil) external;

    function batchRegisterIdentity(
        address[] calldata userAddresses,
        address[] calldata identities,
        uint16[] calldata countries
    ) external;

    function contains(address userAddress) external view returns (bool);

    function isVerified(address userAddress) external view returns (bool);

    function identity(address userAddress) external view returns (address);

    function investorCountry(address userAddress) external view returns (uint16);

    function kycValidUntil(address userAddress) external view returns (uint64);
}
