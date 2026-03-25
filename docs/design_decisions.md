# 設計判断メモ

このドキュメントでは、本 PoC における主要な設計判断と、その理由を整理しています。

---

## 1. 最初は手作業で構築し、その後 Terraform で再現する方針にした理由
今回の PoC では、最初から IaC で構築するのではなく、まず AWS コンソールから手作業で環境を構築しました。

理由は以下の通りです。

- 各 AWS リソースの役割を、画面操作と関連付けながら理解したかった
- VPC / Subnet / Route Table / Security Group / ALB / Target Group の関係を整理したかった
- 後から Terraform を書く際に、「何をコード化しているのか」を理解した状態にしたかった

単に Terraform を書くだけではなく、手作業で構成を確認したうえで IaC 化することで、再現性だけでなく理解の深さも示せると考えています。

---

## 2. 手作業版と Terraform 版で VPC を分ける理由
手作業版と Terraform 版は、同じ VPC に混在させず、別 VPC で構築する方針としました。

理由は以下の通りです。

- 手作業版の検証結果と Terraform 版の結果を分けて管理しやすくするため
- どのリソースがどの方式で作られたかを明確にするため
- destroy / apply などの Terraform 操作時に、手作業版へ影響しないようにするため
- ポートフォリオとして「手動理解フェーズ」と「IaC 再現フェーズ」を説明しやすくするため

また、タグも以下のように分離しています。

- 手作業版: `Project=aws-poc`, `BuildType=manual`
- Terraform 版: `Project=aws-poc`, `BuildType=terraform`

---

## 3. 最初の PoC で Private Subnet / NAT Gateway を入れなかった理由
今回の PoC では、あえて最小構成から開始するため、Private Subnet や NAT Gateway は導入していません。

理由は以下の通りです。

- まずは ALB → EC2 の基本的な Web 基盤構成を理解することを優先したかった
- VPC / Public Subnet / IGW / Route Table / Security Group / ALB の最小構成を把握したかった
- 要素を増やしすぎると、何が通信成立の本質か見えにくくなるため
- 学習順序として、まず基本構成、その後にセキュアな拡張構成へ進む方が理解しやすいと判断したため

将来的には、Private Subnet 配置や NAT Gateway 利用、VPC Endpoint の利用なども拡張候補として想定しています。

---

## 4. EC2 を Public Subnet に置きつつ、直接公開しない理由
今回の PoC では、EC2 インスタンスを Public Subnet 上に配置しています。  
ただし、設計意図としては「EC2 を外部に直接公開する」ことではありません。

EC2 用 Security Group では、以下のように制御しています。

- HTTP(80) の送信元を `manual-poc-alb-sg` に限定
- 外部からの直接 HTTP アクセスは不可
- SSH(22) は開放しない

これにより、通信経路は以下に限定されます。

```text
Internet -> ALB -> EC2
```

つまり、Public Subnet を使っていても、Security Group により ALB 経由のみのアクセスに絞る構成としています。

---

## 5. SSH ではなく SSM Session Manager を使う理由
本 PoC では、EC2 の管理アクセスに SSH を使わず、AWS Systems Manager Session Manager を採用しています。

理由は以下の通りです。

- 22番ポートを開けずに管理できるため
- SSH 鍵の配布・保管・管理が不要になるため
- 「不要なインバウンドを開けない」という方針に合っているため
- AWS のマネージドな管理経路を利用する実践経験として有効なため

この構成では、EC2 に IAM Role `manual-poc-ec2-role` を付与し、`AmazonSSMManagedInstanceCore` を利用しています。

---

## 6. web1 は手動構築、web2 は user data 自動構築に分けた理由
PoC の中で、EC2 の初期構築方法を 2 パターン試しています。

- `manual-poc-web1`
  - SSM で接続し、nginx を手動導入
- `manual-poc-web2`
  - user data を用いて起動時に nginx を自動導入

このように分けた理由は以下の通りです。

- 手動作業で「EC2 の中で何をしているか」を理解したかった
- user data による自動化の初歩も同時に確認したかった
- 後で Terraform に進む際に、「手動でやったことをどう自動化するか」を説明しやすくするため

---

## 7. ALB をインターネット向けにし、Target Group 経由で転送する理由
今回の PoC では、外部公開の入口として Application Load Balancer を採用しています。

理由は以下の通りです。

- 複数の EC2 に対してリクエストを分散できるため
- ヘルスチェックにより、疎通性を監視できるため
- EC2 を直接公開せず、ALB を入口とする一般的な Web 構成を確認できるため
- 今後 HTTPS 化やルール追加などの拡張にもつなげやすいため

ALB の Listener は HTTP:80 とし、デフォルトアクションで `manual-poc-tg` に転送しています。

---

## 8. 監視は Terraform フェーズでまとめて実施する理由
CloudWatch Alarm などの監視設定は、手作業フェーズでは後回しにし、Terraform フェーズでまとめて実装する方針としています。

理由は以下の通りです。

- まずは本体リソースの構築と疎通確認を優先したいため
- 監視は ALB / EC2 / Target Group などの各リソースと密接に関連するため、コード管理した方が整理しやすいため
- Terraform 化後にまとめて定義することで、再現性のある監視設定として残せるため

---

## 9. この PoC で重視したこと
本 PoC では、以下を特に重視しています。

- 最小構成で本質を理解すること
- 不要な公開を避けること
- 手動理解から IaC 化へつなげること
- 後で説明できる構成にすること
- 単なる動作確認ではなく、設計意図まで残すこと

---

## 10. 今後の改善候補
今後は以下のような改善を検討しています。

- Terraform による再現
- CloudWatch Alarm の追加
- README や構成図の拡充
- destroy / 再 apply による再現性確認
- Private Subnet 構成への拡張
- NAT Gateway / VPC Endpoint の導入検討
- HTTPS / ACM 証明書の導入
- 監視項目やアラート条件の整理
