// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin/token/ERC721/IERC721.sol";

import "openzeppelin/token/ERC721/IERC721Receiver.sol";

contract BNPL_Escrow is IERC721Receiver {

    /*///////////////////////////////////////////////////////////////
                                INITIATION
    ///////////////////////////////////////////////////////////////*/

    address immutable owner;

    address immutable buyer;

    IERC721 immutable nft;

    uint immutable id;

    uint immutable deposit_minimum;

    uint immutable deadline;

    constructor(
        address _buyer,
        IERC721 _nft,
        uint _id,
        uint _deposit_minumum
    ) {
        owner = msg.sender;
        buyer = _buyer;
        nft = _nft;
        id = _id;
        deposit_minimum = _deposit_minumum;
        deadline = block.timestamp + 1 days;
    }

    /// @notice buyer => deposit balance
    mapping(address => uint) public depositBalance;

    /// @notice if NFT has been successfully purchased
    bool public purchased;

    receive() external payable { }

    /*///////////////////////////////////////////////////////////////
                                EVENTS
    ///////////////////////////////////////////////////////////////*/

    event FullyDeposited(uint total);

    event PurchaseFailed();

    event GoblinWithdraw(bytes indexed data);

    event SuccessfulPurchase();

    /*///////////////////////////////////////////////////////////////
                               ESCROW LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @notice buyer deposit function
    function deposit() external payable {
        require(msg.sender == buyer, "NOT_BUYER");

        // save new total to memory
        uint totalDeposited = depositBalance[msg.sender] + msg.value;

        // if total >= minimum, emit log
        if (totalDeposited >= deposit_minimum) {
            emit FullyDeposited(totalDeposited);
        }

        // store new total to storage
        depositBalance[msg.sender] = totalDeposited;
    }

    /// @notice buyer withdraw on unsuccessful purchase
    function withdraw() public returns (bool success, bytes memory data){
        require(msg.sender == buyer, "NOT_BUYER");

        require(block.timestamp >= deadline, "TIMELOCKED");

        require(!purchased, "PUCHASE_COMPLETED");

        (success, data) = msg.sender.call{ value : depositBalance[msg.sender] }("");

        emit PurchaseFailed();
    }

    /// @notice send nft to NFTfi on successful purchase
    function sendToNFTfi() public {
        // send NFT to NFTfi
        // i'm still not really sure how NFTfi works yet... 🤣
    }

    /// @notice GS ETH withdraw depost on successful purchase
    function goblinWithdraw(address to) public returns (bool success, bytes memory data) {
        require(msg.sender == owner, "NOT_OWNER");

        (success, data) = to.call{ value : address(this).balance }("");

        emit GoblinWithdraw(data);
    }

    /*  
    *   [functions to GS withdraw non-eth assets accidentially sent to this contract]...
    */

    /*///////////////////////////////////////////////////////////////
                            ERC-721 RECEIVER
    ///////////////////////////////////////////////////////////////*/

    /// @notice nft receiver that sets purchased to true on successful purchase
    /// note: still don't fully understand how onERC721Received works so this will require some research/testing
    function onERC721Received(
        address, 
        address, 
        uint, 
        bytes calldata
    ) external override returns (bytes4) {
        if (nft.ownerOf(id) == address(this)) {
            purchased = true;

            emit SuccessfulPurchase();
        }

        return IERC721Receiver.onERC721Received.selector;
    }

}
