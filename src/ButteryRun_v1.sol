// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
// move this to manager
abstract contract ButteryRun_v1 {
    error protocolUpdateInprogress();
    error OnlyOwnerAllowed();

    enum UpdateState {
        NOTUPDATING,
        UPDATING
    }

    address private deployer;// use ownable
    UpdateState private currentState;

    modifier notUpdating() {//change naming
        if (currentState == UpdateState.UPDATING) revert protocolUpdateInprogress();
        _;
    }

    

    constructor() {
        deployer = msg.sender;
    }

    function _setUpdating(UpdateState state) internal {
        currentState = state;
    }

    function getProtocolState() external view returns(UpdateState){
        return currentState;
    }
}
