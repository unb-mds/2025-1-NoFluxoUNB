const http = require('http');

const options = {
  hostname: 'localhost',
  port: 3000,
  path: '/health',
  method: 'GET',
  timeout: 1000
};

const req = http.request(options, (res) => {
  console.log('Server is still running, killing process in 1s...');
  setTimeout(() => process.exit(0), 1000);
});

req.on('timeout', () => {
  console.log('Server not responding');
  process.exit(0);
});

req.on('error', (e) => {
  console.log('Server not accessible');
  process.exit(0);
});

req.end();
