import type { RequestHandler } from './$types';

const siteUrl = 'https://nofluxo.unb.br';

const staticRoutes = ['/', '/login', '/signup', '/password-recovery'];

export const GET: RequestHandler = async () => {
	const sitemap = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  ${staticRoutes
		.map(
			(route) => `
  <url>
    <loc>${siteUrl}${route}</loc>
    <lastmod>${new Date().toISOString().split('T')[0]}</lastmod>
    <changefreq>weekly</changefreq>
    <priority>${route === '/' ? '1.0' : '0.8'}</priority>
  </url>`
		)
		.join('')}
</urlset>`;

	return new Response(sitemap.trim(), {
		headers: {
			'Content-Type': 'application/xml',
			'Cache-Control': 'max-age=3600'
		}
	});
};
