const crypto = require('crypto');

const MID = "100000000429484";
const ORDER_ID = "RB1778148802824";
const AMOUNT = "1.00";
const AGG_ID = "100000000429483";
const CUST_ID = "i2groa2oL2czJI469ZQN";
const MOBILE = "8489044570";
const EMAIL = "sharan2252001@gmail.com";
const KEY = "68daac24-ee72-4563-b213-742a9113d7af";
const TARGET_HASH = "2638a476ae06727c65a15c29ac86eb5687d5c17e74aff017b627acd29892d856";

const keys = [KEY, KEY.toUpperCase(), KEY.replace(/-/g, ""), KEY.replace(/-/g, "").toUpperCase()];
const base_fields = [MID, ORDER_ID, AMOUNT, AGG_ID, CUST_ID, MOBILE, EMAIL];

function permute(permutation) {
  var length = permutation.length,
      result = [permutation.slice()],
      c = new Array(length).fill(0),
      i = 1, k, p;

  while (i < length) {
    if (c[i] < i) {
      k = i % 2 && c[i];
      p = permutation[i];
      permutation[i] = permutation[k];
      permutation[k] = p;
      ++c[i];
      i = 1;
      result.push(permutation.slice());
    } else {
      c[i] = 0;
      ++i;
    }
  }
  return result;
}

const allOrders = permute(base_fields);
console.log("Testing HMAC-SHA256 and regular SHA256...");

for (let key_val of keys) {
    for (let order of allOrders) {
        const raw = order.join("|");
        
        // 1. Regular SHA256
        let hash = crypto.createHash('sha256').update(raw + "|" + key_val).digest('hex').toLowerCase();
        if (hash === TARGET_HASH) {
            console.log("\n✅ MATCH FOUND (Regular SHA256)!");
            console.log("Sequence:", order.join("|"));
            process.exit(0);
        }

        // 2. HMAC-SHA256
        hash = crypto.createHmac('sha256', key_val).update(raw).digest('hex').toLowerCase();
        if (hash === TARGET_HASH) {
            console.log("\n✅ MATCH FOUND (HMAC-SHA256)!");
            console.log("Sequence:", order.join("|"));
            process.exit(0);
        }
    }
}
console.log("No match found.");
