# Terraform版 構成概要

## 1. 目的
手作業で構築した最小限の Web 基盤を、Terraform を用いて別 VPC 上に再現することを目的とする。  
本フェーズでは、IaC による再現性・構築速度・構成の明文化を確認する。

## 2. 構成方針
- 手作業版とは別の VPC を作成する
- タグにより手作業版と Terraform 版を識別する
- ALB 配下に EC2 を 2 台配置する
- EC2 への管理アクセスは SSH ではなく AWS Systems Manager (SSM) を利用する
- まずは理解優先のため、ALB と EC2 は Public Subnet に配置する
- ただし EC2 を直接公開する意図ではなく、HTTP は ALB 経由のみを許可する
- Private Subnet / NAT Gateway / 監視強化は今後の改善対象とする

## 3. 構成情報

### 共通タグ
- `Project=aws-poc`
- `BuildType=terraform`

### VPC
- Name: `tf-poc-vpc`
- CIDR: `10.1.0.0/16`

### Public Subnet
- `tf-poc-public-subnet-a`
  - CIDR: `10.1.1.0/24`
  - AZ: `ap-northeast-1a`
- `tf-poc-public-subnet-c`
  - CIDR: `10.1.2.0/24`
  - AZ: `ap-northeast-1c`

### Internet 接続
- Internet Gateway: `tf-poc-igw`
- Route Table: `tf-poc-public-rt`
- Route:
  - `0.0.0.0/0 -> Internet Gateway`

### Security Group

#### ALB 用
- Name: `tf-poc-alb-sg`
- inbound:
  - HTTP 80 from `0.0.0.0/0`
- outbound:
  - all traffic

#### EC2 用
- Name: `tf-poc-ec2-sg`
- inbound:
  - HTTP 80 from `tf-poc-alb-sg`
- outbound:
  - all traffic

### IAM
- Role: `tf-poc-ec2-role`
- Instance Profile: `tf-poc-ec2-profile`
- Attached Policy:
  - `AmazonSSMManagedInstanceCore`

### EC2
- `tf-poc-web1`
  - Subnet: `tf-poc-public-subnet-a`
  - OS: Amazon Linux 2023
  - Web Server: nginx
- `tf-poc-web2`
  - Subnet: `tf-poc-public-subnet-c`
  - OS: Amazon Linux 2023
  - Web Server: nginx

### Load Balancer
- ALB: `tf-poc-alb`
- Listener:
  - HTTP 80
- Target Group: `tf-poc-tg`
- Health Check:
  - protocol: HTTP
  - path: `/`
  - matcher: `200`

## 4. Terraform ディレクトリ構成

```text
terraform/
├─ versions.tf
├─ provider.tf
├─ variables.tf
├─ locals.tf
├─ vpc.tf
├─ security_groups.tf
├─ iam.tf
├─ ec2.tf
├─ alb.tf
├─ outputs.tf
├─ terraform.tfvars
└─ user_data/
   └─ nginx.sh.tftpl
```

## 5. ファイル分割方針
今回の PoC では、module 化は行わず、ルートモジュール内で責務ごとに tf ファイルを分割した。

- `vpc.tf`: VPC / Subnet / IGW / Route Table
- `security_groups.tf`: ALB / EC2 の通信制御
- `iam.tf`: EC2 が SSM を利用するための IAM
- `ec2.tf`: Web サーバ 2 台
- `alb.tf`: ALB / Target Group / Listener
- `outputs.tf`: 構築後の確認用出力

小規模構成のため、学習しやすさと見通しの良さを優先した。

## 6. user data の方針
Terraform 版では、EC2 2 台とも user data により nginx を自動導入する構成とした。  
これにより、手作業差分を減らし、再構築時にも同一手順を自動で適用できる。

user data では以下を実施する。

- nginx のインストール
- nginx の自動起動設定
- nginx の起動
- `index.html` へのサーバ識別名の書き込み

## 7. 想定するアクセス経路
- 利用者:
  - Internet -> ALB -> Target Group -> EC2
- 管理者:
  - Systems Manager -> EC2

## 8. 今後の改善案
- EC2 を Private Subnet へ移行し、ALB のみを Public Subnet に配置する
- NAT Gateway を導入し、より実運用に近い構成へ発展させる
- CloudWatch Alarm を Terraform 管理下に追加する
- セキュリティおよび監視の粒度を強化する
