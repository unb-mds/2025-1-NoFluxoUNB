# Script de exemplo para testar a API de testes do NoFluxo Backend
# Certifique-se de que o servidor está rodando em localhost:3000

$BaseUrl = "http://localhost:3000/testes"

Write-Host "🧪 Iniciando testes da API NoFluxo Backend" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green

# Teste 1: Conexão com banco
Write-Host ""
Write-Host "1️⃣ Testando conexão com banco..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$BaseUrl/banco" -Method GET
    $response | ConvertTo-Json -Depth 10
} catch {
    Write-Host "❌ Erro ao testar conexão com banco: $($_.Exception.Message)" -ForegroundColor Red
}

# Teste 2: Busca de curso
Write-Host ""
Write-Host "2️⃣ Testando busca de curso..." -ForegroundColor Yellow
try {
    $curso = "Engenharia de Software"
    $encodedCurso = [System.Web.HttpUtility]::UrlEncode($curso)
    $response = Invoke-RestMethod -Uri "$BaseUrl/curso?nome_curso=$encodedCurso" -Method GET
    $response | ConvertTo-Json -Depth 10
} catch {
    Write-Host "❌ Erro ao testar busca de curso: $($_.Exception.Message)" -ForegroundColor Red
}

# Teste 3: Casamento de disciplinas
Write-Host ""
Write-Host "3️⃣ Testando casamento de disciplinas..." -ForegroundColor Yellow
try {
    $body = @{
        nome_curso = "Engenharia de Software"
        dados_extraidos = @{
            extracted_data = @(
                @{
                    tipo_dado = "Disciplina Regular"
                    nome = "Cálculo I"
                    codigo = "MAT001"
                    status = "APR"
                    carga_horaria = 60
                },
                @{
                    tipo_dado = "Disciplina Regular"
                    nome = "Programação I"
                    codigo = "INF001"
                    status = "APR"
                    carga_horaria = 60
                },
                @{
                    tipo_dado = "Disciplina Regular"
                    nome = "Física I"
                    codigo = "FIS001"
                    status = "REP"
                    carga_horaria = 60
                }
            )
        }
    } | ConvertTo-Json -Depth 10

    $headers = @{
        "Content-Type" = "application/json"
    }

    $response = Invoke-RestMethod -Uri "$BaseUrl/casamento" -Method POST -Body $body -Headers $headers
    $response | ConvertTo-Json -Depth 10
} catch {
    Write-Host "❌ Erro ao testar casamento de disciplinas: $($_.Exception.Message)" -ForegroundColor Red
}

# Teste 4: Teste completo
Write-Host ""
Write-Host "4️⃣ Executando teste completo..." -ForegroundColor Yellow
try {
    $body = @{
        nome_curso = "Engenharia de Software"
        dados_extraidos = @{
            extracted_data = @(
                @{
                    tipo_dado = "Disciplina Regular"
                    nome = "Cálculo I"
                    codigo = "MAT001"
                    status = "APR"
                    carga_horaria = 60
                },
                @{
                    tipo_dado = "Disciplina Regular"
                    nome = "Programação I"
                    codigo = "INF001"
                    status = "APR"
                    carga_horaria = 60
                }
            )
        }
    } | ConvertTo-Json -Depth 10

    $headers = @{
        "Content-Type" = "application/json"
    }

    $response = Invoke-RestMethod -Uri "$BaseUrl/completo" -Method POST -Body $body -Headers $headers
    $response | ConvertTo-Json -Depth 10
} catch {
    Write-Host "❌ Erro ao executar teste completo: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "✅ Testes concluídos!" -ForegroundColor Green
Write-Host ""
Write-Host "💡 Dicas:" -ForegroundColor Cyan
Write-Host "   - Verifique se o servidor está rodando em localhost:3000" -ForegroundColor White
Write-Host "   - Consulte API_TESTES.md para mais detalhes" -ForegroundColor White
Write-Host "   - Use Postman ou Insomnia para testes mais avançados" -ForegroundColor White 