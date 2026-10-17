import nextCoreWebVitals from "eslint-config-next/core-web-vitals";

const config = [
  { ignores: [".next/**", "node_modules/**", ".agents/**", ".claude/**", ".taste-skill/**"] },
  ...nextCoreWebVitals,
];

export default config;
