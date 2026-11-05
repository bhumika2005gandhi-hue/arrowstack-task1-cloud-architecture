###############################################################################
# Terraform validation test — checks that the IaC is well-formed
# Run: python3 tests/test_terraform.py
###############################################################################
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TF_DIR = os.path.join(ROOT, "terraform")

def run(cmd, cwd=TF_DIR):
    return subprocess.run(cmd, cwd=cwd, shell=True, capture_output=True, text=True)

def test_terraform_installed():
    assert shutil.which("terraform"), "terraform binary not found in PATH"

def test_fmt_check():
    r = run("terraform fmt -check -recursive -diff")
    assert r.returncode == 0, f"terraform fmt issues:\n{r.stdout}\n{r.stderr}"

def test_init():
    r = run("terraform init -backend=false -input=false")
    assert r.returncode == 0, f"terraform init failed:\n{r.stdout}\n{r.stderr}"

def test_validate():
    r = run("terraform validate")
    assert r.returncode == 0, f"terraform validate failed:\n{r.stdout}\n{r.stderr}"

def test_required_files():
    for f in ["providers.tf", "variables.tf", "main.tf", "outputs.tf"]:
        assert os.path.exists(os.path.join(TF_DIR, f)), f"missing {f}"

if __name__ == "__main__":
    for name, fn in list(globals().items()):
        if name.startswith("test_") and callable(fn):
            try:
                fn()
                print(f"PASS  {name}")
            except AssertionError as e:
                print(f"FAIL  {name}: {e}")
                sys.exit(1)
    print("\nAll Terraform tests passed.")
