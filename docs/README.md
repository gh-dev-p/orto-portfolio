# ドキュメント一覧

**複数アカウント切替メッセージアプリ（Orto）**

- 各ドキュメントには変更履歴を書かない。変更の記録は git のコミットに残す
- サーバ側の実装（`firebase/`）と、運用のための文書は、このコピーには含まない

---

## 仕様書・設計書

| ドキュメント | 格納先 | 内容 |
|---|---|---|
| 要件定義書 | [requirements/requirements.md](requirements/requirements.md) | 目的・背景、機能要件・非機能要件 |
| 機能仕様書 | [specs/functional-spec.md](specs/functional-spec.md) | 各機能の挙動（処理フロー・異常系） |
| データ設計書 | [design/data/data-design.md](design/data/data-design.md) | Firestoreのコレクション構造・フィールド定義・セキュリティルールの方針・Storage |
| 画面設計書 | [design/screens/screen-design.md](design/screens/screen-design.md) | 画面一覧・画面遷移・構成要素・入力項目・異常系表示 |
| アーキテクチャ・フォルダ構成定義書 | [design/architecture/architecture-design.md](design/architecture/architecture-design.md) | MVVM＋Riverpodのアーキテクチャとフォルダ構成 |
| 多言語対応（i18n）設計書 | [design/architecture/i18n-design.md](design/architecture/i18n-design.md) | 日本語・英語の切り替えの仕組みと文言の管理 |
| README | [README.md](../README.md)（リポジトリ直下） | アプリの概要・技術スタック・構成 |
