// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./Marketplace.sol";
import "./Patient.sol";
import "./MedicalRecord.sol";

contract Organization {
    /** CONSTANTS */
    enum OrganizationType {
        Hospital,
        Research,
        Pharmacy,
        HealthTech
    }

    /** STRUCTS */
    struct Profile {
        uint256 profileId;
        address verifiedBy; // the address of org that verified this organization
        OrganizationType organizationType;
        string location;
        string organizationName;
    }

    /** PROPERTIES */
    address public owner = msg.sender;
    Marketplace public marketplaceInstance;
    Patient public patientInstance;

    mapping(address => Profile) organizationProfileMap;
    uint256 profileId;

    /** EVENTS */
    event OrganizationAdded(address addedBy, address newOrgAddress); // event when new organization is added
    event OrganizationRemoved(address removedBy, address deletedOrgAddress); // event when organization is removed

    constructor() {
        // add default seeder organization
        profileId++;

        organizationProfileMap[msg.sender] = Profile(
            profileId,
            msg.sender,
            OrganizationType.Hospital,
            "Singapore",
            "NUH"
        );
    }

    /********************MODIFIERS *****/
    modifier ownerOnly() {
        require(msg.sender == owner, "Owner only!");

        _;
    }

    modifier verifiedOnly(address user) {
        require(
            organizationProfileMap[user].profileId > 0,
            "Verified organization only!"
        );

        _;
    }

    // modifier marketplaceOnly(address marketplace) {
    //     require(
    //         marketplace == address(marketplaceInstance),
    //         "Marketplace only!"
    //     );

    //     _;
    // }

    /********************APIs *****/

    function setPatient(address patient) public ownerOnly {
        patientInstance = Patient(patient);
    }

    function setMarketplace(address market) public ownerOnly {
        marketplaceInstance = Marketplace(market);
    }

    // TESTED
    function addNewOrganization(
        address newOrg,
        OrganizationType organizationType,
        string memory location,
        string memory organizationName
    ) public verifiedOnly(msg.sender) {
        // check if new org already is verified
        require(
            organizationProfileMap[newOrg].profileId == 0,
            "Organization already added!"
        );

        // incre id
        profileId++;

        // create profile
        Profile memory newProfile = Profile(
            profileId,
            msg.sender, //verified by
            organizationType,
            location,
            organizationName
        );

        organizationProfileMap[newOrg] = newProfile;

        emit OrganizationAdded(msg.sender, newOrg);
    }

    // TESTED
    function getOrganizationType(
        address org
    ) public view verifiedOnly(org) returns (OrganizationType) {
        return organizationProfileMap[org].organizationType;
    }

    // TESTED
    function getOrganizationProfile(
        address org
    ) public view verifiedOnly(org) returns (Profile memory) {
        return organizationProfileMap[org];
    }

    // TESTED
    function removeOrganization(
        address orgAddress
    ) public verifiedOnly(msg.sender) verifiedOnly(orgAddress) {
        require(
            msg.sender == organizationProfileMap[orgAddress].verifiedBy ||
                msg.sender == owner,
            "Org not eligible to remove organization!"
        );

        delete organizationProfileMap[orgAddress];

        emit OrganizationRemoved(msg.sender, orgAddress);
    }

    // TESTED
    function isVerifiedOrganization(
        address userAddress
    ) public view returns (bool) {
        return organizationProfileMap[userAddress].profileId > 0;
    }
}
