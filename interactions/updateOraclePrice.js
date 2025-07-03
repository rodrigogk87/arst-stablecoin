import dotenv from "dotenv";
import { ethers } from "ethers";
import axios from "axios";

dotenv.config();

const oracleAbi = [
  "function updatePrice(uint256 newPrice) external",
];

async function fetchPrice() {
  try {
    const bluelyticsUrl = "https://api.bluelytics.com.ar/v2/latest";
    const binanceUrl = "https://api.binance.com/api/v3/ticker/price?symbol=USDTARS";

    console.log("🌐 Fetching Bluelytics price...");
    const bluelyticsResp = await axios.get(bluelyticsUrl);

    console.log("🌐 Fetching Binance price...");
    const binanceResp = await axios.get(binanceUrl);

    let prices = [];

    // Bluelytics
    if (bluelyticsResp.data && bluelyticsResp.data.blue && bluelyticsResp.data.blue.value_avg > 0) {
      const bluePrice = bluelyticsResp.data.blue.value_avg;
      console.log(`✅ Bluelytics blue avg: ${bluePrice}`);
      prices.push(bluePrice);
    }

    // Binance
    if (binanceResp.data && parseFloat(binanceResp.data.price) > 0) {
      const binancePrice = parseFloat(binanceResp.data.price);
      console.log(`✅ Binance price: ${binancePrice}`);
      prices.push(binancePrice);
    }

    if (prices.length === 0) {
      throw new Error("❌ No valid prices from APIs");
    }

    // Mean
    const meanPrice = prices.reduce((sum, p) => sum + p, 0) / prices.length;
    console.log(`📊 Mean ARS price: ${meanPrice}`);

    // Invert to USD/ARS
    const usdPerArs = 1 / meanPrice;
    console.log(`💵 USD per ARS: ${usdPerArs}`);

    // Scale
    const scaled = Math.round(usdPerArs * 1e8);
    console.log(`⚖️ Scaled value: ${scaled}`);

    return scaled;
  } catch (error) {
    console.error("❌ Error fetching or processing prices:", error);
    throw error;
  }
}

async function updateOracle(newPrice) {
  const { PRIVATE_KEY, ARB_SEPOLIA_RPC_URL, ARB_SEPOLIA_ORACLE_ADDRESS } = process.env;

  if (!PRIVATE_KEY || !ARB_SEPOLIA_RPC_URL || !ARB_SEPOLIA_ORACLE_ADDRESS) {
    throw new Error("🚫 Missing PRIVATE_KEY, ARB_SEPOLIA_RPC_URL, or ARB_SEPOLIA_ORACLE_ADDRESS in .env");
  }

  const provider = new ethers.JsonRpcProvider(ARB_SEPOLIA_RPC_URL);
  const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
  const oracle = new ethers.Contract(ARB_SEPOLIA_ORACLE_ADDRESS, oracleAbi, wallet);

  console.log("🚀 Sending transaction to update oracle price...");
  const tx = await oracle.updatePrice(newPrice);

  console.log(`📡 Tx sent: ${tx.hash}`);
  const receipt = await tx.wait();
  console.log(`✅ Transaction confirmed in block ${receipt.blockNumber}`);
}

async function main() {
  const scaledPrice = await fetchPrice();
  await updateOracle(scaledPrice);
}

main().catch((err) => {
  console.error("❌ Unhandled error:", err);
  process.exit(1);
});
