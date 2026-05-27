const capabilities = {
  platformName: 'iOS',
  'appium:automationName': 'XCUITest',
  'appium:deviceName': 'iPhone 17 Pro',
  'appium:platformVersion': '26.4',
  'appium:bundleId': 'com.jyq920203.musicshare',
  'appium:noReset': true,
  'appium:fullReset': false,
  'appium:autoAcceptAlerts': true,
  'appium:newCommandTimeout': 60,
};

const config = {
  path: '/',
  port: 4723,
  capabilities,
  waitforTimeout: 10000,
};

module.exports = { config, capabilities };
