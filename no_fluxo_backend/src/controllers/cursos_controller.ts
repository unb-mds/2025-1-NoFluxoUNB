import { EndpointController, RequestType } from "../interfaces";
import { Pair, Utils } from "../utils";
import { Request, Response } from "express";
import { SupabaseWrapper } from "../supabase_wrapper";
import axios from 'axios';
import FormData from 'form-data';
import { createControllerLogger } from '../utils/controller_logger';


export const CursosController: EndpointController = {
    name: "cursos",
    routes: {
        "all-cursos": new Pair(RequestType.GET, async (req: Request, res: Response) => {
            const logger = createControllerLogger("CursosController", "all-cursos");
            logger.info(`Buscando todos os cursos`);

            const cursos = await SupabaseWrapper.get().from("cursos").select("*,creditos_por_curso(*)");

            if (cursos.error) {
                logger.error(`Erro ao buscar cursos: ${cursos.error.message}`);
                return res.status(500).json({ error: cursos.error.message });
            }

            return res.status(200).json(cursos.data);
        }),

    }
}