
# 構成概要

このドキュメントでは、手作業版PoCの構成を整理します。

---

## 1. 全体像
本PoCは、AWS上に最小限のWeb基盤を構築し、ALB 配下に 2台の EC2 を配置する構成です。

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
