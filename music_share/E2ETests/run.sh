#!/bin/bash
set -e

APPIUM_PID=""

cleanup() {
  echo ""
  echo "正在清理..."
  if [ -n "$APPIUM_PID" ]; then
    kill "$APPIUM_PID" 2>/dev/null
  fi
  exit
}

trap cleanup INT TERM

echo "=== MusicShare E2E 测试 ==="
echo ""

# 检查 Appium 是否运行
if ! curl -s http://localhost:4723/status > /dev/null 2>&1; then
  echo "启动 Appium 服务..."
  nohup appium --log-level warn > /tmp/appium.log 2>&1 < /dev/null &
  APPIUM_PID=$!
  sleep 3
  echo "Appium 已启动 (PID: $APPIUM_PID)"
else
  echo "Appium 已在运行"
fi

# 编译 app
echo ""
echo "编译项目..."
cd "$(dirname "$0")/.."
xcodebuild -project MusicShare.xcodeproj -scheme MusicShare -configuration Debug -destination 'generic/platform=iOS Simulator' build -quiet 2>&1 | tail -1
echo "编译完成"

# 启动模拟器
echo ""
echo "启动模拟器..."
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/MusicShare-*/Build/Products/Debug-iphonesimulator/MusicShare.app -maxdepth 0 2>/dev/null | head -1)
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
xcrun simctl install "iPhone 17 Pro" "$APP_PATH" 2>/dev/null
echo "App 已安装到模拟器"

# 运行测试
echo ""
echo "─────────────────────────────"
NODE_PATH=$(npm root -g) node tests/e2e.js
echo "─────────────────────────────"

NODE_PATH=$(npm root -g) node tests/share.js
echo "─────────────────────────────"

echo ""
echo "=== 全部测试完成 ==="
