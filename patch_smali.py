"""
patch_smali.py <file.smali>
Finds boolean-returning methods that contain root/emulator detection keywords
and injects an early "return false (0)" at the top of the method body.
"""
import sys, re

DETECTION_KEYWORDS = [
    "isRooted", "checkRoot", "detectRoot", "isEmulator",
    "checkEmulator", "RootBeer", "Build.FINGERPRINT",
    "test-keys", "su", "/system/app/Superuser",
]

RETURN_FALSE_Z  = "    const/4 v0, 0x0\n    return v0\n"
RETURN_FALSE_I  = "    const/4 v0, 0x0\n    return v0\n"

def patch(path):
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()

    methods = re.split(r'(?=\.method\s)', content)
    patched = []
    changes = 0

    for block in methods:
        if not block.startswith(".method"):
            patched.append(block)
            continue

        # Only patch methods that contain detection keywords
        if not any(kw.lower() in block.lower() for kw in DETECTION_KEYWORDS):
            patched.append(block)
            continue

        # Determine return type from method signature
        sig_line = block.splitlines()[0]
        # e.g. .method public isRooted()Z  → returns Z (boolean)
        #      .method public checkRoot()I  → returns I (int)
        ret_match = re.search(r'\)(.)$', sig_line.strip())
        ret_type  = ret_match.group(1) if ret_match else None

        if ret_type not in ("Z", "I"):
            # Not a boolean/int return — skip to avoid breaking void methods
            patched.append(block)
            continue

        # Inject early return-false after the .locals line
        lines = block.splitlines(keepends=True)
        injected = False
        new_lines = []
        for line in lines:
            new_lines.append(line)
            # Insert after .locals declaration inside the method
            if not injected and re.match(r'\s+\.locals\s+\d+', line):
                new_lines.append(f"\n    # [PATCH] bypass detection\n")
                new_lines.append(f"    const/4 v0, 0x0\n")
                new_lines.append(f"    return v0\n\n")
                injected = True
                changes += 1

        patched.append("".join(new_lines))

    if changes:
        with open(path, "w", encoding="utf-8") as f:
            f.write("".join(patched))
        print(f"      [+] Patched {changes} method(s) in {path}")
    else:
        print(f"      [~] No patchable methods found in {path}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: patch_smali.py <file.smali>")
        sys.exit(1)
    patch(sys.argv[1])
