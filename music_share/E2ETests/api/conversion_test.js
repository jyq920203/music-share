// === 集成测试: 完整转换链路 ===
// 模拟 MusicLinkService 的转换逻辑 — 不依赖 iOS App

const BASE = "https://api.song.link/v1-alpha.1/links?url=";

async function songLinkResolve(url) {
  const res = await fetch(BASE + encodeURIComponent(url));
  if (res.status !== 200) return null;
  return res.json();
}

async function qqMusicSongInfo(songId) {
  const body = JSON.stringify({
    songinfo: { module: "music.pf_song_detail_svr", method: "get_song_detail", param: { song_id: parseInt(songId) } }
  });
  const res = await fetch(`https://u.y.qq.com/cgi-bin/musicu.fcg?format=json&data=${encodeURIComponent(body)}`);
  const json = await res.json();
  const track = json.songinfo.data.track_info;
  return { title: track.name, artist: track.singer?.[0]?.name || "" };
}

async function neteaseSongInfo(songId) {
  const res = await fetch(`https://music.163.com/api/song/detail?ids=%5B${songId}%5D`, {
    headers: { "Referer": "https://music.163.com", "User-Agent": "Mozilla/5.0" }
  });
  const json = await res.json();
  const song = json.songs[0];
  return { title: song.name, artist: song.artists[0].name };
}

function extractQQSongID(url) {
  const u = new URL(url);
  const songid = u.searchParams.get("songid");
  if (songid) return songid;
  const parts = u.pathname.split("/");
  const last = parts[parts.length - 1];
  if (/^\d+$/.test(last)) return last;
  return null;
}

function extractNetEaseSongID(url) {
  return new URL(url).searchParams.get("id");
}

function buildSearchURLs(query, platforms) {
  const map = {
    spotify: "https://open.spotify.com/search/{q}",
    appleMusic: "https://music.apple.com/search?term={q}",
    youtube: "https://www.youtube.com/results?search_query={q}",
    youtubeMusic: "https://music.youtube.com/search?q={q}",
    deezer: "https://www.deezer.com/search/{q}",
    tidal: "https://tidal.com/search?q={q}",
    amazonMusic: "https://music.amazon.com/search/{q}",
  };
  const encoded = encodeURIComponent(query);
  return platforms.map(p => ({ platform: p, url: map[p]?.replace("{q}", encoded) || `https://${p}` }));
}

async function convert(url, label) {
  console.log(`\n── ${label} ──`);
  console.log(`URL: ${url.substring(0, 80)}`);

  const host = new URL(url).hostname;

  // QQ Music
  if (host.includes("y.qq.com")) {
    const songId = extractQQSongID(url);
    if (!songId) return console.log("✗ 无法提取 songId");

    // Try Song.Link first
    const normalized = `https://y.qq.com/n/ryqq/songDetail/${songId}`;
    const payload = await songLinkResolve(normalized);

    if (payload?.linksByPlatform) {
      const platforms = Object.keys(payload.linksByPlatform);
      console.log(`✓ Song.Link 成功: ${platforms.length} 个国际平台直达`);
    } else {
      console.log(`⚠ Song.Link 不支持 QQ Music → 走歌名搜索`);

      // Get song info from QQ API
      const info = await qqMusicSongInfo(songId);
      console.log(`  歌曲: ${info.title} - ${info.artist}`);

      // Build search links for international
      const intl = ["spotify", "appleMusic", "youtube", "youtubeMusic", "deezer", "tidal", "amazonMusic"];
      const links = buildSearchURLs(`${info.title} ${info.artist}`, intl);
      console.log(`  国际平台: ${links.length} 个搜索链接`);
    }
    return;
  }

  // NetEase
  if (host.includes("music.163.com")) {
    const songId = extractNetEaseSongID(url);
    if (!songId) return console.log("✗ 无法提取 songId");

    const payload = await songLinkResolve(url);
    if (payload?.linksByPlatform) {
      const platforms = Object.keys(payload.linksByPlatform);
      console.log(`✓ Song.Link 成功: ${platforms.length} 个国际平台直达`);
    } else {
      console.log(`⚠ Song.Link 不支持 NetEase → 走歌名搜索`);
      const info = await neteaseSongInfo(songId);
      console.log(`  歌曲: ${info.title} - ${info.artist}`);
      const intl = ["spotify", "appleMusic", "youtube", "youtubeMusic", "deezer", "tidal", "amazonMusic"];
      console.log(`  国际平台: ${intl.length} 个搜索链接`);
    }
    return;
  }

  // International platforms → Song.Link
  const payload = await songLinkResolve(url);
  if (payload?.linksByPlatform) {
    const platforms = Object.keys(payload.linksByPlatform);
    const entity = payload.entityUniqueId ? payload.entitiesByUniqueId?.[payload.entityUniqueId] : null;
    console.log(`✓ 直达链接: ${platforms.length} 个平台`);
    if (entity) console.log(`  歌曲: ${entity.title} - ${entity.artistName}`);
    platforms.forEach(p => {
      const url = payload.linksByPlatform[p].url;
      console.log(`  · ${p}: ${url.substring(0, 80)}`);
    });
  } else {
    console.log(`✗ 解析失败: ${payload?.code || "未知"}`);
  }
}

async function main() {
  console.log("═══════ 转换引擎集成测试 ═══════");

  await convert("https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT", "Spotify 链接");
  await convert("https://music.apple.com/us/album/never-gonna-give-you-up/867556292?i=867556303", "Apple Music 链接");
  await convert("https://i2.y.qq.com/n3/other/pages/playsong/index.html?ADTAG=ryqq.songDetail&songmid=&songid=594493086&songtype=0#webchat_redirect", "QQ 音乐链接");
  await convert("https://music.163.com/song?id=18520488", "网易云音乐链接");
  await convert("https://y.qq.com/n/ryqq/songDetail/109290161", "QQ 音乐链接 2 (晴天)");

  console.log("\n═══ 完成 ═══");
}

main().catch(e => console.error(e));
