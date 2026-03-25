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
```

### 確認コマンド
```bash
systemctl status nginx
curl http://localhost
cat /usr/share/nginx/html/index.html
```

### 確認結果
- SSM Session Manager による接続が可能であることを確認
- `nginx` サービスが起動状態であることを確認
- `curl http://localhost` の結果として `manual-poc-web1` が返ることを確認
- `index.html` に `manual-poc-web1` が書き込まれていることを確認

### 確認できたこと
- EC2 1台目は、SSM 経由でログインし、手動操作で Web サーバー化できること
- SSH を使用しなくても、EC2 の管理・設定変更が可能であること
- nginx によるローカル HTTP 応答が成立していること

---

## 3. EC2 2台目（web2）の確認

### 対象インスタンス
- `manual-poc-web2`

### 構築方法
- EC2 起動時の user data により自動構築

### 使用した user data
```bash
#!/bin/bash
dnf update -y
dnf install -y nginx
systemctl enable nginx
systemctl start nginx
echo "manual-poc-web2" > /usr/share/nginx/html/index.html
```

### 確認コマンド
```bash
systemctl status nginx
curl http://localhost
cat /usr/share/nginx/html/index.html
```

### 確認結果
- nginx が起動状態であることを確認
- `curl http://localhost` の結果として `manual-poc-web2` が返ることを確認
- `index.html` に `manual-poc-web2` が書き込まれていることを確認

### 確認できたこと
- user data を用いて、EC2 起動時に Web サーバーを自動構築できること
- 手動構築だけでなく、自動初期構築の基本も確認できたこと
- EC2 2台目も、ALB 配下に置く前提の Web サーバーとして機能していること

---

## 4. Security Group 設定の確認

### ALB 用 Security Group
- `manual-poc-alb-sg`

#### 確認内容
- HTTP(80) を `0.0.0.0/0` から許可していること

### EC2 用 Security Group
- `manual-poc-ec2-sg`

#### 確認内容
- HTTP(80) を `manual-poc-alb-sg` からのみ許可していること
- 外部からの直接 HTTP アクセスを許可していないこと
- SSH(22) を開放していないこと

### 確認できたこと
- ALB を公開入口とし、EC2 には ALB 経由のみで到達させる設計になっていること
- Public Subnet 上の EC2 であっても、Security Group によりアクセス経路を制御できること
- 不要な管理用ポートを開けない構成を実現できていること

---

## 5. Target Group の確認

### 対象 Target Group
- `manual-poc-tg`

### 登録インスタンス
- `manual-poc-web1`
- `manual-poc-web2`

### 確認内容
- 2台の EC2 を Target Group に登録
- ヘルスチェックパス `/` を設定
- ターゲットの状態を確認

### 確認結果
- `manual-poc-web1` が正常に登録されていることを確認
- `manual-poc-web2` が正常に登録されていることを確認
- 2台ともヘルスチェックに通過し、正常に疎通できる状態であることを確認

### 確認できたこと
- ALB 配下に置くための転送先として、EC2 2台を正常にグルーピングできたこと
- ヘルスチェックにより、アプリケーション応答状態を判定できること

---

## 6. ALB の確認

### 対象 ALB
- `manual-poc-alb`

### 設定内容
- Scheme: `internet-facing`
- Listener: `HTTP 80`
- Default action: `manual-poc-tg` に転送

### 確認内容
- ALB が作成され、`active` 状態であること
- DNS 名が払い出されていること
- Target Group と紐付いていること

### 確認結果
- ALB が正常に作成されていることを確認
- Listener 80 で Target Group に転送する設定になっていることを確認

### 確認できたこと
- インターネット公開用の入口として ALB を構成できたこと
- ALB / Listener / Target Group の関係を一通り確認できたこと

---

## 7. ALB 経由での疎通確認

### 確認内容
ALB の DNS 名に対してブラウザまたは HTTP アクセスを行い、応答内容を確認しました。

### 確認結果
- ALB の DNS 名経由でアクセス可能であることを確認
- `manual-poc-web1` または `manual-poc-web2` の応答を確認
- 2台の EC2 が ALB 配下のバックエンドとして機能していることを確認

### 確認できたこと
- `Internet -> ALB -> EC2` の通信経路が成立していること
- ALB 配下に複数台の EC2 を配置する最小構成の Web 基盤として機能していること

---

## 8. この段階で確認できた全体像

本PoCにより、以下の構成と動作を確認できました。

- VPC / Public Subnet / Internet Gateway / Route Table によるネットワーク構成
- Security Group による ALB 経由のみのアクセス制御
- IAM Role と Session Manager による SSH 不要の管理アクセス
- EC2 1台の手動構築
- EC2 1台の user data 自動構築
- Target Group への登録
- ALB による外部公開
- ALB 経由での Web 応答確認

---

## 9. 補足メモ

### EC2 1台目の手動構築コマンド
```bash
sudo dnf install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx
echo "manual-poc-web1" | sudo tee /usr/share/nginx/html/index.html
```

### EC2 2台目の user data
```bash
#!/bin/bash
dnf update -y
dnf install -y nginx
systemctl enable nginx
systemctl start nginx
echo "manual-poc-web2" > /usr/share/nginx/html/index.html
```

### 共通の確認コマンド
```bash
systemctl status nginx
curl http://localhost
cat /usr/share/nginx/html/index.html
```

---

## 10. 今後の予定

今後は、この手作業版 PoC で確認した構成をベースに、以下を実施予定です。

- Terraform による別 VPC での再現
- CloudWatch Alarm 等の監視追加
- セキュリティ設定の見直し
- 再構築性の確認
- README / 構成図 / 設計意図の整理
