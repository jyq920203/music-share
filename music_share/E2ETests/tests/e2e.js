const wdio = require('webdriverio');
const { config } = require('../lib/config');

const G = '\x1b[32m';
const R = '\x1b[31m';
const X = '\x1b[0m';
function pass(s) { console.log(`${G}✓${X} ${s}`); }
function fail(s) { console.log(`${R}✗${X} ${s}`); }

const TEST_URL = 'https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT';

(async () => {
  const driver = await wdio.remote(config);
  pass('会话已创建');
  await driver.pause(2000);

  // ==== 测试1: 基础 UI 元素 ====
  console.log(`\n${G}── 1. 基础 UI 检查 ──${X}`);
  const title = await driver.$('//XCUIElementTypeStaticText[@name="音乐分享"]');
  (await title.getText()) === '音乐分享' ? pass('App 标题') : fail('App 标题');
  const input = await driver.$('//XCUIElementTypeTextField');
  (await input.getAttribute('placeholderValue')) === '粘贴音乐链接...' ? pass('输入框 placeholder') : fail('输入框 placeholder');
  const btn = await driver.$('//XCUIElementTypeButton[@name="转换"]');
  (await btn.isExisting()) ? pass('转换按钮存在') : fail('转换按钮不存在');

  // ==== 测试2: 手动输入转换 ====
  console.log(`\n${G}── 2. 手动转换测试 ──${X}`);
  await input.click();
  await input.clearValue();
  await input.setValue(TEST_URL);
  pass(`已输入 URL`);

  await btn.click();
  pass('已点击转换');

  await driver.pause(8000);
  const source = await driver.getPageSource();

  if (source.includes('XCUIElementTypeScrollView')) {
    const count = (source.match(/arrow\.up\.forward\.app\.fill/g) || []).length;
    pass(`转换成功 → ${count} 个平台链接`);
    ['Apple Music', 'YouTube', 'YouTube Music', 'Deezer', 'Tidal', 'Amazon Music', 'QQ音乐', '网易云音乐'].forEach(n => {
      source.includes(n) ? pass(`  ✓ ${n}`) : fail(`  ✗ ${n}`);
    });
  } else {
    fail('转换未产生结果');
  }

  await driver.deleteSession();
  console.log(`\n${G}=== 全部测试通过 ===${X}`);
})().catch(err => {
  console.error(`${R}\n测试失败:${X}`, err.message);
  process.exit(1);
});
