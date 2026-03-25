# 設計判断メモ

このドキュメントでは、本PoCにおける主要な設計判断と、その理由を整理しています。

---

## 1. 最初は手作業で構築し、その後 Terraform で再現する方針にした理由
今回のPoCでは、最初からIaCで構築するのではなく、まずAWSコンソールから手作業で環境を構築しました。

理由は以下の通りです。

- 各AWSリソースの役割を、画面操作と関連付けながら理解したかった
- VPC / Subnet / Route Table / Security Group / ALB / Target Group の関係を整理したかった
- 後からTerraformを書く際に、「何をコード化しているのか」を理解した状態にしたかった

単にTerraformを書くだけではなく、手作業で構成を確認したうえでIaC化することで、再現性だけでなく理解の深さも示せると考えています。

---

## 2. 手作業版と Terraform 版で VPC を分ける理由
手作業版と Terraform 版は、同じVPCに混在させず、別VPCで構築する方針としました。

理由は以下の通りです。

- 手作業版の検証結果と Terraform 版の結果を分けて管理しやすくするため
- どのリソースがどの方式で作られたかを明確にするため
- destroy / apply などの Terraform 操作時に、手作業版へ影響しないようにするため
- ポートフォリオとして「手動理解フェーズ」と「IaC再現フェーズ」を説明しやすくするため

また、タグも以下のように分離しています。

- 手作業版: `Project=aws-poc`, `BuildType=manual`
- Terraform版: `Project=aws-poc`, `BuildType=terraform`

---

## 3. 最初のPoCで Private Subnet / NAT Gateway を入れなかった理由
今回のPoCでは、あえて最小構成から開始するため、Private Subnet や NAT Gateway は導入していません。

理由は以下の通りです。

- まずは ALB → EC2 の基本的なWeb基盤構成を理解することを優先したかった
- VPC / Public Subnet / IGW / Route Table / Security Group / ALB の最小構成を把握したかった
- 要素を増やしすぎると、何が通信成立の本質か見えにくくなるため
- 学習順序として、まず基本構成、その後にセキュアな拡張構成へ進む方が理解しやすいと判断したため

将来的には、Private Subnet 配置や NAT Gateway 利用、VPC Endpoint の利用なども拡張候補として想定しています。

---

## 4. EC2 を Public Subnet に置きつつ、直接公開しない理由
今回のPoCでは、EC2 インスタンスを Public Subnet 上に配置しています。  
ただし、設計意図としては「EC2 を外部に直接公開する」ことではありません。

EC2 用 Security Group では、以下のように制御しています。

- HTTP(80) の送信元を `manual-poc-alb-sg` に限定
- 外部からの直接HTTPアクセスは不可
- SSH(22) は開放しない

これにより、通信経路は以下に限定されます。

```text
Internet -> ALB -> EC2
