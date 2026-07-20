# 手作業版 動作確認結果

このドキュメントでは、手作業で構築した AWS Web PoC の主な確認内容と結果を整理します。

Application Load Balancer 配下に EC2 を 2 台配置し、EC2 の HTTP 受信元を ALB 用 Security Group に限定したうえで、ALB 経由で Web 応答できることを確認しました。EC2 の管理アクセスには SSH ではなく AWS Systems Manager Session Manager を利用しました。

## 1. 確認対象

- EC2 に Session Manager で接続できること
- `manual-poc-web1` に nginx を手動導入し、HTTP 応答できること
- `manual-poc-web2` に user data で nginx を自動導入できること
- Target Group に登録した EC2 2 台がヘルスチェックを通過すること
- ALB の DNS 名経由で EC2 2 台の応答を確認できること
- EC2 への SSH およびインターネットからの直接 HTTP アクセスを許可していないこと

## 2. EC2 1 台目（web1）の確認

### 対象インスタンス

- `manual-poc-web1`

### 接続方法

- AWS Systems Manager Session Manager

### 実施内容

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

- Session Manager で接続できることを確認
- `nginx` サービスが起動状態であることを確認
- `curl http://localhost` で `manual-poc-web1` が返ることを確認
- `index.html` に `manual-poc-web1` が設定されていることを確認

## 3. EC2 2 台目（web2）の確認

### 対象インスタンス

- `manual-poc-web2`

### 構築方法

- EC2 起動時の user data による自動構築

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
- `curl http://localhost` で `manual-poc-web2` が返ることを確認
- `index.html` に `manual-poc-web2` が設定されていることを確認
- user data によって、EC2 起動時の初期設定を自動化できることを確認

## 4. Security Group の確認

### ALB 用 Security Group

- `manual-poc-alb-sg`
- HTTP（80）を `0.0.0.0/0` から許可

### EC2 用 Security Group

- `manual-poc-ec2-sg`
- HTTP（80）を `manual-poc-alb-sg` からのみ許可
- インターネットからの直接 HTTP アクセスを許可しない
- SSH（22）を許可しない

### 確認結果

- ALB を外部公開の入口とし、EC2 の HTTP 受信元を ALB に限定できることを確認
- Public Subnet 上の EC2 でも、Security Group により受信経路を制御できることを確認
- 不要な管理用ポートを開放しない構成を確認

## 5. Target Group の確認

### 対象 Target Group

- `manual-poc-tg`

### 登録インスタンス

- `manual-poc-web1`
- `manual-poc-web2`

### 確認内容

- EC2 2 台を Target Group に登録
- Health check path に `/` を設定
- ターゲットの状態を確認

### 確認結果

- EC2 2 台が正常に登録されることを確認
- 2 台ともヘルスチェックを通過することを確認
- ヘルスチェックにより Web サーバーの応答状態を判定できることを確認

## 6. ALB の確認

### 対象 ALB

- `manual-poc-alb`

### 設定内容

- Scheme: `internet-facing`
- Listener: HTTP 80
- Default action: `manual-poc-tg` へ転送

### 確認結果

- ALB が `active` になることを確認
- DNS 名が払い出されることを確認
- Listener から Target Group へ転送されることを確認

## 7. ALB 経由の疎通確認

ALB の DNS 名へブラウザまたは HTTP でアクセスし、応答内容を確認しました。

### 確認結果

- ALB の DNS 名経由でアクセスできることを確認
- `manual-poc-web1` / `manual-poc-web2` の応答を確認
- `Internet -> ALB -> Target Group -> EC2` の通信経路が成立することを確認
- EC2 2 台が ALB 配下のバックエンドとして動作することを確認

## 8. 確認結果まとめ

- VPC / Public Subnet / Internet Gateway / Route Table によるネットワーク構成
- Security Group の参照による ALB から EC2 への通信制御
- IAM Role と Session Manager による SSH 不要の管理アクセス
- nginx の手動導入と user data による自動導入
- Target Group のヘルスチェック
- ALB による外部公開と EC2 2 台へのアクセス

## 9. 後続の Terraform 検証

手作業で確認した構成を、別 VPC 上に Terraform で再現しました。Terraform 版では EC2 2 台の初期設定を user data で統一し、構築から削除までを確認しています。

- [Terraform 版構成概要](terraform_architecture.md)
- [Terraform 版検証結果](terraform_verification.md)

検証用に作成した AWS リソースは削除済みです。
