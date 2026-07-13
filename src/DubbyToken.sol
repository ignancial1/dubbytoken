// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DubbyToken is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public immutable taxWallet;
    address public owner;

    uint256 public launchBlock;
    bool public launched;
    uint256 public constant TRANSFER_TAX_PERCENT = 5;

    mapping(address => uint256) public ethBalance;
    mapping(address => bool) public isBlacklisted;
    mapping(address => bool) public isTaxExempt;

    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event TaxSent(address indexed taxWallet, uint256 amount);
    event Blacklisted(address indexed user);
    event Unblacklisted(address indexed user);
    event TaxTaken(address indexed from, uint256 taxAmount);
    event TaxExemptSet(address indexed account, bool isExempt);
    event RecoveredETH(uint256 amount);
    event RecoveredToken(address indexed token, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not contract owner");
        _;
    }

    modifier notBlacklisted(address user) {
        require(!isBlacklisted[user], "Blacklisted address");
        _;
    }

    modifier protectSniper() {
        if (launched) {
            require(block.number > launchBlock + 5, "Sniper protection active");
        }
        _;
    }

    constructor(address _taxWallet) ERC20("DubbyToken", "DUB") {
        require(_taxWallet != address(0), "Invalid tax wallet address");
        taxWallet = _taxWallet;
        owner = msg.sender;

        _mint(msg.sender, 1_000_000 * 10 ** decimals());
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Cannot be zero address");
        require(isContract(newOwner), "New owner must be a contract");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    function blacklist(address user) external onlyOwner {
        isBlacklisted[user] = true;
        emit Blacklisted(user);
    }

    function unblacklist(address user) external onlyOwner {
        isBlacklisted[user] = false;
        emit Unblacklisted(user);
    }

    function setTaxExempt(address account, bool exempt) external onlyOwner {
        isTaxExempt[account] = exempt;
        emit TaxExemptSet(account, exempt);
    }

    function launchToken() external onlyOwner {
        require(!launched, "Already launched");
        launchBlock = block.number;
        launched = true;
    }

    function deposit() external payable notBlacklisted(msg.sender) nonReentrant {
        require(msg.value > 0, "Must send ETH");

        uint256 tax = (msg.value * TRANSFER_TAX_PERCENT) / 100;
        uint256 amountAfterTax = msg.value - tax;

        (bool sent,) = taxWallet.call{value: tax}("");
        require(sent, "Tax transfer failed");
        emit TaxSent(taxWallet, tax);

        ethBalance[msg.sender] += amountAfterTax;
        emit Deposit(msg.sender, amountAfterTax);
    }

    function withdrawal() external notBlacklisted(msg.sender) nonReentrant {
        uint256 amount = ethBalance[msg.sender];
        require(amount > 0, "Not enough ETH");

        ethBalance[msg.sender] = 0;
        (bool sent,) = msg.sender.call{value: amount}("");
        require(sent, "Withdrawal failed");

        emit Withdrawal(msg.sender, amount);
    }

    function transfer(address to, uint256 amount)
        public
        override
        notBlacklisted(msg.sender)
        notBlacklisted(to)
        protectSniper
        returns (bool)
    {
        uint256 tax = isTaxExempt[msg.sender] ? 0 : (amount * TRANSFER_TAX_PERCENT) / 100;
        uint256 netAmount = amount - tax;

        if (tax > 0) {
            _transfer(msg.sender, taxWallet, tax);
            emit TaxTaken(msg.sender, tax);
        }

        _transfer(msg.sender, to, netAmount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount)
        public
        override
        notBlacklisted(from)
        notBlacklisted(to)
        protectSniper
        returns (bool)
    {
        uint256 tax = isTaxExempt[from] ? 0 : (amount * TRANSFER_TAX_PERCENT) / 100;
        uint256 netAmount = amount - tax;

        _spendAllowance(from, msg.sender, amount);

        if (tax > 0) {
            _transfer(from, taxWallet, tax);
            emit TaxTaken(from, tax);
        }

        _transfer(from, to, netAmount);
        return true;
    }

    function rescueETH() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to recover");
        (bool sent,) = payable(owner).call{value: balance}("");
        require(sent, "ETH recovery failed");
        emit RecoveredETH(balance);
    }

    function rescueTokens(address tokenAddress) external onlyOwner {
        require(tokenAddress != address(this), "Cannot recover this token");
        uint256 balance = IERC20(tokenAddress).balanceOf(address(this));
        require(balance > 0, "No tokens to recover");

        IERC20(tokenAddress).safeTransfer(owner, balance);
        emit RecoveredToken(tokenAddress, balance);
    }
}
