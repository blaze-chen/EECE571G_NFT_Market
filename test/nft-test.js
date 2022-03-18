const { expect } = require("chai");
const { ethers } = require("hardhat");
const { BN, constants, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
// Note that the big number should be transfer as string
const firstTokenId = new BN('5042').toString();
const secondTokenId = new BN('79217').toString();

describe("Test NFT", function () {
    let NFT;
    let nft;
    let owner;
    let addr1;
    let addr2;
    let addrs;

    before(async function () {
        NFT = await ethers.getContractFactory("MyNFT");
        nft = await NFT.deploy();
        [owner, addr1, addr2,...addrs] = await ethers.getSigners();
        await nft.deployed(owner.address);
      });

    describe("Add a token to account", function () {
        it("1. Add a token to address who call this function", async function(){
            await expect(nft.mint("AAAAAA",owner.address)).
            to.emit(nft, "Transfer");
        });
    });

    describe("Verify the token that belongs to this account", function () {
        it("1. Add a token to address, it should present the address as msg.sender", async function(){
            nft.mint(ethers.utils.parseEther("100"),owner.address);
            nft.mint(firstTokenId,owner.address);
            // '1' is the hash
            // we need to write a "hash to unit" function
            expect(await nft.ownerOf('1')).equal(owner.address);
        });
    });

});