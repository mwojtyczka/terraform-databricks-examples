# Private link documentation:
# https://registry.terraform.io/providers/databricks/databricks/latest/docs/guides/aws-private-link-workspace

resource "aws_subnet" "privatelink" {
  count                   = length(local.spoke_pl_private_subnets_cidr)
  vpc_id                  = aws_vpc.spoke_vpc.id
  cidr_block              = local.spoke_pl_private_subnets_cidr[count.index]
  availability_zone       = element(local.availability_zones, count.index)
  map_public_ip_on_launch = false // explicit private subnet

  tags = merge(var.tags, {
    Name = "${local.prefix}-spoke-pl-vpce-subnet"
  })
}

resource "aws_route_table" "pl_subnet_rt" {
  vpc_id = aws_vpc.spoke_vpc.id
  count  = length(local.spoke_pl_private_subnets_cidr) > 0 ? 1 : 0

  tags = merge(var.tags, {
    Name = "${local.prefix}-pl-spoke-route-tbl"
  })
}

resource "aws_route_table_association" "dataplane_vpce_rtb" {
  count          = length(local.spoke_pl_private_subnets_cidr)
  subnet_id      = aws_subnet.privatelink[count.index].id
  route_table_id = aws_route_table.pl_subnet_rt[count.index].id
}

resource "aws_security_group" "privatelink" {
  count  = length(local.spoke_pl_private_subnets_cidr) > 0 ? 1 : 0
  vpc_id = aws_vpc.spoke_vpc.id

  ingress {
    description     = "Inbound rules"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.default_spoke_sg.id]
  }

  ingress {
    description     = "Inbound rules"
    from_port       = 6666
    to_port         = 6666
    protocol        = "tcp"
    security_groups = [aws_security_group.default_spoke_sg.id]
  }

  egress {
    description     = "Outbound rules"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.default_spoke_sg.id]
  }

  egress {
    description     = "Outbound rules"
    from_port       = 6666
    to_port         = 6666
    protocol        = "tcp"
    security_groups = [aws_security_group.default_spoke_sg.id]
  }

  tags = {
    Name = "${local.prefix}-privatelink-sg"
  }
}

resource "aws_vpc_endpoint" "backend_rest" {
  count               = length(local.spoke_pl_private_subnets_cidr) > 0 ? 1 : 0
  vpc_id              = aws_vpc.spoke_vpc.id
  service_name        = local.vpc_endpoint_backend_rest
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.privatelink[count.index].id]
  subnet_ids          = aws_subnet.privatelink[*].id
  private_dns_enabled = true // try to directly set this to true in the first apply
  depends_on          = [aws_subnet.privatelink]
  tags = {
    Name = "${local.prefix}-databricks-backend-rest"
  }
}

resource "aws_vpc_endpoint" "backend_relay" {
  count               = length(local.spoke_pl_private_subnets_cidr) > 0 ? 1 : 0
  vpc_id              = aws_vpc.spoke_vpc.id
  service_name        = local.vpc_endpoint_backend_relay
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.privatelink[count.index].id]
  subnet_ids          = aws_subnet.privatelink[*].id
  private_dns_enabled = true
  depends_on          = [aws_subnet.privatelink]
  tags = {
    Name = "${local.prefix}-databricks-backend-relay"
  }
}

resource "databricks_mws_vpc_endpoint" "backend_rest_vpce" {
  count               = length(local.spoke_pl_private_subnets_cidr) > 0 ? 1 : 0
  provider            = databricks.mws
  account_id          = var.databricks_account_id
  aws_vpc_endpoint_id = aws_vpc_endpoint.backend_rest[count.index].id
  vpc_endpoint_name   = "${local.prefix}-vpc-spoke-backend"
  region              = var.region
  depends_on          = [aws_vpc_endpoint.backend_rest]
}

resource "databricks_mws_vpc_endpoint" "relay_vpce" {
  count               = length(local.spoke_pl_private_subnets_cidr) > 0 ? 1 : 0
  provider            = databricks.mws
  account_id          = var.databricks_account_id
  aws_vpc_endpoint_id = aws_vpc_endpoint.backend_relay[count.index].id
  vpc_endpoint_name   = "${local.prefix}-vpc-spoke-relay"
  region              = var.region
  depends_on          = [aws_vpc_endpoint.backend_relay]
}

resource "databricks_mws_private_access_settings" "pla" {
  provider                     = databricks.mws
  account_id                   = var.databricks_account_id
  private_access_settings_name = "Private Access Settings for ${local.prefix}"
  region                       = var.region
  public_access_enabled        = true # no private link for the web ui
}