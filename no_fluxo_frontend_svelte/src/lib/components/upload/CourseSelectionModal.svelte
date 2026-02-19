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
								{curso.nome_curso}{#if curso.matriz_curricular}
									<span class="text-gray-400"> — {curso.matriz_curricular}</span>
								{/if}
							</span>
						</label>
					{/each}
				</div>
			</div>

			<!-- Footer -->
			<div class="flex gap-3 border-t border-white/10 px-6 py-4">
				<button
					type="button"
					class="flex-1 rounded-lg border border-white/10 px-4 py-2.5 text-sm font-medium text-gray-300 transition-colors hover:bg-white/10"
					onclick={onclose}
				>
					Cancelar
				</button>
				<button
					type="button"
					class="confirm-btn flex-1"
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
	@reference 'tailwindcss';

	.overlay {
		@apply fixed inset-0 z-50 flex items-center justify-center p-4;
		background: rgba(0, 0, 0, 0.7);
		backdrop-filter: blur(4px);
	}

	.modal {
		@apply w-full max-w-md overflow-hidden rounded-2xl;
		background: rgba(30, 30, 30, 0.95);
		border: 1px solid rgba(255, 255, 255, 0.1);
		box-shadow: 0 25px 50px rgba(0, 0, 0, 0.5);
	}

	.course-option {
		@apply flex cursor-pointer items-center gap-3 rounded-lg border border-white/5 px-4 py-3 transition-all;
		background: rgba(255, 255, 255, 0.03);
	}

	.course-option:hover {
		@apply border-purple-500/30;
		background: rgba(139, 92, 246, 0.05);
	}

	.course-option.selected {
		@apply border-purple-500/50;
		background: rgba(139, 92, 246, 0.1);
	}

	.radio-dot {
		@apply h-4 w-4 shrink-0 rounded-full border-2 border-gray-500 transition-all;
	}

	.radio-dot.active {
		@apply border-purple-400;
		background: #8b5cf6;
		box-shadow: 0 0 0 2px rgba(139, 92, 246, 0.3);
	}

	.confirm-btn {
		@apply rounded-lg px-4 py-2.5 text-sm font-medium text-white transition-all;
		background: linear-gradient(135deg, #6c63ff, #e91e63);
	}

	.confirm-btn:disabled {
		@apply cursor-not-allowed opacity-40;
	}

	.confirm-btn:not(:disabled):hover {
		box-shadow: 0 4px 15px rgba(108, 99, 255, 0.3);
	}
</style>
