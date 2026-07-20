# 手作業版 構成概要

このドキュメントでは、手作業で構築した AWS Web PoC の構成を整理します。

## 1. 全体像

Application Load Balancer（ALB）配下に、2 つの Availability Zone に分けて EC2 を 2 台配置しました。

ALB をインターネット公開の入口とし、EC2 の HTTP 受信元は ALB 用 Security Group に限定しています。EC2 は Public Subnet 上に配置しましたが、インターネットから EC2 への直接 HTTP アクセスは許可していません。

EC2 の管理アクセスには SSH ではなく、AWS Systems Manager Session Manager を利用しました。

## 2. 構成イメージ

```text
Internet
  ↓ HTTP 80
Application Load Balancer (manual-poc-alb)
  ↓
Target Group (manual-poc-tg)
  ├─ manual-poc-web1 (ap-northeast-1a)
  └─ manual-poc-web2 (ap-northeast-1c)
```

管理経路は以下の通りです。

```text
Operator
  ↓
AWS Systems Manager Session Manager
  ↓
EC2 instances
```

## 3. ネットワーク構成

### リージョン

- `ap-northeast-1`

### VPC

- Name: `manual-poc-vpc`
- CIDR: `10.0.0.0/16`

### Public Subnet

- `manual-poc-public-subnet-a`
  - AZ: `ap-northeast-1a`
  - CIDR: `10.0.1.0/24`
- `manual-poc-public-subnet-c`
  - AZ: `ap-northeast-1c`
  - CIDR: `10.0.2.0/24`

### Internet Gateway

- `manual-poc-igw`

### Route Table

- `manual-poc-public-rt`

主なルート:

- `10.0.0.0/16 -> local`
- `0.0.0.0/0 -> manual-poc-igw`

2 つの Subnet をこの Route Table に関連付け、Internet Gateway への経路を持つ Public Subnet としました。

## 4. セキュリティ設計

### ALB 用 Security Group

- Name: `manual-poc-alb-sg`
- Inbound:
  - HTTP 80 / source `0.0.0.0/0`
- Outbound:
  - すべて許可

### EC2 用 Security Group

- Name: `manual-poc-ec2-sg`
- Inbound:
  - HTTP 80 / source `manual-poc-alb-sg`
- Outbound:
  - すべて許可

EC2 用 Security Group の受信元には CIDR ではなく ALB 用 Security Group を指定し、ALB を経由した HTTP 通信のみを許可しました。SSH（22 番ポート）は開放していません。

## 5. EC2 構成

### `manual-poc-web1`

- 配置先: `manual-poc-public-subnet-a`
- 構築方法: Session Manager で接続し、nginx を手動導入
- `index.html`: `manual-poc-web1`

### `manual-poc-web2`

- 配置先: `manual-poc-public-subnet-c`
- 構築方法: user data により nginx を自動導入
- `index.html`: `manual-poc-web2`

## 6. 管理アクセス

### IAM Role

- `manual-poc-ec2-role`

### 付与ポリシー

- `AmazonSSMManagedInstanceCore`

### 方針

- SSH は使用しない
- 22 番ポートは開放しない
- Session Manager を管理経路として利用する

## 7. ALB 構成

### Load Balancer

- Name: `manual-poc-alb`
- Type: Application Load Balancer
- Scheme: `internet-facing`
- Listener: HTTP 80

### Target Group

- Name: `manual-poc-tg`
- Target type: Instance
- Protocol: HTTP
- Port: 80
- Health check path: `/`

### Targets

- `manual-poc-web1`
- `manual-poc-web2`

## 8. 動作確認

以下を確認しました。

- `manual-poc-web1` に Session Manager で接続し、nginx を手動導入できること
- `manual-poc-web2` で user data による nginx の自動導入が成功すること
- Target Group のヘルスチェックで EC2 2 台が正常になること
- ALB の DNS 名経由で EC2 2 台の応答を確認できること

## 9. 後続フェーズ

この手作業版を基に、同等構成を別 VPC 上に Terraform で再現しました。

- [Terraform 版構成概要](terraform_architecture.md)
- [Terraform 版検証結果](terraform_verification.md)

検証用に作成した AWS リソースは削除済みです。

## 10. 今後の改善候補

- EC2 を Private Subnet に配置する
- ALB を HTTPS 化し、ACM 証明書を利用する
- CloudWatch Metrics / Alarm による監視を追加する
- 送信方向を含めて Security Group の許可範囲を見直す
