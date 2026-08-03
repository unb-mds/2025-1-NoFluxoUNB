<script lang="ts">
	import { SvelteFlow, Background, Controls, type Node, type Edge, Position, MarkerType } from '@xyflow/svelte';
	import '@xyflow/svelte/dist/style.css';
	import type { PlanoFormatura } from '$lib/types/plano-formatura';
	import type { CursoModel } from '$lib/types/curso';
	import { getDirectPrerequisites } from '$lib/types/curso';
	import SvelteFlowMateriaNode from './SvelteFlowMateriaNode.svelte';
	import SvelteFlowHeaderNode from './SvelteFlowHeaderNode.svelte';
	import type { MateriaPlano } from '$lib/types/plano-formatura';

	interface Props {
		plano: PlanoFormatura;
		curso: CursoModel | null;
		materiasMATR?: MateriaPlano[];
		semestreAtual?: number;
		onChatAction?: (msg: string) => void;
		displayUnit?: 'creditos' | 'horas';
	}

	let { plano, curso, materiasMATR = [], semestreAtual = 1, onChatAction, displayUnit = 'creditos' }: Props = $props();

	// Registra o custom node
	const nodeTypes = {
		materia: SvelteFlowMateriaNode,
		header: SvelteFlowHeaderNode
	};

	let nodes = $state<Node[]>([]);
	let edges = $state<Edge[]>([]);

	// Configuração do layout
	const COLUMN_WIDTH = 400; // Aumentado para dar mais respiro horizontal
	const ROW_HEIGHT = 160;   // Aumentado para dar respiro vertical entre os cards
	const START_X = 50;
	const START_Y = 120;

	$effect(() => {
		if (!plano || !plano.plano) return;
		
		const newNodes: Node[] = [];
		const newEdges: Edge[] = [];
		const codeToNodeId = new Map<string, string>();

		let currentColumnIndex = 0;

		// 1. Renderiza a coluna do semestre ATUAL (materias matriculadas) se houver
		if (materiasMATR && materiasMATR.length > 0) {
			const xPos = START_X + (currentColumnIndex * COLUMN_WIDTH);
			
			newNodes.push({
				id: 'header-matr',
				type: 'header',
				position: { x: xPos, y: START_Y - 70 },
				data: { label: `Semestre ${semestreAtual} (Em Curso)` },
				draggable: false,
				selectable: false
			});

			materiasMATR.forEach((item, rowIndex) => {
				if ('codigo' in item) {
					const yPos = START_Y + (rowIndex * ROW_HEIGHT);
					const nodeId = `node-${item.codigo}`;
					codeToNodeId.set(item.codigo, nodeId);
					
					newNodes.push({
						id: nodeId,
						type: 'materia',
						position: { x: xPos, y: yPos },
						data: { materia: item, tipoSemestre: 'estimado', onChatAction, displayUnit }
					});
				}
			});
			currentColumnIndex++;
		}

		// 2. Criar Nodes para os semestres futuros do plano
		plano.plano.forEach((semestre, index) => {
			const xPos = START_X + (currentColumnIndex * COLUMN_WIDTH);
			
			// Cálculo correto do número do semestre
			const numeroSemestre = semestreAtual + index + 1;
			
			// Renderiza um cabeçalho pro semestre
			const semestreStr = semestre.semestre ? ` (${semestre.semestre})` : '';
			newNodes.push({
				id: `header-${semestre.indice}`,
				type: 'header',
				position: { x: xPos, y: START_Y - 70 },
				data: { label: `Semestre ${numeroSemestre}${semestreStr} — ${semestre.tipo === 'recomendado' ? 'Recomendado' : 'Estimado'}` },
				draggable: false,
				selectable: false
			});

			semestre.materias.forEach((item, rowIndex) => {
				if ('codigo' in item) {
					const yPos = START_Y + (rowIndex * ROW_HEIGHT);
					const nodeId = `node-${item.codigo}`;
					codeToNodeId.set(item.codigo, nodeId);
					
					newNodes.push({
						id: nodeId,
						type: 'materia',
						position: { x: xPos, y: yPos },
						data: { materia: item, tipoSemestre: semestre.tipo, onChatAction, displayUnit }
					});
				}
			});
			currentColumnIndex++;
		});

		// 2. Criar Edges (Arestas) verificando os pré-requisitos
		if (curso) {
			plano.plano.forEach((semestre) => {
				semestre.materias.forEach((item) => {
					if ('codigo' in item) {
						const targetNodeId = codeToNodeId.get(item.codigo);
						if (!targetNodeId) return;

						const prereqs = getDirectPrerequisites(curso, item.codigo);
						prereqs.forEach(prereqMateria => {
							const sourceNodeId = codeToNodeId.get(prereqMateria.codigoMateria);
							// Se o pré-requisito também está no plano (não foi concluído ainda)
							if (sourceNodeId) {
								newEdges.push({
									id: `edge-${sourceNodeId}-${targetNodeId}`,
									source: sourceNodeId,
									target: targetNodeId,
									type: 'smoothstep',
									animated: true,
									style: 'stroke: rgba(255,255,255,0.2); stroke-width: 2;',
									markerEnd: {
										type: MarkerType.ArrowClosed,
										color: 'rgba(255,255,255,0.2)',
									}
								});
							}
						});
					}
				});
			});
		}

		nodes = newNodes;
		edges = newEdges;
	});
</script>

<div class="w-full h-full min-h-[600px] border border-white/10 rounded-xl overflow-hidden bg-[#090c12]">
	<SvelteFlow 
		{nodes} 
		{edges} 
		{nodeTypes} 
		minZoom={0.3}
		maxZoom={2}
		initialViewport={{ x: 20, y: 20, zoom: 0.8 }}
		panOnScroll={true}
		preventScrolling={false}
		panOnDrag={false}
		selectionOnDrag={false}
		zoomOnDoubleClick={false}
		defaultEdgeOptions={{ type: 'smoothstep' }}
		colorMode="dark"
	>
		<Background bgColor="#090c12" />
		<Controls />
	</SvelteFlow>
</div>
