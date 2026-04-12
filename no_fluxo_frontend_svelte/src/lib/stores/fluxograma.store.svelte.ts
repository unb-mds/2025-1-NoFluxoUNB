/**
 * Fluxograma store — manages state for the interactive curriculum flowchart.
 * Svelte 5 runes-based store using $state().
 */

import { fluxogramaService } from '$lib/services/fluxograma.service';
import { dadosFluxogramaUserToJson } from '$lib/factories';
import { authStore } from '$lib/stores/auth';
import type { CursoModel } from '$lib/types/curso';
import type { MateriaModel } from '$lib/types/materia';
import {
	isOptativa,
	SubjectStatusEnum,
	determineSubjectStatus,
	type SubjectStatusValue,
	type OptativaAdicionada
} from '$lib/types/materia';
import {
	getCompletedSubjectCodes,
	getCurrentSubjectCodes,
	isMateriaAprovada,
	type DadosFluxogramaUser,
	type DadosMateria,
	type OptativaPlanejadaRef,
	findSubjectInFluxograma
} from '$lib/types/user';
import { getCompletedByEquivalenceCodes } from '$lib/types/equivalencia';
import { getSubjectsBySemester } from '$lib/types/curso';
import { captureScreenshot } from '$lib/utils/screenshot';
import { toast } from 'svelte-sonner';
import type { AuthState } from '$lib/types/auth';

export type ConnectionMode = 'off' | 'direct' | 'all';

export type DisplayUnit = 'creditos' | 'horas';

export interface FluxogramaState {
	courseData: CursoModel | null;
	loading: boolean;
	error: string | null;
	zoomLevel: number;
	connectionMode: ConnectionMode;
	/** Exibição das badges por semestre: créditos ou horas */
	displayUnit: DisplayUnit;
	isAnonymous: boolean;
	hoveredSubjectCode: string | null;
	/** No modo "Todas" as conexões: pré-visualização do card sob o rato (clique continua fixando `hoveredSubjectCode`). */
	hoverPreviewSubjectCode: string | null;
	selectedSubjectCode: string | null;
	isCapturingScreenshot: boolean;
}

const MIN_ZOOM = 0.3;
const MAX_ZOOM = 2.0;
const ZOOM_STEP = 0.1;

function hydrateOptativasFromRefs(
	refs: OptativaPlanejadaRef[] | undefined,
	course: CursoModel
): OptativaAdicionada[] {
	if (!refs?.length) return [];
	const byCode = new Map(course.materias.map((m) => [m.codigoMateria.trim().toUpperCase(), m]));
	const out: OptativaAdicionada[] = [];
	const seen = new Set<string>();
	for (const r of refs) {
		const key = r.codigoMateria.trim().toUpperCase();
		if (!key || seen.has(key)) continue;
		seen.add(key);
		const m = byCode.get(key);
		// Ref persistida pelo usuário: não exigir isOptativa aqui — matriz pode vir sem tipo_natureza
		// ou com optativa em nivel>0; senão o planejamento some após recarregar.
		if (m) {
			const sem = Number(r.semestre);
			out.push({ materia: m, semestre: Number.isFinite(sem) && sem >= 1 ? sem : 1 });
		}
	}
	return out;
}

function refsPlanejadasIguais(
	salvas: OptativaPlanejadaRef[] | undefined,
	atual: OptativaAdicionada[]
): boolean {
	const norm = (pairs: { c: string; s: number }[]) =>
		[...pairs].sort((x, y) => x.c.localeCompare(y.c) || x.s - y.s);
	const a = norm(
		(salvas ?? []).map((r) => ({
			c: r.codigoMateria.trim().toUpperCase(),
			s: r.semestre
		}))
	);
	const b = norm(
		atual.map((o) => ({
			c: o.materia.codigoMateria.trim().toUpperCase(),
			s: o.semestre
		}))
	);
	return JSON.stringify(a) === JSON.stringify(b);
}

function createFluxogramaStore() {
	let state = $state<FluxogramaState>({
		courseData: null,
		loading: false,
		error: null,
		zoomLevel: 0.6,
		connectionMode: 'direct' as ConnectionMode,
		displayUnit: 'horas' as DisplayUnit,
		isAnonymous: false,
		hoveredSubjectCode: null,
		hoverPreviewSubjectCode: null,
		selectedSubjectCode: null,
		isCapturingScreenshot: false
	});

	let optativasAdicionadas = $state<OptativaAdicionada[]>([]);
	/** Inclusão manual de optativa concluída no histórico — ainda não enviada ao Supabase. */
	let historicoManualPendenteSalvar = $state(false);

	// Per-semester connection density: semester → connection count
	let connectionDensityBySemester = $state<Map<number, number>>(new Map());

	/** Incrementado ao mudar optativas planejadas ou histórico local — força recálculo das linhas no diagrama. */
	let diagramLayoutRevision = $state(0);
	function bumpDiagramLayout() {
		diagramLayoutRevision += 1;
	}

	// Mirror the Svelte 4 writable authStore into a $state variable so that
	// $derived expressions can reactively track auth changes.
	let authState = $state<AuthState>({
		user: null,
		isAuthenticated: false,
		isAnonymous: false,
		isLoading: true,
		error: null
	});
	authStore.subscribe((value) => {
		authState = value;
	});

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

	/** Código (uppercase) → semestre da optativa planejada (para densidade de linhas; matriz mantém nivel 0). */
	const optativaPlanejadaSemestrePorCodigo = $derived.by(() => {
		const m = new Map<string, number>();
		for (const o of optativasAdicionadas) {
			m.set(o.materia.codigoMateria.trim().toUpperCase(), o.semestre);
		}
		return m;
	});

	const optativasPlanejadasRefs = $derived.by((): OptativaPlanejadaRef[] =>
		optativasAdicionadas.map((o) => ({
			codigoMateria: o.materia.codigoMateria.trim(),
			semestre: o.semestre
		}))
	);

	// Computed: subjects grouped by semester
	const subjectsBySemester = $derived.by(() => {
		if (!state.courseData) return new Map<number, MateriaModel[]>();
		return getSubjectsBySemester(state.courseData);
	});

	// Computed: user progress data (reactive to auth store changes)
	const userFluxograma = $derived.by(() => {
		return authState.user?.dadosFluxograma ?? null;
	});

	const optativasPlanejamentoSalvo = $derived.by(() =>
		refsPlanejadasIguais(userFluxograma?.optativasPlanejadas, optativasAdicionadas)
	);

	const precisaSalvarPerfil = $derived.by(
		() => !optativasPlanejamentoSalvo || historicoManualPendenteSalvar
	);

	/** Disciplinas com `inclusao_manual_optativa` ainda não enviadas (exibe em “Alterações para salvar”). */
	const historicoManualPendenteItens = $derived.by((): { codigoMateria: string; nomeMateria: string }[] => {
		if (!historicoManualPendenteSalvar || !userFluxograma) return [];
		const course = state.courseData;
		const byCode = new Map(
			(course?.materias ?? []).map((m) => [m.codigoMateria.trim().toUpperCase(), m])
		);
		const seen = new Set<string>();
		const out: { codigoMateria: string; nomeMateria: string }[] = [];
		for (const sem of userFluxograma.dadosFluxograma) {
			for (const dm of sem) {
				if (dm.tipoDado !== 'inclusao_manual_optativa') continue;
				if (!isMateriaAprovada(dm)) continue;
				const u = dm.codigoMateria.trim().toUpperCase();
				if (!u || seen.has(u)) continue;
				seen.add(u);
				const m = byCode.get(u);
				out.push({
					codigoMateria: dm.codigoMateria.trim(),
					nomeMateria: m?.nomeMateria ?? dm.codigoMateria.trim()
				});
			}
		}
		return out;
	});

	// Computed: carga horária integralizada do histórico (PDF)
	const cargaHorariaIntegralizada = $derived.by(() => {
		return authState.user?.cargaHorariaIntegralizada ?? null;
	});

	// Computed: completed subject codes (histórico + concluídas por equivalência)
	const completedCodes = $derived.by(() => {
		if (!userFluxograma) return new Set<string>();
		const base = getCompletedSubjectCodes(userFluxograma);
		const courseData = state.courseData;
		const byEquiv =
			courseData?.equivalencias && courseData.equivalencias.length > 0
				? getCompletedByEquivalenceCodes(courseData.equivalencias, base)
				: new Set<string>();
		return new Set([...base, ...byEquiv]);
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
		get cargaHorariaIntegralizada() {
			return cargaHorariaIntegralizada;
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
		get optativaPlanejadaSemestrePorCodigo() {
			return optativaPlanejadaSemestrePorCodigo;
		},
		get optativasPlanejadasRefs() {
			return optativasPlanejadasRefs;
		},
		get optativasPlanejamentoSalvo() {
			return optativasPlanejamentoSalvo;
		},
		get historicoManualPendenteSalvar() {
			return historicoManualPendenteSalvar;
		},
		get historicoManualPendenteItens() {
			return historicoManualPendenteItens;
		},
		get precisaSalvarPerfil() {
			return precisaSalvarPerfil;
		},
		get connectionDensityBySemester() {
			return connectionDensityBySemester;
		},

		get diagramLayoutRevision() {
			return diagramLayoutRevision;
		},

		getSubjectStatus(materia: MateriaModel): SubjectStatusValue {
			if (state.isAnonymous || !userFluxograma) {
				return SubjectStatusEnum.NOT_STARTED;
			}
			return determineSubjectStatus(materia, completedCodes, currentCodes, failedCodes, state.courseData ?? undefined);
		},

		getSubjectUserData(codigoMateria: string) {
			if (!userFluxograma) return null;
			return findSubjectInFluxograma(userFluxograma, codigoMateria);
		},

		addOptativa(materia: MateriaModel, semestre: number) {
			if (!isOptativa(materia)) {
				toast.error('Só matérias optativas da matriz entram neste planejamento.');
				return;
			}
			const codeU = materia.codigoMateria.trim().toUpperCase();
			const exists = optativasAdicionadas.some(
				(o) => o.materia.codigoMateria.trim().toUpperCase() === codeU
			);
			if (exists) {
				toast.warning('Esta optativa já foi adicionada.');
				return;
			}
			optativasAdicionadas = [...optativasAdicionadas, { materia, semestre }];
			bumpDiagramLayout();
			toast.success(`${materia.nomeMateria} adicionada ao ${semestre}º semestre.`);
		},

		registrarOptativaConcluida(materia: MateriaModel) {
			const user = authStore.getUser();
			if (state.isAnonymous || !user?.dadosFluxograma) {
				toast.error('Entre na conta para registrar disciplina concluída.');
				return;
			}
			const st = determineSubjectStatus(
				materia,
				completedCodes,
				currentCodes,
				failedCodes,
				state.courseData ?? undefined
			);
			if (st === SubjectStatusEnum.LOCKED) {
				toast.error(
					'Complete os pré-requisitos desta disciplina (como no fluxograma) antes de registrá-la como concluída.'
				);
				return;
			}
			if (st === SubjectStatusEnum.COMPLETED) {
				toast.warning('Esta disciplina já consta como concluída no seu histórico.');
				return;
			}
			const fluxo = user.dadosFluxograma;
			const codeU = materia.codigoMateria.trim().toUpperCase();

			const nova: DadosMateria = {
				codigoMateria: materia.codigoMateria.trim(),
				mencao: 'MS',
				professor: '-',
				status: 'APR',
				anoPeriodo: fluxo.anoAtual?.trim() ? fluxo.anoAtual : null,
				frequencia: null,
				tipoDado: 'inclusao_manual_optativa',
				turma: null,
				codigoEquivalente: null,
				nomeEquivalente: null
			};
			const nextGrid = fluxo.dadosFluxograma.map((s) => [...s]);
			if (nextGrid.length === 0) nextGrid.push([]);

			let idxAtualizar: { si: number; mi: number } | null = null;
			for (let si = 0; si < nextGrid.length; si++) {
				for (let mi = 0; mi < nextGrid[si].length; mi++) {
					const m = nextGrid[si][mi];
					if (m.codigoMateria.trim().toUpperCase() !== codeU) continue;
					if (isMateriaAprovada(m)) {
						toast.warning('Esta disciplina já consta como concluída no histórico.');
						return;
					}
					idxAtualizar = { si, mi };
					break;
				}
				if (idxAtualizar) break;
			}

			if (idxAtualizar) {
				const { si, mi } = idxAtualizar;
				const old = nextGrid[si][mi];
				nextGrid[si][mi] = {
					...old,
					...nova,
					codigoMateria: old.codigoMateria
				};
			} else {
				nextGrid[0].push(nova);
			}

			const atualizado: DadosFluxogramaUser = { ...fluxo, dadosFluxograma: nextGrid };
			authStore.updateDadosFluxograma(atualizado);
			historicoManualPendenteSalvar = true;
			bumpDiagramLayout();
			toast.success(`${materia.nomeMateria} registrada como concluída — salve para enviar ao servidor.`);
		},

		removeOptativa(codigoMateria: string) {
			const u = codigoMateria.trim().toUpperCase();
			const opt = optativasAdicionadas.find(
				(o) => o.materia.codigoMateria.trim().toUpperCase() === u
			);
			optativasAdicionadas = optativasAdicionadas.filter(
				(o) => o.materia.codigoMateria.trim().toUpperCase() !== u
			);
			if (opt) {
				bumpDiagramLayout();
				toast.success(`${opt.materia.nomeMateria} removida.`);
			}
		},

		isOptativaPlanejada(codigoMateria: string): boolean {
			const u = codigoMateria.trim().toUpperCase();
			return optativasAdicionadas.some(
				(o) => o.materia.codigoMateria.trim().toUpperCase() === u
			);
		},

		/**
		 * Remove optativa do planejamento e persiste `optativas_planejadas` no servidor (rollback se falhar).
		 * Anônimo: só remove localmente.
		 */
		async removeOptativaPlanejadaESalvar(codigoMateria: string): Promise<boolean> {
			const user = authStore.getUser();
			const u = codigoMateria.trim().toUpperCase();
			const prev = optativasAdicionadas;
			const opt = prev.find((o) => o.materia.codigoMateria.trim().toUpperCase() === u);
			if (!opt) return false;

			if (state.isAnonymous || !user?.idUser || !user.dadosFluxograma) {
				optativasAdicionadas = prev.filter((o) => o.materia.codigoMateria.trim().toUpperCase() !== u);
				bumpDiagramLayout();
				toast.success(`${opt.materia.nomeMateria} removida do planejamento (somente neste aparelho).`);
				return true;
			}

			const next = prev.filter((o) => o.materia.codigoMateria.trim().toUpperCase() !== u);
			optativasAdicionadas = next;
			bumpDiagramLayout();

			const refs: OptativaPlanejadaRef[] = next.map((o) => ({
				codigoMateria: o.materia.codigoMateria.trim(),
				semestre: o.semestre
			}));
			const dadosAtualizados: DadosFluxogramaUser = {
				...user.dadosFluxograma,
				optativasPlanejadas: refs.length ? refs : undefined
			};
			try {
				await fluxogramaService.saveFluxograma(
					user.idUser,
					dadosFluxogramaUserToJson(dadosAtualizados),
					user.dadosFluxograma.semestreAtual
				);
				authStore.updateDadosFluxograma(dadosAtualizados);
				historicoManualPendenteSalvar = false;
				toast.success(`${opt.materia.nomeMateria} removida e salva no perfil.`);
				return true;
			} catch {
				optativasAdicionadas = prev;
				bumpDiagramLayout();
				toast.error('Não foi possível salvar. A optativa foi restaurada.');
				return false;
			}
		},

		async saveOptativasPlanejadas() {
			const user = authStore.getUser();
			if (state.isAnonymous || !user?.idUser || !user.dadosFluxograma) {
				toast.error('Entre na conta para salvar o planejamento de optativas.');
				return;
			}
			const refs: OptativaPlanejadaRef[] = optativasAdicionadas.map((o) => ({
				codigoMateria: o.materia.codigoMateria.trim(),
				semestre: o.semestre
			}));
			const dadosAtualizados: DadosFluxogramaUser = {
				...user.dadosFluxograma,
				optativasPlanejadas: refs.length ? refs : undefined
			};
			try {
				await fluxogramaService.saveFluxograma(
					user.idUser,
					dadosFluxogramaUserToJson(dadosAtualizados),
					user.dadosFluxograma.semestreAtual
				);
				authStore.updateDadosFluxograma(dadosAtualizados);
				historicoManualPendenteSalvar = false;
				toast.success('Alterações salvas no seu perfil.');
			} catch {
				toast.error('Não foi possível salvar. Tente de novo.');
			}
		},

		async loadCourseData(courseName: string, anonymous = false) {
			state.loading = true;
			state.error = null;
			state.isAnonymous = anonymous;

			try {
				const data = await fluxogramaService.getCourseData(courseName);
				state.courseData = data;
				optativasAdicionadas = hydrateOptativasFromRefs(
					authStore.getUser()?.dadosFluxograma?.optativasPlanejadas,
					data
				);
			} catch (err) {
				const message =
					err instanceof Error ? err.message : 'Erro ao carregar dados do curso';
				state.error = message;
				toast.error(message);
			} finally {
				state.loading = false;
			}
		},

		async loadCourseDataByCurriculoCompleto(curriculoCompleto: string, anonymous = false) {
			state.loading = true;
			state.error = null;
			state.isAnonymous = anonymous;
			try {
				const data = await fluxogramaService.getCourseDataByCurriculoCompleto(curriculoCompleto);
				state.courseData = data;
				optativasAdicionadas = hydrateOptativasFromRefs(
					authStore.getUser()?.dadosFluxograma?.optativasPlanejadas,
					data
				);
			} catch (err) {
				const message =
					err instanceof Error ? err.message : 'Erro ao carregar dados da matriz';
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
			state.zoomLevel = 0.6;
		},

		setConnectionMode(mode: ConnectionMode) {
			state.connectionMode = mode;
		},

		setDisplayUnit(unit: DisplayUnit) {
			state.displayUnit = unit;
		},

		setConnectionDensity(density: Map<number, number>) {
			connectionDensityBySemester = density;
		},

		toggleConnections() {
			state.connectionMode = state.connectionMode === 'off' ? 'direct' : 'off';
		},

		setHoveredSubject(code: string | null) {
			state.hoveredSubjectCode = code;
		},

		setHoverPreviewSubject(code: string | null) {
			state.hoverPreviewSubjectCode = code;
		},

		setSelectedSubject(code: string | null) {
			state.selectedSubjectCode = code;
		},

		/**
		 * @param captureOptions.connectionMode — `off`: só disciplinas (sem linhas). `all`: todas as conexões no print. Estado do usuário é restaurado após a captura.
		 */
		async saveScreenshot(
			container: HTMLElement | null,
			captureOptions?: { connectionMode: 'off' | 'all' }
		) {
			if (!container) {
				toast.error('Elemento do fluxograma não encontrado.');
				return;
			}
			const prevMode = state.connectionMode;
			const prevHover = state.hoveredSubjectCode;
			const prevPreview = state.hoverPreviewSubjectCode;
			const shouldRestore = !!captureOptions?.connectionMode;
			try {
				state.isCapturingScreenshot = true;
				if (captureOptions?.connectionMode) {
					state.connectionMode = captureOptions.connectionMode;
					state.hoveredSubjectCode = null;
					state.hoverPreviewSubjectCode = null;
				}
				// Modo "todas" altera gaps entre colunas — precisa de mais tempo para o layout/SVG
				const delayMs = captureOptions?.connectionMode === 'all' ? 450 : captureOptions?.connectionMode === 'off' ? 180 : 100;
				await new Promise((resolve) => setTimeout(resolve, delayMs));
				const courseName = state.courseData?.nomeCurso ?? 'fluxograma';
				const base = courseName.replace(/\s+/g, '_');
				const suffix =
					captureOptions?.connectionMode === 'all'
						? '_todas_conexoes'
						: captureOptions?.connectionMode === 'off'
							? '_normal'
							: '';
				const filename = `${base}${suffix}.png`;
				await captureScreenshot(container, filename);
				toast.success('Screenshot salvo com sucesso!');
			} catch {
				toast.error('Não foi possível capturar a imagem.');
			} finally {
				state.isCapturingScreenshot = false;
				if (shouldRestore) {
					state.connectionMode = prevMode;
					state.hoveredSubjectCode = prevHover;
					state.hoverPreviewSubjectCode = prevPreview;
				}
			}
		},

		reset() {
			state.courseData = null;
			state.loading = false;
			state.error = null;
			state.zoomLevel = 0.6;
			state.connectionMode = 'direct';
			state.displayUnit = 'horas';
			state.isAnonymous = false;
			state.hoveredSubjectCode = null;
			state.hoverPreviewSubjectCode = null;
			state.selectedSubjectCode = null;
			state.isCapturingScreenshot = false;
			optativasAdicionadas = [];
			connectionDensityBySemester = new Map();
		}
	};
}

export const fluxogramaStore = createFluxogramaStore();
