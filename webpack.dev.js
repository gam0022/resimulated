const merge = require('webpack-merge');
const common = require('./webpack.common.js');
const webpack = require('webpack');

module.exports = merge(common, {
  entry: './src/index.dev.ts',
  mode: 'development',
  devtool: 'inline-source-map',
  devServer: {
    inline: true,
    hot: true,
    contentBase: './dist',
  },
  plugins: [
    new webpack.DefinePlugin({
      PRODUCTION: JSON.stringify(false),
    })
  ],
});