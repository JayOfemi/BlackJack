// scripts/deploy.js
async function main () {
  // We get the contracts to deploy
  const BlackJack = await ethers.getContractFactory('BlackJack');
  console.log('Deploying BlackJack...');
  const _blackJack = await BlackJack.deploy();
  await _blackJack.deployed();
  console.log('BlackJack deployed to:', _blackJack.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });