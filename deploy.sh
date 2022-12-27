
rm -rf .openzeppelin artifacts cache
mkdir -p deployments

if [ ! -f "deployments/deployments.json" ]; then
    echo "{}" > deployments/deployments.json
fi

npx hardhat run scripts/deploy/01_id_deploy.js --network bsc_testnet
# npx hardhat run scripts/deploy/02_name_deploy.js --network bsc_testnet
# npx hardhat run scripts/deploy/03_bundle_deploy.js --network bsc_testnet
