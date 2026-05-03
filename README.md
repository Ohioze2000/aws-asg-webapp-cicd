# GitOps-Native AWS Infrastructure

## 🏗️ Architecture Diagram

```mermaid

%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#0073bb', 'edgeLabelBackground':'#f4f4f4', 'tertiaryColor': '#f4f4f4'}}}%%
graph TD
    %% Define External Nodes
    Internet((🌍 Users on Internet))

    subgraph "1. Source & CI/CD (GitHub)"
        GitRepo[GitHub Repository]
        GHA[GitHub Actions Runner]
    end

    subgraph "2. IaC & State (HCP Terraform)"
        TFCloud[HCP Terraform Workspace]
    end

    %% Define AWS Cloud Boundaries
    subgraph "3. AWS Region: us-east-1"
        Route53[Route 53 DNS]
        ACM[ACM SSL Cert]
        CW[CloudWatch Alarms & Logs]
        
        subgraph "AWS VPC (Elastic & Scalable)"
            
            %% Define Public Subnets
            subgraph "Public Subnet (AZ-A & AZ-B)"
                ALB[Application Load Balancer]
                IGW[Internet Gateway]
            end

            %% Define Private Subnets
            subgraph "Private App Subnet (AZ-A & AZ-B)"
                subgraph "ASG: Auto Scaling Group"
                    EC2_A[EC2 Instance A]
                    EC2_B[EC2 Instance B]
                end
                LT[Launch Template]
                NAT[NAT Gateway]
            end
        end
    end

    %% Define Flows & Relationships
    GitRepo -->|"A. Code Push"| GHA
    GHA -->|"B. terraform apply"| TFCloud
    TFCloud -->|"C. Updates Launch Template"| LT
    LT -->|"D. Triggers Instance Refresh"| ASG
    
    %% External User Flow
    Internet -->|"1. Request"| Route53
    Internet -->|"2. HTTPS Request"| ALB
    ACM -.->|"Cert Validation"| ALB

    %% Traffic Distribution
    ALB -->|"3. Routes to Target Group"| EC2_A
    ALB -->|"3. Routes to Target Group"| EC2_B

    %% Observability & Scaling Loop
    EC2_A -.->|"Metrics/Logs"| CW
    EC2_B -.->|"Metrics/Logs"| CW
    CW -.->|"E. Trigger Scaling Policy"| ASG
    
    %% Notifications
    GHA -.->|Status| Slack((Slack))
    TFCloud -.->|Status| Slack((Slack))
    CW -.->|Alarm Notifications| Slack((Slack))

    %% Styling
    classDef git fill:#f6f8fa,stroke:#d1d5da,stroke-width:2px,color:#24292e;
    classDef aws fill:#FF9900,stroke:#fff,stroke-width:1px,color:#fff;
    classDef aws_blue fill:#0073bb,stroke:#fff,stroke-width:1.5px,color:#fff;
    classDef hashicorp fill:#000,stroke:#844FBA,stroke-width:2px,color:#fff;
    classDef tool fill:#f4f4f4,stroke:#333,stroke-width:1px;

    class GitRepo,GHA git;
    class Route53,ACM,ALB,IGW,NAT,LT aws_blue;
    class EC2_A,EC2_B aws;
    class TFCloud hashicorp;
    class Slack tool;
```

## 📌 Project Overview
This project is a production-grade, two-tier AWS architecture managed through a **CI/CD pipeline**. It demonstrates a modern developer workflow where infrastructure is treated as code, and all deployments are handled automatically via **GitHub Actions**.

## 🔄 The CI/CD Workflow
1. **Develop:** Infrastructure is defined using Terraform (HCL) on a local machine.
2. **Push:** Code is pushed to the GitHub repository.
3. **Automate:** GitHub Actions triggers a workflow that authenticates to AWS using Secret Access Keys.
4. **Deploy:** Terraform Cloud executes the `plan` and `apply`, provisioning the updated resources in AWS.

## 🚀 Technical Stack
- **IaC:** Terraform & Terraform Cloud
- **CI/CD:** GitHub Actions (Self-hosted/GitHub-hosted runners)
- **Cloud:** AWS (VPC, EC2, ASG, ALB, CloudWatch etc.)
- **Security:** Encrypted GitHub Secrets and Terraform Sensitive Variables

## 🏗️ Architecture Overview
- **Networking:** Custom VPC with Public and Private subnets.
- **Compute:** Auto Scaling Group (ASG) ensuring high availability and self-healing.
- **Load Balancing:** Application Load Balancer (ALB) with Security Group Chaining.
- **Observability:** CloudWatch Alarms monitoring health, integrated with **Slack** for real-time notifications.

## 🛠️ Infrastructure Modules
* `/modules/network`: VPC, Subnets, IGW, and NAT Gateways.
* `/modules/iam`: Specialized ECS Task Execution and Task Roles.
* `/modules/alb`: Load Balancer, Listeners, and Target Groups.
* `/modules/webserver`: ASG, Launch Templates, and Instance SGs.
* `/modules/dns`: Route 53 Records.
* `/modules/ssl`: SSL Validation.
* `/modules/monitoring`: SNS Topic, CloudWatch Metric Alarm, SNS Topic Subscription, and CloudWatch Dashboard.

## 🚦 Prerequisites secrets
Before deploying, ensure you have:
1. An **AWS Account** with IAM credentials.
2. An **HCP Terraform** account and workspace. 
3. **GitHub Secrets** configured:
   - `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`
   - `TF_API_TOKEN`
   - `SLACK_WEBHOOK_URL`

## ⚙️ How to Deploy
1. **Clone the Repo:**
   ```bash
   git clone https://github.com/Ohioze2000/aws-asg-webapp-cicd.git

2. Update Variables:
Modify terraform.tfvars or your HCP Terraform workspace variables to match your domain and environment settings.

3. Push to Main:

i.  git add .

ii. git commit -m "push code to repo"

iv. git remote add origin https://github.com/your-username/your-repo-name.git

v.  git branch -M main (if you are not in main)

vi. git push -u origin main

4. Monitor Slack:
The pipeline will notify your Slack channel once the application is live and provide the URL.

🧹 Cleanup
To tear down the infrastructure and avoid costs:

Go to GitHub Actions -> Infrastructure Cleanup.

Run the workflow manually by cliicking Run workflow.

🧠 Lessons Learned
The Project provided deep insights into the nuances of cloud automation and the realities of managing infrastructure-as-code in a CI/CD environment.

1. Solving the "502 Bad Gateway" Mystery
Perhaps the most significant technical hurdle was resolving a 502 error when accessing the site via a custom domain.
I learned that infrastructure is more than just code; it's a handshake. The issue required auditing the Security Group Chaining and verifying the Route 53 Alias record. I discovered that even if the ALB DNS works, a misconfigured host-header or a stale DNS record can break the entire user experience.

2. Remote State is Non-Negotiable
Transitioning from local state files to HCP Terraform (Terraform Cloud) was a turning point. It taught me the importance of state locking and centralized management in a collaborative environment, preventing "state corruption" that often happens during concurrent runs.