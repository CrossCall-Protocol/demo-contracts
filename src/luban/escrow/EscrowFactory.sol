// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19.0;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable reason-string */

import "./EscrowProxy.sol";
import "@openzeppelin/contracts/utils/Create2.sol";

/**
 * @author  Qi Protocol - Charles Taylor
 * @title   A factory contract to create private escrow.
 * @dev     Called by CrossCall relay.
 * @notice  .
 */

contract EscrowFactory {
    uint256 private immutable _ESCROWIMPL;
    string public constant VERSION = "0.0.1";

    constructor(address _escrowImpl) {
        require(_escrowImpl != address(0));
        _ESCROWIMPL = uint256(uint160(_escrowImpl));
    }

    function escrowImpl() external view returns (address) {
        return address(uint160(_ESCROWIMPL));
    }

    function _calcSalt(bytes memory _initializer, bytes32 _salt) private pure returns (bytes32 salt) {
        salt = keccak256(abi.encodePacked(keccak256(_initializer), _salt));
    }

    /**
     * @notice  Deploy the escrow contract using 1559 proxy and returns the address of the proxy.
     */
    function createEscrow(bytes memory _initializer, bytes32 _salt) external returns (address proxy) {
        bytes memory deploymentData = abi.encodePacked(type(EscrowProxy).creationCode, _ESCROWIMPL);
        bytes32 salt = _calcSalt(_initializer, _salt);
        assembly ("memory-safe") {
            proxy := create2(0x0, add(deploymentData, 0x20), mload(deploymentData), salt)
        }
        if (proxy == address(0)) {
            revert();
        }
        assembly ("memory-safe") {
            let succ := call(gas(), proxy, 0, add(_initializer, 0x20), mload(_initializer), 0, 0)
            if eq(succ, 0) { revert(0, 0) }
        }
        return proxy;
    }

    /**
     * @notice  returns the proxy creationCode external method.
     * @dev     used by CrossCall to calcudate the escrow address.
     * @return  bytes  .
     */
    function proxyCode() external pure returns (bytes memory) {
        return _proxyCode();
    }

    /**
     * @notice  returns the proxy creationCode private method.
     * @dev     .
     * @return  bytes  .
     */
    function _proxyCode() private pure returns (bytes memory) {
        return type(EscrowProxy).creationCode;
    }

    /**
     * @notice  return the counterfactual address of escrow as it would be return by createEscrow()
     */
    function getEscrowAddress(bytes memory _initializer, bytes32 _salt) external view returns (address proxy) {
        bytes memory deploymentData = abi.encodePacked(type(EscrowProxy).creationCode, _ESCROWIMPL);
        bytes32 salt = _calcSalt(_initializer, _salt);
        proxy = Create2.computeAddress(salt, keccak256(deploymentData));
    }
}
