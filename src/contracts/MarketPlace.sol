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
    uint private _rewardPrice = 1*10**16; // reward 0.0001 ETH
    struct Item{
        uint itemId;
        IERC721 nft;
        uint tokenId;
        uint price;
        address payable seller;
        address payable developer;
        bool sold;
        uint totalReward;
        bool inAuction;
    }
    struct auctionDetails{
        address payable seller;
        uint128 basePrice;
        uint256 duration;
        uint256 maxBid;
        address payable maxBidUser;
        bool isActive;
        uint256[] bidAmounts;
        address [] users; 
    }
    event Offered(
        uint itemId,
        address indexed nft,
        uint tokenId,
        uint price,
        address indexed seller
    );
    event SellAgain(
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
    event sellCancelled(
        uint itemId,
        address indexed nft,
        uint tokenId,
        address indexed seller,
        address indexed tokenOwner
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
        uint256 maxBidPrice,
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
    //developer make Item for sell
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


    function currentAddress() public view returns(address ){
        return msg.sender;
    }


    // sell item after buying it (means seller is not the original developer)
    // onlyNotInSelling
    function sellItem(uint _itemId, uint _price) public nonReentrant 
    onlySeller(_itemId) 
    itemExist(_itemId){
        Item storage item = items[_itemId];
        require(item.sold,"Should be a re-sell item.");
        item.nft.transferFrom(msg.sender,address(this),item.tokenId);
        item.sold = false;
        item.price = _price;
        // emit Offered event
        emit SellAgain(
            item.itemId,
            address(item.nft),
            item.tokenId,
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
        //change the seller to current buyer
        item.seller = payable(msg.sender);
    }
    function getTotalPrice(uint _itemId) view public returns(uint){
        
        return(items[_itemId].price * (100+ feePercent)/100);
    }
    function cancelSell(uint _itemId) external onlySeller(_itemId){
        // transfer the nft to seller
        Item storage aItem= items[_itemId];
        aItem.nft.transferFrom(
            address(this),
            aItem.seller,
            aItem.tokenId);
        aItem.sold=true;
        address tokenOwner=aItem.nft.ownerOf(aItem.tokenId);

        // emit sellCancelled event
        emit sellCancelled(
            _itemId,
            address(aItem.nft),
            aItem.tokenId,
            aItem.seller,
            tokenOwner
        );
    }
    
    /* Reward function
    other users give a like to this photo as well as give tiny reward */
    function reward(uint _itemId) external payable nonReentrant{
        require(_itemId>0 && _itemId <= itemCount,"item doesn't exist");
        Item storage item = items[_itemId];
        //require(!item.sold,"item already sold");
        require(msg.value>_rewardPrice ,"reward should greater than 0.0001ETH");
        item.totalReward += _rewardPrice;
        //give reward to developer
        item.developer.transfer(_rewardPrice);
        //emit rewarded event
        emit Rewarded(
            _itemId,
            address(item.nft),
            item.tokenId,
            item.price,
            _rewardPrice,
            item.totalReward,
            item.developer,
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
            seller: payable(msg.sender),
            basePrice: _basePrice,
            duration: _duration,
            maxBid:0,
            maxBidUser: payable(address(0)),
            isActive:true,
            bidAmounts: new uint256[](0),
            users: new address[](0)
        });
        itemToAuction[_itemId]=_auction;

        emit auctionCreated(
            item.itemId,
            address(item.nft),
            item.tokenId,
            _basePrice,
            msg.sender,
            _duration
        );
    }

    //user bid for an item,the max bid is compared and set if current bid highest
    //itemExist onlyNotSeller
    function bid(uint _itemId) external payable onlyNotSeller(_itemId) itemExist(_itemId){
        auctionDetails storage auction = itemToAuction[_itemId];
        require(msg.value >= auction.basePrice*(100+ feePercent)/100, "bid price is less than base price+market fee");
        require(auction.isActive,"Auction not active");
        //require(auction.duration> block.timestamp,"Deadline already passed");
        //get back the previous bid
        if (bids[_itemId][msg.sender]>0){
            payable(msg.sender).transfer(bids[_itemId][msg.sender]);
        }
        // }
        bids[_itemId][msg.sender]=msg.value;
        // If there is no current bid, then this bid is the maximum
        if (auction.bidAmounts.length==0){
            auction.maxBid= msg.value;
            auction.maxBidUser=payable(msg.sender);
        } else {
            // Compare it with highest bid, required to be higher than that
            require(auction.maxBid < msg.value,"Current max bid is higher than your bid");
            auction.maxBid = msg.value;
            auction.maxBidUser= payable(msg.sender);
        }
        auction.users.push(payable(msg.sender));
        auction.bidAmounts.push(msg.value);
    }

    //when auction duration is over. The highest bid user get the nft and other bidders get Eth back
    function executeSale(uint _itemId) external{
        auctionDetails storage auction = itemToAuction[_itemId];
        require(block.timestamp >= auction.duration,"auction hasn't ended.");
        require(msg.sender==auction.seller,"Not seller");
        require(auction.isActive,"Auction not active");
        auction.isActive = false;
        Item storage aItem = items[_itemId];
        if (auction.bidAmounts.length==0){
            aItem.nft.transferFrom(address(this), auction.seller, aItem.tokenId);
        }else{
            // change the calculation function
            uint fee = auction.maxBid*feePercent/(100);
            // Contract pay seller the max bid
            auction.seller.transfer(auction.maxBid-fee);
            // Contract pay fee to feeAccount
            feeAccount.transfer(fee);
            // Contract refund to other bidders
            for (uint256 i=0; i<auction.users.length;i++){
                if(auction.users[i]!=auction.maxBidUser){
                    payable(auction.users[i]).transfer(bids[_itemId][auction.users[i]]);
                }
            }
            // transfer the nft to maxbidder
            aItem.nft.transferFrom(
                address(this),
                auction.maxBidUser,
                aItem.tokenId);
        }
        aItem.inAuction = false;
        aItem.sold = true;
        aItem.seller = payable(auction.maxBidUser);

        emit auctionDeal(
            _itemId,
            address(aItem.nft),
            aItem.tokenId,
            auction.maxBid,
            auction.seller,
            auction.maxBidUser);
    }

    // cancel auction by seller. refund to all bidders. refund the nft to seller
    function cancelAuction(uint _itemId) external itemExist(_itemId){
        Item storage aItem = items[_itemId];
        auctionDetails storage auction =itemToAuction[_itemId];
        require(auction.seller == msg.sender,"Not seller");
        require(auction.isActive,"Auction not active");
        auction.isActive=false;
        aItem.inAuction=false;
        // pay back to bidders
        for (uint256 i=0; i< auction.users.length; i++){
            payable(auction.users[i]).transfer(bids[_itemId][auction.users[i]]);
        }
        // transfer the nft to seller
        aItem.nft.transferFrom(
            address(this),
            auction.seller,
            aItem.tokenId);
        aItem.sold=true;
        address tokenOwner=aItem.nft.ownerOf(aItem.tokenId);
        
        emit auctionCanceled(
            _itemId,
            address(aItem.nft),
            aItem.tokenId,
            auction.seller,
            tokenOwner);
    }
    function getAuctionDetails (uint _itemId) public view returns (auctionDetails memory){
        Item memory aItem = items[_itemId];
        require(aItem.inAuction,"Item is not in auction");
        auctionDetails memory auction = itemToAuction[_itemId];
        return auction;
    }

    
}