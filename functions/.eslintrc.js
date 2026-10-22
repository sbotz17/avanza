module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    'eslint:recommended',
  ],
  rules: {
    'no-console': 'off',
  },
  parserOptions: {
    ecmaVersion: 2020,
  },
};
