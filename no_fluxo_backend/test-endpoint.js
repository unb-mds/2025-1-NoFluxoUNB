const http = require('http');

const data = JSON.stringify({
  curriculo_completo: '8885/1 - 2019.2',
  codigos_concluidos: ['MAT0026'],
  semestre_atual: 13,
  limite_creditos: 24
});

const options = {
  hostname: 'localhost',
  port: 3000,
  path: '/planejamento/gerar-plano',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': data.length
  }
};

const req = http.request(options, (res) => {
  let responseData = '';
  res.on('data', chunk => responseData += chunk);
  res.on('end', () => {
    console.log('Status:', res.statusCode);
    console.log('Response:', responseData);
    process.exit(0);
  });
});

req.on('error', (e) => {
  console.log('Error:', e.message);
  process.exit(1);
});

req.write(data);
req.end();
