import logger from '../logger';

export class ControllerLogger {
    private controller: string;
    private endpoint: string;

    constructor(controller: string, endpoint: string) {
        this.controller = controller;
        this.endpoint = endpoint;
    }

    private formatMessage(message: string): string {
        return `\b[${this.controller}][${this.endpoint}] ${message}`;
    }

    info(message: string): void {
        logger.info(this.formatMessage(message));
    }

    error(message: string): void {
        logger.error(this.formatMessage(message));
    }

    warn(message: string): void {
        logger.warn(this.formatMessage(message));
    }

    http(message: string): void {
        logger.http(this.formatMessage(message));
    }

    debug(message: string): void {
        logger.debug(this.formatMessage(message));
    }
}

export function createControllerLogger(controller: string, endpoint: string): ControllerLogger {
    return new ControllerLogger(controller, endpoint);
}