import type { NextConfig } from "next";

const isProd = process.env.NODE_ENV === "production";

const nextConfig: NextConfig = {
  output: "export",
  // GitHub Pages serves at /lemon-squeezer when deploying from this repo.
  // Local `next dev` and `next start` should NOT use the basePath.
  basePath: isProd ? "/lemon-squeezer" : "",
  assetPrefix: isProd ? "/lemon-squeezer/" : "",
  images: { unoptimized: true },
  trailingSlash: true,
};

export default nextConfig;
