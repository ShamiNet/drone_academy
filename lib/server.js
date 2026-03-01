const express = require('express');
const admin = require('firebase-admin');
const cors = require('cors');
const bodyParser = require('body-parser');
const axios = require('axios');

// 🔴 المفتاح المعتمد
const API_KEY = "AIzaSyBn60A5sIw5SkOK94iyxXxmeH8mprdKp7g";

const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const app = express();

app.use(cors());
app.use(bodyParser.json());

// دالة مساعدة لتحويل لقطات البيانات (Snapshots) إلى مصفوفة مع تنسيق التواريخ
const snapshotToArray = (snapshot) => {
    return snapshot.docs.map(doc => {
        const data = doc.data();
        for (const key in data) {
            if (data[key] && typeof data[key].toDate === 'function') {
                data[key] = data[key].toDate().toISOString();
            }
        }
        return { id: doc.id, ...data };
    });
};

// --- 🆕 نقطة نهاية التسجيل (إنشاء حساب عبر السيرفر لتجاوز الحظر والتحقق من حظر الجهاز) ---
app.post('/api/signup', async (req, res) => {
    const { email, password, displayName, role, fcmToken, deviceId } = req.body; // نستقبل معرف الجهاز

    try {
        // 1. 🛑 التحقق أولاً: هل الجهاز محظور؟
        if (deviceId) {
            const banDoc = await db.collection('blocked_devices').doc(deviceId).get();
            if (banDoc.exists) {
                return res.status(403).json({
                    success: false,
                    error: "DEVICE_BANNED",
                    reason: banDoc.data().reason
                });
            }
        }

        // 2. إنشاء المستخدم في المصادقة (Authentication)
        const userRecord = await admin.auth().createUser({
            email: email,
            password: password,
            displayName: displayName,
        });

        // 3. حفظ بيانات المستخدم في قاعدة البيانات (Firestore)       
        const userData = {
            uid: userRecord.uid,
            email: email,
            displayName: displayName,
            role: role || 'trainee',
            photoUrl: '',
            fcmToken: fcmToken || '',
            createdAt: admin.firestore.Timestamp.now(),
            isBlocked: false,
            lastDeviceId: deviceId // نحفظ معرف الجهاز
        };

        await db.collection('users').doc(userRecord.uid).set(userData);

        res.json({ success: true, uid: userRecord.uid });

    } catch (error) {
        console.error("Signup Error:", error);
        res.status(400).json({ success: false, error: error.message });
    }
});

// --- 🚫 نظام حظر الأجهزة ---
app.post('/api/check_device_ban', async (req, res) => {
    const { deviceId } = req.body;
    if (!deviceId) return res.json({ isBanned: false });

    try {
        const doc = await db.collection('blocked_devices').doc(deviceId).get();
        if (doc.exists) return res.json({ isBanned: true, reason: doc.data().reason });
        res.json({ isBanned: false });
    } catch (error) { res.status(500).send(error.message); }
});

app.post('/api/ban_device', async (req, res) => {
    const { deviceId, reason, bannedBy } = req.body;
    try {
        await db.collection('blocked_devices').doc(deviceId).set({    
            reason: reason || 'Violating rules',
            bannedAt: admin.firestore.Timestamp.now(),
            bannedBy: bannedBy
        });
        res.json({ success: true });
    } catch (error) { res.status(500).send(error.message); }
});

app.post('/api/unban_device', async (req, res) => {
    const { deviceId } = req.body;
    try {
        await db.collection('blocked_devices').doc(deviceId).delete();
        res.json({ success: true });
    } catch (error) { res.status(500).send(error.message); }
});

// --- 🔐 تسجيل الدخول (مع فحص الحظر) ---
app.post('/api/login', async (req, res) => {
    const { email, password, deviceId } = req.body;
    try {
        // 1. فحص حظر الجهاز
        if (deviceId) {
            const banDoc = await db.collection('blocked_devices').doc(deviceId).get();
            if (banDoc.exists) {
                return res.status(403).json({ success: false, error: "DEVICE_BANNED", reason: banDoc.data().reason });
            }
        }

        const authResponse = await axios.post(
            `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}`,
            { email, password, returnSecureToken: true }
        );

        const uid = authResponse.data.localId;
        const userRef = db.collection('users').doc(uid);
        const userDoc = await userRef.get();

        let userData = {};
        if (userDoc.exists) {
            userData = userDoc.data();
            if (deviceId) await userRef.update({ lastDeviceId: deviceId });
        } else {
            userData = { uid: uid, email: email, role: 'trainee', displayName: 'User', lastDeviceId: deviceId };
            await userRef.set(userData);
        }

        if (userData.isBlocked) {
             return res.status(403).json({ success: false, error: "USER_BANNED" });
        }

        res.json({
            success: true,
            uid: uid,
            email: email,
            role: userData.role || 'trainee',
            displayName: userData.displayName || '',
            photoUrl: userData.photoUrl || '',
            lastDeviceId: deviceId
        });
    } catch (error) {
        console.error("Login Error:", error.response?.data || error.message);
        // 🔥 استخراج رسالة الخطأ الحقيقية من Firebase وإرسالها للتطبيق
        const actualError = error.response?.data?.error?.message || error.message || "Login failed";
        res.status(400).json({ success: false, error: actualError }); 
    }
});

// --- 🤖 تحليل الذكاء الاصطناعي الفردي (gemini-2.5-flash) ---        
app.post('/api/analyze_notes', async (req, res) => {
    const { notes, requester } = req.body;

    // ✅ فحص البريد الإلكتروني - الميزة متاحة فقط لـ kloklop8@gmail.com
    if (requester?.email !== 'kloklop8@gmail.com') {
        return res.status(403).json({
            success: false,
            summary: 'عذراً، ميزة الذكاء الاصطناعي متاحة فقط للحسابات  المصرح لها.'
        });
    }

    if (!notes || !Array.isArray(notes) || notes.length === 0) {      
        return res.json({ summary: "لا توجد ملاحظات كافية للتحليل." });
    }
    const notesText = notes.join('\n- ');
    const prompt = `بصفتك خبير تدريب، قم بتحليل الملاحظات التالية لمتدرب:\n- ${notesText}\nالمطلوب: اكتب ملخصاً قصيراً جداً ومفيداً (باللغة         العربية) يوضح نقاط القوة والضعف والتوصية. اجعل الرد نصياً مباشراً. .`;

    try {
        const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${API_KEY}`;
        const response = await axios.post(url, { contents: [{ parts: [{ text: prompt }] }] });
        const summary = response.data?.candidates?.[0]?.content?.parts?.[0]?.text || "تعذر استخراج النص.";
        res.json({ summary: summary });
    } catch (error) {
        console.error("AI Error:", error.response?.data || error.message);
        res.json({ summary: "فشل الاتصال بخدمة الذكاء الاصطناعي." }); 
    }
});

// --- 🤖 مسار جديد: تحليل الملاحظات بشكل مجمع (طلب واحد للجميع لتوفير الاستهلاك) ---
app.post('/api/analyze_bulk_notes', async (req, res) => {
    // نستقبل كائن يحتوي على معرف المتدرب وملاحظاته
    const { traineesNotes, requester } = req.body;

    // ✅ فحص البريد الإلكتروني - الميزة متاحة فقط لـ kloklop8@gmail.com
    if (requester?.email !== 'kloklop8@gmail.com') {
        return res.status(403).json({
            success: false,
            summaries: {},
            error: 'عذراً، ميزة الذكاء الاصطناعي متاحة فقط للحسابات اللمصرح لها.'
        });
    }

    if (!traineesNotes || Object.keys(traineesNotes).length === 0) {  
        return res.json({ summaries: {} });
    }

    try {
        // بناء موجه (Prompt) واحد يحتوي على بيانات الجميع
        let prompt = "بصفتك خبير تدريب، قم بتحليل ملاحظات المتدربين التالية وأعطني ملخصاً لكل متدرب بنسق JSON حصراً. يجب أن يكون المفتاح هو     معرف المتدرب والقيمة هي الملخص العربي القصير:\n";

        for (const [id, notes] of Object.entries(traineesNotes)) {    
            prompt += `المتدرب ${id}:\n- ${notes.join('\n- ')}\n`;    
        }

        const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${API_KEY}`;
        const response = await axios.post(url, { contents: [{ parts: [{ text: prompt }] }] });

        const resultText = response.data?.candidates?.[0]?.content?.parts?.[0]?.text || "{}";

        // استخراج كائن JSON من نص استجابة الذكاء الاصطناعي
        const jsonMatch = resultText.match(/\{[\s\S]*\}/);
        const summaries = jsonMatch ? JSON.parse(jsonMatch[0]) : {};  

        res.json({ summaries });
    } catch (error) {
        console.error("Bulk AI Error:", error.message);
        res.json({ summaries: {}, error: "فشل التحليل المجمع بسبب خطأ في السيرفر." });
    }
});

// --- 🧠 استعلام الذكاء الاصطناعي للمدير (لوحة الذكاء الاصطناعي للمدير) ---
app.post('/api/ai_admin_query', async (req, res) => {
  const { question, mode, scope, requester } = req.body;

  if (!question || typeof question !== 'string') {
    return res.status(400).json({ error: 'INVALID_QUESTION' });       
  }
  if (!requester?.uid) {
    return res.status(401).json({ error: 'MISSING_REQUESTER' });      
  }

  try {
    // ✅ فحص البريد الإلكتروني أولاً - الميزة متاحة فقط لـ kloklop8@ggmail.com
    if (requester?.email !== 'kloklop8@gmail.com') {
      return res.status(403).json({ error: 'عذراً، ميزة الذكاء الاصطنااعي متاحة فقط للحسابات المصرح لها.' });
    }

    // ✅ تحقق الدور من قاعدة البيانات (لا نثق بالعميل)
    const userDoc = await db.collection('users').doc(requester.uid).get();
    if (!userDoc.exists) {
      return res.status(403).json({ error: 'FORBIDDEN' });
    }
    const role = (userDoc.data().role || '').toLowerCase();
    if (!['admin', 'owner'].includes(role)) {
      return res.status(403).json({ error: 'FORBIDDEN' });
    }

    // ✅ جلب البيانات حسب النطاق
    const data = {};
    const limit = 200;

    if (scope?.users) {
      const snap = await db.collection('users').limit(limit).get();   
      data.users = snapshotToArray(snap);
    }
    if (scope?.trainings) {
      const snap = await db.collection('trainings').orderBy('level').limit(limit).get();
      data.trainings = snapshotToArray(snap);
    }
    if (scope?.results) {
      const snap = await db.collection('results').orderBy('date', 'desc').limit(limit).get();
      data.results = snapshotToArray(snap);
    }
    if (scope?.dailyNotes) {
      const snap = await db.collection('daily_notes').orderBy('date', 'desc').limit(limit).get();
      data.dailyNotes = snapshotToArray(snap);
    }
    if (scope?.equipment) {
      const snap = await db.collection('equipment').limit(limit).get();
      data.equipment = snapshotToArray(snap);
    }
    if (scope?.competitions) {
      const snap = await db.collection('competitions').limit(limit).get();
      data.competitions = snapshotToArray(snap);
    }
    if (scope?.schedule) {
      const snap = await db.collection('schedule').orderBy('startTime', 'desc').limit(limit).get();
      data.schedule = snapshotToArray(snap);
    }
        if (scope?.appControlPanel) {
            const configDoc = await db.collection('app_status').doc('config').get();
            data.appControlPanel = configDoc.exists
                ? { id: configDoc.id, ...configDoc.data() }
                : { isEnabled: true, minVersion: '1.0.0', updateUrl: '' };
        }
        if (scope?.appReleaseLog) {
            const configDoc = await db.collection('app_status').doc('config').get();
            data.appReleaseLog = configDoc.exists
                ? configDoc.data().releaseLog || {
                    appName: 'Drone Academy',
                    version: 'v1.0.2',
                    highlights: []
                }
                : {
                    appName: 'Drone Academy',
                    version: 'v1.0.2',
                    highlights: [
                        'إطلاق النسخة الأولى المتكاملة.',
                        'نظام إدارة ذكي للمتدربين والمدربين.',        
                        'دعم الذكاء الاصطناعي (Gemini AI) للتحليل.',  
                        'لوحة تحكم إدارية شاملة.',
                        'تحسينات في الأداء والمظهر (Dark Mode).'      
                    ]
                };
        }

    const dataJson = JSON.stringify(data);
    const maxChars = 120000; // حماية من حجم الطلب
    const trimmedData = dataJson.length > maxChars ? dataJson.slice(0, maxChars) : dataJson;

    const prompt = `
أنت مساعد إداري لتطبيق أكاديمية الدرون.
المطلوب: ${question}

نوع الطلب: ${mode}
القواعد:
- أجب بالعربية.
- كن مختصرًا وعمليًا.
- إذا كان السؤال يحتاج تفاصيل أكثر اطلبها.

البيانات المتاحة (JSON):
${trimmedData}
`;

    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${API_KEY}`;
    const response = await axios.post(url, {
      contents: [{ parts: [{ text: prompt }] }]
    });

    const answer =
      response.data?.candidates?.[0]?.content?.parts?.[0]?.text ||    
      'تعذر استخراج النص.';

    return res.json({ answer });
  } catch (error) {
    console.error('AI_ADMIN_QUERY Error:', error.response?.data || error.message);
    return res.status(500).json({ error: 'AI_ADMIN_QUERY_FAILED' });  
  }
});

// --- � التحقق من تحديثات الإصدار والإجبار على التحديث ---
app.post('/api/check_version', async (req, res) => {
  const { currentVersion } = req.body;

  try {
    const configDoc = await db.collection('app_status').doc('config').get();
    const config = configDoc.exists ? configDoc.data() : {};

    // قيم افتراضية
    const minRequiredVersion = config.minVersion || '1.0.0';
    const latestVersion = config.latestVersion || '1.0.2';
    const updateRequired = config.updateRequired || false;
    const updateMessage = config.updateMessage || 'تحديث جديد متاح. الرجاء التحديث للحصول على أفضل الخدمات.';
    const releaseLog = config.releaseLog || {
      appName: 'Drone Academy',
      version: latestVersion,
      highlights: []
    };

    // دالة مساعدة لمقارنة الإصدارات
    const compareVersions = (v1, v2) => {
      const parts1 = v1.replace(/v/i, '').split('.').map(Number);     
      const parts2 = v2.replace(/v/i, '').split('.').map(Number);     

      for (let i = 0; i < 3; i++) {
        const p1 = parts1[i] || 0;
        const p2 = parts2[i] || 0;
        if (p1 > p2) return 1;
        if (p1 < p2) return -1;
      }
      return 0;
    };

    const isOutdated = compareVersions(currentVersion, minRequiredVersion) < 0;
    const hasNewVersion = compareVersions(currentVersion, latestVersion) < 0;

    // 📊 تسجيل الطلب
    console.log(`📌 [CHECK_VERSION] Current: ${currentVersion} | Min Required: ${minRequiredVersion} | Latest: ${latestVersion}`);
    console.log(`   ├─ Is Outdated: ${isOutdated}`);
    console.log(`   ├─ Has New Version: ${hasNewVersion}`);
    console.log(`   └─ Update Required (Forced): ${updateRequired}`);

    res.json({
      success: true,
      currentVersion: currentVersion,
      minRequiredVersion: minRequiredVersion,
      latestVersion: latestVersion,
      isOutdated: isOutdated, // ❌ إعادة تحديث إجباري
      hasNewVersion: hasNewVersion, // ✅ تحديث اختياري
      updateRequired: updateRequired, // تم تفعيل الإجبار من لوحة التحكم
      updateMessage: updateMessage,
      releaseLog: releaseLog,
      appConfig: {
        isEnabled: config.isEnabled !== false,
        maintenanceMode: config.maintenanceMode || false,
        maintenanceMessage: config.maintenanceMessage || '',
        updateUrl: config.updateUrl || 'https://play.google.com/store/apps/details?id=com.droneacademy'
      }
    });

  } catch (error) {
    console.error('CHECK_VERSION Error:', error.message);
    res.status(500).json({
      success: false,
      error: 'فشل التحقق من الإصدار',
      message: error.message
    });
  }
});

// --- 📱 تحديث إعدادات الإصدار من لوحة التحكم (Admin only) ---       
app.post('/api/update_version_config', async (req, res) => {
  const { requester, latestVersion, minVersion, updateRequired, updateMessage, releaseLog } = req.body;

  try {
    // ✅ التحقق من أن المستخدم هو Admin أو Owner
    if (!requester?.uid) {
      return res.status(401).json({ error: 'MISSING_REQUESTER' });    
    }

    const userDoc = await db.collection('users').doc(requester.uid).get();
    if (!userDoc.exists) {
      return res.status(403).json({ error: 'USER_NOT_FOUND' });       
    }

    const role = (userDoc.data().role || '').toLowerCase();
    if (!['admin', 'owner'].includes(role)) {
      return res.status(403).json({ error: 'FORBIDDEN: Only admins can update version config' });
    }

    // تحديث الإصدارات في قاعدة البيانات
    const updateData = {
      updatedAt: admin.firestore.Timestamp.now(),
      updatedBy: requester.uid,
      updatedByEmail: userDoc.data().email || ''
    };

    if (latestVersion) updateData.latestVersion = latestVersion;      
    if (minVersion) updateData.minVersion = minVersion;
    if (updateRequired !== undefined) updateData.updateRequired = updateRequired;
    if (updateMessage) updateData.updateMessage = updateMessage;      
    if (releaseLog) updateData.releaseLog = releaseLog;

    // 📊 تسجيل التحديث
    console.log(`🔄 [UPDATE_VERSION_CONFIG]`);
    console.log(`   ├─ Updated By: ${userDoc.data().email || userDoc.data().displayName}`);
    console.log(`   ├─ Min Version: ${minVersion}`);
    console.log(`   ├─ Latest Version: ${latestVersion}`);
    console.log(`   ├─ Update Required: ${updateRequired}`);
    console.log(`   └─ Update Message: ${updateMessage}`);

    await db.collection('app_status').doc('config').set(updateData, { merge: true });

    // حفظ سجل للتغييرات
    await db.collection('version_history').add({
      timestamp: admin.firestore.Timestamp.now(),
      action: 'UPDATE_VERSION_CONFIG',
      updatedBy: requester.uid,
      email: userDoc.data().email || '',
      changes: updateData
    });

    res.json({
      success: true,
      message: 'تم تحديث إعدادات الإصدار بنجاح',
      updatedConfig: updateData
    });

  } catch (error) {
    console.error('UPDATE_VERSION_CONFIG Error:', error.message);     
    res.status(500).json({
      success: false,
      error: 'فشل تحديث إعدادات الإصدار',
      message: error.message
    });
  }
});



// 1. استقبال الخطأ وحفظه في قاعدة البيانات
app.post('/api/system_errors', async (req, res) => {
    try {
        const errorData = req.body;
        // نضيف توقيت السيرفر لضمان الدقة
        errorData.serverTimestamp = admin.firestore.Timestamp.now();  

        await db.collection('system_errors').add(errorData);
        res.json({ success: true });
    } catch (error) {
        console.error("Error logging system error:", error);
        res.status(500).json({ success: false, error: error.message });
    }
});

// 2. جلب سجل الأخطاء (لعرضها في تطبيق الأونر)
app.get('/api/system_errors', async (req, res) => {
    try {
        // نجلب آخر 100 خطأ مرتبة من الأحدث للأقدم
        const snapshot = await db.collection('system_errors')
                                 .orderBy('serverTimestamp', 'desc')  
                                 .limit(100)
                                 .get();
        res.json(snapshotToArray(snapshot));
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// 3. حذف سجل خطأ معين (بعد حله)
app.delete('/api/system_errors/:id', async (req, res) => {
    try {
        await db.collection('system_errors').doc(req.params.id).delete();
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// --- نقاط نهاية REST API (عمليات الإنشاء والقراءة والتحديث والحذف) ---

// المستخدمون
app.get('/api/users', async (req, res) => { try { let q=db.collection('users'); if(req.query.role) q=q.where('role','==',req.query.role); const s=await q.get(); res.json(snapshotToArray(s)); } catch(e){res.status(500).send(e.message);} });
app.get('/api/users/:id', async (req, res) => { try { const d=await db.collection('users').doc(req.params.id).get(); if(!d.exists) res.status(404).send('NF'); else res.json({id:d.id,...d.data()}); } catch(e){res.status(500).send(e.message);} });
app.post('/api/users', async (req, res) => { try { await db.collection('users').doc(req.body.uid).set(req.body,{merge:true}); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });
app.delete('/api/users/:id', async (req, res) => { try { await db.collection('users').doc(req.params.id).delete(); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });

// التدريبات
app.get('/api/trainings', async (req, res) => { try { const s=await db.collection('trainings').orderBy('level').get(); res.json(snapshotToArray(s)); } catch(e){res.status(500).send(e.message);} });
app.post('/api/trainings', async (req, res) => { try { req.body.createdAt=admin.firestore.Timestamp.now(); const r=await db.collection('trainings').add(req.body); res.json({success:true,id:r.id}); } catch(e){res.status(500).send(e.message);} });
app.put('/api/trainings/:id', async (req, res) => { try { await db.collection('trainings').doc(req.params.id).update(req.body); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });        
app.delete('/api/trainings/:id', async (req, res) => { try { await db.collection('trainings').doc(req.params.id).delete(); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });
app.get('/api/trainings/:id/steps', async (req, res) => { try { const s=await db.collection('trainings').doc(req.params.id).collection('steps').orderBy('order').get(); res.json(snapshotToArray(s)); } catch(e){res.status(500).send(e.message);} });
app.post('/api/trainings/:id/steps', async (req, res) => { try { await db.collection('trainings').doc(req.params.id).collection('steps').add(req.body); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });
app.put('/api/trainings/:id/steps/:stepId', async (req, res) => { try { await db.collection('trainings').doc(req.params.id).collection('steps').doc(req.params.stepId).update(req.body); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });
app.delete('/api/trainings/:id/steps/:stepId', async (req, res) => { try { await db.collection('trainings').doc(req.params.id).collection('steps').doc(req.params.stepId).delete(); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });

// المعدات والمخزون
app.get('/api/equipment', async (req, res) => { try { const s=await db.collection('equipment').get(); res.json(snapshotToArray(s)); } catch(e){res.status(500).send(e.message);} });
app.post('/api/equipment', async (req, res) => { try { if(req.body.createdAt) req.body.createdAt=admin.firestore.Timestamp.fromDate(new Date(req.body.createdAt)); await db.collection('equipment').add(req.body); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });
app.put('/api/equipment/:id', async (req, res) => { try { await db.collection('equipment').doc(req.params.id).update(req.body); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });        
app.delete('/api/equipment/:id', async (req, res) => { try { await db.collection('equipment').doc(req.params.id).delete(); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });
app.get('/api/equipment_log', async (req, res) => { try { let q=db.collection('equipment_log').orderBy('checkOutTime','desc'); if(req.query.equipmentId) q=q.where('equipmentId','==',req.query.equipmentId); const s=await q.get(); res.json(snapshotToArray(s)); } catch(e){res.status(500).send(e.message);} });
app.post('/api/equipment_log', async (req, res) => { try { if(req.body.checkOutTime) req.body.checkOutTime=admin.firestore.Timestamp.fromDate(new Date(req.body.checkOutTime)); if(req.body.checkInTime) req.body.checkInTime=admin.firestore.Timestamp.fromDate(new Date(req.body.checkInTime)); await db.collection('equipment_log').add(req.body); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });    
app.delete('/api/equipment_log/:id', async (req, res) => { try { await db.collection('equipment_log').doc(req.params.id).delete(); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });     

app.get('/api/inventory', async (req, res) => { try { const s=await db.collection('inventory').get(); res.json(snapshotToArray(s)); } catch(e){res.status(500).send(e.message);} });
app.post('/api/inventory', async (req, res) => { try { if(req.body.createdAt) req.body.createdAt=admin.firestore.Timestamp.fromDate(new Date(req.body.createdAt)); await db.collection('inventory').add(req.body); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });
app.put('/api/inventory/:id', async (req, res) => { try { await db.collection('inventory').doc(req.params.id).update(req.body); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });        
app.delete('/api/inventory/:id', async (req, res) => { try { await db.collection('inventory').doc(req.params.id).delete(); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });
app.get('/api/inventory_log', async (req, res) => { try { let q=db.collection('inventory_log').orderBy('date','desc'); if(req.query.itemId) q=q.where('itemId','==',req.query.itemId); const s=await q.get(); res.json(snapshotToArray(s)); } catch(e){res.status(500).send(e.message);} });
app.post('/api/inventory_log', async (req, res) => { try { if(req.body.date) req.body.date=admin.firestore.Timestamp.fromDate(new Date(req.body.date)); await db.collection('inventory_log').add(req.body); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });  

// النتائج والملاحظات
app.get('/api/results', async (req, res) => { try { let q=db.collection('results').orderBy('date','desc'); if(req.query.traineeUid) q=q.where('traineeUid','==',req.query.traineeUid); const s=await q.get(); res.json(snapshotToArray(s)); } catch(e){res.status(500).send(e.message);} });
app.post('/api/results', async (req, res) => { try { req.body.date=req.body.date?admin.firestore.Timestamp.fromDate(new Date(req.body.date)):admin.firestore.Timestamp.now(); await db.collection('results').add(req.body); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });
app.get('/api/daily_notes', async (req, res) => { try { let q=db.collection('daily_notes').orderBy('date','desc'); if(req.query.traineeUid) q=q.where('traineeUid','==',req.query.traineeUid); const s=await q.get(); res.json(snapshotToArray(s)); } catch(e){res.status(500).send(e.message);} });
app.post('/api/daily_notes', async (req, res) => { try { req.body.date=req.body.date?admin.firestore.Timestamp.fromDate(new Date(req.body.date)):admin.firestore.Timestamp.now(); await db.collection('daily_notes').add(req.body); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });
app.put('/api/daily_notes/:id', async (req, res) => { try { if(req.body.date) req.body.date=admin.firestore.Timestamp.fromDate(new Date(req.body.date)); await db.collection('daily_notes').doc(req.params.id).update(req.body); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });
app.delete('/api/daily_notes/:id', async (req, res) => { try { await db.collection('daily_notes').doc(req.params.id).delete(); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });

// متفرقات
app.get('/api/competitions', async (req, res) => { try { const s=await db.collection('competitions').get(); res.json(snapshotToArray(s)); } catch(e){res.status(500).send(e.message);} });
app.post('/api/competitions', async (req, res) => { try { await db.collection('competitions').add(req.body); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });
app.put('/api/competitions/:id', async (req, res) => { try { await db.collection('competitions').doc(req.params.id).update(req.body); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });  
app.delete('/api/competitions/:id', async (req, res) => { try { await db.collection('competitions').doc(req.params.id).delete(); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });       
app.get('/api/competition_entries', async (req, res) => { try { let q=db.collection('competition_entries').orderBy('score','asc'); if(req.query.competitionId) q=q.where('competitionId','==',req.query.competitionId); const s=await q.get(); res.json(snapshotToArray(s)); } catch(e){res.status(500).send(e.message);} });
app.post('/api/competition_entries', async (req, res) => { try { req.body.date=admin.firestore.Timestamp.now(); await db.collection('competition_entries').add(req.body); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });
app.get('/api/schedule', async (req, res) => { try { let q=db.collection('schedule'); if(req.query.traineeId) q=q.where('traineeId','==',req.query.traineeId); const s=await q.get(); res.json(snapshotToArray(s)); } catch(e){res.status(500).send(e.message);} });
app.post('/api/schedule', async (req, res) => { try { if(req.body.startTime) req.body.startTime=admin.firestore.Timestamp.fromDate(new Date(req.body.startTime)); if(req.body.endTime) req.body.endTime=admin.firestore.Timestamp.fromDate(new Date(req.body.endTime)); await db.collection('schedule').add(req.body); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });
app.get('/api/user_favorites', async (req, res) => { try { let q=db.collection('user_favorites'); if(req.query.trainerId) q=q.where('trainerId','==',req.query.trainerId); const s=await q.get(); res.json(snapshotToArray(s)); } catch(e){res.status(500).send(e.message);} });        
app.post('/api/user_favorites', async (req, res) => { try { await db.collection('user_favorites').add(req.body); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });
app.delete('/api/user_favorites/:id', async (req, res) => { try { await db.collection('user_favorites').doc(req.params.id).delete(); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });   
app.get('/api/user_favorite_competitions', async (req, res) => { try { let q=db.collection('user_favorite_competitions'); if(req.query.trainerId) q=q.where('trainerId','==',req.query.trainerId); const s=await q.get(); res.json(snapshotToArray(s)); } catch(e){res.status(500).send(e.message);} });
app.post('/api/user_favorite_competitions', async (req, res) => { try { await db.collection('user_favorite_competitions').add(req.body); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });
app.delete('/api/user_favorite_competitions/:id', async (req, res) => { try { await db.collection('user_favorite_competitions').doc(req.params.id).delete(); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });
app.get('/api/step_progress', async (req, res) => { try { let q=db.collection('step_progress'); if(req.query.userId) q=q.where('userId','==',req.query.userId); if(req.query.trainingId) q=q.where('trainingId','==',req.query.trainingId); const s=await q.get(); res.json(snapshotToArray(s)); } catch(e){res.status(500).send(e.message);} });
app.post('/api/step_progress', async (req, res) => { try { await db.collection('step_progress').add(req.body); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });
app.delete('/api/step_progress', async (req, res) => { try { const {userId,trainingId,stepId}=req.body; const s=await db.collection('step_progress').where('userId','==',userId).where('trainingId','==',trainingId).where('stepId','==',stepId).get(); const b=db.batch(); s.docs.forEach(d=>b.delete(d.ref)); await b.commit(); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });
app.get('/api/org_nodes', async (req, res) => { try { const s=await db.collection('org_nodes').get(); res.json(snapshotToArray(s)); } catch(e){res.status(500).send(e.message);} });
app.post('/api/org_nodes', async (req, res) => { try { await db.collection('org_nodes').add(req.body); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });
app.put('/api/org_nodes/:id', async (req, res) => { try { await db.collection('org_nodes').doc(req.params.id).update(req.body); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });        
app.delete('/api/org_nodes/:id', async (req, res) => { try { await db.collection('org_nodes').doc(req.params.id).delete(); res.json({success:true}); } catch(e){res.status(500).send(e.message);} });
// --- إدارة إعدادات التطبيق (قراءة وكتابة مع التحقق) ---
app.get('/api/app_config', async (req, res) => { 
  try { 
    const d = await db.collection('app_status').doc('config').get(); 
    const config = d.exists ? d.data() : {
      isEnabled: true,
      minVersion: '1.0.0',
      latestVersion: '1.0.2',
      updateRequired: false,
      updateUrl: '',
      updateMessage: 'تحديث جديد متاح'
    };
    res.json(config);
  } catch(e){
    res.status(500).send(e.message);
  } 
});

app.post('/api/app_config', async (req, res) => { 
  try { 
    const newConfig = req.body;
    
    // التحقق من البيانات
    if (!newConfig.minVersion || !newConfig.latestVersion) {
      return res.status(400).json({ 
        success: false, 
        error: 'يجب تحديد minVersion و latestVersion' 
      });
    }

    // 📊 حفظ البيانات في Firebase
    await db.collection('app_status').doc('config').set(newConfig, { merge: true });
    
    // 📝 حفظ سجل للتغييرات
    await db.collection('version_history').add({
      timestamp: admin.firestore.Timestamp.now(),
      action: 'UPDATE_CONFIG',
      data: newConfig,
      updatedBy: newConfig.updatedBy || 'admin'
    });

    res.json({ 
      success: true, 
      message: 'تم تحديث إعدادات التطبيق بنجاح',
      savedConfig: newConfig
    }); 
  } catch(e){
    res.status(500).send(e.message);
  } 
});    

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});