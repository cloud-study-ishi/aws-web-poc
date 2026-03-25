# 動作確認メモ

このドキュメントでは、手作業版 AWS PoC における主な確認内容と確認結果を整理しています。

本PoCでは、Application Load Balancer 配下に 2台の EC2 を配置し、EC2 への直接公開を避けつつ、ALB 経由で Web 応答できる構成を確認しました。  
また、EC2 の管理アクセスには SSH ではなく SSM Session Manager を利用しています。

---

## 1. 確認対象

本ドキュメントで確認した主な項目は以下の通りです。

- EC2 に対して SSM Session Manager で接続できること
- web1 に対して nginx を手動導入し、HTTP 応答できること
- web2 に対して user data により nginx を自動導入できること
- Target Group に登録した EC2 2台が正常にヘルスチェックを通過すること
- ALB の DNS 名経由でアクセスし、EC2 2台に到達できること

---

## 2. EC2 1台目（web1）の確認

### 対象インスタンス
- `manual-poc-web1`

### 接続方法
- AWS Systems Manager Session Manager

### 実施内容
SSM で接続し、以下のコマンドを実行して nginx を手動で導入しました。

```bash
sudo dnf install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx
echo "manual-poc-web1" | sudo tee /usr/share/nginx/html/index.html
