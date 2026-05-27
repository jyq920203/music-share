// === API: 网易云音乐获取歌曲信息 ===
async function neteaseInfo(songId, label) {
  const url = `https://music.163.com/api/song/detail?ids=%5B${songId}%5D`;
  const res = await fetch(url, {
    headers: {
      "Referer": "https://music.163.com",
      "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
    }
  });
  const json = await res.json();

  try {
    const song = json.songs[0];
    console.log(`✓ ${label}: ${song.name} - ${song.artists[0].name} (id=${songId})`);
  } catch {
    console.log(`✗ ${label}: ${JSON.stringify(json).substring(0, 120)}`);
  }
}

async function main() {
  console.log("=== 网易云音乐 API 测试 ===\n");
  await neteaseInfo("18520488", "Never Gonna Give You Up");
  await neteaseInfo("186057", "晴天");
  await neteaseInfo("0", "无效 ID");
}

main().catch(e => console.error(e));
