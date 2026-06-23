import { createTheme } from '@mantine/core'

import { variantColorResolver } from './colors-resolver'
import components from './overrides'

export const theme = createTheme({
    variantColorResolver,
    components,
    cursorType: 'pointer',
    fontFamily:
        'Montserrat, Vazirmatn, Apple Color Emoji, Noto Sans SC, Twemoji Country Flags, sans-serif',
    fontFamilyMonospace: 'Fira Code, monospace',
    breakpoints: {
        xs: '30em',
        sm: '40em',
        md: '48em',
        lg: '64em',
        xl: '80em',
        '2xl': '96em',
        '3xl': '120em',
        '4xl': '160em'
    },

    scale: 1,
    fontSmoothing: true,
    focusRing: 'never',
    white: '#ffffff',
    black: '#090909',
    colors: {
        dark: [
            '#F2F2F2',
            '#E0E0E0',
            '#B0B0B0',
            '#A0A0A0',
            '#808080',
            '#505050',
            '#383838',
            '#252525',
            '#131313',
            '#090909'
        ],
        'aurora-orange': [
            '#FFF0E0',
            '#FFD6B3',
            '#FFB880',
            '#FF9A4D',
            '#FF8F1F',
            '#FF7A00',
            '#CC6200',
            '#994900',
            '#663100',
            '#331800'
        ],
        'shaded-gray': [
            '#f5f5f5',
            '#e8e8e8',
            '#d4d4d4',
            '#c0c0c0',
            '#a8a8a8',
            '#a0a0a0',
            '#808080',
            '#686868',
            '#505050',
            '#383838'
        ]
    },
    primaryShade: 5,
    primaryColor: 'aurora-orange',
    autoContrast: true,
    luminanceThreshold: 0.3,
    headings: {
        fontWeight: '600'
    },
    defaultRadius: 'md'
})
