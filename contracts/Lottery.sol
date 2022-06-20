pragma solidity >=0.4.21 <0.6.0;

contract Lottery {
    address public owner;

    constructor() public {
        owner = msg.sender; // msg.sender는 전역변수
    }

    function getSomeValue() public pure returns (uint256 value){
        return 5;
    }
}
