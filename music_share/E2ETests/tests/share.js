const { execSync } = require('child_process');
const wdio = require('webdriverio');

const G = '\x1b[32m'; const R = '\x1b[31m'; const X = '\x1b[0m';
function pass(s) { console.log(`${G}✓${X} ${s}`); }
function fail(s) { console.log(`${R}✗${X} ${s}`); }

const DEVICE = 'iPhone 17 Pro';
const BUNDLE_ID = 'com.jyq920203.musicshare';
const URL = 'https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT';
const DL = `musicshare://share?url=${encodeURIComponent(URL)}`;

(async () => {
  // ====== 1. Deep Link 跳转 ======
  console.log(`${G}── 1. Deep Link 验证 ──${X}`);
  execSync(`xcrun simctl terminate "${DEVICE}" ${BUNDLE_ID} 2>/dev/null || true`, { stdio: 'ignore' });
  execSync(`xcrun simctl openurl "${DEVICE}" "${DL}"`, { stdio: 'ignore' });
  await new Promise(r => setTimeout(r, 4000));

  const app = await wdio.remote({
    path: '/', port: 4723,
    capabilities: {
      platformName: 'iOS', 'appium:automationName': 'XCUITest',
      'appium:deviceName': DEVICE, 'appium:platformVersion': '26.4',
      'appium:bundleId': BUNDLE_ID, 'appium:noReset': true,
      'appium:autoAcceptAlerts': true, 'appium:waitForQuiescence': false,
    }
  });
  await app.pause(1000);

  const val = await (await app.$('//XCUIElementTypeTextField')).getAttribute('value');
  val === URL ? pass(`musicshare:// 成功传入 URL`) : fail(`失败: "${val}"`);

  await app.pause(8000);
  const src = await app.getPageSource();
  if (src.includes('XCUIElementTypeScrollView')) {
    const n = (src.match(/arrow\.up\.forward\.app\.fill/g) || []).length;
    pass(`转换 → ${n} 个平台链接`);
  }
  await app.deleteSession();

  // ====== 2. Test Stub 触发 Share Sheet ======
  console.log(`\n${G}── 2. Test Stub 触发系统 Share Sheet ──${X}`);
  execSync(`xcrun simctl terminate "${DEVICE}" ${BUNDLE_ID} 2>/dev/null || true`, { stdio: 'ignore' });

  const app2 = await wdio.remote({
    path: '/', port: 4723,
    capabilities: {
      platformName: 'iOS', 'appium:automationName': 'XCUITest',
      'appium:deviceName': DEVICE, 'appium:platformVersion': '26.4',
      'appium:bundleId': BUNDLE_ID, 'appium:noReset': true,
      'appium:autoAcceptAlerts': true, 'appium:waitForQuiescence': false,
      'appium:animationCoolOffTimeout': 0,
    }
  });
  await app2.pause(1000);

  // 点击 "测试分享" debug 按钮
  try {
    const testBtn = await app2.$('//XCUIElementTypeButton[@name="测试分享"]');
    await testBtn.click();
    await app2.pause(1500);
    pass('已点击测试分享按钮');
  } catch (e) {
    fail(`找不到测试分享按钮: ${e.message}`);
    await app2.deleteSession();
    process.exit(1);
  }

  // Share Sheet 由 UIActivityViewController 触发，在 App 进程内
  const popover = await app2.$('//XCUIElementTypePopover');
  const cell = await app2.$('//XCUIElementTypeCell[@label="音乐分享"]');

  if (await cell.isExisting()) {
    pass('Share Sheet 中找到 MusicShare');
    await cell.click();
    pass('已点击 MusicShare');
    await app2.pause(3000);

    // 切回主 App 验证 URL
    const app3 = await wdio.remote({
      path: '/', port: 4723,
      capabilities: {
        platformName: 'iOS', 'appium:automationName': 'XCUITest',
        'appium:deviceName': DEVICE, 'appium:platformVersion': '26.4',
        'appium:bundleId': BUNDLE_ID, 'appium:noReset': true,
        'appium:autoAcceptAlerts': true, 'appium:waitForQuiescence': false,
      }
    });
    await app3.pause(2000);

    const input = await app3.$('//XCUIElementTypeTextField');
    const v = await input.getAttribute('value');
    v === URL
      ? pass(`Share Extension 跳转主 App 成功 → "${v}"`)
      : fail(`失败 → "${v}"`);

    await app3.pause(8000);
    const src3 = await app3.getPageSource();
    if (src3.includes('XCUIElementTypeScrollView') && src3.includes('arrow.up.forward.app.fill')) {
      pass('主 App 自动转换完成');
    }
    await app3.deleteSession();
  } else {
    fail('Share Sheet 中未找到 MusicShare');
  }

  await app2.deleteSession();

  // ====== 3. 编译产物 ======
  console.log(`\n${G}── 3. 编译验证 ──${X}`);
  const out = execSync(
    'find ~/Library/Developer/Xcode/DerivedData/MusicShare-*/Build/Products/Debug-iphonesimulator/ -name "ShareExtension.appex" -type d',
    { encoding: 'utf8' }
  ).trim();
  out ? pass('ShareExtension.appex 已编译') : fail('未编译');

  console.log(`\n${G}=== Share Extension 验证完成 ===${X}`);
})().catch(err => {
  console.error(`${R}测试失败:${X}`, err.message);
  process.exit(1);
});
