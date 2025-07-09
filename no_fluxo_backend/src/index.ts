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
import { spawn } from 'child_process';
import path from 'path';
import { CursosController } from './controllers/cursos_controller';

dotenv.config();

SupabaseWrapper.init();
logger.info('Supabase client initialized');

// start the ragflow agent server
const ragflowAgentProcess = spawn('python', ['AI-agent/app.py', "--port", "4652"], {
    cwd: path.join(__dirname, '..')
});

ragflowAgentProcess.stdout.on('data', (data) => {
    logger.info(`\b[RAGFlow Agent] ${data}`);
});

ragflowAgentProcess.stderr.on('data', (data) => {
    logger.error(`\b[RAGFlow Agent] ${data}`);
});

ragflowAgentProcess.on('close', (code) => {
    if (code !== 0) {
        logger.error(`\b[RAGFlow Agent] process exited with code ${code}`);
    }
});

// Start the Python PDF parser server
const pythonProcess = spawn('python', ['parse-pdf/pdf_parser_final.py'], {
    cwd: path.join(__dirname, '..')
});

pythonProcess.stdout.on('data', (data) => {
    logger.info(`\b[PDF Parser] ${data}`);
});

pythonProcess.stderr.on('data', (data) => {
    logger.error(`\b[PDF Parser] ${data}`);
});

pythonProcess.on('close', (code) => {
    if (code !== 0) {
        logger.error(`\b[PDF Parser] process exited with code ${code}`);
    }
});

// Handle Node.js process termination
const cleanup = () => {
    logger.info('[PDF Parser] Terminating Python process...');
    pythonProcess.kill();
    ragflowAgentProcess.kill();
};


// Handle normal exit
process.on('exit', cleanup);

// Handle CTRL+C
process.on('SIGINT', () => {
    cleanup();
    process.exit(0);
});

// Handle uncaught exceptions
process.on('uncaughtException', (err) => {
    logger.error('Uncaught Exception:', err);
    cleanup();
    process.exit(1);
});

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
    logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
    cleanup();
    process.exit(1);
});

const router = express.Router();

const controllers: EndpointController[] = [
    FluxogramaController,
    TestesController,
    UsersController,
    CursosController
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
            default:
                logger.warn(`Unhandled request type: ${method} for route ${routePath}`);
                break;
        }
    });
});

const app: Express = express();

//expressws(app);

// Configure CORS properly
app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Origin', 'X-Requested-With', 'Content-Type', 'Accept', 'Authorization', 'User-ID']
}));

app.use(fileUpload())
app.use(bodyParser.json({ limit: 500 * 1024 * 1024, }));
app.use(bodyParser.urlencoded({ extended: true, limit: 500 * 1024 * 1024 }));


app.use(router);

const port = process.env.PORT ?? 3000;
app.listen(port, () => {
    logger.info(`Server running on port ${port}`);
});





