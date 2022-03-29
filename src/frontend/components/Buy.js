import { Row, Col, Button, ButtonToolbar } from 'react-bootstrap'
import item from './item.png'
import {
    Link
} from "react-router-dom";


const Buy = () => {
  return (
    <div className="container-fluid mt-5">
        <Row className="justify-content-md-center">
            <Col md="auto"><h1>NFT Name: </h1></Col>
        </Row>
        <Row className="justify-content-md-center">
            <Col md="auto"><img src={item} width="600" height="300" className="" alt="" /></Col>
        </Row>
        <br></br>
        <Row className="justify-content-md-center" style={{ color: 'grey' }}>
            <Col md="auto"><h4>Owner:</h4></Col>
            <Col md="auto"><h4>Designer:</h4></Col>
        </Row>
        <Row className="justify-content-md-center"  style={{ color: 'grey' }}>
            <Col md="auto"><h4>Price:</h4></Col>
            <Col md="auto"><h4>In Auction:</h4></Col>
        </Row>
        <br></br>
        <Row className="justify-content-md-center">
        <Button as={Link} to="/explore" variant="dark" size="lg"  style={{ marginRight: '15px', width: '200px' }}>
            Buy this
        </Button>{' '}
        </Row>
    </div>
  );
}

export default Buy