// functions/index.js

// نستعمل واجهة v2 من Firebase Functions
const { onRequest } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2/options");
// ✅ تريجر لـ Realtime Database v2
const { onValueWritten } = require("firebase-functions/v2/database");
const { onObjectFinalized } = require("firebase-functions/v2/storage");
const axios = require("axios");
const FormData = require("form-data");



const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

// نخلي كل الفنكشنز على نفس الريجن
setGlobalOptions({ region: "us-central1" });

// نضمن إن admin ما ينتهي أكثر من مرة
if (!admin.apps.length) {
  admin.initializeApp();
}

// إعداد nodemailer مع Gmail
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: "",        // ✅ إيميلك
    pass: "",          // ✅ App Password من Google
  },
});

// CORS بسيط للـ Flutter
function setCorsHeaders(res) {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
}

// ===================================================
// 1) طلب كود التسجيل (إرسال الكود على الإيميل)
// ===================================================
exports.requestSignUpCode = onRequest(async (req, res) => {
  setCorsHeaders(res);

  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Only POST allowed" });
  }

  const { email, firstName, lastName, password } = req.body || {};

  if (!email || !firstName || !lastName || !password) {
    return res.status(400).json({
      error:
        "Missing fields (email, firstName, lastName, password) are required.",
    });
  }

  // كود من 5 أرقام
  const code = Math.floor(10000 + Math.random() * 90000).toString();

  try {
    // نخزّن بيانات التسجيل مؤقتًا في pending_signups
    await admin.firestore().collection("pending_signups").doc(email).set({
      email,
      firstName,
      lastName,
      password,
      code,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // نرسل الإيميل
    await transporter.sendMail({
      from: `"Smart Garden" <essafayad77@gmail.com>`,
      to: email,
      subject: "Smart Garden - Verification Code",
      text: `Your verification code is: ${code}`,
      html: `<p>Your verification code is: <b>${code}</b></p>`,
    });

    return res.status(200).json({ success: true });
  } catch (err) {
    console.error("Error in requestSignUpCode:", err);
    return res
      .status(500)
      .json({ error: "Internal error while sending code." });
  }
});

// ===================================================
// 2) تأكيد الكود وإنشاء الحساب الحقيقي
// ===================================================
exports.confirmSignUp = onRequest(async (req, res) => {
  setCorsHeaders(res);

  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Only POST allowed" });
  }

  const { email, code } = req.body || {};

  if (!email || !code) {
    return res
      .status(400)
      .json({ error: "Missing fields (email, code) are required." });
  }

  try {
    const docRef = admin.firestore().collection("pending_signups").doc(email);
    const snap = await docRef.get();

    if (!snap.exists) {
      return res
        .status(400)
        .json({ error: "No pending signup for this email." });
    }

    const data = snap.data();

    if (!data.code || data.code !== code) {
      return res.status(400).json({ error: "Invalid code." });
    }

    const firstName = data.firstName || "";
    const lastName = data.lastName || "";
    const fullName = `${firstName} ${lastName}`.trim();

    // 1) إنشاء المستخدم في Authentication
    const userRecord = await admin.auth().createUser({
      email: data.email,
      password: data.password,
      displayName: fullName,
    });

    // 2) إنشاء document في users/{uid}
    await admin.firestore().collection("users").doc(userRecord.uid).set({
      firstName,
      lastName,
      fullName,
      email: data.email,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      espId: null,
      isEmailVerified: true,
      // fcmToken: سيُضاف لاحقًا من التطبيق
    });

    // 3) حذف التسجيل المؤقت
    await docRef.delete();

    return res.status(200).json({ success: true });
  } catch (err) {
    console.error("Error in confirmSignUp:", err);
    return res
      .status(500)
      .json({ error: "Internal error while confirming code." });
  }
});

// ===================================================
// 3) طلب كود نسيان كلمة المرور
// ===================================================
exports.requestPasswordResetCode = onRequest(async (req, res) => {
  setCorsHeaders(res);

  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Only POST allowed" });
  }

  const { email } = req.body || {};

  if (!email) {
    return res.status(400).json({ error: "Missing field: email" });
  }

  try {
    // نتأكد أن فيه يوزر بهذا الإيميل في Auth
    let userRecord;
    try {
      userRecord = await admin.auth().getUserByEmail(email);
    } catch (err) {
      console.error("getUserByEmail error:", err);
      return res
        .status(400)
        .json({ error: "No user found with this email." });
    }

    const code = Math.floor(10000 + Math.random() * 90000).toString();

    // نخزن الكود مؤقتًا في password_reset_codes
    await admin
      .firestore()
      .collection("password_reset_codes")
      .doc(email)
      .set({
        email,
        uid: userRecord.uid,
        code,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    // نرسل الإيميل بالكود
    await transporter.sendMail({
      from: `"Smart Garden" <essafayad77@gmail.com>`,
      to: email,
      subject: "Smart Garden - Password Reset Code",
      text: `Your password reset code is: ${code}`,
      html: `<p>Your password reset code is: <b>${code}</b></p>`,
    });

    return res.status(200).json({ success: true });
  } catch (err) {
    console.error("Error in requestPasswordResetCode:", err);
    return res
      .status(500)
      .json({ error: "Internal error while sending reset code." });
  }
});

// ===================================================
// 4) تأكيد كود نسيان كلمة المرور وتغييرها
// ===================================================
exports.resetPasswordWithCode = onRequest(async (req, res) => {
  setCorsHeaders(res);

  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Only POST allowed" });
  }

  const { email, code, newPassword } = req.body || {};

  if (!email || !code || !newPassword) {
    return res.status(400).json({
      error: "Missing fields (email, code, newPassword) are required.",
    });
  }

  try {
    const docRef = admin
      .firestore()
      .collection("password_reset_codes")
      .doc(email);

    const snap = await docRef.get();

    if (!snap.exists) {
      return res
        .status(400)
        .json({ error: "No reset request found for this email." });
    }

    const data = snap.data();

    if (!data.code || data.code !== code) {
      return res.status(400).json({ error: "Invalid code." });
    }

    const uid = data.uid;

    // نغير كلمة المرور في Firebase Auth
    await admin.auth().updateUser(uid, {
      password: newPassword,
    });

    // نحذف الكود عشان يكون مؤقت فقط
    await docRef.delete();

    return res.status(200).json({ success: true });
  } catch (err) {
    console.error("Error in resetPasswordWithCode:", err);
    return res
      .status(500)
      .json({ error: "Internal error while resetting password." });
  }
});

// ===================================================
// 5) دالة عامة: إرسال إشعار لمستخدم يملك espId معيّن
// ===================================================
async function sendNotificationToEspUser(espId, title, body) {
  try {
    const snap = await admin
      .firestore()
      .collection("users")
      .where("espId", "==", espId)
      .limit(1)
      .get();

    if (snap.empty) {
      console.log("No user found for espId:", espId);
      return;
    }

    const userDoc = snap.docs[0];
    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;

    if (!fcmToken) {
      console.log("User has no fcmToken, uid:", userDoc.id);
      return;
    }

    const message = {
      token: fcmToken,
      notification: { title, body },
    };

    const response = await admin.messaging().send(message);
    console.log("Notification sent to", userDoc.id, "=>", response);
  } catch (err) {
    console.error("Error in sendNotificationToEspUser:", err);
  }
}

// ===================================================
// 6) إشعارات أحداث الجهاز (المطر / الخطأ / الماء القليل / الري الطبيعي)
// RTDB path: /devices/{espId}/alerts/{alertId}
// ===================================================
exports.onDeviceAlert = onValueWritten(
  "/devices/{espId}/alerts/{alertId}",
  async (event) => {
    const before = event.data.before.val();
    const after = event.data.after.val();

    // نشتغل فقط لما alert جديد ينضاف (ما كانش موجود قبل)
    if (before || !after) {
      return null;
    }

    const espId = event.params.espId;
    const alertData = after || {};

    const type = alertData.type;   // skip_rain, pipe_error, pump_error, low_water, normal_irrigation
    console.log("New alert from", espId, "=>", type, alertData);

    let title = "Smart Garden";
    let body = "";

    switch (type) {
      case "skip_rain":
        title = "تخطي الري بسبب المطر";
        body = "تم تخطي عملية الري بسبب توقع هطول الأمطار.";
        break;

      case "pipe_error":
        title = "خطأ في الأنابيب";
        body = "تم اكتشاف مشكلة في أنابيب الري، يرجى فحص النظام.";
        break;

      case "pump_error":
        title = "خطأ في المضخة";
        body = "تم اكتشاف مشكلة في المضخة، يرجى فحصها.";
        break;

      case "low_water":
        title = "مستوى الماء منخفض";
        body = "مستوى الماء في الخزان منخفض، يرجى إعادة تعبئة الخزان.";
        break;

      case "normal_irrigation":
        title = "تم الري بنجاح";
        body = "تم تنفيذ عملية الري بشكل طبيعي.";
        break;

      default:
        title = "Smart Garden";
        body = "حدث جديد من نظام الري.";
        break;
    }

    await sendNotificationToEspUser(espId, title, body);
    return null;
  }
);

// ===================================================
// 7) إشعار عند تغيير وضع الجهاز Auto / Manual من Realtime DB
// RTDB path: /devices/{espId}/mode
// ===================================================
exports.onModeChangeSendNotification = onValueWritten(
  "/devices/{espId}/mode",
  async (event) => {
    const beforeMode = event.data.before.val();
    const afterMode = event.data.after.val();

    // لو ما تغيّرش أو القيمة فاضية نخرج
    if (!beforeMode || !afterMode || beforeMode === afterMode) {
      return null;
    }

    const espId = event.params.espId;
    console.log(
      `Mode changed for ESP ${espId}: ${beforeMode} -> ${afterMode}`
    );

    // نبحث عن المستخدم اللي يملك هذا الـ espId في مجموعة users
    const usersSnap = await admin
      .firestore()
      .collection("users")
      .where("espId", "==", espId)
      .limit(1)
      .get();

    if (usersSnap.empty) {
      console.log("No user found with this espId:", espId);
      return null;
    }

    const userDoc = usersSnap.docs[0];
    const token = userDoc.get("fcmToken");

    if (!token) {
      console.log("No fcmToken for user:", userDoc.id);
      return null;
    }

    // نص الإشعار بالعربي
    let body = "";
    if (afterMode === "auto") {
      body = "تم تغيير وضع النظام إلى Auto (تشغيل تلقائي).";
    } else if (afterMode === "manual") {
      body = "تم تغيير وضع النظام إلى Manual (تشغيل يدوي).";
    } else {
      // لو قيمة غريبة نطنّش
      return null;
    }

    const message = {
      token,
      notification: {
        title: "Smart Garden - Mode Changed",
        body,
      },
      data: {
        espId: String(espId),
        oldMode: String(beforeMode),
        newMode: String(afterMode),
      },
    };

    try {
      const response = await admin.messaging().send(message);
      console.log("Notification sent, response:", response);
    } catch (err) {
      console.error("Error sending FCM notification:", err);
    }

    return null;
  }
);

// ===================================================
// 8) إرسال إشعار مباشرة عبر FCM Token عن طريق HTTP (API)
// ===================================================
exports.sendNotificationByToken = onRequest(async (req, res) => {
  setCorsHeaders(res);

  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Only POST allowed" });
  }

  const { token, title, body, data } = req.body || {};

  if (!token || !title || !body) {
    return res.status(400).json({
      error: "Fields (token, title, body) are required.",
    });
  }

  try {
    const message = {
      token: token,
      notification: {
        title: title,
        body: body,
      },
      data: data || {},
    };

    const response = await admin.messaging().send(message);
    console.log("FCM sent:", response);

    return res.status(200).json({ success: true, messageId: response });
  } catch (err) {
    console.error("Error in sendNotificationByToken:", err);
    return res
      .status(500)
      .json({ error: "Internal error while sending notification." });
  }
});
// ===================================================
// 9) Plant Disease AI Trigger (Storage -> Cloud Run -> Firestore)
// Storage path: plant_diagnosis/{userId}/{caseId}.jpg
// Firestore: plantDiagnosis/{userId}/cases/{caseId}
// ===================================================

const AI_PREDICT_FILE_URL =
  "https://plant-ai-service-994679352406.us-central1.run.app/predict_file";

exports.onPlantDiagnosisImageUpload = onObjectFinalized(async (event) => {
  const object = event.data;
  const filePath = object.name || "";

  // اشتغل فقط على المسار المطلوب
  if (!filePath.startsWith("plant_diagnosis/")) return;

  // plant_diagnosis/{userId}/{caseId}.jpg
  const parts = filePath.split("/");
  if (parts.length < 3) return;

  const userId = parts[1];
  const fileName = parts[2];
  const caseId = fileName.replace(/\.[^/.]+$/, ""); // remove extension

  // ✅ Firebase bucket الصحيح
  const bucket = admin.storage().bucket("");
  const file = bucket.file(filePath);

  const caseRef = admin
    .firestore()
    .collection("plantDiagnosis")
    .doc(userId)
    .collection("cases")
    .doc(caseId);

  // اكتب حالة PROCESSING أولاً
  await caseRef.set(
    {
      status: "PROCESSING",
      imagePath: filePath,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  try {
    // ✅ نزّل الصورة داخل الفنكشن (بدون Signed URL)
    const [buf] = await file.download();

    // ✅ ارسلها لـ Cloud Run كـ multipart/form-data
    const form = new FormData();
    form.append("file", buf, {
      filename: fileName,
      contentType: object.contentType || "image/jpeg",
    });

    const resp = await axios.post(AI_PREDICT_FILE_URL, form, {
      headers: form.getHeaders(),
      timeout: 30000,
      maxBodyLength: Infinity,
      maxContentLength: Infinity,
    });

    const { label, confidence, top_k } = resp.data;

    await caseRef.set(
      {
        status: "DONE",
        label,
        confidence,
        topK: top_k,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  } catch (err) {
    // طباعة تفاصيل أكثر في Logs
    const msg =
      err?.response?.data?.detail ||
      err?.response?.data ||
      err?.message ||
      String(err);

    console.error("AI trigger FAILED:", msg);

    await caseRef.set(
      {
        status: "FAILED",
        error: typeof msg === "string" ? msg : JSON.stringify(msg),
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }
});
