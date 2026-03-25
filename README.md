# AWS Web PoC

## 概要
このリポジトリは、AWS上に最小構成のWeb基盤を構築し、構成要素の理解と IaC 化の練習を目的として作成した PoC です。

まずは AWS コンソールから手作業で環境を構築し、各サービスの役割や通信経路を理解したうえで、後続で Terraform を用いて同等構成を別 VPC に再現する方針です。

本 PoC では、以下のような観点を確認しています。

- VPC / Subnet / Internet Gateway / Route Table の役割
- Security Group による通信制御
- EC2 を直接公開せず、ALB 経由でのみアクセスさせる構成
- SSH を使わず、SSM Session Manager による管理アクセス
- ALB / Target Group / Listener / Health Check の関係
- 手動構築した内容を Terraform で再現可能な形に整理する流れ

---

## 構成概要
手作業版の PoC では、以下の構成を作成しました。

- VPC × 1
- Public Subnet × 2（2AZ）
- Internet Gateway × 1
- Public Route Table × 1
- Security Group × 2
  - ALB 用
  - EC2 用
- IAM Role（SSM 接続用）× 1
- EC2 × 2
- Target Group × 1
- Application Load Balancer × 1

アクセス経路は以下の通りです。

```text
Internet
  ↓
Application Load Balancer
  ↓
Target Group
  ├─ manual-poc-web1
  └─ manual-poc-web2
```

管理経路は以下の通りです。

```text
利用者端末
  ↓
SSM Session Manager
  ↓
EC2
```

---

## 手作業版の構成情報

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

### 主なリソース
- Internet Gateway: `manual-poc-igw`
- Route Table: `manual-poc-public-rt`
- ALB SG: `manual-poc-alb-sg`
- EC2 SG: `manual-poc-ec2-sg`
- IAM Role: `manual-poc-ec2-role`
- EC2
  - `manual-poc-web1`
  - `manual-poc-web2`
- Target Group: `manual-poc-tg`
- ALB: `manual-poc-alb`

---

## 設計方針
今回の PoC では、理解優先のため、あえて最小構成から着手しています。

- ALB はインターネット公開する
- EC2 は Public Subnet 上に配置する
- ただし、EC2 の Security Group で ALB からの HTTP のみ許可し、外部からの直接アクセスはさせない
- EC2 の管理アクセスは SSH ではなく SSM を利用する
- 手作業版と Terraform 版は VPC とタグを分けて管理する

---

## 動作確認内容
手作業版では、以下を確認済みです。

- VPC / Public Subnet / IGW / Route Table によりインターネット到達可能なネットワークを構成
- ALB 用 Security Group で HTTP(80) を外部公開
- EC2 用 Security Group で、ALB からの HTTP(80) のみ許可
- IAM Role を付与した EC2 に対し、SSM Session Manager で接続可能であることを確認
- `manual-poc-web1` は SSM 経由で nginx を手動導入
- `manual-poc-web2` は user data により nginx を自動導入
- Target Group に 2台の EC2 を登録
- ALB に Listener を設定し、Target Group に転送
- ALB の DNS 名経由でアクセスし、`manual-poc-web1` / `manual-poc-web2` の応答を確認

---

## この PoC で学んだこと
- Subnet が Public になる条件は、IGW のアタッチと Route Table のデフォルトルート設定が必要であること
- Security Group により、Public Subnet 上の EC2 でも ALB 経由のみのアクセス制御が可能であること
- Session Manager を使うことで、SSH ポートを開けずに EC2 を管理できること
- ALB / Target Group / Listener / Health Check はそれぞれ別の役割を持つこと
- 手動構築で理解した内容を、その後 Terraform に落とし込む流れが有効であること

---

## 今後の予定
今後は、手作業版で理解した構成を Terraform で別 VPC に再現し、以下を進める予定です。

- Terraform による再構築
- CloudWatch Alarm 等の監視追加
- セキュリティ設定の見直し
- destroy / 再 apply による再現性確認
- README / 構成図 / 設計理由の整理
- 転職用ポートフォリオとしての説明資料化

---

## 関連ドキュメント
- `docs/manual_build_notes.md`
- `docs/design_decisions.md`
- `docs/architecture.md`
- `docs/verification.md`
