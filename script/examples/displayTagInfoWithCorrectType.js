const { ethers, network } = require("hardhat");
const config = require("../../hardhat.config");
const parse = require("../../tools/DIDTypeParse");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Wallet account:", deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());
    console.log("");

    const terminusDIDProxyAddr = config.addresses[network.name].terminusDIDProxy;
    const terminudDIDPrixy = await ethers.getContractAt("TerminusDID", terminusDIDProxyAddr, deployer);

    const rootDomain = "";
    const targetDomain = "song.net";
    const rsaPubKeyTagName = "rsaPubKey";
    const dnsARecordTagName = "dnsARecord";
    const latestDIDTagName = "latestDID";
    const authAddressesTagName = "authAddresses";
    const studentFileTagName = "studentFile";

    const simpleTypeTags = [rsaPubKeyTagName, dnsARecordTagName, latestDIDTagName, authAddressesTagName, studentFileTagName];

    let abiCoder = new ethers.utils.AbiCoder();

    for (let tagName of simpleTypeTags) {
        console.log(`try to get type info of ${tagName}...`);

        const tagRawType = await terminudDIDPrixy.getTagABIType(rootDomain, tagName);
        console.log(`tag type raw bytes:`);
        console.log(tagRawType);

        const tagType = parse(tagRawType);
        console.log(`tag type:`);
        console.log(tagType);

        const rawData = await terminudDIDPrixy.getTagElem(rootDomain, targetDomain, tagName, []);
        console.log(`tag raw value:`);
        console.log(rawData);

        let data = abiCoder.decode([tagType], rawData);
        data = data[0];
        console.log("tag value:");
        console.log(data);

        // tuple type, to get tuple field name
        if (tagType.includes("tuple")) {
            let [_, fieldNamesHashs] = await terminudDIDPrixy.getTagType(rootDomain, tagName);
            let fieldNames = [];
            for (let hash of fieldNamesHashs) {
                let blockNum = await terminudDIDPrixy.getFieldNamesEventBlock(hash);
                console.log(`field name hash: ${hash}`);
                console.log(`block num: ${blockNum}`);
                const events = await terminudDIDPrixy.queryFilter("OffchainStringArray", Number(blockNum), Number(blockNum));
                for (let event of events) {
                    if (hash == event.args.hash) {
                        fieldNames.push(event.args.value)
                    }
                }
            }
            console.log(`found field names:`);
            console.log(fieldNames);

            const tagTypeWithFieldName = parse(tagRawType, fieldNames);
            console.log(`parse type with field names:`);
            console.log(tagTypeWithFieldName);
            let dataWithFieldNames = abiCoder.decode([tagTypeWithFieldName], rawData);
            dataWithFieldNames = dataWithFieldNames[0];
            console.log("tag value with field names:");
            console.dir(dataWithFieldNames, { depth: null });
        }

        console.log("");
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
