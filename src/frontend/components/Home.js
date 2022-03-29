import { Row, Col, Button, ButtonToolbar } from 'react-bootstrap'
import homeImg from './homeImg.png'
import {
    Link
} from "react-router-dom";


const Home = () => {
  return (
    <div className="container-fluid mt-5">
      <div className="row">
        <main role="main" className="col-lg-12 mx-auto" style={{ maxWidth: '1000px' }}>
          <div className="content mx-auto">
            <Row>
                <Col xs={6}>
                    <h1 style={{ textAlign: 'left' }}>Explore, Purchase, and Sell Extraordinary NFTs</h1>
                    <h3 style={{ color: 'grey', textAlign: 'left' }}>Welcome to the NFT Marketplace</h3>
                    <p style={{ color: 'grey', textAlign: 'left' }}>A digital marketplace for crypto collectibles and non-fungible tokens (NFTs).
                     Buy, sell, and discover exclusive digital items.</p>
                    <ButtonToolbar className="custom-btn-toolbar">
                        <Button as={Link} to="/explore" variant="dark" size="lg"  style={{ marginRight: '15px' }}>
                            Explore
                        </Button>{' '}
                        <Button as={Link} to="/create" variant="outline-dark" size="lg"  style={{ marginLeft: '15px' }}>
                            Create
                        </Button>
                    </ButtonToolbar>
                </Col>
                <Col xs={6}>
                    <img src={homeImg} width="500" height="300" className="" alt="" />
                </Col>
            </Row>
          </div>
        </main>
      </div>
    </div>
  );
}

export default Home