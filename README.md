# plnim

**Use Nim as a Procedural Language for PostgreSQL**

## Overview

**plnim** is a PostgreSQL language handler that lets you write PostgreSQL functions and procedures in the Nim programming language. Built on top of [pgxcrown](https://github.com/luisacosta828/pgxcrown), plnim brings Nim’s expressive syntax, compile-time safety, and performance to your database logic—right inside Postgres.

---

## Features

### 🚀 Nim-Powered PostgreSQL Functions & Procedures
- Write PostgreSQL functions and procedures directly in Nim.
- Leverage Nim’s static typing and modern programming features for database development.

### 🛡️ Safety & Security by Design
- Built on pgxcrown, plnim enforces the use of safe, pure Nim code:
  - Only allows trusted mode (cannot run in PostgreSQL’s untrusted mode).
  - Functions are pure by design—no heap allocations, no global state, and no side effects.
  - Compile-time checks help prevent common bugs and vulnerabilities.

### 🛠️ Simple and Familiar Workflow
- Easy installation with Nimble and clear setup instructions.
- Automatic type mapping and glue code generation—focus on your logic.

### 🌐 Cross-Platform Support
- Works on Linux, Windows, and WSL (Windows Subsystem for Linux).
- Handles platform-specific deployment details for you.

### 💡 Open Source & Community-Friendly
- MIT Licensed.
- Welcomes issues, discussions, and contributions!

---

## Quick Start

### 1. Install Nim and PostgreSQL

Ensure you have [Nim](https://nim-lang.org/) and PostgreSQL installed.

### 2. Install plnim

```bash
nimble install pgxcrown
nimble install plnim
```

### 3. Register plnim in PostgreSQL

(Setup instructions for enabling `plnim` as a language handler will go here—see documentation or examples.)

### 4. Write Nim Functions and Procedures

```sql
CREATE FUNCTION nim_add_one(a integer) RETURNS integer
AS $$
  return a + 1
$$ LANGUAGE plnim;

SELECT nim_add_one(10); -- returns 11
```

---

## Security & Safety

- **Pure Functions:** By enforcing Nim’s `func` (pure procedure) discipline, plnim prevents unsafe operations, memory leaks, and other vulnerabilities.
- **Strict PostgreSQL Integration:** Functions are registered as `STRICT` for safe handling of NULLs and argument validation.

---

## Contributing

Pull requests, issues, and feedback are welcome! Please open an issue to discuss any major changes before submitting a PR. Contributions should be well-tested.

---

## License

[MIT](https://choosealicense.com/licenses/mit/)
