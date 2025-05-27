# Delphi Logical Record Locking Solution

[![Delphi](https://img.shields.io/badge/Language-Delphi-blue.svg?style=flat&logo=delphi)](https://www.embarcadero.com/products/delphi)
[![Logical Locking](https://img.shields.io/badge/Concept-Logical%20Locking-orange.svg?style=flat)](https://en.wikipedia.org/wiki/Concurrency_control#Locking)
[![Database](https://img.shields.io/badge/Type-Database%20Solution-red.svg?style=flat)](https://en.wikipedia.org/wiki/Database)
[![Concurrency Control](https://img.shields.io/badge/Feature-Concurrency%20Control-brightgreen.svg?style=flat)](https://en.wikipedia.org/wiki/Concurrency_control)

This repository presents a robust **Delphi solution for implementing logical record locking**, designed to enhance data integrity and prevent concurrent modifications in multi-user environments, particularly within legacy web applications or systems relying on `TDataSet` components.

---

## 🛑 The Challenge of Data Integrity in Enterprise Applications

In enterprise applications, multiple users often need to access and modify the same data simultaneously. This concurrent access, while necessary for business operations, poses a significant challenge: **maintaining data integrity**. Without proper mechanisms, two or more users could try to edit the same record at the same time, leading to lost updates, inconsistent data, or even application crashes.

Imagine a scenario where two sales representatives are trying to update the stock quantity for the same product. If both read the current stock, deduct their sale, and then write the new quantity back, the last one to save their changes will overwrite the other's update. This results in an inaccurate stock count and potentially unfulfilled orders.

To prevent such issues, applications employ **concurrency control mechanisms**. While databases offer physical locking (e.g., row-level locks), these can sometimes be too restrictive or unsuitable for certain application architectures, especially in distributed or web-based systems where user interactions might span long periods. This is where **logical locking** comes into play. It's an application-level strategy that allows you to manage access to records based on your specific business rules, providing a more flexible and often more user-friendly approach to concurrency.

---

## 💡 How This Logical Locking Algorithm Works

The core of this logical locking mechanism revolves around a dedicated **lock table** in your database. When a user attempts to acquire a lock on a record, the system follows a precise set of rules to determine if the lock can be granted, ensuring data consistency and providing intelligent handling of concurrent access:

1.  **Initial Lock Acquisition**: A user can acquire a logical lock on a record if:
    * There is **no existing entry** for that record in the lock table (i.e., the record has never been locked before).
    * The **user's current session is the one that previously held the lock**, regardless of whether that previous lock has expired. This ensures that a user can safely re-acquire a lock on data they were already working on, preventing them from being locked out of their own work.

2.  **Timeout and Read-Only State**: If the lock acquisition attempt does not conclude successfully within a configurable **timeout period**, the system considers the operation failed, and the data is returned to the user in a **read-only state**. This prevents indefinite waiting and allows the application to remain responsive, informing the user that the record is currently unavailable for modification.

3.  **Controlled Takeover (Takeover Logic)**: If the session attempting to acquire the lock is *different* from the one that currently holds the (potentially expired) lock, a **takeover is only permitted if the last logical lock expired *before* the timestamp when the current user read the data**. This crucial rule guarantees that the user always works with the absolute latest version of the data. If the previous lock expired *after* the data was read, it implies another user might have been actively working on it more recently, and a takeover would risk overwriting newer changes. By checking the `ReadTimeStamp` against the `Expiration` time of the last lock, we ensure the user is seeing the most up-to-date information before they're allowed to modify it.

This algorithm strikes a balance between strict concurrency control and user experience, allowing for flexible access while strongly prioritizing **data integrity**.

---

## 💻 Code Overview

The solution is encapsulated within the `uRecordLockHelper` unit, providing interfaces and classes for managing record locks.

### Key Components:

* **`IRecordLock` & `IRecordLockVS`**: Base interfaces defining the fundamental capabilities for record locking, including properties for granular control like `RecordLockRequired`, `AllowLockTakeover`, and `ReadTimeStamp`.
* **`IDataSetRecordLockVS` & `IXMLRecordLockVS`**: Specialized interfaces for acquiring locks from `TDataSet` components or `IXMLNode` (e.g., XML payloads), providing flexibility in data source integration.
* **`IRecordLockProc`**: Interface for the back-end implementation of locking and unlocking procedures.
* **`TRecordLockTable`**: A record structure defining the schema for the dedicated logical lock table in your database.
* **`TLockInfo`**: A class to store the current lock status, including who locked it and when it expires.
* **`IRecordIDsLoader`**: An interface for loading record identifiers from various sources, with concrete implementations for `TDataSet` (`TRecordIDsLoaderDataSet`) and `IXMLNode` (`TRecordIDsLoaderXMLNode`).
* **`TRecordLockHelper`**: The main class that orchestrates the logical lock operations, interacting with the database to apply and release locks based on the defined algorithm. It primarily uses **`TADOQuery`** for database interactions and leverages SQL `MERGE` statements (or equivalent) for atomic lock acquisition and update.

### Core Logic (`TRecordLockHelper.Lock` and `TRecordLockHelper.Unlock`):

The `Lock` procedure implements the complex logic for acquiring a lock, utilizing parameterized SQL queries to:
* Check for existing locks.
* Apply the "same session" or "takeover" rules.
* Update lock metadata (session ID, username, lock time, expiration).
* Raise an error if the lock cannot be acquired due to concurrent access.

The `Unlock` procedure simply sets the expiration time of the lock to `Now`, effectively releasing it and allowing other sessions to acquire it based on the takeover rules.

### Thread Safety and Optimization:

* **`TCriticalSection`**: Used to ensure thread-safe access to internal lists (`rlList`) when managing `TRecordLockHelper` class aliases, crucial in multi-threaded environments.
* **`OptimizeLockTable`**: A class procedure designed to clean up expired locks from the lock table. This operation includes a `WARNING` regarding potential lock escalation on large tables, suggesting execution during off-peak hours and utilizing `ALTER INDEX ... REORGANIZE` for performance.

---

## 🚀 Getting Started

To integrate this solution into your Delphi project:

1.  **Define your Lock Table**: Ensure your database includes a table that matches the structure defined in `TRecordLockTable` (e.g., `RECORD_LOCKS` with fields like `RL_ID`, `SESSION_ID`, `RECORD_ID`, `USERNAME`, `TIME`, `EXPIRATION`, `ENTITY`).
2.  **Integrate `TYourFrameworkBaseClass` and `TYourFrameworkSessionClass`**: Replace these placeholders with your actual base class and session management class, as the `TRecordLockHelper` relies on your application's connection and session context.
3.  **Utilize `AcquireLock` and `ReleaseLock`**: Call the appropriate `AcquireLock` and `ReleaseLock` methods from your application logic when working with records that require concurrency control.

---

## 🤝 Contribution

Feel free to explore, use, and provide feedback on this solution. If you have suggestions for improvements or encounter issues, please open an issue or pull request.