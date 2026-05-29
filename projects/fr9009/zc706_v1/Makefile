####################################################################################
## Copyright (c) 2026
## SPDX-License-Identifier: BSD-1-Clause
####################################################################################

PROJECT_NAME := fr9009_zc706_v1_prj

# Keep project dependencies aligned with the folderized source layout.
M_DEPS += system_project.tcl
M_DEPS += system_bd.tcl
M_DEPS += system.tcl
M_DEPS += $(wildcard src/*)
M_DEPS += $(wildcard constraints/*.xdc)

LIB_DEPS += axi_fr9009_config
LIB_DEPS += util_rx_data_capture
LIB_DEPS += util_tx_data_pack

include ../../scripts/project-xilinx.mk
