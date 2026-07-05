import { SupabaseWrapper } from "./supabase_wrapper";
import { createControllerLogger } from "./utils/controller_logger";
import { Request } from "express";


export class Pair<K, V> {
    key: K;
    value: V;

    constructor(key: K, value: V) {
        this.key = key;
        this.value = value;
    }
}

// logger for utils
const utilsLogger = createControllerLogger("Utils", "Utils");

export const Utils = {

    checkAuthorization: async (req: Request) => {
        const headers = req.headers;

        // DEV-ONLY: bypass de autorização para impersonação local.
        // Gated por NODE_ENV !== 'production'. Header X-Dev-Impersonate carrega o
        // email do usuário a impersonar; o User-ID continua sendo lido normalmente.
        // Útil para Playwright e debug manual sem precisar logar via Supabase.
        if (process.env.NODE_ENV !== "production") {
            const devImpersonate = headers["x-dev-impersonate"];
            if (devImpersonate && typeof devImpersonate === "string") {
                const userId = headers["user-id"];
                if (!userId) {
                    utilsLogger.error("[DEV-IMPERSONATE] User-ID header obrigatório mesmo com X-Dev-Impersonate");
                    return false;
                }
                const { data: user, error: userError } = await SupabaseWrapper.get()
                    .from("users")
                    .select("*")
                    .eq("id_user", userId);
                if (userError || !user || user.length === 0) {
                    utilsLogger.error(`[DEV-IMPERSONATE] usuário ${userId} não encontrado`);
                    return false;
                }
                if (user[0].email !== devImpersonate) {
                    utilsLogger.error(`[DEV-IMPERSONATE] email ${devImpersonate} não bate com idUser ${userId}`);
                    return false;
                }
                utilsLogger.info(`[DEV-IMPERSONATE] autorizando ${devImpersonate} (idUser=${userId})`);
                return true;
            }
        }

        const authorization = headers["authorization"];
        utilsLogger.info(`Authorization header: ${authorization}`);
        if (!authorization) {
            utilsLogger.error("Authorization header not found");
            return false;
        }

        if (typeof authorization !== "string") {
            utilsLogger.error(`Authorization header is not a string: ${authorization}`);
            return false;
        }

        let token = authorization;
        if (typeof token === "string" && token.startsWith("Bearer ")) {
            token = token.slice(7);
        }
        var { data, error } = await SupabaseWrapper.get().auth.getUser(token);
        if (error) {
            utilsLogger.error(`Erro ao verificar autorização: ${error.message}`);
            return false;
        }

        //check for User-ID header
        const userId = headers["user-id"];
        if (!userId) {
            utilsLogger.error("User-ID header not found");
            return false;
        }

        // check on db if user exists
        var { data: user, error: userError } = await SupabaseWrapper.get().from("users").select("*").eq("id_user", userId);
        if (userError) {
            utilsLogger.error(`Erro ao verificar usuário: ${userError.message}`);
            return false;
        }

        if (user === null || user.length === 0) {
            utilsLogger.error(`Usuário não encontrado: ${userId}`);
            return false;
        }

        if (user[0].email !== data.user?.email) {
            utilsLogger.error(`Usuário não autorizado: ${userId} !== ${data.user?.email}`);
            return false;
        }

        return true;
    }
}