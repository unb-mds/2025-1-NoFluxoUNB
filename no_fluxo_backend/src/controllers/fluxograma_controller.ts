import { EndpointController, RequestType } from "../interfaces";
import { Pair } from "../utils";
import { Request, Response } from "express";
import { SupabaseWrapper } from "../supabase_wrapper";
import axios from 'axios';
import FormData from 'form-data';


export const FluxogramaController: EndpointController = {
    name: "fluxograma",
    routes: {
        "fluxograma": new Pair(RequestType.GET, async (req: Request, res: Response) => {

            console.log(`Chamando fluxograma`);
            const nome_curso = req.query.nome_curso as string;

            console.log(nome_curso);
            if (!nome_curso) {
                console.log(`Nome do curso não informado`);
                return res.status(400).json({ error: "Nome do curso não informado" });
            }


            const { data, error } = await SupabaseWrapper.get().from("cursos").select("*,materias_por_curso(materias(*))").like("nome_curso","%"+req.query.nome_curso+"%");

            if (error) {
                console.log(error);
                return res.status(500).json({ error: error.message });
            }

            console.log(data);

            return res.status(200).json(data);
        }),

        "read_pdf": new Pair(RequestType.POST, async (req: Request, res: Response) => {
            try {
                if (!req.files || !req.files.pdf) {
                    return res.status(400).json({ error: "Arquivo PDF não enviado." });
                }

                const pdfFile = Array.isArray(req.files.pdf) ? req.files.pdf[0] : req.files.pdf;
                const form = new FormData();
                form.append('pdf', pdfFile.data, pdfFile.name);

                // Envia para o Python
                const response = await axios.post(
                    'http://localhost:3001/upload-pdf',
                    form,
                    { headers: form.getHeaders() }
                );

                // Retorna a resposta do Python para o frontend
                return res.status(200).json(response.data);
            } catch (error: any) {
                return res.status(500).json({ error: error.message || "Erro ao processar PDF" });
            }
        })
    }
}