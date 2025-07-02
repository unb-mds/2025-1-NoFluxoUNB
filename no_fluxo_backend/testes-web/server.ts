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