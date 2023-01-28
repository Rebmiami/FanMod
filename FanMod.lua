function FanElements()


-- Check if the current snapshot supports tmp3/tmp4
-- Otherwise, use pavg0/1
local tmp3 = "pavg0"
local tmp4 = "pavg1"
if sim.FIELD_TMP3 then -- Returns nil if tmp3 is not part of the current snapshot
	tmp3 = "tmp3"
	tmp4 = "tmp4"
end

-- Element definitions

local smdb = elem.allocate("FanMod", "SMDB") -- Super mega death bomb
local srad = elem.allocate("FanMod", "SRAD") -- Hidden. Used by SDMB as part of its explosion

local trit = elem.allocate("FanMod", "TRIT") -- Tritium
local ltrt = elem.allocate("FanMod", "LTRT") -- Liquid Tritium. Hidden, created by pressurizing TRIT

local ffld = elem.allocate("FanMod", "FFLD") -- Forcefield generator

local grph = elem.allocate("FanMod", "GRPH") -- Graphite
local bgph = elem.allocate("FanMod", "BGPH") -- Broken Graphite

local melt = elem.allocate("FanMod", "MELT") -- Melt Powder
local mlva = elem.allocate("FanMod", "MLVA") -- Melting Lava

local mmry = elem.allocate("FanMod", "MMRY") -- Shape Memory Alloy


local halo = elem.allocate("FanMod", "HALO") -- Halogens
local lhal = elem.allocate("FanMod", "LHAL") -- Liquid halogens
local fhal = elem.allocate("FanMod", "FHAL") -- Frozen halogens
local chlw = elem.allocate("FanMod", "CHLW") -- Chlorinated water
local chlw = elem.allocate("FanMod", "FLOR") -- Fluorite
local chlw = elem.allocate("FanMod", "BFLR") -- Broken fluorite

-- v2 Elements
local no32 = elem.allocate("FanMod", "NO32") -- Nobili32
local lncr = elem.allocate("FanMod", "LNCR") -- Launcher
local shot = elem.allocate("FanMod", "SHOT") -- Bullet
local rset = elem.allocate("FanMod", "RSET") -- Resetter

-- Utilities

local mouseButtonType = {
	[1] = function() return tpt.selectedl end,
	[3] = function() return tpt.selectedr end,
	[2] = function() return tpt.selecteda end,
}

local copyInterfaceActive = false
local zoomLensFree = false
local shiftHeld = false

-- I'm cheating and using nil as a third boolean value (means ignore this key)
-- true = ctrl must be held down
-- false = ctrl does not have to be held down
local copyInterfaceKeys = {
	[99] = true, -- C
	[120] = true, -- X
	[118] = true, -- V
	[115] = false, -- S
	[108] = false, -- L
	[107] = false -- K
}

event.register(event.keypress, function(key, scan, rep, shift, ctrl, alt)
	if not rep then
		if key == 122 then -- Z
			zoomLensFree = true
		end

		local requiresCtrl = copyInterfaceKeys[key]

		if requiresCtrl ~= nil then
			if (requiresCtrl and ctrl) or not requiresCtrl then
				copyInterfaceActive = true
			end
		end
	end

	if scan == 225 or scan == 229 then
		shiftHeld = true
	end
end)  

event.register(event.keyrelease, function(key, scan, rep, shift, ctrl, alt)
	
	if key == 122 then -- Z
		zoomLensFree = false
	end
	-- print("You released " .. scan)
	if scan == 225 or scan == 229 then
		shiftHeld = false
	end
end)  

-- local hasShownFfldWarning = false

-- FFLD placement may still have some edge-case problems. Test further?
-- event.register(event.tick, function()
-- 	if not hasShownFfldWarning and mouseButtonType[1]() == "FANMOD_PT_FFLD" or mouseButtonType[2]() == "FANMOD_PT_FFLD" or mouseButtonType[3]() == "FANMOD_PT_FFLD" then
-- 		-- print("Warning: Having FFLD selected may cause some issues with copy/paste or stamps.")
-- 		hasShownFfldWarning = true
-- 	end
-- end)  

local shiftTriangleHold = false
local shiftTriangleID = -1

-- local mouseDown = false
event.register(event.mousedown, function(x, y, button)
	if mouseButtonType[button] ~= nil and mouseButtonType[button]() == "FANMOD_PT_FFLD" and not zoomLensFree and not copyInterfaceActive then
		-- print("Gettin Printed")
		-- mouseDown = true
		local gx, gy = sim.adjustCoords(x, y)
		if (gx >= 4 and gx <= sim.XRES - 4) and (gy >= 4 and gy <= sim.YRES - 4) then
			-- print (gx, gy)
			local i = sim.partCreate(-1, gx, gy, ffld)

			if tpt.brushID == 0 then
				sim.partProperty(i, "tmp", 0x010);
			elseif tpt.brushID == 1 then
				sim.partProperty(i, "tmp", 0x020);
			elseif tpt.brushID == 2 then
				sim.partProperty(i, "tmp", 0x040);
				if shiftHeld then
					shiftTriangleHold = true
					shiftTriangleID = i
				end
			end

			sim.partProperty(i, "temp", math.max(tpt.brushx, tpt.brushy) + 273.15 + 1);
			sim.partProperty(i, tmp4, 1) -- USE NEW MODE ENCODING
			return false
		end
	end

	zoomLensFree = false
	copyInterfaceActive = false
end) 

-- Changes the direction of the triangular forcefield when drawn with a line
event.register(event.mouseup, function(x, y, button, reason)
	if shiftTriangleHold then
		-- print("Gettin Printed")
		-- mouseDown = true
		local gx, gy = sim.adjustCoords(x, y)
		local px, py = sim.partPosition(shiftTriangleID)
		gx = gx - px
		gy = gy - py

		if gx > 0 and gx > math.abs(gy) then
			sim.partProperty(shiftTriangleID, "tmp", 0x060)
		elseif gx < 0 and -gx > math.abs(gy) then
			sim.partProperty(shiftTriangleID, "tmp", 0x070)
		elseif gy > 0 then
			sim.partProperty(shiftTriangleID, "tmp", 0x050)
		else
			sim.partProperty(shiftTriangleID, "tmp", 0x040)
		end
		
	end
	shiftTriangleHold = false
	shiftTriangleID = -1
end) 

-- event.register(event.blur, function()
	-- print("Where We Are")
-- end) 

local solidWalls = { -- SMDB is only allowed to destroy solid walls.
	[1] = true, -- conductive wall
	[2] = true, -- e-wall
	[6] = true, -- liquid only wall
	[7] = true, -- absorb wall
	[8] = true, -- normal wall
	[9] = true, -- air only wall
	[10] = true, -- powder only wall
	[13] = true, -- gas only wall
	[15] = true, -- energy only wall
}

function round(num)
	return math.ceil(num - 0.5)
end

elem.element(smdb, elem.element(elem.DEFAULT_PT_DEST))
elem.property(smdb, "Name", "SMDB")
elem.property(smdb, "Description", "Super mega death bomb. Can destroy literally anything, including walls.")
elem.property(smdb, "Colour", 0xff0000)

elem.property(smdb, "Gravity", 0.1)

elem.property(smdb, "Update", function(i, x, y, s, n)
	local boom = false
	
	for cx = -1, 1 do
		for cy = -1, 1 do
			local type = tpt.get_property('type', x + cx, y + cy)
			if type ~= 0 and type ~= smdb then
				-- print("Particle death")
				boom = true
				goto done
			end

			local wx, wy = math.floor((x + cx) / 4), math.floor((y + cy) / 4)
			if solidWalls[tpt.get_wallmap(wx, wy)] == true then
				-- print("Wall death: " .. tpt.get_wallmap(wx, wy))
				boom = true
				goto done
			end
		end
	end

	::done::

	if boom then
		sim.partKill(i)
		for j=0,30 do
			local rad = sim.partCreate(-3, x, y, srad)
		end
	end
	
	
end)

local useMapCoords = false -- Future-proofing in case simulation.createWallBox is changed to use map instead of part coordinates

function spawnSradJunk(x, y, isWall)
	-- print(x, y)
	if not isWall then
		local old = sim.pmap(x, y)
		sim.partKill(old)
	end

	local r1 = math.random()

	if r1 > 0.99 then
		sim.partCreate(-1, x, y, smdb)
	elseif r1 > 0.97 then
		local part = sim.partCreate(-1, x, y, elem.DEFAULT_PT_BCLN)
		sim.partProperty(part, "ctype", elem.DEFAULT_PT_LIGH)	
	elseif r1 > 0.95 then
		local part = sim.partCreate(-1, x, y, elem.DEFAULT_PT_SING)
		sim.partProperty(part, "tmp", 50000)
	elseif r1 > 0.935 then
		sim.partCreate(-1, x, y, elem.DEFAULT_PT_DMG)
	elseif r1 > 0.92 then
		sim.partCreate(-1, x, y, elem.DEFAULT_PT_GBMB)
	elseif r1 > 0.87 then
		sim.partCreate(-1, x, y, elem.DEFAULT_PT_THDR)
	elseif r1 > 0.80 then
		sim.partCreate(-1, x, y, elem.DEFAULT_PT_DEST)
	elseif r1 > 0.70 then
		sim.partCreate(-1, x, y, elem.DEFAULT_PT_FIRW)
	elseif r1 > 0.50 then
		sim.partCreate(-1, x, y, elem.DEFAULT_PT_WARP)
	else
		sim.partCreate(-1, x, y, elem.DEFAULT_PT_PLSM)
	end


end

elem.element(srad, elem.element(elem.DEFAULT_PT_PROT))
elem.property(srad, "Name", "SRAD")
elem.property(srad, "Description", "Hidden element. Used by SMDB")
elem.property(srad, "Colour", 0xff1111)
elem.property(srad, "MenuSection", -1)
elem.property(srad, "Collision", 1)
 -- elem.property(srad, "Properties", )
for i=0,2^sim.PMAPBITS-1 do
	sim.can_move(srad, i, 2)
end

elements.property(srad, "Create", function(i, x, y, t, v)
	sim.partProperty(i, "vx", (math.random() - 0.5) * 10)
	sim.partProperty(i, "vy", (math.random() - 0.5) * 10)
end)

elem.property(srad, "Update", function(i, x, y, s, n)

	local cx, cy = x + math.random(5) - 3, y + math.random(5) - 3

	local index = sim.pmap(cx, cy)

	-- local type = tpt.get_property('type', cx, cy)
	if index ~= nil then
		local type = sim.partProperty(index, "type")
		if  type ~= srad and type ~= smdb then
			spawnSradJunk(cx, cy, false)
		end
	end

	-- Kill walls

	local wx, wy = math.floor(cx / 4), math.floor(cy / 4)
	if solidWalls[tpt.get_wallmap(wx, wy)] == true then
		if useMapCoords then
			sim.createWallBox(wx, wy, wx, wy, 0)
		else
			sim.createWallBox(cx, cy, cx, cy, 0)
		end
		for xf = 0, 3, 1 do
			for yf = 0, 3, 1 do
				spawnSradJunk(wx * 4 + xf, wy * 4 + yf, true)
			end
		end
	end
end)

elements.property(srad, "Graphics", function(i, r, g, b)
	
	local firea = 255;

	local pixel_mode = ren.PMODE_FLAT + ren.PMODE_FLARE + ren.FIRE_ADD

	return 1,pixel_mode,255,r,g,b,firea,r,g,b;
end)

-- I HATE CONV 🤡🤡🤡🤡🤡🤡🤡🤡🤡🤡🤡🤡🤡
-- Translation: The only element that SMDB is weak against is CONV, so grant SMDB some special ability
-- against it
elem.property(elem.DEFAULT_PT_CONV, "Update", function(i, x, y, s, n)
	for cx = -1, 1 do
		for cy = -1, 1 do
			-- local part = sim.partID(x + cx, y + cy)
			if tpt.get_property("type", x + cx, y + cy) == srad then
				tpt.set_property("ctype", srad, i)
				-- sim.partKill(i)
				-- spawnSradJunk(x, y)
			end
		end
	end
end
, 2)


elem.element(trit, elem.element(elem.DEFAULT_PT_HYGN))
elem.property(trit, "Name", "TRIT")
elem.property(trit, "Description", "Tritium. Radioactive gas. Can be created by firing neutrons at LITH. Can be fused with DEUT.")
elem.property(trit, "Colour", 0x055b3f)
elem.property(trit, "MenuSection", elem.SC_NUCLEAR)
elem.property(trit, "Properties", elem.TYPE_GAS + elem.PROP_NEUTPASS)
elem.property(trit, "HighPressure", 10)
elem.property(trit, "HighPressureTransition", ltrt)

function tritupdate(i, x, y, s, n)
	if math.random(3000) == 1 then
		sim.partChangeType(i, elem.DEFAULT_PT_HYGN)
		local elec = sim.partCreate(-3, x, y, elem.DEFAULT_PT_ELEC)
		sim.partProperty(elec, "temp", sim.partProperty(i, "temp"))
	end

	local nearbyRadiation = false
	local bx, by = x + math.random(3) - 2, y + math.random(3) - 2
	local bp = sim.partID(bx, by)
	if bp ~= nil then
		if (sim.partProperty(bp, "type") == elem.DEFAULT_PT_PHOT) or (sim.partProperty(bp, "type") == elem.DEFAULT_PT_NEUT) then
			nearbyRadiation = true
		end
		-- if nearbyRadiation then print("So Irradiated Rn") end
	end

	-- Not realistic, but making tritium fusion easy to activate makes it more useful.
	if nearbyRadiation or (sim.partProperty(i, "temp") > 1273.15 and sim.pressure(x/4, y/4) > 10.0) then
		local cx, cy = x + math.random(3) - 2, y + math.random(3) - 2
		if tpt.get_property('type', cx, cy) == elem.DEFAULT_PT_DEUT then
			sim.partProperty(i, "temp", sim.partProperty(i, "temp") + math.random(750, 1249))

			sim.partChangeType(i, elem.DEFAULT_PT_NOBL)
			local elec = sim.partCreate(-3, x, y, elem.DEFAULT_PT_NEUT)
			sim.partProperty(elec, "temp", sim.partProperty(i, "temp"))
			sim.pressure(x/4, y/4, sim.pressure(x/4, y/4) + 10)
		end
	end
end
	
elem.property(trit, "Update", tritupdate)


elements.property(trit, "Graphics", function (i, r, g, b)
	
	local colr = r
	local colg = g
	local colb = b
	
	local firea = 255

	local pixel_mode = ren.FIRE_BLEND

	local x, y = sim.partPosition(i)
	x = math.floor(x)
	y = math.floor(y)

	local nearGlass = sim.partNeighbours(x, y, 2, elem.DEFAULT_PT_GLAS)
	local nearFilt = sim.partNeighbours(x, y, 2, elem.DEFAULT_PT_FILT)

	if #nearGlass + #nearFilt > 0 then
		pixel_mode = ren.FIRE_ADD + ren.PMODE_GLOW
	end
	
	local firer = colr;
	local fireg = colg;
	local fireb = colb;
	
	return 0,pixel_mode,255,colr,colg,colb,firea,firer,fireg,fireb;
end)

elem.element(ltrt, elem.element(elem.DEFAULT_PT_DEUT))
elem.property(ltrt, "Name", "LTRT")
elem.property(ltrt, "Description", "Liquid tritium.")
elem.property(ltrt, "Colour", 0x055b3f)
elem.property(ltrt, "MenuSection", -1)
elem.property(ltrt, "Properties", elem.TYPE_LIQUID + elem.PROP_NEUTPASS)
elem.property(ltrt, "LowPressure", 10)
elem.property(ltrt, "LowPressureTransition", trit)
elem.property(ltrt, "Update", tritupdate)

sim.can_move(elem.DEFAULT_PT_ELEC, trit, 2)
sim.can_move(elem.DEFAULT_PT_PHOT, trit, 2)
sim.can_move(elem.DEFAULT_PT_ELEC, ltrt, 2)
sim.can_move(elem.DEFAULT_PT_PHOT, ltrt, 2)


elem.property(elem.DEFAULT_PT_LITH, "Properties", elem.property(elem.DEFAULT_PT_LITH, "Properties") + elem.PROP_NEUTPASS)
-- sim.can_move(elem.DEFAULT_PT_NEUT, elem.DEFAULT_PT_LITH, 2)

-- High-speed neutrons convert Lithium into Tritium
elem.property(elem.DEFAULT_PT_NEUT, "Update", function(i, x, y, s, n)
	if math.random(15) == 1 then
		local index = sim.partID(x, y)
		if index ~= i and index ~= nil and sim.partProperty(index, "type") == elem.DEFAULT_PT_LITH then
			-- print("Neut On Me")
			local velocity = math.sqrt(sim.partProperty(i, "vx") ^ 2 + sim.partProperty(i, "vy") ^ 2)
			if velocity > 5 then
				sim.partChangeType(index, trit)

				sim.partProperty(i, "vx", sim.partProperty(i, "vx") * 0.7)
				sim.partProperty(i, "vy", sim.partProperty(i, "vy") * 0.7)
			end
		end
	end
end)

local oldModeFormatMap = {
	[0x00000000] = 0x000,
	[0x01000000] = 0x100,
	[0x10000000] = 0x200,
	[0x11000000] = 0x300,
	[0x000000] = 0x00,
	[0x001000] = 0x10,
	[0x010000] = 0x20,
	[0x011000] = 0x30,
	[0x100000] = 0x40,
	[0x101000] = 0x50,
	[0x110000] = 0x60,
	[0x111000] = 0x70,
	[0x000] = 0x0,
	[0x001] = 0x1,
	[0x010] = 0x2,
	[0x011] = 0x3,
	[0x100] = 0x4,
	[0x101] = 0x5,
	[0x110] = 0x6,
	[0x111] = 0x7,
}

local shieldPatternFunctions = {
	[0x000] = function(x, y, range, ctype) -- Get all parts matching ctype
		local nearbyCtype = sim.partNeighbours(x, y, range, ctype)
		return nearbyCtype
	end,
	[0x100] = function(x, y, range, ctype) -- Get all parts not matching ctype
		local nearby = sim.partNeighbours(x, y, range)
		-- local nearbyCtype = sim.partNeighbours(x, y, range, ctype)
		local result = {}
		for k,p in pairs(nearby) do
			if sim.partProperty(p, "type") ~= ctype then
				table.insert(result, p)
			end
		end
		return result
	end,
	[0x200] = function(x, y, range, ctype) -- Get all parts if any match ctype
		local nearby = sim.partNeighbours(x, y, range)
		local nearbyCtype = sim.partNeighbours(x, y, range, ctype)
		if #nearbyCtype > 0 then
			return nearby
		end
		return {}
	end,
	[0x300] = function(x, y, range, ctype) -- Get all parts if none match ctype
		local nearby = sim.partNeighbours(x, y, range)
		local nearbyCtype = sim.partNeighbours(x, y, range, ctype)
		if #nearbyCtype == 0 then
			return nearby
		end
		return {}
	end,
	[0x400] = function(x, y, range, ctype) -- Get all parts if any don't match ctype
		local nearby = sim.partNeighbours(x, y, range)
		local nearbyCtype = sim.partNeighbours(x, y, range, ctype)
		if #nearbyCtype < #nearby then
			return nearby
		end
		return {}
	end,
	[0x500] = function(x, y, range, ctype) -- Get all parts if all match ctype
		local nearby = sim.partNeighbours(x, y, range)
		local nearbyCtype = sim.partNeighbours(x, y, range, ctype)
		if #nearbyCtype == #nearby then
			return nearby
		end
		return {}
	end,
	[0x600] = function(x, y, range, ctype) -- Get all parts in range
		local nearby = sim.partNeighbours(x, y, range)
		return nearby
	end,
	[0x700] = function(x, y, range, ctype) -- Get all parts in the same menu section as ctype
		local nearby = sim.partNeighbours(x, y, range)
		local result = {}
		for k,d in pairs(nearby) do
			if elem.property(sim.partProperty(d, "type"), "MenuSection") == elem.property(ctype, "MenuSection") then
				table.insert(result, d)
			end
		end
		return result
	end,
	[0x800] = function(x, y, range, ctype) -- Get all parts in the same state of matter as ctype
		local nearby = sim.partNeighbours(x, y, range)
		local result = {}
		for k,d in pairs(nearby) do
			local ctypeState = bit.band(elem.property(ctype, "Properties"), elem.TYPE_GAS + elem.TYPE_LIQUID + elem.TYPE_PART + elem.TYPE_SOLID + elem.TYPE_ENERGY)
			local dState = bit.band(elem.property(sim.partProperty(d, "type"), "Properties"), elem.TYPE_GAS + elem.TYPE_LIQUID + elem.TYPE_PART + elem.TYPE_SOLID + elem.TYPE_ENERGY)
			if ctypeState == dState then
				table.insert(result, d)
			end
		end
		return result
	end,
	[0x900] = function(x, y, range, ctype) -- Get all parts in a different state of matter as ctype
		local nearby = sim.partNeighbours(x, y, range)
		local result = {}
		for k,d in pairs(nearby) do
			local ctypeState = bit.band(elem.property(ctype, "Properties"), elem.TYPE_GAS + elem.TYPE_LIQUID + elem.TYPE_PART + elem.TYPE_SOLID + elem.TYPE_ENERGY)
			local dState = bit.band(elem.property(sim.partProperty(d, "type"), "Properties"), elem.TYPE_GAS + elem.TYPE_LIQUID + elem.TYPE_PART + elem.TYPE_SOLID + elem.TYPE_ENERGY)
			if ctypeState ~= dState then
				table.insert(result, d)
			end
		end
		return result
	end,
	[0xA00] = function(x, y, range, ctype) -- Get all parts hotter than the ctype as a number
		local nearby = sim.partNeighbours(x, y, range)
		local result = {}
		for k,d in pairs(nearby) do
			if sim.partProperty(d, "temp") > ctype then
				table.insert(result, d)
			end
		end
		return result
	end,
	[0xB00] = function(x, y, range, ctype) -- Get all parts colder than the ctype as a number
		local nearby = sim.partNeighbours(x, y, range)
		local result = {}
		for k,d in pairs(nearby) do
			if sim.partProperty(d, "temp") < ctype then
				table.insert(result, d)
			end
		end
		return result
	end,
	[0xC00] = function(x, y, range, ctype) -- Get all parts matching LMB element
		local mouseType = elem[tpt.selectedl]
		if mouseType ~= nil then
			local nearbyCtype = sim.partNeighbours(x, y, range, mouseType)
			return nearbyCtype
		end
		return {}
	end,
	[0xD00] = function(x, y, range, ctype) -- Get all parts not matching LMB element
		local mouseType = elem[tpt.selectedl]
		local nearby = sim.partNeighbours(x, y, range)
		-- local nearbyCtype = sim.partNeighbours(x, y, range, ctype)
		local result = {}
		for k,p in pairs(nearby) do
			if sim.partProperty(p, "type") ~= mouseType then
				table.insert(result, p)
			end
		end
		return result
	end,
	[0xE00] = function(x, y, range, ctype) -- Get all parts in a different menu section as ctype
		local nearby = sim.partNeighbours(x, y, range)
		local result = {}
		for k,d in pairs(nearby) do
			if elem.property(sim.partProperty(d, "type"), "MenuSection") ~= elem.property(ctype, "MenuSection") then
				table.insert(result, d)
			end
		end
		return result
	end,
}

-- Do not display an "invalid type" warning if any of these modes are selected
local ctypeSafePatternFunctions = {
	[0x600] = true,
	[0xA00] = true,
	[0xB00] = true,
	[0xC00] = true,
	[0xD00] = true,
}

local shieldFunctions = {
	[0x000] = function(size, dx, dy) -- None
		return false 
	end,
	[0x010] = function(size, dx, dy)  -- Circle
		local dist = math.sqrt(dx ^ 2 + dy ^ 2)
		return dist < size
	end,
	[0x020] = function(size, dx, dy) -- Square
		return true 
	end,
	[0x030] = function(size, dx, dy) -- Diamond
		local dist = math.abs(dx) + math.abs(dy)
		return dist < size
	end,
	[0x040] = function(size, dx, dy) -- Triangle (up)
		local dist = math.abs(dx) - dy / 2 + size / 2
		return dist < size
	end,
	[0x050] = function(size, dx, dy) -- Triangle (down)
		local dist = math.abs(dx) + dy / 2 + size / 2
		return dist < size
	end,
	[0x060] = function(size, dx, dy) -- Triangle (right)
		local dist = math.abs(dy) + dx / 2 + size / 2
		return dist < size
	end,
	[0x070] = function(size, dx, dy) -- Triangle (left)
		local dist = math.abs(dy) - dx / 2 + size / 2
		return dist < size
	end,
}

local shieldDrawFunctions = {
	[0x000] = function(size, x, y, r, g, b, a) -- None

	end,
	[0x010] = function(size, x, y, r, g, b, a)  -- Circle
		graphics.drawCircle(x, y, size + 1, size + 1, r, g, b, a) 
	end,
	[0x020] = function(size, x, y, r, g, b, a) -- Square
		graphics.drawRect(x - size, y - size, size * 2 + 1, size * 2 + 1, r, g, b, a)
	end,
	[0x030] = function(size, x, y, r, g, b, a) -- Diamond
		graphics.drawLine(x + size, y, x, y + size, r, g, b, a)
		graphics.drawLine(x, y + size, x - size, y, r, g, b, a)
		graphics.drawLine(x - size, y, x, y - size, r, g, b, a)
		graphics.drawLine(x, y - size, x + size, y, r, g, b, a)
		return nil
	end,
	[0x040] = function(size, x, y, r, g, b, a) -- Triangle (up)
		graphics.drawLine(x + size, y + size, x, y - size, r, g, b, a)
		graphics.drawLine(x, y - size, x - size, y + size, r, g, b, a)
		graphics.drawLine(x - size, y + size, x + size, y + size, r, g, b, a)
	end,
	[0x050] = function(size, x, y, r, g, b, a) -- Triangle (down)
		graphics.drawLine(x + size, y - size, x, y + size, r, g, b, a)
		graphics.drawLine(x, y + size, x - size, y - size, r, g, b, a)
		graphics.drawLine(x - size, y - size, x + size, y - size, r, g, b, a)
	end,
	[0x060] = function(size, x, y, r, g, b, a) -- Triangle (right)
		graphics.drawLine(x - size, y + size, x + size, y, r, g, b, a)
		graphics.drawLine(x + size, y, x - size, y - size, r, g, b, a)
		graphics.drawLine(x - size, y - size, x - size, y + size, r, g, b, a)
	end,
	[0x070] = function(size, x, y, r, g, b, a) -- Triangle (left)
		graphics.drawLine(x + size, y + size, x - size, y, r, g, b, a)
		graphics.drawLine(x - size, y, x + size, y - size, r, g, b, a)
		graphics.drawLine(x + size, y - size, x + size, y + size, r, g, b, a)
	end,
}

-- Used for action 0x00A (Highlight).
local highlighted = {}
local updateHighlighted = true
local highlightedDrawn = false

event.register(event.tick, function()
	highlightedDrawn = false
end)  

local pipeTypes = {
	[elem.DEFAULT_PT_PIPE] = true,
	[elem.DEFAULT_PT_PPIP] = true
}

function transferPartToPipe(part, pipe)
	if sim.partProperty(pipe, "ctype") == 0 then
		sim.partProperty(pipe, "ctype", sim.partProperty(part, "type"))
		sim.partProperty(pipe, "temp", sim.partProperty(part, "temp"))
		sim.partProperty(pipe, "tmp2", sim.partProperty(part, "life"))
		sim.partProperty(pipe, tmp3, sim.partProperty(part, "tmp"))
		sim.partProperty(pipe, tmp4, sim.partProperty(part, "ctype"))
		sim.partKill(part)
		return true
	end
	return false
end

-- Return true: continue processing particles after this one
-- Return false: stop processing particles after this one
local shieldActionFunctions = {
	[0x000] = function(d, x, y) -- Repel
		local px, py = sim.partPosition(d)
		px = px - x
		py = py - y
		local fx = px / math.sqrt(px ^ 2 + py ^ 2)
		local fy = py / math.sqrt(px ^ 2 + py ^ 2)
		sim.partProperty(d, "vx", sim.partProperty(d, "vx") + fx)
		sim.partProperty(d, "vy", sim.partProperty(d, "vy") + fy)
		return true
	end,
	[0x001] = function(d, x, y) -- Destroy
		sim.partChangeType(d, elem.DEFAULT_PT_EMBR)
		sim.partProperty(d, "life", 30)
		return true
	end,
	[0x002] = function(d, x, y) -- Suspend
		sim.partProperty(d, "vx", 0)
		sim.partProperty(d, "vy", 0)
		return true
	end,
	[0x003] = function(d, x, y) -- Detect
		for p in sim.neighbors(x, y, 2, 2) do
			if sim.partProperty(p, "life") == 0 and bit.band(elem.property(sim.partProperty(p, "type"), "Properties"), elem.TYPE_SOLID + elem.PROP_CONDUCTS) == elem.TYPE_SOLID + elem.PROP_CONDUCTS then
				local ctype = sim.partProperty(p, "type")
				sim.partChangeType(p, elem.DEFAULT_PT_SPRK)
				sim.partProperty(p, "life", 4)
				sim.partProperty(p, "ctype", ctype)
			end
		end
		return false
	end,
	[0x004] = function(d, x, y) -- Superheat
		if elem.property(sim.partProperty(d, "type"), "HeatConduct") ~= 0 then
			sim.partProperty(d, "temp", 10000)
		end
		return true
	end,
	[0x005] = function(d, x, y) -- Supercool
		if elem.property(sim.partProperty(d, "type"), "HeatConduct") ~= 0 then
			sim.partProperty(d, "temp", 0)
		end
		return true
	end,
	[0x006] = function(d, x, y) -- Encase
		local px, py = sim.partPosition(d)
		px = round(px)
		py = round(py)
		for cx = -1, 1 do
			for cy = -1, 1 do
				local bray = sim.partCreate(-1, px + cx, py + cy, elem.DEFAULT_PT_BRAY)
				sim.partProperty(bray, "tmp", 0x01000110 )
			end
		end
		sim.partProperty(d, "vx", 0)
		sim.partProperty(d, "vy", 0)
		return true
	end,
	[0x007] = function(d, x, y) -- Annihilate
		sim.partChangeType(d, elem.DEFAULT_PT_SING)
		sim.partProperty(d, "tmp", 50000)
		sim.partProperty(d, "life", 0)
		return true
	end,
	[0x008] = function(d, x, y) -- Attract
		local px, py = sim.partPosition(d)
		px = px - x
		py = py - y
		local fx = px / math.sqrt(px ^ 2 + py ^ 2)
		local fy = py / math.sqrt(px ^ 2 + py ^ 2)
		sim.partProperty(d, "vx", sim.partProperty(d, "vx") - fx)
		sim.partProperty(d, "vy", sim.partProperty(d, "vy") - fy)
		return true
	end,
	[0x009] = function(d, x, y) -- Collect
		for p in sim.neighbors(x, y, 2, 2) do
			if pipeTypes[sim.partProperty(p, "type")] then
				local successfulTransfer = transferPartToPipe(d, p)
				if successfulTransfer then
					return true
				end
			end
		end
		return false
	end,
	[0x00A] = function(d, x, y) -- Highlight
		local px, py = sim.partPosition(d)
		px = round(px + sim.partProperty(d, "vx"))
		py = round(py + sim.partProperty(d, "vy"))
		table.insert(highlighted, {px, py})
		return true
	end,
	[0x00B] = function(d, x, y) -- Paint with deco color
		local color = sim.partProperty(sim.pmap(x, y), "dcolour")
		sim.partProperty(d, "dcolour", color)
		return true
	end,
	[0x00C] = function(d, x, y) -- Delete (no embr)
		-- Doesn't look as cool but avoids some of the problems the embr causes in some cases
		sim.partKill(d)
		return true
	end,
}

local ffldIgnore = {
	[elem.DEFAULT_PT_BRAY] = true,
	-- [elem.DEFAULT_PT_EMBR] = true,
	[ffld] = true,
}

function shouldIgnore(type, fieldCtype, mode)
	if mode == 0x1 and type == elem.DEFAULT_PT_EMBR then
		return false
	end

	return ffldIgnore[type] and type ~= fieldCtype
end

function isInsideFieldShape(size, shape, dx, dy)
	return shieldFunctions[shape](size, dx, dy)

end

-- ctype: The element that this forcefield protects against.
-- temp: Field radius.
-- life: Used for the flashing effect when the forcefield activates or deactivates.
-- tmp: Forcefield mode. To be reformatted.
	-- OLD: 0xPPSSSMMM
	-- NEW: 0xPSM (Mistook hex literals for binary; wasted a lot of space.)
-- tmp2: Whether or not the forcefield is enabled.
-- pavg0: Whether or not there are any (matching) particles inside the forcefield. Used for graphics.
-- pavg1: Whether to use new or old forcefield mode encoding (not yet implemented)

elem.element(ffld, elem.element(elem.DEFAULT_PT_CLNE))
elem.property(ffld, "Name", "FFLD")
elem.property(ffld, "Description", "Forcefield generator. Repels parts of its ctype. Temp sets range, TMP sets mode. Toggle with PSCN/NSCN or ARAY.")
elem.property(ffld, "Colour", 0x00de94)
elem.property(ffld, "HeatConduct", 0)
elem.property(ffld, "Hardness", 0)
elem.property(ffld, "MenuSection", elem.SC_FORCE)

elem.property(ffld, "Properties", elem.TYPE_SOLID + elem.PROP_NOCTYPEDRAW + elem.PROP_NOAMBHEAT + elem.PROP_LIFE_DEC)

elements.property(ffld, "Create", function(i, x, y, t, v)

	sim.partProperty(i, "tmp2", 1)
	sim.partProperty(i, tmp3, 0)
end)

-- Does not account for the fact that elements may be deallocated
-- But who the hell does that
-- (Trust no one)
local definitelySafeElementIds = {}

-- (TRUST NO ONE)
for i=0,2^sim.PMAPBITS-1 do
	-- table.insert(definitelySafeElementIds, i, false)
	definitelySafeElementIds[i] = false
end

elem.property(ffld, "Update", function(i, x, y, s, n)

	if updateHighlighted then
		updateHighlighted = false
		highlighted = {}
	end

	if sim.partProperty(i, "temp") < 273.15 then
		sim.partProperty(i, "temp", 273.15)
	end
	if sim.partProperty(i, "temp") > 273.15 + 200 then
		sim.partProperty(i, "temp", 273.15 + 200)
	end

	local enabled = sim.partProperty(i, "tmp2") -- Used for toggling with silicon/aray

	for cx = -2, 2 do
		for cy = -2, 2 do
			local id = sim.partID(x + cx, y + cy)
			if id ~= nil then
				if sim.partProperty(id, "type") == elem.DEFAULT_PT_BRAY then
					if sim.partProperty(id, "tmp") < 2 then
						sim.partProperty(i, "tmp2", 1)
						sim.partProperty(i, "life", 20)
					elseif sim.partProperty(id, "tmp") == 2 then
						sim.partProperty(i, "tmp2", 0)
						sim.partProperty(i, "life", 20)
					end
				end

				if sim.partProperty(id, "type") == elem.DEFAULT_PT_SPRK then
					if sim.partProperty(id, "ctype") == elem.DEFAULT_PT_PSCN then
						sim.partProperty(i, "tmp2", 1)
						sim.partProperty(i, "life", 20)
					elseif sim.partProperty(id, "ctype") == elem.DEFAULT_PT_NSCN then
						sim.partProperty(i, "tmp2", 0)
						sim.partProperty(i, "life", 20)
					end
				end
			end
		end
	end

	local newFormat = sim.partProperty(i, tmp4)


	if enabled == 1 then

		local ctype = sim.partProperty(i, "ctype")
		local range = math.floor(math.max(sim.partProperty(i, "temp") - 273.15, 0))
		local tmp = sim.partProperty(i, "tmp")

		local pattern = 0-- = bit.band(tmp, 0x11000000)
		local shape = 0-- = bit.band(tmp, 0x00111000)
		local action = 0-- = bit.band(tmp, 0x00000111)

		if newFormat == 1 then
			pattern = bit.band(tmp, 0xF00)
			shape = bit.band(tmp, 0x0F0)
			action = bit.band(tmp, 0x00F)
		else
			pattern = oldModeFormatMap[bit.band(tmp, 0x11000000)]
			shape = oldModeFormatMap[bit.band(tmp, 0x00111000)]
			action = oldModeFormatMap[bit.band(tmp, 0x00000111)]
		end

		if not ctypeSafePatternFunctions[pattern] and not definitelySafeElementIds[ctype] then
			if pcall(elements.property, ctype, "Name") then
				definitelySafeElementIds[ctype] = true
			else
				print("Warning: " .. ctype .. " is not a valid element ID.")
				sim.partProperty(i, "ctype", 0)
				return
			end
		end

		if shieldPatternFunctions[pattern] and shieldActionFunctions[action] and shieldFunctions[shape] then
			local nearby = shieldPatternFunctions[pattern](x, y, range, ctype)

			local any = false

			for k,d in pairs(nearby) do
				local px, py = sim.partPosition(d)
				if not px or not py then print(k, d, px, py) end
				if isInsideFieldShape(range, shape, px - x, py - y) and not shouldIgnore(sim.partProperty(d, "type"), ctype) then
					shieldActionFunctions[action](d, x, y)
					any = true
				end
			end

			if sim.partProperty(i, tmp3) == 0 and any then
				sim.partProperty(i, tmp3, 1)
				sim.partProperty(i, "life", 20)
			end

			if sim.partProperty(i, tmp3) == 1 and not any then
				sim.partProperty(i, tmp3, 0)
				sim.partProperty(i, "life", 20)
			end
		else
			print("Warning: " .. bit.tohex(tmp) .. " is not a valid forcefield mode.")
			sim.partProperty(i, "tmp", 0)
		end
	end

end)

elem.property(ffld, "Graphics", function (i, r, g, b)

	if not highlightedDrawn then
		for k,d in pairs(highlighted) do
			graphics.drawCircle(d[1], d[2], 2, 2, 255, 0, 0, 255) 
		end
		updateHighlighted = true
		highlightedDrawn = true
	end


	local anyParts = sim.partProperty(i, tmp3)

	local enabled = sim.partProperty(i, "tmp2")
	local flash = sim.partProperty(i, "life")

	local colr = r
	local colg = g
	local colb = b

	local firea = 0
	
	local pixel_mode = ren.PMODE_FLAT

	local newFormat = sim.partProperty(i, tmp4)


	local ctype = sim.partProperty(i, "ctype")
	local range = math.floor(math.max(sim.partProperty(i, "temp") - 273.15, 0))
	local tmp = sim.partProperty(i, "tmp")

	local pattern = 0
	local shape = 0
	local action = 0

	if newFormat == 1 then
		pattern = bit.band(tmp, 0xF00)
		shape = bit.band(tmp, 0x0F0)
		action = bit.band(tmp, 0x00F)
	else
		pattern = oldModeFormatMap[bit.band(tmp, 0x11000000)]
		shape = oldModeFormatMap[bit.band(tmp, 0x00111000)]
		action = oldModeFormatMap[bit.band(tmp, 0x00000111)]
	end

	local fieldr = 0
	local fieldg = 0
	local fieldb = 0
	local fielda = 0

	if enabled == 1 then
		fieldr = 0
		fieldg = 0
		fieldb = 255
		fielda = 255

		if anyParts == 1 then
			fieldg = 255
			fieldb = 0
		end

		-- firea = flash / 20 * 255
		firea = 255

		pixel_mode = ren.PMODE_FLAT + ren.PMODE_GLOW

		if enabled == 1 then
			pixel_mode = ren.PMODE_FLAT + ren.PMODE_GLOW + ren.PMODE_SPARK
		end
	else
		colr = colr / 2
		colg = colg / 2
		colb = colb / 2
	end
	
	fieldr = fieldr + flash / 20 * 255
	fieldg = fieldg + flash / 20 * 255
	fieldb = fieldb + flash / 20 * 255
	fielda = fielda + flash / 20 * 255

	local x, y = sim.partPosition(i)
	shieldDrawFunctions[shape](range, x, y, fieldr, fieldg, fieldb, fielda)

	return 0,pixel_mode,255,colr,colg,colb,firea,colr,colg,colb;
end)

elem.property(ffld, "CtypeDraw", function(i, t)
	pattern = bit.band(sim.partProperty(i, "tmp"), 0xF00)

	if pattern == 0xA00 or pattern == 0xB00 then
		if bit.band( elem.property(t, "Properties"), elem.PROP_NOCTYPEDRAW) == 0 then
			sim.partProperty(i, "ctype", elem.property(t, "Temperature"))
		end
	else
		if bit.band( elem.property(t, "Properties"), elem.PROP_NOCTYPEDRAW) == 0 then
			sim.partProperty(i, "ctype", t)
		end
	end
end)

local graphiteIgniters = {
	[elem.DEFAULT_PT_FIRE] = true,
	[elem.DEFAULT_PT_PLSM] = true,
	[elem.DEFAULT_PT_OXYG] = true,
}

local graphiteBurnHealth = 40
local graphitePressureHealth = 10
local graphiteExtinguishTime = 30
local brokenGraphBurnHealth = 60

-- Likely the most complicated element in this mod
-- life: Not used by the main update function so it can safely transform into LAVA or SPRK and back.
-- tmp: Burn health. Decrements once for every flame particle created.
-- tmp2: Pressure health. Has a 1/2 chance of decrementing every frame the particle is exposed to 80+ pressure.
-- pavg0: Used for a "graphite cycle" that makes sure sparks running through graphite are not subject to particle order bias.
-- pavg1: Used for the direction that sparks are travelling through the material as well as a dead space behind each spark, similarly to how other conductors use life.

elem.element(grph, elem.element(elem.DEFAULT_PT_DMND))
elem.property(grph, "Name", "GRPH")
elem.property(grph, "Description", "Graphite. Strong solid. Can withstand extreme conditions and slows radiation. Conducts electricity in straight lines.")
elem.property(grph, "Colour", 0x15111D)
elem.property(grph, "MenuSection", elem.SC_SOLIDS)
elem.property(grph, "Properties", elem.TYPE_SOLID + elem.PROP_NEUTPASS + elem.PROP_BLACK)
elem.property(grph, "Hardness", 2)
elem.property(grph, "HeatConduct", 12)
elem.property(grph, "HighTemperature", 273.15 + 3400)
elem.property(grph, "HighTemperatureTransition", elem.DEFAULT_PT_LAVA)

elements.property(grph, "Create", function(i, x, y, t, v)

	sim.partProperty(i, "tmp", graphiteBurnHealth)
	sim.partProperty(i, "tmp2", graphitePressureHealth)
end)

local nearbyPartsTable = {
	[0x1] = function(x, y) return {sim.pmap(x, y - 1), sim.pmap(x, y - 2), sim.pmap(x, y - 3), sim.pmap(x, y - 4), } end, -- Up
	[0x2] = function(x, y) return {sim.pmap(x, y + 1), sim.pmap(x, y + 2), sim.pmap(x, y + 3), sim.pmap(x, y + 4), } end, -- Down
	[0x4] = function(x, y) return {sim.pmap(x + 1, y), sim.pmap(x + 2, y), sim.pmap(x + 3, y), sim.pmap(x + 4, y), } end, -- Right
	[0x8] = function(x, y) return {sim.pmap(x - 1, y), sim.pmap(x - 2, y), sim.pmap(x - 3, y), sim.pmap(x - 4, y), } end -- Left
}

local initialDetectionOffsets = {
	{0, -1}, -- Up
	{0, 1}, -- Down
	{1, 0}, -- Right
	{-1, 0}, -- Left
}

local oppositeDirections = {
	[0x1] = 0x2,
	[0x2] = 0x1,
	[0x4] = 0x8,
	[0x8] = 0x4
}

local updateGraphiteCycle = false
local graphiteCycle = 0
local nextGraphiteCycle = 0

event.register(event.tick, function()
	if updateGraphiteCycle then
		graphiteCycle = nextGraphiteCycle
		nextGraphiteCycle = (graphiteCycle + 1) % 4
		updateGraphiteCycle = false
	end
	-- print (graphiteCycle)
end)  

-- 0x10 - Horizontal
-- 0x20 - Vertical
local bitNegaterMap = 
{
	[0x0] = 0x0,
	[0x1] = 0x10,
	[0x2] = 0x10,
	[0x3] = 0x10, -- Illegal state
	[0x4] = 0x20,
	[0x5] = 0x30,
	[0x6] = 0x30,
	[0x7] = 0x30, -- Illegal state
	[0x8] = 0x20,
	[0x9] = 0x30,
	[0xA] = 0x30,
	[0xB] = 0x20, -- Illegal state
	[0xC] = 0x30, -- Illegal state
	[0xD] = 0x30, -- Illegal state
	[0xE] = 0x30, -- Illegal state
	[0xF] = 0x30, -- Illegal state
}

local hoveredPart = -1

local pavg0Debug = false
event.register(event.tick, function()
	if pavg0Debug then
		local gx, gy = sim.adjustCoords(tpt.mousex, tpt.mousey)
		local part = sim.pmap(gx, gy)

		if part ~= nil then
			local text = bit.tohex(sim.partProperty(part, tmp4))
			graphics.drawText(10, 10, text)
			hoveredPart = part
		else
			hoveredPart = -1
		end
	end
end)  

function sparkGraphite(i, sparkDir)
	-- if i == hoveredPart then
	-- 	print("They tried to spark me!")
	-- end
	if i ~= nil and (sim.partProperty(i, "type") == grph or (sim.partProperty(i, "type") == elem.DEFAULT_PT_SPRK and sim.partProperty(i, "ctype") == grph)) then
		local dir = sim.partProperty(i, tmp4)
		local negate = bit.band(dir, bitNegaterMap[sparkDir] * 5)
		if bit.band(dir, oppositeDirections[sparkDir] + sparkDir) == 0 and negate == 0x0 then 
		
			sim.partChangeType(i, elem.DEFAULT_PT_SPRK)
			sim.partProperty(i, "ctype", grph)
			-- if sim.partProperty(i, "life") <= 3 then
			-- 	sim.partProperty(i, tmp4, sparkDir)
			-- else
				sim.partProperty(i, tmp4, bit.bor(sim.partProperty(i, tmp4), sparkDir))
			-- end
			sim.partProperty(i, "life", 4)
			sim.partProperty(i, tmp3, nextGraphiteCycle)
			-- if i == hoveredPart then
			-- 	print("I got sparked! dir: " .. dir .. ", negate: " .. negate .. ", sparkDir: " .. sparkDir)
			-- end
			return true
		end
	end
	return false
end

function graphiteSparkNormal(i)
	if i ~= nil then
		local type = sim.partProperty(i, "type")
		if bit.band(elements.property(type, "Properties"), elements.PROP_CONDUCTS) ~= 0 and type ~= elem.DEFAULT_PT_PSCN then
			local px, py = sim.partPosition(i)
			sim.partCreate(-1, px, py, elem.DEFAULT_PT_SPRK)
			-- sim.partChangeType(i, elem.DEFAULT_PT_SPRK)
			-- sim.partProperty(i, "life", 4)
			-- sim.partProperty(i, "ctype", type)
			return true
		end
	end
	return false
end

local graphiteProgrammable = {
	[elem.DEFAULT_PT_PTCT] = true,
	[elem.DEFAULT_PT_NTCT] = true
}

elem.property(elem.DEFAULT_PT_SPRK, "Update", function(i, x, y, s, n)
	
	updateGraphiteCycle = true
	local ctype = sim.partProperty(i, "ctype")
	local life = sim.partProperty(i, "life")
	local timer = sim.partProperty(i, tmp3)
	if ctype == grph then
		if timer == graphiteCycle then
			for d = 1, 4 do
				local dirBit = 2 ^ (d - 1)
				local dir = bit.band(sim.partProperty(i, tmp4), dirBit)
				if dir == dirBit then
					for p = 1, 4 do
						local part = sim.pmap(x + initialDetectionOffsets[d][1] * p, y + initialDetectionOffsets[d][2] * p)
						if not sparkGraphite(part, dir) and not graphiteSparkNormal(part) then
							break
						end
					end
				end
			end
		end

		if life == 1 then
			sim.partProperty(i, tmp4, bitNegaterMap[bit.band(sim.partProperty(i, tmp4), 0xF)])
		end
	elseif ctype ~= elem.DEFAULT_PT_NSCN then
		for d = 1, 4 do
			local dirBit = 2 ^ (d - 1)
			if graphiteProgrammable[ctype] then
				local tmp = sim.partProperty(i, "tmp")
				if bit.band(tmp, dirBit) ~= 0 then
					goto continue
				end
			end
			local nearbyParts = nearbyPartsTable[dirBit](x, y)
			for p = 1, 4 do
				local part = sim.pmap(x + initialDetectionOffsets[d][1] * p, y + initialDetectionOffsets[d][2] * p)
				if not sparkGraphite(part, dirBit) then
					break
				end
			end
			::continue::
		end
	end
end, 3)

elem.property(grph, "Update", function(i, x, y, s, n)

	if bit.band(sim.partProperty(i, tmp4), 0x10) == 0x10 then
		sim.partProperty(i, tmp4, bit.bxor(sim.partProperty(i, tmp4), 0x50))
	elseif bit.band(sim.partProperty(i, tmp4), 0x40) == 0x40 then
		sim.partProperty(i, tmp4, bit.bxor(sim.partProperty(i, tmp4), 0x40))
	end

	if bit.band(sim.partProperty(i, tmp4), 0x20) == 0x20 then
		sim.partProperty(i, tmp4, bit.bxor(sim.partProperty(i, tmp4), 0xA0))
	elseif bit.band(sim.partProperty(i, tmp4), 0x80) == 0x80 then
		sim.partProperty(i, tmp4, bit.bxor(sim.partProperty(i, tmp4), 0x80))
	end

	sim.partProperty(i, tmp4, bit.band(sim.partProperty(i, tmp4), 0xF0))

	local a = sim.photons(x, y)
	-- print(a)
	if a ~= nil then
		-- print(a)
		local vel = math.sqrt(sim.partProperty(a, "vx") ^ 2 + sim.partProperty(a, "vy") ^ 2)
		if vel > 0.1 then
			sim.partProperty(a, "vx", sim.partProperty(a, "vx") * 0.85)
			sim.partProperty(a, "vy", sim.partProperty(a, "vy") * 0.85)
		end
		sim.partProperty(a, "life", sim.partProperty(a, "life") - 3)
		if math.random(100) == 1 or sim.partProperty(a, "life") <= 0 then
			sim.partKill(a)
		end
	end

	local tempC = sim.partProperty(i, "temp") - 273.15

	if tempC < 400 then
		sim.partProperty(i, tmp3, 0)
	end

	local burnHealth = sim.partProperty(i, tmp3)

	local pressure = simulation.pressure(x / 4, y / 4)

	if pressure > 80 and math.random(2) == 1 then
		sim.partProperty(i, "tmp2", sim.partProperty(i, "tmp2") - 1)
		if sim.partProperty(i, "tmp2") <= 0 then
			sim.partChangeType(i, bgph)
			if tempC > 1000 then
				sim.partProperty(i, "life", brokenGraphBurnHealth - 1)
			else
				sim.partProperty(i, "life", brokenGraphBurnHealth)
			end
			return
		end
	end

	if burnHealth > 0 then

		local fireNeighbors = sim.partNeighbours(x, y, 1, elem.DEFAULT_PT_FIRE)
		local plsmNeighbors = sim.partNeighbours(x, y, 1, elem.DEFAULT_PT_PLSM)
		if #fireNeighbors > 0 or #plsmNeighbors > 0 then
			sim.partProperty(i, tmp3, graphiteExtinguishTime)
		else
			sim.partProperty(i, tmp3, sim.partProperty(i, tmp3) - 1)
		end
		local fire = sim.partCreate(-1, x + math.random(3) - 2, y + math.random(3) - 2, elem.DEFAULT_PT_FIRE)
		if fire ~= -1 then
			sim.partProperty(i, "temp", sim.partProperty(i, "temp") + 10)
			sim.partProperty(fire, "temp", sim.partProperty(i, "temp")) -- Graphite burns hotter than most materials

			sim.partProperty(i, "tmp", sim.partProperty(i, "tmp") - 1)
		end

		if sim.partProperty(i, "tmp") <= 0 then
			sim.partKill(i)
			return
		end
	else
		local randomNeighbor = sim.pmap(x + math.random(3) - 2, y + math.random(3) - 2)
		if tempC > 400 and randomNeighbor ~= nil and (graphiteIgniters[sim.partProperty(randomNeighbor, "type")] == true) then
			sim.partProperty(i, tmp3, graphiteExtinguishTime)
		end
	end

end)



function graphiteGraphics(i, r, g, b)

	local tempC = sim.partProperty(i, "temp") - 273.15
	local burn = graphiteBurnHealth - sim.partProperty(i, "tmp")
	-- local vel = sim.velocityX(number x, number y)

	local pixel_mode = ren.PMODE_FLAT

	local colr = r
	local colg = g
	local colb = b

	if sim.partProperty(i, "type") == grph then
		colr = r + burn * 5
		colg = g + burn * 5
		colb = b + burn * 4
	end

	local firea = 0

	if tempC > 300 then
		colr = colr + (tempC - 300) * 0.2
	end

	if tempC > 1200 then
		colg = colg + (tempC - 1200) * 0.2
	end

	if tempC > 2000 then
		colb = colb + (tempC - 2000) * 0.2
	end

	if tempC > 1600 then
		firea = firea + (tempC - 1600) * 0.02
		pixel_mode = ren.PMODE_FLAT + ren.FIRE_ADD
	end

	local firer = colr;
	local fireg = colg;
	local fireb = colb;

	return 0,pixel_mode,255,colr,colg,colb,firea,colr,colg,colb;

end

elem.property(grph, "Graphics", graphiteGraphics)

elem.property(elem.DEFAULT_PT_COAL, "Update", function(i, x, y, s, n)
	if math.random(15) == 1 then
		local pressure = simulation.pressure(x / 4, y / 4)
		local tempC = sim.partProperty(i, "temp") - 273.15
		if pressure < -20 and tempC > 1000 then
			sim.partChangeType(i, grph)
			sim.partProperty(i, "tmp", graphiteBurnHealth)
			sim.partProperty(i, "tmp2", graphitePressureHealth)
		end
	end
end)

elem.property(elem.DEFAULT_PT_BCOL, "Update", function(i, x, y, s, n)
	if math.random(15) == 1 then
		local pressure = simulation.pressure(x / 4, y / 4)
		local tempC = sim.partProperty(i, "temp") - 273.15
		if pressure < -20 and tempC > 1000 then
			sim.partChangeType(i, bgph)
			sim.partProperty(i, "life", brokenGraphBurnHealth)
		end
	end
end)


-- life: Used for burn time, similar to coal. At 60, does nothing. Below 60, counts down and emits fire, disappearing at 0.
-- tmp: Used while burning. Starts at a random value between 11 and 30. Counts down every frame that this particle has no neighbors of the same type. At zero, explodes.
-- pavg1: Speed on the previous frame. Used to calculate if the particle has impacted a surface so that it can draw on it.

elem.element(bgph, elem.element(elem.DEFAULT_PT_DUST))
elem.property(bgph, "Name", "BGPH")
elem.property(bgph, "Description", "Broken graphite. Can color surfaces dark. Very flammable.")
elem.property(bgph, "Colour", 0x39304e)
elem.property(bgph, "MenuSection", elem.SC_POWDERS)
elem.property(bgph, "Properties", elem.TYPE_PART + elem.PROP_BLACK)
elem.property(bgph, "Hardness", 4)
elem.property(bgph, "HeatConduct", 20)
elem.property(bgph, "Flammable", 0)
elem.property(bgph, "Advection", 0.4)
elem.property(bgph, "Gravity", 0.2)
-- elem.property(bgph, "HighTemperature", 273.15 + 3400)
-- elem.property(bgph, "HighTemperatureTransition", elem.DEFAULT_PT_LAVA)
elem.property(bgph, "Create", function(i, x, y, t, v)

	sim.partProperty(i, "life", 60)
end)

elem.property(bgph, "Update", function(i, x, y, s, n)
	local tempC = sim.partProperty(i, "temp") - 273.15


	local vx = sim.partProperty(i, "vx")
	local vy = sim.partProperty(i, "vy")
	local totalVel = math.sqrt(vx ^ 2 + vy ^ 2) * 100

	local vdx = (sim.partProperty(i, tmp4) - totalVel) / 100

	sim.partProperty(i, tmp4, totalVel)
	-- print(vdx)
	-- print(totalVel)

	if vdx > 0.5 then
		local neighbors = {}
		if vdx > 1 then
			neighbors = sim.partNeighbours(x, y, 2)
		else
			neighbors = sim.partNeighbours(x, y, 1)
		end
		for k,d in pairs(neighbors) do
			local type = sim.partProperty(d, "type")
			if bit.band(elements.property(type, "Properties"), elements.TYPE_SOLID) ~= 0 and type ~= grph then
				local blend = math.min(vdx - 0.5, 1)

				local tr, tg, tb, ta = graphics.getColors(0xFF2E273F)
				local mr, mg, mb, ma = graphics.getColors(sim.partProperty(d, "dcolour"))

				local nr = (tr*blend) + (mr*(1 - blend))
				local ng = (tg*blend) + (mg*(1 - blend))
				local nb = (tb*blend) + (mb*(1 - blend))
				local na = (ta*blend) + (ma*(1 - blend))
				
				sim.partProperty(d, "dcolour", graphics.getHexColor(nr, ng, nb, na))
			end
		end
	end

	if sim.partProperty(i, "life") >= brokenGraphBurnHealth then
		local randomNeighbor = sim.pmap(x + math.random(3) - 2, y + math.random(3) - 2)
		local pressure = simulation.pressure(x / 4, y / 4)
		if (tempC > 1000 and pressure > -2) or randomNeighbor ~= nil and (graphiteIgniters[sim.partProperty(randomNeighbor, "type")] == true) then
			sim.partProperty(i, "life", brokenGraphBurnHealth - 1)
			sim.partProperty(i, "tmp", 10 + math.random(20))
		end
	else
		sim.partCreate(-1, x + math.random(3) - 2, y + math.random(3) - 2, elem.DEFAULT_PT_FIRE)

		sim.partProperty(i, "life", sim.partProperty(i, "life") - 1)
		if sim.partProperty(i, "life") <= 0 then
			sim.partKill(i)
			return
		end

		local nearby = sim.partNeighbours(x, y, 1, bgph)
		if #nearby == 0 then
			sim.partProperty(i, "tmp", sim.partProperty(i, "tmp") - 1)
			if sim.partProperty(i, "tmp") <= 0 then
				for cx = -1, 1 do
					for cy = -1, 1 do
						local fire = sim.partCreate(-1, x + cx, y + cy, elem.DEFAULT_PT_FIRE)
						sim.partProperty(fire, "temp", sim.partProperty(i, "temp") + 200)
					end
				end
				-- sim.createBox(x - 1, y - 1, x + 1, y + 1, elem.DEFAULT_PT_FIRE)
				sim.pressure(x / 4, y / 4, sim.pressure(x / 4, y / 4) + 10)
				sim.partKill(i)
				return
			end
		else
			sim.partProperty(i, "tmp", 10 + math.random(20))
		end
	end
end)

elem.property(bgph, "Graphics", graphiteGraphics)


elem.property(elem.DEFAULT_PT_LAVA, "Update", function(i, x, y, s, n)

	local ctype = sim.partProperty(i, "ctype")

	if math.random(20000) == 1 then
		if ctype == grph then
			local pressure = simulation.pressure(x / 4, y / 4)
			local temp = sim.partProperty(i, "temp")
			if pressure >= 255 and temp >= 9999 then
				sim.partProperty(i, "ctype", elem.DEFAULT_PT_DMND)
			end
		end
	end

	if ctype == elem.DEFAULT_PT_IRON then
		if math.random(20) == 1 then
			local randomNeighbor = sim.pmap(x + math.random(5) - 3, y + math.random(5) - 3)
			if randomNeighbor ~= nil and sim.partProperty(randomNeighbor, "type") == grph then
				sim.partProperty(i, "ctype", elem.DEFAULT_PT_METL)
				sim.partChangeType(randomNeighbor, elem.DEFAULT_PT_BCOL)
			elseif randomNeighbor ~= nil and sim.partProperty(randomNeighbor, "type") == elem.DEFAULT_PT_LAVA and sim.partProperty(randomNeighbor, "ctype") == elem.DEFAULT_PT_PTNM then
				sim.partProperty(i, "ctype", mmry)
				sim.partProperty(randomNeighbor, "ctype", mmry)
			end
		end
	end

	if ctype == mmry then
		sim.partProperty(i, "tmp", x)
		sim.partProperty(i, "tmp2", y)
		-- print (x, y)
	end
end)

local waters = {
	[elem.DEFAULT_PT_WATR] = true,
	[elem.DEFAULT_PT_DSTW] = true,
	[elem.DEFAULT_PT_SLTW] = true,
	[elem.DEFAULT_PT_BUBW] = true,
	[elem.DEFAULT_PT_WTRV] = true,
	[elem.DEFAULT_PT_FRZZ] = true,
	[elem.DEFAULT_PT_FRZW] = true,
	[elem.DEFAULT_PT_ICEI] = true,
	[elem.DEFAULT_PT_SNOW] = true,
	[chlw] = true,
}

local mLavaNeutralizers = {
	[elem.DEFAULT_PT_FRZZ] = true,
	[elem.DEFAULT_PT_FRZW] = true,
	[elem.DEFAULT_PT_ICEI] = true,
	[elem.DEFAULT_PT_SNOW] = true,
}

local mLavaNeutralizersCtype = {
	[elem.DEFAULT_PT_ICEI] = true,
	[elem.DEFAULT_PT_SNOW] = true,
}

-- tmp: Heat factor. As it increases, heats up faster. Increases when chilled or melted.
-- tmp2: 0 if normal, 1 if neutralized. Cools down and no longer heats up if neutralized.
elem.element(melt, elem.element(elem.DEFAULT_PT_SAND))
elem.property(melt, "Name", "MELT")
elem.property(melt, "Description", "Melting powder. Rapidly boils water. Activated by cold or lava, causing it to heat up and convert molten materials.")
elem.property(melt, "Colour", 0xFBA153)
elem.property(melt, "MenuSection", elem.SC_POWDERS)
elem.property(melt, "Properties", elem.TYPE_PART)
elem.property(melt, "HeatConduct", 5)
elem.property(melt, "HighTemperature", 273.15 + 500)
elem.property(melt, "HighTemperatureTransition", mlva)

elem.property(melt, "Update", function(i, x, y, s, n)

	local tmp2 = sim.partProperty(i, "tmp2")

	if tmp2 == 1 then
		sim.partProperty(i, "tmp", 0)
		local temp = sim.partProperty(i, "temp")

		if temp > 273.15 + 400 then
			sim.partProperty(i, "temp", temp + 0.03 * (273.15 + 200 - temp))
		end

		local rx = x + math.random(3) - 2
		local ry = y + math.random(3) - 2
		
		if math.random(30) == 1 then
			local smoke = sim.partCreate(-1, rx, ry, elem.DEFAULT_PT_SMKE)
			sim.partProperty(smoke, "life", 240)
		end
	else
		local tmp = sim.partProperty(i, "tmp")

		local rx = x + math.random(3) - 2
		local ry = y + math.random(3) - 2
		local randomNeighbor = sim.pmap(rx, ry)
		if randomNeighbor ~= nil then
			local type = sim.partProperty(randomNeighbor, "type")
			if waters[type] then
				local temp = sim.partProperty(randomNeighbor, "temp")
				sim.partProperty(randomNeighbor, "temp", temp + 0.8 * (273.15 + 400 - temp))
			end

			if math.random(60) == 1 and type == elem.DEFAULT_PT_LAVA then
				sim.partProperty(i, "tmp", sim.partProperty(i, "tmp") + 1)
			end

			if sim.partProperty(randomNeighbor, "temp") > 273.15 and mLavaNeutralizers[type] then
				if mLavaNeutralizersCtype[type] then
					local ctype = sim.partProperty(randomNeighbor, "ctype")
					if mLavaNeutralizers[ctype] then
						sim.partChangeType(randomNeighbor, elem.DEFAULT_PT_WTRV)
					end
				else
					sim.partChangeType(randomNeighbor, elem.DEFAULT_PT_WTRV)
				end
			end
		elseif math.random(600) <= tmp then
			local smoke = sim.partCreate(-1, rx, ry, elem.DEFAULT_PT_SMKE)
			sim.partProperty(smoke, "life", 240)
		end

		if math.random(60) == 1 and sim.partProperty(i, "temp") < 273.15 - 40 and tmp < 100 then
			sim.partProperty(i, "tmp", sim.partProperty(i, "tmp") + 1)
		end

		sim.partProperty(i, "temp", sim.partProperty(i, "temp") + tmp / 4)

		if math.random() < sim.partProperty(i, "tmp") / 200 then
			sim.partChangeType(i, mlva)
		end
	end
end)

elem.property(melt, "Graphics", function (i, r, g, b)

	local tmp2 = sim.partProperty(i, "tmp2")

	local colr = r
	local colg = g
	local colb = b

	local firea = 0
	
	local pixel_mode = ren.PMODE_FLAT

	if tmp2 == 1 then
		colr, colg, colb = graphics.getColors(0x55B269)
	else
		local tmp = sim.partProperty(i, "tmp")
	
		if math.random(100) <= tmp then
			colr = 255
			colg = 255
			colb = 255
			firea = 100
			pixel_mode = ren.PMODE_FLAT + ren.PMODE_FLARE
		end
	end

	return 0,pixel_mode,255,colr,colg,colb,firea,colr,colg,colb;
end)


elem.element(mlva, elem.element(elem.DEFAULT_PT_LAVA))
elem.property(mlva, "Name", "MLVA")
elem.property(mlva, "Description", "Melting lava.")
elem.property(mlva, "Colour", 0xFF7F11)
elem.property(mlva, "MenuSection", -1)
elem.property(mlva, "Properties", elem.TYPE_LIQUID)
elem.property(mlva, "HeatConduct", 5)
elem.property(mlva, "Advection", 0.07)
-- elem.property(mlva, "LowTemperature", 273.15 + 500)
-- elem.property(mlva, "LowTemperatureTransition", melt)

function neutralizeMlva(x, y)

	local toNeutralize = sim.partNeighbours(x, y, 3, mlva)

	for k,d in pairs(toNeutralize) do 
		sim.partChangeType(d, melt)
		sim.partProperty(d, "tmp2", 1)
	end
end

elem.property(mlva, "Update", function(i, x, y, s, n)

	local tmp = sim.partProperty(i, "tmp")
	local temp = sim.partProperty(i, "temp")

	if math.random(10) == 1 and tmp < 100 then
		sim.partProperty(i, "tmp", sim.partProperty(i, "tmp") + 1)
	end

	if math.random(192) == 1 then
		sim.partChangeType(i, melt)
		sim.partProperty(i, "temp", temp + 200)
		return
	else
		sim.partProperty(i, "temp", temp + tmp / 4)
	end

	local rx = x + math.random(3) - 2
	local ry = y + math.random(3) - 2
	local randomNeighbor = sim.pmap(rx, ry)
	if randomNeighbor ~= nil then
		local type = sim.partProperty(randomNeighbor, "type")
		if math.random(50) == 1 then
			if type == elem.DEFAULT_PT_LAVA then
				sim.partProperty(randomNeighbor, "type", mlva)
			elseif elem.property(type, "HighTemperatureTransition") == elem.DEFAULT_PT_LAVA then
				sim.partProperty(randomNeighbor, "temp", sim.partProperty(randomNeighbor, "temp") + 500)
			end
		end

		if mLavaNeutralizers[type] then
			if mLavaNeutralizersCtype[type] then
				local ctype = sim.partProperty(randomNeighbor, "ctype")
				if mLavaNeutralizers[ctype] then
				end
			else
				sim.partChangeType(i, melt)
				sim.partProperty(i, "tmp2", 1)
			end
		end
	elseif math.random(600) <= tmp then
		local smoke = sim.partCreate(-1, rx, ry, elem.DEFAULT_PT_SMKE)
		sim.partProperty(smoke, "temp", temp)
		sim.partProperty(smoke, "life", 240)
	end
end)

elem.property(mlva, "Graphics", function (i, r, g, b)

	local colr = r
	local colg = g
	local colb = b

	local firea = 10
	
	local pixel_mode = ren.PMODE_FLAT + ren.FIRE_ADD + ren.PMODE_BLUR

	return 1,pixel_mode,255,colr,colg,colb,firea,colr,colg,colb;
end)

-- Life is unused for conduction reasons
-- pavg0: Returning coefficient. Increases when the particle is heated and not at its desired position, causing it to return to it.
-- tmp: Desired x position
-- tmp2: Desired y position
elem.element(mmry, elem.element(elem.DEFAULT_PT_GOO))
elem.property(mmry, "Name", "MEND")
elem.property(mmry, "Description", "Memory alloy. Deforms under pressure, but returns to its original shape when heated.")
elem.property(mmry, "Colour", 0x2F7457)
elem.property(mmry, "MenuSection", elem.SC_SOLIDS)
elem.property(mmry, "AirLoss", 0.99)
elem.property(mmry, "PhotonReflectWavelengths", 0xFFFFFFFF)
elem.property(mmry, "Properties", elem.TYPE_SOLID + elem.PROP_CONDUCTS + elem.PROP_HOT_GLOW + elem.PROP_LIFE_DEC)
elem.property(mmry, "HighTemperature", 273.15 + 1900)
elem.property(mmry, "HighTemperatureTransition", elem.DEFAULT_PT_LAVA)

elem.property(mmry, "Create", function(i, x, y, t, v)
	sim.partProperty(i, "tmp", x)
	sim.partProperty(i, "tmp2", y)
end)
elem.property(mmry, "Update", function(i, x, y, s, n)

	local velx = sim.velocityX(x / 4, y / 4)
	local vely = sim.velocityY(x / 4, y / 4)
	local temp = sim.partProperty(i, "temp")
	local returning = sim.partProperty(i, tmp3)

	if sim.partProperty(i, "life") > 0 then
		sim.pressure(x / sim.CELL, y / sim.CELL, sim.pressure(x / sim.CELL, y / sim.CELL) * 0.97)
	else
		sim.pressure(x / sim.CELL, y / sim.CELL, sim.pressure(x / sim.CELL, y / sim.CELL) * 0.8)
	end
	-- if (!parts[i].life && sim->pv[y/CELL][x/CELL]>1.0f)
	-- 	parts[i].life = RNG::Ref().between(300, 379);
	if math.sqrt(velx ^ 2 + vely ^ 2) > 0.1 then
		sim.partProperty(i, "vx", sim.partProperty(i, "vx") + 0.1 * velx)
		sim.partProperty(i, "vy", sim.partProperty(i, "vy") + 0.1 * vely)
	end
	local desx = sim.partProperty(i, "tmp")
	local desy = sim.partProperty(i, "tmp2")

	if round(x) - desx == 0 and round(y) - desy == 0 then
		sim.partProperty(i, tmp3, math.max(returning - 1, 0))
	elseif temp > 273.15 + 60 then
		sim.partProperty(i, "temp", temp + 0.002 * (-temp))
		sim.partProperty(i, tmp3, math.min(returning + 1, 30))
		sim.partProperty(i, "life", 30)
	else
		sim.partProperty(i, tmp3, math.max(returning - 1, 0))
		sim.partProperty(i, "life", 30)
	end

	-- Permanently deform at very high temperatures
	if temp > 273.15 + 1700 then
		sim.partProperty(i, "tmp", x)
		sim.partProperty(i, "tmp2", y)
	end
	
	local overheat = 1 - math.max(temp - 273.15 - 1000, 0) / 800
	local seek = returning / 300 * overheat
	sim.partProperty(i, "vx", sim.partProperty(i, "vx") + seek * (desx - x + (math.random() - 0.5) * 0.1))
	sim.partProperty(i, "vy", sim.partProperty(i, "vy") + seek * (desy - y + (math.random() - 0.5) * 0.1))

	if returning > 0 then sim.partProperty(i, "life", 30) end
end)

elem.property(mmry, "Graphics", function (i, r, g, b)

	local glow = sim.partProperty(i, tmp3) / 30
	local colr = r + 255 * glow
	local colg = g + 255 * glow
	local colb = b + 255 * glow

	local firea = 255 * glow
	
	local pixel_mode = ren.PMODE_FLAT
	if sim.partProperty(i, "temp") > 273.15 + 60 then
		pixel_mode = ren.PMODE_FLAT + ren.PMODE_FLARE
	end

	return 0,pixel_mode,255,colr,colg,colb,firea,colr,colg,colb;
end)

sim.can_move(mmry, mmry, 1)
-- sim.can_move(mmry, lava, 0)

-- -# means special interaction
local halogenReactions = {
	[elem.DEFAULT_PT_RBDM] = elem.DEFAULT_PT_SALT,
	[elem.DEFAULT_PT_LRBD] = elem.DEFAULT_PT_SALT,
	[elem.DEFAULT_PT_LITH] = elem.DEFAULT_PT_SALT,
	[elem.DEFAULT_PT_WATR] = chlw,
	[elem.DEFAULT_PT_DSTW] = chlw,
	[elem.DEFAULT_PT_SPRK] = -1,
	[elem.DEFAULT_PT_H2] = elem.DEFAULT_PT_CAUS, -- hydrochloric acid
	[elem.DEFAULT_PT_PTNM] = elem.DEFAULT_PT_ACID, -- chloroplatinic acid
	[elem.DEFAULT_PT_IRON] = -2,
	[elem.DEFAULT_PT_CO2] = elem.DEFAULT_PT_RFRG, -- chlorofluorocarbon
	[elem.DEFAULT_PT_SMKE] = elem.DEFAULT_PT_FIRE,
	[elem.DEFAULT_PT_COAL] = -3,
	[elem.DEFAULT_PT_BCOL] = -3,
	[elem.DEFAULT_PT_PLNT] = elem.DEFAULT_PT_DUST, -- fluoride is toxic to plants
	[elem.DEFAULT_PT_WOOD] = elem.DEFAULT_PT_GOO,
	[elem.DEFAULT_PT_GOO] = -4,
	[elem.DEFAULT_PT_YEST] = elem.DEFAULT_PT_DYST,
	[elem.DEFAULT_PT_DYST] = elem.DEFAULT_PT_DUST,
	[grph] = elem.DEFAULT_PT_COAL,
	[bgph] = elem.DEFAULT_PT_BCOL,
	[elem.DEFAULT_PT_FUSE] = -5,
	[elem.DEFAULT_PT_FSEP] = -5,
	[elem.DEFAULT_PT_THDR] = -6,
	[elem.DEFAULT_PT_LIGH] = -6,
}

local dontProduceHeat = {
	[elem.DEFAULT_PT_SPRK] = true,
	[elem.DEFAULT_PT_WATR] = true,
	[elem.DEFAULT_PT_DSTW] = true,
}

local noFire = {
	[elem.DEFAULT_PT_TUNG] = true,
	[chlw] = true,
	[lhal] = true,
	[halo] = true,
	[fhal] = true,
	[elem.DEFAULT_PT_DMND] = true,
	[elem.DEFAULT_PT_GLAS] = true,
	[elem.DEFAULT_PT_TTAN] = true,
	[elem.DEFAULT_PT_QRTZ] = true,
}

-- Only a small subset of elements can survive charged HALO so that making weapons isn't *too* difficult
local noPlasma = {
	[lhal] = true,
	[halo] = true,
	[fhal] = true,
	[elem.DEFAULT_PT_DMND] = true,
	[elem.DEFAULT_PT_PLSM] = true,
	[elem.DEFAULT_PT_FRME] = true,
	[elem.DEFAULT_PT_CLNE] = true,
	[elem.DEFAULT_PT_TESC] = true,
}

local halogenInteractions = {
	[-1] = function(a, b)
		if sim.partProperty(b, "ctype") == elem.DEFAULT_PT_TUNG then
			sim.partProperty(a, "life", 60)
		end
	end,
	[-2] = function(a, b)
		sim.partChangeType(b, elem.DEFAULT_PT_BMTL)
		sim.partProperty(b, "tmp", 1)
	end,
	[-3] = function(a, b)
		sim.partProperty(b, "life", sim.partProperty(b, "life") - 1)
	end,
	[-4] = function(a, b)
		if sim.partProperty(b, "life") == 0 then
			sim.partProperty(b, "life", 40)
		end
	end,
	[-5] = function(a, b)
		sim.partProperty(b, "life", sim.partProperty(b, "life") - 11)
	end,
	[-6] = function(a, b)
		sim.partProperty(a, "tmp", 240)
	end,
}

-- Takes characteristics from both fluorine and chlorine
-- life: Glowing effect, activated by sparking with TUNG
-- tmp: Whether "ionized" by lightning/thunder. Causes it to turn everything into PLSM
elem.element(halo, elem.element(elem.DEFAULT_PT_HYGN))
elem.property(halo, "Name", "HALO")
elem.property(halo, "Description", "Halogens. Reacts with alkali metals to produce SALT, kills STKM, chlorinates water, and damages most elements it touches.")
elem.property(halo, "Colour", 0xFEC06F)
elem.property(halo, "MenuSection", elem.SC_GASES)
elem.property(halo, "Properties", elem.TYPE_GAS + elem.PROP_DEADLY + elem.PROP_LIFE_DEC)
elem.property(halo, "HighPressure", 10)
elem.property(halo, "HighPressureTransition", lhal)
elem.property(halo, "LowTemperature", 112.57)
elem.property(halo, "LowTemperatureTransition", fhal)
elem.property(halo, "HotAir", 0.0006)
elem.property(halo, "Update", function(i, x, y, s, n)

	local tmp = sim.partProperty(i, "tmp")
	if tmp == 0 then
		local randomNeighbor = sim.pmap(x + math.random(-2, 2), y + math.random(-2, 2))
		if randomNeighbor ~= nil then
			local type = sim.partProperty(randomNeighbor, "type")
			local react = halogenReactions[type]
			if react ~= nil then
				if not dontProduceHeat[type] then
					sim.partProperty(i, "temp", sim.partProperty(i, "temp") + 100)
				end
				if react < 0 then
					halogenInteractions[react](i, randomNeighbor)
				else
					local cx, cy = sim.partPosition(randomNeighbor)
					local temp = sim.partProperty(randomNeighbor, "temp")
					cx = round(cx)
					cy = round(cy)
					sim.partKill(randomNeighbor)
					local new = sim.partCreate(-1, cx, cy, react)
					if new ~= -1 then
						if not dontProduceHeat[type] then
							sim.partProperty(new, "temp", temp + 50)
						end
						if math.random(1, 5) == 1 then
							sim.partKill(i)
						end
					end
				end
			elseif not noFire[type] and (elem.property(type, "Flammable") > 0 or bit.band(elem.property(type, "Properties"), elem.TYPE_LIQUID + elem.TYPE_PART + elem.TYPE_SOLID) ~= 0) then
				local rx = x + math.random(-1, 1)
				local ry = y + math.random(-1, 1)
				sim.partCreate(-1, rx, ry, elem.DEFAULT_PT_FIRE)
			end
		end
	else
		local randomNeighbor = sim.pmap(x + math.random(-2, 2), y + math.random(-2, 2))
		if randomNeighbor ~= nil then
			local type = sim.partProperty(randomNeighbor, "type")
			if not noPlasma[type] then
				sim.partChangeType(randomNeighbor, elem.DEFAULT_PT_PLSM)
				sim.partProperty(randomNeighbor, "temp", 10000)
			end
		end
		sim.pressure(x / sim.CELL, y / sim.CELL, sim.pressure(x / sim.CELL, y / sim.CELL) - 0.02)
		sim.partProperty(i, "tmp", sim.partProperty(i, "tmp") - 1)
	end

	
end)
elem.property(halo, "Graphics", function (i, r, g, b)

	local bright = sim.partProperty(i, "life") + sim.partProperty(i, "tmp")
	local colr = r + bright
	local colg = g + bright
	local colb = b + bright

	local firea = 120 + bright
	
	local pixel_mode = ren.FIRE_BLEND

	if bright > 0 then
		pixel_mode = ren.FIRE_BLEND + ren.PMODE_FLARE + ren.FIRE_ADD
	end

	local firer = r * (0.6 + bright / 60)
	local fireg = g * (0.6 + bright / 60)
	local fireb = b * (0.6 + bright / 60)

	return 0,pixel_mode,255,colr,colg,colb,firea,firer,fireg,fireb;
end)

elem.element(lhal, elem.element(elem.DEFAULT_PT_ACID))
elem.property(lhal, "Name", "LHAL")
elem.property(lhal, "Description", "Liquid halogens.")
elem.property(lhal, "Colour", 0xE2FC62)
elem.property(lhal, "Flammable", 0)
elem.property(lhal, "MenuSection", -1)
elem.property(lhal, "Properties", elem.TYPE_LIQUID + elem.PROP_DEADLY + elem.PROP_LIFE_DEC)
elem.property(lhal, "LowPressure", 10)
elem.property(lhal, "LowPressureTransition", halo)
elem.property(lhal, "LowTemperature", 112.57)
elem.property(lhal, "LowTemperatureTransition", fhal)
elem.property(lhal, "HotAir", -0.0004)

elem.element(fhal, elem.element(elem.DEFAULT_PT_NICE))
elem.property(fhal, "Name", "FHAL")
elem.property(fhal, "Description", "Frozen halogens.")
elem.property(fhal, "Colour", 0xF4F8A4)
elem.property(fhal, "MenuSection", -1)
elem.property(fhal, "Temperature", 102.57)
elem.property(fhal, "Properties", elem.TYPE_SOLID + elem.PROP_DEADLY + elem.PROP_LIFE_DEC)
elem.property(fhal, "HighPressure", 0)
elem.property(fhal, "HighPressureTransition", -1)
elem.property(fhal, "HighTemperature", 112.57)
elem.property(fhal, "HighTemperatureTransition", halo)
elem.property(fhal, "HotAir", -0.0004)

local chlwDissolve = {
	[elem.DEFAULT_PT_ROCK] = true,
	[elem.DEFAULT_PT_BRCK] = true,
	[elem.DEFAULT_PT_STNE] = true,
	[elem.DEFAULT_PT_CNCT] = true,
}

local chlwSpread = {
	[elem.DEFAULT_PT_WATR] = true,
	[elem.DEFAULT_PT_DSTW] = true,
	[elem.DEFAULT_PT_SLTW] = true,
	[elem.DEFAULT_PT_FRZW] = true,
}

elem.element(chlw, elem.element(elem.DEFAULT_PT_DSTW))
elem.property(chlw, "Name", "CHLW")
elem.property(chlw, "Description", "Chlorinated water. Kills PLNT and slowly dissolves rocky materials. Not conductive.")
elem.property(chlw, "Colour", 0x0851E5)
elem.property(chlw, "Weight", 31)
elem.property(chlw, "Properties", elem.TYPE_LIQUID)
elem.property(chlw, "Update", function(i, x, y, s, n)

	local r = sim.pmap(x + math.random(-2, 2), y + math.random(-2, 2))
	if r ~= nil then
		local type = sim.partProperty(r, "type")
		if math.random(200) == 1 and chlwDissolve[type] then
			sim.partKill(r)
			if math.random(10) == 1 then
				sim.partKill(i)
			end
		end

		if math.random(250) == 1 and chlwSpread[type] then
			sim.partChangeType(r, chlw)
		end

		if type == elem.DEFAULT_PT_PLNT then
			sim.partKill(r)
		end
	end
end)



-- https://www.gabrielgambetta.com/computer-graphics-from-scratch/07-filled-triangles.html
local function interpolate(i0, d0, i1, d1)
	if i0 == i1 then
	 	return { d0 }
	end
  
	local values = {}
	local a = (d1 - d0) / (i1 - i0)
	local d = d0
	for i = i0, i1 do
		table.insert(values, d)
	 	d = d + a
	end
  
	return values;
end

local function drawTriangle(x1, y1, x2, y2, x3, y3, r, g, b, a)
	if y2 < y1 then
		y2, x2, y1, x1 = y1, x1, y2, x2
	end
	if y3 < y1 then
		y3, x3, y1, x1 = y1, x1, y3, x3
	end
	if y3 < y2 then
		y2, x2, y3, x3 = y3, x3, y2, x2
	end
	
	local x01 = interpolate(y1, x1, y2, x2);
	local x12 = interpolate(y2, x2, y3, x3);
	local x02 = interpolate(y1, x1, y3, x3);

	-- Merge the two short sides.
	local x012 = {}
	for i=1,#x01 - 1 do
		table.insert(x012, x01[i])
	end
	for i=1,#x12 do
		table.insert(x012, x12[i])
	end

	for y = y1, y3 do
		graphics.drawLine(x012[y - y1 + 1], y, x02[y - y1 + 1], y, r, g, b, a)
	end
end

local nobiliStateColorMap = 
{
	0x303030, -- Ground state (will die next frame)

	0xFF0000, -- Sensitized S
	0xFF7D00, -- Sensitized S0
	0xFF9619, -- Sensitized S1
	0xFFAF00, -- Sensitized S00
	0xFFC84B, -- Sensitized S01
	0xFFFF64, -- Sensitized S10
	0xFFFA7D, -- Sensitized S11
	0xFBFF00, -- Sensitized S000

	0x5959FF, -- Ordinary transmission quiescent E (Right)
	0x6A6AFF, -- Ordinary transmission quiescent N (Up)
	0x7A7AFF, -- Ordinary transmission quiescent W (Left)
	0x8B8BFF, -- Ordinary transmission quiescent S (Down)

	0x1BB01B, -- Ordinary transmission excited E (Right)
	0x24C824, -- Ordinary transmission excited N (Up)
	0x49FF49, -- Ordinary transmission excited W (Left)
	0x6AFF6A, -- Ordinary transmission excited S (Down)

	0xEB2424, -- Special transmission quiescent E (Right)
	0xFF3838, -- Special transmission quiescent N (Up)
	0xFF4949, -- Special transmission quiescent W (Left)
	0xFF5959, -- Special transmission quiescent S (Down)

	0xB938FF, -- Special transmission excited E (Right)
	0xBF49FF, -- Special transmission excited N (Up)
	0xC559FF, -- Special transmission excited W (Left)
	0xCB6AFF, -- Special transmission excited S (Down)

	0x00FF0C, -- Confluent Quiescent 00
	0xFF8040, -- Confluent Next-Excited 00
	0xFFFF80, -- Confluent Excited 00
	0x21D7D7, -- Confluent Excited Next-Excited 00
	0x1BB0B0, -- Confluent Excited Horizontal
	0x189C9C, -- Confluent Excited Vertical
	0x158989, -- Confluent Excited Bidirectional
}

local simpleStateNames = {
	"Empty",

	"Sensitized S",
	"Sensitized S0",
	"Sensitized S1",
	"Sensitized S00",
	"Sensitized S01",
	"Sensitized S10",
	"Sensitized S11",
	"Sensitized S000",

	"Wire (uncharged, right)",
	"Wire (uncharged, up)",
	"Wire (uncharged, left)",
	"Wire (uncharged, down)",

	"Wire (charged, right)",
	"Wire (charged, up)",
	"Wire (charged, left)",
	"Wire (charged, down)",

	"Anti-Wire (uncharged, right)",
	"Anti-Wire (uncharged, up)",
	"Anti-Wire (uncharged, left)",
	"Anti-Wire (uncharged, down)",

	"Anti-Wire (charged, right)",
	"Anti-Wire (charged, up)",
	"Anti-Wire (charged, left)",
	"Anti-Wire (charged, down)",

	"Connector 00 (no charge)",
	"Connector 01 (charged next step)",
	"Connector 10 (charged this step)",
	"Connector 11 (charged both steps)",
	"Connector (horizontal charge)",
	"Connector (vertical charge)",
	"Connector (bidirectional charge)",
}

local nobiliBasicDrawFunctions = {
	diamond = function(x, y, size, r, g, b, a)
		drawTriangle(x + size / 2, y, x + 0.5, y + size / 2, x + size, y + size / 2, r, g, b, a)
		drawTriangle(x + size / 2, y + size, x, y + size / 2, x + size, y + size / 2, r, g, b, a)
	end,
	arrowUp = function(x, y, size, r, g, b, a)
		drawTriangle(x + size / 2, y, x, y + size / 2, x + size, y + size / 2, r, g, b, a)
		graphics.fillRect(x + size / 3 + 0.5, y + size / 2, size / 3 + 1, size / 2 + 1, r, g, b, a)
	end,
	arrowDown = function(x, y, size, r, g, b, a)
		drawTriangle(x + size / 2, y + size, x, y + size / 2, x + size, y + size / 2, r, g, b, a)
		graphics.fillRect(x + size / 3 + 0.5, y, size / 3 + 1, size / 2 + 1, r, g, b, a)
	end,
	arrowRight = function(x, y, size, r, g, b, a)
		drawTriangle(x + size / 2, y, x + size / 2, y + size, x + size, y + size / 2, r, g, b, a)
		graphics.fillRect(x, y + size / 3 + 0.5, size / 2 + 1, size / 3 + 1, r, g, b, a)
	end,
	arrowLeft = function(x, y, size, r, g, b, a)
		drawTriangle(x + size / 2, y, x + size / 2, y + size, x, y + size / 2, r, g, b, a)
		graphics.fillRect(x + size / 2, y + size / 3 + 0.5, size / 2 + 1, size / 3 + 1, r, g, b, a)
	end,

}

local nobiliStateDrawFunctions = {
	function(x, y, size, r, g, b, a)
		-- Draw nothing for ground state
	end, -- Ground state

	function(x, y, size, r, g, b, a)
		graphics.fillCircle(x + size / 2, y + size / 2, size / 2, size / 2, r, g, b, a)
	end, -- Sensitized S
	function(x, y, size, r, g, b, a)
		nobiliBasicDrawFunctions.diamond(x, y, size, r, g, b, a)
		graphics.drawLine(x, y + size / 2, x + size, y + size / 2, 0, 0, 0, a)
		graphics.drawLine(x + size / 2, y + size, x + size / 2, y + size / 2, 0, 0, 0, a)
	end, -- Sensitized S0
	function(x, y, size, r, g, b, a)
		nobiliBasicDrawFunctions.diamond(x, y, size, r, g, b, a)
		graphics.drawLine(x, y + size / 2, x + size, y + size / 2, 0, 0, 0, a)
		graphics.drawLine(x + size / 2, y, x + size / 2, y + size / 2, 0, 0, 0, a)
	end, -- Sensitized S1
	function(x, y, size, r, g, b, a)
		nobiliBasicDrawFunctions.diamond(x, y, size, r, g, b, a)
		graphics.fillRect(x, y + size / 2, size + 1, size / 2 + 1, r, g, b, a)
		graphics.drawLine(x, y + size / 2, x + size, y + size / 2, 0, 0, 0, a)
		graphics.drawLine(x + size / 2, y, x + size / 2, y + size, 0, 0, 0, a)
	end, -- Sensitized S00
	function(x, y, size, r, g, b, a)
		nobiliBasicDrawFunctions.diamond(x, y, size, r, g, b, a)
		graphics.fillRect(x + size / 2, y, size / 2 + 1, size / 2 + 1, r, g, b, a)
		graphics.fillRect(x, y + size / 2, size / 2 + 1, size / 2 + 1, r, g, b, a)
		graphics.drawLine(x, y + size / 2, x + size, y + size / 2, 0, 0, 0, a)
		graphics.drawLine(x + size / 2, y, x + size / 2, y + size, 0, 0, 0, a)
	end, -- Sensitized S01
	function(x, y, size, r, g, b, a)
		nobiliBasicDrawFunctions.diamond(x, y, size, r, g, b, a)
		graphics.fillRect(x, y, size / 2 + 1, size / 2 + 1, r, g, b, a)
		graphics.fillRect(x + size / 2, y + size / 2, size / 2 + 1, size / 2 + 1, r, g, b, a)
		graphics.drawLine(x, y + size / 2, x + size, y + size / 2, 0, 0, 0, a)
		graphics.drawLine(x + size / 2, y, x + size / 2, y + size, 0, 0, 0, a)
	end, -- Sensitized S10
	function(x, y, size, r, g, b, a)
		nobiliBasicDrawFunctions.diamond(x, y, size, r, g, b, a)
		graphics.fillRect(x, y, size + 1, size / 2, r, g, b, a)
		graphics.drawLine(x, y + size / 2, x + size, y + size / 2, 0, 0, 0, a)
		graphics.drawLine(x + size / 2, y, x + size / 2, y + size, 0, 0, 0, a)
	end, -- Sensitized S11
	function(x, y, size, r, g, b, a)
		nobiliBasicDrawFunctions.diamond(x, y, size, r, g, b, a)
		graphics.drawLine(x, y + size / 2, x + size, y + size / 2, 0, 0, 0, a)
		graphics.drawLine(x + size / 2, y, x + size / 2, y + size, 0, 0, 0, a)
	end, -- Sensitized S000

	nobiliBasicDrawFunctions.arrowRight, -- Ordinary transmission quiescent E (Right)
	nobiliBasicDrawFunctions.arrowUp, -- Ordinary transmission quiescent N (Up)
	nobiliBasicDrawFunctions.arrowLeft, -- Ordinary transmission quiescent W (Left)
	nobiliBasicDrawFunctions.arrowDown, -- Ordinary transmission quiescent S (Down)

	nobiliBasicDrawFunctions.arrowRight, -- Ordinary transmission excited E (Right)
	nobiliBasicDrawFunctions.arrowUp, -- Ordinary transmission excited N (Up)
	nobiliBasicDrawFunctions.arrowLeft, -- Ordinary transmission excited W (Left)
	nobiliBasicDrawFunctions.arrowDown, -- Ordinary transmission excited S (Down)

	nobiliBasicDrawFunctions.arrowRight, -- Special transmission quiescent E (Right)
	nobiliBasicDrawFunctions.arrowUp, -- Special transmission quiescent N (Up)
	nobiliBasicDrawFunctions.arrowLeft, -- Special transmission quiescent W (Left)
	nobiliBasicDrawFunctions.arrowDown, -- Special transmission quiescent S (Down)

	nobiliBasicDrawFunctions.arrowRight, -- Special transmission excited E (Right)
	nobiliBasicDrawFunctions.arrowUp, -- Special transmission excited N (Up)
	nobiliBasicDrawFunctions.arrowLeft, -- Special transmission excited W (Left)
	nobiliBasicDrawFunctions.arrowDown, -- Special transmission excited S (Down)

	function(x, y, size, r, g, b, a)
		nobiliBasicDrawFunctions.diamond(x, y, size, r, g, b, a)
		nobiliBasicDrawFunctions.diamond(x + size / 3, y + size / 3, size / 3, 0, 0, 0, a)
	end, -- Confluent Quiescent 00
	function(x, y, size, r, g, b, a)
		nobiliBasicDrawFunctions.diamond(x, y, size, r, g, b, a)
		nobiliBasicDrawFunctions.diamond(x + size / 3, y + size / 3, size / 3, 0, 0, 0, a)
	end, -- Confluent Next-Excited 01
	function(x, y, size, r, g, b, a)
		nobiliBasicDrawFunctions.diamond(x, y, size, r, g, b, a)
		graphics.fillRect(x + size / 3 + 0.5, y + size / 3 + 0.5, size / 3 + 1, size / 3 + 1, 0, 0, 0, a)
	end, -- Confluent Excited 10
	nobiliBasicDrawFunctions.diamond, -- Confluent Excited Next-Excited 11
	function(x, y, size, r, g, b, a)
		nobiliBasicDrawFunctions.diamond(x, y, size, r, g, b, a)
		graphics.drawLine(x + size / 2, y + size / 3, x + size / 2, y + size / 3 * 2, 0, 0, 0, a)
	end, -- Confluent Excited Horizontal
	function(x, y, size, r, g, b, a)
		nobiliBasicDrawFunctions.diamond(x, y, size, r, g, b, a)
		graphics.drawLine(x + size / 3, y + size / 2, x + size / 3 * 2, y + size / 2, 0, 0, 0, a)
	end, -- Confluent Excited Vertical
	function(x, y, size, r, g, b, a)
		nobiliBasicDrawFunctions.diamond(x, y, size, r, g, b, a)
		graphics.drawLine(x + size / 3, y + size / 3, x + size / 3 * 2, y + size / 3 * 2, 0, 0, 0, a)
		graphics.drawLine(x + size / 3 * 2, y + size / 3, x + size / 3, y + size / 3 * 2, 0, 0, 0, a)
	end, -- Confluent Excited Bidirectional
}

local vonNeumannNeighbors = {
	{1, 0}, -- Right
	{0, -1}, -- Up
	{-1, 0}, -- Left
	{0, 1}, -- Down
}

local vonNeumannComplement = {
	{-1, 0}, -- Left
	{0, 1}, -- Down
	{1, 0}, -- Right
	{0, -1}, -- Up
}

local directionComplement = {
	3,
	4,
	1,
	2,
}

-- Item 1 always dicatates the type of the state.
-- 0: Grounded
-- 1: Sensitized
-- 2: Transmission
-- 3: Confluent
local stateInfo = {
	{0}, -- No info about Ground State for you >:)

	-- For sensitized states, item 2 is next state if given no input and item 3 is next state if given an input
	{1, 2, 3}, -- State 1
	{1, 4, 5}, -- State 2
	{1, 6, 7}, -- State 3
	{1, 8, 11}, -- State 4
	{1, 12, 17}, -- State 5
	{1, 18, 19}, -- State 6
	{1, 20, 25}, -- State 7
	{1, 9, 10}, -- State 8

	-- For transmission states, item 2 indicates direction (1-4 for RULD) item 3 indicates activation, item 4 indicates specialness, 
	-- item 5 indicates excited equivalent and item 6 indicates quiescent equivalent (may self-reference)
	{2, 1, false, false, 13, 9}, -- State 9
	{2, 2, false, false, 14, 10}, -- State 10
	{2, 3, false, false, 15, 11}, -- State 11
	{2, 4, false, false, 16, 12}, -- State 12

	{2, 1, true, false, 13, 9}, -- State 13
	{2, 2, true, false, 14, 10}, -- State 14
	{2, 3, true, false, 15, 11}, -- State 15
	{2, 4, true, false, 16, 12}, -- State 16
	
	{2, 1, false, true, 21, 17}, -- State 17
	{2, 2, false, true, 22, 18}, -- State 18
	{2, 3, false, true, 23, 19}, -- State 19
	{2, 4, false, true, 24, 20}, -- State 20
	
	{2, 1, true, true, 21, 17}, -- State 21
	{2, 2, true, true, 22, 18}, -- State 22
	{2, 3, true, true, 23, 19}, -- State 23
	{2, 4, true, true, 24, 20}, -- State 24

	-- For confluent states, item 2 indicates if the cell will excite adjacent transmission cells. Item 3 indicates which state it will become if it is not excited,
	-- and item 4 indicates which state it will become if it is excited.
	{3, false, 25, 26}, -- State 25
	{3, false, 27, 28}, -- State 26
	{3, true, 25, 26}, -- State 27
	{3, true, 27, 28}, -- State 28

	-- Linear confluent states. Uses same scheme as normal confluent states, but with an additional 4 boolean values 6-9 that indicate whether or not the cell will
	-- excite transmitters do its RULD respectively. Uses 1 in item 5 to indicate special function.
	{3, true, 25, 25, 1, true, false, true, false}, -- State 29
	{3, true, 25, 25, 1, false, true, false, true}, -- State 30
	{3, true, 25, 25, 1, true, true, true, true}, -- State 31
}

local confluentBridgeDirectionMap = {
	[1] = 1,
	[2] = 2,
	[3] = 1,
	[4] = 2,
}

local confluentBridgeStateMap = {
	[0x0] = 25,
	[0x1] = 29,
	[0x2] = 30,
	[0x3] = 31,
}

local nobiliBrushState = 1

event.register(event.mousedown, function(x, y, button)
	if button == 2 then
		local ax, ay = sim.adjustCoords(x, y)
		local mp = sim.pmap(ax, ay)
		if mp then
			nobiliBrushState = sim.partProperty(mp, "life")
		end
	end
end)


-- Nobili 32
-- life: Current state
-- tmp: Previous state (used to prevent unwanted subframe interactions)
-- tmp2: Set to 1 if this particle should not update this frame (see above parenthetical)
elem.element(no32, elem.element(elem.DEFAULT_PT_DMND))
elem.property(no32, "Name", "NO32")
elem.property(no32, "Description", "Nobili 32. Complex cellular automaton. Use CTRL+S while selected to pick states.")
elem.property(no32, "Colour", 0x6A6AFF)
elem.property(no32, "MenuSection", elem.SC_LIFE)

elem.property(no32, "CreateAllowed", function(p, x, y, t)
	if p == -2 then
		local i = sim.partCreate(-1, x, y, no32) -- User palette choice
		sim.partProperty(i, "life", nobiliBrushState)
		return false
	end
	return true
end)

elem.property(no32, "CtypeDraw", function(i, t)
	if t == elem.DEFAULT_PT_SPRK then
		local state = sim.partProperty(i, "life")
		local info = stateInfo[state + 1]
		if info[1] == 2 then -- Activate transmitter cells when sparked with the brush
			sim.partProperty(i, "life", info[5])
		end
	end
end)

elem.property(no32, "Create", function(i, x, y, t, v)
	sim.partProperty(i, "life", 1) -- Is now Sensitized S
	sim.partProperty(i, "tmp", 0) -- Used to be Ground
end)

elem.property(no32, "Update", function(i, x, y, s, n)
	if sim.partProperty(i, "tmp2") == 1 then
		sim.partProperty(i, "tmp2", 0)
		return
	end

	local state = sim.partProperty(i, "life")
	local info = stateInfo[state + 1]

	if not info then 
		sim.partProperty(i, "life", 0) -- Become grounded if in an invalid state
		state = sim.partProperty(i, "life")
		info = stateInfo[state + 1]
	end

	sim.partProperty(i, "tmp", state)

	local inputOrdinaryExcited = 0
	local inputOrdinaryQuiescent = 0
	local inputSpecialExcited = 0
	local confluentOutputs = 0
	local confluentDirectionSum = 0
	local confluentDirectionSumTotal = 0
	local oppositeAttacking = 0

	local transmitterConduct = false
	local transmitterDestroy = false

	for k,l in pairs(vonNeumannNeighbors) do
		local n = sim.pmap(x + l[1], y + l[2])

		if n then
			if info[1] == 2 then -- Am I a transmitter?
				if sim.partProperty(n, "type") == elem.DEFAULT_PT_SPRK and sim.partProperty(n, "ctype") == elem.DEFAULT_PT_PSCN 
				and sim.partProperty(n, "life") == 3 and k ~= info[2] then -- Am I next to SPRK(PSCN) with a life of 3 and not facing towards it?
					transmitterConduct = true
				elseif info[3] and sim.partProperty(n, "life") == 0 and k == info[2] then -- Am I facing towards a particle with a life of 0?
					sim.partCreate(-1, x + l[1], y + l[2], elem.DEFAULT_PT_SPRK) -- Attempt to spark it
				end
			end

			-- print("Brogle", n, sim.partProperty(n, "tmp2"), sim.partProperty(n, "type"))
			if sim.partProperty(n, "tmp2") == 1 or sim.partProperty(n, "type") ~= no32 then
				goto loopFinish
			end
			-- print(n) 
			local nState
			if n > i then
				--print(n, k)
				nState = sim.partProperty(n, "life")
			else
				--print(n, k)
				nState = sim.partProperty(n, "tmp")
			end

			if nState ~= 0 and stateInfo[nState + 1] then
				local nInfo = stateInfo[nState + 1]
				if nInfo[1] == 2 and nInfo[2] == directionComplement[k] then -- Is there a transmitter facing towards me?

					if info[1] == 3 then -- Am I a confluent?
						confluentDirectionSumTotal = confluentDirectionSumTotal + k
						if info[1] == 3 and nInfo[3] then -- Am I a confluent and is the transmitter excited?
							confluentDirectionSum = confluentDirectionSum + confluentBridgeDirectionMap[nInfo[2]]
						end
					end

					if nInfo[2] ~= directionComplement[info[2]] and nInfo[3] then -- Am I not facing it?
						if info[4] == nInfo[4] then
							transmitterConduct = true
						else
						end
					end

					if info[4] ~= nInfo[4] and nInfo[3] then -- Is it powered and the opposite specialness as me?
						transmitterDestroy = true
					end

					if nInfo[4] then -- Is the transmitter special?
						if nInfo[3] then -- Is it excited?
							inputSpecialExcited = inputSpecialExcited + 1
						end
					else -- Is it ordinary?
						if nInfo[3] then -- Is it excited?
							inputOrdinaryExcited = inputOrdinaryExcited + 1
						else
							inputOrdinaryQuiescent = inputOrdinaryQuiescent + 1
						end
					end
				end

				if info[1] == 3 and nInfo[1] == 2 and k ~= directionComplement[nInfo[2]] then -- Am I a confluent next to a transmitter that is not facing towards me?
					confluentOutputs = confluentOutputs + 1
					-- if nInfo[2] then
					-- 	transmitterConduct = true
					-- end
				end

				if info[1] == 2 and nInfo[1] == 3 and k ~= info[2] then -- Am I a transmitter next to a confluent and not facing towards it?
					if nInfo[5] then -- Is this a bridge confluent?
						transmitterConduct = nInfo[5 + k]
					elseif nInfo[2] then
						transmitterConduct = true
					end
				end


				goto loopFinish
			end
		else
			-- Will only end up here if there is no particle
			if info[1] == 2 and info[3] and info[2] == k then -- Am I an excited transmitter pointing in this direction?
				local s = sim.partCreate(-1, x + l[1], y + l[2], no32)
				if s > i then
					sim.partProperty(s, "tmp2", 1)
				end
			end
		end

		
	
		::loopFinish::
	end

	if info[1] == 0 then
		if inputOrdinaryExcited > 0 or inputSpecialExcited > 0 then -- Am I recieving an input from an excited transmitter?
			sim.partProperty(i, "life", 1) -- Return from grounded to sensitized
		end
	elseif info[1] == 1 then -- Am I a sensitized cell?
		if inputOrdinaryExcited > 0 or inputSpecialExcited > 0 then -- Am I recieving an input from an excited transmitter?
			sim.partProperty(i, "life", info[3])
		else
			sim.partProperty(i, "life", info[2])
		end
	elseif info[1] == 2 then -- Am I a transmitter cell?
		if transmitterDestroy then
		-- if (info[4] and inputOrdinaryExcited > 0) or (not info[4] and inputSpecialExcited > 0) then
			sim.partProperty(i, "life", 0) -- Ground
		elseif transmitterConduct then
		-- elseif info[4] and inputSpecialExcited > 0 or not info[4] and inputOrdinaryExcited > 0 then
			sim.partProperty(i, "life", info[5])
		else
			sim.partProperty(i, "life", info[6])
		end
	elseif info[1] == 3 then -- Am I a confluent cell?
		if inputSpecialExcited > 0 then
			sim.partProperty(i, "life", 0) -- Ground
		elseif confluentDirectionSumTotal % 2 == 1 and inputOrdinaryExcited + inputOrdinaryQuiescent == 2 and confluentOutputs == 2 then -- Should I act like a bridge cell?
			sim.partProperty(i, "life", confluentBridgeStateMap[confluentDirectionSum])
		else
			if inputOrdinaryExcited > 0 and inputOrdinaryQuiescent == 0 then -- Only activate if all inputs are excited
				sim.partProperty(i, "life", info[4])
			elseif confluentOutputs > 0 then -- Memory behavior
				sim.partProperty(i, "life", info[3])
			end
		end

	end

	if sim.partProperty(i, "life") == 0 and state == 0 then -- Did I start and end this frame in ground-state?
		sim.partKill(i) -- DIE!
		return
	end
end)
elem.property(no32, "Graphics", function (i, r, g, b)
	local state = sim.partProperty(i, "life") + 1
	local colr, colg, colb = graphics.getColors(nobiliStateColorMap[state])
	local pixel_mode = ren.PMODE_FLAT
	return 0,pixel_mode,255,colr,colg,colb,0,0,0,0;
end)

event.register(event.tick, function()
	-- drawTriangle(1, 1, 2, 1, 1, 2, 255, 255, 255, 255)
	local zoomEnabled = ren.zoomEnabled()
	if zoomEnabled then
		local zoomX, zoomY, zoomPixels = ren.zoomScope()
		local zWinX, zWinY, zWinPxSize, zWinSize = ren.zoomWindow()
	
		local drawSize = zWinPxSize
		if drawSize % 2 == 1 then
			drawSize = drawSize + 1 -- Prevent odd numbers making the shapes look lopsided
		end
		if drawSize < 8 then
			return
		end

		for i = 0, zoomPixels - 1 do
			for j = 0, zoomPixels - 1 do
				local part = sim.partID(i + zoomX, j + zoomY)

				if part and sim.partProperty(part, "type") == no32 then
					local state = sim.partProperty(part, "life") + 1
					local colr, colg, colb = graphics.getColors(nobiliStateColorMap[state])
					local originX = zWinX + zWinPxSize * i
					local originY = zWinY + zWinPxSize * j
					graphics.fillRect(originX, originY, zWinPxSize, zWinPxSize, 0, 0, 0, 255)
					if nobiliStateDrawFunctions[state] then
						nobiliStateDrawFunctions[state](originX, originY, drawSize - 2, colr, colg, colb)
					else
						drawTriangle(originX, originY, originX + drawSize - 2, originY, originX, originY + drawSize - 2, colr, colg, colb, 255)
					end
				end
			end
		end
	end
end)  

local stateScreenShapes = {}

local function createAndAddStateButton(x, y, wx, wy, state, window)
	-- local stateButton = Button:new(x, y, 15, 15, "")
	-- stateButton:action(
	-- 	function()
	-- 	interface.closeWindow(window)
	-- end)
	-- stateButton:visible(true)
	-- window:addComponent(stateButton)
	local colr, colg, colb = graphics.getColors(nobiliStateColorMap[state + 1])
	table.insert(stateScreenShapes, {state, wx + x, wy + y, colr, colg, colb, 255})
end


event.register(event.keypress, function(key, scan, rep, shift, ctrl, alt)
	if ctrl and tpt.selectedl == "FANMOD_PT_NO32" and key == 115 then -- S 
		local stateSelectWindow = Window:new(-1, -1, 200, 200)

		local titleLabel = Label:new(0, 0, 200, 16, "Nobili32 State Select")
		stateSelectWindow:addComponent(titleLabel)
	
		local buttonSize = 14
		local hBS = buttonSize / 2
		stateScreenShapes = {}
		
		local wx, wy = stateSelectWindow:size()
		local adjX, adjY = (graphics.WIDTH - wx) / 2, (graphics.HEIGHT - wy) / 2

		createAndAddStateButton(100 - hBS, 30 - hBS, adjX, adjY, 1, stateSelectWindow)

		createAndAddStateButton(60 - hBS, 50 - hBS, adjX, adjY, 2, stateSelectWindow)
		createAndAddStateButton(140 - hBS, 50 - hBS, adjX, adjY, 3, stateSelectWindow)

		createAndAddStateButton(40 - hBS, 70 - hBS, adjX, adjY, 4, stateSelectWindow)
		createAndAddStateButton(80 - hBS, 70 - hBS, adjX, adjY, 5, stateSelectWindow)
		createAndAddStateButton(120 - hBS, 70 - hBS, adjX, adjY, 6, stateSelectWindow)
		createAndAddStateButton(160 - hBS, 70 - hBS, adjX, adjY, 7, stateSelectWindow)

		createAndAddStateButton(30 - hBS, 95 - hBS, adjX, adjY, 8, stateSelectWindow)

		createAndAddStateButton(20 - hBS, 120 - hBS, adjX, adjY, 9, stateSelectWindow)
		createAndAddStateButton(40 - hBS, 120 - hBS, adjX, adjY, 10, stateSelectWindow)
		createAndAddStateButton(60 - hBS, 120 - hBS, adjX, adjY, 11, stateSelectWindow)
		createAndAddStateButton(80 - hBS, 120 - hBS, adjX, adjY, 12, stateSelectWindow)
		createAndAddStateButton(100 - hBS, 120 - hBS, adjX, adjY, 17, stateSelectWindow)
		createAndAddStateButton(120 - hBS, 120 - hBS, adjX, adjY, 18, stateSelectWindow)
		createAndAddStateButton(140 - hBS, 120 - hBS, adjX, adjY, 19, stateSelectWindow)
		createAndAddStateButton(160 - hBS, 120 - hBS, adjX, adjY, 20, stateSelectWindow)

		createAndAddStateButton(180 - hBS, 120 - hBS, adjX, adjY, 25, stateSelectWindow)
		createAndAddStateButton(180 - hBS, 140 - hBS, adjX, adjY, 26, stateSelectWindow)
		createAndAddStateButton(180 - hBS, 160 - hBS, adjX, adjY, 27, stateSelectWindow)
		createAndAddStateButton(180 - hBS, 180 - hBS, adjX, adjY, 28, stateSelectWindow)

		createAndAddStateButton(20 - hBS, 140 - hBS, adjX, adjY, 13, stateSelectWindow)
		createAndAddStateButton(40 - hBS, 140 - hBS, adjX, adjY, 14, stateSelectWindow)
		createAndAddStateButton(60 - hBS, 140 - hBS, adjX, adjY, 15, stateSelectWindow)
		createAndAddStateButton(80 - hBS, 140 - hBS, adjX, adjY, 16, stateSelectWindow)
		createAndAddStateButton(100 - hBS, 140 - hBS, adjX, adjY, 21, stateSelectWindow)
		createAndAddStateButton(120 - hBS, 140 - hBS, adjX, adjY, 22, stateSelectWindow)
		createAndAddStateButton(140 - hBS, 140 - hBS, adjX, adjY, 23, stateSelectWindow)
		createAndAddStateButton(160 - hBS, 140 - hBS, adjX, adjY, 24, stateSelectWindow)
		
		createAndAddStateButton(60 - hBS, 180 - hBS, adjX, adjY, 29, stateSelectWindow)
		createAndAddStateButton(100 - hBS, 180 - hBS, adjX, adjY, 30, stateSelectWindow)
		createAndAddStateButton(140 - hBS, 180 - hBS, adjX, adjY, 31, stateSelectWindow)
		
		stateSelectWindow:onDraw(function()
			graphics.drawLine(100 + adjX, 15 + adjY, 100 + adjX, 30 + adjY, 0, 255, 0, 255)

			graphics.drawLine(100 + adjX, 30 + adjY, 60 + adjX, 50 + adjY, 0, 0, 255, 255)
			graphics.drawLine(100 + adjX, 30 + adjY, 140 + adjX, 50 + adjY, 0, 255, 0, 255)

			graphics.drawLine(60 + adjX, 50 + adjY, 40 + adjX, 70 + adjY, 0, 0, 255, 255)
			graphics.drawLine(60 + adjX, 50 + adjY, 80 + adjX, 70 + adjY, 0, 255, 0, 255)
			graphics.drawLine(140 + adjX, 50 + adjY, 120 + adjX, 70 + adjY, 0, 0, 255, 255)
			graphics.drawLine(140 + adjX, 50 + adjY, 160 + adjX, 70 + adjY, 0, 255, 0, 255)

			graphics.drawLine(40 + adjX, 70 + adjY, 30 + adjX, 95 + adjY, 0, 0, 255, 255)
			graphics.drawLine(40 + adjX, 70 + adjY, 60 + adjX, 120 + adjY, 0, 255, 0, 255)
			graphics.drawLine(80 + adjX, 70 + adjY, 80 + adjX, 120 + adjY, 0, 0, 255, 255)
			graphics.drawLine(80 + adjX, 70 + adjY, 100 + adjX, 120 + adjY, 0, 255, 0, 255)
			graphics.drawLine(120 + adjX, 70 + adjY, 120 + adjX, 120 + adjY, 0, 0, 255, 255)
			graphics.drawLine(120 + adjX, 70 + adjY, 140 + adjX, 120 + adjY, 0, 255, 0, 255)
			graphics.drawLine(160 + adjX, 70 + adjY, 160 + adjX, 120 + adjY, 0, 0, 255, 255)
			graphics.drawLine(160 + adjX, 70 + adjY, 180 + adjX, 120 + adjY, 0, 255, 0, 255)

			graphics.drawLine(30 + adjX, 95 + adjY, 20 + adjX, 120 + adjY, 0, 0, 255, 255)
			graphics.drawLine(30 + adjX, 95 + adjY, 40 + adjX, 120 + adjY, 0, 255, 0, 255)



			for i,j in pairs(stateScreenShapes) do
				nobiliStateDrawFunctions[j[1] + 1](j[2], j[3], buttonSize, j[4], j[5], j[6], j[7])
			end
		end)
	
		stateSelectWindow:onMouseDown(function(x, y, button)
			for i,j in pairs(stateScreenShapes) do
				bx = j[2]
				by = j[3]
				local bw, bh = buttonSize, buttonSize
				if x >= bx and y >= by and x <= bx + bw and y <= by + bh then
					nobiliBrushState = j[1]
					interface.closeWindow(stateSelectWindow)
					break
				end
			end
		
		end)

		stateSelectWindow:onMouseMove(function(x, y, dx, dy)
			for i,j in pairs(stateScreenShapes) do
				bx = j[2]
				by = j[3]
				local bw, bh = buttonSize, buttonSize
				if x >= bx and y >= by and x <= bx + bw and y <= by + bh then
					titleLabel:text(simpleStateNames[j[1] + 1])
					break
				end
				titleLabel:text("Nobili32 State Select")
			end
		
		end)

	
		interface.showWindow(stateSelectWindow)
		stateSelectWindow:onTryExit(function()
			interface.closeWindow(stateSelectWindow)
		end)
		return false
	end
end)  

local basicDirectionTable = {
	{225, 180, 135},
	{270, 0, 90},
	{315, 0, 45},
} 

elem.element(lncr, elem.element(elem.DEFAULT_PT_CLNE))
elem.property(lncr, "Name", "LNCR")
elem.property(lncr, "Description", "Launcher. Shift+click and drag on a launcher to set its power and angle.")
elem.property(lncr, "Colour", 0x3B84DF)
elem.property(lncr, "HeatConduct", 0)
elem.property(lncr, "Hardness", 0)
elem.property(lncr, "MenuSection", elem.SC_FORCE)
elem.property(lncr, "Properties", elem.TYPE_SOLID + elem.PROP_NOCTYPEDRAW + elem.PROP_NOAMBHEAT)

elem.property(lncr, "Create", function(i, x, y, t, v)
	sim.partProperty(i, "life", 361)
end)

elem.property(lncr, "Update", function(i, x, y, s, n)
	for cx = -1, 1 do
		for cy = -1, 1 do
			local id = sim.partID(x + cx, y + cy)
			if id ~= nil then
				if sim.partProperty(id, "type") == elem.DEFAULT_PT_SPRK and sim.partProperty(id, "life") == 3 then
					local ctype = sim.partProperty(i, "ctype")
					if ctype ~= 0 then
						local angleVar = sim.partProperty(i, "tmp")
						local life = sim.partProperty(i, "life")

						local angle
						if life <= 360 then
							angle = life + math.random(-angleVar, angleVar) / 2
						else
							angle = basicDirectionTable[-cy + 2][-cx + 2] + math.random(-angleVar, angleVar) / 2
						end
						local speed = (sim.partProperty(i, "temp") - 273.15) / 10
						local fvx, fvy = math.sin(angle / 360 * math.pi * 2), math.cos(angle / 360 * math.pi * 2)
						local launched = sim.partCreate(-1, x + fvx * 3 + 0.5, y + fvy * 3 + 0.5, ctype)
						sim.partProperty(launched, "vx", fvx * speed)
						sim.partProperty(launched, "vy", fvy * speed)
					end
				end
			end
		end
	end
end)

local launcherConfigActive = false
local launcherConfigID = -1

local launcherLogIncrement = 0.05
local launcherVisualIncrement = 0.02

elem.property(lncr, "Graphics", function (i, r, g, b)
	local x, y = sim.partPosition(i)
	local mx, my = sim.adjustCoords(tpt.mousex, tpt.mousey)
	if i == launcherConfigID or (x == mx and y == my and i ~= launcherConfigID) then
		local x, y = sim.partPosition(i)
		local mx, my = sim.adjustCoords(tpt.mousex, tpt.mousey)

		local temp = math.max(sim.partProperty(i, "temp") - 273.15, 0)
		local life = sim.partProperty(i, "life")
		local tmp = sim.partProperty(i, "tmp") / 2

		local maxRingRadius


		local att = 0
		local cval = temp
		while cval > 1 and att < 20 do
			local maxRing = cval + 273.15 >= 10000 - 1
			local radius = math.log(cval, 1 + launcherVisualIncrement) ^ 0.3 * 8
			if not maxRingRadius then maxRingRadius = radius end
			graphics.drawCircle(x, y, radius, radius, 255, maxRing and 0 or 255, maxRing and 0 or 255, 100)
			cval = (1 + launcherVisualIncrement) ^ (math.log(cval, 1 + launcherVisualIncrement) - 50)
			att = att + 1
		end
		
		if not maxRingRadius or maxRingRadius < 10 then
			maxRingRadius = 10
		end

		maxRingRadius = maxRingRadius - 1

		graphics.drawLine(x, y, x + math.sin((life + tmp) * math.pi / 180) * maxRingRadius, y + math.cos((life + tmp) * math.pi / 180) * maxRingRadius, 255, 255, 255, 50)
		graphics.drawLine(x, y, x + math.sin((life - tmp) * math.pi / 180) * maxRingRadius, y + math.cos((life - tmp) * math.pi / 180) * maxRingRadius, 255, 255, 255, 50)
		
		graphics.drawLine(x, y, mx, my, 255, 255, 255, 150)


		graphics.drawText(x + 3, y + 3, (life == 361 and "+" or math.floor(life)) .. "°", 255, 255, 255, 255)

	end
	return 0,pixel_mode,255,r,g,b,0,0,0,0;
end)

event.register(event.mousedown, function(x, y, button)
	local underMouse = sim.pmap(sim.adjustCoords(x, y))
	if shiftHeld and underMouse and sim.partProperty(underMouse, "type") == lncr then
		launcherConfigActive = true
		launcherConfigID = underMouse
		return false
	end
end)

event.register(event.mousemove, function(x, y, button)
	if launcherConfigActive then
		local px, py = sim.partPosition(launcherConfigID)
		local mx, my = sim.adjustCoords(x, y)

		local life

		if mx == px and my == py then
			life = 361
		else
			life = (math.atan2(mx - px, my - py) / (math.pi * 2) * 360) % 360
		end

		sim.partProperty(launcherConfigID, "life", life)
	end
end)

event.register(event.mousewheel, function(x, y, scroll)
	if launcherConfigActive then
		if shiftHeld then
			sim.partProperty(launcherConfigID, "temp", math.max((sim.partProperty(launcherConfigID, "temp") - 273.15) * (1 + scroll * launcherLogIncrement), 1) + 273.15)
		else
			sim.partProperty(launcherConfigID, "tmp", math.min(math.max(sim.partProperty(launcherConfigID, "tmp") + scroll, 0), 360))
		end
		return false
	end
end)

event.register(event.mouseup, function(x, y, button)
	if launcherConfigActive then
		launcherConfigActive = false
		launcherConfigID = -1
	end
end)

elem.property(lncr, "CtypeDraw", function(i, t)
	if bit.band( elem.property(t, "Properties"), elem.PROP_NOCTYPEDRAW) == 0 then
		sim.partProperty(i, "ctype", t)
	end
end)

local bulletImmune = {
	[elem.DEFAULT_PT_DMND] = true,
	[elem.DEFAULT_PT_VIBR] = true,
	[elem.DEFAULT_PT_CLNE] = true,
	[elem.DEFAULT_PT_PCLN] = true,
	[shot] = true,
}

-- Bullet type format:
-- kill, temp, pressure, life, tmp, tmp2, radius, convert mode
-- Set pressure/temp to nil to use default scaling, -1 to use element default
local bulletDefault = {false, -1, 1, nil, nil, nil, 3}

local bulletTypeInfo = {
	[elem.DEFAULT_PT_EMBR] = {true, nil, nil, 50, 0, 0, 2},
	[elem.DEFAULT_PT_FIRE] = {false, nil, nil, nil, nil, nil, 3},
	[elem.DEFAULT_PT_PLSM] = {false, nil, nil, nil, nil, nil, 3},
	[elem.DEFAULT_PT_LAVA] = {false, nil, nil, nil, nil, nil, 3},

	[elem.DEFAULT_PT_THDR] = {true, nil, nil, nil, nil, nil, 1},
	[elem.DEFAULT_PT_BOMB] = {true, nil, nil, nil, nil, nil, 1},
	[elem.DEFAULT_PT_DEST] = {true, nil, -30, 30, nil, nil, 2},
	[elem.DEFAULT_PT_DMG] = {true, nil, nil, nil, nil, nil, 1},
	[elem.DEFAULT_PT_GBMB] = {true, nil, nil, 60, nil, nil, 2},
	[elem.DEFAULT_PT_VIBR] = {true, nil, nil, 2, 0, nil, 2},
	[elem.DEFAULT_PT_BVBR] = {true, nil, nil, 2, 0, nil, 2},
	[elem.DEFAULT_PT_SING] = {true, nil, nil, 0, 100, nil, 2},
	[elem.DEFAULT_PT_COAL] = {true, nil, nil, 99, nil, nil, 3},
	[elem.DEFAULT_PT_BCOL] = {true, nil, nil, 99, nil, nil, 3},
	[elem.DEFAULT_PT_HYGN] = {true, 10000, 256, nil, nil, nil, 10}, -- FUSION

	[elem.DEFAULT_PT_FWRK] = {true, nil, nil, 2, nil, nil, 2},
	[elem.DEFAULT_PT_FIRW] = {true, nil, nil, nil, 2, nil, 2},

	[elem.DEFAULT_PT_FUSE] = {false, nil, nil, 39, nil, nil, 5},
	[elem.DEFAULT_PT_FSEP] = {false, nil, nil, 39, nil, nil, 5},

	[elem.DEFAULT_PT_DEUT] = {false, nil, nil, 300, nil, nil, 2},
	[elem.DEFAULT_PT_MERC] = {false, nil, nil, nil, 300, nil, 2},
	
	[elem.DEFAULT_PT_GOLD] = {true, 295.15, nil, nil, nil, nil, 4, true},
	[elem.DEFAULT_PT_AMTR] = {true, nil, nil, nil, nil, nil, 4, true},
	
	[elem.DEFAULT_PT_SPNG] = {false, 295.15, nil, 100, nil, nil, 4},

	[elem.DEFAULT_PT_URAN] = {true, 10000, nil, nil, nil, nil, 2},

	[elem.DEFAULT_PT_BHOL] = {true, nil, -1000, nil, nil, nil, 0},
	[elem.DEFAULT_PT_WHOL] = {true, nil, 1000, nil, nil, nil, 0},
	
	[elem.DEFAULT_PT_PHOT] = {false, nil, nil, nil, nil, nil, 6},
	[elem.DEFAULT_PT_PROT] = {false, nil, nil, nil, nil, nil, 6},
	[elem.DEFAULT_PT_ELEC] = {false, nil, nil, nil, nil, nil, 6},
	[elem.DEFAULT_PT_GRVT] = {false, nil, nil, nil, nil, nil, 6},
	[elem.DEFAULT_PT_NEUT] = {false, nil, nil, nil, nil, nil, 6},

	[elem.DEFAULT_PT_VOID] = {true, nil, nil, nil, nil, nil, 15},
	[elem.DEFAULT_PT_DMND] = {true, nil, nil, nil, nil, nil, 3},
}

local bulletTypeFunctions = {
	[elem.DEFAULT_PT_DRAY] = function(i)
		if math.random() > 0.5 then -- DRAY bomb
			sim.partProperty(i, "type", elem.DEFAULT_PT_SPRK)
			sim.partProperty(i, "ctype", elem.DEFAULT_PT_METL)
			sim.partProperty(i, "life", 4)
		end
	end,
	[elem.DEFAULT_PT_DMND] = function(i)
		sim.partKill(i)
	end,
	[elem.DEFAULT_PT_VOID] = function(i)
		sim.partKill(i)
	end,
}

elem.element(shot, elem.element(elem.DEFAULT_PT_CNCT))
elem.property(shot, "Name", "AMMO")
elem.property(shot, "Description", "Bullet. Damages materials, but must be accelerated to high speeds first.")
elem.property(shot, "Colour", 0xFDC43F)
elem.property(shot, "Collision", 0)
elem.property(shot, "Loss", 0.99)
elem.property(shot, "Gravity", 0.7)
elem.property(shot, "HighTemperatureTransition", -1)
elem.property(shot, "MenuSection", elem.SC_EXPLOSIVE)
elem.property(shot, "Update", function(i, x, y, s, n)
	if sim.partProperty(i, "life") == -1 then
		sim.partKill(i)
		return
	end

	local vx = sim.partProperty(i, "vx")
	local vy = sim.partProperty(i, "vy")
	local pvx = sim.partProperty(i, "tmp") / 100
	local pvy = sim.partProperty(i, "tmp2") / 100
	local v = math.sqrt(vx ^ 2 + vy ^ 2)
	local pv = math.sqrt(pvx ^ 2 + pvy ^ 2)

	sim.partProperty(i, "life", v)
	sim.partProperty(i, "tmp", vx * 100)
	sim.partProperty(i, "tmp2", vy * 100)
	sim.partProperty(i, "tmp3", x)
	sim.partProperty(i, "tmp4", y)

	if pv - v > 10 then -- Has my velocity suddenly decreased drastically?
		local ctype = sim.partProperty(i, "ctype")
		if ctype == 0 then ctype = elem.DEFAULT_PT_EMBR end

		local bulletProps = bulletTypeInfo[ctype] or bulletDefault

		local radius = bulletProps[7]

		for cx = -radius, radius do
			for cy = -radius, radius do

				if cx ^ 2 + cy ^ 2 < (radius + 0.5) ^ 2 and x + cx >= 0 and y + cy >= 0 and x + cx < sim.XRES and y + cy < sim.YRES then
					local partsKilled = false
					if bulletProps[1] then
						local id = sim.pmap(x + cx, y + cy)
						if not (cx == 0 and cy == 0) and id ~= nil then
							if not bulletImmune[sim.partProperty(id, "type")] then
								sim.partKill(id)
								partsKilled = true
							end
						end
					end
					if (not bulletProps[8]) or partsKilled then
						local fragment = sim.partCreate(-1, x + cx, y + cy, ctype)
						
						if bulletTypeFunctions[ctype] then bulletTypeFunctions[ctype](fragment) end

						-- if fragment then
							if bulletProps[2] then
								if bulletProps[2] ~= -1 then
									sim.partProperty(fragment, "temp", bulletProps[2])
								end
							else
								sim.partProperty(fragment, "temp", pv * 200)
							end
						
							if bulletProps[4] then sim.partProperty(fragment, "life", bulletProps[4]) end
							if bulletProps[5] then sim.partProperty(fragment, "tmp", bulletProps[5]) end
							if bulletProps[6] then sim.partProperty(fragment, "tmp2", bulletProps[6]) end
							sim.partProperty(fragment, "vx", cx + (math.random() - 0.5) * 2)
							sim.partProperty(fragment, "vy", cy + (math.random() - 0.5) * 2)
						-- end
					end
				end
			end
		end

		sim.pressure(x / 4, y / 4, sim.pressure(x / 4, y / 4) + (bulletProps[3] or pv))

		if ctype ~= elem.DEFAULT_PT_DMND then
			sim.partProperty(i, "life", -1)
		end
	end
end)

elem.property(shot, "Graphics", function (i, r, g, b)
	local v = sim.partProperty(i, "life")
	local px = sim.partProperty(i, "tmp3")
	local py = sim.partProperty(i, "tmp4")
	local x, y = sim.partPosition(i)

	if v > 10 then
		graphics.drawLine(x, y, px, py, 255, 255, 0, (v - 10) * 25)
	end
	local pixel_mode = ren.PMODE_FLAT
	return 0,pixel_mode,255,r,g,b,0,0,0,0;
end)

elem.property(shot, "CtypeDraw", function(i, t)
	if t ~= shot and bit.band(elem.property(t, "Properties"), elem.PROP_NOCTYPEDRAW) == 0 then
		sim.partProperty(i, "ctype", t)
	end
end)

sim.can_move(shot, elem.DEFAULT_PT_EMBR, 2)

local resetNukeScreenflash = 0

event.register(event.tick, function()
	if resetNukeScreenflash > 0 then
		graphics.fillRect(0, 0, sim.XRES, sim.YRES, 255, 255, 127, resetNukeScreenflash * 10)
	end
end)  
event.register(event.aftersim, function(a, b, c, d)
	if resetNukeScreenflash > 0 then
		resetNukeScreenflash = resetNukeScreenflash - 1
	end
end)  

local resetByCtype = {
	[elem.DEFAULT_PT_SPRK] = true,
	[elem.DEFAULT_PT_ICEI] = true,
	[elem.DEFAULT_PT_SNOW] = true,
	[elem.DEFAULT_PT_LAVA] = true,
	[mlva] = true, -- RSET can purify MELT
	[melt] = true,
}

local unresettable = {
	[elem.DEFAULT_PT_DMND] = true,
	[rset] = true,
}

local resetVx
local resetVy
local resetTemp
local resetCtype
local function resetParticle(i, x, y, type, ctype, filter, modeVel, modeTemp, modeCtype)
	if not unresettable[type] and (filter == 0 or type == filter) then
		if modeVel then
			resetVx = sim.partProperty(i, "vx")
			resetVy = sim.partProperty(i, "vy")
		end

		if modeTemp then
			resetTemp = sim.partProperty(i, "temp")
		end

		if modeCtype then
			resetCtype = sim.partProperty(i, "ctype")
			sim.partCreate(i, x, y, type)
			sim.partProperty(i, "ctype", sim.partProperty(i, "ctype"))
		else
			sim.partCreate(i, x, y, resetByCtype[type] and ctype ~= 0 and ctype or type)
		end

		if modeVel then
			sim.partProperty(i, "vx", sim.partProperty(i, "vx"))
			sim.partProperty(i, "vy", sim.partProperty(i, "vy"))
		end
		if modeTemp then
			sim.partProperty(i, "temp", sim.partProperty(i, "temp"))
		end
	end
end

-- ctype: Type to reset particles of. Works on all particles if not set.
-- life: Mode.
--  0b000 - Reset all properties.
--  0b001 - Reset all properties except velocity.
--  0b010 - Reset all properties except temperature.
--  0b100 - Reset all properties except ctype. (disables ctype reversion)
elem.element(rset, elem.element(elem.DEFAULT_PT_CONV))
elem.property(rset, "Name", "RSET")
elem.property(rset, "Description", "Resetter. Resets the properties of particles to default on contact.")
elem.property(rset, "Colour", 0xFE31AF)
elem.property(rset, "MenuSection", elem.SC_SPECIAL)
elem.property(rset, "Update", function(i, x, y, s, n)
	if s ~= n then -- Extremely sexy optimization
		local ctype = sim.partProperty(i, "ctype")
		local life = sim.partProperty(i, "life")
		modeVel, modeTemp, modeCtype = bit.band(life, 0x1) ~= 0, bit.band(life, 0x2) ~= 0, bit.band(life, 0x4) ~= 0
		for cx = -1, 1 do
			for cy = -1, 1 do
				local id = sim.partID(x + cx, y + cy)
				if id ~= nil then
					local ntype = sim.partProperty(id, "type")
					local nctype = sim.partProperty(id, "ctype")

					if ntype == elem.DEFAULT_PT_EMP and sim.partProperty(id, "life") > 0 then
						resetNukeScreenflash = 10
						sim.partChangeType(i, elem.DEFAULT_PT_BOMB)
						for k,j in sim.parts() do 
							if math.random() < 0.05 then -- Don't affect all particles, like EMP
								local rx, ry = sim.partPosition(k)
								local stype = sim.partProperty(k, "type")
								local sctype = sim.partProperty(k, "ctype")
								-- Particles frozen inside stasis wall are protected from reset nuke
								if not (tpt.get_wallmap(rx / 4, ry / 4) == 18 and tpt.get_elecmap(rx / 4, ry / 4) == 0) then -- Stasis wall
									resetParticle(k, rx, ry, stype, sctype, ctype, life, modeVel, modeTemp, modeCtype)
								else

								end
							end
						end
					end

					resetParticle(id, x + cx, y + cy, ntype, nctype, ctype, life, modeVel, modeTemp, modeCtype)
				end
			end
		end
	end
end)
-- SEEEEEEEEEEEEECRETS!!!!!!!!!!

local pink = elem.allocate("FanMod", "PINK")

-- https://www.youtube.com/watch?v=nCR9zMU2Q_M
elem.element(pink, elem.element(elem.DEFAULT_PT_DMND))
elem.property(pink, "Name", "PINK")
elem.property(pink, "Description", "Pink sand. A visitor from a pond far, far away...")
elem.property(pink, "Colour", 0xff00ff)
elem.property(pink, "MenuSection", -1)
elem.property(pink, "Update", function(i, x, y, s, n)
	local bx = round(x)
	local by = round(y)
	local below = sim.pmap(bx, by + 1)
	if below == nil then
		local new = sim.partCreate(-1, bx, by + 1, pink)
		if new ~= -1 then
			sim.partKill(i)
			return
		end
	end

	local slide = math.random(-1, 1)
	local slidePart = sim.pmap(bx + slide, by + 1)
	if slidePart == nil then
		local new = sim.partCreate(-1, bx + slide, by + 1, pink)
		if new ~= -1 then
			sim.partKill(i)
			return
		end
	end
end)


end
FanElements()