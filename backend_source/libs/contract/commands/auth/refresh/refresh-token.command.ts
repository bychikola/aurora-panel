import { REST_API } from '../../../api/routes';
import { z } from 'zod';

export namespace RefreshTokenCommand {
    export const url = REST_API.AUTH.REFRESH;

    export const RequestSchema = z.object({
        refreshToken: z.string().min(1, 'Refresh token is required'),
    });

    export type Request = z.infer<typeof RequestSchema>;

    export const ResponseSchema = z.object({
        accessToken: z.string(),
        refreshToken: z.string(),
    });

    export type Response = z.infer<typeof ResponseSchema>;
}
