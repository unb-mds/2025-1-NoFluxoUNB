<!--
  Animated smoke background matching Flutter's animated_background.dart
  Floating blurred color blobs on solid black background.
-->
<div class="smoke-bg" aria-hidden="true">
	<div class="blob blob-1"></div>
	<div class="blob blob-2"></div>
	<div class="blob blob-3"></div>
	<div class="blob blob-4"></div>
	<div class="blob blob-5"></div>
</div>

<style>
	.smoke-bg {
		position: fixed;
		inset: 0;
		z-index: -1;
		background: #000000;
		overflow: hidden;
	}

	.blob {
		position: absolute;
		border-radius: 50%;
		opacity: 0.5;
	}

	/* Purple blob - top left drift */
	.blob-1 {
		width: 400px;
		height: 400px;
		background: #6b19c9;
		filter: blur(100px);
		top: 10%;
		left: 15%;
		animation: drift1 42s ease-in-out infinite alternate;
	}

	/* Pink blob - center right drift */
	.blob-2 {
		width: 350px;
		height: 350px;
		background: #e63783;
		filter: blur(110px);
		top: 40%;
		right: 10%;
		animation: drift2 38s ease-in-out infinite alternate;
	}

	/* Yellow blob - bottom center */
	.blob-3 {
		width: 300px;
		height: 300px;
		background: #f0c419;
		filter: blur(120px);
		bottom: 15%;
		left: 40%;
		opacity: 0.45;
		animation: drift3 50s ease-in-out infinite alternate;
	}

	/* Blue blob - top right */
	.blob-4 {
		width: 280px;
		height: 280px;
		background: #3b82f6;
		filter: blur(90px);
		top: 5%;
		right: 25%;
		opacity: 0.4;
		animation: drift4 55s ease-in-out infinite alternate;
	}

	/* Red blob - bottom left */
	.blob-5 {
		width: 320px;
		height: 320px;
		background: #e11d48;
		filter: blur(100px);
		bottom: 10%;
		left: 10%;
		opacity: 0.35;
		animation: drift5 45s ease-in-out infinite alternate;
	}

	@keyframes drift1 {
		0% {
			transform: translate(0, 0) scale(0.95);
			opacity: 0.45;
		}
		33% {
			transform: translate(3%, -4%) scale(1.08);
			opacity: 0.6;
		}
		66% {
			transform: translate(-2%, 3%) scale(1.0);
			opacity: 0.5;
		}
		100% {
			transform: translate(4%, 2%) scale(1.12);
			opacity: 0.7;
		}
	}

	@keyframes drift2 {
		0% {
			transform: translate(0, 0) scale(1.0);
			opacity: 0.5;
		}
		50% {
			transform: translate(-5%, 3%) scale(1.1);
			opacity: 0.65;
		}
		100% {
			transform: translate(2%, -4%) scale(0.95);
			opacity: 0.45;
		}
	}

	@keyframes drift3 {
		0% {
			transform: translate(0, 0) scale(1.0);
			opacity: 0.4;
		}
		50% {
			transform: translate(4%, -3%) scale(1.12);
			opacity: 0.6;
		}
		100% {
			transform: translate(-3%, 5%) scale(0.98);
			opacity: 0.45;
		}
	}

	@keyframes drift4 {
		0% {
			transform: translate(0, 0) scale(0.98);
			opacity: 0.35;
		}
		50% {
			transform: translate(-4%, 5%) scale(1.08);
			opacity: 0.55;
		}
		100% {
			transform: translate(3%, -2%) scale(1.05);
			opacity: 0.4;
		}
	}

	@keyframes drift5 {
		0% {
			transform: translate(0, 0) scale(1.05);
			opacity: 0.3;
		}
		50% {
			transform: translate(5%, -3%) scale(0.95);
			opacity: 0.5;
		}
		100% {
			transform: translate(-2%, 4%) scale(1.1);
			opacity: 0.35;
		}
	}
</style>
