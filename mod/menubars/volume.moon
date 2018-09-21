---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

import execute from os
{ log:mlog, :floor } = math
menubars = require 'menubars'
import run from require 'shell'
import format, find from string
import next, ipairs, pairs from _G
log = require('log').get 'menubars'
{ sigcheck:T } = require 'typecheck'
import allVolumes from require 'hs.fs.volume'
{ new:StyledText } = require 'hs.styledtext'
import partial, partialr, once from require 'fn'
import sort, keys, join, filterk from require 'fn.table'
import launchOrFocusByBundleID from require 'hs.application'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

NO_DATA_MENU = {{
  title: 'No Data'
  disabled: true
}}

PARAGON_NTFS_ITEM =
  title: 'Open Paragon NTFS...'
  fn: partial launchOrFocusByBundleID, 'com.paragon-software.ntfs.fsapp'

DISK_UTILITY_ITEM =
  title: 'Open Disk Utility...'
  fn: partial launchOrFocusByBundleID, 'com.apple.DiskUtility'

menuItem = nil

CAPACITY_UNITS = { 'bytes', 'kb', 'MB', 'GB', 'TB', 'PB' }
makeCapacityDesc = (bytes) ->
  pow = floor mlog(bytes) / mlog(1000)
  return format '%.3f' .. CAPACITY_UNITS[pow + 1], bytes / (1000 ^ pow)

makeUsageDesc = (total, available, showTotal) ->
  used = total - available
  usage = used / total * 100
  capacity = makeCapacityDesc(showTotal and total or used)
  return format '%.1f%%, %s', usage, capacity

diskutil = (op, path) ->
  output = run 'diskutil', op, path
  log.infof 'diskutil %s "%s": "%s"', op, path, output if log.infof

ejectDiskImages = (volumes) ->
  for p, v in pairs volumes
    diskutil 'eject', p if v.NSURLVolumeIsLocalKey and v.NSURLVolumeIsReadOnlyKey

makeVolumeItem = (path, volume, removing) ->
  name = StyledText volume.NSURLVolumeLocalizedNameKey, {
    font: { name: 'HelveticaNeue-Medium', size: 14 }
  }
  usage = makeUsageDesc volume.NSURLVolumeTotalCapacityKey, volume.NSURLVolumeAvailableCapacityKey
  return if volume.NSURLVolumeIsInternalKey then {
    title: format '%s (%s)', name, usage
    fn: partial execute, format('open %q', path)
  } elseif removing then {
    title: format '⏏ %s (%s)', name, usage
    fn: partial diskutil, 'unmount', path
  } else {
    title: format '%s (%s)', name, usage
    fn: (mods) ->
      if mods and mods['alt'] then execute format('open %q', path)
      else diskutil 'unmount', path
  }

makeDetailedVolumeItem = (path, volume, flat) ->
  name = StyledText volume.NSURLVolumeLocalizedNameKey, {
    font: { name: 'HelveticaNeue-Medium', size: 14 }
  }
  total = volume.NSURLVolumeTotalCapacityKey
  available = volume.NSURLVolumeAvailableCapacityKey
  internal = volume.NSURLVolumeIsInternalKey
  ejectable = volume.NSURLVolumeIsEjectableKey

  usage = 'Usage: ' .. makeUsageDesc(total, available, false)
  capacity = 'Capacity: ' .. makeCapacityDesc(total)
  fs = 'File System: ' .. volume.NSURLVolumeLocalizedFormatDescriptionKey

  removal = partial diskutil, (ejectable and 'eject' or 'unmount'), path
  action = (mods) ->
    if mods and mods['alt'] then removal!
    else execute format('open %q', path)

  return if flat then {
    { title: name, fn: action }
    { title: usage, disabled: true, indent: 1 }
    { title: capacity, disabled: true, indent: 1 }
    { title: fs, disabled: true, indent: 1 }
  } else {
    {
      title: name, fn: action, menu: {
        { title: 'Open', fn: partial execute, format('open %q', path) }
        { title: ejectable and 'Eject' or 'Unmount', fn: removal, disabled: internal }
        { title: '-' }
        { title: usage, disabled: true }
        { title: capacity, disabled: true }
        { title: fs, disabled: true }
      }
    }
  }

addVolumeItems = (volumes, menu, maker) ->
  paths = keys volumes
  -- sort by capacity.
  sort paths, (l, r) ->
    volumes[l].NSURLVolumeTotalCapacityKey > volumes[r].NSURLVolumeTotalCapacityKey

  for _, p in ipairs paths
    v = volumes[p]
    item = maker p, v
    if item.title -- is list of items
      menu[#menu + 1] = item
    else
      join menu, item

addUtilityCommands = (volumes, menu) ->
  local hasDiskImages, hasNTFSVolumes
  for _, v in pairs volumes
    if v.NSURLVolumeIsLocalKey and v.NSURLVolumeIsReadOnlyKey
      hasDiskImages = true
    if find v.NSURLVolumeLocalizedFormatDescriptionKey, 'Windows NT Filesystem'
      hasNTFSVolumes = true
    break if hasDiskImages and hasNTFSVolumes

  menu[#menu + 1] = title: '-'
  menu[#menu + 1] = {
    title: 'Eject All Disk Images',
    fn: partial ejectDiskImages, volumes
  } if hasDiskImages
  menu[#menu + 1] = DISK_UTILITY_ITEM
  menu[#menu + 1] = PARAGON_NTFS_ITEM if hasNTFSVolumes

makeMenu = (showInternalVolumes, showUtilityCommands, modifiers) ->
  volumes = allVolumes!
  maker = partialr makeVolumeItem, modifiers and modifiers['alt']
  return NO_DATA_MENU unless next volumes

  externals = {}
  internals = filterk volumes, (p, v) ->
    return true if v.NSURLVolumeIsInternalKey
    externals[p] = v

  menu = {}
  if showInternalVolumes
    addVolumeItems internals, menu, maker
    if next(externals) -- has external volumes
      menu[#menu + 1] = title: '-'
      addVolumeItems externals, menu, maker
  elseif next externals
    addVolumeItems externals, menu, maker
  else
    menu[#menu + 1] = { title: 'No External Volumes', disabled: true }

  addUtilityCommands volumes, menu if showUtilityCommands
  return menu

makeDetailedMenu = (showInternalVolumes, showUtilityCommands, modifiers) ->
  volumes = allVolumes!
  maker = partialr makeDetailedVolumeItem, modifiers and modifiers['alt']
  return NO_DATA_MENU unless next volumes

  externals = {}
  internals = filterk volumes, (p, v) ->
    return true if v.NSURLVolumeIsInternalKey
    externals[p] = v

  menu = {}
  if showInternalVolumes
    menu[#menu + 1] = { title: 'Internal', disabled: true }
    addVolumeItems internals, menu, maker
    if next(externals) -- has external volumes
      menu[#menu + 1] = title: '-'
      menu[#menu + 1] = { title: 'External & Disk Images', disabled: true }
      addVolumeItems externals, menu, maker
  elseif next externals
    addVolumeItems externals, menu, maker
  else
    menu[#menu + 1] = { title: 'No External Volumes', disabled: true }

  addUtilityCommands volumes, menu if showUtilityCommands
  return menu

init = (options) ->
  with options
    icon = .icon or menubars._defaultIcon
    detailed = .showVolumeDetails == true
    showCommands = .showUtilityCommands != false
    showInternals = .showInternalVolumes != false

    menu = partial detailed and makeDetailedMenu or makeMenu, showInternals, showCommands
    menuItem = menubars.new icon, .title, menu

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

{
  init: T 'table', once(init)
}
