terraform {
  cloud {
    
    organization = "DigitalTech"

    workspaces {
      name = "aws-asg-webapp-prod"
    }
  }
}

#