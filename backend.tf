terraform { 
  cloud { 
    
    organization = "DigitalTech" 

    workspaces { 
      name = "gitaction_aws_asg" 
    } 
  } 
}

#