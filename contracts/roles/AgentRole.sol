// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AgentRole
 * @notice Rol de "agente" de ERC-3643: cuentas autorizadas por el owner para operar
 *         (emitir, quemar, congelar, registrar inversores, etc.).
 */
abstract contract AgentRole is Ownable {
    mapping(address => bool) private _agents;

    event AgentAdded(address indexed agent);
    event AgentRemoved(address indexed agent);

    error NotAgent(address account);
    error AgentAlreadyExists(address agent);
    error AgentDoesNotExist(address agent);
    error ZeroAddress();

    modifier onlyAgent() {
        if (!_agents[msg.sender]) revert NotAgent(msg.sender);
        _;
    }

    constructor(address initialOwner) Ownable(initialOwner) {}

    function addAgent(address agent) external onlyOwner {
        if (agent == address(0)) revert ZeroAddress();
        if (_agents[agent]) revert AgentAlreadyExists(agent);
        _agents[agent] = true;
        emit AgentAdded(agent);
    }

    function removeAgent(address agent) external onlyOwner {
        if (!_agents[agent]) revert AgentDoesNotExist(agent);
        _agents[agent] = false;
        emit AgentRemoved(agent);
    }

    function isAgent(address account) public view returns (bool) {
        return _agents[account];
    }
}
