# 構成概要

このドキュメントでは、手作業版 PoC の構成を整理します。

---

## 1. 全体像
本 PoC は、AWS 上に最小限の Web 基盤を構築し、ALB 配下に 2台の EC2 を配置する構成です。

外部公開の入口は Application Load Balancer とし、EC2 インスタンスは ALB 経由の HTTP 通信のみを許可しています。  
また、EC2 の管理アクセスは SSH ではなく、SSM Session Manager を使用しています。

---

## 2. 構成イメージ

```text
Internet
  ↓
Application Load Balancer (manual-poc-alb)
  ↓
Target Group (manual-poc-tg)
  ├─ manual-poc-web1
  └─ manual-poc-web2
```

管理経路は以下の通りです。

```text
Operator
  ↓
SSM Session Manager
  ↓
EC2 instances
```

---

## 3. 手作業版の構成情報

### リージョン
- `ap-northeast-1`

### VPC
- `manual-poc-vpc`
- CIDR: `10.0.0.0/16`

### Subnet
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

この Route Table には以下のルートを設定しています。

- `10.0.0.0/16 -> local`
- `0.0.0.0/0 -> manual-poc-igw`

これにより、2つの Subnet を Public Subnet として成立させています。

---

## 4. セキュリティ設計

### ALB 用 Security Group
- 名前: `manual-poc-alb-sg`
- 用途: 外部から ALB への HTTP アクセスを受ける

主なルール:
- Inbound
  - HTTP 80 / source `0.0.0.0/0`
- Outbound
  - すべて許可

### EC2 用 Security Group
- 名前: `manual-poc-ec2-sg`
- 用途: EC2 への通信を ALB 経由に限定する

主なルール:
- Inbound
  - HTTP 80 / source `manual-poc-alb-sg`
- Outbound
  - すべて許可

これにより、EC2 は Public Subnet 上に存在していても、外部から直接 HTTP アクセスされない構成としています。

---

## 5. EC2 構成

### `manual-poc-web1`
- 配置先: `manual-poc-public-subnet-a`
- 構築方法: SSM で接続し、nginx を手動導入
- index.html の内容: `manual-poc-web1`

### `manual-poc-web2`
- 配置先: `manual-poc-public-subnet-c`
- 構築方法: user data により nginx を自動導入
- index.html の内容: `manual-poc-web2`

---

## 6. 管理アクセス
EC2 への管理アクセスは、IAM Role と SSM Session Manager を使っています。

### IAM Role
- `manual-poc-ec2-role`

### 付与ポリシー
- `AmazonSSMManagedInstanceCore`

### 方針
- SSH は使用しない
- 22番ポートは開放しない
- AWS Systems Manager 経由で接続する

---

## 7. ALB 構成

### Load Balancer
- `manual-poc-alb`
- 種別: Application Load Balancer
- スキーム: internet-facing
- リスナー: HTTP 80

### Target Group
- `manual-poc-tg`
- ターゲットタイプ: Instance
- プロトコル: HTTP
- ポート: 80
- ヘルスチェックパス: `/`

### ターゲット
- `manual-poc-web1`
- `manual-poc-web2`

---

## 8. 動作確認
以下の点を確認済みです。

- web1 は SSM 接続後、nginx を手動導入して `manual-poc-web1` を返す
- web2 は user data 実行により `manual-poc-web2` を返す
- ALB 経由でアクセスし、web1 / web2 の応答を確認
- Target Group のヘルスチェックで 2台が正常に判定されることを確認

---

## 9. 今後の拡張予定
この手作業版 PoC をベースに、次の段階として以下を予定しています。

- Terraform による別 VPC での再現
- CloudWatch Alarm の追加
- セキュリティ設定の見直し
- 再構築手順の整理
- README や構成図の改善
