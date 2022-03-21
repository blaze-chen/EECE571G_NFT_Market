const { expect } = require("chai");
const { ethers } = require("hardhat");
const toWei =(num) => ethers.utils.parseEther(num.toString())
const fromWei = (num) => ethers.utils.formatEther(num)
const BigNumber = require('big-number');


describe("NFTMarketplace",function(){
    let deployer,addr1,addr2,nft,marketPlace;
    let feePercent=1;
    let URI="sample URI";
    beforeEach(async function(){
        const NFT = await ethers.getContractFactory("NFT");
        const MarketPlace= await ethers.getContractFactory("MarketPlace");
        [deployer,addr1,addr2, addr3, addr4]= await ethers.getSigners();
        nft= await NFT.deploy();
        marketPlace=await MarketPlace.deploy(feePercent);
    });
    describe("Deployment",function(){
        it("should track name and symbol of nft collection",async function(){
            expect(await nft.name()).to.equal("DApp NFT")
            expect(await nft.symbol()).to.equal("DApp")
        });
        it("Should track feeAccount and feePercent of the marketPlace",async function(){
            expect(await marketPlace.feeAccount()).to.equal(deployer.address);
            expect(await marketPlace.feePercent()).to.equal(feePercent);
        });
    })
    describe("Minting NFTs",function(){
        it("should track each minted NFT",async function(){
            await nft.connect(addr1).mint(URI);
            expect(await nft.tokenCount()).to.equal(1);
            expect(await nft.balanceOf(addr1.address)).to.equal(1);
            expect(await nft.tokenURI(1)).to.equal(URI);
            await nft.connect(addr2).mint(URI);
            expect(await nft.tokenCount()).to.equal(2);
            expect(await nft.balanceOf(addr2.address)).to.equal(1);
            expect(await nft.tokenURI(2)).to.equal(URI);
        })
    })
    describe("Making marketplace items",function(){
        beforeEach(async function(){
            //addr1 mints an nft
            await nft.connect(addr1).mint(URI);
            //addr1 approves marketplace to spend nft
            await nft.connect(addr1).setApprovalForAll(marketPlace.address,true)
        })
        it("Should track newly created item, transfer NFT from seller to marketplace and emit Offered event",async function(){
            await expect(marketPlace.connect(addr1).makeItem(nft.address,1,toWei(1)))
            .to.emit(marketPlace,"Offered")
            .withArgs(
                1,
                nft.address,
                1,
                toWei(1),
                addr1.address)
        //Owner of NFT should now be the marketPlace
        expect(await nft.ownerOf(1)).to.equal(marketPlace.address);
        //Item count should now equal to 1
        expect(await marketPlace.itemCount()).to.equal(1);
        const item = await marketPlace.items(1);
        expect(item.itemId).to.equal(1);
        expect(item.nft).to.equal(nft.address);
        expect(item.tokenId).to.equal(1);
        expect(item.price).to.equal(toWei(1));
        expect(item.sold).to.equal(false);
        expect(item.totalReward).to.equal(0);
        expect(item.inAuction).to.equal(false);
        });
        it("should fail if price is set to zero",async function(){
            await expect(
                marketPlace.connect(addr1).makeItem(nft.address,1,0)
            ).to.be.revertedWith("Price must be greater than zero");
        });
    });
    describe("Purchasing marketPlace items",function(){
        let price = 2;
        let totalPriceInWei;
        beforeEach(async function(){
            //addr1 mints an nft
            await nft.connect(addr1).mint(URI);
            //addr1 approves marketPlace to spend nft
            await nft.connect(addr1).setApprovalForAll(marketPlace.address,true);
            //addr1 makes their nft a marketPlace item.
            await marketPlace.connect(addr1).makeItem(nft.address,1,toWei(price))
        })
        it("Should update item as sold,pay seller,transfer NFT to buyer,charge fees and emit a Bought event",async function(){
            const sellerInitialEthBal= await addr1.getBalance();
            const feeAccountInitialEthBal= await deployer.getBalance();
            // fetch items total price(market fees + item price)
            totalPriceInWei= await marketPlace.getTotalPrice(1);
            // addr2 purchases item.
            // should be emit correctly now
            await expect(marketPlace.connect(addr2).purchaseItem(1,{value: totalPriceInWei}))
            .to.emit(marketPlace,"Bought")
            .withArgs(
                1,
                nft.address,
                1,
                toWei(price),
                addr1.address,
                addr2.address
            );
            const sellerFinalEthBal= await addr1.getBalance();
            const feeAccountFinalEthBal= await deployer.getBalance();
            //seller should receive payment for the price of the NFT sold.
            expect(+fromWei(sellerFinalEthBal)).to.equal(+price + +fromWei(sellerInitialEthBal));
            // calculate fee
            const fee=(feePercent/100)*price;
            // feeAccount should receive fee
            expect(feeAccountFinalEthBal).to.equal(feeAccountInitialEthBal.add(toWei(fee)));
            // The buyer should now own the nft
            expect(await nft.ownerOf(1)).to.equal(addr2.address);
            //Item should be marked as sold
            expect((await marketPlace.items(1)).sold).to.equal(true)
        });
        it("Should fail for invalid item ids,sold items and when not enough ether is paid",async function(){
            
            // Fails for invalid item ids
            await expect(
                marketPlace.connect(addr2).purchaseItem(2,{value: totalPriceInWei})
            ).to.be.revertedWith("item doesn't exist");
            await expect(
                marketPlace.connect(addr2).purchaseItem(0,{value: totalPriceInWei})
            ).to.be.revertedWith("item doesn't exist");
            //Fails when no enough ether is paid
            await expect(
                marketPlace.connect(addr2).purchaseItem(1,{value: toWei(price)})
            ).to.be.revertedWith("not enough ether to cover item price and market fee");
            //addr2 purchases item1
            await marketPlace.connect(addr2).purchaseItem(1,{value: totalPriceInWei});
            // deployer tries to purchase item 1 after it is sold.
            await expect(
                marketPlace.connect(deployer).purchaseItem(1,{value: totalPriceInWei})
            ).to.be.revertedWith("The item is sold!");
        });
        it("Should be able to re-sell item after purchasing",async function(){
            // price to pay the item
            totalPriceInWei= await marketPlace.getTotalPrice(1);
            // addr2 purchases item.
            // should be emit correctly now
            await expect(marketPlace.connect(addr2).purchaseItem(1,{value: totalPriceInWei}))
            .to.emit(marketPlace,"Bought")
            .withArgs(
                1,
                nft.address,
                1,
                toWei(price),
                addr1.address,
                addr2.address
            );
            // addr2 re-sell the token with price 10 ETH
            await nft.connect(addr2).setApprovalForAll(marketPlace.address,true);
            await expect(marketPlace.connect(addr2).sellItem(1, toWei(10)))
            .to.emit(marketPlace, "SellAgain")
            .withArgs(
                1,
                nft.address,
                1,
                toWei(10),
                addr2.address
            );
            // addr3 purchase the token 
            totalPriceInWei= await marketPlace.getTotalPrice(1);
            await expect(marketPlace.connect(addr3).purchaseItem(1,{value: totalPriceInWei}))
            .to.emit(marketPlace,"Bought")
            .withArgs(
                1,
                nft.address,
                1,
                toWei(10),
                addr2.address,
                addr3.address
            );

        });

    });
    describe("Other user reward an item",function(){
        let price=2;
        beforeEach(async function(){
            //addr1 mints an nft
            await nft.connect(addr1).mint(URI);
            //addr1 approves marketPlace to spend nft
            await nft.connect(addr1).setApprovalForAll(marketPlace.address,true);
            //addr1 makes their nft a marketPlace item.
            await marketPlace.connect(addr1).makeItem(nft.address,1,toWei(price))
        })
        it("Should update totalReward the seller received,emit reward event",async function(){
            //Seller initial balance
            const sellerInitialEthBal= await addr1.getBalance();
            //addr2 reward this item
            await expect(marketPlace.connect(addr2).reward(1,{value:toWei(0.01)}))
            .to.emit(marketPlace,"Rewarded")
            .withArgs(
                1,
                nft.address,
                1,
                toWei(price),
                toWei(0.0001),
                toWei(0.0001),
                addr1.address,
                addr2.address
            );
            //deployer reward this item
            await marketPlace.connect(deployer).reward(1,{value:toWei(0.01)});
            const totalReward=(await marketPlace.items(1)).totalReward;
            expect(totalReward).to.equal(toWei(0.0002));
            // Seller receive the reward money
            const sellerAfterEthBal= await addr1.getBalance();
            expect(sellerAfterEthBal).to.equal(sellerInitialEthBal.add(totalReward));
        })
        it("Should fail for invalid itemId or sold items or invalid value",async function(){
            //fail for invalid itemId
            await expect(marketPlace.connect(addr2).reward(5,{value:toWei(0.01)}))
            .to.be.revertedWith("item doesn't exist");
            //fail for invalid reward value
            await expect(marketPlace.connect(addr2).reward(1,{value:toWei(0)}))
            .to.be.revertedWith("reward should greater than 0");
        })
    });
    describe("Test bidding",function(){
        let price=2;
        beforeEach(async function(){
            //addr1 mints an nft
            await nft.connect(addr1).mint(URI);
            //addr1 approves marketPlace to spend nft
            await nft.connect(addr1).setApprovalForAll(marketPlace.address,true);
            //addr1 makes their nft a marketPlace item.
            await marketPlace.connect(addr1).makeItem(nft.address,1,toWei(price));
        })
        it("Should create auction correctly and finish bidding successfuly",async function(){
            const addr2InitialEthBal= await addr2.getBalance();
            const feeAccountInitialEthBal= await deployer.getBalance();
            //addr1 create auction
            await expect(marketPlace.connect(addr1).auctionItem(1, toWei(5), 1000)).
            to.emit(marketPlace, "auctionCreated")
            .withArgs(
                1,
                nft.address,
                1,
                toWei(5),
                addr1.address,
                1000
            );
            // addr2 bid 6 ETH
            await expect(marketPlace.connect(addr2).bid(1, {value:toWei(6)})).
            to.emit(marketPlace, "Bidded")
            .withArgs(
                1,
                1,
                toWei(6),
                addr1.address,
                addr2.address,
                1000
            );
            const addr2AfterEthBal= await addr2.getBalance();
            const feeAccountAfterEthBal= await deployer.getBalance();
            expect(feeAccountAfterEthBal).to.equal(feeAccountInitialEthBal.add(toWei(6)));
            // expect(addr2AfterEthBal).to.equal(addr2InitialEthBal.sub(toWei(6)));

            // addr3 bid 7 ETH
            await expect(marketPlace.connect(addr3).bid(1, {value:toWei(7)})).
            to.emit(marketPlace, "Bidded")
            .withArgs(
                1,
                1,
                toWei(7),
                addr1.address,
                addr3.address,
                1000
            );
            const feeAccountAfterEthBal3= await deployer.getBalance();
            expect(feeAccountAfterEthBal3).to.equal(feeAccountAfterEthBal.add(toWei(7)));
            const addr1InitialETHBal = await addr1.getBalance();
            // finish auction
            await expect(marketPlace.connect(deployer).executeSale(1))
            .to.emit(marketPlace, "auctionDeal")
            .withArgs(
                1,
                nft.address,
                1,
                toWei(7),
                addr1.address,
                addr3.address
            )
            // const addr1AfterETHBal = await addr1.getBalance();
            // const myFee= toWei(7).mul(feePercent).div(100+feePercent);
            // expect(addr1AfterETHBal).to.equal(addr1InitialETHBal.add(myFee));
        })
    });
})