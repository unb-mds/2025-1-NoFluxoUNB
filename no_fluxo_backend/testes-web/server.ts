import * as dotenv from 'dotenv';
dotenv.config({ path: '../.env' }); // se rodar de dentro de testes-web
import express from 'express';
import path from 'path';
import cors from 'cors';
import { SupabaseWrapper } from '../src/supabase_wrapper';


console.log('SUPABASE_URL:', process.env.SUPABASE_URL);
console.log('SUPABASE_SERVICE_ROLE_KEY:', process.env.SUPABASE_SERVICE_ROLE_KEY);

SupabaseWrapper.init();
const supabase = SupabaseWrapper.get();

const app = express();
const PORT = 3002;

// Configurar CORS
app.use(cors());

// Servir arquivos estáticos
app.use(express.static(path.join(__dirname)));

// Rota principal
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'index.html'));
});

// Nova rota: listar cursos
app.get('/api/cursos', async (req, res) => {
    const { data, error } = await supabase.from('cursos').select('*');
    if (error) return res.status(500).json({ error: error.message });
    return res.json(data);
});

// Nova rota: listar matérias de um curso
app.get('/api/cursos/:id_curso/materias', async (req, res) => {
    const { id_curso } = req.params;
    const { data, error } = await supabase
        .from('materias_por_curso')
        .select('nivel, materias(*)')
        .eq('id_curso', id_curso);
    if (error) return res.status(500).json({ error: error.message });
    return res.json(data);
});

// Nova rota: pré-requisitos detalhados (semelhante à view SQL)
app.get('/api/pre-requisitos-detalhado', async (req, res) => {
    const { data, error } = await supabase
        .from('pre_requisitos')
        .select(`
            id_pre_requisito,
            id_materia,
            materias: id_materia (codigo_materia, nome_materia),
            id_materia_requisito,
            requisito: id_materia_requisito (codigo_materia, nome_materia),
            materias_por_curso!inner(id_curso),
            cursos: materias_por_curso(id_curso, nome_curso, matriz_curricular)
        `);
    if (error) return res.status(500).json({ error: error.message });
    // Formatar resultado para ficar igual à view
    const result = data.map(item => ({
        id_pre_requisito: item.id_pre_requisito,
        id_materia: item.id_materia,
        codigo_materia: item.materias?.[0]?.codigo_materia,
        nome_materia: item.materias?.[0]?.nome_materia,
        id_materia_requisito: item.id_materia_requisito,
        codigo_requisito: item.requisito?.[0]?.codigo_materia,
        nome_requisito: item.requisito?.[0]?.nome_materia,
        id_curso: item.materias_por_curso?.[0]?.id_curso,
        nome_curso: item.cursos?.[0]?.nome_curso,
        matriz_curricular: item.cursos?.[0]?.matriz_curricular
    }));
    return res.json(result);
});

// Nova rota: pré-requisitos detalhados (view SQL) com filtros
app.get('/api/vw-pre-requisitos-detalhado', async (req, res) => {
    const { codigo_materia, nome_curso } = req.query;
    let query = supabase.from('vw_pre_requisitos_detalhado').select('*');
    if (codigo_materia) query = query.eq('codigo_materia', codigo_materia);
    if (nome_curso) query = query.ilike('nome_curso', `%${nome_curso}%`);
    const { data, error } = await query;
    if (error) return res.status(500).json({ error: error.message });
    return res.json(data);
});

// Rota de health check
app.get('/health', (req, res) => {
    res.json({ 
        status: 'ok', 
        message: 'Servidor de testes rodando',
        timestamp: new Date().toISOString()
    });
});

// Iniciar servidor
app.listen(PORT, () => {
    console.log(`🚀 Servidor de testes rodando em http://localhost:${PORT}`);
    console.log(`📋 Interface web disponível em http://localhost:${PORT}`);
    console.log(`🔗 API de testes em http://localhost:3000/testes`);
    console.log('');
    console.log('💡 Dicas:');
    console.log('   - Certifique-se de que o backend principal está rodando na porta 3000');
    console.log('   - Use a interface web para testar a API de forma visual');
    console.log('   - Os resultados são exibidos em formato JSON formatado');
}); 