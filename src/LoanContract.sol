// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

contract LoanContract {

    event RegistrationSuccessful(
        address indexed user, // Address of the user registering
        bool isSuccessful    // Status of the registration (true = successful, false = failed)
    );
    mapping(address => bool) public isRegistered;

    event LoanAppliedSuccessfully(
        uint256 indexed applicationId, // ID of the loan application
        address indexed applicant,     // Address of the applicant
        uint256 amountRequired,        // Amount requested for the loan
        uint256 interestRate,          // Interest rate applied to the loan
        uint256 durationOfContribution,// Contribution duration
        uint256 durationOfDebt        // Debt repayment duration
    );

    event ContributionSuccessful(
        uint256 indexed applicationId, // ID of the loan application
        address indexed contributor,   // Address of the contributor
        uint256 amountContributed    // Amount contributed
        
    );

    event SuccessfulRepayment(
        uint256 indexed applicationId, // ID of the loan application
        address indexed borrower,      // Address of the borrower
        uint256 totalRepaidAmount     // Total amount repaid (principal + interest)
    );
    event UnsuccessfulRepayment(
        uint256 indexed applicationId, // ID of the loan application
        address indexed borrower,      // Address of the borrower
        uint256 totalRepaidAmount     // Total amount repaid (principal + interest)
    );

    uint256 public maxBorrowingLimit = 2 ether;

    struct Borrower {
        address walletAddress;  // Wallet address of the user
        string name;            // Name of the user
        string panNumber;       // PAN number of the user
        string adharNumber;     // Aadhaar number of the user
        string phoneNumber;     // Phone number of the user
        
    }
    
    mapping(address => Borrower) public BorrowerDetails;

    function register(string memory _name, string memory _panNumber, string memory _adharNumber, string memory _phoneNumber) public {
            require(msg.sender != address(0) , "Not a valid address!");
            require(bytes(_name).length > 0, "Name cannot be empty");
            require(bytes(_panNumber).length == 10, "Enter a valid PAN Number.");
            require(bytes(_adharNumber).length == 12, "Enter a valid Adhar Number.");
            require(bytes(_phoneNumber).length == 10, "Enter a valid Phone Number.");
            BorrowerDetails[msg.sender] = Borrower({
            walletAddress: msg.sender,
            panNumber: _panNumber,
            adharNumber: _adharNumber,
            phoneNumber: _phoneNumber,
            name: _name
        });
        isRegistered[msg.sender] = true;
        emit RegistrationSuccessful(msg.sender, true);
    }

    struct Application {
        uint applicationId;
        address walletAddr;
        uint256 creationTime;
        uint256 amountRequired;  // changable
        uint256 interest;        // changable
        uint256 interestPerAmount;
        uint256 totalAmountRaised;  
        uint256 durationOfContribution;   // changable  t1
        uint256 durationOfDebt;           // changable t2

    }
    uint256 applicationNumber = 0;
    mapping (uint256 applicationNumber => Application) public applications;
    mapping(address addr=> uint256 appId) public addressToAppId;
    // or we should store applications in array
    // apply check if he is resistered or not

    modifier isRegisteredOrNot(address _user) {
      require(isRegistered[_user] == true, "You are not registered with us.");
      _;
    }
    
    function applyLoan(uint256 _amountRequired, uint256 _interest, uint256 _interestPerAmount, uint _durationOfContribution, uint _durationOfDebt)  public isRegisteredOrNot(msg.sender) {
        require(_amountRequired <= maxBorrowingLimit, "This amount is above the max limit!");
        require(_interest > 0, "Give some interest.");
        applications[applicationNumber] = Application({
            applicationId: applicationNumber,
            walletAddr: msg.sender,
            creationTime: block.timestamp,
            amountRequired: _amountRequired,
            interest: _interest,
            interestPerAmount: _interestPerAmount,
            totalAmountRaised: 0,
            durationOfContribution: block.timestamp + _durationOfContribution,
            durationOfDebt: block.timestamp + _durationOfContribution +  _durationOfDebt
        });
        applicationNumber++;

        emit  LoanAppliedSuccessfully(
        applicationNumber-1, 
        msg.sender,     // Address of the applicant
         _amountRequired,        // Amount requested for the loan
        _interest,          // Interest rate applied to the loan
        _durationOfContribution,    // Contribution duration
        _durationOfDebt
    );
        
    }

    function seeApplication() view public returns (Application[] memory) {
    // Create a memory array to store all applications
    Application[] memory allApplications = new Application[](applicationNumber);

    // Iterate from 0 to applicationNumber - 1
     for (uint i = 0; i < applicationNumber; i++) {
         allApplications[i] = applications[i]; // Assign each application to the memory array
     }

    return allApplications; // Return the memory array
    }

    struct contribution {
         uint256 applicationId;
         mapping(address contributor => uint256 amountContributed) contributionAmt;
         address[] contributorsAddr;
         uint numberOfPeopleContributed;
    }
    mapping(uint256 applicationId => contribution) public contributions;

    function contribute(uint256 _appId) payable public returns(bool) {
          Application memory application = applications[_appId];
          require(msg.value > 0, "Not enough amount!");
          // check if time is in the contribution duration
          require(block.timestamp < application.durationOfContribution,"The time of contribution has passed!");

          // modify the application amount req
          //then pay the msg.value to the corresponding application address
          application.amountRequired -= msg.value;
          application.totalAmountRaised += msg.value;
          address reciepient = application.walletAddr;

          // add contributor details
          contributions[_appId].contributionAmt[msg.sender] = msg.value;
          (bool success, ) = payable(reciepient).call{value: msg.value}(""); 

          emit ContributionSuccessful( _appId, msg.sender, msg.value);
          return success;
    }

    function modifyApplication(uint _applicationId, uint _newInterest, uint _newInterestPerAmount, uint _addToAmountRequired, uint _newDurationOfContribution, uint _newDurationOfDebt, string memory _stopRaisingFund) public {
         // check that modification is being done in the open window timeframe
         require(addressToAppId[msg.sender] == _applicationId, "You are not the owner of this application.");
         Application storage application = applications[_applicationId];
         require(block.timestamp < application.durationOfContribution, "You can't modify the application now.");
         
         if(_addToAmountRequired > 0) {
           application.amountRequired +=  _addToAmountRequired;

         }
         if(_newInterest != 0) {
            require(_newInterest > application.interest);
            application.interest = _newInterest;
         }
         if(_newInterestPerAmount != 0) {
            require(_newInterestPerAmount < application.interestPerAmount);
            application.interestPerAmount = _newInterestPerAmount;
         }
         if(_newDurationOfContribution > 0) {
            require(block.timestamp < application.creationTime + _newDurationOfContribution, "This time is passed!");
            application.durationOfContribution = application.creationTime + _newDurationOfContribution;
            application.durationOfDebt = application.durationOfContribution +  _newDurationOfDebt;
         }

         if(_newDurationOfDebt > 0) {
            application.durationOfDebt = application.durationOfContribution +  _newDurationOfDebt;
         }

         if (keccak256(abi.encodePacked(_stopRaisingFund)) == keccak256(abi.encodePacked("Yes"))) {
         application.amountRequired = 0;
        }  
        
    } 
    modifier onlyOwner(uint _appId) {
        require(msg.sender == applications[_appId].walletAddr, "You are not the owner of this application!");
        _;
    }
    
    function payback(uint appId) public payable onlyOwner(appId) {
        uint fullAmount = checkAmountToBePaied(appId);
        require(msg.value >= fullAmount, "You need to pay more value!");

        bool success = initiatePaymentToContributors(appId, fullAmount);
        if(success) {
            // emit 
            emit SuccessfulRepayment(appId, msg.sender, fullAmount);
        }else {
            emit UnsuccessfulRepayment(appId, msg.sender, fullAmount);

        }
        
    }

    function initiatePaymentToContributors(uint _appId, uint256 _fullAmount) private returns (bool successful){
                    
        contribution storage tempContribution = contributions[_appId];
        bool flag = true;
        for(uint i = 0; i < (contributions[_appId].contributorsAddr).length; i + 1) {
            // access the amount each contributor have paid
            address addr = tempContribution.contributorsAddr[i];
            uint amt = tempContribution.contributionAmt[addr];
            uint payableAmt = (amt * _fullAmount)/applications[_appId].totalAmountRaised;

            (bool success,) = payable(addr).call{value: payableAmt}(""); 
            if(!success) { // not successful
                flag = false;
            }
        }
        return flag;
    }

    function checkAmountToBePaied(uint256 _appId) public view onlyOwner(_appId) returns(uint256) {
        Application memory tempApp = applications[_appId];
        uint amtRaisedTillNow = tempApp.totalAmountRaised;
        uint interestRate = tempApp.interest;
        uint time = tempApp.durationOfDebt - tempApp.durationOfContribution;
        uint fullAmount = amtRaisedTillNow + (amtRaisedTillNow * interestRate * time) / tempApp.interestPerAmount;
        return fullAmount;
    }

}