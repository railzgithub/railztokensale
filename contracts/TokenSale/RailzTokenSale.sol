pragma solidity ^0.4.11;

import '../Token/Owned.sol';
import '../Math/SafeMath.sol'; 

/**
 This is interface to transfer Railz tokens , created by Railz token contract
 */
interface RailzToken {
    function transfer(address _to, uint256 _value) public returns (bool);
}


/**
 * This is the main Railz Token Sale contract
 */
contract RailzTokenSale is Owned {
	using SafeMath for uint256;

	mapping (address=> uint256) contributors;
	mapping (address=> uint256) tokensAllocated;
    
	// start and end timestamps when contributions are allowed  (both inclusive)
	uint256 public presalestartTime = 1525161600 ;     //1st may 8:00 am UTC
	uint256 public presaleendTime = 1527811140 ;       //31st may 23:59 pm UTC
	uint256 public publicsalestartTime = 1527840000 ;  //1st june 8:00 am UTC
	uint256 public publicsalesendTime = 1530403140 ;   //30 june 23:59 pm UTC

	//variables for soft cap and hard cap
	uint256 public hardCap = 100000;

	//token caps for each round
	uint256 public presalesCap = 120000000 ;
	uint256 public publicsalesCap = 350000000;

	//token price for each round
	uint256 public presalesTokenPriceInWei =  80000000000000 ; // 0.00008 ether;
	uint256 public publicsalesTokenPriceInWei = 196000000000000 ;// 0.000196 ether;

	// address where all funds collected from token sale are stored , this will ideally be address of MutliSig wallet
	address wallet;

	// amount of raised money in wei
	uint256 public weiRaised=0;

	//amount of tokens sold
	uint256 public numberOfTokensAllocated=0;

	// maximum gas price for contribution transactions - 60 GWEI
	uint256 public maxGasPrice = 60000000000  wei;  

	// The token being sold
	RailzToken public token;

	bool hasPreTokenSalesCapReached = false;
	bool hasTokenSalesCapReached = false;
	bool hasHardCapReached = false;

	// events for funds received and tokens
	event ContributionReceived(address indexed contributor, uint256 value, uint256 numberOfTokens);
	event TokensTransferred(address indexed contributor, uint256 numberOfTokensTransferred);
	event ManualTokensTransferred(address indexed contributor, uint256 numberOfTokensTransferred);

	function RailzTokenSale(RailzToken _addressOfRewardToken, address _wallet) public {        
  		require(presalestartTime >= now); 
  		require(_wallet != address(0));   
        
  		token = RailzToken (_addressOfRewardToken);
  		wallet = _wallet;
		owner = msg.sender;
	}

	// verifies that the gas price is lower than max gas price
	modifier validGasPrice() {
		assert(tx.gasprice <= maxGasPrice);
		_;
	}

	// fallback function  used to buy tokens , this function is called when anyone sends ether to this contract
	function ()  payable public validGasPrice {  
		require(msg.sender != address(0));                      //contributor's address should not be zero00/80
		require(msg.value != 0);                                //amount should be greater then zero            
        require(msg.value>=0.1 ether);                          //minimum contribution is 0.1 eth
		require(isContributionAllowed());                       //Valid time of contribution and cap has not been reached 11
	
		// Add to mapping of contributor
		contributors[msg.sender] = contributors[msg.sender].add(msg.value);
		weiRaised = weiRaised.add(msg.value);
		uint256 numberOfTokens = 0;

		//calculate number of tokens to be given
		if (isPreTokenSaleActive()) {
			numberOfTokens = msg.value/presalesTokenPriceInWei;
            numberOfTokens = numberOfTokens * 10^18;
			require((numberOfTokens + numberOfTokensAllocated) <= presalesCap);			//Check whether remaining tokens are greater than tokens to allocate

			tokensAllocated[msg.sender] = tokensAllocated[msg.sender].add(numberOfTokens);
			numberOfTokensAllocated = numberOfTokensAllocated.add(numberOfTokens);
			
			//forward fund received to Railz multisig Account
		    forwardFunds(); 

			//Notify server that an contribution has been received
			ContributionReceived(msg.sender, msg.value, numberOfTokens);

		} else if (isTokenSaleActive()) {
			numberOfTokens = msg.value/publicsalesTokenPriceInWei;
			require((numberOfTokens + numberOfTokensAllocated) <= (presalesCap + publicsalesCap));	//Check whether remaining tokens are greater than tokens to allocate

			tokensAllocated[msg.sender] = tokensAllocated[msg.sender].add(numberOfTokens);
			numberOfTokensAllocated = numberOfTokensAllocated.add(numberOfTokens);

            //forward fund received to Railz multisig Account
		    forwardFunds();

			//Notify server that an contribution has been received
		    ContributionReceived(msg.sender, msg.value, numberOfTokens);
		}        

		// check if hard cap has been reached or not , if it has reached close the contract
		checkifCapHasReached();
	}

	/**
	* This function is used to check if an contribution is allowed or not
	*/
	function isContributionAllowed() public view returns (bool) {    
		if (isPreTokenSaleActive())
			return  (!hasPreTokenSalesCapReached);
		else if (isTokenSaleActive())
			return (!hasTokenSalesCapReached);
		else
			return (!hasHardCapReached);
	}

	// send ether to the fund collection wallet  , this ideally would be an multisig wallet
	function forwardFunds() internal {
		wallet.transfer(msg.value);
	}

	//Pre Token Sale time
	function isPreTokenSaleActive() internal view returns (bool) {
		return ((now >= presalestartTime) && (now <= presaleendTime));  
	}

	//Token Sale time
	function isTokenSaleActive() internal view returns (bool) {
		return (now >= (publicsalestartTime) && (now <= publicsalesendTime));  
	}

	// Called by owner when preico token cap has been reached
	function preTokenSalesCapReached() internal {
		hasPreTokenSalesCapReached = true;
	}

	// Called by owner when ico token cap has been reached
	function tokenSalesCapReached() internal {
		hasTokenSalesCapReached = true;
	}

	//This function is used to transfer token to contributor after successful audit
	function transferToken(address _contributor) public onlyOwner {
		require(_contributor != 0);
    uint256 numberOfTokens = tokensAllocated[_contributor];
    tokensAllocated[_contributor] = 0;    
		token.transfer(_contributor, numberOfTokens);
		TokensTransferred(_contributor, numberOfTokens);
	}

	//This function is used to transfer token to contributor after successful audit
	function manualTokenTransfer(address _contributor, uint _numberOfTokens) public onlyOwner {
		require(_numberOfTokens > 0);
		require(_contributor != 0);
		token.transfer(_contributor, _numberOfTokens);
		TokensTransferred(_contributor,_numberOfTokens);
	}

	//This function is used refund contribution of a contributor in case soft cap is not reached or audit of an contributor failed
	function refundContribution(address _contributor, uint256 _weiAmount) public onlyOwner returns (bool) {
		require(_contributor != 0);
		if (!_contributor.send(_weiAmount)) {
			return false;
		} else {
			contributors[_contributor] = 0;
			return true;
		}
	}

	// This function check whether ICO is currently active or not
    function checkifCapHasReached() internal {
    	if (isPreTokenSaleActive() && (numberOfTokensAllocated > presalesCap))  
        	hasPreTokenSalesCapReached = true;
     	else if (isTokenSaleActive() && (numberOfTokensAllocated > (presalesCap + publicsalesCap)))     
        	hasTokenSalesCapReached = true;
     	else if (weiRaised > hardCap)
        	hasHardCapReached = true;
    }

  	//This function allows the owner to update the gas price limit public onlyOwner     
    function setGasPrice(uint256 _gasPrice) public onlyOwner {
    	maxGasPrice = _gasPrice;
    }
}