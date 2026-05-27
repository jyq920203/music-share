const { execSync } = require('child_process');
const wdio = require('webdriverio');
const { config } = require('../lib/config');

const G = '\x1b[32m';
const R = '\x1b[31m';
const X = '\x1b[0m';
function pass(s) { console.log(`${G}✓${X} ${s}`); }
function fail(s) { console.log(`${R}✗${X} ${s}`); }

const DEVICE = 'iPhone 17 Pro';
const BUNDLE_ID = 'com.jyq920203.musicshare';
const MUSIC_URL = 'https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT';
const DEEP_LINK = `musicshare://share?url=${encodeURIComponent(MUSIC_URL)}`;

(async () => {
  // 先终止 app，再通过 deep link 启动 (模拟 Share Extension 调用 NSExtensionContext.open)
  execSync(`xcrun simctl terminate "${DEVICE}" ${BUNDLE_ID} 2>/dev/null || true`, { stdio: 'ignore' });
  execSync(`xcrun simctl openurl "${DEVICE}" "${DEEP_LINK}"`, { stdio: 'ignore' });
  await new Promise(r => setTimeout(r, 4000));

  const driver = await wdio.remote(config);
  pass('会话已创建');
  await driver.pause(1000);

  const input = await driver.$('//XCUIElementTypeTextField');
  const value = await input.getAttribute('value');

  if (value === MUSIC_URL) {
    pass(`Deep link 解析成功 → ${value}`);
  } else {
    fail(`Deep link 解析失败，得到: "${value}"`);
    await driver.deleteSession();
    process.exit(1);
  }

  // 等待转换
  await driver.pause(8000);
  const source = await driver.getPageSource();

  if (source.includes('XCUIElementTypeScrollView') && source.includes('arrow.up.forward.app.fill')) {
    const count = (source.match(/arrow\.up\.forward\.app\.fill/g) || []).length;
    pass(`自动转换成功 → ${count} 个平台链接`);

    ['Apple Music', 'YouTube', 'YouTube Music', 'Deezer', 'Tidal', 'Amazon Music', 'QQ音乐', '网易云音乐']
      .forEach(n => { source.includes(n) ? pass(`  ✓ ${n}`) : fail(`  ✗ ${n}`); });
  } else {
    fail('转换未完成');
  }

  await driver.deleteSession();
  console.log(`\n${G}=== DEEP LINK 测试完成 ===${X}`);
})().catch(err => {
  console.error(`${R}\n测试失败:${X}`, err.message);
  process.exit(1);
});
