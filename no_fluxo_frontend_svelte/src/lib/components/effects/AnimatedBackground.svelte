<!--
  Fundo área logada — mesma linguagem que a home (malha + halos), sem animações multicolor.
-->
<div class="nofluxo-bg" aria-hidden="true">
	<div class="nofluxo-bg-mesh"></div>
	<div class="nofluxo-bg-glow nw"></div>
	<div class="nofluxo-bg-glow se"></div>
</div>

<style>
	.nofluxo-bg {
		position: fixed;
		inset: 0;
		z-index: -1;
		overflow: hidden;
		background: #050505;
	}

	.nofluxo-bg-mesh {
		position: absolute;
		inset: 0;
		opacity: 0.85;
		background-image:
			linear-gradient(hsl(0 0% 100% / 0.016) 1px, transparent 1px),
			linear-gradient(90deg, hsl(0 0% 100% / 0.016) 1px, transparent 1px);
		background-size: 56px 56px;
		mask-image: radial-gradient(ellipse 85% 70% at 50% 45%, hsl(0 0% 0% / 0.5), transparent 100%);
		-webkit-mask-image: radial-gradient(
			ellipse 85% 70% at 50% 45%,
			hsl(0 0% 0% / 0.5),
			transparent 100%
		);
	}

	.nofluxo-bg-glow {
		position: absolute;
		pointer-events: none;
		width: 65%;
		height: 60%;
		filter: blur(110px);
		opacity: 0.22;
		border-radius: 50%;
		background: hsl(var(--primary) / 0.45);
	}

	.nofluxo-bg-glow.nw {
		top: -18%;
		left: -14%;
	}

	.nofluxo-bg-glow.se {
		bottom: -24%;
		right: -16%;
		opacity: 0.18;
	}
</style>
