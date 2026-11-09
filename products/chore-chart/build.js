// Renders chart.html to PDFs (Letter + A4, colour + black-and-white) and a PNG preview.
const { chromium } = require('playwright');
const path = require('path');
const themes = {
  colour: { accent: '#e07a5f', head: '#3d8a8a', band: '#f3f8f6', line: '#cfe0dc', box: '#7fb7a8' },
  bw:     { accent: '#222', head: '#444', band: '#f2f2f2', line: '#bbb', box: '#666' },
};
const sizes = { Letter: ['11in', '8.5in'], A4: ['297mm', '210mm'] };
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto('file://' + path.resolve(__dirname, 'chart.html'));
  await page.waitForTimeout(1500);
  for (const [size, [w, h]] of Object.entries(sizes)) {
    // Page 1 colour, page 2 black-and-white, in one PDF per paper size.
    const html = await page.evaluate(([t1, t2]) => {
      const p = document.querySelector('.page');
      const set = (el, t) => Object.entries(t).forEach(([k, v]) => el.style.setProperty('--' + k, v));
      document.querySelectorAll('.page').forEach((x, i) => i && x.remove());
      set(p, t1); const q = p.cloneNode(true); set(q, t2); p.after(q);
      return true;
    }, [themes.colour, themes.bw]);
    await page.evaluate(([w, h]) => { document.documentElement.style.setProperty('--pw', w); document.documentElement.style.setProperty('--ph', h); }, [w, h]);
    await page.pdf({ path: path.resolve(__dirname, `Weekly-Chore-Chart-${size}.pdf`), preferCSSPageSize: true, printBackground: true });
  }
  await page.setViewportSize({ width: 1056, height: 816 });
  await page.evaluate(() => { document.documentElement.style.setProperty('--pw', '11in'); document.documentElement.style.setProperty('--ph', '8.5in'); });
  await page.locator('.page').first().screenshot({ path: path.resolve(__dirname, 'preview.png') });
  await browser.close();
})();
