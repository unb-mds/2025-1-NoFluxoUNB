import { defineConfig } from '@playwright/test';

// Config minima para rodar tests/e2e contra o vite dev server local
export default defineConfig({
	testDir: 'tests/e2e',
	use: {
		baseURL: 'http://localhost:5173'
	},
	webServer: {
		command: 'npx vite dev',
		port: 5173,
		reuseExistingServer: true
	}
});
