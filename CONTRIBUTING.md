# Raiden Smart Contracts Development Guide

## Code Style

### Solidity

For solidity we generally follow the style guide as shown in the [solidity
documentation](http://solidity.readthedocs.io/en/develop/style-guide.html) with
some exceptions:

#### Variable Names

All variable name should be in snake case, just like in python. Function names
on the other hand should be mixedCase. MixedCase is essentially like CamelCase
but with the initial letter being a small letter. This helps us to easily
determine which function calls are smart contract calls in the python code
side.

```js
function iDoSomething(uint awesome_argument) {
    doSomethingElse();
}
```

#### Reentrance Problems

Calls into other contracts might call back into our contract.
This causes problems when storage accesses and an external call interleave.  For example,

```js
   check(storage[address])
   other_contract.method()
   storage[address] = new_value
```

possibly has a bug, where an attacker can set up `other_contract.method()` so that it calls back into this piece of code.
Then, the `check()` still sees an old value.

#### Resources

* [Solidity documentation](https://solidity.readthedocs.io/) usually has an answer somewhere.
    * Also keep an eye of [upcoming changes](https://github.com/ethereum/solidity/projects).
* [Remix](http://remix.ethereum.org/) allows step-execute a transaction.
* [(Not So) Smart Contracts](https://github.com/trailofbits/not-so-smart-contracts) contains examples of common vulnerabilities.
* [Awesome Ethereum Security](https://github.com/trailofbits/awesome-ethereum-security) contains relevant links.

### Python

This repository follows the same guidelines as the Raiden Client, regarding the Python code used in tests and scripts: https://github.com/raiden-network/raiden/blob/master/CONTRIBUTING.md#coding-style.

## Making a Pull-Request

* If you're fixing a bug or adding a feature, add an entry to CHANGELOG.md.
* If you've changed a Solidity source, run `make compile_contracts` and add the resulting `raiden_contracts/data/contracts.json` and `raiden_contracts/data/source` in the PR.
* If you're changing documentation only, add `[skip ci]` in the commit message so Travis does not waste time.
    * But, if you've changed comments in a Solidity source, do not add `[skip ci]` and let Travis check the hash of the source.
* Add type annotations (especially on function arguments).

## Testing

Read our [Test Guide](./raiden_contracts/tests/README.md)

## Adding a New Smart Contract

### Location

Currently, our setup is:
- for core contracts: `./raiden_contracts/contracts`
- for 3rd party services: `./raiden_contracts/contracts/services`
- libraries: `./raiden_contracts/contracts/lib`
- non-production test contracts: `./raiden_contracts/contracts/test`

### Constants

Update [package constants](./raiden_contracts/constants.py) with the new contract's name, events, gas requirements etc.

Note: gas requirements are currently calculated using [./raiden_contracts/tests/test_print_gas.py](./raiden_contracts/tests/test_print_gas.py), so the contract needs to be added here. This is not optimal: https://github.com/raiden-network/raiden-contracts/issues/16

### Tests

- add a new file with the new contract fixture in [./raiden_contracts/tests/fixtures](./raiden_contracts/tests/fixtures), to be used across tests and add that file to [./raiden_contracts/tests/fixtures/__init__.py](./raiden_contracts/tests/fixtures/__init__.py)
- read our Test Guide for how to add new tests for the contract
- make sure it's covered by our [compilation tests](./raiden_contracts/tests/test_contracts_compilation.py)
- add it to the [deployment tests](./raiden_contracts/tests/test_deploy_script.py)

### Compilation

We need to add the new contract to the precompiled data. If the new contract is located in one of the existing directories, then it will automatically be added.
If a new contracts directory is created, then it must be added to the compilation process:
https://github.com/raiden-network/raiden-contracts/blob/810ea24b61221f74939a732e6f20f20184039507/raiden_contracts/contract_manager.py#L250-L267


### Deployment

Make sure the new contract's precompiled data and deployment info is included in [./raiden_contracts/data](./raiden_contracts/data), by adding the contract to the [deployment process](./raiden_contracts/deploy/__main__.py)

- if it is a core contract, add it to [deploy_raiden_contracts](https://github.com/raiden-network/raiden-contracts/blob/810ea24b61221f74939a732e6f20f20184039507/raiden_contracts/deploy/__main__.py#L436) and to [verify_deployed_contracts](https://github.com/raiden-network/raiden-contracts/blob/810ea24b61221f74939a732e6f20f20184039507/raiden_contracts/deploy/__main__.py#L616)
- if it is a service contract, add it to [deploy_service_contracts](https://github.com/raiden-network/raiden-contracts/blob/810ea24b61221f74939a732e6f20f20184039507/raiden_contracts/deploy/__main__.py#L492) and to [verify_deployed_service_contracts](https://github.com/raiden-network/raiden-contracts/blob/810ea24b61221f74939a732e6f20f20184039507/raiden_contracts/deploy/__main__.py#L686)
- add it to the [Etherscan verification script](./raiden_contracts/deploy/etherscan_verify.py)

Check if the deployment info file path still stands: https://github.com/raiden-network/raiden-contracts/blob/810ea24b61221f74939a732e6f20f20184039507/raiden_contracts/contract_manager.py#L270-L274


### Package Release

We need to make sure the contract and related data is part of the release process:
- update [.bumpversion_contracts.cfg](./.bumpversion_contracts.cfg)
- mention the addition in the [CHANGELOG.md](./CHANGELOG.md)
- make sure the deployment and precompiled data for the new contract is contained in the [MANIFEST.in](./MANIFEST.in) referenced files.
