const { onDocumentUpdated, onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Sends a notification to a specific user based on their role and ID.
 */
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

exports.onAssignmentWritten = onDocumentWritten("{tenantId}/{appId}/Admin_details/{bookingId}", handleAssignment);

// 3. Notify Admin when a new ticket is raised
exports.onTicketRaised = onDocumentCreated("{tenantId}/{appId}/Admin_details/{bookingId}", async (event) => {
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
exports.onStatusUpdated = onDocumentUpdated("{tenantId}/{appId}/Admin_details/{bookingId}", async (event) => {
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

// 4. Send Email Trigger when a document is created in the "mail" collection
exports.sendEmailTrigger = onDocumentCreated("mail/{docId}", async (event) => {
    const data = event.data.data();
    if (!data || !data.to) {
        console.error("Skipping email trigger: Missing 'to' field.");
        return;
    }

    const nodemailer = require("nodemailer");

    // SMTP configuration
    // IMPORTANT: The user needs to provide a valid App Password for this to work with Gmail.
    const transporter = nodemailer.createTransport({
        service: "gmail",
        auth: {
            user: "rookssoftservices@gmail.com",
            pass: "YOUR_GMAIL_APP_PASSWORD", // ACTION REQUIRED: Replace with real password or App Password
        },
    });

    const mailOptions = {
        from: '"Rooks App" <rookssoftservices@gmail.com>',
        to: data.to,
        subject: data.message.subject,
        html: data.message.html,
        attachments: (data.message.attachments || []).map((att) => ({
            filename: att.filename,
            content: att.content,
            encoding: "base64",
        })),
    };

    try {
        console.log(`Attempting to send email to ${data.to}...`);
        await transporter.sendMail(mailOptions);
        console.log(`Email sent successfully to ${data.to}`);

        // Update status in Firestore
        return event.data.ref.update({
            status: {
                state: "SENT",
                sentAt: admin.firestore.FieldValue.serverTimestamp(),
            },
        });
    } catch (error) {
        console.error("Error sending email:", error);
        return event.data.ref.update({
            status: {
                state: "ERROR",
                error: error.message,
                failedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
        });
    }
});
