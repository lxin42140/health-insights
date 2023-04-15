// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./ERC20.sol";
import "./Marketplace.sol";
import "./Patient.sol";
import "./Organization.sol";

contract MedToken {
    /** PROPERTIES */
    ERC20 erc20Contract;
    address owner = msg.sender;
    address marketplaceInstance;

    // address patientInstance;
    // address orgInstance;

    constructor() {
        ERC20 e = new ERC20();
        erc20Contract = e;
    }

    modifier ownerOnly() {
        require(msg.sender == owner, "Only only!");

        _;
    }

    modifier marketplaceOnly() {
        require(msg.sender == marketplaceInstance, "marketplace only!");

        _;
    }

    // function setOrganization(address org) public ownerOnly {
    //     orgInstance = org;
    // }

    // function setPatient(address patient) public ownerOnly {
    //     patientInstance = patient;
    // }

    function setMarketplace(address market) public ownerOnly {
        marketplaceInstance = market;
    }

    /**
        User cannot get credit directly from med token. Credit related operations can only be performed through marketplace
    */

    // TESTED
    function getCredit(
        address recipient,
        uint256 weiAmt
    ) public marketplaceOnly returns (uint256) {
        uint256 amt = weiAmt / (1000000000000000000 / 100); // Convert weiAmt to MT
        erc20Contract.mint(recipient, amt);
        return amt;
    }

    // TESTED
    function checkCredit(
        address ad
    ) public view marketplaceOnly returns (uint256) {
        uint256 credit = erc20Contract.balanceOf(ad);
        return credit;
    }

    // TESTED
    function burnCredit(address source, uint256 amt) public marketplaceOnly {
        erc20Contract.burn(source, amt);
    }

    // TESTED
    function transferCredit(
        address recipient,
        uint256 amt
    ) public marketplaceOnly {
        // Transfers from tx.origin to receipient
        erc20Contract.transfer(recipient, amt);
    }
}
