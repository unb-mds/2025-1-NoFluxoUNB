<script lang="ts">
	interface Props {
		text?: string;
		name?: string;
	}
	let { text = 'Processando...', name = 'Darcy AI' }: Props = $props();
</script>

<div class="flex flex-col items-start mb-4 relative z-10">
	{#if name}
		<span class="text-[10px] font-medium text-white/40 mb-1.5 px-1 uppercase tracking-widest">{name}</span>
	{/if}
	<div class="max-w-[85%] px-5 py-4 bg-black/30 backdrop-blur-xl border border-white/10 rounded-[24px] rounded-tl-[8px] shadow-lg flex items-center gap-3">
		<div class="liquid-loader shrink-0 shadow-lg scale-75 origin-left">
			<div class="liquid-blob-1"></div>
			<div class="liquid-blob-2"></div>
		</div>
		<span class="text-[13px] text-white/50 animate-pulse font-medium">{text}</span>
	</div>
</div>

<style>
	.liquid-loader {
		position: relative;
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 50%;
		overflow: hidden;
		background-color: transparent;
	}
	.liquid-blob-1 {
		position: absolute;
		width: 24px;
		height: 24px;
		background: #8b5cf6;
		border-radius: 40% 60% 70% 30% / 40% 50% 60% 50%;
		animation: liquidMix 3s linear infinite;
		filter: blur(5px);
		mix-blend-mode: screen;
		opacity: 0.8;
	}
	.liquid-blob-2 {
		position: absolute;
		width: 24px;
		height: 24px;
		background: #3b82f6;
		border-radius: 60% 40% 30% 70% / 60% 30% 70% 40%;
		animation: liquidMixReverse 4s linear infinite;
		filter: blur(5px);
		mix-blend-mode: screen;
		opacity: 0.8;
	}
	@keyframes liquidMix {
		0% { transform: rotate(0deg) scale(1) translate(-2px, -2px); }
		50% { transform: rotate(180deg) scale(1.3) translate(2px, 2px); }
		100% { transform: rotate(360deg) scale(1) translate(-2px, -2px); }
	}
	@keyframes liquidMixReverse {
		0% { transform: rotate(360deg) scale(1) translate(2px, 2px); }
		50% { transform: rotate(180deg) scale(1.3) translate(-2px, -2px); }
		100% { transform: rotate(0deg) scale(1) translate(2px, 2px); }
	}
</style>
