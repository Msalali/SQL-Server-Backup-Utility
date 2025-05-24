# SQL Server Backup & LogFile Script

PowerShell script to **backup a SQL Server database**, generate a **LogFile of database size and objects**, verify the backup, and export a **log file** with detailed information.

## 📋 Features

- Connects to SQL Server using **Windows Authentication** or **SQL Server Login**.
- Executes the stored procedure `dbo.GetDatabaseSizeReport` to collect database object sizes.
- Creates a `.bak` backup file of the specified database.
- Verifies backup integrity using `RESTORE VERIFYONLY`.
- Generates a log file (`.txt`) containing:
  - SQL Server version, edition, and level
  - Object size LogFile (tables, indexes, total size, etc.)
  - Backup status, size, and verification result
- Automatically installs the `SqlServer` PowerShell module if it's not already available.

---

## 🛠️ How to Use

### 1. Open PowerShell as Administrator

(Optional but recommended for module installation)

Set execution policy for the session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
```

### 2. Run the Script

Execute the script:

```powershell
CD Path dirctory script
.\backup_script.ps1
```

You will be prompted to enter the following:

- **Server Name** (e.g., `localhost`, `127.0.0.1`, or `ServerName\Instance`)
- **Database Name** to back up
- **Backup Folder Path** (where `.bak` and `.txt` files will be saved)
- **Authentication Method**: Press `Y` for Windows Authentication or `N` for SQL Login (will prompt for credentials)

---

## 📄 Output

Two files will be generated in the specified directory:

1. **Database Backup File**  
   Format: `YourDatabase_Backup_yyyyMMdd_HHmmss.bak`

2. **Log LogFile File**  
   Format: `LogFileBackup_YourDatabase_yyyyMMdd_HHmmss.txt`  
   Includes:
   - SQL Server details
   - Table/index/object sizes
   - Backup file size and verification status
   - Timestamp and execution notes

---

## 📌 Requirements

- PowerShell 5.1 or newer
- `SqlServer` module (installed automatically if missing)
- Stored Procedure `dbo.GetDatabaseSizeReport` must exist in the target database  


---

## ✅ Example Output in Log File

```text
SQL Server Info:-
 - Version        : 15.0.2000.5
 - Edition        : Developer Edition
 - Product Level  : RTM

--------------------------------------------
Objects Include:-
Database_Name Date_Report Object_Name  Object_Type Total_Rows Size (MB)
------------- ------------ ------------ ------------ ----------- ----------
MyDB          2025-05-18   Customers     Table        100000     25.3
MyDB          2025-05-18   Orders        Table        250000     47.9
MyDB          2025-05-18   DB Total      DB Total     N/A        73.2

--------------------------------------------
Backup Info:-
 - Backup Date    : 2025-05-18 15:30:21
 - Backup Size    : 75.65 MB
 - Status         : Completed
 - Verify Status  : Passed

--------------------------------------------
Dev Script By Meshary alali (:
--------------------------------------------
```



---

## 👨‍💻 Devloper

****  

 [Meshary Alali](https://github.com/msalali)

 [LICENSE](https://github.com/Msalali/BackupScript/blob/main/LICENSE)

---




# سكربت النسخ الاحتياطي المتقدم لقاعدة بيانات SQL Server

سكريبت PowerShell يقوم بعمل **نسخة احتياطية لقاعدة بيانات SQL Server**، ويولّد **تقريرًا بحجم الكائنات داخل القاعدة**، ويتحقق من صحة النسخة، ويولّد **ملف سجل** يحتوي على كافة التفاصيل.

## 📋 الميزات

- الاتصال بـ SQL Server باستخدام **مصادقة ويندوز** أو **تسجيل دخول SQL Server**.
- تنفيذ الإجراء المخزن `dbo.GetDatabaseSizeReport` لاستخراج أحجام الكائنات.
- إنشاء ملف نسخة احتياطية بامتداد `.bak`.
- التحقق من صحة النسخة الاحتياطية باستخدام `RESTORE VERIFYONLY`.
- توليد ملف سجل (`.txt`) يحتوي على:
  - إصدار SQL Server والمستوى والنوع
  - تقرير تفصيلي عن الكائنات (جداول، فهارس، الحجم الإجمالي، ...)
  - حالة النسخ وحجم الملف ونتيجة التحقق
- تثبيت وحدة PowerShell `SqlServer` تلقائيًا في حال عدم توفرها.

---

## 🛠️ طريقة الاستخدام

### 1. افتح PowerShell كمسؤول

(اختياري لكن يُفضل لتفادي مشاكل التصاريح)

قم بتعيين سياسة التنفيذ للجلسة:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
```

### 2. تشغيل السكربت

قم بتشغيل السكربت:

```powershell
CD Path dirctory script
.\backup_script.ps1

```

سيُطلب منك إدخال ما يلي:

- **اسم الخادم** (مثل: `localhost` أو `127.0.0.1` أو `ServerName\Instance`)
- **اسم قاعدة البيانات** التي ترغب بعمل نسخة احتياطية لها
- **مسار حفظ النسخة** (حيث سيتم حفظ ملفات `.bak` و`.txt`)
- **طريقة المصادقة**: اضغط `Y` لاستخدام مصادقة ويندوز أو `N` لاستخدام تسجيل دخول SQL (وسيطلب منك بيانات الدخول)

---

## 📄 الملفات الناتجة

يتم إنشاء ملفين في المسار الذي حددته:

1. **ملف النسخة الاحتياطية**  
   الصيغة: `YourDatabase_Backup_yyyyMMdd_HHmmss.bak`

2. **ملف السجل النصي**  
   الصيغة: `LogFileBackup_YourDatabase_yyyyMMdd_HHmmss.txt`  
   يحتوي على:
   - تفاصيل SQL Server
   - تقرير حجم الكائنات
   - حجم النسخة وحالة التحقق
   - الوقت وتفاصيل التشغيل

---

## 📌 المتطلبات

- PowerShell 5.1 أو أحدث
- وحدة `SqlServer` (يتم تثبيتها تلقائيًا إن لم تكن متوفرة)
- الإجراء المخزن `dbo.GetDatabaseSizeReport` يجب أن يكون موجودًا داخل قاعدة البيانات  

---

## ✅ مثال على الإخراج داخل ملف السجل

```text
SQL Server Info:-
 - Version        : 15.0.2000.5
 - Edition        : Developer Edition
 - Product Level  : RTM

--------------------------------------------
Objects Include:-
Database_Name Date_Report Object_Name  Object_Type Total_Rows Size (MB)
------------- ------------ ------------ ------------ ----------- ----------
MyDB          2025-05-18   Customers     Table        100000     25.3
MyDB          2025-05-18   Orders        Table        250000     47.9
MyDB          2025-05-18   DB Total      DB Total     N/A        73.2

--------------------------------------------
Backup Info:-
 - Backup Date    : 2025-05-18 15:30:21
 - Backup Size    : 75.65 MB
 - Status         : Completed
 - Verify Status  : Passed

--------------------------------------------
Dev Script By Meshary alali (:
--------------------------------------------
```

---

## 👨‍💻 المطور


 [مشاري العلي](https://github.com/msalali)

[الترخيص](https://github.com/Msalali/BackupScript/blob/main/LICENSE)

---



