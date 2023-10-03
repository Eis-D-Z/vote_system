import { TransactionBlock } from "@mysten/sui.js/transactions";
import {
  Ed25519Keypair,
  Ed25519KeypairData,
} from "@mysten/sui.js/keypairs/ed25519";
import { getVoter, getClient } from "./utils";
import * as dotenv from "dotenv";
import { SuiClient } from "@mysten/sui.js/dist/cjs/client";
dotenv.config();

const pkg = process.env.PACKAGE_ID as string;
const adminCap = process.env.ADMIN_CAP as string;

const sharedObjects = { registry: "", groups: "" };
const toElect = 1; // out of 50
const all = 10;
const keypairs: Ed25519Keypair[] = [];

const getCitizens = () => {
  let { address, keypair: _ } = getVoter();
  let result: string[] = [];
  let initial: number[] = [];
  let i = 0;
  while (i < 32) {
    initial.push(i);
    i++;
  }
  i = 0;
  while (i < all - 1) {
    if (i % 2 == 0) {
      initial[0]++;
    } else {
      initial[1]++;
    }
    let keypair = Ed25519Keypair.fromSecretKey(Uint8Array.from(initial));
    keypairs.push(keypair);
    result.push(keypair.toSuiAddress());
    i++;
  }
  result.push(address);

  return result;
};

const shuffleArray = () => {
  const array: number[] = [];
  let k = 0;
  while (k < all / 10) {
    array.push(k);
    k++;
  }

  //   for (let i = array.length - 1; i > 0; i--) {
  //     let j = Math.floor(Math.random() * (i + 1));
  //     let temp = array[i];
  //     array[i] = array[j];
  //     array[j] = temp;
  //   }

  return array;
};

const newCampaign = async () => {
  const { address, keypair, client } = getClient();

  const tx = new TransactionBlock();

  tx.moveCall({
    target: `${pkg}::vote::new`,
    arguments: [tx.object(adminCap), tx.pure(toElect)],
  });

  const response = await client.signAndExecuteTransactionBlock({
    transactionBlock: tx,
    options: {
      showEffects: true,
      showObjectChanges: true,
    },
    requestType: "WaitForLocalExecution",
    signer: keypair,
  });

  const changes: any = response.objectChanges;
  if (Array.isArray(changes) && changes.length >= 4) {
    changes.forEach((item) => {
      if (item.objectType.includes("VotingGroups"))
        sharedObjects.groups = item.objectId;
      if (item.objectType.includes("VotingRegistry"))
        sharedObjects.registry = item.objectId;
    });
  }

  console.log("Started new campaing!");
  console.log(
    `Registry address is ${sharedObjects.registry} and groups address is ${sharedObjects.groups}`
  );
};

const populateShared = async () => {
  const { address, keypair, client } = getClient();
  const tx = new TransactionBlock();

  tx.moveCall({
    target: `${pkg}::vote::populate_registry`,
    arguments: [
      tx.object(adminCap),
      tx.object(sharedObjects.registry),
      tx.pure(getCitizens(), "vector<address>"),
    ],
  });

  tx.moveCall({
    target: `${pkg}::vote::populate_voting_groups`,
    arguments: [
      tx.object(adminCap),
      tx.object(sharedObjects.registry),
      tx.object(sharedObjects.groups),
    ],
  });

  //   const random_array = shuffleArray();
  //   console.log(random_array.length);
  //   tx.moveCall({
  //     target: `${pkg}::vote::voting_start`,
  //     arguments: [
  //       tx.object(adminCap),
  //       tx.object(sharedObjects.registry),
  //       tx.object(sharedObjects.groups),
  //       tx.pure(random_array, "vector<u64>"),
  //       tx.pure(toElect),
  //     ],
  //   });

  const response = await client.signAndExecuteTransactionBlock({
    transactionBlock: tx,
    options: {
      showEffects: true,
    },
    requestType: "WaitForLocalExecution",
    signer: keypair,
  });
};

const voting_start = async () => {
  const { address, keypair, client } = getClient();
  const tx = new TransactionBlock();
  const random_array = shuffleArray();
  console.log(random_array);
  tx.moveCall({
    target: `${pkg}::vote::voting_start`,
    arguments: [
      tx.object(adminCap),
      tx.object(sharedObjects.registry),
      tx.object(sharedObjects.groups),
      tx.pure(random_array, "vector<u64>"),
      tx.pure(toElect),
    ],
  });
  const response = await client.signAndExecuteTransactionBlock({
    transactionBlock: tx,
    options: {
      showEffects: true,
    },
    requestType: "WaitForLocalExecution",
    signer: keypair,
  });
};

const singleVote = async (ourVoter: string, kp: Ed25519Keypair, sponsor: string, sponsorKeypair: Ed25519Keypair, client: SuiClient) => {
  const tx = new TransactionBlock();
  const resp = await client.getOwnedObjects({
    owner: kp.toSuiAddress(),
    options: {
      showType: true,
    },
  });
  const [votingPassObj] = resp.data.filter((item) => {
    return item.data?.type === `${pkg}::vote::VotingPass`;
  });
  const votingPassId = votingPassObj.data?.objectId!;
  console.log(votingPassId);

  tx.moveCall({
    target: `${pkg}::vote::vote`,
    arguments: [
      tx.object(sharedObjects.groups),
      tx.object(votingPassId),
      tx.pure(ourVoter),
    ],
  });
  tx.setSender(kp.toSuiAddress());
  tx.setGasOwner(sponsor);
  const txBytes = await tx.build({client});
  const {signature: sponsorSig, bytes: _txb1} = await sponsorKeypair.signTransactionBlock(txBytes);
  const {signature: ownerSig, bytes: _txb2} = await kp.signTransactionBlock(txBytes);
  await client.executeTransactionBlock({
    transactionBlock: txBytes,
    requestType: "WaitForEffectsCert",
    signature: [ownerSig, sponsorSig]
  });
};

const voting = async () => {
  let { address, keypair, client } = getClient();
  let { address: ourVoter, keypair: voterKeypair } = getVoter();
  for (let kp of keypairs) {
    await singleVote(ourVoter, kp, address, keypair, client);
  }
  // ourVoter vote
  await singleVote(keypairs[0].toSuiAddress(), voterKeypair, address, keypair, client);
};

const end = async () => {
    let {address, keypair, client} = getClient();
    const tx = new TransactionBlock();

    tx.moveCall({
        target: `${pkg}::vote::vote_end`,
        arguments: [tx.object(sharedObjects.registry), tx.object(sharedObjects.groups)]
    });

    const response = await client.signAndExecuteTransactionBlock({
        transactionBlock: tx,
        requestType: "WaitForLocalExecution",
        options: {
            showEffects: true
        },
        signer: keypair
    });
    console.log(JSON.stringify(response));
}

const main = async () => {
  await newCampaign();
  await populateShared();
  await voting_start();
  await voting();
  end();
};
main();

