# 手作業構築メモ

## 概要
このドキュメントでは、AWS上に最小構成のWeb基盤を手作業で構築した際の実施内容と確認事項を整理しています。

本 PoC では、まず AWS コンソールから構築を行い、各リソースの役割や通信経路を理解したうえで、後続の Terraform 化につなげることを目的としています。

---

## 実施内容

### 1. VPC 作成
- VPC `manual-poc-vpc` を作成
- CIDR は `10.0.0.0/16`

### 2. Public Subnet 作成
- `manual-poc-public-subnet-a`
  - AZ: `ap-northeast-1a`
  - CIDR: `10.0.1.0/24`
- `manual-poc-public-subnet-c`
  - AZ: `ap-northeast-1c`
  - CIDR: `10.0.2.0/24`

### 3. Internet Gateway / Route Table 設定
- Internet Gateway `manual-poc-igw` を作成し、VPC にアタッチ
- Route Table `manual-poc-public-rt` を作成
- `0.0.0.0/0 -> manual-poc-igw` を追加
- 上記 Route Table を 2つの Subnet に関連付け

### 4. Security Group 作成
- `manual-poc-alb-sg`
  - HTTP(80) を `0.0.0.0/0` から許可
- `manual-poc-ec2-sg`
  - HTTP(80) を `manual-poc-alb-sg` からのみ許可

### 5. IAM Role 作成
- `manual-poc-ec2-role` を作成
- `AmazonSSMManagedInstanceCore` を付与
- EC2 に対して SSM Session Manager で接続可能な状態を作成

### 6. EC2 作成
- `manual-poc-web1`
  - Subnet: `manual-poc-public-subnet-a`
  - 構築方法: 手動
- `manual-poc-web2`
  - Subnet: `manual-poc-public-subnet-c`
  - 構築方法: user data による自動構築

### 7. Web サーバー構築
- `manual-poc-web1`
  - SSM で接続
  - nginx を手動導入
  - `index.html` に `manual-poc-web1` を記載
- `manual-poc-web2`
  - user data で nginx をインストール
  - `index.html` に `manual-poc-web2` を出力

### 8. Target Group / ALB 作成
- Target Group `manual-poc-tg` を作成
- `manual-poc-web1` / `manual-poc-web2` を登録
- ALB `manual-poc-alb` を作成
- Listener `HTTP:80` を設定
- デフォルトアクションで `manual-poc-tg` に転送

### 9. 動作確認
- `manual-poc-web1` に SSM 接続できることを確認
- `curl http://localhost` で `manual-poc-web1` を確認
- `manual-poc-web2` でも nginx 応答を確認
- Target Group のヘルスチェックが通ることを確認
- ALB の DNS 名経由でアクセスし、`manual-poc-web1` / `manual-poc-web2` の応答を確認

---

## 確認できたこと
- Subnet を Public にするには、IGW のアタッチと Route Table のデフォルトルート設定が必要であること
- Security Group により、Public Subnet 上の EC2 に対しても ALB 経由のみのアクセス制御が可能であること
- SSM Session Manager により、SSH を開けずに EC2 を管理できること
- ALB / Target Group / Listener / Health Check の役割を分けて理解できること
- 手動構築した内容を、Terraform で再現すべき単位に整理できること

---

## 今後の予定
- Terraform による別 VPC での再現
- CloudWatch Alarm 等の監視追加
- セキュリティ設定の見直し
- 再構築・destroy / apply の確認
- README / 構成図 / 設計理由の整理
