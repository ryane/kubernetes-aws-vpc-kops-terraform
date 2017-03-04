data "aws_availability_zone" "az" {
  count = "${length(var.availability_zones)}"
  name  = "${var.availability_zones[count.index]}"
}

resource "aws_subnet" "public" {
  count                   = "${length(var.availability_zones)}"
  vpc_id                  = "${var.vpc_id}"
  cidr_block              = "${cidrsubnet(var.vpc_cidr, var.newbits, var.az_number[data.aws_availability_zone.az.*.name_suffix[count.index]] + var.public_netnum_offset)}"
  availability_zone       = "${var.availability_zones[count.index]}"
  map_public_ip_on_launch = true
  tags                    = "${merge(map("Name", "${var.name}-${var.env}-sn-public-${data.aws_availability_zone.az.*.name_suffix[count.index]}"), var.tags)}"
}

resource "aws_route_table" "public" {
  vpc_id = "${var.vpc_id}"
  tags   = "${merge(map("Name", "${var.name}-${var.env}-rt-public"), var.tags)}"
}

resource "aws_route" "internet_route" {
  route_table_id         = "${aws_route_table.public.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${var.internet_gateway_id}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route_table_association" "public" {
  count          = "${length(var.availability_zones)}"
  subnet_id      = "${aws_subnet.public.*.id[count.index]}"
  route_table_id = "${aws_route_table.public.id}"

  lifecycle {
    ignore_changes        = ["subnet_id", "route_table_id"]
    create_before_destroy = true
  }
}

resource "aws_eip" "nat_eip" {
  count = "${length(var.availability_zones)}"
  vpc   = true
}

resource "aws_nat_gateway" "nat_gw" {
  count         = "${length(var.availability_zones)}"
  allocation_id = "${aws_eip.nat_eip.*.id[count.index]}"
  subnet_id     = "${aws_subnet.public.*.id[count.index]}"

  lifecycle {
    create_before_destroy = true
    ignore_changes        = ["subnet_id"]
  }
}

resource "aws_subnet" "private" {
  count                   = "${length(var.availability_zones)}"
  vpc_id                  = "${var.vpc_id}"
  cidr_block              = "${cidrsubnet(var.vpc_cidr, var.newbits, var.az_number[data.aws_availability_zone.az.*.name_suffix[count.index]] + var.private_netnum_offset)}"
  availability_zone       = "${var.availability_zones[count.index]}"
  map_public_ip_on_launch = false
  tags                    = "${merge(map("Name", "${var.name}-${var.env}-sn-private-${data.aws_availability_zone.az.*.name_suffix[count.index]}"), var.tags)}"
  depends_on              = ["aws_nat_gateway.nat_gw"]
}

resource "aws_route_table" "private" {
  count  = "${length(var.availability_zones)}"
  vpc_id = "${var.vpc_id}"
  tags   = "${merge(map("Name", "${var.name}-${var.env}-rt-private-${data.aws_availability_zone.az.*.name_suffix[count.index]}"), var.tags)}"
}

resource "aws_route" "nat_route" {
  count                  = "${length(var.availability_zones)}"
  route_table_id         = "${aws_route_table.private.*.id[count.index]}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${aws_nat_gateway.nat_gw.*.id[count.index]}"

  lifecycle {
    create_before_destroy = true
    ignore_changes        = ["route_table_id", "nat_gateway_id"]
  }

  depends_on = ["aws_nat_gateway.nat_gw"]
}

resource "aws_route_table_association" "private" {
  count          = "${length(var.availability_zones)}"
  subnet_id      = "${aws_subnet.private.*.id[count.index]}"
  route_table_id = "${aws_route_table.private.*.id[count.index]}"

  lifecycle {
    ignore_changes        = ["subnet_id"]
    create_before_destroy = true
  }
}

resource "aws_security_group" "default" {
  name        = "internal"
  description = "Default security group that allows inbound and outbound traffic from all instances in the VPC"
  vpc_id      = "${var.vpc_id}"
  tags        = "${merge(map("Name", "${var.name}-${var.env}-sg-default"), var.tags)}"
}

resource "aws_security_group_rule" "internal_ingress" {
  type              = "ingress"
  from_port         = "0"
  to_port           = "0"
  protocol          = "-1"
  self              = true
  security_group_id = "${aws_security_group.default.id}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "internal_egress" {
  type              = "egress"
  from_port         = "0"
  to_port           = "0"
  protocol          = "-1"
  self              = true
  security_group_id = "${aws_security_group.default.id}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "nat" {
  name        = "nat"
  description = "security group that allows all inbound and outbound traffic. should only be applied to instances in a private subnet"
  vpc_id      = "${var.vpc_id}"
  tags        = "${merge(map("Name", "${var.name}-${var.env}-sg-nat"), var.tags)}"
  depends_on  = ["aws_nat_gateway.nat_gw"]
}

resource "aws_security_group_rule" "nat_ingress" {
  type              = "ingress"
  from_port         = "0"
  to_port           = "0"
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.nat.id}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "nat_egress" {
  type              = "egress"
  from_port         = "0"
  to_port           = "0"
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.nat.id}"

  lifecycle {
    create_before_destroy = true
  }
}
