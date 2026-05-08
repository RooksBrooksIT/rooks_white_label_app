const crypto = require('crypto');

const MID = "100000000429484";
const ORDER_ID = "RB1778147008313";
const AMOUNT = "1.00";
const AGG_ID = "100000000429483";
const CUST_ID = "i2groa2oL2czJI469ZQN";
const MOBILE = "8489044570";
const EMAIL = "sharan2252001@gmail.com";
const RAW_KEY = "68daac24-ee72-4563-b213-742a9113d7af";
const TARGET_HASH = "feaa9b5c8f626235db95d755421b4b345fe25f75c9dda0ad18b1b001a2fef6e6";

const RETURN_URL = "https://us-central1-white-label-app-33300.cloudfunctions.net/paymentCallback";
const NOTIFY_URL = RETURN_URL;
const TXN_DATE = "07-05-2026 15:13:30"; 

const keys = [
    RAW_KEY,
    RAW_KEY.toUpperCase(),
    RAW_KEY.replace(/-/g, ""),
    RAW_KEY.replace(/-/g, "").toUpperCase()
];

const amounts = [AMOUNT, "1", "1.0", "100"]; 
const separators = ["|", "", ","];


const payload = {
    merchantId: MID,
    aggregatorID: AGG_ID,
    merchantTxnNo: ORDER_ID,
    amount: AMOUNT,
    currency: "INR",
    txnDate: TXN_DATE,
    returnURL: RETURN_URL,
    notifyURL: NOTIFY_URL,
    merchantName: "ROOKS AND BROOKS TECHNOLOGIES PRIVATE LIMITED",
    paymentMode: "UPI",
    custId: CUST_ID,
    mobileNo: MOBILE,
    emailId: EMAIL
};

console.log("Searching for match (Alphabetical and more)...");

for (let key_val of keys) {
    for (let amt_val of amounts) {
        payload.amount = amt_val;
        
        // 1. Alphabetical Order
        const sortedKeys = Object.keys(payload).sort();
        const sortedVals = sortedKeys.map(k => payload[k]);
        
        for (let sep of separators) {
            // Key at end
            let raw = [...sortedVals, key_val].join(sep);
            let hash = crypto.createHash('sha256').update(raw).digest('hex').toLowerCase();
            if (hash === TARGET_HASH) {
                console.log("\n✅ MATCH FOUND (Alphabetical)!");
                console.log("Raw String:", raw.replace(key_val, "****"));
                process.exit(0);
            }
        }
        
        // 2. Minimal V2 (Mid, Order, Amount, Key)
        for (let sep of separators) {
            let raw = [MID, ORDER_ID, amt_val, key_val].join(sep);
            let hash = crypto.createHash('sha256').update(raw).digest('hex').toLowerCase();
            if (hash === TARGET_HASH) {
                console.log("\n✅ MATCH FOUND (Minimal V2)!");
                console.log("Raw String:", raw.replace(key_val, "****"));
                process.exit(0);
            }
        }

        // 3. Simple sequence with pipe
        let raw = [MID, ORDER_ID, amt_val, AGG_ID, CUST_ID, MOBILE, EMAIL, key_val].join("|");
        let hash = crypto.createHash('sha256').update(raw).digest('hex').toLowerCase();
         if (hash === TARGET_HASH) {
            console.log("\n✅ MATCH FOUND (Simple Pipe)!");
            console.log("Raw String:", raw.replace(key_val, "****"));
            process.exit(0);
        }
    }
}
console.log("Still no match.");
