# تحسينات استعلامات Firestore وتقليل الاستهلاك
## Firebase Quota Optimization Guide

تم تطبيق مجموعة من التحسينات الشاملة على التطبيق لتقليل استهلاك حصص Firestore بنسبة **تصل إلى 90%**.

---

## 📊 المشكلة السابقة

### الاستهلاك الأصلي:
- **Polling Interval:** 5 ثوانٍ
- **عدد الـ Streams:** ~20 stream نشط
- **استعلامات في الدقيقة:** 240 طلب
- **استعلامات يومية:** ~345,000 قراءة/يوم
- **النتيجة:** تجاوز حصة 50k يومية في أقل من ساعة!

---

## ✅ التحسينات المطبّقة

### 1️⃣ زيادة مدة الـ Polling
```dart
// ❌ قبل
final Duration pollingInterval = const Duration(seconds: 5);

// ✅ بعد
final Duration pollingInterval = const Duration(seconds: 60);
```

**التأثير:** تقليل الطلبات بنسبة **92%** (من 345k إلى 28.8k يومياً)

---

### 2️⃣ نظام ذاكرة مؤقتة ذكي (Memory Cache with TTL)

```dart
class CachedData {
  final List<dynamic> data;
  final DateTime expiresAt;

  CachedData(this.data, this.expiresAt);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
```

**الآلية:**
- تخزين البيانات في الذاكرة لمدة **5 دقائق**
- عدم جلب البيانات من السيرفر إذا كانت موجودة وصالحة
- تحديث تلقائي كل 60 ثانية فقط عند الانتهاء

**التأثير:** تقليل إضافي بنسبة **70-80%** من الطلبات المتبقية

---

### 3️⃣ تحسين دالة `_createSmartStream`

**التحسينات:**
- ✅ التحقق من **memory cache** قبل طلب السيرفر
- ✅ استخدام **disk cache** كبديل احتياطي
- ✅ تقليل الطلبات المتكررة للبيانات النادرة التغيير

```dart
void tick() async {
  // تحقق من الذاكرة المؤقتة أولاً
  final cachedInMemory = _memoryCache[cacheKey];
  if (cachedInMemory != null && !cachedInMemory.isExpired) {
    // لا حاجة لطلب جديد!
    controller.add(cachedInMemory.data);
    return;
  }
  
  // جلب من السيرفر فقط عند الحاجة
  final data = await fetcher();
  _memoryCache[cacheKey] = CachedData(data, DateTime.now().add(_cacheTTL));
}
```

---

### 4️⃣ تحسين استعلامات AI Admin

**التغييرات:**
- ✅ إضافة حد افتراضي: **50 سجل** بدلاً من 200
- ✅ **Slider لتحديد العدد** (10-200) حسب الحاجة
- ✅ تخزين نتائج AI في الذاكرة المؤقتة لمدة **10 دقائق**
- ✅ كشف تلقائي للاستعلامات المكررة

```dart
// إذا كانت نفس الاستعلام موجوداً في الذاكرة المؤقتة
final cacheKey = 'AI_QUERY_${question}_${mode}_${scope.toString()}';
final cached = _memoryCache[cacheKey];
if (cached != null && !cached.isExpired) {
  return {'success': true, 'answer': cached.data[0], 'cached': true};
}
```

**التأثير:** عدم تكرار نفس الاستعلام AI خلال 10 دقائق، وتقليل حجم البيانات المجلوبة

---

### 5️⃣ إضافة أدوات إدارة الذاكرة المؤقتة

```dart
// مسح البيانات منتهية الصلاحية
void cleanExpiredCache() {
  _memoryCache.removeWhere((key, value) => value.isExpired);
}

// مسح كامل للذاكرة المؤقتة
void clearAllCache() {
  _memoryCache.clear();
  // مسح disk cache أيضاً
}
```

**الفائدة:** تحرير الذاكرة وتجنب امتلاء التخزين المحلي

---

## 📈 النتائج المتوقعة

### قبل التحسينات:
```
- Polling: 5 ثوانٍ
- Streams: 20 نشط
- قراءات يومية: ~345,000
- تكلفة (Blaze): ~$1.80/يوم
```

### بعد التحسينات:
```
- Polling: 60 ثانية
- Memory Cache: 5 دقائق TTL
- قراءات يومية: ~5,000-10,000
- تكلفة (Blaze): ~$0.10/يوم أو أقل
- توفير: 95-97%
```

---

## 🎯 أفضل الممارسات للاستخدام

### للمطورين:
1. **استخدم `clearAllCache()` عند الحاجة فقط** (مثل تحديث البيانات الحساسة)
2. **اضبط `_limit` في AI Admin** على أقل قيمة ممكنة تحقق الغرض
3. **تجنب فتح شاشات متعددة** بـ streams نشطة في نفس الوقت
4. **راقب استخدام Firebase Console** بانتظام

### للمستخدمين النهائيين:
- زر **"مسح الذاكرة المؤقتة"** في شاشة AI Admin يزيل البيانات القديمة
- اختر **نطاق البيانات** بحذر (اختر فقط ما تحتاجه)
- **حد البيانات:** استخدم slider لتقليل العدد إذا كنت تريد ملخصاً سريعاً

---

## 🔧 التحديثات المستقبلية الموصى بها

### 1. استخدام Firestore Listeners بدلاً من Polling
```dart
// بدلاً من polling كل 60 ثانية
Stream<List<User>> streamUsers() {
  return FirebaseFirestore.instance
    .collection('users')
    .snapshots()
    .map((snapshot) => snapshot.docs.map((doc) => User.fromFirestore(doc)).toList());
}
```
**الفائدة:** تحديثات فورية فقط عند التغيير، بدون طلبات دورية

### 2. Pagination في قوائم كبيرة
```dart
Query query = FirebaseFirestore.instance
  .collection('trainings')
  .limit(20);

// عند التمرير للأسفل
query = query.startAfterDocument(lastDocument).limit(20);
```

### 3. استخدام Cloud Functions للاستعلامات الثقيلة
- نقل عمليات AI Admin إلى Cloud Function
- تجميع البيانات على السيرفر وإرسال النتيجة فقط

---

## 📝 ملاحظات مهمة

### ⚠️ تحذيرات:
- **Memory cache تُمسح** عند إعادة تشغيل التطبيق
- **Disk cache تبقى** حتى مع إعادة التشغيل
- **TTL = 5 دقائق** قد يحتاج تعديل حسب طبيعة البيانات

### 💡 نصائح:
- البيانات النادرة التغيير (مثل المعدات): يمكن زيادة TTL إلى 15 دقيقة
- البيانات الديناميكية (مثل النتائج المباشرة): يمكن تقليل TTL إلى دقيقة واحدة
- استعلامات AI: 10 دقائق مناسبة للأسئلة المتكررة

---

## 📚 الملفات المعدّلة

1. **`lib/services/api_service.dart`**
   - إضافة class `CachedData`
   - تحديث `pollingInterval` إلى 60 ثانية
   - إضافة `_memoryCache` و `_cacheTTL`
   - تحسين `_createSmartStream()`
   - تحسين `aiAdminQuery()` مع pagination
   - إضافة `cleanExpiredCache()` و `clearAllCache()`

2. **`lib/screens/ai_admin_screen.dart`**
   - إضافة `_limit` slider للتحكم في عدد السجلات
   - إضافة زر **"مسح الذاكرة المؤقتة"**
   - إضافة إشعار عند استخدام cached data

---

## 🚀 الخطوات التالية

1. ✅ **اختبار التطبيق** بعد التحديثات
2. ⏳ **مراقبة Firebase Console** لمدة 24-48 ساعة
3. 📊 **تحليل استهلاك الحصص** الجديد
4. 🔧 **ضبط TTL و polling interval** حسب النتائج

---

**آخر تحديث:** 28 فبراير 2026  
**الإصدار:** 2.0.0-optimized
