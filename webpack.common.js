const path = require('path');
//const { CleanWebpackPlugin } = require('clean-webpack-plugin');
//const HtmlWebpackPlugin = require('html-webpack-plugin');

module.exports = {
  entry: './src/index.js',
  output: {
    filename: 'main.js',
    path: path.resolve(__dirname, 'dist'),
  },
  /*entry: {
    app: './src/index.js',
  },
  output: {
    filename: '[name].bundle.js',
    path: path.resolve(__dirname, 'dist'),
  },*/
  module: {
    rules: [
      {
        test: /\.glsl$/i,
        use: 'raw-loader',
      },
    ],
  },
  /*plugins: [
    new CleanWebpackPlugin(),
    new HtmlWebpackPlugin({
      title: 'Production',
    }),
  ],*/
};