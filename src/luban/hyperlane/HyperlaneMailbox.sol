// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract HyperlaneMailbox is Ownable {
    uint256 _nonce = 100;
    uint256 _price = 0.001 ether;
    address _owner;
    mapping(bytes32 => bool) _paid;
    mapping(uint32 => uint256) _gasPrice;

    constructor(uint32 domain_) Ownable(msg.sender) payable {
        _gasPrice[domain_] = 0.001 ether;
    }

    function quoteGas(uint32 destinationDomain, uint256 gasAmount) external view returns(uint256) {
        (gasAmount); // unused
        return _gasPrice[destinationDomain];
    }

    // this should be a callback
    function setDomain(uint32 domain_, uint256 value_) external payable onlyOwner() {
        _gasPrice[domain_] = value_;
    }

    function payMessage(bytes32 messageId, address refundAddress) external payable {
        require(msg.value >= _price, "insufficent payment");
        _paid[messageId] = true;
        if(msg.value >= 0.001 ether) {
            payable(refundAddress).call{value: msg.value - 0.001 ether}("");
        }
    }

    function handleDispatch(uint256 destinationDomain, address recipientAddress, bytes calldata messageBody) external {
        bytes memory payload_;
        bool success;
        payload_ = abi.encodeWithSignature("interchainSecurityModule()");
        (success, ) = recipientAddress.call(payload_);
        require(success); // hyperlane required ISM is defined (even if zero)
        payload_ = abi.encodeWithSignature(
            "handle(uint32,bytes32,bytes)",
            uint32(uint256(destinationDomain)),
            bytes32(uint256(uint160(msg.sender))),
            messageBody
        );
        (success, ) = recipientAddress.call(payload_);
        require(success, "recipient execution failed");
    }

    function dispatch( uint32 _destinationDomain, bytes32 _recipientAddress, bytes calldata _messageBody) external returns (bytes32) {
        (_destinationDomain, _recipientAddress, _messageBody);
        // should execute escrow
        return(bytes32(_nonce++));
    }

    receive() external payable {}
}
