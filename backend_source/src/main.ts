import '@common/utils/bootstrap/patch-bigint';

import { utilities as nestWinstonModuleUtilities, WinstonModule } from 'nest-winston';
import { patchNestJsSwagger, ZodValidationPipe } from 'nestjs-zod';
import relativeTime from 'dayjs/plugin/relativeTime';
import timezone from 'dayjs/plugin/timezone';
import { createLogger } from 'winston';
import compression from 'compression';
import * as winston from 'winston';
import utc from 'dayjs/plugin/utc';
import { json } from 'express';
import helmet from 'helmet';
import morgan from 'morgan';
import dayjs from 'dayjs';

import { ROOT } from '@contract/api';

import { NestExpressApplication } from '@nestjs/platform-express';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';

import { getDocs, isDevelopment, isDevOrDebugLogsEnabled } from '@common/utils/startup-app';
import { proxyCheckMiddleware, getRealIp, noRobotsMiddleware } from '@common/middlewares';
import { getStartMessage } from '@common/utils/startup-app/get-start-message';
import { customLogFilter } from '@common/utils/filter-logs';
import { AxiosService } from '@common/axios';

import { AppModule } from './app.module';

dayjs.extend(utc);
dayjs.extend(relativeTime);
dayjs.extend(timezone);

patchNestJsSwagger();

const instanceId = process.env.INSTANCE_ID || '0';

const logger = createLogger({
    transports: [new winston.transports.Console()],
    format: winston.format.combine(
        customLogFilter(),
        winston.format.timestamp({
            format: 'YYYY-MM-DD HH:mm:ss.SSS',
        }),
        // winston.format.ms(),
        winston.format.align(),
        nestWinstonModuleUtilities.format.nestLike(`API Server: #${instanceId}`, {
            colors: true,
            prettyPrint: true,
            processId: false,
            appName: true,
        }),
    ),
    level: isDevOrDebugLogsEnabled() ? 'debug' : 'http',
});

async function bootstrap(): Promise<void> {
    const app = await NestFactory.create<NestExpressApplication>(AppModule, {
        logger: WinstonModule.createLogger({
            instance: logger,
        }),
    });

    app.disable('x-powered-by');

    app.use(json({ limit: '100mb' }));

    const config = app.get(ConfigService);

    app.use(
        helmet({
            contentSecurityPolicy: {
                directives: {
                    defaultSrc: ["'self'", '*'],
                    scriptSrc: ["'self'", "'unsafe-inline'", "'unsafe-eval'", '*'],
                    imgSrc: ["'self'", 'data:', '*'],
                    connectSrc: ["'self'", '*'],
                    workerSrc: ["'self'", 'blob:', '*'],
                    frameSrc: ["'self'", 'oauth.telegram.org', '*'],
                    frameAncestors: ["'self'", '*'],
                },
            },

            crossOriginOpenerPolicy: { policy: 'same-origin-allow-popups' },
            crossOriginResourcePolicy: { policy: 'same-site' },
            referrerPolicy: {
                policy: 'strict-origin-when-cross-origin',
            },
        }),
    );

    app.use(compression());

    app.use(getRealIp);

    if (config.getOrThrow<string>('IS_HTTP_LOGGING_ENABLED') === 'true') {
        app.use(
            morgan(
                ':remote-addr - ":method :url HTTP/:http-version" :status :res[content-length] ":referrer" ":user-agent"',
            ),
        );
    }

    app.use(noRobotsMiddleware, proxyCheckMiddleware);

    app.setGlobalPrefix(ROOT);

    await getDocs(app, config);

    app.enableCors({
        origin: isDevelopment() ? '*' : config.getOrThrow<string>('FRONT_END_DOMAIN'),
        methods: 'GET,HEAD,PUT,PATCH,POST,DELETE',
        credentials: false,
    });

    app.useGlobalPipes(new ZodValidationPipe());

    app.enableShutdownHooks();

    await app.listen(Number(config.getOrThrow<string>('APP_PORT')));

    const axiosService = app.get(AxiosService);
    await axiosService.setJwt();

    logger.info('\n' + (await getStartMessage()) + '\n');
}
void bootstrap();
