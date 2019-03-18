### Instructions

1. Bump version if needed with this command: 

```
bumpversion --config-file ./.bumpversion_contracts.cfg 0.4.0 --new-version 0.3.0
```

2. To deploy the contracts, use this command:
```
python -m raiden_contracts.deploy raiden --rpc-provider https://ropsten.infura.io/v3/b41cfdbe6a9d47109dc10d8d2b087142 --private-key privatekey --gas-price 100 --gas-limit 6000000
```
