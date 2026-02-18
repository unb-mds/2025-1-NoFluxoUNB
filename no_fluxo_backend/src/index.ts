import { createClient } from '@supabase/supabase-js'
import { SupabaseWrapper } from './supabase_wrapper'
import express, { Express, Request, Response } from 'express';
import dotenv from "dotenv";
import { Utils } from './utils';
import { EndpointController, RequestType } from './interfaces';
import bodyParser from 'body-parser';
import cors from "cors";
import { FluxogramaController } from './controllers/fluxograma_controller';
import { TestesController } from './controllers/testes_controller';
import logger from './logger';
import { UsersController } from './controllers/users_controller';
import { CursosController } from './controllers/cursos_controller';
import { MateriasController } from './controllers/materias_controller';
import { AssistenteController } from './controllers/assistente_controller';

dotenv.config();

SupabaseWrapper.init();
logger.info('Supabase client initialized');

// Handle CTRL+C
process.on('SIGINT', () => {
    process.exit(0);
});

process.on('SIGTERM', () => {
    process.exit(0);
});

// Handle uncaught exceptions
process.on('uncaughtException', (err) => {
    logger.error('Uncaught Exception:', err);
    process.exit(1);
});

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
    logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
    process.exit(1);
});



const router = express.Router();

const controllers: EndpointController[] = [
    FluxogramaController,
    TestesController,
    UsersController,
    CursosController,
    MateriasController,
    AssistenteController,
];
router.get('/', (req: Request, res: Response) => {
    logger.info(`\b[GET][/]`);

    res.json({
        status: 'online',
        timestamp: new Date().toISOString(),
        version: '1.0.0',
        serverInfo: {
            nodeVersion: process.version,
            platform: process.platform,
            memoryUsage: process.memoryUsage(),
            uptime: process.uptime()
        },
        endpoints: controllers.map(controller => ({
            name: controller.name,
            description: `${controller.name} API endpoints`,
            routes: Object.keys(controller.routes).map(route => ({
                path: `/${controller.name}/${route}`,
                method: controller.routes[route].key,
                fullPath: `${req.protocol}://${req.get('host')}/${controller.name}/${route}`
            })),
            totalRoutes: Object.keys(controller.routes).length
        })),
        documentation: {
            swagger: `${req.protocol}://${req.get('host')}/api-docs`,
            postman: `${req.protocol}://${req.get('host')}/postman-collection`
        }
    });
});

// Health check endpoint for Kubernetes probes
router.get('/health', (req: Request, res: Response) => {
    res.status(200).json({ status: 'healthy', timestamp: new Date().toISOString() });
});

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
                        logger.http(`\b[GET][${routePath}]`);
                        await callback(req, res);
                        logger.http(`\b[GET][${routePath}] completed successfully`);
                    } catch (error) {
                        logger.error(`\b[GET][${routePath}] Error: ${error}`);
                        res.status(500).json({ error: 'Internal server error' });
                    }
                });
                break;
            case RequestType.POST:
                router.post(routePath, async (req: Request, res: Response) => {
                    try {
                        logger.http(`\b[POST][${routePath}]`);
                        await callback(req, res);
                        logger.http(`\b[POST][${routePath}] completed successfully`);
                    } catch (error) {
                        logger.error(`\b[POST][${routePath}] Error: ${error}`);
                        res.status(500).json({ error: 'Internal server error' });
                    }
                });
                break;
            case RequestType.PUT:
                router.put(routePath, async (req: Request, res: Response) => {
                    try {
                        logger.http(`\b[PUT][${routePath}]`);
                        await callback(req, res);
                        logger.http(`\b[PUT][${routePath}] completed successfully`);
                    } catch (error) {
                        logger.error(`\b[PUT][${routePath}] Error: ${error}`);
                        res.status(500).json({ error: 'Internal server error' });
                    }
                });
                break;
            case RequestType.DELETE:
                router.delete(routePath, async (req: Request, res: Response) => {
                    try {
                        logger.http(`\b[DELETE][${routePath}]`);
                        await callback(req, res);
                        logger.http(`\b[DELETE][${routePath}] completed successfully`);
                    } catch (error) {
                        logger.error(`\b[DELETE][${routePath}] Error: ${error}`);
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

// Configure CORS properly (allow prod and local origins) and ensure preflight succeeds
const allowedOrigins = new Set<string>([
    'https://www.no-fluxo.com',
    'https://no-fluxo.com',
    'https://simplifica-pbl.space',
    'http://localhost:3000',
    'http://localhost:5000',


]);

app.use(cors({
    origin: (origin, callback) => {
        // Allow non-browser or same-origin requests
        if (!origin) return callback(null, true);
        if (allowedOrigins.has(origin)) return callback(null, true);
        // Fallback: allow any origin to avoid accidental blocks (adjust if you want strict policy)
        return callback(null, true);
    },
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Origin', 'X-Requested-With', 'Content-Type', 'Accept', 'Authorization', 'User-ID'],
    credentials: false,
    optionsSuccessStatus: 204,
}));

// Make sure OPTIONS preflight is handled quickly
app.options('*', cors());

app.use(bodyParser.json({ limit: 500 * 1024 * 1024, }));
app.use(bodyParser.urlencoded({ extended: true, limit: 500 * 1024 * 1024 }));


app.use(router);

const port = process.env.PORT ?? 3000;
app.listen(port, () => {
    logger.info(`Server running on port ${port}`);
});





