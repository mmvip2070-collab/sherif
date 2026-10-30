# لقطة LOQTA: تطبيق أندرويد بـ Capacitor

الملفات جاهزة: `capacitor.config.json` (appId = com.loqta.app) و`www/` (الموقع كله) و`assets/` (اللوجو للأيقونة والسبلاش).
مش محتاج `npx cap init`، الإعداد موجود. لو شغّلته هيسألك تكتب فوق الملف، اقفله.

## المتطلبات
Node.js (النسخة اللي بتطلبها وثائق Capacitor الحالية) + Android Studio + JDK.

## الخطوات (من داخل فولدر loqta-android)
```
npm install
npm i @capacitor/core @capacitor/android @capacitor/splash-screen @capacitor/status-bar
npm i -D @capacitor/cli @capacitor/assets
npx cap add android
npm run icons        # بيولّد أيقونة التطبيق والسبلاش من فولدر assets
npx cap sync android
npx cap open android # يفتح Android Studio، دوس Run على موبايل أو محاكي
```

## اسم التطبيق بالعربي تحت الأيقونة
افتح `android/app/src/main/res/values/strings.xml` وغيّر `app_name` و`title_activity_main` لـ `لقطة`.

## بعد أي تعديل في الموقع
عدّل الملفات في `www/` ثم `npx cap sync android`.

## النشر على Google Play
Build > Generate Signed Bundle (AAB). احتفظ بالـ keystore وكلمة السر في مكان آمن، لأنك محتاجهم لكل تحديث جاي.
قبل النشر: استبدل Tailwind CDN (في product.html و admin.html) بملف CSS مبني محلياً، وربط Supabase بدل localStorage.
