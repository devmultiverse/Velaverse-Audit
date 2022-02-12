// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract Whitelist is AccessControl {
    uint256 public rateFee;
    mapping(address => bool) public whiteLists;
    constructor(address _token){
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        rateFee = 2;
        whiteLists[_token] = true; //CLASS
    }
    function _getWhiteList(address token) public view returns (bool){
        return whiteLists[token];
    }
    function addWhiteList(address token) public onlyRole(DEFAULT_ADMIN_ROLE){
       whiteLists[token] = true;
    }
    function removeWhiteList(address token) public onlyRole(DEFAULT_ADMIN_ROLE){
        whiteLists[token] = false;
    }
    function grantRole(address user) public onlyRole(DEFAULT_ADMIN_ROLE){
        _grantRole(DEFAULT_ADMIN_ROLE, user);
    }
    function setFee(uint256 _rateFee) public onlyRole(DEFAULT_ADMIN_ROLE){
        require(_rateFee < 100, "Rate fee is incorrect");
        rateFee = _rateFee;
    }
    function getFee(uint256 price) public view returns (uint256) {
        return price * rateFee / 100;
    }
}