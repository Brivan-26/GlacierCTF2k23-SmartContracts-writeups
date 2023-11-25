pragma solidity ^0.8.20;

import "./TotallyNotCopiedToken.sol";

contract IcyPool
{
    address public exchange;
    IERC20 public icyToken;
    IERC20 public token2;

    modifier onlyExchange
    {
        require(msg.sender == exchange, "Only the exchange can call this function");
        _;
    }

    constructor(address icyToken_, address token2_)
    {
        icyToken = IERC20(icyToken_);
        token2 = IERC20(token2_);
        exchange = msg.sender;
    }
    //----------------------------- External Functionalities -----------------------------------------//

    function swap(address caller, address fromToken, address toToken, uint256 amount) onlyExchange external
    {
        uint256 receivedTokens = _calculateOutput(fromToken, toToken, amount);

        //Check if the pool has enough tokens to swap
        require(IERC20(toToken).balanceOf(address(this)) > receivedTokens, "The pool does not have enough tokens to swap");

        //Let the pool swap the tokens
        IERC20(fromToken).transferFrom(caller, address(this), amount);

        //Transfer the tokens back to the caller
        IERC20(toToken).transfer(caller, receivedTokens);
    }

    function getTokensPerIcyToken(uint256 amount) view external returns (uint256)
    {

        return _calculateOutput(address(icyToken), address(token2), amount);
    }

    //----------------------------- Internal Functionalities -----------------------------------------//

    function _calculateOutput(address _tokenFrom, address _tokenTo, uint256 amount) internal view returns (uint256)
    {
        // audit-info _calculateOutput(icyToken, hackToken, 1_000_000_000)
        uint256 balanceOfTokenFrom = IERC20(_tokenFrom).balanceOf(address(this)); // audit-info 100_000
        uint256 balanceOfTokenTo = IERC20(_tokenTo).balanceOf(address(this)); // audit-info 100_000

        // audit-info 1_000_000_000 * 100_000/100_000 = 1_000_000_000
        uint256 returned_tokens = (amount * balanceOfTokenTo) / balanceOfTokenFrom;

        if (returned_tokens >= balanceOfTokenTo)
        {
            // audit-info returned_tokens = 99_999
            returned_tokens = balanceOfTokenTo - 1;
        }

        return returned_tokens;
    }
}
