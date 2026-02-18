<script lang="ts">
	interface Props {
		name: string;
		githubUsername: string;
	}

	let { name, githubUsername }: Props = $props();
	let isHovered = $state(false);
	let imageError = $state(false);

	const avatarUrl = `https://avatars.githubusercontent.com/${githubUsername}`;
</script>

<div
	onmouseenter={() => (isHovered = true)}
	onmouseleave={() => (isHovered = false)}
	class="team-card"
	style="transform: scale({isHovered ? 1.05 : 1});"
>
	<div class="team-avatar-wrap">
		{#if imageError}
			<div class="w-full h-full flex items-center justify-center bg-gray-700 rounded-full">
				<svg class="w-8 h-8 text-white" fill="currentColor" viewBox="0 0 20 20">
					<path
						fill-rule="evenodd"
						d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z"
						clip-rule="evenodd"
					/>
				</svg>
			</div>
		{:else}
			<img
				src={avatarUrl}
				alt={name}
				class="team-avatar"
				loading="lazy"
				onerror={() => (imageError = true)}
			/>
		{/if}
	</div>

	<h4 class="team-name">{name}</h4>
	<span class="team-role">Desenvolvedor</span>
</div>

<style>
	.team-card {
		background: rgba(255, 255, 255, 0.1);
		border: 1px solid rgba(255, 255, 255, 0.1);
		border-radius: 12px;
		padding: 1rem 1rem 1.25rem;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		transition: transform 0.2s ease;
	}

	.team-avatar-wrap {
		width: 100px;
		height: 100px;
		margin-bottom: 1rem;
	}

	.team-avatar {
		width: 100%;
		height: 100%;
		border-radius: 50%;
		object-fit: cover;
		background: #374151;
	}

	.team-name {
		font-family: 'Permanent Marker', cursive;
		color: white;
		font-size: clamp(0.875rem, 2vw, 1.25rem);
		text-align: center;
		margin-bottom: 0.25rem;
	}

	.team-role {
		color: #aeadad;
		font-size: clamp(0.75rem, 1.5vw, 1rem);
		letter-spacing: 0.5px;
	}
</style>
