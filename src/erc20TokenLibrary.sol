// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library erc20TokenLibrary {
    using SafeERC20 for IERC20;

    struct tokenData {
        IERC20 token;
    }

    function allowance(
        address token,
        address owner,
        address spender
    ) internal view returns(uint256 _allowance){
        IERC20 _token = IERC20(token);
        _allowance = _token.allowance(owner, spender);
        return _allowance;
    }

    function transferTokens(
        address token,
        address to,
        uint256 amount
    ) internal {
        IERC20 _token = IERC20(token);
        _token.safeTransfer(to, amount);
    }

    function approveTokens(
        address token,
        address spender,
        uint256 amount
    ) internal {
        IERC20 _token = IERC20(token);
        _token.forceApprove(spender, amount*10**18);
    }

    function transferFromTokens(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        IERC20 _token = IERC20(token);
        _token.safeTransferFrom(from, to, amount);
    }

    function getBalance(
        address contractAddress,
        address token
    ) internal view returns (uint256) {
        IERC20 _token = IERC20(token);
        return _token.balanceOf(contractAddress);
    }

    function initializeTokenData(
        address token
    ) internal pure returns (tokenData memory) {
        IERC20 _token = IERC20(token);
        return tokenData({token: _token});
    }
}

// library erc20TokenLibrary {
//     using SafeERC20 for IERC20;

//     struct tokenData {
//         IERC20 token;
//     }

//     function increaseAllowance(
//         address token,
//         address spender,
//         uint256 value
//     ) internal {
//         IERC20 _token = IERC20(token);
//         _token.safeIncreaseAllowance( spender, value);
//     }
//     function allowance(
//         address token,
//         address owner,
//         address spender
//     ) internal view returns(uint256 _allowance){
//         IERC20 _token = IERC20(token);
//       _allowance =  _token.allowance(owner, spender);
//       return _allowance;
//     }



//     function transferTokens(
//         address token,
//         address to,
//         uint256 amount
//     ) internal {
//         IERC20 _token = IERC20(token);
//         _token.safeTransfer(to, amount);
//     }

//     function approveTokens(
//         address token,
//         address spender,
//         uint256 amount
//     ) internal {
//         IERC20 _token = IERC20(token);
//         _token.forceApprove(spender, amount);
//     }

//     function transferFromTokens(
//         address token,
//         address from,
//         address to,
//         uint256 amount
//     ) internal {
//         IERC20 _token = IERC20(token);
//         _token.safeTransferFrom(address(from), to, amount);
//     }

//     function getBalance(
//         address contractAddress,
//         address token
//     ) internal view returns (uint256) {
//         IERC20 _token = IERC20(token);
//         return _token.balanceOf(address(contractAddress));
//     }

//     function initializeTokenData(
//         address token
//     ) internal pure returns (tokenData memory) {
//         IERC20 _token = IERC20(token);
//         return tokenData({token: _token});
//     }

//     //  function withdrawTokenBalance(uint256 amount) internal  {
//     //  IERC20 token = IERC20(_token);
//     // uint256 contractBalance = tokenData.balanceOf(address(this));
//     // if (amount == 0 || amount > contractBalance) revert() /*revert InvalidWithdrawalAmount(contractBalance, amount)*/;
//     // tokenData.token.safeTransfer(msg.sender, amount); // Transfer tokens to the owner
//     // // emit TokensWithdrawn(msg.sender, buttertoken, amount);
//     // }
// }
