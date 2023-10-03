import { Ed25519Keypair } from "@mysten/sui.js/keypairs/ed25519";
import { fromB64 } from "@mysten/sui.js/utils";
import { SuiClient } from "@mysten/sui.js/client";
import * as dotenv from "dotenv";
dotenv.config();

const getClient = () => {
  const b64PrivateKey = process.env.ADMIN_PRIVATE_KEY as string;
  const privkey: number[] = Array.from(fromB64(b64PrivateKey));
  privkey.shift();
  const privateKey = Uint8Array.from(privkey);
  const keypair = Ed25519Keypair.fromSecretKey(privateKey);

  const address = `${keypair.getPublicKey().toSuiAddress()}`;
  const client = new SuiClient({
    url: "https://fullnode.testnet.sui.io:443",
  });

  return { address, keypair, client };
};

const getVoter = () => {
  const b64PrivateKey = process.env.VOTER_PRIVATE_KEY as string;
  const privkey: number[] = Array.from(fromB64(b64PrivateKey));
  privkey.shift();
  const privateKey = Uint8Array.from(privkey);
  const keypair = Ed25519Keypair.fromSecretKey(privateKey);

  const address = `${keypair.getPublicKey().toSuiAddress()}`;

  return { address, keypair };
};
export {getClient, getVoter};