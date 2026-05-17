<script lang="ts">
	import { X } from 'lucide-svelte';
	import { clickOutside } from '$lib/actions/clickOutside';
	import { fade, fly } from 'svelte/transition';
	import type { CourseSelectionError } from '$lib/services/upload.service';

	interface SelectedCourse {
		nome_curso: string;
		id_curso?: number;
		matriz_curricular?: string;
	}

	interface Props {
		open: boolean;
		courseError: CourseSelectionError;
		onselect: (courseName: string, selected?: SelectedCourse) => void;
		onclose: () => void;
	}

	let { open, courseError, onselect, onclose }: Props = $props();

	let selectedCourse = $state<SelectedCourse | null>(null);

	function handleConfirm() {
		if (selectedCourse) {
			onselect(selectedCourse.nome_curso, selectedCourse);
		}
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') onclose();
	}
</script>

{#if open}
	<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
	<div
		class="overlay"
		role="dialog"
		aria-modal="true"
		aria-label="Selecionar curso"
		transition:fade={{ duration: 200 }}
		onkeydown={handleKeydown}
	>
		<div
			class="modal"
			use:clickOutside={{ onClickOutside: onclose }}
			transition:fly={{ y: 30, duration: 250 }}
		>
			<!-- Header -->
			<div class="border-b border-white/10 px-6 py-4">
				<h2 class="text-lg font-bold text-white">Selecionar Curso</h2>
				<p class="mt-1 text-sm text-gray-400">
					{courseError.message || 'Encontramos mais de um curso possível. Selecione o correto:'}
				</p>
			</div>

			<!-- Course List -->
			<div class="max-h-64 overflow-y-auto px-6 py-4">
				<div class="space-y-2">
					{#each courseError.cursos_disponiveis as curso}
						{@const option = { nome_curso: curso.nome_curso, id_curso: curso.id_curso, matriz_curricular: curso.matriz_curricular }}
						{@const optionKey = curso.id_curso != null ? String(curso.id_curso) : `${curso.nome_curso}|${curso.matriz_curricular ?? ''}`}
						<label
							class="course-option"
							class:selected={selectedCourse?.id_curso === curso.id_curso || (selectedCourse?.nome_curso === curso.nome_curso && selectedCourse?.matriz_curricular === curso.matriz_curricular)}
						>
							<input
								type="radio"
								name="course"
								value={optionKey}
								class="sr-only"
								checked={selectedCourse?.id_curso === curso.id_curso || (selectedCourse?.nome_curso === curso.nome_curso && selectedCourse?.matriz_curricular === curso.matriz_curricular)}
								onchange={() => selectedCourse = option}
							/>
							<div
								class="radio-dot"
								class:active={selectedCourse?.id_curso === curso.id_curso || (selectedCourse?.nome_curso === curso.nome_curso && selectedCourse?.matriz_curricular === curso.matriz_curricular)}
							></div>
							<span class="text-sm text-gray-200">
								{curso.nome_curso}{#if curso.turno}
									<span class="text-gray-500"> ({curso.turno === 'NOTURNO' ? 'Noturno' : curso.turno === 'DIURNO' ? 'Diurno' : curso.turno})</span>
								{/if}{#if curso.matriz_curricular}
									<span class="text-gray-400"> — {curso.matriz_curricular}</span>
								{/if}
							</span>
						</label>
					{/each}
				</div>
			</div>

			<!-- Footer -->
			<div class="flex gap-3 border-t border-white/10 px-6 py-4">
				<button type="button" class="cancel-btn flex-1" onclick={onclose}>Cancelar</button>
				<button
					type="button"
					class="confirm-btn"
					disabled={!selectedCourse}
					onclick={handleConfirm}
				>
					Confirmar
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.overlay {
		position: fixed;
		inset: 0;
		z-index: 50;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 1rem;
		background: hsl(0 0% 0% / 0.72);
		backdrop-filter: blur(8px);
		-webkit-backdrop-filter: blur(8px);
	}

	.modal {
		width: 100%;
		max-width: 28rem;
		overflow: hidden;
		border-radius: 1.125rem;
		background: hsl(var(--card) / 0.97);
		border: 1px solid hsl(0 0% 100% / 0.058);
		box-shadow:
			inset 0 1px 0 hsl(0 0% 100% / 0.052),
			0 0 0 1px hsl(var(--primary) / 0.06),
			0 28px 64px hsl(0 0% 0% / 0.5);
	}

	.course-option {
		display: flex;
		cursor: pointer;
		align-items: center;
		gap: 0.75rem;
		border-radius: var(--radius, 10px);
		border: 1px solid hsl(0 0% 100% / 0.06);
		background: hsl(0 0% 100% / 0.03);
		padding: 0.85rem 1rem;
		transition:
			border-color 0.16s ease,
			background 0.16s ease;
	}

	.course-option:hover {
		border-color: hsl(var(--primary) / 0.28);
		background: hsl(var(--primary) / 0.07);
	}

	.course-option.selected {
		border-color: hsl(var(--primary) / 0.42);
		background: hsl(var(--primary) / 0.11);
	}

	.radio-dot {
		height: 1rem;
		width: 1rem;
		flex-shrink: 0;
		border-radius: 9999px;
		border: 2px solid hsl(var(--muted-foreground));
		transition:
			border-color 0.16s ease,
			background 0.16s ease,
			box-shadow 0.16s ease;
	}

	.radio-dot.active {
		border-color: hsl(var(--primary));
		background: hsl(var(--primary));
		box-shadow: 0 0 0 2px hsl(var(--primary) / 0.25);
	}

	.cancel-btn {
		cursor: pointer;
		flex: 1;
		border-radius: var(--radius, 10px);
		border: 1px solid hsl(0 0% 100% / 0.1);
		padding: 0.625rem 1rem;
		font-size: 0.875rem;
		font-weight: 600;
		color: hsl(var(--foreground) / 0.82);
		background: transparent;
		transition: background 0.16s ease;
	}

	.cancel-btn:hover {
		background: hsl(0 0% 100% / 0.06);
	}

	.confirm-btn {
		flex: 1;
		cursor: pointer;
		border-radius: var(--radius, 10px);
		border: none;
		padding: 0.625rem 1rem;
		font-size: 0.875rem;
		font-weight: 600;
		color: hsl(var(--primary-foreground));
		background: hsl(var(--primary));
		box-shadow:
			0 1px 0 hsl(0 0% 100% / 0.1) inset,
			0 10px 32px hsl(var(--primary) / 0.2);
		transition:
			filter 0.18s ease,
			box-shadow 0.18s ease;
	}

	.confirm-btn:disabled {
		cursor: not-allowed;
		opacity: 0.42;
	}

	.confirm-btn:not(:disabled):hover {
		filter: brightness(1.04);
	}
</style>
