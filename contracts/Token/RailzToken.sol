
pragma solidity ^0.4.18;

import './Owned.sol';
import './ERC20.sol';
import '../Math/SafeMath.sol'; 


//This is the Main Railz Token Contract derived from the other two contracts Owned and ERC20
contract RailzToken is Owned, ERC20 {

    using SafeMath for uint256;

    uint256  tokenSupply = 2000000000;  //2 billions
             
    // This notifies clients about the amount burnt , only admin is able to burn the contract
    event Burn(address from, uint256 value); 
    
    /* This is the main Token Constructor 
     * @param _centralAdmin  Address of the admin of the contract
     */
	function RailzToken() 

	ERC20 (tokenSupply,"Railz","RLZ") public
    {
		owner = msg.sender;
	}           

    /* This function is used to mint additional tokens
     * only admin can invoke this function
     * @param _mintedAmount amount of tokens to be minted  
     */
    function mintTokens(uint256 _mintedAmount) public onlyOwner {
        balanceOf[owner] = balanceOf[owner].add(_mintedAmount);
        totalSupply = totalSupply.add(_mintedAmount);
        Transfer(0, owner, _mintedAmount);      
    }    

     /**
    * This function Burns a specific amount of tokens.
    * @param _value The amount of token to be burned.
    */
    function burn(uint256 _value) public onlyOwner {
      require(_value <= balanceOf[msg.sender]);
      // no need to require value <= totalSupply, since that would imply the
      // sender's balance is greater than the totalSupply, which *should* be an assertion failure
      address burner = msg.sender;
      balanceOf[burner] = balanceOf[burner].sub(_value);
      totalSupply = totalSupply.sub(_value);
      Burn(burner, _value);
  }

   /* This function is used to lock a user's token , tokens once locked cannot be transferred
     * only admin can invoke this function
     * @param _target address of the target      
     */
    function lockAccount(address _target) public onlyOwner {
        require(_target != address(0));
        isLockedAccount[_target] = true;       
    }

     /* This function is used to unlock a user's already locked tokens
     * only admin can invoke this function
     * @param _target address of the target      
     */
    function unlockAccount(address _target) public onlyOwner {
        require(_target != address(0));
        isLockedAccount[_target] = false;       
    }
}
