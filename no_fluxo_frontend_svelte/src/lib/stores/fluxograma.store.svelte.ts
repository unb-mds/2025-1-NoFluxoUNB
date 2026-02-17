/**
 * Fluxograma store — manages state for the interactive curriculum flowchart.
 * Svelte 5 runes-based store using $state().
 */

import { fluxogramaService } from '$lib/services/fluxograma.service';
import { authStore } from '$lib/stores/auth';
import type { CursoModel } from '$lib/types/curso';
import type { MateriaModel } from '$lib/types/materia';
import {
	SubjectStatusEnum,
	determineSubjectStatus,
	type SubjectStatusValue,
	type OptativaAdicionada
} from '$lib/types/materia';
import {
	getCompletedSubjectCodes,
	getCurrentSubjectCodes,
	type DadosFluxogramaUser,
	findSubjectInFluxograma
} from '$lib/types/user';
import { getSubjectsBySemester } from '$lib/types/curso';
import { captureScreenshot } from '$lib/utils/screenshot';
import { toast } from 'svelte-sonner';

export interface FluxogramaState {
	courseData: CursoModel | null;
	loading: boolean;
	error: string | null;
	zoomLevel: number;
	showConnections: boolean;
	isAnonymous: boolean;
	hoveredSubjectCode: string | null;
	selectedSubjectCode: string | null;
}

const MIN_ZOOM = 0.3;
const MAX_ZOOM = 2.0;
const ZOOM_STEP = 0.1;

function createFluxogramaStore() {
	let state = $state<FluxogramaState>({
		courseData: null,
		loading: false,
		error: null,
		zoomLevel: 0.75,
		showConnections: false,
		isAnonymous: false,
		hoveredSubjectCode: null,
		selectedSubjectCode: null
	});

	let optativasAdicionadas = $state<OptativaAdicionada[]>([]);

	const optativasBySemester = $derived.by(() => {
		const map = new Map<number, OptativaAdicionada[]>();
		for (const opt of optativasAdicionadas) {
			if (!map.has(opt.semestre)) {
				map.set(opt.semestre, []);
			}
			map.get(opt.semestre)!.push(opt);
		}
		return map;
	});

	// Computed: subjects grouped by semester
	const subjectsBySemester = $derived.by(() => {
		if (!state.courseData) return new Map<number, MateriaModel[]>();
		return getSubjectsBySemester(state.courseData);
	});

	// Computed: user progress data
	const userFluxograma = $derived.by(() => {
		const user = authStore.getUser();
		return user?.dadosFluxograma ?? null;
	});

	// Computed: completed subject codes
	const completedCodes = $derived.by(() => {
		if (!userFluxograma) return new Set<string>();
		return getCompletedSubjectCodes(userFluxograma);
	});

	// Computed: current subject codes
	const currentCodes = $derived.by(() => {
		if (!userFluxograma) return new Set<string>();
		return getCurrentSubjectCodes(userFluxograma);
	});

	// Computed: failed subject codes
	const failedCodes = $derived.by(() => {
		if (!userFluxograma) return new Set<string>();
		const failed = new Set<string>();
		for (const semester of userFluxograma.dadosFluxograma) {
			for (const materia of semester) {
				if (materia.status === 'REP') {
					failed.add(materia.codigoMateria);
				}
			}
		}
		return failed;
	});

	return {
		get state() {
			return state;
		},
		get subjectsBySemester() {
			return subjectsBySemester;
		},
		get userFluxograma() {
			return userFluxograma;
		},
		get completedCodes() {
			return completedCodes;
		},
		get currentCodes() {
			return currentCodes;
		},
		get failedCodes() {
			return failedCodes;
		},
		get optativasAdicionadas() {
			return optativasAdicionadas;
		},
		get optativasBySemester() {
			return optativasBySemester;
		},

		getSubjectStatus(materia: MateriaModel): SubjectStatusValue {
			if (state.isAnonymous || !userFluxograma) {
				return SubjectStatusEnum.NOT_STARTED;
			}
			return determineSubjectStatus(materia, completedCodes, currentCodes, failedCodes);
		},

		getSubjectUserData(codigoMateria: string) {
			if (!userFluxograma) return null;
			return findSubjectInFluxograma(userFluxograma, codigoMateria);
		},

		addOptativa(materia: MateriaModel, semestre: number) {
			const exists = optativasAdicionadas.some(
				(o) => o.materia.codigoMateria === materia.codigoMateria
			);
			if (exists) {
				toast.warning('Esta optativa já foi adicionada.');
				return;
			}
			optativasAdicionadas = [...optativasAdicionadas, { materia, semestre }];
			toast.success(`${materia.nomeMateria} adicionada ao ${semestre}º semestre.`);
		},

		removeOptativa(codigoMateria: string) {
			const opt = optativasAdicionadas.find(
				(o) => o.materia.codigoMateria === codigoMateria
			);
			optativasAdicionadas = optativasAdicionadas.filter(
				(o) => o.materia.codigoMateria !== codigoMateria
			);
			if (opt) {
				toast.success(`${opt.materia.nomeMateria} removida.`);
			}
		},

		async loadCourseData(courseName: string, anonymous = false) {
			state.loading = true;
			state.error = null;
			state.isAnonymous = anonymous;

			try {
				const data = await fluxogramaService.getCourseData(courseName);
				state.courseData = data;
			} catch (err) {
				const message =
					err instanceof Error ? err.message : 'Erro ao carregar dados do curso';
				state.error = message;
				toast.error(message);
			} finally {
				state.loading = false;
			}
		},

		setZoom(level: number) {
			state.zoomLevel = Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, level));
		},

		zoomIn() {
			this.setZoom(state.zoomLevel + ZOOM_STEP);
		},

		zoomOut() {
			this.setZoom(state.zoomLevel - ZOOM_STEP);
		},

		resetZoom() {
			state.zoomLevel = 0.75;
		},

		toggleConnections() {
			state.showConnections = !state.showConnections;
		},

		setHoveredSubject(code: string | null) {
			state.hoveredSubjectCode = code;
		},

		setSelectedSubject(code: string | null) {
			state.selectedSubjectCode = code;
		},

		async saveScreenshot(container: HTMLElement | null) {
			if (!container) {
				toast.error('Elemento do fluxograma não encontrado.');
				return;
			}
			try {
				const courseName = state.courseData?.nomeCurso ?? 'fluxograma';
				const filename = `${courseName.replace(/\s+/g, '_')}.png`;
				await captureScreenshot(container, filename);
				toast.success('Screenshot salvo com sucesso!');
			} catch {
				toast.error('Não foi possível capturar a imagem.');
			}
		},

		reset() {
			state.courseData = null;
			state.loading = false;
			state.error = null;
			state.zoomLevel = 0.75;
			state.showConnections = false;
			state.isAnonymous = false;
			state.hoveredSubjectCode = null;
			state.selectedSubjectCode = null;
			optativasAdicionadas = [];
		}
	};
}

export const fluxogramaStore = createFluxogramaStore();
