import { ethers } from "ethers";
import * as dotenv from "dotenv";
dotenv.config();

// --- CONFIG --- //
const RPC_URL = process.env.ARB_SEPOLIA_RPC_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY;

const ENGINE_ADDRESS = "0x733a2e073cf9886a4b4E3A188d037E457C2A5A0a";//arb
// //"0xa7CE4add0035CF2C0ac73468CF3dfc53098D6703";(sepolia)
const COLLATERAL_ADDRESS = "0x2836ae2eA2c013acD38028fD0C77B92cccFa2EE4";//arb
// //"0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9"; (sepolia)

// ABIs (mínimo ABI para ERC20 y tu función)
const ERC20_ABI = [
  "function approve(address, uint256) external returns (bool)"
];

const ENGINE_ABI = [
  "function depositCollateralAndMintArsx(address,uint,uint) external"
];

async function main() {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

  const collateral = new ethers.Contract(COLLATERAL_ADDRESS, ERC20_ABI, wallet);
  const engine = new ethers.Contract(ENGINE_ADDRESS, ENGINE_ABI, wallet);

  // Configura los valores
  const amountCollateral = ethers.parseEther("0.01");  // Ej: 0.01 WETH

  //0.01 WETH × $2,556 = $25.56
  //$25.56 × 1,200 ARS/USD = 30,672 ARS
  //30,672 ARS × 50% = 15,336 ARS ≈ 15,336 ARSX
  const amountArsxToMint = ethers.parseEther("14000");   // Ej: 14000 ARSX

  // ✅ Aprobar primero
  console.log("Aprobando...");
  const approveTx = await collateral.approve(ENGINE_ADDRESS, amountCollateral);
  await approveTx.wait();
  console.log(`✔️ Approved: ${approveTx.hash}`);

  // ✅ Depositar y mintear
  console.log("Llamando depositCollateralAndMintArsx...");
  const tx = await engine.depositCollateralAndMintArsx(
    COLLATERAL_ADDRESS,
    amountCollateral,
    amountArsxToMint,
    { gasLimit: 2_000_000 } // ejemplo
  );
  await tx.wait();
  console.log(`✅ Tx confirmada: ${tx.hash}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
