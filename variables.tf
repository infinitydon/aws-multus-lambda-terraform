variable "instance" {
  description = "Name of the CNF instance that is been deployed like du,cu,core,upf"
  type        = string  
}

variable "multus_security_group_id" {
  description = "The security group ID for the Multus interfaces"
  type        = string
}

variable "multus_subnets" {
  description = "Subnets To Use In Creating Secondary ENIs"
  type        = string
}

variable "source_dest_check_enable" {
  description = "Enable or Disable src-dst checking"
  type        = bool
  default     = true
}

variable "use_ips_from_start_of_subnet" {
  description = "False -> use DHCP allocation (use it when using subnet CIDR reservation), True -> Allocate IPs from begining of the subnet(Lambda does this handling)"
  type        = bool
  default =  true
}

variable "interface_tags" {
  description = "(Optional) Any additional tags to be applied on the multus intf (Key value pair, separated by comma ex: cnf=abc01,type=5g)"
  type        = string
  default = ""
}

variable "autoscaling_group_name" {
  description = "Unique identifier for the Node Group"
  type        = string
}

variable "attach_2nd_eni_lambda_s3_bucket" {
  description = "Specify S3 Bucket(directory) where you locate Lambda function (Attach2ndENI function)"
  type        = string
}

variable "attach_2nd_eni_lambda_s3_key" {
  description = "Specify S3 Key(filename) of your Lambda Function (Attach2ndENI)"
  type        = string
  default = "lambda_function.zip"
}