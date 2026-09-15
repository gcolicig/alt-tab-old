module.exports = {
    extends: ['@commitlint/config-conventional'],
    rules: {
        // commitlint 21 no longer rejects long headers by default; keep the 72-char limit
        'header-max-length': [2, 'always', 72],
    },
}
