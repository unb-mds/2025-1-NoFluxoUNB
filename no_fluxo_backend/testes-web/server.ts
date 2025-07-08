import express from 'express';
import path from 'path';
import cors from 'cors';

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