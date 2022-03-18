const { utils } = require("ethers");

async function main(){
    // Get owner/deployer's wallet address
    const [owner] = await hre.ethers.getSigners();
    // Get contract that we want to deploy
    const contractFactory=await hre.ethers.getContractFactory("NFT");
    // Deploy contract with the correct constructor arguments
    const nft = await contractFactory.deploy();

    const MarketPlace= await hre.ethers.getContractFactory("MarketPlace");
    const marketPlace = await MarketPlace.deploy(1);

    // Wait for this transaction to be mined
    await nft.deployed();
    await marketPlace.deployed();

    //Get contract address
    console.log("NFT Contract deployed to:", nft.address);
    console.log("MarketPlace Contract deployed to:", marketPlace.address);
    // // Reserve NFTs
    // let txn= await contract.reserveNFTs();
    // await txn.wait();
    // console.log("10 NFTs have been reserved");

    // // Mint 3 NFTs by sending 0.03 ether
    // txn = await contract.mintNFTs(3,{value: utils.parseEther('0.003')});
    // await txn.wait()

    // // Get all token IDs of the owner
    // let tokens = await contract.tokensOfOwner(owner.address)
    // console.log("Owner has tokens: ", tokens);

    // await contract.withdraw();

}
main().then(()=>process.exit(0)).catch((error)=>{
    console.error(error);
    process.exit(1);
});