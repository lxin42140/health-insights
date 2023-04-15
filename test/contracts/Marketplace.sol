// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./Organization.sol";
import "./Patient.sol";
import "./MedToken.sol";
import "./MedicalRecord.sol";

contract Marketplace {
    /** CONSTANTS */
    uint256 constant SECONDS_IN_DAYS = 86400;

    /** STRUCTS */
    struct Listing {
        uint256 id;
        address listingOwner;
        uint256 pricePerDay;
        MedicalRecord.MedicalRecordType[] recordTypes;
        Organization.OrganizationType[] allowOrganizationTypes;
    }

    struct Purchase {
        Listing listing; // listing snapshot
        uint256 accessStartDate;
        uint256 expirationDate;
        uint256 otp;
        address[] medicalRecordPointers;
    }

    /** PROPERTIES */
    Organization public orgInstance;
    Patient public patientInstance;
    MedToken public medTokenInstance;
    address public owner = msg.sender;
    // commission of marketplace e.g. 10 == 10%
    uint256 public marketCommissionRate;
    uint256 public orgCommissionRate;
    // to use as ID, increment only
    uint256 listingId;
    // map id to the listing
    mapping(uint => Listing) listingMap;
    // map buyer address to list of its purchases
    mapping(address => Purchase[]) purchases;

    /** EVENTS */
    event ListingAdded(address seller, uint256 listingId); // event of adding a listing
    event ListingRemoved(uint256 listingId, string description); // event of removing a listing
    event NewPurchase(
        address buyer,
        uint256 listingId,
        uint256 startDate,
        uint256 expiryDate
    );
    event UpdatedPurchase(
        address buyer,
        uint256 listingId,
        uint256 startDate,
        uint256 expiryDate
    );
    // event of purchasing a listing access
    event CreditMinted(address recipient, uint256 amount);
    event CreditReturned(address recipient, uint256 amount);

    constructor(uint256 marketFee, uint256 orgFee) {
        marketCommissionRate = marketFee; // commission rate that marketplace earns when patient successfully sells a listing
        orgCommissionRate = orgFee; // commission rate that organization which added the patient will earn when the patient successfully sells a listing
    }

    /********************MODIFIERS *****/

    modifier ownerOnly() {
        require(msg.sender == owner, "Owner only!");

        _;
    }

    modifier organisationOnly(address organization) {
        require(
            orgInstance.isVerifiedOrganization(organization),
            "Verified organization only!"
        );

        _;
    }

    modifier patientOnly(address patient) {
        require(patientInstance.isPatient(patient), "Patient only!");

        _;
    }

    modifier validListingOnly(uint256 id) {
        require(listingMap[id].id != 0, "Listing does not exists!");

        _;
    }

    /********************PRIVATE *****/

    function isExpired(uint256 date) private view returns (bool) {
        // returns true if input date is earlier than block timestamp

        return date > 0 && block.timestamp > date;
    }

    function generateRandomOTP() private view returns (uint256) {
        // generate a 6 digit OTP which is used to access the DB

        uint256 seed = uint256(
            keccak256(abi.encodePacked(block.timestamp, block.difficulty))
        );
        uint256 random = uint256(keccak256(abi.encodePacked(seed)));
        uint256 otp = random % 1000000;
        return otp;
    }

    function getPurchaseDetails(
        address buyer,
        uint256 id
    ) private view returns (Purchase memory) {
        // common method to get the purchase detail given buyer address and listing id

        Purchase[] memory orgPurchaseHistory = purchases[buyer];
        uint index = 0;
        bool purchaseExists = false;

        // find the purchase
        for (uint i = 0; i < orgPurchaseHistory.length; i++) {
            if (orgPurchaseHistory[i].listing.id == id) {
                index = i;
                purchaseExists = true;
                break;
            }
        }

        // check if org has purchased the listing
        require(purchaseExists, "Did not purchase the listing!");

        Purchase memory purchase = orgPurchaseHistory[index];

        // check if accesss has expired
        require(!isExpired(purchase.expirationDate), "Purchase has expired!");

        // retrieve matching medical record addresses
        address[] memory matchingRecords = patientInstance.getMedicalRecords(
            purchase.listing.listingOwner,
            purchase.listing.recordTypes
        );

        purchase.medicalRecordPointers = matchingRecords;

        return purchase;
    }

    /******************************API****************/

    function setOrganization(address org) public ownerOnly {
        orgInstance = Organization(org);
    }

    function setPatient(address patient) public ownerOnly {
        patientInstance = Patient(patient);
    }

    function setMedToken(address token) public ownerOnly {
        medTokenInstance = MedToken(token);
    }

    //TESTED
    function getMT() public payable {
        require(
            orgInstance.isVerifiedOrganization(msg.sender) ||
                patientInstance.isPatient(msg.sender) ||
                msg.sender == owner,
            "Only patient, owner and organization can perform this action!"
        );

        uint256 amount = medTokenInstance.getCredit(msg.sender, msg.value);

        emit CreditMinted(msg.sender, amount);
    }

    //TESTED
    function checkMT() public view returns (uint256) {
        return medTokenInstance.checkCredit(msg.sender);
    }

    //TESTED
    function returnMT() public {
        // get eth back at conversion rate of 0.009 Eth per MT
        // and burn corresponding amount of MT

        require(
            orgInstance.isVerifiedOrganization(msg.sender) ||
                patientInstance.isPatient(msg.sender) ||
                msg.sender == owner,
            "Only patient, owner and organization can perform this action!"
        );

        uint256 availMT = medTokenInstance.checkCredit(msg.sender);

        require(availMT > 0, "No MT!");

        // transfer 10% fee to marketplace
        medTokenInstance.transferCredit(address(this), availMT / 10);

        // burn remaining 90% credit from user
        medTokenInstance.burnCredit(msg.sender, (availMT / 10) * 9);

        // convert remaining to eth and send back to user
        address payable recipient = payable(address(msg.sender));
        uint256 weiAmount = availMT * (1000000000000000000 / 100);
        recipient.transfer((weiAmount / 10) * 9);

        emit CreditReturned(msg.sender, (availMT / 10) * 9);
    }

    //TESTED
    function addListing(
        uint256 pricePerDay,
        MedicalRecord.MedicalRecordType[] memory recordTypes,
        Organization.OrganizationType[] memory allowOrganizationTypes
    ) public patientOnly(msg.sender) returns (uint256) {
        require(
            recordTypes.length > 0,
            "Provide min 1 type of record that you wish to sell!"
        );

        // check that patient has at least one record of matching recordTypes
        address[] memory records = patientInstance.getMedicalRecords(
            msg.sender,
            recordTypes
        );

        require(
            records.length > 0,
            "No medical records of matching types to sell!"
        );

        // incre id
        listingId++;

        // create new listing and add to map
        Listing memory newListing = Listing(
            listingId, // id
            msg.sender, // listingOwner
            pricePerDay, // pricePerDay per time unit
            recordTypes,
            allowOrganizationTypes
        );

        listingMap[listingId] = newListing;

        emit ListingAdded(msg.sender, listingId);

        return listingId;
    }

    // TESTED
    function getListingDetails(
        uint256 id
    ) public view validListingOnly(id) returns (Listing memory) {
        return listingMap[listingId];
    }

    // TESTED
    function removeListing(uint256 id) public validListingOnly(id) {
        Listing memory listing = listingMap[id];

        // only listing ower can remove listing
        require(
            msg.sender == listing.listingOwner,
            "Only listing owner can perform this action!"
        );

        delete listingMap[id];

        emit ListingRemoved(id, "Remove by owner!");
    }

    // TESTED
    function buyListing(
        uint256 id,
        uint256 daysToPurchase
    )
        public
        organisationOnly(msg.sender)
        validListingOnly(id)
        returns (uint256)
    {
        /**************PURCHASE REQUIREMENT CHECK******/
        require(
            daysToPurchase >= 30,
            "Required to purchase min 30 days of access!"
        );

        Listing memory listing = listingMap[id];

        // only allowed organizations can purchase
        if (listing.allowOrganizationTypes.length > 0) {
            Organization.OrganizationType orgType = orgInstance
                .getOrganizationType(msg.sender);

            bool isAllowed = false;

            for (
                uint256 i = 0;
                i < listing.allowOrganizationTypes.length;
                i++
            ) {
                if (listing.allowOrganizationTypes[i] == orgType) {
                    isAllowed = true;
                    break;
                }
            }

            require(
                isAllowed,
                "Organization type not allowed to purchase this listing!"
            );
        }

        // check if buyer has enough tokens to pay
        // for now, default to charge by per day
        uint256 totalPrice = listing.pricePerDay * daysToPurchase;
        require(
            medTokenInstance.checkCredit(msg.sender) >= totalPrice,
            "Insufficient tokens!"
        );

        /**************PURCHASE RECORD******/

        // find existing purchase associated with the same listing
        Purchase[] memory existingPurchases = purchases[msg.sender];
        uint256 index = 0;
        bool purchaseExists = false;

        for (uint i = 0; i < existingPurchases.length; i++) {
            if (existingPurchases[i].listing.id == id) {
                index = i;
                purchaseExists = true;
                break;
            }
        }

        if (purchaseExists) {
            // if access is not expired, prevent buyer from purchasing again
            require(
                isExpired(existingPurchases[index].expirationDate),
                "Previous purchase has not expired yet!"
            );

            // if listing has expired, update the purchase details
            existingPurchases[index].accessStartDate = block.timestamp;
            existingPurchases[index].expirationDate =
                block.timestamp +
                (daysToPurchase * SECONDS_IN_DAYS);
            existingPurchases[index].otp = generateRandomOTP();

            emit UpdatedPurchase(
                msg.sender,
                id,
                existingPurchases[index].accessStartDate,
                existingPurchases[index].expirationDate
            );
        } else {
            // create new purchase history and add to list
            address[] memory recordAddress;

            Purchase memory newPurchase = Purchase(
                listing, // struct is pass by value
                block.timestamp, // access start date
                block.timestamp + (daysToPurchase * SECONDS_IN_DAYS), // expiry date of access
                generateRandomOTP(), // OTP to access DB
                recordAddress
            );

            // add to purchases
            purchases[msg.sender].push(newPurchase);
            index = purchases[msg.sender].length - 1;

            emit NewPurchase(
                msg.sender,
                id,
                newPurchase.accessStartDate,
                newPurchase.expirationDate
            );
        }

        /**************FUND TRANSFER******/

        // transfer to marketplace
        uint256 marketCommission = (totalPrice / 100) * marketCommissionRate;
        medTokenInstance.transferCredit(address(this), marketCommission);

        // transfer to org that added the patient
        uint256 orgComission = (totalPrice / 100) * orgCommissionRate;
        address issuedBy = patientInstance.getPatientIssuedBy(
            listing.listingOwner
        );
        medTokenInstance.transferCredit(issuedBy, orgComission);

        // transfer to seller
        uint256 sellerEarning = totalPrice - marketCommission - orgComission;
        medTokenInstance.transferCredit(listing.listingOwner, sellerEarning);

        return index;
    }

    // TESTED
    // for the market to get purchase details of all buyers
    // for DB layer
    function marketGetPurchaseDetails(
        address org,
        uint256 purchaseId
    ) public view ownerOnly returns (Purchase memory) {
        return getPurchaseDetails(org, purchaseId);
    }

    // TESTED
    // for individual organisation to get their purchase details
    function buyerGetPurchaseDetails(
        uint256 purchaseId
    ) public view organisationOnly(msg.sender) returns (Purchase memory) {
        return getPurchaseDetails(msg.sender, purchaseId);
    }

    // TESTED
    function hasPurchasedAccessToRecord(
        address buyer,
        address medRecord
    ) public view returns (bool) {
        Purchase[] memory buyerPurchases = purchases[buyer];

        if (buyerPurchases.length == 0) {
            return false;
        }

        bool hasAccess = false;

        for (uint i = 0; i < buyerPurchases.length; i++) {
            Purchase memory purchase = buyerPurchases[i];

            if (isExpired(purchase.expirationDate)) {
                return false;
            }

            // retrieve matching medical record addresses
            address[] memory matchingRecords = patientInstance
                .getMedicalRecords(
                    purchase.listing.listingOwner,
                    purchase.listing.recordTypes
                );

            for (uint j = 0; j < matchingRecords.length; j++) {
                if (matchingRecords[j] == medRecord) {
                    return true;
                }
            }
        }

        return hasAccess;
    }
}
