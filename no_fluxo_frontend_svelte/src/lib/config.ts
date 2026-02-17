import {
	PUBLIC_API_URL,
	PUBLIC_AGENT_URL,
	PUBLIC_REDIRECT_URL,
	PUBLIC_ENVIRONMENT
} from '$env/static/public';

export const config = {
	apiUrl: PUBLIC_API_URL || 'http://localhost:3000',
	agentUrl: PUBLIC_AGENT_URL || 'http://localhost:4652',
	redirectUrl: PUBLIC_REDIRECT_URL || 'http://localhost:5173',
	isDev: PUBLIC_ENVIRONMENT !== 'production',
	isProd: PUBLIC_ENVIRONMENT === 'production'
} as const;

export default config;
