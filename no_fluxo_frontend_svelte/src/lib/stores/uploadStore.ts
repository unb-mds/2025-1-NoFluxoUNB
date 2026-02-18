import { writable, get } from 'svelte/store';
import { goto } from '$app/navigation';
import { toast } from 'svelte-sonner';
import {
	uploadService,
	type UploadPdfResponse,
	type CasarDisciplinasResponse,
	type CourseSelectionError
} from '$lib/services/upload.service';
import { authStore } from '$lib/stores/auth';
import { ROUTES } from '$lib/config/routes';

export type UploadState = 'initial' | 'uploading' | 'processing' | 'success' | 'error';

export interface UploadStoreState {
	state: UploadState;
	progress: number;
	fileName: string;
	error: string | null;
	extractedData: UploadPdfResponse | null;
	disciplinasCasadas: CasarDisciplinasResponse | null;
	courseSelectionError: CourseSelectionError | null;
	showCourseSelection: boolean;
}

const initialState: UploadStoreState = {
	state: 'initial',
	progress: 0,
	fileName: '',
	error: null,
	extractedData: null,
	disciplinasCasadas: null,
	courseSelectionError: null,
	showCourseSelection: false
};

function createUploadStore() {
	const { subscribe, set, update } = writable<UploadStoreState>({ ...initialState });

	let progressInterval: ReturnType<typeof setInterval> | null = null;

	function startProgressSimulation(from: number, to: number, durationMs: number) {
		stopProgressSimulation();
		const steps = Math.floor(durationMs / 100);
		const increment = (to - from) / steps;
		let current = from;

		progressInterval = setInterval(() => {
			current = Math.min(current + increment, to);
			update((s) => ({ ...s, progress: Math.round(current) }));
			if (current >= to) {
				stopProgressSimulation();
			}
		}, 100);
	}

	function stopProgressSimulation() {
		if (progressInterval) {
			clearInterval(progressInterval);
			progressInterval = null;
		}
	}

	return {
		subscribe,

		async uploadFile(file: File) {
			update((s) => ({
				...s,
				state: 'uploading',
				progress: 0,
				fileName: file.name,
				error: null,
				extractedData: null,
				disciplinasCasadas: null,
				courseSelectionError: null,
				showCourseSelection: false
			}));

			try {
				// Phase 1: Parse PDF locally in the browser (0-50%)
				startProgressSimulation(0, 45, 3000);
				const extracted = await uploadService.parsePdfLocally(file);
				stopProgressSimulation();
				update((s) => ({ ...s, progress: 50, extractedData: extracted }));

				// Phase 2: Match disciplines (50-90%)
				update((s) => ({ ...s, state: 'processing' }));
				startProgressSimulation(50, 85, 4000);
				const result = await uploadService.casarDisciplinas(extracted);
				stopProgressSimulation();

				// Check for course selection needed
				if ('type' in result && result.type === 'COURSE_SELECTION') {
					update((s) => ({
						...s,
						progress: 60,
						state: 'processing',
						courseSelectionError: result as CourseSelectionError,
						showCourseSelection: true
					}));
					return;
				}

				// Success
				update((s) => ({
					...s,
					progress: 100,
					state: 'success',
					disciplinasCasadas: result as CasarDisciplinasResponse
				}));
				toast.success('Histórico processado com sucesso!');
			} catch (err) {
				stopProgressSimulation();
				const message = err instanceof Error ? err.message : 'Erro desconhecido ao processar o PDF.';
				update((s) => ({
					...s,
					state: 'error',
					error: message
				}));
				toast.error(message);
			}
		},

		async retryWithSelectedCourse(courseName: string) {
			const currentState = get({ subscribe });
			if (!currentState.extractedData) {
				toast.error('Dados do PDF não encontrados. Tente novamente.');
				return;
			}

			update((s) => ({
				...s,
				showCourseSelection: false,
				state: 'processing',
				progress: 55,
				error: null
			}));

			try {
				startProgressSimulation(55, 85, 3000);
				const dataWithCourse = {
					...currentState.extractedData,
					curso_selecionado: courseName
				};
				const result = await uploadService.casarDisciplinas(dataWithCourse);
				stopProgressSimulation();

				if ('type' in result && result.type === 'COURSE_SELECTION') {
					update((s) => ({
						...s,
						courseSelectionError: result as CourseSelectionError,
						showCourseSelection: true,
						progress: 60
					}));
					return;
				}

				update((s) => ({
					...s,
					progress: 100,
					state: 'success',
					disciplinasCasadas: result as CasarDisciplinasResponse
				}));
				toast.success('Histórico processado com sucesso!');
			} catch (err) {
				stopProgressSimulation();
				const message = err instanceof Error ? err.message : 'Erro ao processar disciplinas.';
				update((s) => ({
					...s,
					state: 'error',
					error: message
				}));
				toast.error(message);
			}
		},

		async saveAndNavigate() {
			const currentState = get({ subscribe });
			const user = authStore.getUser();

			if (!currentState.disciplinasCasadas || !user) {
				toast.error('Dados insuficientes para salvar.');
				return;
			}

			try {
				await uploadService.saveFluxogramaToDB(
					user.idUser,
					currentState.disciplinasCasadas,
					currentState.extractedData?.numero_semestre ?? undefined
				);

				// Update auth store with fluxograma data
				authStore.updateDadosFluxograma({
					nomeCurso: currentState.extractedData?.curso_extraido ?? '',
					ira: currentState.disciplinasCasadas.dados_validacao?.ira ?? 0,
					matricula: currentState.extractedData?.matricula ?? '',
					horasIntegralizadas: currentState.disciplinasCasadas.dados_validacao?.horas_integralizadas ?? 0,
					suspensoes: currentState.extractedData?.suspensoes ?? [],
					anoAtual: currentState.extractedData?.semestre_atual ?? '',
					matrizCurricular: currentState.extractedData?.matriz_curricular ?? '',
					semestreAtual: currentState.extractedData?.numero_semestre ?? 0,
					dadosFluxograma: []
				});

				toast.success('Fluxograma salvo com sucesso!');
				goto(ROUTES.MEU_FLUXOGRAMA);
			} catch (err) {
				const message = err instanceof Error ? err.message : 'Erro ao salvar fluxograma.';
				toast.error(message);
			}
		},

		dismissCourseSelection() {
			update((s) => ({
				...s,
				showCourseSelection: false,
				state: 'error',
				error: 'Seleção de curso cancelada. Tente novamente.'
			}));
		},

		reset() {
			stopProgressSimulation();
			set({ ...initialState });
		}
	};
}

export const uploadStore = createUploadStore();
