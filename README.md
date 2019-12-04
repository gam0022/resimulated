# Chromatic

デモシーンを目的にしたファイルサイズが極小のWebGLエンジンです。

## 環境構築

### 0: 依存ツールのインストール

- [node.js 6.13.1](https://nodejs.org/ja/) 以上
- ruby

### 1: セットアップ

```sh
# gitからリポジトリをcloneします。
git clone git@github.com:gam0022/webpack-tdf2020.git

cd webpack-tdf2020

# プロジェクトのセットアップをします。
npm install

# 開発をするときのコマンド（Webサーバを起動）
npm run start

# ビルドをするときのコマンド（提出するときにしか使わないので、sadakkey さんはあまり使わないはず）
npm run build
```

## 編集するとき

### サウンド

`src/shaders/sound-*.glsl` を編集してください。

ファイル名は以下から指定できます。
https://github.com/gam0022/webpack-tdf2020/blob/master/src/index.dev.ts#L13
