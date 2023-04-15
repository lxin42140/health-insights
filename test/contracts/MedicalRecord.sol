// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./Marketplace.sol";
import "./Patient.sol";
import "./Organization.sol";

contract MedicalRecord {
    /** CONSTANTS */
    enum MedicalRecordType {
        Prescription,
        Diagnoses,
        Procedure,
        Test,
        TreatmentPlan
    }

    /** STRUCT */
    struct Metadata {
        address patient;
        address issuedBy;
        address record;
        uint dateCreated;
        MedicalRecordType recordType;
        string uri;
    }

    /** PROPERTIES */
    address public patientInstance;
    address public marketplaceInstance;
    uint createdDate = block.timestamp;
    address issuedBy;
    address owner;
    MedicalRecordType medicalRecordType;
    string filePointer; //URI of file

    /** SWITCH */
    bool public contractStopped;
    bool public isValid;

    /** EVENTS */
    event MedicalRecordAdded(address newMedicalRecord); // event when adding new medical record
    event ContractStopped(); // event when contract access stopped by owner
    event ContractResumed(); // event when contract access resumed by owner
    event RecordInvalidated(); // event when organization invalidated the record
    event RecordValidated(); // event when organization re-validated the record

    constructor(
        MedicalRecordType typeOfRecord,
        address issuedByOrg,
        address patient,
        string memory uri,
        address patientContract,
        address market
    ) {
        medicalRecordType = typeOfRecord;
        issuedBy = issuedByOrg;
        owner = patient;
        filePointer = uri;
        patientInstance = patientContract;
        marketplaceInstance = market;

        // by default record is valid
        isValid = true;
        contractStopped = false;
    }

    /********************MODIFIERS *****/
    modifier ownerOnly() {
        require(owner == msg.sender, "Owner only!");

        _;
    }

    modifier issuedByOnly() {
        require(
            issuedBy == msg.sender,
            "Organization that issued the record only!"
        );

        _;
    }

    modifier recordValid() {
        require(isValid, "Record invalid!");

        _;
    }

    modifier recordNotStopped() {
        require(!contractStopped, "Record access stopped!");

        _;
    }

    /********************APIS *****/

    function toggleContractStopped() public ownerOnly {
        // for owner to prevent access to record if the owner realized access has been leaked/abused

        contractStopped = !contractStopped;

        if (contractStopped) {
            emit ContractStopped();
        } else {
            emit ContractResumed();
        }
    }

    function toggleValidity() public issuedByOnly {
        // for organizaion that issued the record to stop access when there is something wrong
        // with the record
        isValid = !isValid;

        if (isValid) {
            emit RecordValidated();
        } else {
            emit RecordInvalidated();
        }
    }

    // TESTED
    function getMetadata()
        public
        view
        recordValid
        recordNotStopped
        returns (Metadata memory)
    {
        require(
            msg.sender == marketplaceInstance ||
                msg.sender == issuedBy ||
                msg.sender == owner ||
                Marketplace(marketplaceInstance).hasPurchasedAccessToRecord(
                    msg.sender,
                    address(this)
                ),
            "No access!"
        );

        Metadata memory data = Metadata(
            owner,
            issuedBy,
            address(this),
            createdDate,
            medicalRecordType,
            filePointer
        );

        return data;
    }

    // TESTED
    function getRecordType()
        public
        view
        recordValid
        recordNotStopped
        returns (MedicalRecordType)
    {
        require(
            msg.sender == marketplaceInstance ||
                msg.sender == issuedBy ||
                msg.sender == owner ||
                Marketplace(marketplaceInstance).hasPurchasedAccessToRecord(
                    msg.sender,
                    address(this)
                ),
            "No access!"
        );

        return medicalRecordType;
    }

    // TESTED
    function getFilePointer()
        public
        view
        recordValid
        recordNotStopped
        returns (string memory)
    {
        require(
            msg.sender == marketplaceInstance ||
                msg.sender == issuedBy ||
                msg.sender == owner ||
                Marketplace(marketplaceInstance).hasPurchasedAccessToRecord(
                    msg.sender,
                    address(this)
                ),
            "No access!"
        );

        return filePointer;
    }
}
