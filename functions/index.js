const { onDocumentUpdated, onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Sends a notification to a specific user based on their role and ID.
 */
async function sendNotification(role, userId, payload) {
    if (!userId) {
        console.error(`Skipping notification: Missing userId for role ${role}`);
        return;
    }

    try {
        console.log(`Attempting to fetch token for ${role}/${userId}`);
        const tokenDoc = await admin.firestore()
            .collection("notifications_tokens")
            .doc(role)
            .collection("tokens")
            .doc(userId)
            .get();

        if (!tokenDoc.exists) {
            console.warn(`No token doc found for user ${userId} with role ${role} at path notifications_tokens/${role}/tokens/${userId}`);
            return;
        }

        const data = tokenDoc.data();
        if (!data || !data.token) {
            console.warn(`Token field missing in doc for user ${userId} with role ${role}`);
            return;
        }

        const registrationToken = data.token;
        console.log(`Found token: ${registrationToken.substring(0, 10)}... for user ${userId}`);

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

        await admin.messaging().send(message);
        console.log(`Successfully sent notification to ${userId} (${role})`);
    } catch (error) {
        console.error(`Error sending notification to ${userId} (${role}):`, error);
        if (error.code === 'messaging/registration-token-not-registered') {
            console.warn(`Token for ${userId} is invalid/expired. Consider removing it.`);
        }
    }
}

// 1. Notify Engineer when a ticket is assigned
exports.onAssignmentCreated = onDocumentUpdated("Admin_details/{bookingId}", async (event) => {
    const newData = event.data.after.data();
    const oldData = event.data.before.data();

    // Trigger if assigned employee changed (assignment)
    // Note: Flutter app uses 'assignedEmployee', Cloud Function used 'engineerName'
    if (newData.assignedEmployee && newData.assignedEmployee !== oldData.assignedEmployee) {
        console.log(`Assignment detected for booking ${event.params.bookingId}. Engineer: ${newData.assignedEmployee}`);

        // 1. Notify Engineer
        const engineerPayload = {
            notification: {
                title: "New Assignment",
                body: `You have been assigned a new task: ${event.params.bookingId}`,
            },
            data: {
                type: "new_assignment",
                bookingId: event.params.bookingId,
            },
        };
        // Normalize engineer name if needed (e.g., trim)
        const engineerId = newData.assignedEmployee.trim();
        await sendNotification("engineer", engineerId, engineerPayload);

        // 2. Notify Customer
        if (newData.id) {
            console.log(`Notifying customer ${newData.id} about new assignment.`);
            const customerPayload = {
                notification: {
                    title: "Ticket Assigned",
                    body: `Your ticket (${event.params.bookingId}) has been assigned to ${newData.assignedEmployee}`,
                },
                data: {
                    type: "ticket_assigned",
                    bookingId: event.params.bookingId,
                    engineerName: newData.assignedEmployee,
                },
            };
            await sendNotification("customer", newData.id, customerPayload);
        } else {
            console.warn(`Cannot notify customer for assignment: Missing 'id' field in Admin_details/${event.params.bookingId}`);
        }
    }
});

// 2. Notify Admin when a new ticket is raised
exports.onTicketRaised = onDocumentCreated("Admin_details/{bookingId}", async (event) => {
    const ticketData = event.data.data();
    console.log(`New ticket raised: ${event.params.bookingId}`);

    // Find all registered admins to notify
    try {
        const adminsSnapshot = await admin.firestore()
            .collection("notifications_tokens")
            .doc("admin")
            .collection("tokens")
            .get();

        if (adminsSnapshot.empty) {
            console.log("No admins found in notifications_tokens/admin/tokens to notify");
            return;
        }

        const payload = {
            notification: {
                title: "New Ticket Raised",
                body: `A new ticket (${ticketData.bookingId}) has been raised by ${ticketData.customerName || "a customer"}`,
            },
            data: {
                type: "new_ticket",
                bookingId: ticketData.bookingId || "",
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
                console.error(`Error sending to admin token ${doc.id}:`, error);
                // Delete invalid tokens if needed
                if (error.code === 'messaging/registration-token-not-registered') {
                    // Optional: doc.ref.delete(); 
                }
                return null; // Continue despite error
            });
        });

        await Promise.all(promises);
        console.log(`Notified ${adminsSnapshot.size} admin devices of new ticket`);
    } catch (e) {
        console.error("Error in onTicketRaised:", e);
    }
});

// 3. Notify Customer when ticket status is updated
exports.onStatusUpdated = onDocumentUpdated("Admin_details/{bookingId}", async (event) => {
    const newData = event.data.after.data();
    const oldData = event.data.before.data();

    // Trigger if status updated (either engineer status or admin status)
    const statusChanged = (newData.engineerStatus !== oldData.engineerStatus) ||
        (newData.adminStatus !== oldData.adminStatus);

    if (statusChanged) {
        const currentStatus = newData.engineerStatus || newData.adminStatus || "Updated";
        console.log(`Status update detected for ${event.params.bookingId}: ${currentStatus}`);

        const payload = {
            notification: {
                title: "Ticket Update",
                body: `Your ticket (${event.params.bookingId}) status is now: ${currentStatus}`,
            },
            data: {
                type: "status_update",
                bookingId: event.params.bookingId,
                status: currentStatus,
            },
        };
        // Use 'id' field which is the customerId
        if (newData.id) {
            await sendNotification("customer", newData.id, payload);
        } else {
            console.warn(`Cannot notify customer of status update: Missing 'id' field in Admin_details/${event.params.bookingId}`);
        }
    }
});
