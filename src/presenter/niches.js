// The content lanes the AI presenter rotates through. `searchFocus` steers the trend
// research; `disclaimer` is appended to the spoken script and the post description for
// lanes where viewers could act on the content (money/markets).
const NICHES = {
  ai: {
    label: 'AI & tech',
    searchFocus:
      'AI and consumer tech news from the last 72 hours: new model/tool releases, product launches, notable research, practical how-tos people are searching for',
    disclaimer: null,
  },
  money: {
    label: 'Money & business',
    searchFocus:
      'personal finance, side hustles, small business and entrepreneurship stories trending in the last 72 hours: policy changes, rates, viral business lessons, practical money tips',
    disclaimer: 'This is general education, not financial advice.',
  },
  markets: {
    label: 'Trading & markets',
    searchFocus:
      'stock market, crypto and macro news from the last 72 hours: big movers and why, earnings, Fed/economic data, explainers of concepts traders are searching for',
    disclaimer: 'Not financial advice - do your own research before you trade.',
  },
  food: {
    label: 'Food & restaurant life',
    searchFocus:
      'food and restaurant trends from the last 72 hours: viral dishes and techniques, kitchen hacks, food-safety news, restaurant industry stories',
    disclaimer: null,
  },
};

const ORDER = Object.keys(NICHES);

// Deterministic rotation by day, so a daily run walks through every lane in turn
// without needing stored state. `offset` lets one day produce several different videos.
function nicheForDate(date = new Date(), offset = 0) {
  const day = Math.floor(date.getTime() / 86400000);
  return ORDER[(((day + offset) % ORDER.length) + ORDER.length) % ORDER.length];
}

function resolveNiche(key, date = new Date()) {
  if (!key || key === 'auto') return nicheForDate(date);
  if (!NICHES[key]) {
    throw new Error(`Unknown niche "${key}" - use one of: ${ORDER.join(', ')}, auto`);
  }
  return key;
}

module.exports = { NICHES, ORDER, nicheForDate, resolveNiche };
