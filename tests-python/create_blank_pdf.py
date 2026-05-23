
from pypdf import PdfWriter

def create_blank_pdf(path):
    """
    Creates a blank PDF file.
    """
    pdf = PdfWriter()
    pdf.add_blank_page(width=612, height=792)
    with open(path, "wb") as f:
        pdf.write(f)

if __name__ == '__main__':
    create_blank_pdf("blank.pdf")
