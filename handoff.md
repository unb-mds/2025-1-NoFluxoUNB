# Handoff — Refazer tema claro/escuro + kit de animações (método Runter)

> Documento de transferência. Cole este arquivo na raiz do outro projeto e peça pro
> agente seguir as duas partes. O dark mode já está bom — **não mexer nele**, usá-lo
> como verdade. O foco é consertar o **light mode** e trazer as animações da landing.

---

# PARTE 1 — Por que o light mode quebrou e como consertar

## 1.1 Diagnóstico

Dark ótimo + light horrível = quase sempre estas três causas juntas:

1. **Cores pensadas só pro fundo escuro.** Um roxo/azul que brilha sobre preto, "só
   invertido" pro claro. Roxo vibrante (`hsl(270 76% 60%)`) sobre branco com texto
   branco em cima = ilegível. No claro a cor de marca tem que ficar **mais escura e
   mais saturada**, não a mesma.
2. **Sem camada de tokens semânticos.** Componentes usam cor direta
   (`bg-purple-500`, `text-gray-700`, `#1a1a1a`) em vez de token (`bg-card`,
   `text-muted-foreground`). Sem essa camada não dá pra ter dois temas coerentes.
3. **Sem contraste de superfícies no claro.** No dark, `background` e `card` se
   distinguem fácil. No light, se ambos forem quase branco, tudo vira uma chapa
   branca sem hierarquia.

## 1.2 Princípio central: tokens em 2 camadas

**Camada 1 — Primitivos** (escalas 50→950 por matiz). Fixas, não mudam por tema. É a
"caixa de tintas".

**Camada 2 — Tokens semânticos** (`--background`, `--foreground`, `--card`,
`--primary`, `--border`, `--muted-foreground`…). Mudam por tema: um valor em `:root`
(claro), outro em `.dark` (escuro). **Nenhum componente usa cor crua — só token
semântico.** Botão = `bg-primary text-primary-foreground`. Card =
`bg-card text-card-foreground border-border`.

> Regra de ouro: **se há uma cor (hex, rgb, `purple-500`) dentro de um componente,
> está errado. Componente só consome token semântico.**

## 1.3 Tabela de referência (claro × escuro)

Estrutura real do Runter (azul `221°` + roxo `270°`). Troque só o matiz pela cor da
marca; mantenha as relações de lightness/saturation.

```css
:root {                              /* LIGHT */               /* DARK (.dark) */
  --background:        210 20% 98%;  /* cinza-claro, NÃO branco puro */  /* 222 47% 6%  */
  --foreground:        222 47% 11%;  /* quase-preto azulado */           /* 210 40% 98% */
  --card:              0 0% 100%;    /* branco PURO (descola do bg) */   /* 222 47% 8%  */
  --card-foreground:   222 47% 11%;                                      /* 210 40% 98% */
  --popover:           0 0% 100%;                                        /* 222 47% 8%  */
  --popover-foreground:222 47% 11%;                                      /* 210 40% 98% */
  --primary:           221 83% 53%;  /* azul ESCURO no claro */          /* 221 83% 60% */
  --primary-foreground:210 40% 98%;                                      /* 222 47% 6%  */
  --secondary:         270 76% 55%;                                      /* 270 76% 60% */
  --secondary-foreground: 0 0% 100%;                                     /* 0 0% 100%   */
  --muted:             210 40% 96%;                                      /* 217 33% 17% */
  --muted-foreground:  215 16% 47%;  /* secundário — AINDA passa AA */   /* 215 20% 65% */
  --accent:            270 76% 55%;                                      /* 270 76% 60% */
  --accent-foreground: 0 0% 100%;                                        /* 0 0% 100%   */
  --destructive:       0 84% 60%;                                        /* 0 72% 55%   */
  --border:            214 32% 91%;  /* borda VISÍVEL no claro */        /* 217 33% 17% */
  --input:             214 32% 91%;                                      /* 217 33% 17% */
  --ring:              221 83% 53%;                                      /* 221 83% 60% */
}
```

### As 5 lições embutidas

1. **`background` no claro NÃO é branco puro** (`210 20% 98%`). Branco puro fica só
   pro `card`. Isso cria hierarquia de superfície sem sombra pesada. `background:#fff`
   + `card:#fff` = a interface some (erro nº1).
2. **A cor de marca muda de lightness entre temas.** Claro `53%` (escuro o bastante
   pra texto branco passar AA), escuro `60%` (clareia pra brilhar no preto). Não é a
   mesma cor.
3. **`foreground` não é `#000`.** É `222 47% 11%` — quase-preto com tinta da marca.
   Preto puro sobre branco puro vibra e cansa.
4. **`muted-foreground` é o token mais perigoso.** Texto secundário; no claro tem que
   ser escuro o bastante (`~47%` luz) pra manter contraste ≥ 4.5:1.
5. **`border` precisa existir no claro** (`214 32% 91%`). Sem ela, cards brancos sobre
   fundo quase-branco viram um borrão. Borda + sombra suave dá forma no light.

## 1.4 Sombras por tema

- **Claro:** colorida, suave, tingida com a marca, baixa opacidade.
  `--shadow-md: 0 4px 6px -1px hsl(221 83% 53% / 0.1)`
- **Escuro:** preta pura e densa (sombra colorida some no escuro).
  `--shadow-md: 0 4px 6px -1px hsl(0 0% 0% / 0.5)`

Sombra também é token, trocada em `.dark`.

## 1.5 Plano de execução

1. **Auditar hardcode:** buscar em `src/` por `#`, `rgb(`, `rgba(`, e classes de cor
   direta (`bg-purple-`, `text-gray-`, `bg-white`, `text-black`, `bg-zinc-`…). Listar
   todos os arquivos.
2. **Definir as 2 camadas** no CSS global: primitivos (50–950) + semânticos em `:root`
   e `.dark`, espelhando a tabela acima.
3. **Calibrar o claro:** `background` cinza 96–98% luz; `card`/`popover` branco puro;
   `border` ≈ 90% luz e sempre visível; `foreground` quase-preto (~11% luz), nunca
   `#000`.
4. **Calibrar a marca por tema:** no claro baixar lightness do `primary`/`accent` até
   texto branco em cima passar AA (≥4.5:1 normal, ≥3:1 grande). No escuro subir.
5. **Substituir todo hardcode por token semântico**, usando a lista do passo 1.
6. **Sombras por tema** como tokens (coloridas/suaves no claro, pretas/densas no escuro).
7. **Validar contraste WCAG AA** nestes pares no claro: `foreground`/`background`,
   `muted-foreground`/`background`, `muted-foreground`/`muted`,
   `primary-foreground`/`primary`, `card-foreground`/`card`, texto sobre hover.
   Qualquer < 4.5:1 (texto normal) reprova.
8. **Teste visual:** abrir telas principais nos dois temas; alternar não pode sumir
   com nenhum elemento.

---

# PARTE 2 — Kit de animações da landing

Stack: **framer-motion** + keyframes Tailwind/CSS. Filosofia: poucas primitivas
reutilizáveis, easing único, sempre com fallback `prefers-reduced-motion`.

## 2.1 Easing assinatura

```ts
ease: [0.16, 1, 0.3, 1]   // "out-expo" — usar em TUDO, dá unidade
```
Durações: entrada `0.6s`, headline `0.8s`, micro-interações `0.25–0.45s`.

## 2.2 `ScrollReveal` (copiar inteiro)

```tsx
import { ReactNode } from "react";
import { motion, type HTMLMotionProps, useReducedMotion } from "framer-motion";

interface ScrollRevealProps
  extends Omit<HTMLMotionProps<"div">, "initial" | "whileInView" | "viewport" | "transition"> {
  children: ReactNode;
  y?: number;
  delay?: number;
  duration?: number;
  once?: boolean;
  amount?: number;
}

export function ScrollReveal({
  children, y = 24, delay = 0, duration = 0.6,
  once = true, amount = 0.2, className, ...rest
}: ScrollRevealProps) {
  const reduced = useReducedMotion();
  if (reduced) return <div className={className as string}>{children}</div>;
  return (
    <motion.div
      initial={{ opacity: 0, y }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once, amount }}
      transition={{ duration, delay, ease: [0.16, 1, 0.3, 1] }}
      className={className}
      {...rest}
    >
      {children}
    </motion.div>
  );
}
```
Uso (cascata):
```tsx
{items.map((it, i) => (
  <ScrollReveal key={it.id} delay={i * 0.08}><Card>{/* ... */}</Card></ScrollReveal>
))}
```

## 2.3 `AnimatedHeadline` (copiar inteiro)

```tsx
import { motion, useReducedMotion } from "framer-motion";
import { cn } from "@/lib/utils";

interface Props {
  text: string; className?: string;
  stagger?: number; delayBase?: number;
  as?: "h1" | "h2" | "h3"; highlightWords?: string[];
}

export function AnimatedHeadline({
  text, className, stagger = 0.06, delayBase = 0,
  as = "h1", highlightWords = [],
}: Props) {
  const reduced = useReducedMotion();
  const words = text.split(" ");
  const Tag = as;
  if (reduced) {
    return (
      <Tag className={cn(className)}>
        {words.map((w, i) => {
          const hl = highlightWords.includes(w.replace(/[.,!?]/g, ""));
          return <span key={i} className={cn(hl && "gradient-text")}>{w}{i < words.length - 1 ? " " : ""}</span>;
        })}
      </Tag>
    );
  }
  const container = { hidden: {}, visible: { transition: { staggerChildren: stagger, delayChildren: delayBase } } };
  const child = { hidden: { y: "110%" }, visible: { y: "0%", transition: { duration: 0.8, ease: [0.16, 1, 0.3, 1] } } };
  return (
    <motion.span
      initial="hidden" whileInView="visible"
      viewport={{ once: true, amount: 0.3 }}
      variants={container}
      className={cn(className, "inline-block")}
    >
      <Tag className="inline">
        {words.map((word, i) => {
          const clean = word.replace(/[.,!?]/g, "");
          const isHL = highlightWords.includes(clean);
          return (
            <span key={i}
              className="inline-block overflow-hidden pb-[0.15em] align-bottom"
              style={{ marginRight: i < words.length - 1 ? "0.25em" : undefined }}>
              <motion.span variants={child} className={cn("inline-block", isHL && "gradient-text")}>
                {word}
              </motion.span>
            </span>
          );
        })}
      </Tag>
    </motion.span>
  );
}
```
> Truque: wrapper `overflow-hidden` por palavra; a palavra começa em `y:110%`
> (escondida abaixo da própria caixa) e sobe — efeito "máscara".

## 2.4 Barra de progresso de leitura

```tsx
const { scrollYProgress } = useScroll();
const scaleX = useSpring(scrollYProgress, { stiffness: 120, damping: 24, restDelta: 0.001 });
// <motion.div style={{ scaleX, transformOrigin: "0%" }}
//   className="fixed top-0 inset-x-0 h-1 bg-primary z-50" />
```

## 2.5 Reveal cinematográfico 3D do mockup do hero

```tsx
const { scrollYProgress } = useScroll({ target: ref, offset: ["start 85%", "end 60%"] });
const scale   = useTransform(scrollYProgress, [0, 0.5], [0.82, 1]);
const rotateX = useTransform(scrollYProgress, [0, 0.5], [14, 0]);
const y       = useTransform(scrollYProgress, [0, 0.5], [60, 0]);
const opacity = useTransform(scrollYProgress, [0, 0.3], [0.4, 1]);
// container { perspective: 1600px }; <motion.div style={{ scale, rotateX, y, opacity }}>
```

## 2.6 Keyframes reaproveitáveis

```ts
// tailwind.config — theme.extend
keyframes: {
  "fade-in":   { from: { opacity: "0" }, to: { opacity: "1" } },
  "slide-up":  { from: { opacity: "0", transform: "translateY(20px)" },
                 to:   { opacity: "1", transform: "translateY(0)" } },
  "pulse-glow":{ "0%,100%": { boxShadow: "0 0 20px hsl(var(--primary)/0.3)" },
                 "50%":     { boxShadow: "0 0 30px hsl(var(--primary)/0.5)" } },
},
animation: {
  "fade-in":   "fade-in 0.5s ease-out",
  "slide-up":  "slide-up 0.5s ease-out",
  "pulse-glow":"pulse-glow 2s ease-in-out infinite",
},
```
```css
/* index.css */
@keyframes cta-shift { 0%,100% { background-position:0% 50% } 50% { background-position:100% 50% } }
.cta-animated { background: var(--gradient-primary); background-size:200% 200%;
                animation: cta-shift 8s ease-in-out infinite; }

@keyframes marquee { from { transform:translateX(0) } to { transform:translateX(-50%) } }
.animate-marquee { animation: marquee 40s linear infinite; will-change:transform; }

@keyframes shimmer { 0% { background-position:-200% 0 } 100% { background-position:200% 0 } }
.shimmer-badge { background-size:200% 100%; animation: shimmer 2.2s linear infinite; }
```

## 2.7 Hover de card padrão (Tailwind puro)

```
transition-all duration-300 hover:-translate-y-1
hover:border-primary/30
hover:shadow-[0_20px_40px_-20px_hsl(var(--primary)/0.35)]
```

## 2.8 Acessibilidade (obrigatório)

```css
@media (prefers-reduced-motion: reduce) {
  *,*::before,*::after {
    animation-duration:.001ms!important; animation-iteration-count:1!important;
    transition-duration:.001ms!important; scroll-behavior:auto!important;
  }
}
```
Em componentes framer-motion: se `useReducedMotion()` for true, renderizar a versão
estática (sem `motion`).

## 2.9 Receita pra atualizar a home

1. Hero: `AnimatedHeadline` no H1 + `ScrollReveal` em cascata (subtítulo `delay 0.1`,
   CTA `0.2`) + mockup com reveal 3D.
2. Barra de progresso de leitura fixa no topo.
3. Cada seção: heading e cards dentro de `ScrollReveal` com `delay={i * 0.08}`.
4. CTA com `.cta-animated`; faixa de logos com `.animate-marquee`.
5. Hover padrão (2.7) em todos os cards.
6. Um único easing `[0.16, 1, 0.3, 1]` em tudo.
