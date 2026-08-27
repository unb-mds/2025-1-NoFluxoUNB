export const mockCursos = [
  {
    id_curso: 1,
    nome_curso: 'Engenharia de Software',
    tipo_curso: 'graduacao',
    turno: 'DIURNO',
    criado_em: '2023-01-01T00:00:00.000Z',
    atualizado_em: '2023-01-01T00:00:00.000Z'
  },
  {
    id_curso: 2,
    nome_curso: 'Sistemas de Informação',
    tipo_curso: 'graduacao',
    turno: 'NOTURNO',
    criado_em: '2023-01-01T00:00:00.000Z',
    atualizado_em: '2023-01-01T00:00:00.000Z'
  },
  {
    id_curso: 3,
    nome_curso: 'Ciência da Computação',
    tipo_curso: 'graduacao',
    turno: 'DIURNO',
    criado_em: '2023-01-01T00:00:00.000Z',
    atualizado_em: '2023-01-01T00:00:00.000Z'
  }
];

export const mockCursosWithCreditos = [
  {
    ...mockCursos[0],
    total_creditos: 240,
    cred_obrigatorio_exigido: 160,
    cred_optativo_exigido: 60,
    cred_complementar_exigido: 20
  },
  {
    ...mockCursos[1],
    total_creditos: 200,
    cred_obrigatorio_exigido: 140,
    cred_optativo_exigido: 40,
    cred_complementar_exigido: 20
  },
  {
    ...mockCursos[2],
    total_creditos: 260,
    cred_obrigatorio_exigido: 180,
    cred_optativo_exigido: 60,
    cred_complementar_exigido: 20
  }
];