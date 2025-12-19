// SPDX-License-Identifier: MIT

pragma solidity >=0.8.13 <0.9.0;

import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {StdCheatsSafe} from "forge-std/StdCheats.sol";
import {console2} from "forge-std/console2.sol";
// import {StringUtils} from "foundry-devops/src/StringUtils.sol";

library StringUtils {
    function isEqualTo(
        string memory str1,
        string memory str2
    ) internal pure returns (bool) {
        return
            keccak256(abi.encodePacked(str1)) ==
            keccak256(abi.encodePacked(str2));
    }

    function contains(
        string memory str,
        string memory substr
    ) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory substrBytes = bytes(substr);
        if (strBytes.length < substrBytes.length || strBytes.length == 0) {
            return false;
        }

        for (uint256 i = 0; i <= strBytes.length - substrBytes.length; i++) {
            bool isEqual = true;
            for (uint256 j = 0; j < substrBytes.length; j++) {
                if (strBytes[i + j] != substrBytes[j]) {
                    isEqual = false;
                    break;
                }
            }
            if (isEqual) return true;
        }
        return false;
    }
}

library ProxyDevOps {
    using stdJson for string;
    using StringUtils for string;

    Vm public constant vm =
        Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    string public constant RELATIVE_BROADCAST_PATH = "./broadcast";
    function get_most_recent_deployment(
        string memory contractName,
        uint256 chainId
    ) internal view returns (address) {
        return
            get_most_recent_deployment(
                contractName,
                chainId,
                RELATIVE_BROADCAST_PATH
            );
    }

    function get_most_recent_deployment(
        string memory contractName,
        uint256 chainId,
        string memory relativeBroadcastPath
    ) internal view returns (address) {
        address latestAddress = address(0);
        uint256 lastTimestamp;

        bool runProcessed;
        Vm.DirEntry[] memory entries = vm.readDir(relativeBroadcastPath, 3);
        for (uint256 i = 0; i < entries.length; i++) {
            string memory normalizedPath = normalizePath(entries[i].path);
            if (
                normalizedPath.contains(
                    string.concat("/", vm.toString(chainId), "/")
                ) &&
                normalizedPath.contains(".json") &&
                !normalizedPath.contains("dry-run")
            ) {
                string memory json = vm.readFile(normalizedPath);
                latestAddress = processRun(json, contractName, latestAddress);
            }
        }
        for (uint256 i = 0; i < entries.length; i++) {
            Vm.DirEntry memory entry = entries[i];
            if (
                entry.path.contains(
                    string.concat("/", vm.toString(chainId), "/")
                ) &&
                entry.path.contains(".json") &&
                !entry.path.contains("dry-run")
            ) {
                runProcessed = true;
                string memory json = vm.readFile(entry.path);

                uint256 timestamp = vm.parseJsonUint(json, ".timestamp");

                if (timestamp > lastTimestamp) {
                    latestAddress = processRun(
                        json,
                        contractName,
                        latestAddress
                    );

                    // If we have found some deployed contract, update the timestamp
                    // Otherwise, the earliest deployment may have been before `lastTimestamp` and we should not update
                    if (latestAddress != address(0)) {
                        lastTimestamp = timestamp;
                    }
                }
            }
        }

        if (!runProcessed) {
            revert("No deployment artifacts were found for specified chain");
        }

        if (latestAddress != address(0)) {
            return latestAddress;
        } else {
            revert(
                string.concat(
                    "No contract named ",
                    "'",
                    contractName,
                    "'",
                    " has been deployed on chain ",
                    vm.toString(chainId)
                )
            );
        }
    }

    function get_most_recent_proxy_deployment(
        string memory contractName,
        string memory proxy,
        uint256 chainId
    ) internal view returns (address) {
        return
            get_most_recent_proxy_deployment(
                contractName,
                proxy,
                chainId,
                RELATIVE_BROADCAST_PATH
            );
    }

    function get_most_recent_proxy_deployment(
        string memory contractName,
        string memory proxy,
        uint256 chainId,
        string memory relativeBroadcastPath
    ) internal view returns (address) {
        address latestAddress = address(0);
        uint256 lastTimestamp;

        bool runProcessed;
        Vm.DirEntry[] memory entries = vm.readDir(relativeBroadcastPath, 3);
        // console2.log("entries", entries.length);
        for (uint256 i = 0; i < entries.length; i++) {
            string memory normalizedPath = normalizePath(entries[i].path);
            if (
                normalizedPath.contains(
                    string.concat("/", vm.toString(chainId), "/")
                ) &&
                normalizedPath.contains(".json") &&
                !normalizedPath.contains("dry-run")
            ) {
                string memory json = vm.readFile(normalizedPath);
                latestAddress = processProxyRun(
                    json,
                    contractName,
                    latestAddress
                );

                console2.log("latestAddress", address(latestAddress));
            }
        }

        for (uint256 i = 0; i < entries.length; i++) {
            Vm.DirEntry memory entry = entries[i];
            if (
                entry.path.contains(
                    string.concat("/", vm.toString(chainId), "/")
                ) &&
                entry.path.contains(".json") &&
                !entry.path.contains("dry-run")
            ) {
                runProcessed = true;
                string memory json = vm.readFile(entry.path);

                uint256 timestamp = vm.parseJsonUint(json, ".timestamp");

                if (timestamp > lastTimestamp) {
                    latestAddress = processProxyRun(
                        json,
                        contractName,
                        latestAddress
                    );

                    // If we have found some deployed contract, update the timestamp
                    // Otherwise, the earliest deployment may have been before `lastTimestamp` and we should not update
                    if (latestAddress != address(0)) {
                        lastTimestamp = timestamp;
                    }
                }
            }
        }

        if (!runProcessed) {
            revert("No deployment artifacts were found for specified chain");
        }

        if (latestAddress != address(0)) {
            return latestAddress;
        } else {
            revert(
                string.concat(
                    "No contract named ",
                    "'",
                    contractName,
                    "'",
                    " has been deployed on chain ",
                    vm.toString(chainId)
                )
            );
        }
    }

    function processRun(
        string memory json,
        string memory contractName,
        address latestAddress
    ) internal view returns (address) {
        for (
            uint256 i = 0;
            vm.keyExistsJson(
                json,
                string.concat("$.transactions[", vm.toString(i), "]")
            );
            i++
        ) {
            string memory contractNamePath = string.concat(
                "$.transactions[",
                vm.toString(i),
                "].contractName"
            );
            if (vm.keyExistsJson(json, contractNamePath)) {
                string memory deployedContractName = json.readString(
                    contractNamePath
                );
                if (deployedContractName.isEqualTo(contractName)) {
                    latestAddress = json.readAddress(
                        string.concat(
                            "$.transactions[",
                            vm.toString(i),
                            "].contractAddress"
                        )
                    );
                }
            }
        }

        return latestAddress;
    }
    function processProxyRun(
        string memory json,
        string memory contractName,
        address latestAddress
    ) internal view returns (address) {
        for (
            uint256 i = 0;
            vm.keyExistsJson(
                json,
                string.concat("$.transactions[", vm.toString(i), "]")
            );
            i++
        ) {
            string memory contractNamePath = string.concat(
                "$.transactions[",
                vm.toString(i),
                "].contractName"
            );
            if (vm.keyExistsJson(json, contractNamePath)) {
                string memory deployedContractName = json.readString(
                    contractNamePath
                );
                if (deployedContractName.isEqualTo(contractName)) {
                    latestAddress = json.readAddress(
                        string.concat(
                            "$.transactions[",
                            vm.toString(i),
                            "].contractAddress"
                        )
                    );
                }
            }
        }

        return latestAddress;
    }

    function normalizePath(
        string memory path
    ) internal pure returns (string memory) {
        // Replace backslashes with forward slashes
        bytes memory b = bytes(path);
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == bytes1("\\")) {
                b[i] = "/";
            }
        }
        return string(b);
    }
}

library ProxyDevOpsTools {
    using stdJson for string;
    using StringUtils for string;

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
