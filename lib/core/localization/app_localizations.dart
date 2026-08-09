import 'package:flutter/widgets.dart';

class AppLocalizations {
  final Locale locale;

  const AppLocalizations(this.locale);

  static const supportedLocales = [Locale('en'), Locale('ar')];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations(Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  bool get isArabic => locale.languageCode == 'ar';

  String t(String key) {
    final language = isArabic ? _ar : _en;
    return language[key] ?? _en[key] ?? key;
  }

  static const Map<String, String> _en = {
    'settings': 'Settings',
    'language': 'Language',
    'english': 'English',
    'arabic': 'Arabic',
    'app_settings': 'App settings',
    'display_language': 'Display language',
    'display_language_subtitle': 'Choose the language used across the app.',
    'notifications': 'Notifications',
    'push_notifications': 'Push notifications',
    'push_notifications_subtitle':
        'Receive real-time alerts from Firebase Cloud Messaging.',
    'enabled': 'Enabled',
    'disabled': 'Disabled',
    'close': 'Close',
    'save': 'Save',
    'retry': 'Retry',
    'refresh': 'Refresh',
    'sign_out': 'Sign out',
    'startup_failed': 'Startup failed',
    'academy_platform': 'Academy Platform',
    'admin_dashboard': 'Academy - Admin Dashboard',
    'student_portal': 'Academy - Student Portal',
    'teacher_portal': 'Academy - Teacher Portal',
    'parent_portal': 'Academy - Parent Portal',
    'staff_portal': 'Academy - Staff Portal',
    'Overview': 'Overview',
    'Home': 'Home',
    'Branches': 'Branches',
    'Subjects': 'Subjects',
    'Groups': 'Groups',
    'Schedules': 'Schedules',
    'Students': 'Students',
    'Parents': 'Parents',
    'Teachers': 'Teachers',
    'Staff': 'Staff',
    'Curriculum': 'Curriculum',
    'Questions': 'Questions',
    'Homework': 'Homework',
    'Exams': 'Exams',
    'Attendance': 'Attendance',
    'Finance': 'Finance',
    'Security': 'Security',
    'Audit': 'Audit',
    'Replay': 'Replay',
    'Import': 'Import',
    'Settings': 'Settings',
    'Lessons': 'Lessons',
    'Assessments': 'Assessments',
    'Boards': 'Boards',
    'Announcements': 'Announcements',
    'Billing': 'Billing',
    'Account': 'Account',
    'Progress': 'Progress',
    'Payments': 'Payments',
    'Report': 'Report',
    'Teaching': 'Teaching',
    'Academic': 'Academic',
    'Operations': 'Operations',
    'Queues': 'Queues',
    'Academy Suite': 'Academy Suite',
    'Admin operations': 'Admin operations',
    'Student portal': 'Student portal',
    'Teacher Studio': 'Teacher Studio',
    'Teaching workspace': 'Teaching workspace',
    'Operations workspace': 'Operations workspace',
    'Admin': 'Admin',
    'Clear search': 'Clear search',
    'Search': 'Search',
    'Create': 'Create',
    'Edit': 'Edit',
    'Delete': 'Delete',
    'View': 'View',
    'Export': 'Export',
    'Upload': 'Upload',
    'Download': 'Download',
    'Request': 'Request',
    'Submit': 'Submit',
    'Cancel': 'Cancel',
    'Send': 'Send',
    'Acknowledge': 'Acknowledge',
    'Mark read': 'Mark read',
    'Save Profile': 'Save Profile',
    'Update Password': 'Update Password',
    'No lessons available': 'No lessons available',
    'Lessons appear here after your teacher publishes them.':
        'Lessons appear here after your teacher publishes them.',
    'No assessments available': 'No assessments available',
    'Published homework and exams will appear here.':
        'Published homework and exams will appear here.',
    'No attendance records': 'No attendance records',
    'Attendance appears after sessions are marked.':
        'Attendance appears after sessions are marked.',
    'No published boards': 'No published boards',
    'No announcements': 'No announcements',
    'Targeted announcements will appear here.':
        'Targeted announcements will appear here.',
    'No notifications': 'No notifications',
    'Academic and payment alerts will appear here.':
        'Academic and payment alerts will appear here.',
    'No billing records': 'No billing records',
    'Invoices appear here when a subscription is assigned.':
        'Invoices appear here when a subscription is assigned.',
    'No operations data': 'No operations data',
    'Refresh after staff permissions are assigned.':
        'Refresh after staff permissions are assigned.',
    'No linked children': 'No linked children',
    'Ask the academy admin to link your account to a student profile.':
        'Ask the academy admin to link your account to a student profile.',
    'Teacher Portal': 'Teacher Portal',
    'My Teaching Workspaces': 'My Teaching Workspaces',
    'Academic & Content Workspace': 'Academic & Content Workspace',
    'Operations & Grading Workspace': 'Operations & Grading Workspace',
    'Request Leave': 'Request Leave',
    'Session': 'Session',
    'Reason': 'Reason',
    'Answer / notes': 'Answer / notes',
    'Attachment URL': 'Attachment URL',
    'Full name': 'Full name',
    'Phone number': 'Phone number',
    'Avatar image URL': 'Avatar image URL',
    'New password': 'New password',
    'Reviewer note': 'Reviewer note',
    'Notes': 'Notes',
    'Resolution note': 'Resolution note',
    'Class session': 'Class session',
    'Child': 'Child',
  };

  static const Map<String, String> _ar = {
    'settings': 'الإعدادات',
    'language': 'اللغة',
    'english': 'الإنجليزية',
    'arabic': 'العربية',
    'app_settings': 'إعدادات التطبيق',
    'display_language': 'لغة العرض',
    'display_language_subtitle': 'اختر اللغة المستخدمة داخل التطبيق.',
    'notifications': 'الإشعارات',
    'push_notifications': 'إشعارات الهاتف',
    'push_notifications_subtitle':
        'استقبل تنبيهات فورية حقيقية من Firebase Cloud Messaging.',
    'enabled': 'مفعلة',
    'disabled': 'غير مفعلة',
    'close': 'إغلاق',
    'save': 'حفظ',
    'retry': 'إعادة المحاولة',
    'refresh': 'تحديث',
    'sign_out': 'تسجيل الخروج',
    'startup_failed': 'فشل تشغيل التطبيق',
    'academy_platform': 'منصة الأكاديمية',
    'admin_dashboard': 'الأكاديمية - لوحة الإدارة',
    'student_portal': 'الأكاديمية - تطبيق الطالب',
    'teacher_portal': 'الأكاديمية - تطبيق المدرس',
    'parent_portal': 'الأكاديمية - تطبيق ولي الأمر',
    'staff_portal': 'الأكاديمية - تطبيق الموظفين',
    'Overview': 'نظرة عامة',
    'Home': 'الرئيسية',
    'Branches': 'الفروع',
    'Subjects': 'المواد',
    'Groups': 'المجموعات',
    'Schedules': 'الجداول',
    'Students': 'الطلاب',
    'Parents': 'أولياء الأمور',
    'Teachers': 'المدرسون',
    'Staff': 'الموظفون',
    'Curriculum': 'المناهج',
    'Questions': 'الأسئلة',
    'Homework': 'الواجبات',
    'Exams': 'الاختبارات',
    'Attendance': 'الحضور',
    'Finance': 'المالية',
    'Security': 'الصلاحيات',
    'Audit': 'سجل العمليات',
    'Replay': 'إعادة الشرح',
    'Import': 'استيراد',
    'Settings': 'الإعدادات',
    'Lessons': 'الدروس',
    'Assessments': 'التقييمات',
    'Boards': 'البوردات',
    'Announcements': 'الإعلانات',
    'Billing': 'الفواتير',
    'Account': 'الحساب',
    'Progress': 'التقدم',
    'Payments': 'المدفوعات',
    'Report': 'التقرير',
    'Teaching': 'التدريس',
    'Academic': 'الأكاديمي',
    'Operations': 'العمليات',
    'Queues': 'الطوابير',
    'Academy Suite': 'نظام الأكاديمية',
    'Admin operations': 'عمليات الإدارة',
    'Student portal': 'تطبيق الطالب',
    'Teacher Studio': 'استوديو المدرس',
    'Teaching workspace': 'مساحة التدريس',
    'Operations workspace': 'مساحة العمليات',
    'Admin': 'الإدارة',
    'Clear search': 'مسح البحث',
    'Search': 'بحث',
    'Create': 'إنشاء',
    'Edit': 'تعديل',
    'Delete': 'حذف',
    'View': 'عرض',
    'Export': 'تصدير',
    'Upload': 'رفع',
    'Download': 'تحميل',
    'Request': 'طلب',
    'Submit': 'إرسال',
    'Cancel': 'إلغاء',
    'Send': 'إرسال',
    'Acknowledge': 'تأكيد القراءة',
    'Mark read': 'تحديد كمقروء',
    'Save Profile': 'حفظ الملف الشخصي',
    'Update Password': 'تحديث كلمة المرور',
    'No lessons available': 'لا توجد دروس متاحة',
    'Lessons appear here after your teacher publishes them.':
        'ستظهر الدروس هنا بعد أن ينشرها المدرس.',
    'No assessments available': 'لا توجد تقييمات متاحة',
    'Published homework and exams will appear here.':
        'ستظهر الواجبات والاختبارات المنشورة هنا.',
    'No attendance records': 'لا توجد سجلات حضور',
    'Attendance appears after sessions are marked.':
        'يظهر الحضور بعد تسجيله في الحصص.',
    'No published boards': 'لا توجد بوردات منشورة',
    'No announcements': 'لا توجد إعلانات',
    'Targeted announcements will appear here.': 'ستظهر الإعلانات الموجهة هنا.',
    'No notifications': 'لا توجد إشعارات',
    'Academic and payment alerts will appear here.':
        'ستظهر تنبيهات الدراسة والدفع هنا.',
    'No billing records': 'لا توجد سجلات فواتير',
    'Invoices appear here when a subscription is assigned.':
        'ستظهر الفواتير هنا عند إضافة اشتراك.',
    'No operations data': 'لا توجد بيانات عمليات',
    'Refresh after staff permissions are assigned.':
        'حدث الصفحة بعد تعيين صلاحيات الموظف.',
    'No linked children': 'لا يوجد طلاب مرتبطون',
    'Ask the academy admin to link your account to a student profile.':
        'اطلب من إدارة الأكاديمية ربط حسابك بملف الطالب.',
    'Teacher Portal': 'تطبيق المدرس',
    'My Teaching Workspaces': 'مساحات التدريس الخاصة بي',
    'Academic & Content Workspace': 'مساحة المحتوى الأكاديمي',
    'Operations & Grading Workspace': 'مساحة العمليات والتصحيح',
    'Request Leave': 'طلب غياب',
    'Session': 'الحصة',
    'Reason': 'السبب',
    'Answer / notes': 'الإجابة / الملاحظات',
    'Attachment URL': 'رابط المرفق',
    'Full name': 'الاسم الكامل',
    'Phone number': 'رقم الهاتف',
    'Avatar image URL': 'رابط صورة الحساب',
    'New password': 'كلمة المرور الجديدة',
    'Reviewer note': 'ملاحظة المراجع',
    'Notes': 'ملاحظات',
    'Resolution note': 'ملاحظة الحل',
    'Class session': 'الحصة',
    'Child': 'الطالب',
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supported) => supported.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String tr(String key) => AppLocalizations.of(this).t(key);
}
