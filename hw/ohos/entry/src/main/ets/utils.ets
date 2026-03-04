import http from '@ohos.net.http';

export const kBaseHost: string = 'https://www.jkan.app';
export const kDefaultListUrl: string = 'https://www.jkan.app/show/1--------1---.html';

export function toAbsUrl(url: string): string {
  if (!url) return url;
  if (url.startsWith('http')) return url;
  if (url.startsWith('//')) return 'https:' + url;
  if (url.startsWith('/')) return kBaseHost + url;
  return kBaseHost + '/' + url;
}

export function defaultHeaders(referer: string): Record<string, string> {
  const ref = referer && referer.length > 0 ? referer : kBaseHost;
  return {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36',
    'Referer': ref,
    'Origin': kBaseHost,
    'Accept': '*/*',
    'Accept-Language': 'zh-CN,zh;q=0.9'
  };
}

export async function fetchHtml(url: string): Promise<string> {
  const httpClient = http.createHttp();
  const resp = await httpClient.request(url, {
    method: http.RequestMethod.GET,
    header: defaultHeaders(url),
    expectDataType: http.HttpDataType.STRING
  });
  const result = resp.result as string;
  httpClient.destroy();
  if (!result) {
    throw new Error('empty response');
  }
  return result;
}

export function parseListItems(html: string): Array<Record<string, string>> {
  const items: Array<Record<string, string>> = [];
  const listRegex = /<li[^>]*class=\"vodlist_item\"[\s\S]*?<\/li>/g;
  const blocks = html.match(listRegex) ?? [];
  for (const block of blocks) {
    const cover = matchGroup(block, /data-background-image=\"([^\"]+)\"/);
    const href = matchGroup(block, /class=\"vodlist_thumb\"[^>]*href=\"([^\"]+)\"/)
      || matchGroup(block, /class=\"vodlist_title\"[\s\S]*?href=\"([^\"]+)\"/);
    const title = matchGroup(block, /class=\"vodlist_thumb\"[^>]*title=\"([^\"]+)\"/)
      || matchGroup(block, /class=\"vodlist_title\"[\s\S]*?>\s*([^<]+)\s*</);
    const subTitle = matchGroup(block, /class=\"vodlist_sub\"[^>]*>\s*([^<]*)\s*</);
    const badge = matchGroup(block, /class=\"xszxj\"[^>]*>\s*([^<]*)\s*</);
    if (!title || !href) continue;
    items.push({
      title: title.trim(),
      detailUrl: toAbsUrl(href),
      coverUrl: cover ? toAbsUrl(cover) : '',
      subTitle: subTitle ? subTitle.trim() : '',
      badge: badge ? badge.trim() : ''
    });
  }
  return items;
}

export function parsePlayUrlFromHtml(html: string): string | undefined {
  const playerMatch = /player_data\s*=\s*(\{[\s\S]*?\})\s*;/.exec(html);
  if (playerMatch && playerMatch[1]) {
    const obj = playerMatch[1];
    const url = extractField(obj, 'url');
    const encrypt = extractField(obj, 'encrypt');
    if (url) {
      const decoded = decodeUrl(url, encrypt);
      if (decoded) return decoded;
    }
  }
  const urlField = /[\"']url[\"']\s*:\s*[\"']([^\"']+)[\"']/.exec(html);
  if (urlField && urlField[1]) {
    const encrypt = /[\"']encrypt[\"']\s*:\s*[\"']?(\d+)/.exec(html)?.[1];
    const decoded = decodeUrl(urlField[1], encrypt);
    if (decoded) return decoded;
  }
  const attrField = /(?:data-url|data-src|data-play)\s*=\s*[\"']([^\"']+)[\"']/i.exec(html);
  if (attrField && attrField[1]) {
    const decoded = decodeUrl(attrField[1], undefined);
    if (decoded) return decoded;
  }
  const videoMatch = /https?:\/\/[^\s\"']+\.(m3u8|mp4|mkv|flv|mov)/i.exec(html);
  if (videoMatch && videoMatch[0]) return videoMatch[0];
  return undefined;
}

export function findPlayPageUrl(html: string): string | undefined {
  const match = /(href|data-href|data-play)\s*=\s*[\"']([^\"']+\/play\/[^\"']+)[\"']/i.exec(html);
  if (match && match[2]) return toAbsUrl(match[2]);
  const match2 = /(href|data-href|data-play)\s*=\s*[\"']([^\"']+\/player\/[^\"']+)[\"']/i.exec(html);
  if (match2 && match2[2]) return toAbsUrl(match2[2]);
  return undefined;
}

function extractField(obj: string, field: string): string | undefined {
  const reg = new RegExp('"' + field + '"\\s*:\\s*"(.*?)"|\'' + field + '\\s*:\\s*\'(.*?)\'');
  const match = reg.exec(obj);
  return match?.[1] ?? match?.[2];
}

function decodeUrl(url: string, encrypt?: string): string | undefined {
  let value = url.replace('\\/', '/');
  value = tryDecodePercent(value);
  if (encrypt === '1') {
    value = tryDecodePercent(value);
  } else if (encrypt === '2') {
    try {
      value = globalThis.atob(value);
      value = tryDecodePercent(value);
    } catch (e) {
      return undefined;
    }
  }
  value = value.trim();
  const idx = value.indexOf('http');
  if (idx >= 0) value = value.substring(idx);
  if (value.startsWith('//')) value = 'https:' + value;
  if (value.startsWith('http')) return value;
  return toAbsUrl(value);
}

function tryDecodePercent(input: string): string {
  let out = input;
  for (let i = 0; i < 2; i++) {
    if (!out.includes('%')) break;
    try {
      out = decodeURIComponent(out);
    } catch (e) {
      break;
    }
  }
  return out;
}

function matchGroup(text: string, reg: RegExp): string | undefined {
  const match = reg.exec(text);
  return match?.[1];
}
