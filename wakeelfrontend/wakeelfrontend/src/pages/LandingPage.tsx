import React from 'react';
import {
  Smartphone,
  Apple,
  Download,
  Settings,
  Shield,
  CheckCircle,
  Wifi
} from 'lucide-react';
import rozLogo from '../images/Rozlogo.png';

const ANDROID_APK_URL = '/appase.apk';
const IOS_PROFILE_URL = '/RozEmp.mobileconfig';

const iosSteps = [
  'افتح هذه الصفحة من متصفح Safari.',
  'اضغط زر «تحميل آيفون».',
  'اذهب إلى الإعدادات ← عام ← VPN وإدارة الجهاز.',
  'ثبّت ملف التعريف واتبع التعليمات.'
];

const LandingPage: React.FC = () => {
  return (
    <div
      dir="rtl"
      className="min-h-screen bg-gradient-to-br from-primary-50 via-white to-primary-100 dark:from-gray-900 dark:via-gray-900 dark:to-gray-800"
      style={{ fontFamily: 'Cairo, sans-serif' }}
    >
      {/* Header */}
      <header className="bg-white/80 dark:bg-gray-800/80 backdrop-blur shadow-sm">
        <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-center sm:justify-start gap-3 py-4">
            <img src={rozLogo} alt="شركة روز" className="h-12 w-12 rounded-xl object-contain" />
            <div>
              <h1 className="text-xl font-bold text-gray-900 dark:text-white">
                شركة روز لخدمات الانترنت
              </h1>
              <p className="text-sm text-gray-500 dark:text-gray-400 flex items-center gap-1">
                <Wifi className="h-4 w-4" />
                خدمة إنترنت موثوقة وسريعة
              </p>
            </div>
          </div>
        </div>
      </header>

      {/* Hero */}
      <section className="py-14 sm:py-20">
        <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <div className="flex justify-center mb-8">
            <img
              src={rozLogo}
              alt="شركة روز لخدمات الانترنت"
              className="h-28 w-28 sm:h-36 sm:w-36 rounded-3xl object-contain shadow-lg bg-white p-2"
            />
          </div>
          <h1 className="text-3xl sm:text-5xl font-bold text-gray-900 dark:text-white mb-4">
            شركة روز لخدمات الانترنت
          </h1>
          <p className="text-lg sm:text-2xl text-gray-600 dark:text-gray-300 max-w-2xl mx-auto">
            حمّل تطبيق الموظف الآن وتابع مهامك واشتراكات المشتركين من هاتفك
          </p>
        </div>
      </section>

      {/* Download cards */}
      <section className="pb-16">
        <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
            {/* Android */}
            <div className="bg-white dark:bg-gray-800 rounded-2xl shadow-lg hover:shadow-xl transition-shadow p-8 flex flex-col">
              <div className="flex items-center gap-4 mb-6">
                <div className="bg-green-100 dark:bg-green-900/30 p-4 rounded-2xl">
                  <Smartphone className="h-10 w-10 text-green-600 dark:text-green-400" />
                </div>
                <div>
                  <h2 className="text-2xl font-bold text-gray-900 dark:text-white">تطبيق الأندرويد</h2>
                  <p className="text-gray-500 dark:text-gray-400">لأجهزة Android — تحميل مباشر</p>
                </div>
              </div>
              <ul className="space-y-3 mb-8 text-gray-600 dark:text-gray-300">
                <li className="flex items-center gap-2">
                  <CheckCircle className="h-5 w-5 text-green-500 shrink-0" />
                  تثبيت مباشر بدون متجر
                </li>
                <li className="flex items-center gap-2">
                  <CheckCircle className="h-5 w-5 text-green-500 shrink-0" />
                  إشعارات فورية بالمهام الجديدة
                </li>
              </ul>
              <a
                href={ANDROID_APK_URL}
                download="RozEmp.apk"
                className="mt-auto bg-green-600 hover:bg-green-700 text-white text-lg font-semibold px-8 py-4 rounded-xl transition-colors flex items-center justify-center gap-3"
              >
                <Download className="h-6 w-6" />
                تحميل أندرويد (APK)
              </a>
            </div>

            {/* iPhone */}
            <div className="bg-white dark:bg-gray-800 rounded-2xl shadow-lg hover:shadow-xl transition-shadow p-8 flex flex-col">
              <div className="flex items-center gap-4 mb-6">
                <div className="bg-blue-100 dark:bg-blue-900/30 p-4 rounded-2xl">
                  <Apple className="h-10 w-10 text-blue-600 dark:text-blue-400" />
                </div>
                <div>
                  <h2 className="text-2xl font-bold text-gray-900 dark:text-white">تطبيق الآيفون</h2>
                  <p className="text-gray-500 dark:text-gray-400">لأجهزة iPhone — ملف تعريف</p>
                </div>
              </div>
              <a
                href={IOS_PROFILE_URL}
                className="bg-blue-600 hover:bg-blue-700 text-white text-lg font-semibold px-8 py-4 rounded-xl transition-colors flex items-center justify-center gap-3 mb-6"
              >
                <Download className="h-6 w-6" />
                تحميل آيفون
              </a>
              <div className="bg-blue-50 dark:bg-blue-900/20 rounded-xl p-5">
                <h3 className="font-bold text-gray-900 dark:text-white mb-3 flex items-center gap-2">
                  <Settings className="h-5 w-5 text-blue-600 dark:text-blue-400" />
                  خطوات التثبيت على آيفون
                </h3>
                <ol className="space-y-2 text-gray-700 dark:text-gray-300">
                  {iosSteps.map((step, index) => (
                    <li key={index} className="flex items-start gap-3">
                      <span className="bg-blue-600 text-white rounded-full h-6 w-6 flex items-center justify-center text-sm font-bold shrink-0 mt-0.5">
                        {index + 1}
                      </span>
                      <span>{step}</span>
                    </li>
                  ))}
                </ol>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="py-8 bg-white dark:bg-gray-800 border-t border-gray-100 dark:border-gray-700">
        <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 text-center text-gray-500 dark:text-gray-400">
          <p className="flex items-center justify-center gap-2">
            <Shield className="h-4 w-4" />
            شركة روز لخدمات الانترنت — جميع الحقوق محفوظة {new Date().getFullYear()}
          </p>
        </div>
      </footer>
    </div>
  );
};

export default LandingPage;
