const merge = require('webpack-merge');
const common = require('./webpack.common.js');
const webpack = require('webpack');
const path = require('path');

module.exports = merge(common, {
    entry: './src/index.dev.ts',
    mode: 'development',
    output: {
        filename: 'bundle.js',
        path: path.resolve(__dirname, 'dist'),
    },
    devtool: 'inline-source-map',
    devServer: {
        inline: true,
        hot: true,
        contentBase: './dist',
    },
    plugins: [new webpack.DefinePlugin({
        PRODUCTION: JSON.stringify(false),
        GLOBAL_UNIFORMS: JSON.stringify(true),
        // PLAY_SOUND_FILE: JSON.stringify('200319_bgm_sketch.aac'),
        PLAY_SOUND_FILE: JSON.stringify(false),
    })],
});