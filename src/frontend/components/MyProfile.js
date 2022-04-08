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
      console.log(item.developer)
      if (item.seller == address) {
        // get uri url from nft contract
        const uri = await nft.tokenURI(item.tokenId)
        // use uri to fetch the nft metadata stored on ipfs 
        const response = await fetch(uri)
        const metadata = await response.json()
        // get total price of item (item price + fee)
        const totalPrice = await marketplace.getTotalPrice(item.itemId)
        console.log(item.sold)
        // Add item to items array
        items.push({
          totalPrice,
          itemId: item.itemId,
          seller: item.seller,
          name: metadata.name,
          description: metadata.description,
          image: metadata.image,
          sold: item.sold
        })
      }
    }
    setLoading(false)
    setItems(items)
  }

  const sellItem = async (item) => {
    const listingPrice = ethers.utils.parseEther(price.toString())
    await (await marketplace.sellItem(item.itemId, listingPrice)).wait()
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
                  <Card.Img variant="top" src={item.image} />
                  <Card.Body color="secondary">
                    <Card.Title>{item.name}</Card.Title>
                    <Card.Text>
                      {item.description}
                    </Card.Text>
                  </Card.Body>
                  <Card.Footer>
                    <div className='d-grid'>
                      <Form.Control onChange={(e) => setPrice(e.target.value)} size="lg" required type="number" placeholder="Price in ETH" />
                      <Button disabled={!item.sold} onClick={() => sellItem(item)} variant="primary" size="lg">
                        Sell This Item
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