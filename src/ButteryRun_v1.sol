// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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

    // modifier onlyOwner() {
    //     if (msg.sender != deployer) revert OnlyOwnerAllowed(); // Reverts if the caller is not an owner
    //     _;
    // }

    constructor() {
        deployer = msg.sender;
    }

    function _setUpdating(UpdateState state) internal {
        currentState = state;
    }
}
