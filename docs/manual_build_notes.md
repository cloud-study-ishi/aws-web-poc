# 手作業構築メモ

## 概要

AWS 上に最小構成の Web 基盤を手作業で構築した際の実施内容と確認事項を整理します。

最初に AWS マネジメントコンソールから構築することで、各リソースの役割と通信経路を確認しました。その後、この構成を別 VPC 上に Terraform で再現しました。

## 実施内容

### 1. VPC 作成

- VPC `manual-poc-vpc` を作成
- CIDR: `10.0.0.0/16`

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
- 上記 Route Table を 2 つの Subnet に関連付け

### 4. Security Group 作成

- `manual-poc-alb-sg`
  - HTTP（80）を `0.0.0.0/0` から許可
- `manual-poc-ec2-sg`
  - HTTP（80）を `manual-poc-alb-sg` からのみ許可
  - SSH（22）は許可しない

EC2 は Public Subnet に配置しましたが、HTTP の受信元を ALB 用 Security Group に限定し、インターネットから EC2 への直接 HTTP アクセスを許可しない構成としました。

### 5. IAM Role 作成

- `manual-poc-ec2-role` を作成
- AWS 管理ポリシー `AmazonSSMManagedInstanceCore` を付与
- EC2 に対して Session Manager で接続できる状態を作成

### 6. EC2 作成

- `manual-poc-web1`
  - Subnet: `manual-poc-public-subnet-a`
  - 構築方法: Session Manager 接続後に手動設定
- `manual-poc-web2`
  - Subnet: `manual-poc-public-subnet-c`
  - 構築方法: user data による自動設定

### 7. Web サーバー構築

- `manual-poc-web1`
  - Session Manager で接続
  - nginx を手動導入
  - `index.html` に `manual-poc-web1` を設定
- `manual-poc-web2`
  - user data で nginx をインストール
  - `index.html` に `manual-poc-web2` を設定

### 8. Target Group / ALB 作成

- Target Group `manual-poc-tg` を作成
- `manual-poc-web1` / `manual-poc-web2` を登録
- ALB `manual-poc-alb` を作成
- Listener `HTTP:80` を設定
- デフォルトアクションで `manual-poc-tg` に転送

### 9. 動作確認

- `manual-poc-web1` に Session Manager で接続できることを確認
- `curl http://localhost` で `manual-poc-web1` の応答を確認
- `manual-poc-web2` でも nginx の応答を確認
- Target Group のヘルスチェックが 2 台とも正常になることを確認
- ALB の DNS 名経由でアクセスし、`manual-poc-web1` / `manual-poc-web2` の応答を確認

## 確認できたこと

- Subnet の Route Table に Internet Gateway へのデフォルトルートを設定することで、Public Subnet を構成できること
- インターネットとの通信には、経路設定に加えて Public IP や Security Group などの条件も関係すること
- Security Group の参照により、EC2 の HTTP 受信元を ALB に限定できること
- Session Manager を利用することで、SSH ポートを開放せずに EC2 を管理できること
- ALB / Listener / Target Group / Health Check の役割と関係
- 手作業で理解した構成を Terraform のリソース単位へ整理する流れ

## 後続の実施結果

- 手作業版と別の VPC 上に Terraform 版を構築
- Terraform 版では EC2 2 台の nginx 設定を user data で自動化
- ALB による負荷分散と Target Group の正常性を確認
- `terraform destroy` による Terraform 管理リソースの削除を確認
- 検証用に作成した AWS リソースは削除済み

詳細は以下を参照してください。

- [設計判断メモ](design_decisions.md)
- [Terraform 版構成概要](terraform_architecture.md)
- [Terraform 版検証結果](terraform_verification.md)
