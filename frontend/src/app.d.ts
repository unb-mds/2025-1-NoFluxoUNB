declare global {
	namespace App {
		// No server-side locals — all auth is handled client-side
		interface PageData {}
	}
}

export { };
