/** @type {import('next').NextConfig} */

// Github Pages向けにBuildする時には環境変数として設定されているので判別に使う
const isDeployGithubPages = process.env.DEPLOY_GITHUB_PAGES != undefined;

const nextConfig = {
  eslint: {
    dirs: ['src'],
  },
  // envに値を設定することでこの後の環境変数にも上書きされるので、そのまま使うことができる
  env: {
    isDeployGithubPages: isDeployGithubPages,
  },
  // Github PagesにDeployするときはbasePathをしっかりと設定しないとちゃんと表示されない
  basePath: isDeployGithubPages ? '/hackathon_portal' : '',

  // 末尾にスラッシュが付いている URL から、末尾にスラッシュが付いていない URL にデフォルトでリダイレクトする設定
  // https://nextjs-ja-translation-docs.vercel.app/docs/api-reference/next.config.js/trailing-slash
  trailingSlash: true,
  reactStrictMode: true,
  swcMinify: true,
  images: {
    unoptimized: true,
  },

  // Uncoment to add domain whitelist
  // images: {
  //   domains: [
  //     'res.cloudinary.com',
  //   ],
  // },

  // SVGR
  webpack(config) {
    config.module.rules.push({
      test: /\.svg$/i,
      issuer: /\.[jt]sx?$/,
      use: [
        {
          loader: '@svgr/webpack',
          options: {
            typescript: true,
            icon: true,
          },
        },
      ],
    });

    return config;
  },
};

module.exports = nextConfig;
