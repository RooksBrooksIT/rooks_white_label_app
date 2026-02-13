const { onDocumentUpdated, onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Sends a notification to a specific user based on their role and ID.
 */
async function sendNotification(role, userId, payload) {
    try {
        const tokenDoc = await admin.firestore()
            .collection("notifications_tokens")
            .doc(role)
            .collection("tokens")
            .doc(userId)
            .get();

        if (!tokenDoc.exists) {
            console.log(`No token found for user ${userId} with role ${role}`);
            return;
        }

        const registrationToken = tokenDoc.data().token;
        console.log(`Sending notification to token: ${registrationToken.substring(0, 10)}... for user ${userId}`);
        await admin.messaging().send({
            token: registrationToken,
            notification: payload.notification,
            data: payload.data || {},
        });
        console.log(`Successfully sent notification to ${userId} (${role})`);
    } catch (error) {
        console.error(`Error sending notification to ${userId} (${role}):`, error);
    }
}

// 1. Notify Engineer when a ticket is assigned
exports.onAssignmentCreated = onDocumentUpdated("Admin_details/{bookingId}", async (event) => {
    const newData = event.data.after.data();
    const oldData = event.data.before.data();

    // Trigger if assigned employee changed (assignment)
    // Note: Flutter app uses 'assignedEmployee', Cloud Function used 'engineerName'
    if (newData.assignedEmployee && newData.assignedEmployee !== oldData.assignedEmployee) {
        const payload = {
            notification: {
                title: "New Assignment",
                body: `You have been assigned a new task: ${event.params.bookingId}`,
            },
            data: {
                type: "new_assignment",
                bookingId: event.params.bookingId,
            },
        };
        console.log(`Detected assignment of ${event.params.bookingId} to ${newData.assignedEmployee}`);
        await sendNotification("engineer", newData.assignedEmployee, payload);
    }
});

// 2. Notify Admin when a new ticket is raised
exports.onTicketRaised = onDocumentCreated("Admin_details/{bookingId}", async (event) => {
    const ticketData = event.data.data();

    // Find all registered admins to notify
    const adminsSnapshot = await admin.firestore()
        .collection("notifications_tokens")
        .doc("admin")
        .collection("tokens")
        .get();

    if (adminsSnapshot.empty) {
        console.log("No admins found to notify");
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
        return admin.messaging().send({
            token: doc.data().token,
            notification: payload.notification,
            data: payload.data,
        });
    });

    await Promise.all(promises);
    console.log(`Notified ${adminsSnapshot.size} admins of new ticket`);
});

// 3. Notify Customer when ticket status is updated
exports.onStatusUpdated = onDocumentUpdated("Admin_details/{bookingId}", async (event) => {
    const newData = event.data.after.data();
    const oldData = event.data.before.data();

    // Trigger if status updated (either engineer status or admin status)
    const statusChanged = newData.engineerStatus !== oldData.engineerStatus ||
        newData.adminStatus !== oldData.adminStatus;

    if (statusChanged) {
        const currentStatus = newData.engineerStatus || newData.adminStatus || "Updated";
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
            console.log(`Sending status update notification to customer ${newData.id} for ticket ${event.params.bookingId}`);
            await sendNotification("customer", newData.id, payload);
        }
    }
});
