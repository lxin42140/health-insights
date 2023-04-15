// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./MedicalRecord.sol";
import "./Organization.sol";
import "./MedToken.sol";

contract Patient {
    /** STRUCTS */
    struct Profile {
        uint256 profileId;
        address issuedBy; // organization that add this user as patient
        address patientAddress;
        uint8 age;
        string gender;
        string country;
    }

    /** PROPERTIES */
    address public owner = msg.sender;
    Organization public orgInstance;
    Marketplace public marketplaceInstance;

    uint256 profileId;
    mapping(address => Profile) profileMap;
    mapping(address => address[]) patientRecordMap; // list of medical records associated with each patient
    mapping(address => MedicalRecord.MedicalRecordType) recordTypeMap; // medical record and its type

    /** EVENTS */
    event PatientAdded(address addedBy, address newPatientAddress); // event when new patient is added
    event PatientRemoved(address removedBy, address patientAddress); // event when new patient is removed
    event MedicalRecordAdded(address caller, address medicalRecord); // event when new medical record is added

    /********************MODIFIERS *****/

    modifier ownerOnly() {
        require(msg.sender == owner, "Owner only!");

        _;
    }

    modifier marketplaceOnly(address marketplace) {
        require(
            marketplace == address(marketplaceInstance),
            "Marketplace only!"
        );

        _;
    }

    modifier organisationOnly(address organization) {
        require(
            orgInstance.isVerifiedOrganization(organization),
            "Verified organization only!"
        );

        _;
    }

    modifier newPatientOnly(address patientAddress) {
        require(
            profileMap[patientAddress].profileId == 0,
            "Patient profile already eixsts!"
        );

        _;
    }

    modifier patientOnly(address patient) {
        require(profileMap[patient].profileId >= 0, "Patient only!");

        _;
    }

    /********************APIs *****/

    function setMarketplace(address market) public ownerOnly {
        marketplaceInstance = Marketplace(market);
    }

    function setOrganization(address org) public ownerOnly {
        orgInstance = Organization(org);
    }

    // TESTED
    function addNewPatient(
        address patientAddress,
        uint8 age,
        string memory gender,
        string memory country
    ) public organisationOnly(msg.sender) newPatientOnly(patientAddress) {
        profileId++;

        //new patient object
        Profile memory newProfile = Profile(
            profileId,
            msg.sender,
            patientAddress,
            age,
            gender,
            country
        );

        profileMap[patientAddress] = newProfile;

        emit PatientAdded(msg.sender, patientAddress);
    }

    // TESTED
    function removePatient(
        address patientAddress
    ) public organisationOnly(msg.sender) patientOnly(patientAddress) {
        require(
            msg.sender == profileMap[patientAddress].issuedBy ||
                msg.sender == owner,
            "User cannot remove patient!"
        );

        delete profileMap[patientAddress];

        emit PatientRemoved(msg.sender, patientAddress);
    }

    // TESTED
    function getPatientProfile(
        address patientAddress
    ) public view returns (Profile memory) {
        require(
            msg.sender == address(marketplaceInstance) ||
                msg.sender == profileMap[patientAddress].patientAddress ||
                msg.sender == profileMap[patientAddress].issuedBy,
            "Only patient, issued by organization and marketplace can access!"
        );

        return profileMap[patientAddress];
    }

    //TESTED
    function addNewMedicalRecord(
        address issuedByOrg,
        address patient,
        MedicalRecord.MedicalRecordType typeOfRecord,
        string memory uri
    ) public returns (address) {
        if (orgInstance.isVerifiedOrganization(msg.sender)) {
            // org adding new record
            require(issuedByOrg == msg.sender, "Associated org must be same!");
            require(
                profileMap[patient].profileId > 0,
                "Associated user is not patient!"
            );
        } else if (profileMap[msg.sender].profileId > 0) {
            // patient adding new record
            require(msg.sender == patient, "Associated patient must be same!");
            require(
                orgInstance.isVerifiedOrganization(issuedByOrg),
                "Associated org is not verified!"
            );
        } else {
            revert("Only patient and verified organization can add records!");
        }

        MedicalRecord medRecord = new MedicalRecord(
            typeOfRecord,
            issuedByOrg,
            patient,
            uri,
            address(this),
            address(marketplaceInstance)
        );

        patientRecordMap[patient].push(address(medRecord));
        recordTypeMap[address(medRecord)] = typeOfRecord;

        emit MedicalRecordAdded(msg.sender, address(medRecord));

        return address(medRecord);
    }

    //TESTED
    function getMedicalRecords(
        address patientAddress,
        MedicalRecord.MedicalRecordType[] memory recordTypes
    ) public view patientOnly(patientAddress) returns (address[] memory) {
        require(
            msg.sender == address(marketplaceInstance) ||
                msg.sender == profileMap[patientAddress].patientAddress ||
                msg.sender == profileMap[patientAddress].issuedBy,
            "Only patient, issued by org or marketplace can access!"
        );

        // get patient medical records
        address[] memory patientRecords = patientRecordMap[patientAddress];

        // if no record type, return all
        if (recordTypes.length == 0) {
            return patientRecords;
        } else {
            uint index = 0;
            uint[] memory indices = new uint[](patientRecords.length);

            for (uint i = 0; i < patientRecords.length; i++) {
                for (uint j = 0; j < recordTypes.length; j++) {
                    if (recordTypeMap[patientRecords[i]] == recordTypes[j]) {
                        indices[index] = i;
                        index++;
                        break;
                    }
                }
            }

            address[] memory response = new address[](index);
            for (uint i = 0; i < response.length; i++) {
                response[i] = patientRecords[indices[i]];
            }

            return response;
        }
    }

    // TESTED
    function getPatientIssuedBy(
        address patientAddress
    )
        public
        view
        marketplaceOnly(msg.sender)
        patientOnly(patientAddress)
        returns (address)
    {
        return profileMap[patientAddress].issuedBy;
    }

    function isPatient(address patientAddress) public view returns (bool) {
        return profileMap[patientAddress].profileId > 0;
    }
}
