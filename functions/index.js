const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");
const Razorpay = require("razorpay");

admin.initializeApp();
const db = admin.firestore();

// Server-side Razorpay credentials (never exposed to Flutter client)
// Configured via Firebase Environment Configuration or Secret Manager:
// firebase functions:config:set razorpay.key_id="rzp_test_..." razorpay.key_secret="..."
const getRazorpayInstance = () => {
  const keyId =
    process.env.RAZORPAY_KEY_ID ||
    functions.config().razorpay?.key_id;
  const keySecret =
    process.env.RAZORPAY_KEY_SECRET ||
    functions.config().razorpay?.key_secret;

  if (!keyId || !keySecret) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Razorpay API credentials are not configured on the server. Please set RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET."
    );
  }

  return {
    instance: new Razorpay({ key_id: keyId, key_secret: keySecret }),
    keyId,
    keySecret,
  };
};

/**
 * 1. CREATE RAZORPAY ORDER (Callable HTTPS Function)
 * Enforces server-side amount verification (₹4500 = 450000 paise).
 */
exports.createRazorpayOrder = functions.https.onCall(async (data, context) => {
  // Ensure student is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Authentication required to initiate payment."
    );
  }

  const { applicationId, routeId } = data;
  if (!applicationId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Application ID is required."
    );
  }

  const uid = context.auth.uid;

  // Verify application from Firestore
  const appDoc = await db.collection("bus_pass_applications").doc(applicationId).get();
  if (!appDoc.exists) {
    throw new functions.https.HttpsError(
      "not-found",
      "Bus pass application record not found."
    );
  }

  const appData = appDoc.data();
  // Ensure the caller owns the application or is admin
  if (appData.uid !== uid && appData.studentId !== uid) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Unauthorized access to application."
    );
  }

  // Prevent double payment
  if (
    appData.paymentStatus === "Paid" ||
    appData.paymentStatus === "success"
  ) {
    throw new functions.https.HttpsError(
      "already-exists",
      "This application is already paid."
    );
  }

  // Strict route fare verification (Default ₹4500, or exact route fare from database)
  const fare = Number(appData.fare) || 4500.0;
  const amountPaise = Math.round(fare * 100); // 4500 INR = 450000 paise

  const { instance, keyId } = getRazorpayInstance();
  const receiptReference = `RCPT-${applicationId.slice(-8)}-${Date.now()}`;

  try {
    const order = await instance.orders.create({
      amount: amountPaise,
      currency: "INR",
      receipt: receiptReference,
      notes: {
        applicationId,
        studentId: uid,
        studentName: appData.fullName || appData.studentName || "Student",
        route: appData.route || appData.routeName || "",
      },
    });

    // Create tracking payment attempt in `payments` collection
    const paymentRef = db.collection("payments").doc();
    const now = admin.firestore.FieldValue.serverTimestamp();

    await paymentRef.set({
      paymentId: paymentRef.id,
      applicationId,
      studentId: uid,
      studentName: appData.fullName || appData.studentName || "Student",
      routeId: routeId || appData.routeId || "",
      routeName: appData.route || appData.routeName || "Route",
      amount: fare,
      currency: "INR",
      razorpayOrderId: order.id,
      paymentStatus: "created",
      paymentMethod: "Razorpay",
      createdAt: now,
      updatedAt: now,
    });

    // Update application with active order ID
    await appDoc.ref.update({
      razorpayOrderId: order.id,
      activePaymentId: paymentRef.id,
      updatedAt: now,
    });

    return {
      orderId: order.id,
      keyId,
      amount: amountPaise,
      currency: "INR",
      paymentId: paymentRef.id,
    };
  } catch (err) {
    console.error("Razorpay order creation failed:", err);
    throw new functions.https.HttpsError(
      "internal",
      `Failed to create Razorpay order: ${err.message || err}`
    );
  }
});

/**
 * 2. VERIFY RAZORPAY PAYMENT (Callable HTTPS Function)
 * Verifies HMAC-SHA256 signature using Razorpay Key Secret.
 * Sets paymentStatus = "paid" and applicationStatus = "pending_admin_approval" (NEVER auto-approved).
 */
exports.verifyRazorpayPayment = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Authentication required to verify payment."
    );
  }

  const {
    applicationId,
    paymentId,
    razorpayOrderId,
    razorpayPaymentId,
    razorpaySignature,
  } = data;

  if (
    !applicationId ||
    !razorpayOrderId ||
    !razorpayPaymentId ||
    !razorpaySignature
  ) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Missing required Razorpay verification parameters."
    );
  }

  const { keySecret } = getRazorpayInstance();

  // Compute expected HMAC SHA-256 signature: hmac_sha256(order_id + "|" + razorpay_payment_id, secret)
  const expectedSignature = crypto
    .createHmac("sha256", keySecret)
    .update(`${razorpayOrderId}|${razorpayPaymentId}`)
    .digest("hex");

  const isSignatureValid = expectedSignature === razorpaySignature;

  if (!isSignatureValid) {
    console.error("Signature verification failed", {
      expected: expectedSignature,
      received: razorpaySignature,
    });

    if (paymentId) {
      await db.collection("payments").doc(paymentId).update({
        paymentStatus: "failed",
        failureReason: "Razorpay signature verification mismatch.",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    throw new functions.https.HttpsError(
      "permission-denied",
      "Payment verification failed: cryptographic signature mismatch."
    );
  }

  const now = admin.firestore.FieldValue.serverTimestamp();

  // 1. Update Payment Record to 'paid'
  const payDocRef = paymentId
    ? db.collection("payments").doc(paymentId)
    : db.collection("payments").doc();

  await payDocRef.set(
    {
      paymentStatus: "paid",
      razorpayPaymentId,
      razorpaySignature,
      paidAt: now,
      verifiedAt: now,
      updatedAt: now,
    },
    { merge: true }
  );

  // 2. Update Application Status to Pending Admin Approval
  const appDocRef = db.collection("bus_pass_applications").doc(applicationId);
  const appSnap = await appDocRef.get();
  if (appSnap.exists) {
    const appData = appSnap.data();

    await appDocRef.update({
      paymentStatus: "Paid",
      status: "Pending", // Pending Admin Approval
      passStatus: "Pending",
      paidAt: now,
      verifiedPaymentId: razorpayPaymentId,
      updatedAt: now,
    });

    // 3. Update Bus Pass document (status Pending, pass is NOT active yet)
    const studentUid = appData.uid || appData.studentId;
    if (studentUid) {
      await db.collection("bus_passes").doc(studentUid).set(
        {
          paymentStatus: "Paid",
          status: "Pending",
          passStatus: "Pending",
          updatedAt: now,
        },
        { merge: true }
      );
    }

    // 4. Generate Official Receipt
    const receiptRef = db.collection("receipts").doc(payDocRef.id);
    await receiptRef.set({
      receiptId: receiptRef.id,
      paymentId: payDocRef.id,
      applicationId,
      studentId: studentUid,
      studentName: appData.fullName || appData.studentName || "Student",
      route: appData.route || appData.routeName || "",
      routeId: appData.routeId || "",
      boarding: appData.boardingStop || "",
      destination: appData.destinationStop || "",
      fare: appData.fare || 4500.0,
      amount: appData.fare || 4500.0,
      paymentMethod: "Razorpay",
      transactionId: razorpayPaymentId,
      razorpayOrderId,
      razorpayPaymentId,
      paymentStatus: "Paid",
      paymentDate: now,
      createdAt: now,
    });
  }

  return {
    success: true,
    message: "Payment verified successfully. Awaiting administrative approval.",
    paymentId: payDocRef.id,
  };
});

/**
 * 3. RAZORPAY WEBHOOK (HTTP Request Function)
 * Reliable asynchronous server-to-server webhook processing.
 */
exports.razorpayWebhook = functions.https.onRequest(async (req, res) => {
  if (req.method !== "POST") {
    return res.status(405).send("Method Not Allowed");
  }

  const webhookSecret =
    process.env.RAZORPAY_WEBHOOK_SECRET ||
    functions.config().razorpay?.webhook_secret;

  if (webhookSecret) {
    const signature = req.headers["x-razorpay-signature"];
    const expectedSignature = crypto
      .createHmac("sha256", webhookSecret)
      .update(JSON.stringify(req.body))
      .digest("hex");

    if (signature !== expectedSignature) {
      console.warn("Invalid webhook signature received.");
      return res.status(400).send("Invalid Signature");
    }
  }

  const event = req.body.event;
  const payload = req.body.payload;

  if (event === "payment.captured") {
    const paymentEntity = payload.payment.entity;
    const orderId = paymentEntity.order_id;
    const paymentId = paymentEntity.id;

    // Find payment document by razorpayOrderId
    const payQuery = await db
      .collection("payments")
      .where("razorpayOrderId", "==", orderId)
      .limit(1)
      .get();

    if (!payQuery.empty) {
      const payDoc = payQuery.docs[0];
      const payData = payDoc.data();

      if (payData.paymentStatus !== "paid") {
        const now = admin.firestore.FieldValue.serverTimestamp();
        await payDoc.ref.update({
          paymentStatus: "paid",
          razorpayPaymentId: paymentId,
          paidAt: now,
          verifiedAt: now,
          updatedAt: now,
        });

        // Update application
        if (payData.applicationId) {
          const appRef = db.collection("bus_pass_applications").doc(payData.applicationId);
          await appRef.update({
            paymentStatus: "Paid",
            status: "Pending",
            passStatus: "Pending",
            paidAt: now,
            updatedAt: now,
          });
        }
      }
    }
  }

  return res.status(200).json({ status: "ok" });
});
