//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract MarketPlace is ReentrancyGuard{
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
    struct auctionDetails{
        address seller;
        uint128 basePrice;
        uint256 duration;
        uint256 maxBid;
        address maxBidUser;
        bool isActive;
        uint256[] bidAmounts;
        address[] users; 
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
    event auctionCreated(
        uint itemId,
        address indexed nft,
        uint tokenId,
        uint128 basePrice,
        address indexed seller,
        uint256 duration
    );
    event auctionDeal(
        uint itemId,
        address indexed nft,
        uint tokenId,
        uint128 maxBidPrice,
        address indexed seller,
        address indexed maxBidder
    );
    event auctionCanceled(
        uint itemId,
        address indexed nft,
        uint tokenId,
        address indexed seller,
        address indexed tokenOwner
    );

    //map itemId to Item status 
    mapping(uint => Item) public items;
    //map itemId to auctionDetails
    mapping(uint => auctionDetails) public itemToAuction;
    //map itemId to bids list
    mapping(uint => mapping(address => uint256)) public bids;
    //Check if seller is calling
    modifier onlySeller(uint _itemId) {
        Item memory aItem = items[_itemId];
        require(msg.sender==aItem.seller,"Only can be called by seller");
        _;
    }
    modifier onlyNotSeller(uint _itemId) {
        Item memory aItem = items[_itemId];
        require(msg.sender!=aItem.seller,"Seller cannot call this function");
        _;
    }
    //Check if item is sold
    modifier onlyNotSold(uint _itemId) {
        Item memory aItem = items[_itemId];
        require(!aItem.sold,"The item is sold!");
        _;
    }
    //Check if item is in auction
    modifier onlyNotAuction(uint _itemId) {
        Item memory aItem = items[_itemId];
        require(!aItem.inAuction,"The item is in auction!");
        _;
    }
    //Check if item exist
    modifier itemExist(uint _itemId){
        require(_itemId>0 && _itemId <= itemCount,"item doesn't exist");
        _;
    }

    constructor (uint _feePercent){
        feeAccount =payable(msg.sender);
        feePercent = _feePercent;
    }
    //make Item for sell
    function makeItem(IERC721 _nft, uint _tokenId, uint _price) public nonReentrant{
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
    
    function purchaseItem(uint _itemId) external payable nonReentrant onlyNotAuction(_itemId) onlyNotSold(_itemId){
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
    
    /* Reward function
    other users give a like to this photo as well as give tiny reward */
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

    /* Auction function
     */
    //seller creat an auction for existing selling item
    //onlySeller onlyNotSold itemExist
    function auctionItem(uint _itemId,uint128 _basePrice, uint256 _duration) public 
    onlySeller(_itemId) 
    onlyNotSold(_itemId) 
    onlyNotAuction(_itemId) 
    itemExist(_itemId){
        Item storage item = items[_itemId];
        item.inAuction=true;
        require(_basePrice > 0,"Base price should be greater than 0");
        require(_duration > 0, "Invalid duration value");
        auctionDetails memory _auction = auctionDetails({
            seller: msg.sender,
            basePrice: _basePrice,
            duration: _duration,
            maxBid:0,
            maxBidUser: address(0),
            isActive:true,
            bidAmounts: new uint256[](0),
            users: new address[](0)
        });
        itemToAuction[_itemId]=_auction;

        emit auctionCreated(
            item.itemId,
            address(_nft),
            item.tokenId,
            _basePrice,
            msg.sender,
            _duration
        );
    }

    // seller create an auction directly from token
    function createAuction(IERC721 _nft,uint _tokenId, uint128 _basePrice,uint256 _duration) external nonReentrant{   
        itemCount++;
        _nft.transferFrom(msg.sender, address(this), _tokenId);
        items[itemCount] = Item(
            itemCount,
            _nft,
            _tokenId,
            _basePrice,
            payable(msg.sender),
            false,
            0,
            true
        );
        auctionItem(itemCount,_basePrice,_duration);
    }
    //user bid for an item,the max bid is compared and set if current bid highest
    //itemExist onlyNotSeller
    function bid(uint _itemId) external payable onlyNotSeller(_itemId) itemExist(_itemId){
        auctionDetails storage auction = itemToAuction[_itemId];
        require(msg.value >= auction.basePrice*(100+ feePercent)/100, "bid price is less than base price+market fee");
        require(auction.isActive,"auction not active");
        require(auction.duration> block.timestamp,"Deadline already passed");
        //get back the previous bid
        if (bids[_itemId][msg.sender]>0){
            (bool success, )= msg.sender.call{value: bids[_itemId][msg.sender]*(100+ feePercent)/100}("");
            require(success);
        }
        bids[_itemId][msg.sender]=msg.value;
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
    function executeSale(uint _itemId) external{
        auctionDetails storage auction = itemToAuction[_itemId];
        require(block.timestamp >= auction.duration,"auction hasn't ended.");
        require(msg.sender==auction.seller,"Not seller");
        require(auction.isActive,"Auction not active");
        auction.isActive = false;
        Item memory aItem = items[_itemId];
        if (auction.bidAmounts.length==0){
            aItem.nft.safeTransferFrom(address(this), auction.seller, aItem.tokenId);
        }else{
            uint fee = auction.maxBid*feePercent/(100+feePercent);
            // pay seller the max bid
            (bool success, )= auction.seller.call{value:auction.maxBid-fee}("");
            require(success);
            // pay feeAccount
            (success, )=feeAccount.call{value:fee}("");
            require(success);
            // refund to other bidders
            for (uint256 i=0; i<auction.users.length;i++){
                if(auction.users[i]!=auction.maxBidUser){
                    (success, )=auction.users[i].call{
                        value: bids[_itemId][auction.users[i]]
                    }("");
                    require(success);
                }
            }
            // transfer the nft to maxbidder
            aItem.nft.safeTransferFrom(
                address(this),
                auction.maxBidUser,
                aItem.tokenId);
        }
        aItem.inAuction = false;
        aItem.sold = true;

        emit auctionDeal(
            _itemId,
            address(aItem.nft),
            aItem.tokenId,
            auction.maxBid,
            auction.seller,
            auction.maxBidder);
    }

    // cancel auction by seller. refund to all bidders. refund the nft to seller
    function cancelAuction(uint _itemId) external itemExist(_itemId){
        Item memory aItem = items[_itemId];
        auctionDetails storage auction =itemToAuction[_itemId];
        require(auction.seller == msg.sender,"Not seller");
        require(auction.isActive,"auction not active");
        auction.isActive=false;
        aItem.inAuction=false;
        for (uint256 i=0; i< auction.users.length; i++){
            (bool success, )=auction.users[i].call{
                value: bids[_itemId][auction.users[i]]
                }("");
            require(success);
        }
        // transfer the nft to seller
        aItem.nft.safeTransferFrom(
            address(this),
            auction.seller,
            aItem.tokenId);
        address tokenOwner=aItem.nft.ownerOf(aItem.tokenId);
        
        emit auctionCanceled(
            _itemId,
            address(aItem.nft),
            aItem.tokenId,
            auction.seller,
            tokenOwner);
    }
    function getAuctionDetails (uint _itemId) public view returns (auctionDetails memory){
        auctionDetails memory auction = itemToAuction[_itemId];
        return auction;
    }

    
}