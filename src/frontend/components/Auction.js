import { useState, useEffect } from 'react'
import { ethers } from "ethers"
import { Row, Col, Card, Button, ButtonToolbar, Form, ListGroup } from 'react-bootstrap'

const Auction = ({ marketplace, nft }) => {
  const [loading, setLoading] = useState(true)
  const [items, setItems] = useState([])
  const [price, setPrice] = useState(null)
  const [bidPrice, setBidPrice] = useState(0)
  const loadAuctionItems = async () => {
    // Load all items belongs to current address
    const itemCount = await marketplace.itemCount()
    const address = await marketplace.currentAddress()
    let items = []
    for (let i = 1; i <= itemCount; i++) {
      const item = await marketplace.items(i)
      if (!item.sold && item.inAuction) {
        // get uri url from nft contract
        const uri = await nft.tokenURI(item.tokenId)
        // use uri to fetch the nft metadata stored on ipfs 
        const response = await fetch(uri)
        const metadata = await response.json()
        // get total price of item (item price + fee)
        const auction = await marketplace.getAuctionDetails(item.itemId)
        console.log(ethers.utils.formatEther(auction.basePrice))
        // Add item to items array
        items.push({
          itemId: item.itemId,
          seller: item.seller,
          name: metadata.name,
          description: metadata.description,
          image: metadata.image,
          sold: item.sold,
          basePrice: auction.basePrice,
          maxBid: auction.maxBid,
          maxBidUser: auction.maxBidUser,
          bidAmounts: auction.bidAmounts,
          users: auction.users
        })
      }
    }
    setLoading(false)
    setItems(items)
  }

  const rewardItem = async (item) => {
    const rewardPrice = 0.02
    const reward = ethers.utils.parseEther(rewardPrice.toString())
    await (await marketplace.reward(item.itemId, {value: reward})).wait()
  }

  const bid = async (item) => {
    const bid = ethers.utils.parseEther(bidPrice.toString())
    await (await marketplace.bid(item.itemId, {value: bid})).wait()
    loadAuctionItems()
  }
  useEffect(() => {
    loadAuctionItems()
  }, [])
  if (loading) return (
    <main style={{ padding: "1rem 0" }}>
      <h2>Loading...</h2>
    </main>
  )
  return (
    <div className="flex justify-center">
      {items.length > 0 ?
        <div className="px-5 container">
          <Row xs={1} md={2} lg={4} className="g-4 py-5">
            {items.map((item, idx) => (
              <Col key={idx} className="overflow-hidden">
                <Card>
                  <Card.Img variant="top" src={item.image} />
                  <Card.Body color="secondary">
                    <Card.Title>{item.name}</Card.Title>
                    <Card.Text>
                      Seller: {item.seller}, Base Price {ethers.utils.formatEther(item.basePrice)} ETH
                    </Card.Text>
                    <Card.Text>
                      Current Maximum Bid is {ethers.utils.formatEther(item.maxBid)} ETH from {item.maxBidUser}
                    </Card.Text>
                  </Card.Body>
                  {/* <ListGroup variant="flush">
                    <ListGroup.Item></ListGroup.Item>
                    <ListGroup.Item>Dapibus ac facilisis in</ListGroup.Item>
                    <ListGroup.Item>Vestibulum at eros</ListGroup.Item>
                  </ListGroup> */}
                  <Card.Footer>
                    <div className='d-grid'>
                      <Button onClick={() => rewardItem(item)} variant="dark" size="sm" style={{ marginTop: '5px', marginBottom: '15px', background: '#ffc800',borderColor: '#ffc800' }}>
                        Reward the developer
                      </Button>
                      <Form.Control onChange={(e) => setBidPrice(e.target.value)} size="sm" required type="number" placeholder="Enter Bid Price in ETH" />
                      <Button disabled={item.inAuction} onClick={() => bid(item)} variant="dark" size="sm" style={{ marginTop: '5px', marginBottom: '5px'}}>
                        Bid this item
                      </Button>
                    </div>
                  </Card.Footer>
                </Card>
              </Col>
            ))}
          </Row>
        </div>
        : (
          <main style={{ padding: "1rem 0" }}>
            <h2>No listed assets</h2>
          </main>
        )}
    </div>
  );
}
export default Auction