<div align="center">
  <img src="assets/branding/brivio_icon.png" alt="Brivio Logo" width="120" />

  # Brivio - Modern Academy Management ERP

  **A comprehensive, scalable, and secure educational platform built with Flutter and Supabase.**

  [![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev/)
  [![Dart](https://img.shields.io/badge/Dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev/)
  [![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com/)
  [![Firebase](https://img.shields.io/badge/firebase-%23039BE5.svg?style=for-the-badge&logo=firebase)](https://firebase.google.com/)
</div>

---

## 📖 Overview

**Brivio** is an enterprise-grade Educational Resource Planning (ERP) application designed to streamline academy and school management. It provides dedicated, role-based portals for **Admins, Staff, Teachers, Students, and Parents**, seamlessly connecting all stakeholders in the educational ecosystem.

Built on a robust, feature-driven Clean Architecture, Brivio leverages **Flutter** for a beautiful cross-platform UI and **Supabase** for a scalable, real-time backend. 

---

## ✨ Key Features

Brivio is packed with features distributed across multiple domains, ensuring every user role has the precise tools they need.

### 🎭 Role-Based Portals
*   **👨‍💼 Admin Portal**: Comprehensive oversight of the academy. Manage RBAC (Role-Based Access Control), audit logs, global settings, branches, and high-level reports.
*   **👩‍🏫 Teacher Portal**: Manage curriculums, grade homework, track attendance, and communicate directly with students and parents.
*   **🎓 Student Portal**: Interactive study workspace (Sandbox), real-time schedule, assignment submissions, grades, and academy announcements.
*   **👪 Parent Portal**: Monitor child's academic progress, attendance history, view and pay invoices, and communicate with teachers.
*   **💼 Staff Portal**: Unified operations workspace. Handle leave requests, attendance exceptions, payment follow-ups, and enrollments.

### 🧩 Core Modules
*   **🏫 Academy Core**: Manage branches, groups, subjects, and complex scheduling.
*   **💳 Finance & Payments**: Track invoices, process fee collections, generate receipts, and monitor staff finances.
*   **✅ Attendance Tracking**: Real-time attendance logging via manual entry or QR code scanning (`mobile_scanner`).
*   **💬 Communication & Chat**: Secure, real-time chat threads, broadcast announcements, and push notifications (`firebase_messaging`).
*   **📚 Curriculum & Homework**: Rich curriculum builder/editor, homework assignments, and a dedicated grading interface.
*   **🎫 Helpdesk**: Integrated support ticket system for students and parents to reach academy staff.
*   **📊 Reports & Analytics**: Interactive dashboards for attendance trends, financial health, and academic performance.
*   **🔒 Security & RBAC**: Granular permission system, biometric authentication (`local_auth`), and strict audit logging.

---

## 🏗 Architecture & Tech Stack

Brivio follows a **Feature-Driven, Modular Architecture** inspired by Clean Architecture principles. This ensures that the codebase remains maintainable, testable, and scalable as the platform grows.

### Tech Stack
*   **UI Framework**: [Flutter](https://flutter.dev/) (Material Design 3 & Custom Design System)
*   **Backend / BaaS**: [Supabase](https://supabase.com/) (PostgreSQL, Auth, Storage, Edge Functions)
*   **State Management**: `flutter_riverpod` + `provider`
*   **Dependency Injection**: `get_it`
*   **Local Storage**: `hive`, `flutter_secure_storage`, `shared_preferences`
*   **Media & Files**: `video_player`, `pdfrx`, `mobile_scanner`, `printing`
*   **Push Notifications**: Firebase Cloud Messaging (FCM) via `firebase_messaging`

### Directory Structure
```text
lib/
├── apps/               # Entry points and Dashboards for each role (admin, student, etc.)
├── core/               # Cross-cutting concerns (DI, Network, Localization, Settings, Security)
├── design_system/      # Custom UI Tokens (Colors, Typography) and Reusable Components
└── features/           # Independent Feature Modules
    ├── academy/        # Branches, Groups, Subjects, Schedules
    ├── attendance/     # QR and Manual Check-ins
    ├── auth/           # Login, Biometrics, Session Management
    ├── communication/  # Chat, Announcements, Notifications
    ├── curriculum/     # Course Materials, Syllabus Editor
    ├── helpdesk/       # Ticketing System
    ├── parent_portal/  # Parent-specific views and data logic
    ├── payments/       # Invoicing, Receipts, Financial Dashboards
    ├── people/         # User Profiles (Teachers, Students, Staff)
    ├── reports/        # Analytics and Data Visualization
    ├── security/       # RBAC and Audit Logs
    ├── study_workspace/# Interactive Student Sandbox
    └── teacher_homework/# Homework Creation and Grading
```

---

## 🎨 Custom Design System

Brivio does not rely solely on default Material widgets. It utilizes a highly customized **Design System** located in `lib/design_system/`.
*   **Design Tokens**: Strict definitions for `AppColors`, `AppTypography`, and spacing.
*   **Portal Components**: Reusable widgets like `PortalScaffold`, `PortalHeader`, `PortalMetricCard`, and `PortalSearchField` ensure a consistent UI across all 5 user roles.
*   **Theme**: Comprehensive Light and Dark mode support built-in.

---

## 🚀 Getting Started

### Prerequisites
1.  **Flutter SDK**: `>=3.12.2`
2.  **Supabase Project**: You need an active Supabase project for the backend.
3.  **Firebase Project**: (Optional but recommended) for Push Notifications.

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/brivio.git
   cd brivio
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Environment Variables**
   Create a `.env` file (or use your preferred config management) and add your Supabase credentials:
   ```env
   SUPABASE_URL=your_supabase_project_url
   SUPABASE_ANON_KEY=your_supabase_anon_key
   ```

4. **Run the App**
   ```bash
   flutter run
   ```

---

## 🛠 Backend (Supabase) Setup

The project includes backend configuration files and scripts.
1. Navigate to the `supabase/` directory.
2. Apply the necessary schema, tables, and RPC functions to your Supabase instance using Supabase CLI.
3. Ensure Row Level Security (RLS) policies match the expected RBAC permissions in `Permission` enum (`lib/core/security/permission.dart`).

---

## 🛡️ Security

*   **Biometric Login**: Supports Fingerprint/FaceID via `local_auth`.
*   **Secure Storage**: JWT tokens and sensitive session data are encrypted using `flutter_secure_storage`.
*   **Granular Permissions**: Every action is verified against a strict `UserRole` and `Permission` mapping.

---

## 📄 License

This project is proprietary and confidential. Unauthorized copying of this file, via any medium, is strictly prohibited.
