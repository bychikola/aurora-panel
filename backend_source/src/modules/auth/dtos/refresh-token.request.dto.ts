import { RefreshTokenCommand } from '@libs/contracts/commands';
import { createZodDto } from 'nestjs-zod';

export class RefreshTokenRequestDto extends createZodDto(
    RefreshTokenCommand.RequestSchema,
) {}
