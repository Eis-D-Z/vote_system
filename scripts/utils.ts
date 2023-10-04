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

const getAddressesInGroup = async (groupNumber: string, groups: string) => {
  const { address, keypair, client } = getClient();

  const resp: any = await client.getObject({
    id: groups,
    options: { showContent: true },
  });
  const groupsId = resp.data?.content?.fields?.groups.fields.id.id;
  const dfs: any = await client.getDynamicFieldObject({
    parentId: groupsId,
    name: { type: "u64", value: groupNumber },
  });
  const membersId =
    dfs.data?.content?.fields?.value?.fields?.members?.fields?.id?.id;
  const members:any = await client.getDynamicFields({ parentId: membersId });
  const voters: string[] = [];
  members.data.forEach((item: any) => {
    voters.push(item?.name?.value);
  });
  return voters;
};

getAddressesInGroup(
  "0",
  "0x8d7d5651051fe20555ec20a5d3898d7976b101e1dd648c0d2cd86c8ccf9afe50"
);
export { getClient, getVoter };
