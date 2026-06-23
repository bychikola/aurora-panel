import { getBorderCharacters, table } from 'table';
import { readPackageJSON } from 'pkg-types';
import gradient from 'gradient-string';
import chalk from 'chalk';

export async function getStartMessage() {
    const pkg = await readPackageJSON();

    const gradientRange = gradient(['#FF7A00', '#FF8F1F']);

    return table(
        [
            [gradientRange('▰▱'.repeat(30))],
            [gradientRange(`⚓ AURORA Backend v${pkg.version}`)],
            [chalk.gray('─'.repeat(60))],
            [
                chalk.cyan('📚 Documentation') +
                    chalk.gray(' ········ ') +
                    chalk.white('https://aurora.rw'),
            ],
            [
                chalk.green('💬 Community') +
                    chalk.gray(' ······ ') +
                    chalk.white('https://t.me/aurora'),
            ],
            [chalk.gray('─'.repeat(60))],
            [
                chalk.yellow('🛠️  Rescue CLI') +
                    chalk.gray(' ······ ') +
                    chalk.dim('docker exec -it aurora aurora'),
            ],
            [gradientRange('▰▱'.repeat(30))],
        ],
        {
            columnDefault: {
                width: 64,
            },
            columns: {
                0: { alignment: 'center' },
            },
            drawVerticalLine: () => false,
            drawHorizontalLine: () => false,
            border: getBorderCharacters('honeywell'),
        },
    );
}
