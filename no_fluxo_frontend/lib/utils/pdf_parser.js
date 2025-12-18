/**
 * Parser de PDF para histórico escolar da UnB
 * Extrai dados acadêmicos diretamente no frontend usando PDF.js
 * 
 * Este arquivo substitui os parsers Python (pdf_parser_final.py e pdf_parser_ocr.py)
 * e processa PDFs diretamente no navegador, sem necessidade de backend pesado.
 */

// Certifique-se de que PDF.js está carregado
// <script src="https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js"></script>

/**
 * Classe principal para parsing de PDF de histórico escolar
 */
class PdfHistoricoParser {
  constructor() {
    // Configura o worker do PDF.js
    if (typeof pdfjsLib !== 'undefined') {
      pdfjsLib.GlobalWorkerOptions.workerSrc = 
        'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';
    }

    // Padrões Regex para extração de dados (alinhados com Python)
    this.padroes = {
      ira: /IRA[:\s]+(\d+[\.,]\d+)/i,
      mp: /MP[:\s]+(\d+[\.,]\d+)/i,
      curriculo: /(\d{4}[\./]\d+(?:\s*-\s*\d{4}\.\d)?)/m,
      curso: /Curso[:\s]+([A-ZÀ-Ÿ\s/\\-]+?)(?:\s+Status:|$)/im,
      cursoAlt: /^([A-ZÀ-ÿ\s]+(?:DE\s+[A-ZÀ-ÿ\s]+)*)\/[A-Z]+ - [A-ZÀ-ÿ\s]+ - [A-ZÀ-ÿ]+/im,
      
      // Padrões para processamento linha por linha (formato PyMuPDF estruturado)
      // Flexíveis para aceitar variações entre diferentes cursos/departamentos
      nomeDisciplina: /^([A-ZÀ-ÿ][A-ZÀ-ÿ\s0-9\-\/\(\)]+(?:DE\s+[A-ZÀ-ÿ\s0-9\-\/\(\)]*)*(?:\s+[A-ZÀ-ÿ\s0-9\-\/\(\)]*)*)\s*$/m,
      anoPeriodo: /^(\d{4}\.\d)$/m,
      // Códigos podem variar: CIC123, MAT456, FIS1234, ENG0001, etc.
      codigoDisciplina: /^([A-Z]{2,}\d{3,})$/m,
      // Todos os status possíveis do SIGAA
      situacao: /^(MATR|APR|REP|REPF|REPMF|CANC|DISP|TRANC|TRANCF|CUMP)$/m,
      mencao: /^(SS|MS|MM|MI|II|SR|\-)$/m,
      // Turmas: A, B, 01, 02, A1, etc.
      turma: /^([A-Z0-9]{1,4})$/m,
      // Carga horária: 15, 30, 45, 60, 90, 120, etc.
      cargaHoraria: /^(\d{1,4})$/m,
      frequencia: /^(\d{1,3}[,\.]\d+|--|\d{1,3})$/m,
      simbolos: /^([*&#e@§%]+)\s*$/m,
      
      // Equivalências
      equivalencias: /Cumpriu\s+([A-Z]{2,}\d{3,})\s*-\s*([A-ZÀ-Ÿ\s0-9]+?)\s*\((\d+)h\)\s*através\s*de\s*([A-Z]{2,}\d{3,})\s*-\s*([A-ZÀ-Ÿ\s0-9]+?)\s*\((\d+)h\)/gim,
      
      // Suspensões
      suspensoes: /Suspensões:\s*\n((?:\d{4}\.\d(?:\s*,\s*\d{4}\.\d)*)?)/im,
      
      // Disciplinas pendentes
      pendentesSigaa: /^\s+([A-ZÀ-Ÿ\sÇÃÕÁÉÍÓÚÂÊÎÔÛ0-9]+?)\s+(\d+)\s+h\s+([A-Z]{2,}\d{3,})(?:\s+(Matriculado|Matriculado em Equivalente))?$/gim,
      
      // Professor com carga horária
      professor: /(?:Dr\.|Dra\.|MSc\.|Prof\.|Professor|Professora)?\s*([A-ZÀ-ÿ\s\.]+?)\s*\((\d+)h\)/gi
    };
  }

  /**
   * Processa um arquivo PDF e extrai os dados acadêmicos
   * 
   * @param {File|ArrayBuffer} pdfFile - Arquivo PDF ou ArrayBuffer
   * @param {string} matricula - Matrícula do aluno (opcional)
   * @returns {Promise<Object>} Dados extraídos do PDF
   */
  async parsePdf(pdfFile, matricula = null) {
    try {
      // Converte File para ArrayBuffer se necessário
      const arrayBuffer = pdfFile instanceof ArrayBuffer 
        ? pdfFile 
        : await pdfFile.arrayBuffer();

      // Carrega o PDF
      const pdf = await pdfjsLib.getDocument({ data: arrayBuffer }).promise;
      
      console.log(`PDF carregado: ${pdf.numPages} páginas`);

      // Extrai texto de todas as páginas
      let fullText = '';
      for (let pageNum = 1; pageNum <= pdf.numPages; pageNum++) {
        const page = await pdf.getPage(pageNum);
        const textContent = await page.getTextContent();
        
        // Extrai texto com preservação de layout
        const pageText = this._extractStructuredText(textContent);
        fullText += pageText + '\n\n';
      }

      console.log('Texto extraído, iniciando parsing...');
      console.log('Primeiros 500 caracteres:', fullText.substring(0, 500));

      // Extrai dados acadêmicos
      const disciplinasRegulares = this._extrairDisciplinas(fullText);
      const disciplinasPendentes = this._extrairDisciplinasPendentes(fullText);
      const todasDisciplinas = [...disciplinasRegulares, ...disciplinasPendentes];
      
      const result = {
        message: 'PDF processado com sucesso!',
        filename: pdfFile.name || 'historico.pdf',
        matricula: matricula,
        curso_extraido: this._extrairCurso(fullText),
        matriz_curricular: this._extrairMatrizCurricular(fullText),
        media_ponderada: this._extrairMp(fullText),
        ira: this._extrairIra(fullText),
        extracted_data: todasDisciplinas,
        equivalencias_pdf: this._extrairEquivalencias(fullText),
        suspensoes: this._extrairSuspensoes(fullText),
        full_text: fullText
      };

      // Calcula semestre atual e número de semestre
      result.semestre_atual = this._extrairSemestreAtual(todasDisciplinas);
      result.numero_semestre = this._calcularNumeroSemestre(todasDisciplinas);

      console.log(`Parsing concluído: ${result.extracted_data.length} disciplinas extraídas`);
      
      return result;
    } catch (error) {
      console.error('Erro ao processar PDF:', error);
      throw new Error(`Erro ao processar PDF: ${error.message}`);
    }
  }

  /**
   * Extrai texto estruturado do conteúdo do PDF
   * Preserva layout e posicionamento dos elementos
   */
  _extractStructuredText(textContent) {
    if (!textContent || !textContent.items) {
      return '';
    }

    // Organiza items por posição Y (linha)
    const lines = [];
    let currentLine = [];
    let lastY = null;

    for (const item of textContent.items) {
      if (!item.str) continue;

      const y = Math.round(item.transform[5]); // Posição Y
      const x = Math.round(item.transform[4]); // Posição X

      // Nova linha se Y mudou significativamente
      if (lastY !== null && Math.abs(y - lastY) > 5) {
        if (currentLine.length > 0) {
          // Ordena por X e junta
          currentLine.sort((a, b) => a.x - b.x);
          lines.push({
            y: lastY,
            text: currentLine.map(item => item.text).join(' ')
          });
          currentLine = [];
        }
      }

      currentLine.push({ x, text: item.str });
      lastY = y;
    }

    // Adiciona última linha
    if (currentLine.length > 0) {
      currentLine.sort((a, b) => a.x - b.x);
      lines.push({
        y: lastY,
        text: currentLine.map(item => item.text).join(' ')
      });
    }

    // Ordena linhas por Y (de cima para baixo)
    lines.sort((a, b) => b.y - a.y);

    return lines.map(line => line.text).join('\n');
  }

  /**
   * Extrai o nome do curso
   * Suporta todos os formatos do SIGAA da UnB
   */
  _extrairCurso(texto) {
    // Tenta padrão alternativo primeiro (formato completo)
    let match = this.padroes.cursoAlt.exec(texto);
    if (match) {
      return match[1].trim();
    }

    // Tenta padrão original com label "Curso:"
    match = this.padroes.curso.exec(texto);
    if (match) {
      let curso = match[1].trim();
      // Remove sufixos desnecessários (campus, turno, habilitação)
      curso = curso.split('/')[0].split('-')[0].trim();
      // Remove espaços extras
      curso = curso.replace(/\s+/g, ' ');
      return curso;
    }

    // Fallback: busca por padrões conhecidos de curso
    // Ex: "CIÊNCIA DA COMPUTAÇÃO", "ENGENHARIA DE SOFTWARE", etc.
    const cursosFallback = /\b([A-ZÀ-ÿ]{2,}(?:\s+[A-ZÀ-ÿ]{2,}){1,5})\b(?=\s*\/)/;
    match = cursosFallback.exec(texto);
    if (match) {
      console.log('[CURSO] Extraído via fallback:', match[1]);
      return match[1].trim();
    }

    console.warn('[AVISO] Curso não encontrado no PDF');
    return null;
  }

  /**
   * Extrai a matriz curricular
   */
  _extrairMatrizCurricular(texto) {
    const match = this.padroes.curriculo.exec(texto);
    if (match) {
      return match[1].replace('/', '.');
    }
    return null;
  }

  /**
   * Extrai a média ponderada (MP)
   */
  _extrairMp(texto) {
    const match = this.padroes.mp.exec(texto);
    if (match) {
      return parseFloat(match[1].replace(',', '.'));
    }
    return null;
  }

  /**
   * Extrai o IRA
   */
  _extrairIra(texto) {
    const match = this.padroes.ira.exec(texto);
    if (match) {
      return parseFloat(match[1].replace(',', '.'));
    }
    return null;
  }

  /**
   * Extrai as disciplinas do histórico
   * FORMATO REAL DO PDF (baseado na análise do debug):
   * Linha 1: "2023.2   NOME DA DISCIPLINA"
   * Linha 2: "CODIGO   Dr. PROFESSOR (90h)   90   09   93,0   SS APR"
   */
  _extrairDisciplinas(texto) {
    const disciplinas = [];
    const linhas = texto.split('\n');
    
    console.log(`[DEBUG] Processando ${linhas.length} linhas para extrair disciplinas...`);
    
    // Padrão linha 1: Ano/Período + Nome da disciplina
    const regexLinha1 = /^(\d{4}\.\d)\s+(.+)$/;
    
    // Padrão linha 2: Código + info do professor + dados da disciplina
    // Exemplo: "CIC0004   Dr. FABRICIO ATAIDES BRAZ (90h)   90   09   93,0   SS APR"
    const regexLinha2 = /^([#*e\s]*)([A-Z]{2,}[A-Z\d]{3,})\s+(.+?)\((\d+)h\)\s+(\d{2,3})\s+(\d{1,2})\s+(\d{1,3}[,.]?\d*|--)\s+(SS|MS|MM|MI|II|SR|\-)\s+(APR|REP|REPF|REPMF|CANC|DISP|TRANC|MATR|CURS)\s*$/;
    
    let i = 0;
    let encontradas = 0;
    let ignoradas = 0;
    
    while (i < linhas.length - 1) { // -1 porque precisa da próxima linha
      const linha1 = linhas[i].trim();
      const match1 = linha1.match(regexLinha1);
      
      if (match1) {
        const anoPeriodo = match1[1];
        const nomeDisciplina = match1[2].trim();
        
        // Pula linhas de ENADE
        if (nomeDisciplina.includes('ENADE') || 
            nomeDisciplina.includes('INGRESSANTE') ||
            nomeDisciplina.includes('PROJETO PEDAGÓGICO')) {
          i++;
          continue;
        }
        
        // Próxima linha deve ter os detalhes
        const linha2 = linhas[i + 1].trim();
        const match2 = linha2.match(regexLinha2);
        
        if (match2) {
          const marcadores = match2[1]; // #, *, e ou espaços
          const codigo = match2[2];
          const professor = match2[3].trim();
          const cargaProf = match2[4]; // Carga do professor
          const cargaHoraria = match2[5];
          const turma = match2[6];
          const frequencia = match2[7];
          const mencao = match2[8];
          const status = match2[9];
          
          // Ignora disciplinas com menções problemáticas (II, MI, SR)
          if (['II', 'MI', 'SR'].includes(mencao)) {
            console.log(`  [IGNORADO] ${codigo} - ${nomeDisciplina.substring(0, 30)}... (Menção: ${mencao})`);
            ignoradas++;
            i += 2;
            continue;
          }
          
          // Remove marcadores do nome (#, *, e)
          const nomeProcessado = nomeDisciplina.replace(/^[#*e]\s+/, '').trim();
          
          disciplinas.push({
            tipo_dado: 'Disciplina Regular',
            nome: this._limparNomeDisciplina(nomeProcessado),
            status: status,
            mencao: mencao === '-' ? '-' : mencao,
            creditos: Math.floor(parseInt(cargaHoraria) / 15),
            codigo: codigo,
            carga_horaria: parseInt(cargaHoraria),
            ano_periodo: anoPeriodo,
            professor: professor,
            turma: turma,
            frequencia: frequencia === '--' ? null : parseFloat(frequencia.replace(',', '.')),
            nota: null
          });
          
          encontradas++;
          console.log(`  ✓ ${codigo} - ${nomeProcessado.substring(0, 40)}... (${status}/${mencao})`);
          
          i += 2; // Pula ambas as linhas processadas
          continue;
        }
      }
      
      i++;
    }
    
    console.log(`[RESULTADO] ${encontradas} disciplinas extraídas, ${ignoradas} ignoradas (menção problemática)`);
    return disciplinas;
  }

  /**
   * FALLBACK: Tenta padrão antigo (8 linhas sequenciais) caso o novo falhe
   */
  _extrairDisciplinasLegado(texto) {
    const disciplinas = [];
    const linhas = texto.split('\n');
    
    console.log(`[FALLBACK] Tentando extração no formato legado (8 linhas)...`);
    
    let i = 0;
    while (i < linhas.length) {
      const linha = linhas[i].trim();
      
      // Padrão 1: Ano/período primeiro, depois nome
      const anoPeriodoMatch = linha.match(this.padroes.anoPeriodo);
      if (anoPeriodoMatch && i + 7 < linhas.length) {
        const anoPeriodo = anoPeriodoMatch[1];
        
        // Verifica se próxima linha é nome da disciplina
        const nomeMatch = linhas[i + 1].trim().match(this.padroes.nomeDisciplina);
        if (nomeMatch) {
          const nome = nomeMatch[1];
          
          try {
            // Linha i+2: turma
            const turmaMatch = linhas[i + 2].trim().match(this.padroes.turma);
            if (!turmaMatch) { i++; continue; }
            const turma = turmaMatch[1];
            
            // Linha i+3: situação
            const situacaoMatch = linhas[i + 3].trim().match(this.padroes.situacao);
            if (!situacaoMatch) { i++; continue; }
            const situacao = situacaoMatch[1];
            
            // Linha i+4: código
            const codigoMatch = linhas[i + 4].trim().match(this.padroes.codigoDisciplina);
            if (!codigoMatch) { i++; continue; }
            const codigo = codigoMatch[1];
            
            // Linha i+5: carga horária
            const cargaMatch = linhas[i + 5].trim().match(this.padroes.cargaHoraria);
            if (!cargaMatch) { i++; continue; }
            const cargaH = cargaMatch[1];
            
            // Linha i+6: frequência
            const freqMatch = linhas[i + 6].trim().match(this.padroes.frequencia);
            if (!freqMatch) { i++; continue; }
            const freq = freqMatch[1];
            
            // Linha i+7: menção
            const mencaoMatch = linhas[i + 7].trim().match(this.padroes.mencao);
            if (!mencaoMatch) { i++; continue; }
            const mencao = mencaoMatch[1];
            
            // Ignora disciplinas com menções II, MI ou SR
            if (['II', 'MI', 'SR'].includes(mencao.toUpperCase())) {
              console.log(`  -> Ignorando disciplina com menção ${mencao}: ${codigo}`);
              i += 8;
              continue;
            }
            
            // Validação adicional: nome não pode ser muito curto
            if (nome.length < 3) {
              console.log(`  -> Ignorando possível falso positivo (nome muito curto): ${nome}`);
              i++;
              continue;
            }
            
            // Procura professor nas próximas linhas
            let professor = '';
            let cargaHProf = cargaH;
            for (let j = i + 8; j < Math.min(linhas.length, i + 12); j++) {
              const profMatch = linhas[j].trim().match(this.padroes.professor);
              if (profMatch) {
                professor = profMatch[1].trim();
                cargaHProf = profMatch[2];
                break;
              }
            }
            
            disciplinas.push({
              tipo_dado: 'Disciplina Regular',
              nome: this._limparNomeDisciplina(nome),
              status: situacao,
              mencao: mencao === '-' ? '-' : mencao,
              creditos: Math.floor(parseInt(cargaHProf) / 15),
              codigo: codigo,
              carga_horaria: parseInt(cargaHProf),
              ano_periodo: anoPeriodo,
              professor: professor,
              turma: turma,
              frequencia: freq === '--' ? null : parseFloat(freq.replace(',', '.')),
              nota: null
            });
            
            console.log(`  -> Disciplina: ${codigo} - ${nome.substring(0, 30)}... (Status: ${situacao})`);
            
            i += 8;
            continue;
          } catch (e) {
            // Se houver erro, continua para próxima linha
          }
        }
      }
      
      // Padrão 2: Nome primeiro, depois ano/período
      const nomeMatch = linha.match(this.padroes.nomeDisciplina);
      if (nomeMatch && i + 8 < linhas.length) {
        const nome = nomeMatch[1];
        
        try {
          // Linha i+1: ano/período
          const anoPeriodoMatch = linhas[i + 1].trim().match(this.padroes.anoPeriodo);
          if (!anoPeriodoMatch) { i++; continue; }
          const anoPeriodo = anoPeriodoMatch[1];
          
          // Linha i+2: turma
          const turmaMatch = linhas[i + 2].trim().match(this.padroes.turma);
          if (!turmaMatch) { i++; continue; }
          const turma = turmaMatch[1];
          
          // Linha i+3: situação
          const situacaoMatch = linhas[i + 3].trim().match(this.padroes.situacao);
          if (!situacaoMatch) { i++; continue; }
          const situacao = situacaoMatch[1];
          
          // Linha i+4: código
          const codigoMatch = linhas[i + 4].trim().match(this.padroes.codigoDisciplina);
          if (!codigoMatch) { i++; continue; }
          const codigo = codigoMatch[1];
          
          // Linha i+5: carga horária
          const cargaMatch = linhas[i + 5].trim().match(this.padroes.cargaHoraria);
          if (!cargaMatch) { i++; continue; }
          const cargaH = cargaMatch[1];
          
          // Linha i+6: frequência
          const freqMatch = linhas[i + 6].trim().match(this.padroes.frequencia);
          if (!freqMatch) { i++; continue; }
          const freq = freqMatch[1];
          
          // Linha i+7: menção
          const mencaoMatch = linhas[i + 7].trim().match(this.padroes.mencao);
          if (!mencaoMatch) { i++; continue; }
          const mencao = mencaoMatch[1];
          
          // Ignora disciplinas com menções II, MI ou SR
          if (['II', 'MI', 'SR'].includes(mencao.toUpperCase())) {
            console.log(`  -> Ignorando disciplina com menção ${mencao}: ${codigo}`);
            disciplinasIgnoradas++;
            i += 8;
            continue;
          }
          
          // Procura professor nas próximas linhas
          let professor = '';
          let cargaHProf = cargaH;
          for (let j = i + 8; j < Math.min(linhas.length, i + 12); j++) {
            const profMatch = linhas[j].trim().match(this.padroes.professor);
            if (profMatch) {
              professor = profMatch[1].trim();
              cargaHProf = profMatch[2];
              break;
            }
          }
          
          disciplinas.push({
            tipo_dado: 'Disciplina Regular',
            nome: this._limparNomeDisciplina(nome),
            status: situacao,
            mencao: mencao === '-' ? '-' : mencao,
            creditos: Math.floor(parseInt(cargaHProf) / 15),
            codigo: codigo,
            carga_horaria: parseInt(cargaHProf),
            ano_periodo: anoPeriodo,
            professor: professor,
            turma: turma,
            frequencia: freq === '--' ? null : parseFloat(freq.replace(',', '.')),
            nota: null
          });
          
          disciplinasEncontradas++;
          console.log(`  -> Disciplina: ${codigo} - ${nome.substring(0, 30)}... (Status: ${situacao})`);
          
          i += 8;
          continue;
        } catch (e) {
          // Se houver erro, continua para próxima linha
        }
      }
      
      i++;
    }
    
    return disciplinas;
  }

  /**
   * Extração de disciplinas pendentes (ainda não cursadas)
   */
  _extrairDisciplinasPendentes(texto) {
    const disciplinas = [];
    
    // Extrair disciplinas pendentes
    this.padroes.pendentesSigaa.lastIndex = 0;
    let matchPendente;
    while ((matchPendente = this.padroes.pendentesSigaa.exec(texto)) !== null) {
      try {
        const nome = matchPendente[1].trim();
        const cargaH = matchPendente[2];
        const codigo = matchPendente[3];
        const statusMatricula = matchPendente[4] || null;
        
        const status = statusMatricula ? 'MATR' : 'PENDENTE';
        
        disciplinas.push({
          tipo_dado: 'Disciplina Pendente',
          nome: this._limparNomeDisciplina(nome),
          status: status,
          mencao: '-',
          creditos: Math.floor(parseInt(cargaH) / 15),
          codigo: codigo,
          carga_horaria: parseInt(cargaH),
          ano_periodo: '',
          prefixo: '',
          observacao: statusMatricula
        });
        
        console.log(`  -> Pendente: ${codigo} - ${nome.substring(0, 30)}... (Status: ${status})`);
      } catch (e) {
        console.warn('Erro ao parsear disciplina pendente:', e);
      }
    }

    return disciplinas;
  }

  /**
   * Extrai as equivalências
   */
  _extrairEquivalencias(texto) {
    const equivalencias = [];
    let match;

    // Reset regex global
    this.padroes.equivalencias.lastIndex = 0;

    while ((match = this.padroes.equivalencias.exec(texto)) !== null) {
      try {
        equivalencias.push({
          codigo_cumprido: match[1],
          nome_cumprido: match[2].trim(),
          carga_horaria_cumprida: parseInt(match[3]),
          codigo_equivalente: match[4],
          nome_equivalente: match[5].trim(),
          carga_horaria_equivalente: parseInt(match[6])
        });
      } catch (e) {
        console.warn('Erro ao parsear equivalência:', e);
        continue;
      }
    }

    return equivalencias;
  }

  /**
   * Extrai as suspensões
   */
  _extrairSuspensoes(texto) {
    const match = this.padroes.suspensoes.exec(texto);
    if (match && match[1]) {
      return match[1]
        .split(',')
        .map(s => s.trim())
        .filter(s => s.length > 0);
    }
    return [];
  }

  /**
   * Extrai o semestre atual baseado em disciplinas matriculadas
   */
  _extrairSemestreAtual(disciplinas) {
    const matriculadas = disciplinas
      .filter(d => d.status === 'MATR')
      .map(d => d.ano_periodo);

    if (matriculadas.length === 0) return null;

    // Retorna o semestre mais recente
    matriculadas.sort((a, b) => {
      const aNum = parseFloat(a);
      const bNum = parseFloat(b);
      return bNum - aNum;
    });

    return matriculadas[0];
  }

  /**
   * Calcula o número do semestre
   */
  _calcularNumeroSemestre(disciplinas) {
    // Conta semestres únicos
    const semestres = [...new Set(disciplinas.map(d => d.ano_periodo))];
    
    semestres.sort((a, b) => {
      const aNum = parseFloat(a);
      const bNum = parseFloat(b);
      return aNum - bNum;
    });

    return semestres.length;
  }

  /**
   * Limpa o nome da disciplina removendo padrões desnecessários
   */
  _limparNomeDisciplina(nome) {
    // Remove padrões de período
    nome = nome.replace(/^\d{4}\.\d\s*/, '');
    // Remove caracteres especiais do início e fim
    nome = nome.replace(/^[^\w\s]+|[^\w\s]+$/g, '');
    // Remove espaços extras
    nome = nome.replace(/\s+/g, ' ').trim();
    return nome;
  }
}

// Exporta para uso em módulos ES6
if (typeof module !== 'undefined' && module.exports) {
  module.exports = PdfHistoricoParser;
}

// Exemplo de uso:
/*
const parser = new PdfHistoricoParser();

// Com input file do HTML
document.getElementById('pdfInput').addEventListener('change', async (e) => {
  const file = e.target.files[0];
  if (file) {
    try {
      const result = await parser.parsePdf(file, '12345678');
      console.log('Dados extraídos:', result);
      // Processar resultado...
    } catch (error) {
      console.error('Erro:', error);
    }
  }
});
*/
