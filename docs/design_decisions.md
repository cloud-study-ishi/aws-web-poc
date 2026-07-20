# 設計判断メモ

このドキュメントでは、本 PoC における主要な設計判断と、その理由を整理します。

## 1. 手作業で構築した後に Terraform で再現した理由

最初から IaC のみで構築するのではなく、まず AWS マネジメントコンソールから手作業で環境を構築しました。

理由は以下の通りです。

- 各 AWS リソースの役割を、画面操作と関連付けて理解するため
- VPC / Subnet / Route Table / Security Group / ALB / Target Group の関係を整理するため
- Terraform のコードが、AWS 上のどの設定に対応するかを理解するため
- 手作業と IaC の双方を経験し、IaC による再現性と作業差分を比較するため

手作業で構成を確認した後、同等構成を Terraform で再現し、`validate` / `plan` / `apply` / `state list` / `destroy` までを実施しました。

## 2. 手作業版と Terraform 版で VPC を分けた理由

手作業版と Terraform 版は同じ VPC に混在させず、別 VPC に構築しました。

- 手作業版と Terraform 版の検証結果を分けて管理するため
- どのリソースがどの方式で作成されたかを明確にするため
- `terraform apply` / `terraform destroy` が手作業版へ影響しないようにするため
- 「手動理解フェーズ」と「IaC 再現フェーズ」を分けて説明できるようにするため

タグも以下のように分離しました。

- 手作業版: `Project=aws-poc`, `BuildType=manual`
- Terraform 版: `Project=aws-poc`, `BuildType=terraform`

## 3. Private Subnet / NAT Gateway を最初のスコープに含めなかった理由

本 PoC では、基本的な通信経路を理解することを優先し、Private Subnet と NAT Gateway は導入していません。

- ALB から EC2 までの最小 Web 基盤を先に理解するため
- VPC / Public Subnet / Internet Gateway / Route Table / Security Group の関係に学習範囲を絞るため
- 構成要素を増やしすぎず、通信が成立する条件を確認しやすくするため
- NAT Gateway の継続料金を避け、短時間の個人学習 PoC としてコストを抑えるため

実運用を想定する場合は、ALB のみを Public Subnet に配置し、EC2 を Private Subnet に配置する構成を検討します。EC2 の外向き通信には、要件に応じて NAT Gateway や VPC Endpoint などを選択します。

## 4. EC2 を Public Subnet に配置した理由とアクセス制御

学習範囲とコストを抑えるため、EC2 は Public Subnet に配置し、Public IP を付与しました。ただし、EC2 を直接の公開入口とする意図はありません。

EC2 用 Security Group では、以下のように受信を制御しました。

- HTTP（80）の送信元を ALB 用 Security Group に限定
- インターネットから EC2 への直接 HTTP アクセスを許可しない
- SSH（22）を許可しない

```text
Internet -> ALB -> Target Group -> EC2
```

この構成により、外部公開の入口を ALB に集約し、EC2 の HTTP 受信経路を ALB に限定しました。

## 5. SSH ではなく Session Manager を利用した理由

EC2 の管理アクセスには SSH を使わず、AWS Systems Manager Session Manager を採用しました。

- 22 番ポートを開放せずに管理できるため
- SSH 鍵の配布、保管、更新を不要にできるため
- 不要なインバウンドルールを追加しない方針に合うため
- AWS のマネージドな管理経路を利用する経験を得るため

EC2 には IAM Role を付与し、AWS 管理ポリシー `AmazonSSMManagedInstanceCore` を利用しました。

## 6. 手作業版で EC2 の構築方法を分けた理由

手作業版では、EC2 の初期構築を 2 パターンで実施しました。

- `manual-poc-web1`
  - Session Manager で接続し、nginx を手動導入
- `manual-poc-web2`
  - user data を利用し、起動時に nginx を自動導入

目的は以下の通りです。

- EC2 内部で必要となる設定を手動操作で理解するため
- user data による初期設定自動化を確認するため
- 手動手順を Terraform 版でどのように自動化するか比較するため

Terraform 版では、EC2 2 台とも user data による同一方式の初期設定に統一しました。

## 7. Application Load Balancer を採用した理由

外部公開の入口として Application Load Balancer を採用しました。

- EC2 2 台へ HTTP リクエストを分散するため
- Target Group のヘルスチェックでバックエンドの応答状態を確認するため
- EC2 の HTTP 受信元を ALB に限定する構成を確認するため
- 将来的な HTTPS 化やパスベースルーティングなどの拡張につなげやすいため

Listener は HTTP 80 とし、デフォルトアクションで Target Group へ転送しました。

## 8. 監視を今回のスコープ外とした理由

CloudWatch Alarm などの監視は、本 PoC では実装対象外としました。

- まずネットワーク、アクセス制御、EC2、ALB、Terraform の基本に学習範囲を絞るため
- 短時間で作成・削除する検証環境であり、常時監視の必要性が低かったため
- 監視対象、閾値、通知経路まで設計する場合は、別の学習テーマとして扱う方が整理しやすいため

実運用を想定する場合は、ALB の 5xx、Target Response Time、Healthy Host Count、EC2 の CPU 使用率などを候補として、要件に応じた監視を追加します。

## 9. Terraform のファイルを責務ごとに分割した理由

本 PoC は小規模であるため module 化は行わず、ルートモジュール内で責務ごとに `.tf` ファイルを分割しました。

- ネットワーク、Security Group、IAM、EC2、ALB の関係を追いやすくするため
- 小規模な学習コードで過度に抽象化しないため
- 将来 module 化する場合の責務の境界を意識するため

## 10. Terraform State をローカル管理とした理由

個人で短時間実施する単一環境の PoC であるため、Terraform State はローカル管理としました。State ファイルは Git の管理対象外としています。

チーム利用や継続運用を想定する場合は、S3 バックエンド、State Lock、暗号化、アクセス制御などを設計します。

## 11. 検証後にリソースを削除した理由

検証終了後、Terraform 版では `terraform destroy` を実行し、20 リソースが削除されることを確認しました。手作業版を含む検証用リソースも削除済みです。

- 不要な継続課金を防ぐため
- IaC のライフサイクルとして、構築だけでなく削除まで確認するため
- 一時的な検証環境を残さないため

## 12. 今後の改善候補

- EC2 の Private Subnet への移行
- ACM を利用した HTTPS 化
- CloudWatch Metrics / Alarm と通知経路の追加
- Terraform State のリモート管理
- CI による `terraform fmt -check` / `terraform validate` の自動化
- IAM、暗号化、ログ、送信方向の通信制御を含むセキュリティ強化
- 構成の再利用が必要になった場合の module 化
