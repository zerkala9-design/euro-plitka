// @ts-check
import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://euro-plitka.com.ua',
  integrations: [
    sitemap({
      i18n: {
        defaultLocale: 'uk',
        locales: {
          uk: 'uk-UA',
          ru: 'ru-RU',
        },
      },
    }),
  ],
  build: { format: 'directory' },
});
