#!/bin/bash
# 用法: ./release.sh <版本号> <DMG路径>
# 示例: ./release.sh 1.0.1 "/Users/yangyichen/个人资料/00Lib/AppleDeveloper/Projects/barTimer/dmgs/barTimer_1.0.1.dmg"

set -e

VERSION="$1"
DMG_PATH="$2"

# 参数检查
if [ -z "$VERSION" ] || [ -z "$DMG_PATH" ]; then
  echo "用法: ./release.sh <版本号> <DMG路径>"
  echo "示例: ./release.sh 1.0.1 \"/path/to/barTimer_1.0.1.dmg\""
  exit 1
fi

if [ ! -f "$DMG_PATH" ]; then
  echo "错误：DMG 文件不存在: $DMG_PATH"
  exit 1
fi

SPARKLE_BIN="/Users/yangyichen/Library/Developer/Xcode/DerivedData/barTimer-fdlhgjlpqldaijhamvesjujdkgaw/SourcePackages/artifacts/sparkle/Sparkle/bin"
SIGN_UPDATE="$SPARKLE_BIN/sign_update"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
APPCAST="$REPO_DIR/docs/appcast.xml"
# appcast 公开访问地址：https://raw.githubusercontent.com/AidenYang1/barTimer/main/docs/appcast.xml

# 检查 sign_update 工具
if [ ! -f "$SIGN_UPDATE" ]; then
  echo "错误：找不到 sign_update 工具，请确认 Sparkle 已通过 SPM 添加到项目"
  exit 1
fi

echo "→ 对 DMG 签名中..."
SIGN_OUTPUT=$("$SIGN_UPDATE" "$DMG_PATH")

ED_SIGNATURE=$(echo "$SIGN_OUTPUT" | grep -o 'sparkle:edSignature="[^"]*"' | cut -d'"' -f2)
LENGTH=$(echo "$SIGN_OUTPUT" | grep -o 'length="[^"]*"' | cut -d'"' -f2)

if [ -z "$ED_SIGNATURE" ] || [ -z "$LENGTH" ]; then
  echo "错误：签名失败，输出：$SIGN_OUTPUT"
  exit 1
fi

echo "  签名: $ED_SIGNATURE"
echo "  大小: $LENGTH bytes"

# 生成 pubDate（RFC 2822 格式）
PUB_DATE=$(date -R)

# 构造新 item
DMG_FILENAME=$(basename "$DMG_PATH")
DOWNLOAD_URL="https://github.com/AidenYang1/barTimer/releases/download/v${VERSION}/${DMG_FILENAME}"

NEW_ITEM="
    <item>
      <title>Version ${VERSION}</title>
      <pubDate>${PUB_DATE}</pubDate>
      <sparkle:releaseNotesLink>
        https://github.com/AidenYang1/barTimer/releases/tag/v${VERSION}
      </sparkle:releaseNotesLink>
      <enclosure
        url=\"${DOWNLOAD_URL}\"
        sparkle:version=\"${VERSION}\"
        sparkle:shortVersionString=\"${VERSION}\"
        sparkle:edSignature=\"${ED_SIGNATURE}\"
        length=\"${LENGTH}\"
        type=\"application/x-apple-diskimage\" />
    </item>"

# 插入到注释行之后
COMMENT="<!-- ===== 每次发新版本，在这里顶部插入一个新 <item>，保留旧的 ===== -->"

if ! grep -q "$COMMENT" "$APPCAST"; then
  echo "错误：在 appcast.xml 里找不到插入标记，请检查文件格式"
  exit 1
fi

# 用 Python 做精确插入（避免 sed 跨平台问题）
python3 - <<PYEOF
import re

with open('$APPCAST', 'r', encoding='utf-8') as f:
    content = f.read()

marker = '$COMMENT'
insert = '''$NEW_ITEM'''

new_content = content.replace(marker, marker + '\n' + insert, 1)

with open('$APPCAST', 'w', encoding='utf-8') as f:
    f.write(new_content)

print("  appcast.xml 已更新")
PYEOF

echo "→ appcast.xml 已插入 v${VERSION} 条目"

# git 提交推送
echo "→ 推送到 GitHub..."
cd "$REPO_DIR"
git add docs/appcast.xml
git commit -m "chore: release v${VERSION}"
git push origin main

echo ""
echo "✓ 完成！appcast.xml 已更新并推送"
echo ""
echo "下一步：去 GitHub 发布 Release 并上传 DMG："
echo "  https://github.com/AidenYang1/barTimer/releases/new"
echo "  Tag: v${VERSION}"
echo "  上传文件: $DMG_FILENAME"
