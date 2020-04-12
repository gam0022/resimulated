module.exports = {
    resolve: {
        extensions: ['.tsx', '.ts', '.js'],
    },
    module: {
        rules: [
            {
                test: /\.glsl$/i,
                use: 'raw-loader',
            },
            {
                test: /\.tsx?$/,
                exclude: /node_modules/,
                use: 'ts-loader',
            },
            {
                test: /\.css$/,
                exclude: /node_modules/,
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