import { createClient } from '@supabase/supabase-js'
import { SupabaseWrapper } from './supabase_wrapper'
import express, { Express, Request, Response } from 'express';
import dotenv from "dotenv";
import { Utils } from './utils';
import { EndpointController, RequestType } from './interfaces';
import fileUpload from 'express-fileupload';
import bodyParser from 'body-parser';
import cors from "cors";
import { FluxogramaController } from './controllers/fluxograma_controller';
import { TestesController } from './controllers/testes_controller';
import logger from './logger';
import { UsersController } from './controllers/users_controller';

dotenv.config();

SupabaseWrapper.init();
logger.info('Supabase client initialized');

const router = express.Router();

const controllers: EndpointController[] = [
    FluxogramaController,
    TestesController,
    UsersController
];

controllers.forEach(controller => {
    Object.keys(controller.routes).forEach(route_name => {
        const route = controller.routes[route_name];
        const method = route.key;
        const callback = route.value;
        const routePath = `/${controller.name}/${route_name}`;

        logger.info(`Registering route: ${method} ${routePath}`);

        switch (method) {
            case RequestType.GET:
                router.get(routePath, async (req: Request, res: Response) => {
                    try {
                        logger.http(`GET request to ${routePath}`);
                        await callback(req, res);
                        logger.http(`GET request to ${routePath} completed successfully`);
                    } catch (error) {
                        logger.error(`Error handling GET request to ${routePath}: ${error}`);
                        res.status(500).json({ error: 'Internal server error' });
                    }
                });
                break;
            case RequestType.POST:
                router.post(routePath, async (req: Request, res: Response) => {
                    try {
                        logger.http(`POST request to ${routePath}`);
                        await callback(req, res);
                        logger.http(`POST request to ${routePath} completed successfully`);
                    } catch (error) {
                        logger.error(`Error handling POST request to ${routePath}: ${error}`);
                        res.status(500).json({ error: 'Internal server error' });
                    }
                });
                break;
            case RequestType.PUT:
                router.put(routePath, async (req: Request, res: Response) => {
                    try {
                        logger.http(`PUT request to ${routePath}`);
                        await callback(req, res);
                        logger.http(`PUT request to ${routePath} completed successfully`);
                    } catch (error) {
                        logger.error(`Error handling PUT request to ${routePath}: ${error}`);
                        res.status(500).json({ error: 'Internal server error' });
                    }
                });
                break;
            default:
                logger.warn(`Unhandled request type: ${method} for route ${routePath}`);
                break;
        }
    });
});

const app: Express = express();

//expressws(app);

app.use(fileUpload())
app.use(bodyParser.json({ limit: 500 * 1024 * 1024, }));
app.use(bodyParser.urlencoded({ extended: true, limit: 500 * 1024 * 1024 }));
app.use(function (req, res, next) {
    logger.http(`${req.method} ${req.url}`);
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept, Authorization");
    next();
});

app.use(router);

const port = process.env.PORT ?? 3000;
app.listen(port, () => {
    logger.info(`Server running on port ${port}`);
});





