import { Row, Col, Button, ButtonToolbar } from 'react-bootstrap'
import item from './item.png'

const Explore = () => {
  return (
    <div className="container-fluid mt-5">
        <Row className="justify-content-md-center">
            <Col md="auto"><h3>Total 3 Collections in the Market</h3></Col>
        </Row>
        <Row className="justify-content-md-center">
            <Col md="auto">
                <div>
                    <img src={item} width="300" height="200" className="" alt="" />
                    <h5>Name 1</h5>
                    
                </div>
            </Col>
            <Col md="auto">
                <div>
                    <img src={item} width="300" height="200" className="" alt="" />
                    <h5>Name 2</h5>
                </div>
            </Col>
            <Col md="auto">
                <div>
                    <img src={item} width="300" height="200" className="" alt="" />
                    <h5>Name 3</h5>
                </div>
            </Col>
        </Row>
       
    </div>
  );
}

export default Explore