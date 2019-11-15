const path = require('path');

module.exports = {
  // argv.mode === 'production' で切り替えたい
  devtool: 'inline-source-map',
  mode: 'development',
  devServer: {
    inline: true,
    hot: true,
    contentBase: './dist',
  },
  entry: './src/index.js',
  output: {
    filename: 'main.js',
    path: path.resolve(__dirname, 'dist'),
  },
  module: {
    rules: [
      {
        test: /\.glsl$/i,
        use: 'raw-loader',
      },
    ],
  },
};