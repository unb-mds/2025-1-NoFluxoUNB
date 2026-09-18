import adapter from '@sveltejs/adapter-static';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/kit').Config} */
const config = {
	preprocess: vitePreprocess(),

	kit: {
		adapter: adapter({
			fallback: 'index.html',
			pages: 'build',
			assets: 'build',
			precompress: true
		}),
		prerender: {
			handleHttpError: 'warn'
		},
		alias: {
			$components: 'src/lib/components',
			$lib: 'src/lib',
			$stores: 'src/lib/stores',
			$types: 'src/lib/types',
			$services: 'src/lib/services',
			$utils: 'src/lib/utils'
		}
	}
};

export default config;
