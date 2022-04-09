import { Row, Col, Button, ButtonToolbar, header } from 'react-bootstrap'
import homeImg from './homeImg.png'
import {
    Link
} from "react-router-dom";


const Home = () => {
  return (
    <div className="container-fluid mt-5">
      <div style={{width:'500px', float:'left', marginLeft:'100px', marginTop:'50px'}}>
          <h1 style={{ textAlign: 'left',fontFamily: 'Open Sans',lineHeight: '110%' }}>Explore, Purchase, and Sell Extraordinary NFTs</h1>
          <h3 style={{ color: 'grey', textAlign: 'left',fontFamily: 'Open Sans' }}>Welcome to the NFT Marketplace</h3>
          <p style={{ color: 'grey', textAlign: 'left',fontFamily: 'Open Sans'  }}>A digital marketplace for crypto collectibles and non-fungible tokens (NFTs).
          Buy, sell, and discover exclusive digital items.</p>
          <ButtonToolbar className="custom-btn-toolbar">
            <Button as={Link} to="/explore" variant="dark" size="lg"  style={{ width: '200px', background: '#ffc800',borderColor: '#ffc800' }}>
                Explore
            </Button>{' '}
            <Button as={Link} to="/create" variant="outline-dark" size="lg"  style={{ width: '200px', marginLeft: '15px' }}>
                Create
            </Button>
          </ButtonToolbar>
      </div>
      <div>
        <img src={homeImg} width="700" height="400" className="" alt="" />
      </div>
                
    </div>
  );
}

export default Home