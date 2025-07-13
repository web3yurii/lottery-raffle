-include .env

.PHONY: all test deploy

build :; forge build

test :; forge test

install:
	@forge install Cyfrin/foundry-devops
	@forge install OpenZeppelin/openzeppelin-contracts
	@forge install smartcontractkit/chainlink-brownie-contracts@1.1.1
	@forge install transmissions11/solmate@v6
	;

deploy-sepolia :
	@forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(SEPOLIA_RPC_URL) --account metamask --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
