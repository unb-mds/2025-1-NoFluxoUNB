import { Pair } from "./utils";
import { Request, Response } from 'express';

export enum RequestType {
    GET = "GET",
    POST = "POST",
    PUT = "PUT",
    DELETE = "DELETE",
    
}

export interface EndpointController {
    name: string;
    routes: {
        [key: string]: Pair<RequestType, (req: Request, res: Response) => Promise<Response | void>>
    };
}

