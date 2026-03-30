# Terraform版 検証結果

## 1. 検証目的
手作業で構築した最小 Web 基盤を Terraform により別 VPC 上へ再現できることを確認する。  
あわせて、ALB 配下で 2 台の EC2 へロードバランシングされること、および user data による初期設定自動化を確認する。

## 2. 実施環境
- Region: `ap-northeast-1`
- Terraform 実行ディレクトリ: `C:\Tools\git\AWSPoC\terraform`

## 3. 実行コマンド

```powershell
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
terraform output
terraform state list
```

## 4. 確認観点
1. Terraform により必要な AWS リソースが正常に作成されること
2. ALB の DNS 名でアクセス可能であること
3. アクセスを繰り返すと `tf-poc-web1` と `tf-poc-web2` が切り替わること
4. EC2 2 台が ALB 配下で動作していること
5. EC2 管理アクセスの前提が SSH ではなく SSM であること
6. Terraform により構築済みリソースが state 管理されていること

## 5. 実施結果

### 5.1 init / validate / plan / apply
- `terraform init` 成功
- `terraform validate` 成功
- `terraform plan` 成功
- `terraform apply` 成功

### 5.2 ALB 経由の疎通確認
`terraform output` で取得した ALB DNS 名へブラウザからアクセスし、想定どおり Web 画面が表示されることを確認した。  
また、ブラウザ更新を複数回実施したところ、`tf-poc-web1` と `tf-poc-web2` が切り替わって表示されることを確認した。

これにより、以下を確認できた。

- ALB が正常にリクエストを受け付けている
- Target Group 配下の EC2 2 台へリクエストが振り分けられている
- user data によって各 EC2 の `index.html` が自動設定されている

### 5.3 terraform output 確認
`terraform output` により、以下の値を取得できることを確認した。

- `alb_dns_name`
- `public_subnet_a_id`
- `public_subnet_c_id`
- `target_group_arn`
- `vpc_id`
- `web1_instance_id`
- `web2_instance_id`

これにより、構築後の確認や追加検証に必要な情報を Terraform から取得できることを確認した。

### 5.4 terraform state list 確認
`terraform state list` により、以下の主要リソースが Terraform state 上で管理されていることを確認した。

- VPC
- Public Subnet 2つ
- Internet Gateway
- Route Table
- Route Table Association
- Security Group 2つ
- IAM Role / Instance Profile
- EC2 2台
- ALB
- Target Group
- Listener
- Target Group Attachment

これにより、今回構築した主要リソースが Terraform 管理下にあることを確認した。

## 6. 所要時間
- `terraform apply` 所要時間: 約 3 分

手作業構築と比較して、IaC による再現性と構築速度の有効性を確認できた。

## 7. 検証結果まとめ
今回の Terraform 版では、手作業で理解した最小 Web 基盤を別 VPC 上に再現し、以下を確認できた。

- Terraform により最小 Web 基盤を構築できる
- ALB 経由で 2 台の EC2 へアクセスが分散される
- user data による初期設定自動化が機能する
- Systems Manager を前提とした EC2 管理構成を実装できる
- 構築したリソースを Terraform state で一元管理できる

## 8. 取得した証跡
以下の証跡を取得対象とする。

- `terraform plan` 実行結果
- `terraform apply` 実行結果
- `terraform output` 実行結果
- `terraform state list` 実行結果
- ALB DNS アクセス結果（`tf-poc-web1` 表示）
- ALB DNS アクセス結果（`tf-poc-web2` 表示）
- Target Group healthy 画面
- 必要に応じて Systems Manager 接続画面

## 9. 補足
- ID / ARN / DNS 名は構築のたびに変化するため、ドキュメント上は必要に応じてマスクまたは例示とする
- 今回は理解優先のため、ALB / EC2 ともに Public Subnet に配置した
- より実運用に近づける場合は、Private Subnet / NAT Gateway / CloudWatch 追加を行う
