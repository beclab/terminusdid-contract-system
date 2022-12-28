
#rm -rf .openzeppelin artifacts cache
mkdir -p deployments

if [ ! -f "deployments/deployments.json" ]; then
    echo "{}" > deployments/deployments.json
fi

#npx hardhat run scripts/deploy/01_min_forwarder.js --network goerli
#npx hardhat run scripts/deploy/02_id_deploy.js --network goerli
#npx hardhat run scripts/deploy/03_name_deploy.js --network goerli
#npx hardhat run scripts/deploy/04_bundle_deploy.js --network goerli
npx hardhat run scripts/deploy/05_bundle_register.js  --network goerli
