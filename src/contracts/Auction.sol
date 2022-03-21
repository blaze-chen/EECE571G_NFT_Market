//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract Auction is ERC721URIStorage{
    using SafeMath for uint256;

    struct auctionItem{
        address payable seller;
        uint256 minbid;//minimum price by seller
        string tokenURI;
        bool exists;
        uint bidIncrement;//incremention of bid
    }
    struct bidding{
        uint highestBindingBid;
        address payable highestBidder;
    }
    //map id to A Item
    mapping(uint256 => auctionItem) private _items;
    address public owner;

    //Unique Image ID that are tokenized
    uint256 public _tokenIds;
    uint256 public _itemIds;
    bool public canceled;

    //mapping tokenid to a bidder funds list
    mapping(uint256=>mapping(address => uint256)) public fundsByBidder;
    //mapping tokenid to bidding
    mapping(uint256=>bidding) public bid;
    bool auctionstarted = false;
    bool firsttime=false;

    event LogBid(
        address bidder, 
        uint bid, 
        address highestBidder, 
        uint highestBid, 
        uint highestBindingBid
    );
    event LogWithdrawal(
        address withdrawer, 
        address withdrawalAccount, 
        uint amount
    );
    event LogCanceled();

    constructor() ERC721("DAu", "Auction"){
        owner=msg.sender;
    }
    //modifiers
    modifier ItemExist(uint256 id) {   //check if item exists
        require(_items[id].exists, "Not Found");
        _;
    }

    //Check if owner is calling
    modifier onlyNotOwner(uint256 id) {            
      auctionItem memory aItem = _items[id];   
      if (msg.sender == aItem.seller) revert();
      _;
    }
    //Auction only if is not cancelled
    modifier onlyNotCanceled{
        if (canceled) revert();
        _;
    }
    modifier onlyOwner(uint256 id){
        auctionItem memory aItem = _items[id]; 
        if (msg.sender != aItem.seller) revert();
        _;
    }
    modifier minbid(uint256 id){
        auctionItem memory aItem = _items[id];
        if(msg.value < aItem.minbid) revert();
        _;
    }

    function addAucItem(uint256 price,string memory tokenURI,uint _bidincrement) public{
        require(price >= 0, "Price cannot be lesss than 0");
        _itemIds ++;
        _items[_itemIds]=auctionItem(
            payable(msg.sender),
            price,
            tokenURI,
            true,
            _bidincrement
        );
    }

    function getAucItem(uint256 id) public view ItemExist(id) 
    returns(
        uint256,
        uint256,
        string memory,
        uint256
    ){
        auctionItem memory aItem=_items[id];
        bidding memory aBid = bid[id];
        return (id,aItem.minbid,aItem.tokenURI,aBid.highestBindingBid);
    }

    function cancelAuction(uint256 id) public payable 
    onlyOwner(id) 
    onlyNotCanceled() 
    returns (bool success){
        canceled = true;
        //mint token if auctionstarted
        if (auctionstarted==true){
            auctionItem memory aItem = _items[id];
            bidding storage aBid=bid[id];
            _tokenIds++;
            _safeMint(msg.sender, _tokenIds);
            _setTokenURI(_tokenIds, aItem.tokenURI);
            // the auction's owner should be allowed to withdraw the highestBindingBid
            if (aBid.highestBindingBid==0) revert();
            fundsByBidder[id][aBid.highestBidder]-= aBid.highestBindingBid;
            //send the funds
            if (!payable(msg.sender).send(aBid.highestBindingBid)) revert();
        }
        emit LogCanceled();
        return true;
    }

    function placeBid(uint256 id) public payable 
    onlyNotCanceled 
    onlyNotOwner(id) 
    minbid(id) 
    returns(bool success){
        // reject payments of 0 ETH
        if (msg.value == 0) revert();
        bidding storage aBid = bid[id]; 
        auctionstarted = true;
        auctionItem memory aItem = _items[id];
        uint newBid = fundsByBidder[id][msg.sender] + msg.value;
        
        if(newBid<=aBid.highestBindingBid) revert();

        // grab the previous highest bid
        uint highestBid = fundsByBidder[id][aBid.highestBidder];

        // updating fundsByBidder
        fundsByBidder[id][msg.sender] = newBid;

        // if the user has overbid the highestBindingBid but not the highestBid
        if (newBid <= highestBid){
            if(newBid+aItem.bidIncrement> highestBid){
                aBid.highestBindingBid = highestBid;
            }
            else{
                aBid.highestBindingBid = newBid+aItem.bidIncrement;
            }

        }else{
            if (msg.sender != aBid.highestBidder){
               aBid.highestBidder = payable(msg.sender);
               if (newBid+aItem.bidIncrement> highestBid){
                   if(firsttime==false)
                   aBid.highestBindingBid = highestBid;
                   else {
                       aBid.highestBindingBid = aItem.minbid + aItem.bidIncrement;
                       firsttime=true;
                   }
               }else{
                   aBid.highestBindingBid = newBid+aItem.bidIncrement;
               }
            }
            highestBid = newBid;
        }
        emit LogBid(msg.sender, newBid, aBid.highestBidder, highestBid, aBid.highestBindingBid);
        return true;
    }

    function withdraw(uint256 id) public payable onlyNotOwner(id) 
    returns (bool success){
        require(canceled==true);
        require(auctionstarted==true);
        address payable withdrawalAccount;
        uint withdrawalAmount;
        bidding storage aBid = bid[id];
        if (msg.sender == aBid.highestBidder) {
            // the highest bidder should only be allowed to withdraw the difference between their
            // highest bid and the highestBindingBid
            withdrawalAccount = aBid.highestBidder;
            withdrawalAmount = fundsByBidder[id][aBid.highestBidder];
        }
        else {
            // anyone who participated but did not win the auction should be allowed to withdraw
            // the full amount of their funds
            withdrawalAccount = payable(msg.sender);
            withdrawalAmount = fundsByBidder[id][withdrawalAccount];
        }

        if (withdrawalAmount == 0) revert();

        fundsByBidder[id][withdrawalAccount] -= withdrawalAmount;

        // send the funds
        if (!payable(msg.sender).send(withdrawalAmount)) revert();

        emit LogWithdrawal(msg.sender, withdrawalAccount, withdrawalAmount);

        return true;
    }
}