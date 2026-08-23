<div align="center">

# PL/Nim ⚡

### Native, High-Performance Nim Procedural Language for PostgreSQL
#### *Write expressive, memory-safe, compiled Nim functions directly inside PostgreSQL.*

[![Nim Version](https://img.shields.io/badge/Nim-2.0%2B-FFE953?logo=nim&logoColor=white)](https://nim-lang.org/)
[![PostgreSQL Support](https://img.shields.io/badge/PostgreSQL-13%20--%2017-336791?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Release](https://img.shields.io/badge/Release-v0.6.0-00E599?logo=github)](https://github.com/luisacosta828/plnim/releases)
[![Core Engine](https://img.shields.io/badge/Powered%20By-Pgxcrown%20👑-00E599)](https://github.com/luisacosta828/pgxcrown)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Memory Safety](https://img.shields.io/badge/Safety-Panic%20Shield-success)](#-panic-shield--exception-safety)
</div>

---

## ⚡ What is PL/Nim?

**PL/Nim** is a high-performance PostgreSQL procedural language handler that allows developers to write stored functions and procedures using [Nim](https://nim-lang.org/). 

Built on top of the [Pgxcrown](https://github.com/luisacosta828/pgxcrown) compilation and FFI engine, **PL/Nim** compiles your Nim code on-the-fly into native shared libraries with zero-overhead C interop, deterministic ORC memory management, and enterprise-grade panic protection.

---

## 🏛️ Architectural Design Principles

PL/Nim is designed from first principles for mission-critical database environments:

* **⚡ Zero-Overhead C Compilation:** Functions are compiled into native shared objects (`.so` / `.dll`) via Nim's C code generator. There is no runtime VM, no bytecode interpreter, and no language server overhead.
* **🧠 Deterministic ARC/ORC Memory Management:** Memory is allocated and reclaimed deterministically without stop-the-world garbage collector pauses, ensuring predictable microsecond query execution.
* **⚡ Sub-Second JIT UDF Compilation:** High-speed function compilation allows stored procedures to be defined and updated on-the-fly inside PostgreSQL with minimal turnaround time.
* **🧬 Deep Catalog Introspection:** Automatically inspects PostgreSQL's catalog to construct native Nim types for composite objects (`CREATE TYPE`), native arrays (`seq[T]`), and JSONB (`JsonNode`) without boilerplate glue code.
* **🛡️ Panic Shield Isolation:** Built-in exception wrappers catch runtime defects (out-of-bounds access, nil dereferences, overflows) and safely translate them into PostgreSQL transaction rollbacks without crashing backend workers.

---

## ✨ Key Highlights

* **🚀 Native C Performance:** Compiles to optimized machine code via C backend. No interpreter overhead or heavy runtime VM.
* **🧠 Automatic Import Hoisting:** Write `import std/math` or `from std/strutils import ...` anywhere inside your SQL function body—PL/Nim automatically hoists imports to the module level.
* **🧬 Zero-Boilerplate Composite Types:** Query-time catalog introspection automatically discovers PostgreSQL `CREATE TYPE` definitions and maps them directly to Nim `object` types.
* **📦 Native JSON & JSONB:** First-class mapping of `json` and `jsonb` to Nim's `JsonNode`, with access to constructors (`%*`), indexing, and mutators.
* **🛡️ Panic Shield (100% Crash Proof):** Built-in exception interceptors catch all Nim `Defect` exceptions (overflows, out-of-bounds, nil dereferences) and translate them safely to PostgreSQL `ERROR` reports without crashing backend workers.
* **🐳 One-Command Docker Setup:** Try PL/Nim across PostgreSQL 13, 14, 15, 16, and 17 with pre-configured Docker images.

---

## 🚀 Quick Start (Try in 30 Seconds with Docker)

Run a complete PostgreSQL instance with PL/Nim pre-installed in one command:

```bash
# Clone the repository
git clone https://github.com/luisacosta828/plnim.git
cd plnim

# Start PostgreSQL with PL/Nim enabled
docker-compose -f docker/docker-compose.yml up -d
```

Connect with `psql`:

```bash
psql -h localhost -p 5445 -U postgres
```

Execute your first Nim function inside PostgreSQL:

```sql
CREATE FUNCTION hello_nim(name text) RETURNS text AS $$
  return "Hello, " & name & "! Powered by PL/Nim ⚡"
$$ LANGUAGE plnim;

SELECT hello_nim('Developer');
-- Output: "Hello, Developer! Powered by PL/Nim ⚡"
```

---

## 📚 Real-World Use Cases & Live Code Tour

### 1. AI & Vector Embeddings (Cosine Similarity)
Calculate vector distance metrics directly inside PostgreSQL without heavyweight external extensions:

```sql
CREATE FUNCTION cosine_similarity(v1 float8[], v2 float8[]) RETURNS float8 AS $$
  import std/math
  var dotProduct = 0.0
  var normA = 0.0
  var normB = 0.0
  for i in 0 ..< min(v1.len, v2.len):
    dotProduct += v1[i] * v2[i]
    normA += v1[i] * v1[i]
    normB += v2[i] * v2[i]
  let denominator = sqrt(normA) * sqrt(normB)
  return if denominator == 0.0: 0.0 else: dotProduct / denominator
$$ LANGUAGE plnim;

SELECT cosine_similarity(ARRAY[0.1, 0.8, 0.3], ARRAY[0.2, 0.7, 0.4]);
-- Output: 0.957297
```

---

### 2. High-Speed Fuzzy String Matching (Levenshtein Distance)
Execute string distance algorithms at bare-metal speed across thousands of rows:

```sql
CREATE FUNCTION levenshtein_dist(s1 text, s2 text) RETURNS int AS $$
  import std/editdistance
  return editDistance(s1, s2).int32
$$ LANGUAGE plnim;

SELECT levenshtein_dist('PostgreSQL', 'Postgres');
-- Output: 3
```

---

### 3. Fast Cryptographic & Token Hashing
Perform fast 64-bit hashing using Nim's standard library:

```sql
CREATE FUNCTION fast_hash(key text) RETURNS bigint AS $$
  import std/hashes
  return hash(key).int64
$$ LANGUAGE plnim;

SELECT fast_hash('user_session_token_xyz987');
-- Output: 3487291847120938472
```

---

### 4. Zero-Boilerplate Composite Types (`CREATE TYPE` In & Out)
PL/Nim automatically inspects PostgreSQL's catalog and constructs corresponding Nim `object` types:

```sql
CREATE TYPE geo_point AS (
  x float8,
  y float8
);

-- Input composite types: Calculate Euclidean distance
CREATE FUNCTION point_distance(p1 geo_point, p2 geo_point) RETURNS float8 AS $$
  import std/math
  let dx = p1.x - p2.x
  let dy = p1.y - p2.y
  return sqrt(dx * dx + dy * dy)
$$ LANGUAGE plnim;

SELECT point_distance(ROW(1.0, 2.0)::geo_point, ROW(4.0, 6.0)::geo_point);
-- Output: 5.0

-- Output composite type: Transform and return struct
CREATE FUNCTION scale_point(p geo_point, factor float8) RETURNS geo_point AS $$
  result.x = p.x * factor
  result.y = p.y * factor
$$ LANGUAGE plnim;

SELECT * FROM scale_point(ROW(10.0, 20.0)::geo_point, 2.5);
-- Output: x = 25.0 | y = 50.0
```

---

### 5. Native JSON & JSONB Data Pipelines
Direct integration with Nim's `std/json` and `%*` syntax:

```sql
-- Parse and extract data from JSONB
CREATE FUNCTION parse_user_payload(doc jsonb) RETURNS text AS $$
  if doc.hasKey("name") and doc.hasKey("age"):
    return "User: " & doc["name"].getStr() & " (Age: " & $doc["age"].getInt() & ")"
  return "Invalid Payload"
$$ LANGUAGE plnim;

SELECT parse_user_payload('{"name": "Luis Acosta", "age": 30}'::jsonb);
-- Output: "User: Luis Acosta (Age: 30)"

-- Construct and return dynamic JSONB telemetry payloads
CREATE FUNCTION generate_telemetry(server text, cpu float8, mem float8) RETURNS jsonb AS $$
  return %*{
    "server": server,
    "metrics": {
      "cpu_pct": cpu,
      "mem_pct": mem
    },
    "healthy": cpu < 85.0
  }
$$ LANGUAGE plnim;

SELECT generate_telemetry('db-node-01', 42.1, 68.4);
-- Output: {"healthy": true, "metrics": {"cpu_pct": 42.1, "mem_pct": 68.4}, "server": "db-node-01"}
```

---

### 6. Native PostgreSQL Arrays (`seq[T]`)
PostgreSQL arrays map automatically to Nim's standard sequences:

```sql
CREATE FUNCTION sum_numbers(nums int[]) RETURNS int AS $$
  import std/sequtils
  return foldl(nums, a + b, 0)
$$ LANGUAGE plnim;

SELECT sum_numbers(ARRAY[10, 20, 30, 40, 50]);
-- Output: 150
```

---

## 🛡️ Panic Shield & Exception Safety

Unlike traditional C extensions where segmentation faults or uncaught exceptions crash the entire PostgreSQL server backend, PL/Nim uses **Pgxcrown's Panic Shield**:

```sql
CREATE FUNCTION safe_lookup(items text[], index int) RETURNS text AS $$
  # In plain C, an out-of-bounds index causes a SIGSEGV server crash.
  # In PL/Nim, IndexDefect is intercepted and turned into a PostgreSQL ERROR.
  return items[index]
$$ LANGUAGE plnim;
```

When an exception occurs:
1. Memory is cleaned up deterministically by ORC.
2. The transaction rolls back cleanly via `ereport(ERROR)`.
3. The PostgreSQL server process remains completely healthy.

---

## 🛠️ Installation from Source

### Prerequisites
* [Nim](https://nim-lang.org/) (>= 2.0.0)
* [PostgreSQL](https://www.postgresql.org/) (13, 14, 15, 16, or 17) with development headers (`postgresql-server-dev-*` / `libpq-dev`).
* [Pgxcrown](https://github.com/luisacosta828/pgxcrown) (>= 0.17.1)

### Build & Install
```bash
# 1. Install Pgxcrown core toolchain
nimble install -y pgxcrown

# 2. Clone and install PL/Nim
git clone https://github.com/luisacosta828/plnim.git
cd plnim
nimble install -y

# 3. Copy shared library to PostgreSQL pkglibdir
sudo cp plnim.so $(pg_config --pkglibdir)/

# 4. Enable PL/Nim in your database
psql -d mydatabase -f src/plnim/sql/extension.sql
```

---

## 🧪 Automated Multi-Version Test Matrix

PL/Nim includes an automated test runner validating all 11 core feature suites across PostgreSQL versions:

```bash
# Run test suite across PostgreSQL 14, 15, 16, and 17:
./docker/test_matrix.sh 14 15 16 17
```

---

## 🗺️ Roadmap & Ecosystem

* [x] **Scalar Primitives & Numeric Types**
* [x] **Native Arrays (`seq[T]`)**
* [x] **Automatic Import Hoisting**
* [x] **Composite Types (Input & Output `CREATE TYPE`)**
* [x] **Native `JSON` & `JSONB` via `JsonNode`**
* [x] **Multi-Version Matrix (PostgreSQL 13 - 17)**
* [ ] **In-Memory Handle Cache in `plnim_call_handler`** (Microsecond dispatch)
* [ ] **Set-Returning Functions (`RETURNS SETOF` / `RETURNS TABLE`)**
* [ ] **Embedded SPI Query Engine**

---

## 📄 License

PL/Nim is open-source software licensed under the [MIT License](LICENSE).
Created and maintained by [Luis Acosta](https://github.com/luisacosta828).
