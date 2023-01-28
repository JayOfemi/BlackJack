// scripts/index.js
async function main () {
    console.log("\n/--------------------------------------------------/\n");

    console.log("Running index.js...");
    console.log("Accounts:");
    // Retrieve accounts from the local node
    const accounts = await ethers.provider.listAccounts();
    console.log(accounts);

    console.log("\n/--------------------------------------------------/\n");

    // Set up an ethers contract, representing our deployed contract instance
    const address = '0x5FbDB2315678afecb367f032d93F642f64180aa3';
    const BlackJack = await ethers.getContractFactory('BlackJack');
    const _blackJack = await BlackJack.attach(address);

    console.log("BlackJack at address: " + address + "\n");
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });