import { EndpointController, RequestType } from "../interfaces";
import { Pair, Utils } from "../utils";
import { Request, Response } from "express";
import { SupabaseWrapper } from "../supabase_wrapper";
import axios from 'axios';
import FormData from 'form-data';
import { createControllerLogger } from '../utils/controller_logger';


export const MateriasController: EndpointController = {
    name: "materias",
    routes: {
        "materias-name-by-code": new Pair(RequestType.GET, async (req: Request, res: Response) => {
            const logger = createControllerLogger("MateriasController", "materias-name-by-code");
            logger.info(`Buscando nome das matérias por código`);

            // get all materias names for the codes
            const {codes} = req.body;

            if(!codes) {
                logger.error("Códigos não informados");
                return res.status(400).json({ error: "Códigos não informados" });
            }

            const materias = await SupabaseWrapper.get().from("materias").select("*").in("codigo_materia", codes);

            if(materias.error) {
                logger.error(`Erro ao buscar matérias: ${materias.error.message}`);
                return res.status(500).json({ error: materias.error.message });
            }

            return res.status(200).json(materias.data);
        }),

    }
}