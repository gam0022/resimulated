const merge = require('webpack-merge');
const common = require('./webpack.common.js');
const webpack = require('webpack');

module.exports = merge(common, {
    entry: './src/index.prod.ts',
    mode: 'production',
    plugins: [new webpack.DefinePlugin({
        PRODUCTION: JSON.stringify(true),
        GLOBAL_UNIFORMS: JSON.stringify(true),
        // PLAY_SOUND_FILE: JSON.stringify('200319_bgm_sketch.aac'),
        PLAY_SOUND_FILE: JSON.stringify(false),
    })],
});