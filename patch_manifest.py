"""
patch_manifest.py <AndroidManifest.xml>
Removes <queries> package entries for root/emulator tools and
strips android:permission="" (empty string) from exported activities.
"""
import sys, re

ROOT_PACKAGES = {
    "me.weishu.kernelsu",
    "me.bmax.apatch",
    "com.topjohnwu.magisk",
    "io.github.vvb2060.magisk",
    "de.robv.android.xposed.installer",
    "io.appium.settings",
    "io.appium.uiautomator2.server",
}

def patch(path):
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()

    original = content
    changes = []

    # ── Remove <package android:name="...root/emulator package..."/> entries ──
    def remove_package(m):
        pkg = re.search(r'android:name=["\']([^"\']+)["\']', m.group(0))
        if pkg and pkg.group(1) in ROOT_PACKAGES:
            changes.append(f"  Removed <queries> entry: {pkg.group(1)}")
            return ""
        return m.group(0)

    content = re.sub(
        r'<package\s[^/]*/>\s*',
        remove_package,
        content
    )

    # ── Fix android:permission="" on exported activities (remove the attr) ──
    def fix_empty_permission(m):
        tag = m.group(0)
        if 'android:exported="true"' in tag and 'android:permission=""' in tag:
            fixed = tag.replace('android:permission=""', '')
            changes.append(f"  Removed empty android:permission from exported activity")
            return fixed
        return tag

    content = re.sub(
        r'<activity\b[^>]*>',
        fix_empty_permission,
        content,
        flags=re.DOTALL
    )

    # ── Fix android:resource="@null" in <meta-data> ──────────────────────
    # apktool decodes null resource IDs as "@null" but cannot re-encode them,
    # leaving the attribute dropped → INSTALL_PARSE_FAILED_MANIFEST_MALFORMED.
    # Replace with android:value="0" which is a valid equivalent.
    def fix_null_resource(m):
        tag = m.group(0)
        if 'android:resource="@null"' in tag:
            fixed = tag.replace('android:resource="@null"', 'android:value="0"')
            changes.append('  Fixed android:resource="@null" -> android:value="0" in meta-data')
            return fixed
        return tag

    content = re.sub(r'<meta-data\b[^>]*/>', fix_null_resource, content, flags=re.DOTALL)

    # ── Remove debuggable=true if accidentally present ──
    if 'android:debuggable="true"' in content:
        content = content.replace('android:debuggable="true"', 'android:debuggable="false"')
        changes.append("  Set android:debuggable to false")

    if content != original:
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"  [+] Manifest patched ({len(changes)} change(s)):")
        for c in changes:
            print(c)
    else:
        print("  [~] No manifest changes needed.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: patch_manifest.py <AndroidManifest.xml>")
        sys.exit(1)
    patch(sys.argv[1])
