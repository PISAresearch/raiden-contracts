pragma solidity 0.5.4;

import "raiden/Token.sol";
import "raiden/Utils.sol";

contract UserDeposit is Utils {
    string constant public contract_version = "{{contracts_version}}{{version_suffix}}";
    uint constant public withdraw_delay = 100;  // time before withdraw is allowed in blocks

    // Token to be used for the deposit
    Token public token;

    // Trusted contracts (can execute `transfer`)
    address public msc_address;
    address public one_to_n_address;

    // Total amount of tokens that have been deposited. This is monotonous and
    // doing a transfer or withdrawing tokens will not decrease total_deposit!
    mapping(address => uint256) public total_deposit;
    // Current user's balance, ignoring planned withdraws
    mapping(address => uint256) public balances;
    mapping(address => WithdrawPlan) public withdraw_plans;

    /*
     *  Structs
     */
    struct WithdrawPlan {
        uint256 amount;
        uint256 withdraw_block;  // earliest block at which withdraw is allowed
    }

    /*
     *  Events
     */

    event BalanceReduced(address indexed owner, uint newBalance);
    event WithdrawPlanned(address indexed withdrawer, uint plannedBalance);

    /*
     *  Modifiers
     */

    modifier canTransfer() {
        require(msg.sender == msc_address || msg.sender == one_to_n_address);
        _;
    }

    /*
     *  Constructor
     */

    /// @notice Set the default values for the smart contract
    /// @param _token_address The address of the token to use for rewards
    constructor(address _token_address)
        public
    {
        // check token contract
        require(_token_address != address(0x0));
        require(contractExists(_token_address));
        token = Token(_token_address);
        require(token.totalSupply() > 0); // Check if the contract is indeed a token contract
    }

    /// @notice Specify trusted contracts. This has to be done outside of the
    /// constructor to avoid cyclic dependencies.
    /// @param _msc_address Address of the MonitoringService contract
    /// @param _one_to_n_address Address of the OneToN contract
    function init(address _msc_address, address _one_to_n_address)
        external
    {
        // prevent changes of trusted contracts after initialization
        require(msc_address == address(0x0) && one_to_n_address == address(0x0));

        // check monitoring service contract
        require(_msc_address != address(0x0));
        require(contractExists(_msc_address));
        msc_address = _msc_address;

        // check one to n contract
        require(_one_to_n_address != address(0x0));
        require(contractExists(_one_to_n_address));
        one_to_n_address = _one_to_n_address;
    }

    /// @notice Deposit tokens. The amount of transferred tokens will be
    /// `new_total_deposit - total_deposit[beneficiary]`. This makes the
    /// function behavior predictable and idempotent. Can be called several
    /// times and on behalf of other accounts.
    /// @param beneficiary The account benefiting from the deposit
    /// @param new_total_deposit The total sum of tokens that have been
    /// deposited by the user by calling this function.
    function deposit(address beneficiary, uint256 new_total_deposit)
        external
    {
        require(new_total_deposit > total_deposit[beneficiary]);

        // Calculate the actual amount of tokens that will be transferred
        uint256 added_deposit = new_total_deposit - total_deposit[beneficiary];

        balances[beneficiary] += added_deposit;
        total_deposit[beneficiary] += added_deposit;
        require(token.transferFrom(msg.sender, address(this), added_deposit));
    }

    /// @notice Internally transfer deposits between two addresses.
    /// Sender and receiver must be different or the transaction will fail.
    /// @param sender Account from which the amount will be deducted
    /// @param receiver Account to which the amount will be credited
    /// @param amount Amount of tokens to be transferred
    /// @return true if transfer has been done successfully, otherwise false
    function transfer(
        address sender,
        address receiver,
        uint256 amount
    )
        canTransfer()
        external
        returns (bool success)
    {
        require(sender != receiver);
        if (balances[sender] >= amount && amount > 0) {
            balances[sender] -= amount;
            balances[receiver] += amount;
            emit BalanceReduced(sender, balances[sender]);
            return true;
        } else {
            return false;
        }
    }

    /// @notice Announce intention to withdraw tokens.
    /// Sets the planned withdraw amount and resets the withdraw_block.
    /// There is only one planned withdrawal at a time, the old one gets overwritten.
    /// @param amount Maximum amount of tokens to be withdrawn
    function planWithdraw(uint256 amount)
        external
    {
        require(amount > 0);
        require(balances[msg.sender] >= amount);

        withdraw_plans[msg.sender] = WithdrawPlan({
            amount: amount,
            withdraw_block: block.number + withdraw_delay
        });
        emit WithdrawPlanned(msg.sender, balances[msg.sender] - amount);
    }

    /// @notice Execute a planned withdrawal
    /// Will only work after the withdraw_delay has expired.
    /// An amount lower or equal to the planned amount may be withdrawn.
    /// Removes the withdraw plan even if not the full amount has been
    /// withdrawn.
    /// @param amount Amount of tokens to be withdrawn
    function withdraw(uint256 amount)
        external
    {
        WithdrawPlan storage withdraw_plan = withdraw_plans[msg.sender];
        require(amount <= withdraw_plan.amount);
        require(withdraw_plan.withdraw_block <= block.number);
        uint256 withdrawable = min(amount, balances[msg.sender]);
        balances[msg.sender] -= withdrawable;
        require(token.transfer(msg.sender, withdrawable));

        emit BalanceReduced(msg.sender, balances[msg.sender]);
        delete withdraw_plans[msg.sender];
    }

    /// @notice The owner's balance with planned withdrawals deducted
    /// @param owner Address for which the balance should be returned
    /// @return The remaining balance after planned withdrawals
    function effectiveBalance(address owner)
        external
        view
        returns (uint256 remaining_balance)
    {
        WithdrawPlan storage withdraw_plan = withdraw_plans[owner];
        if (withdraw_plan.amount > balances[owner]) {
            return 0;
        }
        return balances[owner] - withdraw_plan.amount;
    }

    function min(uint256 a, uint256 b) pure internal returns (uint256)
    {
        return a > b ? b : a;
    }
}
