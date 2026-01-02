// SPDX-License-Identifier: MIT

pragma solidity >=0.8.13 <0.9.0;

import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";

library ProxyDevOpsTools {
    using stdJson for string;

    Vm internal constant vm =
        Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    string internal constant RELATIVE_BROADCAST_PATH = "broadcast";

    /*//////////////////////////////////////////////////////////////
                            PUBLIC API
    //////////////////////////////////////////////////////////////*/

    function getMostRecentProxyDeployment(
        string memory implementationName,
        string memory proxyName,
        uint256 chainId
    ) internal view returns (address proxy) {
        Vm.DirEntry[] memory runs = vm.readDir(RELATIVE_BROADCAST_PATH, 3);

        uint256 latestTimestamp;

        for (uint256 i = 0; i < runs.length; i++) {
            if (!_isRunForChain(runs[i].path, chainId)) continue;

            string memory json = vm.readFile(runs[i].path);
            uint256 timestamp = vm.parseJsonUint(json, ".timestamp");

            if (timestamp < latestTimestamp) continue;

            address found = _findProxyInTransactions(
                json,
                implementationName,
                proxyName
            );

            if (found != address(0)) {
                latestTimestamp = timestamp;
                proxy = found;
            }
        }

        require(proxy != address(0), "ProxyDevOpsTools: proxy not found");
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _findProxyInTransactions(
        string memory json,
        string memory implementationName,
        string memory proxyName
    ) private view returns (address) {
        for (uint256 i = 0; ; i++) {
            string memory base = string.concat(
                "$.transactions[",
                vm.toString(i),
                "]"
            );

            if (!vm.keyExistsJson(json, base)) break;

            string memory namePath = string.concat(base, ".contractName");

            if (
                vm.keyExistsJson(json, namePath) &&
                _eq(json.readString(namePath), implementationName)
            ) {
                // look forward for the proxy within the same run
                for (uint256 j = i + 1; ; j++) {
                    string memory proxyBase = string.concat(
                        "$.transactions[",
                        vm.toString(j),
                        "]"
                    );

                    if (!vm.keyExistsJson(json, proxyBase)) break;

                    string memory proxyNamePath = string.concat(
                        proxyBase,
                        ".contractName"
                    );

                    if (
                        vm.keyExistsJson(json, proxyNamePath) &&
                        _eq(json.readString(proxyNamePath), proxyName)
                    ) {
                        return
                            json.readAddress(
                                string.concat(proxyBase, ".contractAddress")
                            );
                    }
                }
            }
        }

        return address(0);
    }

    function _isRunForChain(
        string memory path,
        uint256 chainId
    ) private pure returns (bool) {
        bytes memory pathBytes = bytes(path);
        bytes memory chainBytes = bytes(
            string.concat("/", _uintToString(chainId), "/")
        );

        if (pathBytes.length < chainBytes.length) return false;

        for (uint256 i = 0; i <= pathBytes.length - chainBytes.length; i++) {
            bool matchFound = true;

            for (uint256 j = 0; j < chainBytes.length; j++) {
                if (pathBytes[i + j] != chainBytes[j]) {
                    matchFound = false;
                    break;
                }
            }

            if (matchFound) return true;
        }

        return false;
    }

    function _uintToString(uint256 value) private pure returns (string memory) {
        if (value == 0) return "0";

        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits--;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }

        return string(buffer);
    }

    function _eq(string memory a, string memory b) private pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    function _toString(uint256 value) private pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits--;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
