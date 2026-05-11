<!--
  Fundo identidade NOFLX: base profunda, halos roxos suaves, malha técnica quase imperceptível.
-->
<div class="nofluxo-bg" aria-hidden="true">
	<div class="nofluxo-bg-glow-main"></div>
	<div class="nofluxo-bg-glow-deep"></div>
	<div class="nofluxo-bg-mesh"></div>
</div>

<style>
	.nofluxo-bg {
		position: fixed;
		inset: 0;
		z-index: 0;
		overflow: hidden;
		pointer-events: none;
		background: rgb(8, 8, 15);
	}

	.nofluxo-bg-glow-main {
		position: absolute;
		top: -180px;
		left: -180px;
		width: 900px;
		height: 900px;
		border-radius: 50%;
		pointer-events: none;
		background: radial-gradient(
			circle,
			rgba(108, 38, 220, 0.38) 0%,
			rgba(88, 22, 180, 0.16) 40%,
			transparent 68%
		);
	}

	.nofluxo-bg-glow-deep {
		position: absolute;
		bottom: -100px;
		left: -80px;
		width: 500px;
		height: 500px;
		border-radius: 50%;
		pointer-events: none;
		background: radial-gradient(
			circle,
			rgba(80, 20, 160, 0.22) 0%,
			transparent 65%
		);
	}

	/* Grade sobre os glows — não compete com a luz */
	.nofluxo-bg-mesh {
		position: absolute;
		inset: 0;
		z-index: 1;
		pointer-events: none;
		opacity: 0.05;
		background-image:
			linear-gradient(rgba(255, 255, 255, 0.04) 1px, transparent 1px),
			linear-gradient(90deg, rgba(255, 255, 255, 0.04) 1px, transparent 1px);
		background-size: 56px 56px;
		mask-image: radial-gradient(
			ellipse 85% 70% at 50% 45%,
			rgba(0, 0, 0, 0.55),
			transparent 100%
		);
		-webkit-mask-image: radial-gradient(
			ellipse 85% 70% at 50% 45%,
			rgba(0, 0, 0, 0.55),
			transparent 100%
		);
	}
</style>
