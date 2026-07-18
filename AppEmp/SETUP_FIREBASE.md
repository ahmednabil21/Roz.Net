# إعداد Firebase لإشعارات تطبيق الموظف الفني

Package / Bundle ID المطلوب:
```
Android: com.wakeel.technician_employee_app
iOS:     com.wakeel.technicianemployeeapp
```

يجب أن يطابق Bundle ID في Xcode قيمة `BUNDLE_ID` داخل `GoogleService-Info.plist`.

الباكند يرسل الإشعار عبر `FcmPushService` عند إنشاء مهمة.

---

## أ) في Firebase Console

**مهم:** تطبيق الموظف مربوط بمشروع Firebase اسمه `technicianemployeeapp` (رقم `138547177904`).
مفتاح الخدمة على السيرفر **يجب** أن يكون من **نفس** هذا المشروع، وإلا يفشل FCM بـ `SenderIdMismatch`
وتظهر إشعارات فقط والتطبيق في الذاكرة عبر SignalR (تختفي بعد إزالته من Recent Apps).

1. افتح [Firebase Console](https://console.firebase.google.com) → مشروع **technicianemployeeapp**.
2. **أضف تطبيق Android**
   - Package name: `com.wakeel.technician_employee_app`
   - نزّل الملف: `google-services.json`
   - ضعه هنا:
     ```
     AppEmp/android/app/google-services.json
     ```
3. **أضف تطبيق iOS** (للمحاكي/الآيفون)
   - Bundle ID: `com.wakeel.technicianemployeeapp`  
     (يجب أن يطابق `PRODUCT_BUNDLE_IDENTIFIER` في Xcode و`BUNDLE_ID` في الملف)
   - نزّل: `GoogleService-Info.plist`
   - ضعه هنا:
     ```
     AppEmp/ios/Runner/GoogleService-Info.plist
     ```
   - في Xcode: أضفه إلى target `Runner` إن لم يُضف تلقائياً.
4. **مفتاح الخدمة للباكند (مهم جداً)**
   - Project settings → **Service accounts**
   - Generate new private key → ملف JSON
   - ارفعه للسيرفر مثلاً:
     ```
     /root/wakeel_Roz/firebase-service-account.json
     ```
   - في `appsettings.Production.json` موجود:
     ```json
     "Firebase": {
       "CredentialPath": "/root/wakeel_Roz/firebase-service-account.json"
     }
     ```
5. **للآيفون فقط (APNs)**
   - Firebase → Project settings → Cloud Messaging → Apple app configuration
   - ارفع **APNs Authentication Key** من [Apple Developer](https://developer.apple.com)  
     (Keys → Key with Apple Push Notifications service)
   - بدون هذه الخطوة: أندرويد يعمل، iOS لن يستلم إشعاراً خارج التطبيق.

---

## ب) على سيرفر الباكند

```bash
# بعد وضع ملف JSON على السيرفر
ls -la /root/wakeel_Roz/firebase-service-account.json

# أعد نشر التطبيق ثم أعد تشغيل الخدمة
```

تأكد في اللوجات عند الإقلاع ظهور:
`تم تهيئة Firebase Admin من Firebase:CredentialPath`

إن ظهر تحذير «لم يُهيّأ Firebase» فالإشعارات لن تُرسل من السيرفر.

---

## ج) في تطبيق Flutter

```bash
cd /Users/al-noor/Documents/WakeelFrontMustafa-main/AppEmp
flutter pub get
flutter clean
flutter run   # جهاز/محاكي — ليس web للإشعار الحقيقي
```

1. سجّل دخول موظف.
2. اسمح بالإشعارات إن طُلب.
3. تحقق من جدول `UserFcmDevices` في قاعدة البيانات (صف للموظف).
4. من لوحة الإدارة أنشئ مهمة لهذا الموظف و**اخرج من التطبيق**.
5. يجب وصول إشعار النظام.

---

## د) اختبار سريع

| خطوة | النتيجة المتوقعة |
|------|-------------------|
| دخول موظف | نجاح + تسجيل توكن |
| صف في `UserFcmDevices` | موجود |
| مهمة جديدة والتطبيق مغلق | إشعار على الهاتف |

API الذي يسجّل الجهاز:
`POST https://roz-api.execute-iq.com/wakeel/api/FcmDevices/token`
