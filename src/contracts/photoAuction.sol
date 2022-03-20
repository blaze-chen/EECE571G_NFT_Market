//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract photoAuction is IERC721Receiver{
    address scOwner;
    struct tokenDetails{
        address seller;
        uint128 basePrice; // base price
        uint256 duration;
        uint256 maxBid;
        address maxBidUser;
        bool isActive;
        uint256[] bidAmounts;
        address[] users; 
    }
    mapping(address => mapping(uint256 => tokenDetails)) public tokenToAuction;
    mapping(address => mapping(uint256 => mapping(address => uint256))) public bids;

    constructor(){
        scOwner=msg.sender;
    }
    // seller create an auction for one of item
    function createTokenAuction(
        address _nft,
        uint256 _tokenId,
        uint128 _price,
        uint256 _duration
    ) external {
        require(msg.sender != address(0),"Invalid Address");
        require(_nft != address(0),"Invalid Account");
        require(_price > 0,"price should be greater than 0");
        require(_duration>0, "Invalid duration value");
        tokenDetails memory _auction = tokenDetails({
            seller: msg.sender,
            basePrice: uint128(_price),
            duration: _duration,
            maxBid:0,
            maxBidUser: address(0),
            isActive:true,
            bidAmounts: new uint256[](0),
            users: new address[](0)
        });
        address owner = msg.sender;
        IERC721(_nft).safeTransferFrom(owner,address(this),_tokenId);
        tokenToAuction[_nft][_tokenId]=_auction;
    }

    //user bid for a nft,the max bid is compared and set if current bid highest
    function bid(address _nft, uint256 _tokenId) external payable{
        tokenDetails storage auction = tokenToAuction[_nft][_tokenId];
        require(msg.value >= auction.basePrice, "bid price is less than current price");
        require(auction.isActive,"auction not active");
        require(auction.duration> block.timestamp,"Deadline already passed");
        //get back the previous bid
        if (bids[_nft][_tokenId][msg.sender]>0){
            (bool success, )= msg.sender.call{value: bids[_nft][_tokenId][msg.sender]}("");
            require(success);
        }
        bids[_nft][_tokenId][msg.sender]=msg.value;
        if (auction.bidAmounts.length==0){
            auction.maxBid=msg.value;
            auction.maxBidUser=msg.sender;
        } else {
            uint256 lastIndex = auction.bidAmounts.length -1;
            require(auction.bidAmounts[lastIndex]< msg.value,"Current max bid is higher than your bid");
            auction.maxBid = msg.value;
            auction.maxBidUser=msg.sender;
        }
        auction.users.push(msg.sender);
        auction.bidAmounts.push(msg.value);
    }

    //when auction duration is over. The highest bid user get the nft and other bidders get Eth back
    function executeSale(address _nft, uint256 _tokenId) external{
        tokenDetails storage auction = tokenToAuction[_nft][_tokenId];
        require(auction.duration<= block.timestamp,"auction hasn't ended.");
        require(msg.sender==auction.seller,"Not seller");
        require(auction.isActive,"auction not active");
        auction.isActive = false;
        if (auction.bidAmounts.length==0){
            IERC721(_nft).safeTransferFrom(address(this), auction.seller, _tokenId);
        }else{
            // pay seller the max bid
            (bool success, )= auction.seller.call{value:auction.maxBid}("");
            require(success);
            // refund to other bidders
            for (uint256 i=0; i<auction.users.length;i++){
                if(auction.users[i]!=auction.maxBidUser){
                    (success, )=auction.users[i].call{
                        value: bids[_nft][_tokenId][auction.users[i]]
                    }("");
                    require(success);
                }
            }
            // transfer the nft to maxbidder
            IERC721(_nft).safeTransferFrom(
                address(this),
                auction.maxBidUser,
                _tokenId);
        }
    }
    // cancel auction by seller. refund to all bidders. refund the nft to seller
    function cancelAuction(address _nft, uint256 _tokenId) external {
        tokenDetails storage auction =tokenToAuction[_nft][_tokenId];
        require(auction.seller == msg.sender,"Not seller");
        require(auction.isActive,"auction not active");
        auction.isActive=false;
        for (uint256 i=0; i< auction.users.length; i++){
            (bool success, )=auction.users[i].call{
                value: bids[_nft][_tokenId][auction.users[i]]
                }("");
            require(success);
        }
        // transfer the nft to seller
        IERC721(_nft).safeTransferFrom(
            address(this),
            auction.seller,
            _tokenId);
    }
    function getTokenAuctionDetails (address _nft,uint256 _tokenId) public views returns (tokenDetails memory){
        tokenDetails memory auction = tokenToAuction[_nft][_tokenId];
        return auction;
    }
  

}