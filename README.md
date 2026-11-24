<div align="center">

# CMD Uni

**مخطط جامعي شخصي**

A personal university planner for Android

`v0.1.0` · Android 7.0+ · no internet permission · no account, no server

</div>

> **Status: first release, NOT yet tested on a physical device.** Screenshots in the PDFs are automated UI test renders with demo data, not device screenshots.

## Download

Open the release page and pick **`cmd-uni-0.1.0-arm64-v8a.apk`** for most phones (`armeabi-v7a` for older 32-bit phones, `x86_64` for emulators):

**https://github.com/moh500600/cmd-uni/releases/tag/v0.1.0**

SHA-256 of the arm64-v8a file:

```
5b54c091f5822380021e672b8808ba22e1242e8a191a67cd41814eafa338c390
```

Android will ask you to allow installing from an unknown source. The APK is signed with a new CMD key made for this app.

## Documents

- [Visual README (PDF, 4 pages)](docs/CMD-Uni-README-visual.pdf)
- [Showcase (PDF, 5 pages, 16:9)](docs/CMD-Uni-Showcase.pdf)

## ما هو التطبيق

- **الجدول** (Timetable): محاضرات الأسبوع مع القاعات وكشف التعارض.
- **الواجبات والاختبارات** (Assignments & exams): مواعيد وتنبيهات وحالة كل واجب واختبار.
- **المعدل والدرجات** (GPA & grades): دفتر درجات وحساب المعدل الفصلي والتراكمي.
- **الحضور** (Attendance): تسجيل الغياب مع تنبيه عند الاقتراب من الحد.
- **المشاريع والملاحظات** (Projects & notes): مشاريع بمهام ومراجع وملاحظات لكل مقرر.
- **المذاكرة** (Study timer): مؤقت بومودورو وتحليلات للوقت المنجز.
- **المشاركة بملف** (Share by file): تصدير بياناتك لملف JSON وإرساله بأي تطبيق، والطرف الآخر يستورده ويدمجه.
- **النسخ الاحتياطي** (Backup): حفظ واستعادة ملف نسخة احتياطية من نفس الجهاز.

## What it does

- **Timetable**
- **Assignments & exams**
- **GPA & grades**
- **Attendance**
- **Projects & notes**
- **Study timer**
- **Share by file**
- **Backup**

## Privacy and limits

- All data lives in a database on your phone. The release manifest has no INTERNET permission, there is no cloud account, no backend and no hosted AI.
- المجموعات المباشرة والمساعد الذكي والمزامنة السحابية أُزيلت. المشاركة صارت بملف يدوي.
- It installs **next to** the old app (new package id `com.cmdapps.uni`). It does not replace it and does not move data automatically. Old server data was not touched.
- Sharing between people is done by exporting a file and importing it on the other phone.
- Deleting the app or its data deletes your data. Keep a backup file.
- Not tested on a physical device yet. Report problems in the repository issues.

## Build

Flutter project. CI (`.github/workflows/android.yml`) runs analyze, tests and a release build. The APKs in the release were re-signed locally with the CMD key.

## License

No license has been chosen yet.
