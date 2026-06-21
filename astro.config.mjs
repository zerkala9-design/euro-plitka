// @ts-check
import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://euro-plitka.com.ua',
  integrations: [sitemap()],
  build: { format: 'directory' },
});
