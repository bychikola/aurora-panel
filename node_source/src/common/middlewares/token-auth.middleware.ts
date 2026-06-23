import { NextFunction, Request, Response } from 'express';

import { Injectable, NestMiddleware } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

const HEADER_NAME = 'x-aurora-internal-token';

@Injectable()
export class TokenAuthMiddleware implements NestMiddleware {
    private readonly token: string;

    constructor(private readonly configService: ConfigService) {
        this.token = this.configService.getOrThrow<string>('INTERNAL_REST_TOKEN');
    }

    use(req: Request, res: Response, next: NextFunction): void {
        // Accept token from header (preferred) or query param (backward compat)
        const token = req.headers[HEADER_NAME] as string | undefined
            ?? req.query.token as string | undefined;

        if (!token || !this.token || token !== this.token) {
            res.socket?.destroy();
            return;
        }

        next();
    }
}
