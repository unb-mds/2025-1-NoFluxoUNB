<script lang="ts">
	/**
	 * Texto em linha com marquee automático: se couber no maxWidth fica parado;
	 * se estourar, rola em loop contínuo (duas cópias + gap, deslocando -50%).
	 */
	let {
		text,
		maxWidth = 150,
		speed = 14
	}: {
		text: string;
		/** Largura máxima visível, em px. */
		maxWidth?: number;
		/** Velocidade do scroll em px/s. */
		speed?: number;
	} = $props();

	let medidor: HTMLElement | null = $state(null);
	let overflow = $state(false);
	let dur = $state(6);

	$effect(() => {
		void text;
		if (!medidor) return;
		const larguraReal = medidor.scrollWidth;
		overflow = larguraReal > maxWidth;
		if (larguraReal > 0) dur = Math.max(8, (larguraReal + 32) / speed);
	});
</script>

<span class="marquee" style={`max-width: ${maxWidth}px`}>
	<!-- Medidor invisível: sempre uma cópia única, fora do fluxo visual. -->
	<span bind:this={medidor} class="medidor" aria-hidden="true">{text}</span>
	<span class="faixa" class:anima={overflow} style={`animation-duration: ${dur}s`}>
		{text}{#if overflow}<span class="espaco"></span>{text}<span class="espaco"></span>{/if}
	</span>
</span>

<style>
	.marquee {
		position: relative;
		display: inline-block;
		overflow: hidden;
		vertical-align: bottom;
		white-space: nowrap;
	}
	.medidor {
		position: absolute;
		visibility: hidden;
		white-space: nowrap;
		pointer-events: none;
	}
	.faixa {
		display: inline-block;
		white-space: nowrap;
	}
	.anima {
		animation: marquee linear infinite;
	}
	.espaco {
		display: inline-block;
		width: 32px;
	}
	@keyframes marquee {
		from {
			transform: translateX(0);
		}
		to {
			transform: translateX(-50%);
		}
	}
</style>
