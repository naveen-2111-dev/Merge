import { ethers } from "ethers"
import metadata from "./metadata.js"
import Networkconfig from "./config.js";
import fs from "fs";
import path from "path";
import dotenv from "dotenv";
import { fileURLToPath } from "url";

dotenv.config();
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function main() {
    console.log("🚀 Deploying to Sonic...")

    const abi = metadata.abi;
    const bytecode = metadata.bytecode;

    const provider = new ethers.JsonRpcProvider(Networkconfig.networks.sonic.url);
    const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider)

    const factory = new ethers.ContractFactory(abi, bytecode, wallet);
    const contract = await factory.deploy();

    await contract.waitForDeployment();
    const deployedAddress = await contract.getAddress();

    console.log(`contract deployed to ${deployedAddress}`)

    const updatedConfig = `
    const Network = {
        networks: {
            sonic: {
                url: "${Networkconfig.networks.sonic.url}",
                chainId: ${Networkconfig.networks.sonic.chainId},
                address: "${deployedAddress}"
            },
        },
    };
    
    export default Network;
    `;

    const filePath = path.resolve(__dirname, "config.js");
    fs.writeFileSync(filePath, updatedConfig.trim() + "\n");
}

main().then(err => console.log(err))