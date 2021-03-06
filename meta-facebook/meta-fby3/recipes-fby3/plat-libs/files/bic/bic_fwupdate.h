/*
 *
 * Copyright 2015-present Facebook. All Rights Reserved.
 *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#ifndef __BIC_FWUPDATE_H__
#define __BIC_FWUPDATE_H__

#ifdef __cplusplus
extern "C" {
#endif

#include "bic_xfer.h"
#include "bic.h"

enum {
  UPDATE_BIOS = 0,
  UPDATE_CPLD,
  UPDATE_BIC_BOOTLOADER,
  UPDATE_BIC,
  UPDATE_VR,
  UPDATE_PCIE_SWITCH,
};

int bic_update_fw(uint8_t slot_id, uint8_t comp, uint8_t intf, char *path, uint8_t force);
int bic_show_fw_ver(uint8_t slot_id, uint8_t comp, uint8_t *ver, uint8_t bus, uint8_t addr, uint8_t intf);

#ifdef __cplusplus
} // extern "C"
#endif

#endif /* __BIC_FWUPDATE_H__ */
