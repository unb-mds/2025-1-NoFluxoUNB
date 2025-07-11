from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas
from reportlab.lib.units import cm

def gerar_historico_unb(filename="historico_unb_teste.pdf"):
    c = canvas.Canvas(filename, pagesize=A4)
    largura, altura = A4

    # Título
    c.setFont("Helvetica-Bold", 16)
    c.drawCentredString(largura / 2, altura - 2*cm, "UNIVERSIDADE DE BRASÍLIA - UNB")
    c.setFont("Helvetica", 12)
    c.drawCentredString(largura / 2, altura - 2.7*cm, "Histórico Escolar")

    # Dados do aluno
    c.setFont("Helvetica-Bold", 11)
    c.drawString(2*cm, altura - 4*cm, "Nome do Aluno:")
    c.setFont("Helvetica", 11)
    c.drawString(5.5*cm, altura - 4*cm, "João da Silva")

    c.setFont("Helvetica-Bold", 11)
    c.drawString(2*cm, altura - 4.7*cm, "Matrícula:")
    c.setFont("Helvetica", 11)
    c.drawString(5.5*cm, altura - 4.7*cm, "202312345")

    c.setFont("Helvetica-Bold", 11)
    c.drawString(2*cm, altura - 5.4*cm, "Curso:")
    c.setFont("Helvetica", 11)
    c.drawString(5.5*cm, altura - 5.4*cm, "Engenharia de Software")

    # Cabeçalho da tabela de disciplinas
    c.setFont("Helvetica-Bold", 10)
    y = altura - 7*cm
    c.drawString(2*cm, y, "Código")
    c.drawString(5*cm, y, "Disciplina")
    c.drawString(12*cm, y, "Créditos")
    c.drawString(15*cm, y, "Nota")

    # Lista de disciplinas
    disciplinas = [
        ("MAT101", "Cálculo I", 4, "8.5"),
        ("FIS101", "Física I", 4, "7.0"),
        ("PROG101", "Introdução à Programação", 4, "9.0"),
        ("ALG101", "Álgebra Linear", 3, "8.0"),
        ("PORT101", "Comunicação", 2, "9.5")
    ]

    c.setFont("Helvetica", 10)
    y -= 0.7*cm
    for codigo, nome, creditos, nota in disciplinas:
        c.drawString(2*cm, y, codigo)
        c.drawString(5*cm, y, nome)
        c.drawString(13*cm, y, str(creditos))
        c.drawString(15*cm, y, nota)
        y -= 0.6*cm

    # Assinatura
    c.setFont("Helvetica", 10)
    c.drawString(2*cm, 3*cm, "Brasília, 03 de julho de 2025")
    c.drawString(2*cm, 2*cm, "______________________________")
    c.drawString(2*cm, 1.5*cm, "Secretaria Acadêmica")

    c.save()
    print(f"Arquivo '{filename}' criado com sucesso!")

if __name__ == "__main__":
    gerar_historico_unb()
