// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "./interfaces/IFactory.sol";
import "./interfaces/IIns20.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IPancakeRouter02.sol";
import "./interfaces/IPancakeFactory.sol";
import "./interfaces/IWETH.sol";
import "./library/SafeMath.sol";

contract Ins20 is IIns20 {
    using SafeMath for uint256;

    event SetRewardPoolInfo(uint256 rewardAmount, uint256 rewardMintCount);
    event SetBurnPct(uint256 pct);
    event SetSplitToken(address token);
    event SetRouter(address router);
    event ClaimSuccessMint(address indexed sender, uint256 recordIndex, bool splitToToken);
    event BatchClaimSuccessMint(address indexed sender, bool splitToToken);
    event ClaimRewardPool(address indexed sender, uint256 bonusAmount, uint256 prizeAmount);
    event Split(address indexed sender, uint256 amount, uint256 tokenAmount);
    event Merge(address indexed sender, uint256 tokenAmount, uint256 amount);

    struct MintInfo {
        bool claimed;
        uint16 mintIndex;
        uint256 blockNum;
        uint256 blockIndex;
    }

    struct BlockInfo {
        uint16 mintCount;
        bytes32 preBlockHash;
    }

    struct BonusInfo {
        uint256 shares;
        uint256 pending;
        uint256 rewardPaid;
    }

    uint256 public maxSupply;
    uint256 public amountPerMint;
    uint256 public fee;
    uint256 public totalMinted;
    address public factory;
    uint256 public holderAmount;
    uint256 public txAmount;
    uint256 public deployTime;
    address public deployer;
    address public splitToken;
    string public tick;
    address public router;
    mapping(uint256 => BlockInfo) public blockNumberToBlockInfo;
    uint256 public mintBlockCount;
    MintInfo[] public mintInfo;
    mapping(address => uint256[]) public userMintInfo;
    mapping(address => BonusInfo) public userBonusInfo;
    mapping(uint256 => address) public blockAndIndexToUser;
    mapping(uint256 => uint256) public mintCountToBlockNumber;

    // erc20 standard
    mapping(address => uint256) private _balances;
    uint256 private _totalSupply;
    uint256 public rewardAmountOfPool;
    uint256 public rewardMintCountOfPool;
    uint256 public startRewardMintCountOfPool;
    uint256 public burnPct;
    uint256 public accPerShare;
    uint256 public sharesTotal;

    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;

    constructor(
        uint256 _maxSupply,
        uint256 _amountPerMint,
        uint256 _fee,
        address _factory,
        address _deployer,
        string memory _tick
    ) {
        maxSupply = _maxSupply;
        amountPerMint = _amountPerMint;
        fee = _fee;
        factory = _factory;
        deployer = _deployer;
        tick = _tick;

        totalMinted = 0;
        deployTime = block.timestamp;
        burnPct = 50;
    }

    function setSplitToken(address _splitToken) external {
        require(msg.sender == deployer, "not deployer");
        require(_splitToken != address(0), "invalid split token");
        splitToken = _splitToken;
        uint256 tokenAmount = maxSupply * (10 ** IERC20(splitToken).decimals());
        IERC20(splitToken).transferFrom(msg.sender, address(this), tokenAmount);
        emit SetSplitToken(_splitToken);
    }

    function setRouter(address _router) external {
        require(msg.sender == deployer, "not deployer");
        require(_router != address(0), "invalid split token");
        require(splitToken != address(0), "split token is zero address");
        address weth = IPancakeRouter02(_router).WETH();
        address tokenFactory = IPancakeRouter02(_router).factory();
        require(IPancakeFactory(tokenFactory).getPair(splitToken, weth) != address(0), "no pair");
        router = _router;
        IERC20(weth).approve(_router, type(uint256).max);
        emit SetRouter(_router);
    }

    function setRewardPoolInfo(uint256 _rewardAmount, uint256 _rewardMintCount) external {
        require(msg.sender == deployer, "not deployer");
        require(splitToken != address(0));
        rewardAmountOfPool = _rewardAmount;
        rewardMintCountOfPool = _rewardMintCount;
        startRewardMintCountOfPool = maxSupply / amountPerMint - rewardMintCountOfPool + 1;
        IERC20(splitToken).transferFrom(msg.sender, address(this), _rewardAmount);
        emit SetRewardPoolInfo(_rewardAmount, _rewardMintCount);
    }

    function setBurnPct(uint256 _pct) external {
        require(msg.sender == deployer, "not deployer");
        require(_pct <= 100);
        burnPct = _pct;
        emit SetBurnPct(_pct);
    }

    function mint(address to, uint256 amount) public payable override returns(bool){
        require(msg.sender == factory, "only factory can mint");
        uint256 mintAmount = amount;
        require(mintAmount == amountPerMint, "invalid amount");
        if (fee > 0) {
            require(msg.value == fee, "invalid value");
            require(mintAmount * mintBlockCount <= maxSupply, "max supply exceeded");
            _recordMintInfo(to, block.number);
            return false;
        }
        require(totalMinted + mintAmount <= maxSupply, "max supply exceeded");
        totalMinted += mintAmount;
        _mint(to, mintAmount);
        return true;
    }

    function testMint(address to, uint256 blockNumber) public payable {
        require(msg.sender == deployer, "not deployer");
        require(fee > 0, "Invalid fee");
        require(msg.value == fee, "invalid value");
        uint256 mintAmount = amountPerMint;
        require(mintAmount * mintBlockCount <= maxSupply, "max supply exceeded");
        _recordMintInfo(to, blockNumber);
    }

    function split(uint256 amount) public {
        require(splitToken != address(0), "not support split");
        require(msg.sender == tx.origin, "not EOA");
        require(amount > 0, "invalid amount");
        require(balanceOf(msg.sender) >= amount, "split amount exceeds balance");
        unchecked {
            _balances[msg.sender] -= amount;
        }
        _totalSupply -= amount;
        if(balanceOf(msg.sender) == 0) holderAmount--;
        txAmount++;

        uint256 tokenAmount = amount * (10 ** IERC20(splitToken).decimals());
        require(IERC20(splitToken).balanceOf(address(this)) >= tokenAmount);
        IERC20(splitToken).transfer(msg.sender, tokenAmount);
        _swap(50 * fee);
        emit Split(msg.sender, amount, tokenAmount);
    }

    function merge(uint256 tokenAmount) public {
        require(splitToken != address(0), "not support merge");
        require(msg.sender == tx.origin, "not EOA");
        require(tokenAmount > 0, "invalid amount");
        require(IERC20(splitToken).balanceOf(msg.sender) >= tokenAmount, "merge amount exceeds balance");
        IERC20(splitToken).transferFrom(msg.sender, address(this), tokenAmount);

        uint256 amount = tokenAmount / (10 ** IERC20(splitToken).decimals());
        _mint(msg.sender, amount);
        emit Merge(msg.sender, tokenAmount, amount);
    }

    function swap(uint256 maxBalance) external {
        require(msg.sender == deployer, "not deployer");
        _swap(maxBalance);
    }
    
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        return true;
    }
    
    function decimals() public pure returns (uint8) {
        return 0;
    }

    function name() external view returns(string memory) {
        return tick;
    }

    function totalSupply() public override view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public override view returns(uint256) {
        return _balances[account];
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "transfer from the zero address");
        require(recipient != address(0), "transfer to the zero address");
        require(IFactory(factory).isOperator(msg.sender), "!operator");
        require(amount > 0, "transfer 0");

        if(balanceOf(recipient) == 0) holderAmount++;

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "transfer amount exceeds balance");
        
        unchecked {
            _balances[sender] = senderBalance - amount;
            _balances[recipient] += amount;
        }
        if(balanceOf(sender) == 0) holderAmount--;
        txAmount++;
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "mint to the zero address");

        if(balanceOf(account) == 0) holderAmount++;

        _totalSupply += amount;
        unchecked {
            _balances[account] += amount;
        }
        txAmount++;
    }

    function _swap(uint256 maxBalance) internal {
        if (maxBalance == 0 || router == address(0)) {
            return;
        }

        uint256 balance = address(this).balance;
        if (balance == 0) {
            return;
        }

        if (balance > maxBalance) {
            balance = maxBalance;
        }

        address weth = IPancakeRouter02(router).WETH(); 
        IWETH(weth).deposit{value: balance}();

        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = splitToken;
        uint256 beforeOutAmount = IERC20(splitToken).balanceOf(address(this));
        IPancakeRouter02(router)
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                balance,
                0,
                path,
                address(this),
                block.timestamp + 60
            );
        uint256 afterOutAmount = IERC20(splitToken).balanceOf(address(this));
        uint256 outAmount = afterOutAmount - beforeOutAmount;
        uint256 burnAmount = outAmount * burnPct / 100;
        if (burnAmount > 0)
            IERC20(splitToken).transfer(DEAD, burnAmount);

        _distribute(outAmount - burnAmount);
    }

    function _recordMintInfo(address _to, uint256 _blockNumber) internal {
        BlockInfo memory blockInfo = blockNumberToBlockInfo[_blockNumber];
        if (blockInfo.mintCount == 0) {
            mintBlockCount++;
            blockInfo.preBlockHash = blockhash(_blockNumber - 1);
            mintCountToBlockNumber[mintBlockCount] = _blockNumber;
        }
        blockInfo.mintCount++;
        blockNumberToBlockInfo[_blockNumber] = blockInfo;

        MintInfo memory mInfo;
        mInfo.claimed = false;
        mInfo.blockNum = _blockNumber;
        mInfo.mintIndex = blockInfo.mintCount;
        mInfo.blockIndex = mintBlockCount;
        mintInfo.push(mInfo);
        userMintInfo[_to].push(mintInfo.length);

        BonusInfo memory bonus = userBonusInfo[_to];
        uint256 pending = bonus.shares.mul(accPerShare).div(1e12).sub(bonus.rewardPaid);
        bonus.pending = bonus.pending.add(pending);
        bonus.shares = bonus.shares.add(fee);
        bonus.rewardPaid = bonus.shares.mul(accPerShare).div(1e12);
        userBonusInfo[_to] = bonus;
        sharesTotal = sharesTotal.add(fee);

        if (startRewardMintCountOfPool > 0 && mintBlockCount >= startRewardMintCountOfPool) {
            blockAndIndexToUser[getIndexOf(mInfo.blockIndex, mInfo.mintIndex)] = _to;
        }
    }

    function _distribute(uint256 _rewardAmount) internal {
        if (_rewardAmount == 0) {
            return;
        }

        if (sharesTotal == 0) {
            return;
        }
        accPerShare = accPerShare.add(_rewardAmount.mul(1e12).div(sharesTotal));
    }

    function claimSuccessMint(uint256 recordIndex, bool splitToToken) public {
        require(msg.sender == tx.origin, "not EOA");
        if (splitToToken) {
            require(splitToken != address(0), "not support split");
        }
        _claimSuccessMint(msg.sender, recordIndex, splitToToken);
        if (splitToToken) {
            uint256 tokenAmount = amountPerMint * (10 ** IERC20(splitToken).decimals());
            require(IERC20(splitToken).balanceOf(address(this)) >= tokenAmount);
            IERC20(splitToken).transfer(msg.sender, tokenAmount);
        }
        _swap(50 * fee);
        emit ClaimSuccessMint(msg.sender, recordIndex, splitToToken);
    }

    function batchClaimSuccessMint(uint256[] memory recordsIndex, bool splitToToken) public {
        require(msg.sender == tx.origin, "not EOA");
        if (splitToToken) {
            require(splitToken != address(0), "not support split");
        }

        for (uint256 i = 0; i < recordsIndex.length; ++i) {
            _claimSuccessMint(msg.sender, recordsIndex[i], splitToToken);
        }

        if (splitToToken) {
            uint256 tokenAmount = recordsIndex.length * amountPerMint * (10 ** IERC20(splitToken).decimals());
            require(IERC20(splitToken).balanceOf(address(this)) >= tokenAmount);
            IERC20(splitToken).transfer(msg.sender, tokenAmount);
        }
        _swap(50 * fee);
        emit BatchClaimSuccessMint(msg.sender, splitToToken);
    }

    function _claimSuccessMint(address addr, uint256 recordIndex, bool splitToToken) internal{
        MintInfo memory info = mintInfo[userMintInfo[addr][recordIndex]-1];
        require(info.blockNum > 0, "invalid record");
        require(info.claimed == false, "already claim");
        require(info.mintIndex == getMintSuccessIndex(info.blockNum), "not success index");
        info.claimed = true;
        mintInfo[userMintInfo[addr][recordIndex]-1] = info;
        uint256 mintAmount = amountPerMint;
        require(totalMinted + mintAmount <= maxSupply, "max supply exceeded");
        totalMinted += mintAmount;
        if (!splitToToken) {
            _mint(addr, mintAmount);
        }
    }

    function totalMintInfo() public view returns(
        uint256 maxSupply_,
        uint256 amountPerMint_,
        uint256 fee_,
        uint256 totalMinted_,
        uint256 mintBlockAmount_,
        uint256 mintTxAmount_
    ) {
        maxSupply_ = maxSupply;
        amountPerMint_ = amountPerMint;
        fee_ = fee;
        totalMinted_ = totalMinted;
        mintBlockAmount_ = mintBlockCount;
        mintTxAmount_ = mintInfo.length;
    }

    function getUserMintLength(address user) public view returns(uint256) {
        return userMintInfo[user].length;
    }

    struct UserMintRecords {
        bool claimed;
        uint16 mintIndex;
        uint16 successMintIndex;
        uint256 blockNum;
        uint256 blockIndex;
    }

    function getUserMintRecords(address addr,uint256 page, uint256 pageSize) public view returns (UserMintRecords[] memory records) {
        require(page > 0, "!pNumber");
        require(pageSize > 0, "!pSize");
        uint256 start = (page - 1) * pageSize;
        uint256 end = start + pageSize;
        uint256 length = getUserMintLength(addr);
        if (end > length) {
            end = length;
        }
        if (end < start) {
            end = start;
        }

        records = new UserMintRecords[](end - start);
        for (uint256 i = start; i < end; i++) {
            MintInfo memory info = mintInfo[userMintInfo[addr][i]-1];
            records[i - start].claimed = info.claimed;
            records[i - start].mintIndex = info.mintIndex;
            records[i - start].blockNum = info.blockNum;
            records[i - start].blockIndex = info.blockIndex;
            records[i - start].successMintIndex = getMintSuccessIndex(info.blockNum);
        }
    }

    function getMintSuccessIndex(uint256 blockNumber) public view returns(uint16 index) {
        BlockInfo memory blockInfo = blockNumberToBlockInfo[blockNumber];
        if (blockInfo.mintCount == 0) {
            return 0;
        }

        bytes32 bHash = keccak256(abi.encodePacked(
            blockInfo.preBlockHash,
            blockInfo.mintCount
        ));
        uint8 firstNumber = uint8(bHash[0]) / 16;
        uint256 r = uint256(bHash) % 2;
        index = 0;
        if (r == 0) {
            if (firstNumber >= blockInfo.mintCount) {
                index = blockInfo.mintCount;
            } else {
                index = firstNumber + 1;
            }
        } else {
            if (firstNumber >= blockInfo.mintCount) {
                index = 1;
            } else {
                index = blockInfo.mintCount - firstNumber;
            }
        }
    }

    function getIndexOf(uint256 blockIndex, uint256 mintIndex) public pure returns(uint256) {
        return blockIndex * 100000 + mintIndex;
    }

    function getRewardPoolInfoOf(address _user) public view returns(uint256 bonusAmount, uint256 prizeAmount) {
        BonusInfo memory bonus = userBonusInfo[_user];
        uint256 pending = bonus.shares.mul(accPerShare).div(1e12).sub(bonus.rewardPaid);
        bonusAmount = bonus.pending.add(pending);
        if (bonus.shares > 0 && startRewardMintCountOfPool > 0 && mintBlockCount >= startRewardMintCountOfPool) {
            uint256 perPrizeAmount = rewardAmountOfPool / rewardMintCountOfPool;
            for (uint256 i = startRewardMintCountOfPool; i <= mintBlockCount; ++i) {
                uint256 blockNumber = mintCountToBlockNumber[i];
                uint256 successIndex = getMintSuccessIndex(blockNumber);
                address winner = blockAndIndexToUser[getIndexOf(i, successIndex)];
                if (winner == _user) {
                    prizeAmount += perPrizeAmount;
                }
            }
        }
    }

    function claimRewardPool() external {
        require(msg.sender == tx.origin, "not EOA");
        require(mintBlockCount * amountPerMint >= maxSupply, "mint not finished");
        _swap(address(this).balance);
        (uint256 bonusAmount, uint256 prizeAmount) = getRewardPoolInfoOf(msg.sender);
        uint256 rewardAmount = bonusAmount + prizeAmount;
        require(rewardAmount > 0, "reward amount == 0");
        delete userBonusInfo[msg.sender];

        require(IERC20(splitToken).balanceOf(address(this)) >= rewardAmount);
        IERC20(splitToken).transfer(msg.sender, rewardAmount);
        emit ClaimRewardPool(msg.sender, bonusAmount, prizeAmount);
    }

    receive() external payable {}
}