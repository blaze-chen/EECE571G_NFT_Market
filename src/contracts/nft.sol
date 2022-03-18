pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "hardhat/console.sol";

contract MyNFT is ERC721 {

    // Array that store hash of the pictures
    string[] public colors; 
    
    constructor() ERC721("MyNFT", "MNFT") {
    }


    function mint(string memory _color, address to) public {
        console.log("Trying to send tokens to %s", to);
        colors.push(_color);
        uint _id = colors.length - 1;
        console.log("Stored token is %s", _id);
        _mint(to, _id);
        address res = ownerOf(_id);
        console.log("The stored address is %s", res);
        
    }

}