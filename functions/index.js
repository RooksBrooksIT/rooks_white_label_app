const { onDocumentUpdated, onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const BRAND_BLUE = "#1A237E";
const BRAND_BLUE_LIGHT = "#EBF5FF";

admin.initializeApp();

/**
 * Sends a notification to a specific user based on their role and ID.
 **/

async function sendNotification(tenantId, appId, role, userId, payload) {
    if (!userId) {
        console.error(`[ERROR] Skipping notification: Missing userId for role ${role}`);
        return;
    }

    try {
        const path = `${tenantId}/${appId}/notifications_tokens/${role}/tokens/${userId}`;
        console.log(`[DEBUG] Token lookup for ${role}: ${path}`);

        const tokenDoc = await admin.firestore()
            .collection(tenantId)
            .doc(appId)
            .collection("notifications_tokens")
            .doc(role)
            .collection("tokens")
            .doc(userId)
            .get();

        if (!tokenDoc.exists) {
            console.warn(`[WARN] No token found at path: ${path}`);
            return;
        }

        const data = tokenDoc.data();
        if (!data || !data.token) {
            console.warn(`[WARN] Token field missing in doc for ${userId}`);
            return;
        }

        const registrationToken = data.token;
        console.log(`[DEBUG] Found token for ${userId}: ${registrationToken.substring(0, 10)}...`);

        const message = {
            token: registrationToken,
            notification: payload.notification,
            data: payload.data || {},
            android: {
                priority: "high",
                notification: {
                    channelId: "high_importance_channel",
                    priority: "high",
                    defaultSound: true,
                },
            },
            apns: {
                payload: {
                    aps: {
                        contentAvailable: true,
                        sound: "default",
                    },
                },
            },
        };

        try {
            const response = await admin.messaging().send(message);
            console.log(`[SUCCESS] Notification sent to ${userId} (${role}). Response: ${response}`);
        } catch (fcmError) {
            console.error(`[FCM ERROR] Failed to send to ${userId}:`, fcmError);
        }
    } catch (error) {
        console.error(`[SYSTEM ERROR] sendNotification failed:`, error);
    }
}

// 1. HTTP Test Function: Send notification to any user
// Usage: https://<region>-<project>.cloudfunctions.net/testNotify?tenantId=white-label-app-33300&appId=data&role=engineer&userId=JohnDoe
exports.testNotify = onRequest(async (req, res) => {
    const { tenantId, appId, role, userId } = req.query;
    if (!tenantId || !appId || !role || !userId) {
        return res.status(400).send("Missing query params: tenantId, appId, role, userId");
    }

    const payload = {
        notification: {
            title: "Test Notification",
            body: `This is a test notification from Cloud Functions for ${userId}`,
        },
        data: {
            type: "test",
            sender: "system",
        },
    };

    console.log(`[HTTP TEST] Triggered for ${userId} in ${tenantId}/${appId}`);
    await sendNotification(tenantId, appId, role, userId, payload);
    res.send(`Attempted to send notification to ${userId}. Check functions logs for results.`);
});

// 2. Main Trigger for Assignment
async function handleAssignment(event) {
    const newData = event.data.after ? event.data.after.data() : event.data.data();
    const oldData = event.data.before ? event.data.before.data() : null;
    const { tenantId, appId, bookingId } = event.params;

    if (!newData) return;

    // Trigger if newly assigned or assignment changed
    const isNewAssignment = newData.assignedEmployee && (!oldData || newData.assignedEmployee !== oldData.assignedEmployee);

    if (isNewAssignment) {
        console.log(`[DEBUG] Assignment triggered in ${tenantId}/${appId} for ${bookingId}. Engineer: ${newData.assignedEmployee}`);

        // 1. Notify Engineer
        const engineerPayload = {
            notification: {
                title: "New Assignment",
                body: `You have been assigned a new task: ${bookingId}`,
            },
            data: {
                type: "new_assignment",
                bookingId: bookingId,
            },
        };
        const engineerId = newData.assignedEmployee.trim();
        await sendNotification(tenantId, appId, "engineer", engineerId, engineerPayload);

        // 2. Notify Customer
        if (newData.id) {
            const customerPayload = {
                notification: {
                    title: "Ticket Assigned",
                    body: `Your ticket (${bookingId}) has been assigned to ${newData.assignedEmployee}`,
                },
                data: {
                    type: "ticket_assigned",
                    bookingId: bookingId,
                    engineerName: newData.assignedEmployee,
                },
            };
            await sendNotification(tenantId, appId, "customer", newData.id, customerPayload);

            // Also create an in-app notification document for the banner
            await admin.firestore()
                .collection(tenantId)
                .doc(appId)
                .collection("notifications")
                .add({
                    customerId: newData.id,
                    customerName: newData.customerName || "",
                    bookingId: bookingId,
                    title: "Ticket Assigned",
                    body: `Your ticket (${bookingId}) has been assigned to ${newData.assignedEmployee}`,
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                    seen: false,
                    type: "ticket_assigned"
                });
        }
    }
}

// exports.handleAssignmentCreation = onDocumentWritten("{tenantId}/{appId}/Admin_details/{bookingId}", handleAssignment);
// 3. Notify Admin when a new ticket is raised
exports.handleTicketCreation = onDocumentCreated("{tenantId}/{appId}/Admin_details/{bookingId}", async (event) => {
    const ticketData = event.data.data();
    const { tenantId, appId, bookingId } = event.params;
    console.log(`[DEBUG] New ticket raised in ${tenantId}/${appId}: ${bookingId}`);

    try {
        const adminsSnapshot = await admin.firestore()
            .collection(tenantId)
            .doc(appId)
            .collection("notifications_tokens")
            .doc("admin")
            .collection("tokens")
            .get();

        if (adminsSnapshot.empty) {
            console.log("[DEBUG] No admins found to notify");
            return;
        }

        const payload = {
            notification: {
                title: "New Ticket Raised",
                body: `A new ticket (${bookingId}) has been raised by ${ticketData.customerName || "a customer"}`,
            },
            data: {
                type: "new_ticket",
                bookingId: bookingId || "",
            },
        };

        const promises = adminsSnapshot.docs.map((doc) => {
            const data = doc.data();
            if (!data || !data.token) return Promise.resolve();

            const message = {
                token: data.token,
                notification: payload.notification,
                data: payload.data,
                android: {
                    priority: "high",
                    notification: {
                        channelId: "high_importance_channel",
                        priority: "high",
                        defaultSound: true,
                    },
                },
                apns: {
                    payload: {
                        aps: {
                            contentAvailable: true,
                            sound: "default",
                        },
                    },
                },
            };
            return admin.messaging().send(message).catch(error => {
                console.error(`[FCM ERROR] Failed to notify admin ${doc.id}:`, error);
                return null;
            });
        });

        await Promise.all(promises);
        console.log(`[SUCCESS] Notified ${adminsSnapshot.size} admin devices`);
    } catch (e) {
        console.error("[SYSTEM ERROR] onTicketRaised failed:", e);
    }
});

// 4. Notify Customer when ticket status is updated
exports.handleTicketStatusUpdate = onDocumentUpdated("{tenantId}/{appId}/Admin_details/{bookingId}", async (event) => {
    const newData = event.data.after.data();
    const oldData = event.data.before.data();
    const { tenantId, appId, bookingId } = event.params;

    const statusChanged = (newData.engineerStatus !== oldData.engineerStatus) ||
        (newData.adminStatus !== oldData.adminStatus);

    if (statusChanged) {
        const currentStatus = newData.engineerStatus || newData.adminStatus || "Updated";
        console.log(`[DEBUG] Status update in ${tenantId}/${appId} for ${bookingId}: ${currentStatus}`);

        const payload = {
            notification: {
                title: "Ticket Update",
                body: `Your ticket (${bookingId}) status is now: ${currentStatus}`,
            },
            data: {
                type: "status_update",
                bookingId: bookingId,
                status: currentStatus,
            },
        };
        if (newData.id) {
            await sendNotification(tenantId, appId, "customer", newData.id, payload);

            // Also create an in-app notification document for the banner
            await admin.firestore()
                .collection(tenantId)
                .doc(appId)
                .collection("notifications")
                .add({
                    customerId: newData.id,
                    customerName: newData.customerName || "",
                    bookingId: bookingId,
                    title: "Ticket Update",
                    body: `Your ticket (${bookingId}) status is now: ${currentStatus}`,
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                    seen: false,
                    type: "status_update"
                });
        }
    }
});

// 4. Send Email via Nodemailer when a document is created in the "mail" collection
exports.processMailDocument = onDocumentCreated("mail/{docId}", async (event) => {
    const data = event.data.data();
    if (!data || !data.to) {
        console.error("[EMAIL] Skipping: Missing 'to' field.");
        return;
    }

    const nodemailer = require("nodemailer");

    // ─────────────────────────────────────────────────────────────────────────
    // ACTION REQUIRED: Replace YOUR_GMAIL_APP_PASSWORD with your Gmail App
    // Password. Generate one at:
    //   myaccount.google.com → Security → 2-Step Verification → App Passwords
    // For production, store this in Firebase Secret Manager:
    //   firebase functions:secrets:set GMAIL_APP_PASSWORD
    // ─────────────────────────────────────────────────────────────────────────
    const transporter = nodemailer.createTransport({
        host: "smtp.hostinger.com",
        port: 465,
        secure: true,
        auth: {
            user: "support@rookstechnologies.com",
            pass: "Rooks!123",
        },
    });

    const mailOptions = {
        from: '"Rooks And Brooks" <support@rookstechnologies.com>',
        to: data.to,
        subject: data.message.subject,
        html: data.message.html,
        attachments: (data.message.attachments || []).map((att) => ({
            filename: att.filename,
            content: att.content,
            encoding: "base64",
            contentType: att.contentType, // Added contentType for better attachment handling
        })),
    };

    try {
        console.log(`[EMAIL] Sending to ${data.to} | Subject: "${data.message.subject}"`);
        await transporter.sendMail(mailOptions);
        console.log(`[EMAIL] Successfully sent to ${data.to}`);

        return event.data.ref.update({
            status: { state: "SENT", sentAt: admin.firestore.FieldValue.serverTimestamp() },
        });
    } catch (error) {
        console.error(`[EMAIL ERROR] Failed to send to ${data.to}:`, error.message);
        return event.data.ref.update({
            status: {
                state: "ERROR",
                error: error.message,
                failedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
        });
    }
});

// ─────────────────────────────────────────────────────────────────────────────
// 5. Generate Professional PDF Receipt & Send Email on Payment Success
//    Trigger: {tenantId}/{appId}/payment_transactions/{txnId} → status = SUCCESS
// ─────────────────────────────────────────────────────────────────────────────
exports.processPaymentSuccess = onDocumentWritten(
    "{tenantId}/{appId}/payment_transactions/{txnId}",
    async (event) => {
        const newData = event.data.after ? event.data.after.data() : null;
        const oldData = event.data.before ? event.data.before.data() : null;
        const { tenantId, appId, txnId } = event.params;

        if (!newData || newData.status !== "SUCCESS") return;

        // Only fire when status transitions TO "SUCCESS" (not on subsequent edits)
        const wasAlreadySuccess = oldData && oldData.status === "SUCCESS";
        if (wasAlreadySuccess) return;

        const now = new Date();
        // Invoice number: INV-YYYYMMDD-XXXXXX (last 6 chars of txnId, uppercased)
        const invoiceNo = `INV-${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, "0")}${String(now.getDate()).padStart(2, "0")}-${txnId.slice(-6).toUpperCase()}`;
        const formattedDate = now.toLocaleDateString("en-IN", { day: "2-digit", month: "long", year: "numeric" });
        const formattedTime = now.toLocaleTimeString("en-IN", { hour: "2-digit", minute: "2-digit" });

        console.log(`[RECEIPT] Triggered for txn=${txnId} | invoice=${invoiceNo} | tenant=${tenantId}/${appId}`);

        try {
            // ── 1. Validate required transaction fields ─────────────────────
            const uid = newData.uid;
            if (!uid) {
                console.error(`[ERROR] Missing uid in transaction ${txnId}`);
                return;
            }

            // ── 2. Fetch User from Firestore ────────────────────────────────
            let recipientEmail = null;
            let userName = "Valued Customer";

            // Primary lookup: {tenantId}/data/users/{uid}
            const userDoc = await admin.firestore()
                .collection(tenantId).doc("data")
                .collection("users").doc(uid).get();

            if (userDoc.exists) {
                const ud = userDoc.data();
                recipientEmail = ud.email || null;
                userName = ud.name || ud.displayName || ud.fullName || "Valued Customer";
            }

            // Fallback: Firebase Auth
            if (!recipientEmail) {
                try {
                    const authUser = await admin.auth().getUser(uid);
                    recipientEmail = authUser.email || null;
                    if (!userName || userName === "Valued Customer") {
                        userName = authUser.displayName || "Valued Customer";
                    }
                } catch (authErr) {
                    console.warn(`[WARN] Auth lookup failed for uid ${uid}:`, authErr.message);
                }
            }

            if (!recipientEmail) {
                console.error(`[ERROR] No email found for uid ${uid}. Cannot send receipt.`);
                return;
            }
            console.log(`[RECEIPT] Sending receipt to: ${recipientEmail} (${userName})`);

            // ── 3. Calculate GST (18%) ──────────────────────────────────────
            const totalAmount = parseFloat(newData.amount) || 0;
            const GST_RATE = 0.18;
            const baseAmount = parseFloat((totalAmount / (1 + GST_RATE)).toFixed(2));
            const gstAmount = parseFloat((totalAmount - baseAmount).toFixed(2));
            const planName = newData.planName || "Subscription Plan";
            const billingCycle = newData.isYearly ? "Yearly" : "Monthly";
            const paymentMethod = newData.paymentMethod || "Online";
            const transactionId = newData.merchantTxnNo || newData.paymentId || txnId;

            // ── 4. Calculate Subscription Dates for PDF ───────────────────
            const startD = new Date();
            const endD = new Date();
            if (newData.isYearly) {
                endD.setFullYear(endD.getFullYear() + 1);
            } else if (newData.isSixMonths) {
                endD.setMonth(endD.getMonth() + 6);
            } else {
                endD.setMonth(endD.getMonth() + 1);
            }
            const fmtStart = startD.toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
            const fmtEnd = endD.toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });

            // ── 5. Generate Professional PDF ───────────────────────────────
            const PDFDocument = require("pdfkit");
            const BRAND_COLOR = BRAND_BLUE;
            const LIGHT_BG = "#F9FAFB";
            const TEXT_DARK = "#515861ff";
            const TEXT_MID = "#4B5563";
            const COMPANY_NAME = "Rooks And Brooks";
            const COMPANY_EMAIL = "support@rookstechnologies.com";
            const COMPANY_GSTIN = "GSTIN: 33AAMCR8640J1ZZ";

            const generatePdfBuffer = () => new Promise((resolve, reject) => {
                const doc = new PDFDocument({ margin: 40, size: "A4" });
                const buffers = [];
                doc.on("data", (chunk) => buffers.push(chunk));
                doc.on("end", () => resolve(Buffer.concat(buffers)));
                doc.on("error", reject);

                const W = doc.page.width;
                const L = 40;
                const R = W - 40;
                const mid = W / 2;
                const contentW = R - L;

                // ── Header Section ──────────────────────────────────────────
                // Draw a sleek header bar (Now White as per request)
                doc.save();
                doc.rect(0, 0, W, 130).fill("#FFFFFF");
                doc.restore();

                // Logo positioning
                try {
                    doc.image("assets/logo.png", L, 30, { height: 60 });
                } catch (e) {
                    console.warn("[PDF] Image missing:", e.message);
                }

                // Company Details (Left-ish, below logo)
                doc.font("Helvetica-Bold").fontSize(20).fillColor(BRAND_COLOR)
                    .text(COMPANY_NAME, L + 85, 45);
                doc.font("Helvetica").fontSize(10).fillColor("#4B5563")
                    .text(COMPANY_EMAIL, L + 85, 70)
                    .text(COMPANY_GSTIN, L + 85, 84);

                // Invoice Meta (Right side)
                doc.font("Helvetica-Bold").fontSize(28).fillColor(BRAND_COLOR)
                    .text("INVOICE", L, 35, { width: contentW, align: "right" });
                doc.font("Helvetica").fontSize(10).fillColor("#4B5563")
                    .text(`No: ${invoiceNo}`, L, 70, { width: contentW, align: "right" })
                    .text(`Date: ${formattedDate}`, L, 84, { width: contentW, align: "right" });

                // ── Info Columns (Bill To | Subscription Period) ────────────
                let y = 150;

                // Column 1: Bill To
                doc.font("Helvetica-Bold").fontSize(9).fillColor(TEXT_MID).text("BILL TO", L, y);
                doc.font("Helvetica-Bold").fontSize(12).fillColor(TEXT_DARK).text(userName, L, y + 15);
                doc.font("Helvetica").fontSize(10).fillColor(TEXT_MID).text(recipientEmail, L, y + 32);

                // Column 2: Subscription Info (Starts at mid)
                doc.font("Helvetica-Bold").fontSize(9).fillColor(TEXT_MID).text("SUBSCRIPTION PERIOD", mid, y);
                doc.font("Helvetica-Bold").fontSize(11).fillColor(TEXT_DARK)
                    .text(`${fmtStart} — ${fmtEnd}`, mid, y + 15);
                doc.font("Helvetica").fontSize(9).fillColor(TEXT_MID)
                    .text(`Plan: ${planName} (${billingCycle})`, mid, y + 32);

                // ── Table Structure ─────────────────────────────────────────
                y = 230;
                const col = { desc: L, qty: L + 240, unit: L + 310, total: L + 410 };
                const tableH = 30;

                // Header row
                doc.save();
                doc.rect(L, y, contentW, tableH).fill(BRAND_COLOR);
                doc.restore();
                doc.font("Helvetica-Bold").fontSize(10).fillColor("#FFFFFF");
                doc.text("Description", col.desc + 10, y + 10);
                doc.text("Qty", col.qty, y + 10);
                doc.text("Unit Price", col.unit, y + 10, { width: 90, align: "right" });
                doc.text("Total", col.total, y + 10, { width: 100, align: "right" });

                // Data row
                y += tableH;
                doc.save();
                doc.rect(L, y, contentW, tableH + 10).fill(LIGHT_BG);
                doc.restore();
                doc.font("Helvetica").fontSize(10).fillColor(TEXT_DARK);
                doc.text(planName, col.desc + 10, y + 12, { width: 220 });
                doc.text("1", col.qty, y + 12);
                doc.text(`INR ${baseAmount.toFixed(2)}`, col.unit, y + 12, { width: 90, align: "right" });
                doc.text(`INR ${baseAmount.toFixed(2)}`, col.total, y + 12, { width: 100, align: "right" });

                // ── Breakdown & Total ───────────────────────────────────────
                y += tableH + 40;
                const lineW = 180;
                const lineX = R - lineW;

                const addLine = (label, val, isBold = false) => {
                    doc.font(isBold ? "Helvetica-Bold" : "Helvetica").fontSize(10).fillColor(TEXT_DARK);
                    doc.text(label, lineX, y);
                    doc.text(val, lineX, y, { width: lineW, align: "right" });
                    y += 20;
                };

                addLine("Subtotal:", `INR ${baseAmount.toFixed(2)}`);
                addLine("GST (18%):", `INR ${gstAmount.toFixed(2)}`);

                // Draw total box
                doc.save();
                doc.rect(lineX - 10, y - 5, lineW + 10, 30).fill(BRAND_COLOR);
                doc.restore();
                doc.font("Helvetica-Bold").fontSize(12).fillColor("#FFFFFF");
                doc.text("TOTAL PAID", lineX, y + 5);
                doc.text(`INR ${totalAmount.toFixed(2)}`, lineX, y + 5, { width: lineW, align: "right" });

                // ── Final Details ───────────────────────────────────────────
                y += 60;
                doc.font("Helvetica-Bold").fontSize(9).fillColor(TEXT_DARK).text("PAYMENT INFO", L, y);
                doc.font("Helvetica").fontSize(9).fillColor(TEXT_MID)
                    .text(`Transaction ID: ${transactionId}`, L, y + 15)
                    .text(`Payment Method: ${paymentMethod}`, L, y + 27);

                // Success Badge
                doc.save();
                doc.roundedRect(mid + 50, y + 5, 120, 25, 5).fill(BRAND_BLUE_LIGHT);
                doc.font("Helvetica-Bold").fontSize(9).fillColor(BRAND_BLUE)
                    .text("✔ PAID SUCCESS", mid + 65, y + 12);
                doc.restore();

                // ── Footer ──────────────────────────────────────────────────
                const footerY = doc.page.height - 70;
                doc.fontSize(8).fillColor("#9CA3AF")
                    .text("Thank you for choosing Rooks And Brooks.", L, footerY, { width: contentW, align: "center" })
                    .text("This is a digitally generated invoice and requires no signature.", L, footerY + 12, { width: contentW, align: "center" });

                doc.end();
            });

            const pdfBuffer = await generatePdfBuffer();
            const pdfBase64 = pdfBuffer.toString("base64");

            // ── 5. Build Branded HTML Email ────────────────────────────────
            const htmlEmail = `
<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Payment Receipt</title></head>
<body style="margin:0;padding:0;background-color:#F4F6F9;font-family:Arial,Helvetica,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#F4F6F9;padding:30px 0;">
    <tr><td align="center">
      <table width="600" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,0.08);">

        <!-- Header -->
        <tr>
          <td style="background:#1A237E;padding:32px 40px;">
            <table width="100%" cellpadding="0" cellspacing="0">
              <tr>
                <td><span style="font-size:22px;font-weight:700;color:#ffffff;">${COMPANY_NAME}</span></td>
                <td align="right"><span style="font-size:28px;font-weight:800;color:#ffffff;letter-spacing:2px;">RECEIPT</span></td>
              </tr>
              <tr>
                <td><span style="font-size:12px;color:#BBDEFB;">${COMPANY_EMAIL}</span></td>
                <td align="right"><span style="font-size:11px;color:#BBDEFB;">${invoiceNo}</span></td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- Greeting -->
        <tr>
          <td style="padding:32px 40px 0;">
            <p style="font-size:16px;color:#212121;margin:0 0 8px;">Hello, <strong>${userName}</strong>!</p>
            <p style="font-size:14px;color:#616161;margin:0 0 24px;line-height:1.6;">
              Your subscription payment was <strong style="color:${BRAND_BLUE};">successful</strong>.
              Please find your official invoice attached to this email as a PDF.
            </p>
          </td>
        </tr>

        <!-- Summary Card -->
        <tr>
          <td style="padding:0 40px;">
            <table width="100%" cellpadding="12" cellspacing="0"
              style="background:#F5F5F5;border-radius:8px;font-size:13px;color:#424242;">
              <tr style="border-bottom:1px solid #E0E0E0;">
                <td><strong>Invoice No</strong></td>
                <td align="right">${invoiceNo}</td>
              </tr>
              <tr style="border-bottom:1px solid #E0E0E0;">
                <td><strong>Date</strong></td>
                <td align="right">${formattedDate} at ${formattedTime}</td>
              </tr>
              <tr style="border-bottom:1px solid #E0E0E0;">
                <td><strong>Plan</strong></td>
                <td align="right">${planName} (${billingCycle})</td>
              </tr>
              <tr style="border-bottom:1px solid #E0E0E0;">
                <td><strong>Transaction ID</strong></td>
                <td align="right" style="font-size:11px;word-break:break-all;">${transactionId}</td>
              </tr>
              <tr style="border-bottom:1px solid #E0E0E0;">
                <td><strong>Payment Method</strong></td>
                <td align="right">${paymentMethod}</td>
              </tr>
              <tr style="border-bottom:0.5px solid #E0E0E0;">
                <td><strong>Subtotal (ex-GST)</strong></td>
                <td align="right">₹${baseAmount.toFixed(2)}</td>
              </tr>
              <tr style="border-bottom:0.5px solid #E0E0E0;">
                <td><strong>GST (18%)</strong></td>
                <td align="right">₹${gstAmount.toFixed(2)}</td>
              </tr>
              <tr style="background:#1A237E;border-radius:4px;">
                <td style="color:#fff;font-size:15px;border-radius:4px 0 0 4px;"><strong>Total Paid</strong></td>
                <td align="right" style="color:#fff;font-size:17px;font-weight:700;border-radius:0 4px 4px 0;">
                  ₹${totalAmount.toFixed(2)}
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- Attachment note -->
        <tr>
          <td style="padding:24px 40px 0;">
            <p style="font-size:13px;color:#616161;margin:0;">
              📎 A detailed <strong>PDF invoice</strong> is attached to this email for your records.
            </p>
          </td>
        </tr>

        <!-- CTA -->
        <tr>
          <td style="padding:28px 40px 0;" align="center">
            <span style="display:inline-block;background:#1A237E;color:#fff;font-size:14px;font-weight:600;
              padding:12px 32px;border-radius:6px;text-decoration:none;">
              ✓ &nbsp; Subscription Active
            </span>
          </td>
        </tr>

        <!-- Footer -->
        <tr>
          <td style="padding:32px 40px;border-top:1px solid #E0E0E0;margin-top:28px;">
            <p style="font-size:12px;color:#9E9E9E;text-align:center;margin:0;">
              ${COMPANY_NAME} &nbsp;|&nbsp; ${COMPANY_EMAIL}<br>
              This is an automatically generated email. Please do not reply to this message.<br>
              © ${now.getFullYear()} ${COMPANY_NAME}. All rights reserved.
            </p>
          </td>
        </tr>

      </table>
    </td></tr>
  </table>
</body>
</html>`;

            // ── 6. Write to 'mail' collection → triggers processMailDocument ──
            await admin.firestore().collection("mail").add({
                to: recipientEmail,
                message: {
                    subject: `Payment Confirmed — ${planName} | ${invoiceNo}`,
                    html: htmlEmail,
                    attachments: [{
                        filename: `Invoice_${invoiceNo}.pdf`,
                        content: pdfBase64,
                        encoding: "base64",
                    }],
                },
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                txnId: txnId,
                invoiceNo: invoiceNo,
                uid: uid,
            });

            console.log(`[RECEIPT] ✅ Email queued for ${recipientEmail} | invoice=${invoiceNo}`);

            // ── 7. Update transaction doc with invoice details ──────────────
            await event.data.after.ref.update({
                invoiceNo: invoiceNo,
                receiptSentAt: admin.firestore.FieldValue.serverTimestamp(),
                receiptEmail: recipientEmail,
            });

            // ── 8. Update Subscription Dates & Lifecycle ────────────────
            // Calculate expiry based on billing cycle
            const expiryDate = new Date();
            if (newData.isYearly) {
                expiryDate.setFullYear(expiryDate.getFullYear() + 1);
            } else if (newData.isSixMonths) {
                expiryDate.setMonth(expiryDate.getMonth() + 6);
            } else {
                expiryDate.setMonth(expiryDate.getMonth() + 1);
            }

            const subscriptionRef = admin.firestore()
                .collection(tenantId)
                .doc(appId)
                .collection("subscriptions")
                .doc(uid);

            await subscriptionRef.set({
                status: "active",
                planName: planName,
                isYearly: newData.isYearly || false,
                isSixMonths: newData.isSixMonths || false,
                price: totalAmount,
                startedAt: admin.firestore.FieldValue.serverTimestamp(),
                expiresAt: admin.firestore.Timestamp.fromDate(expiryDate),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                reminderSent: false, // Reset for new period
                corporateEmail: recipientEmail,
            }, { merge: true });

            console.log(`[LIFECYCLE] Updated subscription for ${uid} | expires=${expiryDate.toISOString()}`);

        } catch (error) {
            console.error(`[RECEIPT ERROR] processPaymentSuccess failed for ${txnId}:`, error);
        }
    });

/**
 * ─────────────────────────────────────────────────────────────────────────────
 * Subscription Expiry Reminder (Daily Schedule)
 * ─────────────────────────────────────────────────────────────────────────────
 * Checks for active subscriptions expiring in 3 days and sends a reminder.
 */
exports.checkSubscriptionExpiryReminders = onSchedule("0 0 * * *", async (event) => {
    console.log("[SCHEDULER] Running daily subscription expiry check...");

    const now = new Date();
    const threeDaysFromNow = new Date();
    threeDaysFromNow.setDate(now.getDate() + 3);

    try {
        const subscriptionsSnapshot = await admin.firestore()
            .collectionGroup("subscriptions")
            .where("status", "==", "active")
            .where("reminderSent", "==", false)
            .where("expiresAt", "<=", admin.firestore.Timestamp.fromDate(threeDaysFromNow))
            .where("expiresAt", ">", admin.firestore.Timestamp.fromDate(now))
            .get();

        if (subscriptionsSnapshot.empty) {
            console.log("[SCHEDULER] No subscriptions nearing expiry.");
            return;
        }

        console.log(`[SCHEDULER] Found ${subscriptionsSnapshot.size} subscriptions nearing expiry.`);

        const reminderPromises = subscriptionsSnapshot.docs.map(async (doc) => {
            const subData = doc.data();
            const uid = doc.id;
            const recipientEmail = subData.corporateEmail;
            const planName = subData.planName || "Subscription";
            const expiryDate = subData.expiresAt.toDate();
            const formattedExpiry = expiryDate.toLocaleDateString("en-IN", {
                day: "2-digit",
                month: "long",
                year: "numeric"
            });

            if (!recipientEmail) {
                console.warn(`[WARN] No corporate email for sub ${doc.ref.path}. Skipping.`);
                return;
            }

            // 1. Build Reminder Email
            const htmlReminder = `
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <style>
                    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; }
                    .container { max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 8px; }
                    .header { background-color: ${BRAND_BLUE}; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
                    .content { padding: 30px; }
                    .footer { text-align: center; font-size: 12px; color: #999; margin-top: 20px; }
                    .button { display: inline-block; padding: 12px 24px; background-color: ${BRAND_BLUE}; color: white; text-decoration: none; border-radius: 4px; font-weight: bold; margin-top: 20px; }
                </style>
            </head>
            <body>
                <div class="container">
                    <div class="header">
                        <h1>Subscription Alert</h1>
                    </div>
                    <div class="content">
                        <p>Hello,</p>
                        <p>This is a reminder that your <strong>${planName}</strong> subscription is about to expire on <strong>${formattedExpiry}</strong>.</p>
                        <p>To avoid any interruption in service, please renew your subscription before it expires.</p>
                        <center>
                            <a href="#" class="button">Renew Now</a>
                        </center>
                        <p>If you have already renewed, please ignore this email.</p>
                        <p>Thank you,<br>Rooks And Brooks Team</p>
                    </div>
                    <div class="footer">
                        &copy; ${new Date().getFullYear()} Rooks And Brooks. All rights reserved.
                    </div>
                </div>
            </body>
            </html>`;

            // 2. Queue email in 'mail' collection
            await admin.firestore().collection("mail").add({
                to: recipientEmail,
                message: {
                    subject: 'Urgent: Your Subscription is Expiring Soon!',
                    html: htmlReminder,
                },
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                type: "expiry_reminder",
                uid: uid,
            });

            // 3. Mark as reminder sent
            await doc.ref.update({ reminderSent: true });

            console.log(`[SCHEDULER] Reminder sent to ${recipientEmail} for subscription ${doc.ref.path}`);
        });

        await Promise.all(reminderPromises);
        console.log("[SCHEDULER] ✅ All reminders processed.");

    } catch (error) {
        console.error("[SCHEDULER ERROR] checkSubscriptionExpiryReminders failed:", error);
    }
});
