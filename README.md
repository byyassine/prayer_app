# مواقيت الصلاة — تطبيق Android 📱

تطبيق أصلي (Flutter) لمواقيت الصلاة، يجلب البيانات من موقع وزارة الأوقاف
والمشؤون الإسلامية كل 48 ساعة، ويعمل بالكامل بدون إنترنت، مع إشعارات
حقيقية لكل صلاة حتى والتطبيق مسدود.

## المميزات
- نفس جدول الوزارة الرسمي = نفس الدقة
- جلب تلقائي كل 48 ساعة (WorkManager) + تحديث عند فتح التطبيق بالسحب
- إشعارات دقيقة (AlarmManager exact) لكل صلاة، حتى في وضع السكون
- إعادة جدولة الإشعارات تلقائياً بعد إعادة تشغيل الهاتف
- تصميم ليلي متحرك: نجوم متلألئة، قمر، سيلويت مسجد
- تبويبات الأيام (3 قبل + اليوم + 3 بعد) + عد تنازلي للصلاة القادمة

## خطوات البناء

1. ثبّت Flutter: https://flutter.dev/docs/get-started/install
2. أنشئ مشروعاً فارغاً بهذا الاسم:
   ```
   flutter create prayer_app
   ```
3. استبدل الملفات:
   - `pubspec.yaml` ← هذا المشروع
   - `android/app/src/main/AndroidManifest.xml` ← هذا المشروع
   - `android/app/src/main/kotlin/com/example/prayer_app/BootReceiver.kt` (ملف جديد)
   - `lib/*` ← هذا المشروع
4. في `android/app/build.gradle` تأكد أن `minSdkVersion 21`
5. نفّذ:
   ```
   flutter pub get
   flutter build apk --release
   ```
6. تجد الـ APK في `build/app/outputs/flutter-apk/app-release.apk`

## أول تشغيل (مهم ⚠️)
بعد تثبيت الـ APK على الهاتف، افتح التطبيق مرة واحدة وأعطِ الأذونات:
- **الإشعارات** (Notifications)
- **التنبيهات والتذكيرات الدقيقة** (Alarms & reminders) — Android 12+
- ويُستحسن تعطيل تحسين البطارية للتطبيق (Battery → Unrestricted)
  حتى لا يؤخر النظام الإشعارات.

## تغيير المدينة
في `lib/repository.dart`:
```dart
static const int ville = 117; // ← رمز مدينتك
```
الرمز هو نفسه `ville` في رابط موقع الوزارة.

## بنية الملفات
| الملف | الدور |
|---|---|
| `lib/habous_parser.dart` | قراءة جدول الوزارة (نفس منطق PHP ديالك) |
| `lib/repository.dart` | الجلب + التخزين المحلي + صلاحية 48 ساعة |
| `lib/notification_service.dart` | برمجة إشعارات الشهر كامل (AlarmManager) |
| `lib/main.dart` | الواجهة + المهام الخلفية |
| `BootReceiver.kt` | إعادة جدولة الإشعارات بعد إعادة تشغيل الهاتف |


## البناء أونلاين بدون تثبيت أي شيء (GitHub Actions) ☁️
1. أنشئ حساباً مجانياً على github.com
2. أنشئ مستودعاً (Repository) جديداً سمّه `prayer_app` (Public)
3. من صفحة المستودع: **Add file → Upload files** → اسحب محتوى هذا المجلد كاملاً (مع مجلد `.github` المخفي — فعّل عرض الملفات المخفية)
4. اضغط **Commit changes** — البناء يبدأ تلقائياً
5. اذهب لتبويب **Actions** → انتظر النقطة الصفراء حتى تصبح علامة ✅ خضراء (~10-15 دقيقة أول مرة)
6. اضغط على آخر تشغيل (Build APK) → في الأسفل **Artifacts** → نزّل `prayer-app-apk`
7. داخل الـ ZIP تجد `app-release.apk` — انقله للهاتف وثبّته
