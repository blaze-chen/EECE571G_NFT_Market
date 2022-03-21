//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract NFT is ERC721URIStorage{
    uint public tokenCount;

    constructor() ERC721("DApp NFT","DApp"){}

    function mint(string memory _tokenURI) external returns(uint){
        tokenCount ++;
        _safeMint(msg.sender, tokenCount);
        //tokenURI: IPFS URL
        _setTokenURI(tokenCount, _tokenURI);
        return(tokenCount);
    }

}