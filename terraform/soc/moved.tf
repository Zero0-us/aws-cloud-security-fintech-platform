moved {
  from = aws_subnet.tgw_subnet_2a
  to   = aws_subnet.peering_subnet_2a
}

moved {
  from = aws_subnet.tgw_subnet_2c
  to   = aws_subnet.peering_subnet_2c
}

moved {
  from = aws_route_table.tgw_rt
  to   = aws_route_table.peering_rt
}

moved {
  from = aws_route_table_association.tgw_2a_rta
  to   = aws_route_table_association.peering_2a_rta
}

moved {
  from = aws_route_table_association.tgw_2c_rta
  to   = aws_route_table_association.peering_2c_rta
}
