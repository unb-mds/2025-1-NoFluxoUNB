// Testado em arquivo separado porque manipula ML_PUSH_API_KEY e o cache de
// módulos do Node — misturar isso com o resto dos testes de
// ml_ingest_controller.test.ts (que dependem do módulo já carregado com a
// env var presente) causaria interferência entre os dois arquivos.

describe('ml_ingest_controller — fail-fast na env var', () => {
  const originalKey = process.env.ML_PUSH_API_KEY;

  afterEach(() => {
    if (originalKey === undefined) {
      delete process.env.ML_PUSH_API_KEY;
    } else {
      process.env.ML_PUSH_API_KEY = originalKey;
    }
    jest.resetModules();
  });

  it('lança ao carregar o módulo sem ML_PUSH_API_KEY definida', () => {
    delete process.env.ML_PUSH_API_KEY;
    jest.resetModules();
    expect(() => require('../src/controllers/ml_ingest_controller')).toThrow(/ML_PUSH_API_KEY/);
  });

  it('carrega normalmente quando ML_PUSH_API_KEY está definida', () => {
    process.env.ML_PUSH_API_KEY = 'uma-chave-qualquer';
    jest.resetModules();
    expect(() => require('../src/controllers/ml_ingest_controller')).not.toThrow();
  });
});
