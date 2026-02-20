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
import type { DadosMateria, DadosFluxogramaUser } from '$lib/types/user';
import {
	buildDadosFluxogramaUserFromCasarResponse,
	dadosFluxogramaUserToJson
} from '$lib/factories';
import { supabaseDataService } from '$lib/services/supabase-data.service';

export type UploadState = 'initial' | 'uploading' | 'processing' | 'success' | 'error';

/**
 * Convert a CasarDisciplinasResponse into a DadosMateria[][] grouped by ano_periodo (semester).
 * This bridges the discipline-matching output with the fluxograma rendering format.
 */
function convertCasarResponseToDadosFluxograma(
	response: CasarDisciplinasResponse
): DadosMateria[][] {
	const byPeriod = new Map<string, DadosMateria[]>();

	// 1) Map all matched disciplines from the transcript
	for (const disc of response.disciplinas_casadas) {
		// Use the DB-matched code (codigo_materia) if available, else transcript code
		const code = (disc.codigo_materia as string) || (disc.codigo as string) || '';
		if (!code) continue;

		const status = String(disc.status ?? '-');
		const mencao = String(disc.mencao ?? '-');
		const period = String(disc.ano_periodo ?? 'sem_periodo');

		const materia: DadosMateria = {
			codigoMateria: code,
			mencao,
			professor: String(disc.professor ?? ''),
			status,
			anoPeriodo: disc.ano_periodo != null ? String(disc.ano_periodo) : null,
			frequencia: disc.frequencia != null ? String(disc.frequencia) : null,
			tipoDado: disc.tipo_dado != null ? String(disc.tipo_dado) : null,
			turma: disc.turma != null ? String(disc.turma) : null
		};

		if (!byPeriod.has(period)) {
			byPeriod.set(period, []);
		}
		byPeriod.get(period)!.push(materia);
	}

	// 2) Add mandatory subjects completed by equivalency (not already in disciplinas_casadas)
	const existingCodes = new Set<string>();
	for (const arr of byPeriod.values()) {
		for (const m of arr) {
			existingCodes.add(m.codigoMateria);
		}
	}

	for (const matConcluida of response.materias_concluidas) {
		const rec = matConcluida as Record<string, unknown>;
		if (rec.status_fluxograma !== 'concluida_equivalencia') continue;

		const code = String(rec.codigo ?? '');
		if (!code || existingCodes.has(code)) continue;

		const materia: DadosMateria = {
			codigoMateria: code,
			mencao: '-',
			professor: '',
			status: 'CUMP', // Treated as completed via equivalency
			anoPeriodo: null,
			frequencia: null,
			tipoDado: 'equivalencia',
			turma: null
		};

		const period = 'equivalencias';
		if (!byPeriod.has(period)) {
			byPeriod.set(period, []);
		}
		byPeriod.get(period)!.push(materia);
		existingCodes.add(code);
	}

	// 3) Sort periods chronologically and return as nested array
	const sortedPeriods = [...byPeriod.keys()].sort((a, b) => {
		if (a === 'sem_periodo' || a === 'equivalencias') return 1;
		if (b === 'sem_periodo' || b === 'equivalencias') return -1;
		return a.localeCompare(b);
	});

	console.log('[UploadStore] convertCasarResponseToDadosFluxograma:', {
		totalDisciplinasCasadas: response.disciplinas_casadas.length,
		totalEquivalencias: response.materias_concluidas.filter(
			(m) => (m as Record<string, unknown>).status_fluxograma === 'concluida_equivalencia'
		).length,
		periods: sortedPeriods,
		totalDadosMaterias: [...byPeriod.values()].reduce((sum, arr) => sum + arr.length, 0)
	});

	return sortedPeriods.map((period) => byPeriod.get(period)!);
}

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

		async retryWithSelectedCourse(
			courseName: string,
			selected?: { id_curso?: number; nome_curso: string; matriz_curricular?: string }
		) {
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
					curso_selecionado: courseName,
					...(selected?.id_curso != null && { id_curso_selecionado: selected.id_curso })
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
				const cd = currentState.disciplinasCasadas;
				const ext = currentState.extractedData;
				const meta = {
					nomeCurso: ext?.curso_extraido ?? '',
					matricula: ext?.matricula ?? '',
					anoAtual: ext?.semestre_atual ?? '',
					matrizCurricular: ext?.matriz_curricular ?? '',
					semestreAtual: ext?.numero_semestre ?? 0,
					suspensoes: ext?.suspensoes ?? []
				};
				const dados = buildDadosFluxogramaUserFromCasarResponse(
					cd as { disciplinas_casadas: Record<string, unknown>[]; dados_validacao?: { ira?: number; horas_integralizadas?: number } },
					meta
				);

				// Save in the format expected when loading user (snake_case DadosFluxogramaUser)
				await supabaseDataService.saveFluxogramaData(
					user.idUser,
					dadosFluxogramaUserToJson(dados),
					meta.semestreAtual || undefined
				);

				authStore.updateDadosFluxograma(dados);
				toast.success('Fluxograma salvo com sucesso!');
				goto(ROUTES.MEU_FLUXOGRAMA);
			} catch (err) {
				console.error('[UploadStore] saveAndNavigate error:', err);
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
