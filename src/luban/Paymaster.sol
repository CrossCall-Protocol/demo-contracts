// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "lib/account-abstraction/contracts/core/UserOperationLib.sol";
import {BasePaymaster, IEntryPoint} from "lib/account-abstraction/contracts/core/BasePaymaster.sol";

interface IMailbox {
  function dispatch(
    uint32 _destinationDomain,
    bytes32 _recipientAddress,
    bytes calldata _messageBody
  ) external returns (bytes32);
}

interface IIGP {
  function payForGas(
    bytes32 _messageId,
    uint32 _destinationDomain,
    uint256 _gasAmount,
    address _refundAddress
  ) external payable;

  function quoteGasPayment(
    uint32 _destinationDomain,
    uint256 _gasAmount
  ) external view returns (uint256);
}

// deserialize PaymasterAndData (paymaster, chainid, target, owner, amount)
//bytes20, bytes8, bytes20, bytes20, bytes32 = 100 bytes
// chainid == block.chainid
// validateSignature == owner
// transfer amount to paymaster
contract Paymaster is BasePaymaster {

  using UserOperationLib for PackedUserOperation;

  mapping(uint256 => address) public escrowAddress;
  mapping(uint256 => bool) public acceptedChain; // destinationDomain
  mapping(uint256 => mapping(address => bool)) public acceptedAsset;

  address hyperlaneMailbox;
  address hyperlaneIgp;
  address defaultReceiver;

  constructor(
    IEntryPoint entryPoint_,
    address hyperlaneMailbox_,
    address hyperlaneIgp_,
    address defaultReceiver_
  ) BasePaymaster(entryPoint_) {
    hyperlaneMailbox = hyperlaneMailbox_;
    hyperlaneIgp = hyperlaneIgp_;
    defaultReceiver = defaultReceiver_;
  }

  function addAcceptedChain(uint256 chainId_, bool state_) public onlyOwner {
    acceptedChain[chainId_] = state_;
  }

  function addAcceptedAsset(
    uint256 chainId_,
    address asset_,
    bool state_
  ) public onlyOwner {
    acceptedAsset[chainId_][asset_] = state_;
  }

  function _validatePaymasterUserOp(
    PackedUserOperation calldata userOp,
    bytes32,
    uint256 maxCost
  ) internal override returns (bytes memory context, uint256 validationResult) {
    unchecked {
      //maxCost is already subtracted from stake

      // send with hash and signature
      bytes calldata data = userOp.paymasterAndData;

      uint256 paymasterAndDataLength = data.length;
      // 156 == crosschain non-payable
      if (paymasterAndDataLength != 156 && paymasterAndDataLength != 176) {
        revert InvalidDataLength(paymasterAndDataLength);
      } // disabled for 4337 update compatibility

      // non-payable
      // assumptions:
      // set amount owed will be caclulated pretransaction upon validation
      // although skipped for now, validation must be done within a slippage
      // payment and transfer amount are the same currency (only default to native currency for asset 0)
      address paymaster_                      = address(bytes20(data[:20]));
      uint128 paymasterVerificationGasLimit_  = uint128(bytes16(data[20:36]));
      uint128 paymasterPostOpGasLimit_        = uint128(bytes16(data[36:52]));
      address owner_                          = address(bytes20(data[52:72])); // signer
      uint256 chainId_                        = uint256(bytes32(data[72:104]));
      address paymentAsset_                   = address(bytes20(data[104:124]));
      uint256 paymentAmount_                  = uint256(bytes32(data[124:156]));
      bytes32 messageId_;
      uint256 gasAmount_                      = 100000;
      uint32 destinationDomain_               = uint32(chainId_);

      // paymaster must elect to accept funds from specific chains
      // bundler assumes escrow exists on destination chain
      if (!acceptedChain[destinationDomain_]) {
        revert InvalidChainId(destinationDomain_);
      }

      // enabled only for MVP; tbh we don't care about the assets used, network is P2P
      if (!acceptedAsset[destinationDomain_][paymentAsset_]) {
        revert InvalidAsset(destinationDomain_, paymentAsset_);
      }

      // withdraw funds for oracle call to paymaster
      // nope, let it fail if the paymaster has insufficent funds, solver should know better
      // entryPoint.withdrawTo(payable(address(this)), 0.1 ether);

      // the bundler/ solver that submits the tx from the uomempool
      // in reality we don't care who executes, but they are burdened with refunding the paymaster and tx cost
      address receiver = tx.origin;
      bytes32 recipientAddress_ = bytes32(uint256(uint160(receiver)));

      //////////////////////
      ////////////////////// Fix later: more data should be wrapped to include the 
      bytes memory test = abi.encodePacked(abi.encode(userOp), bytes32(uint256(uint160(receiver)))); 
      
      IMailbox(hyperlaneMailbox).dispatch(
        destinationDomain_,
        recipientAddress_,
        test
      );
      uint256 igpQuote_ = IIGP(hyperlaneIgp).quoteGasPayment(
        destinationDomain_,
        gasAmount_
      );
      context = abi.encode(
        receiver,
        messageId_,
        destinationDomain_,
        gasAmount_,
        igpQuote_
      );
    }
  }

  function _postOp(
    PostOpMode mode,
    bytes calldata context,
    uint256 actualGasCost,
    uint256 actualUserOpFeePerGas
  ) internal override {
    // don't care about the mode, solver fronts the gas
    (mode);
    bytes32 messageId_;
    uint32 destinationDomain_;
    uint256 gasAmount_;
    uint256 igpQuote_;
    address refundAddress_;
    (
      refundAddress_,
      messageId_,
      destinationDomain_,
      gasAmount_,
      igpQuote_
    ) = abi.decode(context, (address, bytes32, uint32, uint256, uint256));
    IIGP(hyperlaneIgp).payForGas{value: address(this).balance}(
      messageId_,
      destinationDomain_,
      gasAmount_,
      address(this)
    );

    entryPoint.addStake{ value: gasAmount_ + actualGasCost + actualUserOpFeePerGas }(10);
     // shouldn't revert, but doesn't matter
    payable(refundAddress_).call{ value: address(this).balance }("");
  }

  // we don't care where the money comes from (solver should be bundling payment tx with signed userop)
  receive() external payable {}
  fallback() external payable {}

  error InvalidChainId(uint32 chainId);
  error InvalidOrigin(address bundler);
  error InvalidAsset(uint32 chainId, address asset);
  error InvalidDataLength(uint256 dataLength);
}
