import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';
import { SvelteKitPWA } from '@vite-pwa/sveltekit';

export default defineConfig({
	plugins: [
		sveltekit(),
		SvelteKitPWA({
			registerType: 'autoUpdate',
			manifest: {
				name: 'NoFluxo UNB',
				short_name: 'NoFluxo',
				description: 'Organize seu fluxograma acadêmico de forma fácil',
				theme_color: '#09090b',
				background_color: '#09090b',
				display: 'standalone',
				icons: [
					{
						src: 'favicon.svg',
						sizes: '192x192',
						type: 'image/svg+xml'
					},
					{
						src: 'favicon.svg',
						sizes: '512x512',
						type: 'image/svg+xml'
					}
				]
			},
			workbox: {
				globPatterns: ['**/*.{js,css,html,svg,png,woff2}'],
				navigateFallback: '/'
			}
		})
	],
	server: {
		port: 5173,
		strictPort: false,
	},
	preview: {
		port: 4173
	},
	ssr: {
		noExternal: ['@xyflow/svelte']
	}
});
