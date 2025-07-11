# AWS Image Processing Project Checklist

## Infrastructure
- [x] VPC, subnets, and routing
- [x] S3 buckets (frontend, original images, processed images)
- [x] Application Load Balancer (ALB)
- [x] NAT instance
- [ ] Auto Scaling Groups (API, worker nodes)
- [ ] RDS instance and standby
- [ ] SQS queue
- [ ] SNS notifications
- [ ] CloudWatch monitoring/logging
- [ ] VPC endpoints (S3, SQS)
- [ ] Security groups and IAM roles

## Application
- [ ] Web frontend deployed to S3/CloudFront
- [ ] API server
- [ ] Worker service for image processing
- [ ] Database schema for RDS
- [ ] Monitoring/alerting setup

---

Check off items as you complete them!