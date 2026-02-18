<!--
  Graffiti background matching Flutter's graffiti_background.dart
  Multi-stop gradient + brick wall pattern overlay.
-->
<div class="graffiti-bg" aria-hidden="true">
	<div class="graffiti-gradient"></div>
	<div class="brick-overlay"></div>
</div>

<style>
	.graffiti-bg {
		position: fixed;
		inset: 0;
		z-index: -1;
		overflow: hidden;
	}

	.graffiti-gradient {
		position: absolute;
		inset: 0;
		background: linear-gradient(
			180deg,
			#9333ea 0%,
			#e11d48 30%,
			#ea580c 50%,
			#ca8a04 70%,
			#000000 100%
		);
	}

	/* Brick wall pattern overlay using repeating-linear-gradient */
	.brick-overlay {
		position: absolute;
		inset: 0;
		background-image:
			/* Horizontal mortar lines */
			repeating-linear-gradient(
				0deg,
				transparent,
				transparent 29px,
				rgba(255, 255, 255, 0.13) 29px,
				rgba(255, 255, 255, 0.13) 30px
			),
			/* Vertical mortar lines - odd rows */
			repeating-linear-gradient(
				90deg,
				transparent,
				transparent 59px,
				rgba(255, 255, 255, 0.1) 59px,
				rgba(255, 255, 255, 0.1) 60px
			);
		background-size:
			60px 30px,
			60px 60px;
		/* Offset every other row of bricks */
		background-position:
			0 0,
			30px 30px;
		opacity: 0.5;
	}
</style>
