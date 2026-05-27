// === API: QQ 音乐获取歌曲信息 ===
async function qqMusicInfo(songId, label) {
  const body = JSON.stringify({
    songinfo: {
      module: "music.pf_song_detail_svr",
      method: "get_song_detail",
      param: { song_id: parseInt(songId) }
    }
  });
  const url = `https://u.y.qq.com/cgi-bin/musicu.fcg?format=json&data=${encodeURIComponent(body)}`;
  const res = await fetch(url);
  const json = await res.json();

  try {
    const track = json.songinfo.data.track_info;
    const title = track.name;
    const artist = track.singer?.[0]?.name || "(未知)";
    console.log(`✓ ${label}: ${title} - ${artist} (id=${songId})`);
  } catch {
    console.log(`✗ ${label}: ${JSON.stringify(json).substring(0, 120)}`);
  }
}

async function main() {
  console.log("=== QQ 音乐 API 测试 ===\n");
  await qqMusicInfo("594493086", "Satellite (落日飛車)");
  await qqMusicInfo("109290161", "晴天 (周杰伦)");
  await qqMusicInfo("000000", "无效 ID");
}

main().catch(e => console.error(e));
