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

  // 清除输入框
  const input = await driver.$('//XCUIElementTypeTextField');
  await input.click();
  await input.clear();
  pass('输入框已清空');

  // 输入 URL
  await input.setValue(TEST_URL);
  pass(`已输入: ${TEST_URL}`);

  // 点击转换按钮
  const convertBtn = await driver.$('//XCUIElementTypeButton[@name="转换"]');
  await convertBtn.click();
  pass('已点击转换按钮');

  // 等待结果
  await driver.pause(8000);
  const source = await driver.getPageSource();

  if (source.includes('XCUIElementTypeScrollView') && source.includes('arrow.up.forward.app.fill')) {
    const count = (source.match(/arrow\.up\.forward\.app\.fill/g) || []).length;
    pass(`转换成功，找到 ${count} 个平台链接`);

    // 验证期望的平台
    const expectedPlatforms = ['Apple Music', 'YouTube', 'YouTube Music', 'Deezer', 'Tidal', 'Amazon Music', 'QQ音乐', '网易云音乐'];
    for (const name of expectedPlatforms) {
      if (source.includes(name)) {
        pass(`  └ ${name}`);
      } else {
        fail(`  └ ${name} (未找到)`);
      }
    }
  } else if (source.includes('转换失败')) {
    fail('转换失败 (API 错误)');
  } else if (source.includes('正在查找')) {
    fail('仍在加载中，API 超时');
  } else {
    fail('意外状态');
  }

  await driver.deleteSession();
  console.log(`\n${G}=== 转换测试完成 ===${X}`);
})().catch(err => {
  console.error(`${R}测试失败:${X}`, err.message);
  process.exit(1);
});
