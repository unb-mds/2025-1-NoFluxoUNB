## 🧩 TypeScript no Backend

TypeScript não é só para frontend — no backend, ele oferece ainda mais benefícios, especialmente em projetos Node.js com Express, NestJS ou similares.

### ⚙️ Vantagens no Backend

- **Segurança de tipos** em rotas, serviços, controladores e comunicação com o banco de dados.
- **Modelagem de dados robusta**, com interfaces e types para representar entidades e DTOs.
- **IntelliSense aprimorado** no desenvolvimento de APIs REST ou GraphQL.
- **Integração fluida com ORM/ODMs**, como Prisma, TypeORM, Sequelize e Mongoose.
- **Refatoração confiável**, essencial em backends complexos com múltiplos módulos.
- **Suporte a decorators e POO moderna**, ideal para arquiteturas como MVC ou Clean Architecture.

### 🧪 Exemplo simples com Express + TypeScript

```ts
import express, { Request, Response } from 'express';

const app = express();
app.use(express.json());

interface Usuario {
  id: number;
  nome: string;
  email: string;
}

app.get('/usuarios', (req: Request, res: Response) => {
  const usuarios: Usuario[] = [
    { id: 1, nome: 'Felipe', email: 'felipe@email.com' }
  ];
  res.json(usuarios);
});

app.listen(3000, () => {
  console.log('Servidor rodando em http://localhost:3000');
});

```

🛠 Ferramentas recomendadas

    ts-node: Executa arquivos TypeScript diretamente no Node.js

    nodemon: Reinicia automaticamente o servidor em alterações de código

    tsconfig.json: Arquivo de configuração central do TypeScript

    dotenv: Para variáveis de ambiente


## ⚙️ Setup Básico com TypeScript + Node.js

```bash
# Inicialize um projeto Node
npm init -y

# Instale TypeScript e ferramentas auxiliares
npm install typescript ts-node-dev @types/node --save-dev

# Crie o arquivo de configuração
npx tsc --init

    Recomenda-se usar ts-node-dev para rodar o projeto com recarregamento automático durante o desenvolvimento.
```


### 📘 Links úteis para backend com TypeScript

- [Node.js + TypeScript Starter](https://github.com/microsoft/TypeScript-Node-Starter)
- [NestJS (framework backend com TypeScript)](https://nestjs.com/)
- [TypeORM (ORM com TypeScript)](https://typeorm.io/)
- [Prisma (ORM moderno com suporte total ao TS)](https://www.prisma.io/)


