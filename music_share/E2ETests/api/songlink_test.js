// === API: Song.Link 解析 ===
const BASE = "https://api.song.link/v1-alpha.1/links?url=";

async function songLink(url, label) {
  const apiURL = BASE + encodeURIComponent(url);
  const res = await fetch(apiURL);
  const data = await res.json();

  if (data.linksByPlatform) {
    const platforms = Object.keys(data.linksByPlatform);
    console.log(`✓ ${label}: ${platforms.length} 个平台`, platforms.join(", "));
    const entity = data.entityUniqueId ? data.entitiesByUniqueId?.[data.entityUniqueId] : null;
    if (entity) console.log(`  歌曲: ${entity.title} - ${entity.artistName}`);
  } else {
    console.log(`✗ ${label}: ${data.code || data.statusCode}`);
  }
}

async function main() {
  console.log("=== Song.Link API 测试 ===\n");

  await songLink("https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT", "Spotify 直达");
  await songLink("https://music.apple.com/us/album/never-gonna-give-you-up/867556292?i=867556303", "Apple Music 直达");
  await songLink("https://y.qq.com/n/ryqq/songDetail/594493086", "QQ Music 标准化");
  await songLink("https://music.163.com/song?id=18520488", "NetEase 直达");
  await songLink("https://www.youtube.com/watch?v=dQw4w9WgXcQ", "YouTube 直达");
  await songLink("https://open.spotify.com/artist/0OdUWJ0sBjDrqHygGUXeCF", "Spotify 艺人页面(应拒绝)");
}

main().catch(e => console.error(e));
