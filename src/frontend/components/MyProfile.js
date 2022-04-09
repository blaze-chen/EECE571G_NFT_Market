import { useState, useEffect } from 'react'
import { ethers } from "ethers"
import { Row, Col, Card, Button, ButtonToolbar, Form } from 'react-bootstrap'

const MyProfile = ({ marketplace, nft }) => {
  const [loading, setLoading] = useState(true)
  const [items, setItems] = useState([])
  const [price, setPrice] = useState(null)

  const loadMyItems = async () => {
    // Load all items belongs to current address
    const itemCount = await marketplace.itemCount()
    const address = await marketplace.currentAddress()
    let items = []
    for (let i = 1; i <= itemCount; i++) {
      const item = await marketplace.items(i)
      if (item.seller == address) {
        // get uri url from nft contract
        const uri = await nft.tokenURI(item.tokenId)
        // use uri to fetch the nft metadata stored on ipfs 
        const response = await fetch(uri)
        const metadata = await response.json()
        // get total price of item (item price + fee)
        const totalPrice = await marketplace.getTotalPrice(item.itemId)

        console.log("developer is:" + item.developer)
        console.log("Is item sold: "+ item.sold)
        console.log("The current seller is: "+item.seller)
        const address2 = await nft.ownerOf(item.itemId)
        console.log("the current owner is: "+ address2)
        // Add item to items array
        items.push({
          totalPrice,
          itemId: item.itemId,
          seller: item.seller,
          name: metadata.name,
          description: metadata.description,
          image: metadata.image,
          sold: item.sold,
          inAuction: item.inAuction
        })
      }
    }
    setLoading(false)
    setItems(items)
  }
  const executeSale = async (item) => {
    await (await marketplace.executeSale(item.itemId)).wait()
    loadMyItems()
  }
  const sellItem = async (item) => {
    console.log("current price is: "+price)
    const listingPrice = ethers.utils.parseEther(price.toString())
    await (await marketplace.sellItem(item.itemId, listingPrice)).wait()
    loadMyItems()
  }

  const auctionItem = async (item) =>{
    const listingPrice = ethers.utils.parseEther(price.toString())
    await (await marketplace.auctionItem(item.itemId, listingPrice, 10)).wait()
    console.log("put this item to auction!")
    loadMyItems()
  }

  useEffect(() => {
    loadMyItems()
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
                  <Card.Img variant="top" src={item.image}  style={{height: '18rem'}}/>
                  <Card.Body color="secondary">
                    <Card.Title>{item.name}</Card.Title>
                    <Card.Text>
                      {item.description}
                    </Card.Text>
                  </Card.Body>
                  <Card.Footer>
                    <div className='d-grid'>
                      <Form.Control onChange={(e) => setPrice(e.target.value)} size="sm" required type="number" placeholder="Price in ETH" />
                      <Button disabled={!item.sold} onClick={() => sellItem(item)} variant="dark" size="sm"  style={{ marginBottom: '5px', marginTop: '10px', background: '#ffc800',borderColor: '#ffc800' }}>
                        Sell This Item
                      </Button>
                      <Button disabled={item.sold || item.inAuction} onClick={() => auctionItem(item)} variant="dark" size="sm"  style={{ marginBottom: '5px', marginTop: '5px', background: '#ffc800',borderColor: '#ffc800' }}>
                        Put this item to Auction
                      </Button>
                      <Button disabled={item.sold} onClick={() => executeSale(item)} variant="dark" size="sm"  style={{ marginBottom: '5px', marginTop: '5px'}}>
                        Finalize the Auction
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
export default MyProfile