# HealthInsights - Decentralized Health Data Marketplace

Our solution serves as a decentralized marketplace to enable direct peer-to-peer transaction of medical data between third party organizations and owners of said data. With the use of blockchain and smart contracts, various issues in the current health data marketplace can be tackled accordingly to promote a healthy and sustainable marketplace.

# Smart Contract Overview

We have 5 core smart contracts that support the business needs of our solution, namely Marketplace, Organization, Patient, MedicalRecord and Token. In this section, we provide an overview of the functions of each smart contract in our system.

The Marketplace contract serves the role of a conventional data broker:
1. Verified patients can list and unlist their specific medical records for sale. 
2. Verified organizations can act as buyers to purchase listed medical records. 
3. Token related operations, such as transfer of token during purchase, token exchange and token withdrawal.
4. Facilitate purchase process.
5. Track purchase history of each buyer.

The Organization contract is used to support organization related operations, with all users representing an organization stored inside a single Organization contract instance. In summary, the Organization contract supports the following operations:
1. Allowing existing verified organizations to verify and add a new user as a verified Organization.
2. Remove verified organizations if verifiers find new organizations malicious. 
3. Retrieving the profile of verified organizations.
4. Check whether a user is a verified organization or not.

The Patient contract is used to support patient related operations, with all users representing a patient stored inside a single Patient contract instance. In summary, the Patient contract supports the following operations:
1. Allowing verified organizations to add new users as patients.
2. Remove verified patients if the verifier finds new patients malicious.
3. Uploading of new medical records by verified organizations or patients.
4. Check whether a user is a verified patient or not.
5. Manage uploaded medical records, and verified patients have total control and knowledge of who, when and which organizations are accessing which medical record that they upload.

The MedicalRecord contract represents a patient’s medical record, with a single instance representing a specific uploaded medical record. When new medical records are created by verified patients or organizations, the associated patient will be the data owner, and they can choose to list their records for sale on the Marketplace contract. A MedicalRecord contains various metadata such as the type of record (e.g. test result, prescription) as well as the URI to access the file associated with the record. It supports operations such as:
1. Retrieving the metadata of the medical record.
2. For verified organizations to toggle the validity of the smart contract.
3. Emergency stop for data owner to control when to stop access to the metadata of the medical record.

The MedToken contract represents a standard ERC20 token, and is used to transact on the Marketplace. It supports fundamental operations such as:
Minting of token.
1. Transfer of token.
2. Burning of token.
3. Checking of token.
