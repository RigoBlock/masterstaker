/*

 Copyright 2018 RigoBlock, Rigo Investment Sagl.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.

*/

pragma solidity ^0.4.24;

/// @title Master Staker - Allows to for multi-user multi-deposit staking to casper.
/// @author Gabriele Rigo - <gab@rigoblock.com>
    contract MasterStaker {

    event DepositCasper(	
        address indexed vault,	
        address indexed validator,	
        address indexed casper,	
        address withdrawal,	
        uint256 amount	
    );

     event WithdrawCasper(	
        address indexed vault,	
        address indexed validator,	
        address indexed casper,	
        uint256 validatorIndex	
    );

    modifier casperContractOnly {	
        Authority auth = Authority(admin.authority);	
        address casperAddress = DexAuth(auth.getExchangesAuthority())	
            .getCasper();	
        if (msg.sender != casperAddress) return;	
        _;	
    }
    
    modifier isCasper(address _casper) {	
        Authority auth = Authority(AUTHORITY);	
        require(	
            DexAuth(auth.getExchangesAuthority())	
                .getCasper() == _casper);	
        _;	
    }

    /// @dev Allows a casper contract to send Ether back	
    function()	
        external	
        payable	
        casperContractOnly	
    {}
    
    /// @dev Allows to deposit from vault to casper contract for pooled PoS mining	
    /// @dev _withdrawal address must be == this	
    /// @param _validation Address of the casper miner	
    /// @param _withdrawal Address where to withdraw	
    /// @param _amount Value of deposit in wei	
    /// @return Bool the function executed correctly	
    function depositCasper(address _validation, address _withdrawal, uint256 _amount)	
        external	
        onlyOwner	
        minimumStake(_amount)	
        returns (bool success)	
    {	
        require(_withdrawal == address(this));	
        Authority auth = Authority(admin.authority);	
        address casperAddress = DexAuth(auth.getExchangesAuthority()).getCasper();	
        Casper casper = Casper(casperAddress);	
        data.validatorIndex = casper.nextValidatorIndex();	
        casper.deposit.value(_amount)(_validation, _withdrawal);	
        VaultEventful events = VaultEventful(auth.getVaultEventful());	
        require(events.depositToCasper(msg.sender, this, casperAddress, _validation, _withdrawal, _amount));	
        return true;	
    }	
     /// @dev Allows vault owner to withdraw from casper to vault contract	
    function withdrawCasper()	
        external	
        onlyOwner	
    {	
        Authority auth = Authority(admin.authority);	
        address casperAddress = DexAuth(auth.getExchangesAuthority()).getCasper();	
        Casper casper = Casper(casperAddress);	
        casper.withdraw(data.validatorIndex);	
        VaultEventful events = VaultEventful(auth.getVaultEventful());	
        require(events.withdrawFromCasper(msg.sender, this, casperAddress, data.validatorIndex));	
    }
    
    /// @dev Logs a vault deposit to the casper contract	
    /// @param _who Address of the caller	
    /// @param _targetVault Address of the vault	
    /// @param _casper Address of the casper contract	
    /// @param _validation Address of the PoS miner	
    /// @param _withdrawal Address of casper withdrawal, must be the vault	
    /// @return Bool the transaction executed successfully	
    function depositToCasper(	
        address _who,	
        address _targetVault,	
        address _casper,	
        address _validation,	
        address _withdrawal,	
        uint256 _amount)	
        external	
        approvedVaultOnly(msg.sender)	
        approvedUserOnly(_who)	
        returns(bool success)	
    {	
        emit DepositCasper(_targetVault, _validation, _casper, _withdrawal, _amount);	
        return true;	
    }	
     /// @dev Logs a vault withdrawal from the casper contract	
    /// @param _who Address of the caller	
    /// @param _targetVault Address of the vault	
    /// @param _casper Address of the casper contract	
    /// @param _validatorIndex Number of the validator in the casper contract	
    /// @return Bool the transaction executed successfully	
    function withdrawFromCasper(	
        address _who,	
        address _targetVault,	
        address _casper,	
        uint256 _validatorIndex)	
        external	
        approvedVaultOnly(msg.sender)	
        approvedUserOnly(_who)	
        returns(bool success)	
    {	
        emit WithdrawCasper(_targetVault, _who, _casper, _validatorIndex);	
        return true;	
    }

/// @dev Finds the value of the deposit of this vault at the casper contract	
    /// @return Value of the deposit at casper in wei	
    function getCasperDeposit() external view returns (uint256) {	
        return getCasperDepositInternal();	
    }
    
    /// @dev Queries the addres of the inizialized casper	
    /// @return Address of the casper address	
    function getCasper()	
        internal view	
        returns (address)	
    {	
        Authority auth = Authority(admin.authority);	
        if (casperInitialized()) {	
            address casperAddress = DexAuth(auth.getExchangesAuthority())	
                .getCasper();	
            return casperAddress;	
        }	
    }	
     /// @dev Checkes whether casper has been inizialized by the Authority	
    /// @return Bool the casper contract has been initialized	
    function casperInitialized()	
        internal view	
        returns (bool)	
    {	
        Authority auth = Authority(admin.authority);	
        return DexAuth(auth.getExchangesAuthority()).isCasperInitialized();	
    }	
     /// @dev Finds the value of the deposit of this vault at the casper contract	
    /// @return Value of the deposit at casper in wei	
    function getCasperDepositInternal()	
        internal view	
        returns (uint256)	
    {	
        if (casperInitialized()) {	
            Casper casper = Casper(getCasper());	
            return uint256(casper.deposit_size(data.validatorIndex));	
        } else {	
            return 0;	
        }	
    }
    
    /// @dev Calculates the value of the shares	    /// @dev Calculates the value of the shares
    /// @return Value of the shares in wei	    /// @return Value of the shares in wei
    function getNav()	    function getNav()
        internal view	        internal view
        returns (uint256)	        returns (uint256)
    {	    {
        uint256 casperDeposit = (casperInitialized() ? getCasperDepositInternal() : 0);	        uint256 aum = address(this).balance - msg.value;
        uint256 aum = safeAdd(address(this).balance, casperDeposit) - msg.value;	
        return (data.totalSupply == 0 ? data.price : safeDiv(aum * BASE, data.totalSupply));	        return (data.totalSupply == 0 ? data.price : safeDiv(aum * BASE, data.totalSupply));
    }
