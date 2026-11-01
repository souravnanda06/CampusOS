import os
import sys
import subprocess
import glob
import time

def main():
    backend_dir = os.path.dirname(os.path.abspath(__file__))
    test_files = sorted(glob.glob(os.path.join(backend_dir, "test_*.py")))
    # Exclude run_all_backend_tests.py itself
    test_files = [f for f in test_files if not os.path.basename(f).startswith("run_all_backend_tests")]

    print(f"Discovered {len(test_files)} backend test suites to run:")
    for f in test_files:
        print(f"  - {os.path.basename(f)}")
    print("=" * 70)

    passed_count = 0
    failed_count = 0
    results = []

    start_time = time.time()

    for f in test_files:
        fname = os.path.basename(f)
        print(f"\n[RUNNING] {fname}...", flush=True)
        t0 = time.time()
        res = subprocess.run([sys.executable, f], capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=backend_dir)
        elapsed = time.time() - t0

        if res.returncode == 0:
            passed_count += 1
            results.append((fname, "PASS", f"{elapsed:.2f}s", ""))
            print(f"  -> [PASS] in {elapsed:.2f}s", flush=True)
        else:
            failed_count += 1
            results.append((fname, "FAIL", f"{elapsed:.2f}s", res.stderr or res.stdout))
            print(f"  -> [FAIL] (exit code {res.returncode}) in {elapsed:.2f}s", flush=True)
            print(res.stdout[-500:] if res.stdout else "", flush=True)
            print(res.stderr[-500:] if res.stderr else "", flush=True)

    total_time = time.time() - start_time
    print("\n" + "=" * 70)
    print("BACKEND TEST SUITES SUMMARY RESULTS")
    print("=" * 70)
    for fname, status, el, err in results:
        status_str = f"[PASS]" if status == "PASS" else f"[FAIL]"
        print(f"{fname:<40} {status_str:<10} ({el})")

    print("-" * 70)
    print(f"Total Suites: {len(test_files)} | Passed: {passed_count} | Failed: {failed_count} | Time: {total_time:.2f}s")
    print("=" * 70)

    if failed_count > 0:
        sys.exit(1)
    else:
        sys.exit(0)

if __name__ == "__main__":
    main()
