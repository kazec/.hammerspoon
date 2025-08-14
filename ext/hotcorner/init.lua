local USERDATA_TAG = 'hotcorner'
local module = require(USERDATA_TAG .. '.internal')
local hotcornerMT = hs.getObjectMetatable(USERDATA_TAG)

local mainScreen = hs.screen.mainScreen

module.modifierFlags = ls.makeConstantsTable(module.modifierFlags)

local function newAtCorner(corner, size, screen)
   if type(size) == 'userdata' then screen = size size = nil end
   frame = size or { w = 5, h = 5 }
   screen = screen or mainScreen()

   local fullFrame = screen:fullFrame()
   if corner == 1 then
   elseif corner == 2 then
      frame.x = fullFrame.w - frame.w
   elseif corner == 3 then
      frame.y = fullFrame.h - frame.h
   else
      frame.x = fullFrame.w - frame.w
      frame.y = fullFrame.h - frame.h
   end

   return module.new(frame)
end

module.topLeft = function(size, screen)
   return newAtCorner(1, size, screen)
end

module.topRight = function(size, screen)
   return newAtCorner(2, size, screen)
end

module.bottomLeft = function(size, screen)
   return newAtCorner(3, size, screen)
end

module.bottomRight = function(size, screen)
   return newAtCorner(4, size, screen)
end

local function convertModifiers(modifiers)
   if not modifiers then return end

   if type(modifiers) == 'table' then

      local flag = 0
      for _, mod in ipairs(modifiers) do
         flag = flag | module.modifierFlags[mod]
      end
      return flag
   elseif type(modifiers) == 'string' then
      local flag = module.modifierFlags[modifiers]
      if not flag then
         flag = 0
         for mod in modifiers:gmatch('[^%+]+') do
            local mask = module.modifierFlags[mod]
            if not mask then
               error('invalid modifiers: ' .. modifiers, 2)
            end
            flag = flag | mask
         end
         if flag == 0 then
            error('invalid modifiers: ' .. modifiers, 2)
         end
      end
      return flag
   elseif type(modifiers) == 'number' then
      return modifiers
   end

   error('"modifiers" must be a table, a string or a number.', 2)
end

local function makeMouseClickCallback(leftClick, doubleClick)
   if leftClick and doubleClick then
      return function(obj, location, clickCount, modifierFlags)
         if clickCount == 1 then
            for i = 1, #leftClick, 2 do
               local modifiers = leftClick[i]
               if modifiers == true or modifiers == modifierFlags then
                  leftClick[i + 1](obj, location)
                  return
               end
            end
         elseif clickCount == 2 then
            for i = 1, #doubleClick, 2 do
               local modifiers = doubleClick[i]
               if modifiers == true or modifiers == modifierFlags then
                  doubleClick[i + 1](obj, location)
                  return
               end
            end
         end
      end
   end

   return function(obj, location, clickCount, modifierFlags)
      if clickCount ~= 2 then return end

      for i = 1, #doubleClick, 2 do
         local modifiers = doubleClick[i]
         if modifiers == true or modifiers == modifierFlags then
            doubleClick[i + 1](obj, location)
            return
         end
      end
   end
end

local function makeMouseUpCallback(leftClick, rightClick)
   if leftClick and rightClick then
      return function(obj, location, clickCount, modifierFlags, leftMouse)
         if leftMouse then
            for i = 1, #leftClick, 2 do
               local modifiers = leftClick[i]
               if modifiers == true or modifiers == modifierFlags then
                  leftClick[i + 1](obj, location)
                  return
               end
            end
         else
            for i = 1, #rightClick, 2 do
               local modifiers = rightClick[i]
               if modifiers == true or modifiers == modifierFlags then
                  rightClick[i + 1](obj, location)
                  return
               end
            end
         end
      end
   end

   local mouse = leftClick ~= nil
   local click = leftClick or rightClick
   return function(obj, location, clickCount, modifierFlags, leftMouse)
      if leftMouse ~= mouse then return end
      for i = 1, #click, 2 do
         local modifiers = click[i]
         if modifiers == true or modifiers == modifierFlags then
            click[i + 1](obj, location)
            return
         end
      end
   end
end

local function makeMouseHoverCallback(mouseHover)
   local previousFlags, idx = 0, 1
   return function(obj, location, delay, modifierFlags)
      if modifierFlags < previousFlags then
         previousFlags = modifierFlags
         return
      end
      previousFlags = modifierFlags

      if delay == 0 then
         local i = 1
         local flag = mouseHover[1]
         repeat
            if (flag & 1 == 1) or (flag & ~7 == modifierFlags) then
               local type = flag & 6
               if type == 0 then -- plain function(0)
                  mouseHover[i + 1](obj, location)
                  i = i + 2
                  -- continue
               elseif type == 2 then -- sequences(2)
                  idx = 1
                  local sequences = mouseHover[i + 1]
                  local firstDelay = sequences[1]

                  if firstDelay > 0 then
                     sequences[0] = 2
                     return firstDelay
                  else
                     sequences[2](obj, location, 0)
                     sequences[0] = 4
                     return sequences[3]
                  end
               else -- interval(4) and delay(6)
                  idx = i
                  return mouseHover[i + 1]
               end
            else
               i = i + (flag & 4 == 4 and 3 or 2) -- 4 set the interval or delay
            end
            flag = mouseHover[i]
         until not flag
         return 0
      end

      local type = mouseHover[idx] & 6
      if type == 2 then -- sequences(2)
         local sequences = mouseHover[idx + 1]
         local i = sequences[0]
         sequences[i](obj, location, delay)

         local nextDelay = sequences[i + 1]
         if nextDelay then
            sequences[0] = i + 2
            return nextDelay
         end
         -- end of sequences
         return 0
      elseif type == 4 then -- interval(4)
         mouseHover[idx + 2](obj, location, delay)
         return delay + mouseHover[idx + 1]
      else -- delay(6)
         mouseHover[idx + 2](obj, location, delay)
         return 0
      end
   end
end

local function makeScrollWheelCallback(scrollWheel)
   return function(obj, deltaX, deltaY, phase, momentumPhase, modifierFlags)
      for i = 1, #scrollWheel, 2 do
         local modifiers = scrollWheel[i]
         if modifiers == true or modifiers == modifierFlags then
            scrollWheel[i + 1](obj, deltaX, deltaY, phase, momentumPhase)
            return
         end
      end
   end
end

local function bindLeftClickAction(callbacks, modifiers, fn)
   local leftClick = callbacks['left-click']

   if leftClick then
      leftClick[#leftClick + 1] = modifiers or true
      leftClick[#leftClick + 1] = fn
   else -- first time add
      leftClick = { modifiers or true, fn }
      callbacks['left-click'] = leftClick

      local doubleClick = callbacks['double-click']
      if doubleClick then
         callbacks.mouseClick = makeMouseClickCallback(leftClick, doubleClick)
         callbacks.mouseClickDirty = true
      else
         local rightClick = callbacks['right-click']
         callbacks.mouseUp = makeMouseUpCallback(leftClick, rightClick)
         callbacks.mouseUpDirty = true
      end
   end
end

local function bindRightClickAction(callbacks, modifiers, fn)
   local rightClick = callbacks['right-click']

   if rightClick then
      rightClick[#rightClick + 1] = modifiers or true
      rightClick[#rightClick + 1] = fn
      return
   else -- first time add
      rightClick = { modifiers or true, fn }
      callbacks['right-click'] = rightClick

      local leftClick = callbacks['left-click']
      if leftClick and callbacks['double-click'] then
         leftClick = nil
      end

      callbacks.mouseUp = makeMouseUpCallback(leftClick, rightClick)
      callbacks.mouseUpDirty = true
   end
end

local function bindDoubleClickAction(callbacks, modifiers, fn)
   local doubleClick = callbacks['double-click']

   if doubleClick then
      doubleClick[#doubleClick + 1] = modifiers or true
      doubleClick[#doubleClick + 1] = fn
      return
   else -- first time add
      doubleClick = { modifiers or true, fn }
      callbacks['double-click'] = doubleClick

      local leftClick = callbacks['left-click']
      if leftClick then
         local rightClick = callbacks['right-click']
         if rightClick then
            callbacks.mouseUp = makeMouseUpCallback(nil, rightClick)
            callbacks.mouseUpDirty = true
         end
      end

      callbacks.mouseClick = makeMouseClickCallback(leftClick, doubleClick)
      callbacks.mouseClickDirty = true
   end
end

local function bindHoverAction(callbacks, modifiers, fn)
   local hoverAction = callbacks['mouse-hover']

   modifiers = (modifiers or 1)
   if hoverAction then
      hoverAction[#hoverAction + 1] = modifiers
      hoverAction[#hoverAction + 1] = fn
      return
   end

   hoverAction = { modifiers, fn }
   callbacks['mouse-hover'] = hoverAction
   callbacks.mouseHover = makeMouseHoverCallback(hoverAction)
   callbacks.mouseHoverDirty = true
end

local function bindHoverSequencesAction(callbacks, modifiers, sequences)
   local hoverAction = callbacks['mouse-hover']

   modifiers = (modifiers or 1) | 2
   flattened = {}
   for i, seq in ipairs(sequences) do
      flattened[2 * i - 1] = seq.delay
      flattened[2 * i] = seq.fn
   end
   if hoverAction then
      hoverAction[#hoverAction + 1] = modifiers
      hoverAction[#hoverAction + 1] = flattened
      return
   end

   hoverAction = { modifiers, flattened }
   callbacks['mouse-hover'] = hoverAction
   callbacks.mouseHover = makeMouseHoverCallback(hoverAction)
   callbacks.mouseHoverDirty = true
end

local function bindHoverIntervalAction(callbacks, modifiers, interval, fn)
   local hoverAction = callbacks['mouse-hover']

   modifiers = (modifiers or 1) | 4
   if hoverAction then
      hoverAction[#hoverAction + 1] = modifiers
      hoverAction[#hoverAction + 1] = interval
      hoverAction[#hoverAction + 1] = fn
      return
   end

   hoverAction = { modifiers, interval, fn }
   callbacks['mouse-hover'] = hoverAction
   callbacks.mouseHover = makeMouseHoverCallback(hoverAction)
   callbacks.mouseHoverDirty = true
end

local function bindHoverDelayAction(callbacks, modifiers, delay, fn)
   local hoverAction = callbacks['mouse-hover']

   modifiers = (modifiers or 1) | 6
   if hoverAction then
      hoverAction[#hoverAction + 1] = modifiers
      hoverAction[#hoverAction + 1] = delay
      hoverAction[#hoverAction + 1] = fn
      return
   end

   hoverAction = { modifiers, delay, fn }
   callbacks['mouse-hover'] = hoverAction
   callbacks.mouseHover = makeMouseHoverCallback(hoverAction)
   callbacks.mouseHoverDirty = true
end

local function bindScrollWheelAction(callbacks, modifiers, fn)
   local scrollWheel = callbacks['scroll-wheel']

   if scrollWheel then
      scrollWheel[#scrollWheel + 1] = modifiers or true
      scrollWheel[#scrollWheel + 1] = fn
      return
   else -- first time add
      scrollWheel = { modifiers or true, fn }
      callbacks['scroll-wheel'] = scrollWheel

      callbacks.scrollWheel = makeScrollWheelCallback(scrollWheel)
      callbacks.scrollWheelDirty = true
   end
end

local function updateCallbacks(object, callbacks)
   local updateWithKey = function(key)
      local originalKey = '_' .. key -- eg: _mouseUp
      local setterKey = key .. 'Callback' -- eg: mouseUpCallback

      local callback = callbacks[key]
      local original = callbacks[originalKey]

      if original == nil then -- first time add
         original = hotcornerMT[setterKey](object)
         if original then
            callbacks[originalKey] = original -- add with original callback
            hotcornerMT[setterKey](object, function(...)
               original(...)
               callback(...)
            end)
         else
            callbacks[originalKey] = false -- add without original callback
            hotcornerMT[setterKey](object, callback)
         end
      elseif original == false then -- added before without original callback
         hotcornerMT[setterKey](object, callback) -- update
      else -- added before with original callback
         hotcornerMT[setterKey](object, function(...)
            original(...)
            callback(...)
         end)
      end
   end

   for _, key in ipairs({'mouseUp', 'mouseClick', 'mouseHover', 'scrollWheel'}) do
      local dirtyKey = key .. 'Dirty'
      if callbacks[dirtyKey] then
         updateWithKey(key)
         callbacks[dirtyKey] = nil
      end
   end
end

hotcornerMT.bind = function(self, modifiers, event, action)
   modifiers = convertModifiers(modifiers)

   callbacks = debug.getuservalue(self)
   if not callbacks then
      callbacks = {}
      debug.setuservalue(self, callbacks)
   end

   if event == 'mouse-hover' then
      if type(action) == 'table' then
         if action.delay then
            bindHoverDelayAction(callbacks, modifiers, action.delay, action.fn)
         elseif action.interval then
            bindHoverIntervalAction(callbacks, modifiers, action.interval, action.fn)
         else
            if #action < 2 then
               error('a "mouse-hover" actions with sequences must have 2 or more items.')
            end
            bindHoverSequencesAction(callbacks, modifiers, action)
         end
      elseif type(action) == 'function' then
         bindHoverAction(callbacks, modifiers, action)
      else
         error('a "mouse-hover" action must be a table or a function.')
      end
   else
      if type(action) ~= 'function' then
         error(string.format('a "%s" action must be a function', event))
      end
      if event == 'left-click' then
         bindLeftClickAction(callbacks, modifiers, action)
      elseif event == 'double-click' then
         bindDoubleClickAction(callbacks, modifiers, action)
      elseif event == 'right-click' then
         bindRightClickAction(callbacks, modifiers, action)
      elseif event == 'scroll-wheel' then
         bindScrollWheelAction(callbacks, modifiers, action)
      else
         error('Unrecognized event: ' .. tostring(event))
      end
   end

   updateCallbacks(self, callbacks)
   return self
end

return module
