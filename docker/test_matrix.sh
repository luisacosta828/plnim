#!/usr/bin/env bash
set -e

VERSIONS=${@:-"14 15 16 17"}
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=============================================================================="
echo "👑 PL/Nim & Pgxcrown Multi-Version PostgreSQL Feature Compatibility Matrix"
echo "Target PostgreSQL Versions: $VERSIONS"
echo "=============================================================================="

for V in $VERSIONS; do
  echo ""
  echo "=============================================================================="
  echo "🚀 [PostgreSQL $V] Building container image..."
  echo "=============================================================================="
  
  TAG="plnim-test-pg${V}"
  CONTAINER="plnim_test_runner_pg${V}"
  
  docker build --build-arg PG_VERSION="${V}" -t "${TAG}" -f "${ROOT_DIR}/docker/Dockerfile" "${ROOT_DIR}"
  
  docker rm -f "${CONTAINER}" 2>/dev/null || true
  
  echo "📦 [PostgreSQL $V] Starting container on port 543${V}..."
  docker run -d --name "${CONTAINER}" -e POSTGRES_PASSWORD=postgres -p "543${V}:5432" "${TAG}"
  
  echo "⏳ [PostgreSQL $V] Waiting for database to accept connections..."
  until docker exec "${CONTAINER}" pg_isready -U postgres >/dev/null 2>&1; do
    sleep 1
  done
  
  echo "🧪 [PostgreSQL $V] Executing Feature-by-Feature Test Suite..."
  docker exec -i "${CONTAINER}" psql -U postgres -v ON_ERROR_STOP=1 << 'EOSQL'
    \timing on

    -- -------------------------------------------------------------------------
    -- FEATURE 1: Primitives & Arithmetic (int4, int8, float8)
    -- -------------------------------------------------------------------------
    CREATE FUNCTION fn_feat1_primitives(a int, b int8, x float8) RETURNS float8 AS $$
      return a.float64 + b.float64 + x
    $$ LANGUAGE plnim;

    SELECT fn_feat1_primitives(10, 20::int8, 3.5) AS "Feature 1 (Primitives)";

    -- -------------------------------------------------------------------------
    -- FEATURE 2: Strings & Text Manipulation
    -- -------------------------------------------------------------------------
    CREATE FUNCTION fn_feat2_strings(greeting text, name text) RETURNS text AS $$
      return greeting & ", " & name & "! Welcome to PL/Nim."
    $$ LANGUAGE plnim;

    SELECT fn_feat2_strings('Hello', 'Luis') AS "Feature 2 (Strings)";

    -- -------------------------------------------------------------------------
    -- FEATURE 3: Booleans & Conditionals
    -- -------------------------------------------------------------------------
    CREATE FUNCTION fn_feat3_boolean(age int) RETURNS bool AS $$
      return age >= 18
    $$ LANGUAGE plnim;

    SELECT fn_feat3_boolean(25) AS "Feature 3 (Adult: True)", fn_feat3_boolean(15) AS "Feature 3 (Minor: False)";

    -- -------------------------------------------------------------------------
    -- FEATURE 4: Standard Library Import Hoisting
    -- -------------------------------------------------------------------------
    CREATE FUNCTION fn_feat4_imports(angle float8, raw_msg text) RETURNS text AS $$
      import std/math
      from std/strutils import toUpperAscii
      let sinVal = sin(angle)
      return toUpperAscii(raw_msg) & " | SIN=" & $sinVal
    $$ LANGUAGE plnim;

    SELECT fn_feat4_imports(1.5707963267948966, 'trig calculation') AS "Feature 4 (Imports)";

    -- -------------------------------------------------------------------------
    -- FEATURE 5: Native PostgreSQL Arrays (int[] -> seq[int32], text[] -> seq[string])
    -- -------------------------------------------------------------------------
    CREATE FUNCTION fn_feat5_arrays(numbers int[], words text[]) RETURNS text AS $$
      import std/[sequtils, strutils]
      let total = foldl(numbers, a + b, 0)
      let joined = words.join(" + ")
      return joined & " = " & $total
    $$ LANGUAGE plnim;

    SELECT fn_feat5_arrays(ARRAY[10, 20, 30], ARRAY['ten', 'twenty', 'thirty']) AS "Feature 5 (Arrays)";

    -- -------------------------------------------------------------------------
    -- FEATURE 6: Composite Types as Return Value (CREATE TYPE Output)
    -- -------------------------------------------------------------------------
    CREATE TYPE calc_stats AS (
      sum_val int,
      count_val int,
      avg_val float8
    );

    CREATE FUNCTION fn_feat6_composite_return(nums int[]) RETURNS calc_stats AS $$
      import std/sequtils
      result.sum_val = foldl(nums, a + b, 0)
      result.count_val = nums.len.int32
      result.avg_val = if nums.len > 0: result.sum_val.float64 / nums.len.float64 else: 0.0
    $$ LANGUAGE plnim;

    SELECT * FROM fn_feat6_composite_return(ARRAY[10, 20, 30, 40, 50]);

    -- -------------------------------------------------------------------------
    -- FEATURE 7: Composite Types as Input Arguments (CREATE TYPE Input)
    -- -------------------------------------------------------------------------
    CREATE TYPE geo_point AS (
      x float8,
      y float8
    );

    CREATE FUNCTION fn_feat7_composite_input(p1 geo_point, p2 geo_point) RETURNS float8 AS $$
      import std/math
      let dx = p1.x - p2.x
      let dy = p1.y - p2.y
      return sqrt(dx * dx + dy * dy)
    $$ LANGUAGE plnim;

    SELECT fn_feat7_composite_input(ROW(0.0, 0.0)::geo_point, ROW(3.0, 4.0)::geo_point) AS "Feature 7 (Composite Input Distance)";

    -- -------------------------------------------------------------------------
    -- FEATURE 8: Composite Types as Both Input and Output (Transformation)
    -- -------------------------------------------------------------------------
    CREATE FUNCTION fn_feat8_composite_transform(p geo_point, factor float8) RETURNS geo_point AS $$
      result.x = p.x * factor
      result.y = p.y * factor
    $$ LANGUAGE plnim;

    SELECT * FROM fn_feat8_composite_transform(ROW(10.0, 20.0)::geo_point, 2.5);

    -- -------------------------------------------------------------------------
    -- FEATURE 9: JSONB Payload Reading & Extraction
    -- -------------------------------------------------------------------------
    CREATE FUNCTION fn_feat9_jsonb_read(doc jsonb) RETURNS text AS $$
      if doc.hasKey("user") and doc.hasKey("score"):
        return "Player: " & doc["user"].getStr() & " (Score: " & $doc["score"].getInt() & ")"
      return "Invalid Payload"
    $$ LANGUAGE plnim;

    SELECT fn_feat9_jsonb_read('{"user": "luis", "score": 9500}'::jsonb) AS "Feature 9 (JSONB Read)";

    -- -------------------------------------------------------------------------
    -- FEATURE 10: JSONB Generation & Mutation
    -- -------------------------------------------------------------------------
    CREATE FUNCTION fn_feat10_jsonb_write(service text, port int, active bool) RETURNS jsonb AS $$
      return %*{
        "service_name": service,
        "port": port,
        "active": active,
        "meta": {
          "framework": "pgxcrown",
          "language": "plnim"
        }
      }
    $$ LANGUAGE plnim;

    SELECT fn_feat10_jsonb_write('auth-gateway', 8080, true) AS "Feature 10 (JSONB Generation)";

    -- -------------------------------------------------------------------------
    -- FEATURE 11: Exception Handling & Defensive Guard
    -- -------------------------------------------------------------------------
    CREATE FUNCTION fn_feat11_safe_division(a float8, b float8) RETURNS text AS $$
      if b == 0.0:
        return "Error: Division by zero avoided safely"
      return "Result: " & $(a / b)
    $$ LANGUAGE plnim;

    SELECT fn_feat11_safe_division(10.0, 2.0) AS "Feature 11 (Safe Div)", fn_feat11_safe_division(10.0, 0.0) AS "Feature 11 (Zero Div Guard)";

    -- -------------------------------------------------------------------------
    -- FEATURE 12: Set-Returning Scalar Functions (RETURNS SETOF text)
    -- -------------------------------------------------------------------------
    CREATE FUNCTION fn_feat12_list_fruits() RETURNS SETOF text AS $$
      return @["Apple", "Banana", "Cherry", "Dragonfruit"]
    $$ LANGUAGE plnim;

    SELECT * FROM fn_feat12_list_fruits();

    -- -------------------------------------------------------------------------
    -- FEATURE 13: Set-Returning Composite Functions (RETURNS SETOF composite_type)
    -- -------------------------------------------------------------------------
    CREATE FUNCTION fn_feat13_generate_grid(n int) RETURNS SETOF geo_point AS $$
      var res: seq[Geo_point] = @[]
      for i in 1 .. n:
        res.add(Geo_point(x: i.float64, y: (i * 2).float64))
      return res
    $$ LANGUAGE plnim;

    SELECT * FROM fn_feat13_generate_grid(3);

    -- -------------------------------------------------------------------------
    -- FEATURE 14: SPI Fluent Scalar Aggregation (fetchScalar)
    -- -------------------------------------------------------------------------
    CREATE TABLE IF NOT EXISTS tbl_staff (id serial, name text, dept text, salary float8);
    TRUNCATE tbl_staff;
    INSERT INTO tbl_staff (name, dept, salary) VALUES
      ('Alice', 'Engineering', 95000.0),
      ('Bob', 'Sales', 60000.0),
      ('Charlie', 'Engineering', 105000.0);

    CREATE FUNCTION fn_feat14_eng_payroll() RETURNS float8 AS $$
      let s = table("tbl_staff", "s")
      return fetchScalar[float64](
        Select(sum(s.salary))
          .From(s)
          .Where(s.dept == "Engineering")
      )
    $$ LANGUAGE plnim;

    SELECT fn_feat14_eng_payroll() AS "Feature 14 (SPI Fluent Scalar)";

    -- -------------------------------------------------------------------------
    -- FEATURE 15: SPI Fluent Row Query (fetchRows)
    -- -------------------------------------------------------------------------
    CREATE FUNCTION fn_feat15_dept_summary() RETURNS jsonb AS $$
      let s = table("tbl_staff", "s")
      let rows = fetchRows(
        Select(s.dept as "dept_name", count(s.id) as "headcount")
          .From(s)
          .GroupBy(s.dept)
          .OrderBy(s.dept)
      )
      var res = newJObject()
      for r in rows:
        res[r["dept_name"]] = %*(r["headcount"].parseInt)
      return res
    $$ LANGUAGE plnim;

    SELECT fn_feat15_dept_summary() AS "Feature 15 (SPI Fluent Rows)";

    -- -------------------------------------------------------------------------
    -- FEATURE 16: SPI Fluent Strongly-Typed Entity Mapping (fetch[T])
    -- -------------------------------------------------------------------------
    CREATE TYPE staff_dto AS (name text, salary float8);

    CREATE FUNCTION fn_feat16_top_earners(min_sal float8) RETURNS SETOF staff_dto AS $$
      let s = table("tbl_staff", "s")
      return fetch[Staff_dto](
        Select(s.name, s.salary)
          .From(s)
          .Where(s.salary >= min_sal)
          .OrderBy(s.salary.desc)
      )
    $$ LANGUAGE plnim;

    SELECT * FROM fn_feat16_top_earners(80000.0);
EOSQL

  echo ""
  echo "✅ [PostgreSQL $V] ALL 16 FEATURES PASSED 100% SUCCESSFULLY!"
  docker rm -f "${CONTAINER}" >/dev/null 2>&1
done

echo ""
echo "=============================================================================="
echo "🎉 Multi-version compatibility test matrix completed successfully across all tested versions!"
echo "=============================================================================="
