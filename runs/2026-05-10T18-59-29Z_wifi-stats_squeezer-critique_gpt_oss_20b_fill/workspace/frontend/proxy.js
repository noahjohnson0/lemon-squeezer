/*globals process*/
const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();
const port = process.env.PORT || 3001;

app.use(
  createProxyMiddleware('/api', {
    target: 'http://localhost:8000',
    changeOrigin: true,
    pathRewrite: {
      '^/api': '/api', // keep the same path
    },
  })
);

app.listen(port, () => {
  console.log(`Proxy server running at http://localhost:${port}`);
});
