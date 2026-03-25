# AWS Web PoC

## 概要
このリポジトリは、AWS上に最小構成のWeb基盤を構築し、構成要素の理解とIaC化の練習を目的として作成したPoCです。

まずはAWSコンソールから手作業で環境を構築し、各サービスの役割や通信経路を理解したうえで、後続でTerraformを用いて同等構成を別VPCに再現する方針です。

本PoCでは、以下のような観点を確認しています。

- VPC / Subnet / Internet Gateway / Route Table の役割
- Security Group による通信制御
- EC2 を直接公開せず、ALB 経由でのみアクセスさせる構成
- SSH を使わず、SSM Session Manager による管理アクセス
- ALB / Target Group / Listener / Health Check の関係
- 手動構築した内容を Terraform で再現可能な形に整理する流れ

---

## 構成概要
手作業版のPoCでは、以下の構成を作成しました。

- VPC × 1
- Public Subnet × 2（2AZ）
- Internet Gateway × 1
- Public Route Table × 1
- Security Group × 2
  - ALB 用
  - EC2 用
- IAM Role（SSM接続用）× 1
- EC2 × 2
- Target Group × 1
- Application Load Balancer × 1

構成のアクセス経路は以下の通りです。

```text
Internet
  ↓
ALB
  ↓
Target Group
  ↓
EC2 (web1 / web2)

利用者端末
  ↓
SSM Session Manager
  ↓
EC2
