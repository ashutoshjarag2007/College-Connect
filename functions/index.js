
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();

exports.reviewStudent = onCall(
  { region: "asia-south1" },
  async (request) => {
    // 1. User must be logged in
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Please login first."
      );
    }

    // 2. Verify Admin role from Firestore
    const adminRef = db.collection("users").doc(request.auth.uid);
    const adminSnap = await adminRef.get();

    if (
      !adminSnap.exists ||
      adminSnap.data().role !== "admin" ||
      adminSnap.data().status !== "active"
    ) {
      throw new HttpsError(
        "permission-denied",
        "Only an active Admin can review students."
      );
    }

    // 3. Validate request
    const studentUid = request.data?.studentUid;
    const decision = request.data?.decision;

    if (
      typeof studentUid !== "string" ||
      !["approve", "reject"].includes(decision)
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Invalid student or decision."
      );
    }

    if (studentUid === request.auth.uid) {
      throw new HttpsError(
        "permission-denied",
        "Admin cannot approve their own account."
      );
    }

    // 4. Review the student in a transaction
    const studentRef = db.collection("users").doc(studentUid);

    await db.runTransaction(async (transaction) => {
      const studentSnap = await transaction.get(studentRef);

      if (!studentSnap.exists) {
        throw new HttpsError(
          "not-found",
          "Student profile not found."
        );
      }

      const student = studentSnap.data();

      if (student.role !== "student") {
        throw new HttpsError(
          "failed-precondition",
          "This account is not a student account."
        );
      }

      if (student.status !== "pending") {
        throw new HttpsError(
          "failed-precondition",
          "This student has already been reviewed."
        );
      }

      transaction.update(studentRef, {
        status: decision === "approve" ? "active" : "rejected",
        reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
        reviewedBy: request.auth.uid,
      });
    });

    return {
      success: true,
      message: decision === "approve"
        ? "Student approved successfully."
        : "Student rejected successfully.",
    };
  }
);
