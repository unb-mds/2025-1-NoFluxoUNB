import { EndpointController, RequestType } from "../interfaces";
import { Pair } from "../utils";
import { Request, Response } from "express";
import { SupabaseWrapper } from "../supabase_wrapper";
import { createControllerLogger } from '../utils/controller_logger';

export const UsersController: EndpointController = {
    name: "users",
    routes: {
        "register-user-with-google": new Pair(RequestType.POST, async (req: Request, res: Response) => {
            const logger = createControllerLogger("UsersController", "register-user-with-google");
            logger.info(`Registrando usuário com Google: ${JSON.stringify(req.body)}`);

            const { email, nome_completo } = req.body;

            if (!email || !nome_completo) {
                logger.error("Email e nome completo são obrigatórios");
                return res.status(400).json({ error: "Email e nome completo são obrigatórios" });
            }

            var { data: userExistsResult, error: userExistsError } = await SupabaseWrapper.get().from("users").select("*").eq("email", email);

            if (userExistsError) {
                logger.error(`Erro ao buscar usuário: ${JSON.stringify(userExistsError)}`);
                return res.status(500).json({ error: "Erro ao buscar usuário" });
            }

            if (userExistsResult && userExistsResult.length > 0) {
                logger.error("Usuário já cadastrado");
                return res.status(400).json({ error: "Usuário já cadastrado" });
            }

            var { data: userCreatedResult, error: userCreatedError } = await SupabaseWrapper.get().from("users").insert({
                email,
                nome_completo
            }).select("*").single();

            if (userCreatedError) {
                logger.error(`Erro ao criar usuário: ${JSON.stringify(userCreatedError)}`);
                return res.status(500).json({ error: "Erro ao criar usuário" });
            }

            logger.info(`Usuário criado com sucesso: ${JSON.stringify(userCreatedResult)}`);
            return res.status(200).json(userCreatedResult);
        }),

        "get-user-by-email": new Pair(RequestType.GET, async (req: Request, res: Response) => {
            const logger = createControllerLogger("UsersController", "get-user-by-email");
            logger.info(`Buscando usuário por email: ${JSON.stringify(req.query)}`);

            const { email } = req.query;
            if (!email) {
                logger.error("Email é obrigatório");
                return res.status(400).json({ error: "Email é obrigatório" });
            }

            var { data: userResult, error: userError } = await SupabaseWrapper.get().from("users").select("*,dados_users(*)").eq("email", email);

            if (userError) {
                logger.error(`Erro ao buscar usuário: ${JSON.stringify(userError)}`);
                return res.status(500).json({ error: "Erro ao buscar usuário" });
            }

            if (userResult && userResult.length > 0) {
                return res.status(200).json(userResult[0]);
            }

            return res.status(404).json({ error: "Usuário não encontrado" });
        }),
        "registrar-user-with-email": new Pair(RequestType.POST, async (req: Request, res: Response) => {
            const logger = createControllerLogger("UsersController", "registrar-user-with-email");
            logger.info(`Registrando usuário com email: ${JSON.stringify(req.body)}`);

            const { email, nome_completo } = req.body;

            if (!email || !nome_completo) {
                logger.error("Email e nome completo são obrigatórios");
                return res.status(400).json({ error: "Email e nome completo são obrigatórios" });
            }

            var { data: userExistsResult, error: userExistsError } = await SupabaseWrapper.get().from("users").select("*").eq("email", email);

            if (userExistsError) {
                logger.error(`Erro ao buscar usuário: ${JSON.stringify(userExistsError)}`);
                return res.status(500).json({ error: "Erro ao buscar usuário" });
            }

            if (userExistsResult && userExistsResult.length > 0) {
                logger.error("Usuário já cadastrado");
                return res.status(400).json({ error: "Usuário já cadastrado" });
            }

            var { data: userCreatedResult, error: userCreatedError } = await SupabaseWrapper.get().from("users").insert({
                email,
                nome_completo
            }).select("*").single();

            if (userCreatedError) {
                logger.error(`Erro ao criar usuário: ${JSON.stringify(userCreatedError)}`);
                return res.status(500).json({ error: "Erro ao criar usuário" });
            }

            logger.info(`Usuário criado com sucesso: ${JSON.stringify(userCreatedResult)}`);
            return res.status(200).json(userCreatedResult);
        })
    }
} 