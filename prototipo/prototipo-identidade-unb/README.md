# Protótipo de identidade visual (NoFluxo UnB)

Este protótipo é independente das páginas atuais e serve para validar:

- Remoção de fonte estilo handwriting/graffiti
- Tipografia legível para títulos e textos
- Tema escuro com identidade institucional (verde, azul e branco da UnB)

## Como executar

### Opção 1 (mais simples)

Abra o arquivo `index.html` no navegador.

### Opção 2 (servidor local)

No terminal, dentro desta pasta:

```bash
python -m http.server 5500
```

Depois acesse:

<http://localhost:5500>

## Estrutura

- `index.html` -> layout do protótipo com 4 telas navegáveis
- `styles.css` -> tokens visuais, tipografia e componentes
- `script.js` -> troca de telas via abas
