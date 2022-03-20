//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./photoAuction.sol";

contract MarketPlace is ReentrancyGuard, photoAuction{
    // the account that receives fees
    address payable public immutable feeAccount;
    // the fee percentage on sales
    uint public immutable feePercent;
    uint public itemCount;
    struct Item{
        uint itemId;
        IERC721 nft;
        uint tokenId;
        uint price;
        address payable seller;
        bool sold;
        uint totalReward;
        bool inAuction;
    }
    event Offered(
        uint itemId,
        address indexed nft,
        uint tokenId,
        uint price,
        address indexed seller
    );
    event Bought(
        uint itemId,
        address indexed nft,
        uint tokenId,
        uint price,
        address indexed seller,
        address indexed buyer
    );
    event Rewarded(
        uint itemId,
        address indexed nft,
        uint tokenId,
        uint price,
        uint rewarded,
        uint totalReward,
        address indexed seller,
        address indexed rewarder
    );

    mapping(uint => Item) public items;

    constructor (uint _feePercent) photoAuction(){
        feeAccount =payable(msg.sender);
        feePercent = _feePercent;
    }
    //sell Item
    function makeItem(IERC721 _nft, uint _tokenId, uint _price) external nonReentrant{
        require(_price>0, "Price must be greater than zero");
        itemCount++;
        _nft.transferFrom(msg.sender, address(this), _tokenId);
        items[itemCount] = Item(
            itemCount,
            _nft,
            _tokenId,
            _price,
            payable(msg.sender),
            false,
            0,
            false
        );
        // emit Offered event
        emit Offered(
            itemCount,
            address(_nft),
            _tokenId,
            _price,
            msg.sender
        );
    }
    // TD: add modifier, OnlyNotInAuction
    function purchaseItem(uint _itemId) external payable nonReentrant{
        uint _totalPrice = getTotalPrice(_itemId);
        Item storage item = items[_itemId];
        require(_itemId>0 && _itemId <= itemCount,"item doesn't exist");
        require(msg.value>=_totalPrice,"not enough ether to cover item price and market fee");
        require(!item.sold,"item already sold");
        //pay seller
        item.seller.transfer(item.price);
        //pay feeAccount
        feeAccount.transfer(_totalPrice-item.price);
        // update the item to sold
        item.sold=true;
        //transfer nft to buyer
        item.nft.transferFrom(address(this), msg.sender, item.tokenId);
        // emit Bought event
        emit Bought(
            _itemId,
            address(item.nft),
            item.tokenId,
            item.price,
            item.seller,
            msg.sender
        );
    }
    function getTotalPrice(uint _itemId) view public returns(uint){
        
        return(items[_itemId].price * (100+ feePercent)/100);
    }

    // other users give a like to this photo as well as give tiny reward
    function reward(uint _itemId) external payable{
        require(_itemId>0 && _itemId <= itemCount,"item doesn't exist");
        Item storage item = items[_itemId];
        require(!item.sold,"item already sold");
        require(msg.value>0,"reward should greater than 0");
        uint rewarded = msg.value;
        item.totalReward += rewarded;
        //give reward to seller
        item.seller.transfer(msg.value);
        //emit rewarded event
        emit Rewarded(
            _itemId,
            address(item.nft),
            item.tokenId,
            item.price,
            rewarded,
            item.totalReward,
            item.seller,
            msg.sender
            );
    }

    //seller creat an auction for existing item
    //OnlySeller
    function auctionItem(uint _itemId,uint _basePrice, uint256 _duration) external nonReentrant{
        Item storage item = items[_itemId];
        //transfer nft to seller
        item.nft.transferFrom(address(this), item.seller, item.tokenId);
        createTokenAuction(
            address(item.nft),
            item.tokenId,
            _basePrice,
            _duration
            );
        item.inAuction=true;
    }
    
    
    
}