// 1. تغيير طريقة الاستيراد لتناسب V2
import {onDocumentCreated, onDocumentDeleted} from "firebase-functions/v2/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

admin.initializeApp();

// =================================================================
// الدالة الأولى: إرسال إشعار عند انضمام متدرب جديد (بصيغة V2)
// =================================================================
export const onnewtraineesignup = onDocumentCreated("users/{userId}", async (event) => {
  // V2: البيانات موجودة داخل event.data
  const snapshot = event.data;
  if (!snapshot) {
    logger.log("No data associated with the event");
    return;
  }
  const newUser = snapshot.data();

  if (newUser.role === "trainee") {
    logger.log(`New trainee signed up: ${newUser.displayName}`);

    const trainersSnapshot = await admin.firestore().collection("users")
      .where("role", "==", "trainer").get();

    if (trainersSnapshot.empty) {
      logger.log("No trainers found to notify.");
      return;
    }

    const tokens: string[] = [];
    trainersSnapshot.forEach((doc) => {
      const trainer = doc.data();
      if (trainer.fcmToken) {
        tokens.push(trainer.fcmToken);
      }
    });

    if (tokens.length === 0) {
      logger.log("No trainers with FCM tokens found.");
      return;
    }

    const payload = {
      notification: {
        title: "متدرب جديد انضم للأكاديمية!",
        body: `المتدرب ${newUser.displayName} قد قام بإنشاء حساب.`,
      },
    };

    logger.log(`Sending notification to ${tokens.length} trainers.`);
    await admin.messaging().sendToDevice(tokens, payload);
  }
});

// =================================================================
// الدالة الثانية: حذف المستخدم من نظام المصادقة (بصيغة V2)
// =================================================================
export const onuserdeleted = onDocumentDeleted("users/{userId}", async (event) => {
  // V2: الـ ID موجود داخل event.params
  const userId = event.params.userId;
  logger.log(`Attempting to delete user from Auth: ${userId}`);

  try {
    await admin.auth().deleteUser(userId);
    logger.log(`Successfully deleted user ${userId} from Auth.`);
  } catch (error) {
    logger.error(`Error deleting user ${userId} from Auth:`, error);
  }
});


// =================================================================
// الدالة الثالثة: إنشاء مستخدم جديد بواسطة المدير (بصيغة V2)
// =================================================================
export const createnewuser = onCall(async (request) => {
  // V2: معلومات المصادقة والبيانات موجودة في "request"
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }

  const callerDoc = await admin.firestore().collection("users").doc(callerUid).get();
  if (callerDoc.data()?.role !== "admin") {
    throw new HttpsError(
      "permission-denied",
      "Only admins can create new users."
    );
  }

  const {email, password, displayName, role, parentId} = request.data;

  try {
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: displayName,
    });

    logger.log("Successfully created new user:", userRecord.uid);

    await admin.firestore().collection("users").doc(userRecord.uid).set({
      uid: userRecord.uid,
      email: email,
      displayName: displayName,
      role: role,
      parentId: parentId ?? "",
      photoUrl: "",
      fcmToken: "",
    });

    return {result: `User ${displayName} created successfully.`};
  } catch (error) {
    logger.error("Error creating new user:", error);
    throw new HttpsError(
      "internal",
      "An error occurred while creating the user."
    );
  }
});