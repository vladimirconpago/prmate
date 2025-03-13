# PRMate 🤝 – Your Friendly PR Generator

**PRMate** is a CLI tool that automatically generates well-structured GitHub pull request descriptions using commit history. It organizes commits by type, scope, and highlights breaking changes, making PR reviews easier and more efficient.

## 🚀 Features

✅ **Intelligent Commit Grouping** – Organizes commits into categories like `✨ Features`, `🐛 Bug Fixes`, and `♲️ Refactoring`.

✅ **Scope-Based Organization** – Groups commits under the relevant feature or module scope.

✅ **Breaking Change Detection** – Clearly highlights commits that contain breaking changes (`BREAKING CHANGE:`).

✅ **Uncategorized Section** – Places commits without a prefix (`feat:`, `fix:`) into a separate 🗑️ "Uncategorized" section.

✅ **Automatic GitHub Links** – Generates direct links to commits in the PR description.

✅ **Dry-Run Mode** – Preview the PR body before submitting.

✅ **Cross-Platform Installation** – Works on **MacOS & Linux** with an easy installer.


---

## 👥 Installation

Run the following command to install **PRMate**:

```sh
 curl -sSL https://raw.githubusercontent.com/vladimirconpago/prmate/master/install.sh | bash
```

Alternatively, clone the repo and run the installer:

```sh
git clone https://github.com/vladimirorg/prmate.git
cd prmate
chmod +x install.sh
./install.sh
```

---

## 🛠️ Usage

### **1️⃣ Create a PR from the current branch**

```sh
prmate
```

This will prompt you for a **Fibery Title** and **Fibery Task Link** before creating the PR.

### **2️⃣ Create a PR from a specific branch**

```sh
prmate -b feature-new-ui
```

### **3️⃣ Preview PR description before submitting**

```sh
prmate --dry-run
```

---

## 🔍 Example PR Description

````
## Description

### egress
- ♲️ [Refactor JWT handling using NestJS](https://github.com/your-org/org-nest-backend/commit/5b17f12)
- ✨ [Add JWT authentication flow](https://github.com/your-org/org-nest-backend/commit/a7c8e3d)

### auth
- ✨ [Implement OAuth login](https://github.com/your-org/org-nest-backend/commit/9f8e2d3)
- 🐛 [Fix session expiration bug](https://github.com/your-org/org-nest-backend/commit/8d7a6c4)

### 🗑️ Uncategorized
- 🗑️ [Fix typo in UI](https://github.com/your-org/org-nest-backend/commit/123abc)

## Fibery Task
https://org.fibery.io/Software_Development/Story/Sync-Care-Appointments-958

## Testing Instructions
```sh
pnpm test
````

```

---

## 📌 Notes
- PRMate assumes you are using **Conventional Commits** (`feat:`, `fix:`, etc.).
- If no commit prefix is found, it will be categorized under **Uncategorized**.
- Works with **GitHub CLI (`gh`)**, ensure you are authenticated (`gh auth login`).

---

## ❤️ Contributing
Want to improve PRMate? Feel free to open an issue or submit a pull request.

---

## 📝 License
MIT License © 2025

```
