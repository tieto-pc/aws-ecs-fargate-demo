# NOTE: This is the environment definition that will be used by all environments.
# The actual environments (like dev) just inject their environment dependent values
# to this env-def module which defines the actual environment and creates that environment
# by injecting the environment related values to modules.


# NOTE: In demonstration you might want to follow this procedure since there is some dependency
# for the ECR.
# 1. Comment all other modules except ECR.
# 2. Run terraform init and apply. This creates only the ECR.
# 3. Use script 'tag-and-push-to-ecr.sh' to deploy the application Docker image to ECR.
# 3. Uncomment all modules.
# 4. Run terraform init and apply. This creates other resources and also deploys the ECS using the image in ECR.
# NOTE: In real world development we wouldn't need that procedure, of course, since the ECR registry would be created
# at the beginning of the project and the ECR registry would then persist for the development period for that
# environment.


locals {
  my_name  = "${var.prefix}-${var.env}"
  my_env   = "${var.prefix}-${var.env}"
}


# ECS bucket policy needs aws account id.
data "aws_caller_identity" "current" {}


# You can use Resource groups to find resources. See AWS Console => Resource Groups => Saved.
module "resource-groups" {
  source           = "../resource-groups"
  prefix           = "${var.prefix}"
  env              = "${var.env}"
  region           = "${var.region}"
}

# We could run the demo in default vpc but it is a good idea to isolate
# even small demos to a dedicated vpc.
module "vpc" {
  source                = "../vpc"
  prefix                = "${var.prefix}"
  env                   = "${var.env}"
  region                = "${var.region}"
  vpc_cidr_block        = "${var.vpc_cidr_block}"
  private_subnet_count  = "${var.private_subnet_count}"
  app_port              = "${var.app_port}"
  admin_workstation_ip  = "${var.admin_workstation_ip}"
}

# We store the Docker images of the application in this ECR registry.
module "ecr" {
  source        = "../ecr"
  prefix        = "${var.prefix}"
  env           = "${var.env}"
  region        = "${var.region}"
}

# This is the actual ECS module which creates ECS and application load balancer (ALB)
# to expose the ECS to the internet.
module "ecs" {
  source                       = "../ecs"
  prefix                       = "${var.prefix}"
  env                          = "${var.env}"
  region                       = "${var.region}"
  ecs_service_desired_count    = "${var.ecs_service_desired_count}"
  ecs_private_subnet_az_names  = "${module.vpc.ecs_subnet_availability_zones}"
  ecr_image_url                = "${module.ecr.ecr_url}"
  ecr_crm_image_version        = "${var.ecr_crm_image_version}"
  fargate_container_memory     = "${var.fargate_container_memory}"
  fargate_container_cpu        = "${var.fargate_container_cpu}"
  ecs_private_subnet_ids       = "${module.vpc.ecs_private_subnet_ids}"
  alb_public_subnet_ids        = "${module.vpc.alb_public_subnet_ids}"
  app_port                     = "${var.app_port}"
  vpc_id                       = "${module.vpc.vpc_id}"
  aws_account_id               = "${data.aws_caller_identity.current.account_id}"
  ecs_private_subnet_sg_id     = "${module.vpc.ecs_private_subnet_sg_id}"
  alb-public-subnet-sg_id      = "${module.vpc.alb-public-subnet-sg_id}"
}

# For testing purposes (not needed in actual infra - just testing connections,
# route tables and security group rules).
# Comment in real action - uncomment when debugging connections between subnets.
//module "testing-ec2-instances" {
//  source                       = "../testing-ec2-instances"
//  prefix                       = "${var.prefix}"
//  env                          = "${var.env}"
//  region                       = "${var.region}"
//  ecs_private_subnet_ids       = "${module.vpc.ecs_private_subnet_ids}"
//  alb_public_subnet_ids        = "${module.vpc.alb_public_subnet_ids}"
//  nat-public_subnet_id         = "${module.vpc.nat_public_subnet_id}"
//  ecs_private_subnet_sg_id     = "${module.vpc.ecs_private_subnet_sg_id}"
//  alb-public-subnet-sg_id      = "${module.vpc.alb-public-subnet-sg_id}"
//  nat-public_subnet_sg_id      = "${module.vpc.nat_public_subnet_sg_id}"
//}
