function FanElements()

-- Some old versions did not use fanElemsEnv
if fanElemsEnv or elem["FANMOD_PT_SMDB"] then
	print("Fan Elements Script: Please restart the game for updates to take effect.")
	return
end

-- Setup environment
fanElemsEnv = {}
-- __index = _G makes it so functions from Lua and the TPT API can be accessed with no additional fuss
setmetatable(fanElemsEnv, {__index = _G})
if _ENV then
	_ENV = fanElemsEnv
else
	setfenv(1, fanElemsEnv)
end

-- pavg0/1 checks have been removed. No longer accomodating old versions
if not sim.FIELD_TMP3 then
	print("Fan Elements Script: Please update The Powder Toy to v97.0 or higher.")
	return
end

-- Element definitions
local smdb = elem.allocate("FANMOD", "SMDB") -- Super mega death bomb
local srad = elem.allocate("FANMOD", "SRAD") -- Hidden. Used by SDMB as part of its explosion

local trit = elem.allocate("FANMOD", "TRIT") -- Tritium
local ltrt = elem.allocate("FANMOD", "LTRT") -- Liquid Tritium. Hidden, created by pressurizing TRIT

local ffld = elem.allocate("FANMOD", "FFLD") -- Forcefield generator

local grph = elem.allocate("FANMOD", "GRPH") -- Graphite
local bgph = elem.allocate("FANMOD", "BGPH") -- Broken Graphite

local melt = elem.allocate("FANMOD", "MELT") -- Melt Powder
local mlva = elem.allocate("FANMOD", "MLVA") -- Melting Lava

local mmry = elem.allocate("FANMOD", "MMRY") -- Shape Memory Alloy

local halo = elem.allocate("FANMOD", "HALO") -- Halogens
local lhal = elem.allocate("FANMOD", "LHAL") -- Liquid halogens
local fhal = elem.allocate("FANMOD", "FHAL") -- Frozen halogens
local trtw = elem.allocate("FANMOD", "BFLR") -- Treated water 
-- (Internally referred to as "BFLR" because of an error in an earlier version)
local flor = elem.allocate("FANMOD", "FLOR") -- Fluorite
local pflr = elem.allocate("FANMOD", "PFLR2") -- Powdered fluorite

-- v2 Elements
local no32 = elem.allocate("FANMOD", "NO32") -- Nobili32

local lncr = elem.allocate("FANMOD", "LNCR") -- Launcher

local shot = elem.allocate("FANMOD", "SHOT") -- Bullet

local rset = elem.allocate("FANMOD", "RSET") -- Resetter

local fuel = elem.allocate("FANMOD", "FUEL") -- Napalm

local copp = elem.allocate("FANMOD", "COPP") -- Copper
local cuso = elem.allocate("FANMOD", "CUSO") -- Copper(II) sulfate
local brcs = elem.allocate("FANMOD", "BRCS") -- Broken copper(II) sulfate

local stgm = elem.allocate("FANMOD", "STGM") -- Strange matter

local fngs = elem.allocate("FANMOD", "FNGS") -- Fungus
local spor = elem.allocate("FANMOD", "SPOR") -- Fungus spore

local plst = elem.allocate("FANMOD", "PLST") -- Plastic
local mpls = elem.allocate("FANMOD", "MPLS") -- Melted plastic
local plex = elem.allocate("FANMOD", "PLEX") -- Plastic explosive

local wick = elem.allocate("FANMOD", "WICK") -- Wick

-- Utilities

local globalTimer = 0
event.register(event.tick, function()
	globalTimer = globalTimer + 1
end)  

local mouseButtonType = {
	[1] = function() return tpt.selectedl end,
	[3] = function() return tpt.selectedr end,
	[2] = function() return tpt.selecteda end,
}

-- Creates a dropdown window from the choices provided
local function createDropdown(options, x, y, width, height, action)
	local dropdownWindow = Window:new(x, y, width, (height - 1) * #options + 1)
	local buttonChoices = {}
	local buttonNames = {}
	for i,j in pairs(options) do
		local dropdownButton = Button:new(0, (height - 1) * (i - 1), width, height, j)
		dropdownButton:action(
			function(sender)
				action(buttonChoices[sender], buttonNames[sender])
				interface.closeWindow(dropdownWindow)
			end)
		dropdownButton:text(j)
		buttonChoices[dropdownButton] = i
		buttonNames[dropdownButton] = j
		dropdownWindow:addComponent(dropdownButton)
	end
	dropdownWindow:onTryExit(function()
		interface.closeWindow(dropdownWindow)
	end)
	interface.showWindow(dropdownWindow)
end

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

-- Utility functions

local function round(num)
	return math.ceil(num - 0.5)
end

local function clamp(val, low, high)
	if val > high then
		return high
	elseif val < low then
		return low
	end
	return val
end

local function hsvToRgb(h, s, v)
	h = h % 360
	local c = v * s
	local x = c * (1 - math.abs((h / 60) % 2 - 1))
	local m = v - c
	local rgbTable = {
		{c, x, 0},
		{x, c, 0},
		{0, c, x},
		{0, x, c},
		{x, 0, c},
		{c, 0, x},
	}
	local rgb = rgbTable[clamp(math.floor(h / 60) + 1, 1, 6)]
	local r, g, b = (rgb[1] + m) * 255, (rgb[2] + m) * 255, (rgb[3] + m) * 255
	return r, g, b
end

-- Because of the overhead from calling the TPT API's bitwise operations, this is actually faster.
-- However, it only works when checking one bit at a time.
local function bitCheck(num, bit)
	return num % (bit * 2) - num % bit == bit
end

-- Extracts the bits from a number from lbound to hbound inclusive
local function filterBits(num, hbound, lbound)
	return num % (hbound * 2) - num % lbound
end

-- Extracts the bits from a number from lbound to hbound inclusive, then divides by the lbound.
local function extractBits(num, hbound, lbound)
	return (num % (hbound * 2) - num % lbound) / lbound
end

local function floodFill(x, y, condition, action)
	local bitmap = {}
	for i = 0, sim.XRES - 1 do
		bitmap[i] = {}
		for j = 0, sim.YRES - 1 do
			bitmap[i][j] = true
		end
	end
	local pstack = {}
	-- Push starting position to stack
	pstack[#pstack + 1]	= {x, y}

	repeat 
	 	local pos = table.remove(pstack)
	 	local x1, x2, y1 = pos[1], pos[1], pos[2]
	 	while x1 >= sim.CELL and condition(x1 - 1, y1) and bitmap[x1 - 1][y1] do
	 		x1 = x1 - 1
	 	end
	 	while x2 < sim.XRES - sim.CELL and condition(x2 + 1, y1) and bitmap[x2 + 1][y1] do
	 		x2 = x2 + 1
	 	end
	 	for i = x1, x2 do
			action(i, y1)
			bitmap[i][y1] = false
	 	end
	 	if y1 >= sim.CELL + 1 then
	 		for i = x1, x2 do
	 			if condition(i, y1 + 1) then
	 				pstack[#pstack + 1]	= {i, y1 + 1}
	 			end
	 		end
	 	end
	 	if y1 < sim.YRES - sim.CELL - 1 then
	 		for i = x1, x2 do
	 			if condition(i, y1 - 1) then
	 				pstack[#pstack + 1]	= {i, y1 - 1}
	 			end
	 		end
	 	end
	until (#pstack == 0)
end

do -- Start of SMDB scope

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

local function spawnSradJunk(x, y, isWall)
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
	local nearbySrad = sim.partNeighbours(x, y, 2, srad)
	if #nearbySrad > 0 then
		sim.partProperty(i, "ctype", srad)
	end
end
, 2)

end -- End oF SMDB scope

do -- Start of TRIT scope
elem.element(trit, elem.element(elem.DEFAULT_PT_HYGN))
elem.property(trit, "Name", "TRIT")
elem.property(trit, "Description", "Tritium. Radioactive gas. Created by firing neutrons at LITH. Can fuse with DEUT.")
elem.property(trit, "Colour", 0x055b3f)
elem.property(trit, "MenuSection", elem.SC_NUCLEAR)
elem.property(trit, "Properties", elem.TYPE_GAS + elem.PROP_NEUTPASS)
elem.property(trit, "HighPressure", 10)
elem.property(trit, "HighPressureTransition", ltrt)

local function tritupdate(i, x, y, s, n)
	if math.random(3000) == 1 then
		sim.partChangeType(i, elem.DEFAULT_PT_HYGN)
		local elec = sim.partCreate(-3, x, y, elem.DEFAULT_PT_ELEC)
		sim.partProperty(elec, "temp", sim.partProperty(i, "temp"))
	end

	local nearbyRadiation = false
	local bx, by = x + math.random(3) - 2, y + math.random(3) - 2
	local bp = sim.photons(bx, by)
	if bp ~= nil then
		if (sim.partProperty(bp, "type") == elem.DEFAULT_PT_PHOT) or (sim.partProperty(bp, "type") == elem.DEFAULT_PT_NEUT) then
			nearbyRadiation = true
		end
		-- if nearbyRadiation then print("So Irradiated Rn") end
	end

	-- Not realistic, but making tritium fusion easy to activate makes it more useful.
	if nearbyRadiation or (sim.partProperty(i, "temp") > 1273.15 and sim.pressure(x/4, y/4) > 10.0) then
		local cx, cy = x + math.random(3) - 2, y + math.random(3) - 2
		local r = sim.pmap(cx, cy)
		if r and sim.partProperty(r, "type") == elem.DEFAULT_PT_DEUT and sim.partProperty(i, "life") ~= 1 then
			sim.partProperty(i, "tmp", 20 + math.random(20))
			sim.partProperty(i, "tmp2", sim.partProperty(r, "life"))
			sim.partKill(r)
		end
	end

	local tmp = sim.partProperty(i, "tmp")
	if tmp > 0 then
		sim.partProperty(i, "tmp", tmp - 1)
		if tmp == 1 then
			sim.partProperty(i, "temp", sim.partProperty(i, "temp") + math.random(750, 1249) * sim.partProperty(i, "tmp2") / 10)

			sim.partChangeType(i, elem.DEFAULT_PT_NBLE)
			local np = sim.partCreate(-1, x, y, elem.DEFAULT_PT_NEUT)
			sim.partProperty(np, "temp", sim.partProperty(i, "temp"))
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

	if sim.partProperty(i, "tmp") > 0 then
		colr = 255
		colg = 127
		colb = 255
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
elem.property(ltrt, "Graphics", function (i, r, g, b)
	
	local colr = r
	local colg = g
	local colb = b
	
	local firea = 0

	if sim.partProperty(i, "tmp") > 0 then
		firea = 255
		colr = 255
		colg = 127
		colb = 255
		pixel_mode = ren.FIRE_ADD + ren.PMODE_GLOW
	end
	
	local firer = colr;
	local fireg = colg;
	local fireb = colb;
	
	return 0,pixel_mode,255,colr,colg,colb,firea,firer,fireg,fireb;
end)
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
end -- End of TRIT scope

do -- Start of FFLD scope
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

event.register(event.beforesim, function()
	if updateHighlighted then
		updateHighlighted = false
		highlighted = {}
	end
end)

local pipeTypes = {
	[elem.DEFAULT_PT_PIPE] = true,
	[elem.DEFAULT_PT_PPIP] = true
}

local function transferPartToPipe(part, pipe)
	if sim.partProperty(pipe, "ctype") == 0 then
		sim.partProperty(pipe, "ctype", sim.partProperty(part, "type"))
		sim.partProperty(pipe, "temp", sim.partProperty(part, "temp"))
		sim.partProperty(pipe, "tmp2", sim.partProperty(part, "life"))
		sim.partProperty(pipe, "tmp3", sim.partProperty(part, "tmp"))
		sim.partProperty(pipe, "tmp4", sim.partProperty(part, "ctype"))
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
	[0x00D] = function(d, x, y) -- Deflect
		-- Essentially stronger version of Repel, specifically for high-velocity particles
		local px, py = sim.partPosition(d)
		px = px - x
		py = py - y
		local vmagnitude = math.sqrt(sim.partProperty(d, "vx") ^ 2 + sim.partProperty(d, "vy") ^ 2) + 0.1
		local fx = px / math.sqrt(px ^ 2 + py ^ 2) * vmagnitude
		local fy = py / math.sqrt(px ^ 2 + py ^ 2) * vmagnitude
		sim.partProperty(d, "vx", fx)
		sim.partProperty(d, "vy", fy)
		return true
	end,
}

local ffldIgnore = {
	[elem.DEFAULT_PT_BRAY] = true,
	-- [elem.DEFAULT_PT_EMBR] = true,
	[ffld] = true,
}

local function shouldIgnore(type, fieldCtype, action)
	if action == 0x1 and type == elem.DEFAULT_PT_EMBR then
		return true
	end

	return ffldIgnore[type] and type ~= fieldCtype
end

local function isInsideFieldShape(size, shape, dx, dy)
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
elem.property(ffld, "Description", "Forcefield generator. Repels parts of its ctype. Temp sets range, Shift+click to set mode. Toggle with PSCN/NSCN or ARAY.")
elem.property(ffld, "Colour", 0x00de94)
elem.property(ffld, "HeatConduct", 0)
elem.property(ffld, "Hardness", 0)
elem.property(ffld, "MenuSection", elem.SC_FORCE)

elem.property(ffld, "Properties", elem.TYPE_SOLID + elem.PROP_NOCTYPEDRAW + elem.PROP_NOAMBHEAT + elem.PROP_LIFE_DEC)

elements.property(ffld, "Create", function(i, x, y, t, v)

	sim.partProperty(i, "tmp2", 1)
	sim.partProperty(i, "tmp3", 0)
end)

-- Does not account for the fact that elements may be deallocated
-- However, this is unlikely and the effects would be largely inconsequential here.
local definitelySafeElementIds = {}

for i=0,2^sim.PMAPBITS-1 do
	definitelySafeElementIds[i] = false
end

elem.property(ffld, "Update", function(i, x, y, s, n)
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

	local newFormat = sim.partProperty(i, "tmp4")


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
				-- if not px or not py then print(k, d, px, py) end
				if isInsideFieldShape(range, shape, px - x, py - y) and not shouldIgnore(sim.partProperty(d, "type"), ctype, action) then
					shieldActionFunctions[action](d, x, y)
					any = true
				end
			end

			if sim.partProperty(i, "tmp3") == 0 and any then
				sim.partProperty(i, "tmp3", 1)
				sim.partProperty(i, "life", 20)
			end

			if sim.partProperty(i, "tmp3") == 1 and not any then
				sim.partProperty(i, "tmp3", 0)
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


	local anyParts = sim.partProperty(i, "tmp3")

	local enabled = sim.partProperty(i, "tmp2")
	local flash = sim.partProperty(i, "life")

	local colr = r
	local colg = g
	local colb = b

	local firea = 0
	
	local pixel_mode = ren.PMODE_FLAT

	local newFormat = sim.partProperty(i, "tmp4")

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

local ffldPatternNames = {
	"Matching ctype",
	"Not matching ctype",
	"All if any match ctype",
	"All if none match ctype",
	"All if any don't match ctype",
	"All if all match ctype",
	"All particles in range",
	"Matching ctype's menu section",
	"Matching ctype's state of matter",
	"Not matching ctype's state of matter",
	"Hotter than ctype (as number)",
	"Colder than ctype (as number)",
	"Matching selected element",
	"Not matching selected element",
	"Not matching ctype's menu section",
}

local ffldShapeNames = {
	"None",
	"Circle",
	"Square",
	"Diamond",
	"Triangle (up)",
	"Triangle (down)",
	"Triangle (right)",
	"Triangle (left)",
}

local ffldActionNames = {
	"Repel",
	"Destroy",
	"Suspend",
	"Detect",
	"Superheat",
	"Supercool",
	"Encase",
	"Annihilate",
	"Attract",
	"Collect",
	"Highlight",
	"Paint w/deco color",
	"Delete",
	"Deflect",
}

-- FFLD placement/configuration handling
event.register(event.mousedown, function(x, y, button)

	-- Check for configurable FFLD
	local underMouse = sim.pmap(sim.adjustCoords(x, y))
	if shiftHeld and underMouse and sim.partProperty(underMouse, "type") == ffld then
		shiftHeld = false

		local newFormat = sim.partProperty(underMouse, "tmp4")
		local tmp = sim.partProperty(underMouse, "tmp")
		
		local pattern
		local shape
		local action

		if newFormat == 1 then
			pattern = bit.band(tmp, 0xF00)
			shape = bit.band(tmp, 0x0F0)
			action = bit.band(tmp, 0x00F)
		else
			pattern = oldModeFormatMap[bit.band(tmp, 0x11000000)]
			shape = oldModeFormatMap[bit.band(tmp, 0x00111000)]
			action = oldModeFormatMap[bit.band(tmp, 0x00000111)]
		end

		pattern = pattern / 0x100
		shape = shape / 0x010
		action = action / 0x001

		local ffldConfigWindow = Window:new(-1, -1, 200, 76)
		
		local actionDropdown = Button:new(10, 10, 180, 16)
		actionDropdown:action(
			function(sender)
				local windowX, windowY = ffldConfigWindow:position()
				createDropdown(ffldActionNames, 10 + windowX, windowY - #ffldActionNames * 8 + 76 / 2, 180, 16, 
					function(a, b)
						actionDropdown:text(b)
						action = a - 1
					end)
			end)
		actionDropdown:text(ffldActionNames[action + 1])
		ffldConfigWindow:addComponent(actionDropdown)

		local patternDropdown = Button:new(10, 30, 180, 16)
		patternDropdown:action(
			function(sender)
				local windowX, windowY = ffldConfigWindow:position()
				createDropdown(ffldPatternNames, 10 + windowX, windowY - #ffldPatternNames * 8 + 76 / 2, 180, 16, 
					function(a, b)
						patternDropdown:text(b)
						pattern = a - 1
					end)
			end)
		patternDropdown:text(ffldPatternNames[pattern + 1])
		ffldConfigWindow:addComponent(patternDropdown)
		
		local shapeDropdown = Button:new(10, 50, 180, 16)
		shapeDropdown:action(
			function(sender)
				local windowX, windowY = ffldConfigWindow:position()
				createDropdown(ffldShapeNames, 10 + windowX, windowY - #ffldShapeNames * 8 + 76 / 2, 180, 16, 
					function(a, b)
						shapeDropdown:text(b)
						shape = a - 1
					end)
			end)
		shapeDropdown:text(ffldShapeNames[shape + 1])
		ffldConfigWindow:addComponent(shapeDropdown)

		ffldConfigWindow:onTryExit(function()
			sim.takeSnapshot()
			-- Subversively convert old format to new format
			sim.partProperty(underMouse, "tmp4", 1)
			sim.partProperty(underMouse, "tmp", pattern * 0x100 + shape * 0x010 + action * 0x001)
			interface.closeWindow(ffldConfigWindow)
		end)
		interface.showWindow(ffldConfigWindow)
		return false
	end


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
			sim.partProperty(i, "tmp4", 1) -- USE NEW MODE ENCODING
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
end -- End of FFLD scope

do -- Start of GRPH scope
local graphiteIgniters = {
	[elem.DEFAULT_PT_FIRE] = true,
	[elem.DEFAULT_PT_PLSM] = true,
	[elem.DEFAULT_PT_OXYG] = true,
	[elem.DEFAULT_PT_LIGH] = true,
}

local graphiteBurnHealth = 40
local graphitePressureHealth = 10
local graphiteExtinguishTime = 30
local brokenGraphBurnHealth = 60

-- life: Not used by the main update function so it can safely transform into LAVA or SPRK and back.
-- tmp: Burn health. Decrements once for every flame particle created.
-- tmp2: Pressure health. Has a 1/2 chance of decrementing every frame the particle is exposed to 80+ pressure.
-- tmp3: Used for a "graphite cycle" that makes sure sparks running through graphite are not subject to particle order bias.
-- tmp4: Used for the direction that sparks are travelling through the material as well as a dead space behind each spark, similarly to how other conductors use life.

elem.element(grph, elem.element(elem.DEFAULT_PT_DMND))
elem.property(grph, "Name", "GRPH")
elem.property(grph, "Description", "Graphite. Strong solid that slows radiation. Conducts electricity in straight lines.")
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
	[0xB] = 0x30, -- Illegal state
	[0xC] = 0x20, -- Illegal state
	[0xD] = 0x30, -- Illegal state
	[0xE] = 0x30, -- Illegal state
	[0xF] = 0x30, -- Illegal state
}

local conductWaitTable = {
	[0x1] = 0x1,
	[0x2] = 0x1,
	[0x4] = 0x2,
	[0x8] = 0x2,
}

local hoveredPart = -1

local tmp4Debug = false
event.register(event.tick, function()
	if tmp4Debug then
		local gx, gy = sim.adjustCoords(tpt.mousex, tpt.mousey)
		local part = sim.pmap(gx, gy)

		if part ~= nil then
			local text = bit.tohex(sim.partProperty(part, "tmp4"))
			graphics.drawText(10, 10, text)
			hoveredPart = part
		else
			hoveredPart = -1
		end
	end
end)  

local function sparkGraphite(i, sparkDir, source, p)
	-- if i == hoveredPart then
	-- 	print("They tried to spark me!")
	-- end
	local ptype = i and sim.partProperty(i, "type")
	if ptype == grph or (ptype == elem.DEFAULT_PT_SPRK and sim.partProperty(i, "ctype") == grph) then
		local dir = sim.partProperty(i, "tmp4")
		local negate = bit.band(dir, bitNegaterMap[sparkDir] * 5)
		if bit.band(dir, oppositeDirections[sparkDir] + sparkDir) == 0 and negate == 0x0 then
			local tmp3 = sim.partProperty(i, "tmp3")
			sim.partChangeType(i, elem.DEFAULT_PT_SPRK)
			sim.partProperty(i, "ctype", grph)
			sim.partProperty(i, "tmp4", bit.bor(dir, sparkDir))
			sim.partProperty(i, "life", 4)
			if source < i then
				sim.partProperty(i, "tmp3", tmp3 + conductWaitTable[sparkDir])
			end
		else
			return false
		end
		return true
	end
	return false
end

local function graphiteSparkNormal(i)
	if i ~= nil then
		local type = sim.partProperty(i, "type")
		if bit.band(elements.property(type, "Properties"), elements.PROP_CONDUCTS) ~= 0 and type ~= elem.DEFAULT_PT_PSCN then
			local px, py = sim.partPosition(i)
			sim.partCreate(-1, px, py, elem.DEFAULT_PT_SPRK)
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
	-- print(i, x, y)
	local ctype = sim.partProperty(i, "ctype")
	if ctype == grph then
		local life = sim.partProperty(i, "life")
		local timer = sim.partProperty(i, "tmp3")
		local tmp4 = sim.partProperty(i, "tmp4")
		if ((life == 3 and timer == 0) or (life == 4 and timer > 0)) then
			for d = 1, 4 do
				local dirBit = 2 ^ (d - 1)
				local dir = bitCheck(tmp4, dirBit)

				if dir and not bitCheck(timer, conductWaitTable[dirBit]) then
					for p = 1, 4 do
						local px, py = x + initialDetectionOffsets[d][1] * p, y + initialDetectionOffsets[d][2] * p
						local part = sim.pmap(px, py)
						if not sparkGraphite(part, dirBit, i, p) and not graphiteSparkNormal(part) then
							break
						end
					end
				end
			end
			sim.partProperty(i, "tmp3", 0)
		end
		if life == 2 then
			sim.partProperty(i, "tmp4", bitNegaterMap[tmp4 % 0x10]) -- tmp4 - tmp4 % 0x10 + 
		end
	elseif ctype ~= elem.DEFAULT_PT_NSCN then
		local life = sim.partProperty(i, "life")
		if life >= 3 then
			local tmp = sim.partProperty(i, "tmp")
			for d = 1, 4 do
				local dirBit = 2 ^ (d - 1)
				if graphiteProgrammable[ctype] then
					if bitCheck(tmp, dirBit) then
						goto continue
					end
				end
				for p = 1, 4 do
					local px, py = x + initialDetectionOffsets[d][1] * p, y + initialDetectionOffsets[d][2] * p
					local part = sim.pmap(px, py)
					if not sparkGraphite(part, dirBit, i, p) then
						break
					end
				end
				::continue::
			end
		end
	end
end, 3)

elem.property(grph, "Update", function(i, x, y, s, n)
	-- Update delay before GRPH can conduct in each direction again
	local tmp4 = sim.partProperty(i, "tmp4")
	if tmp4 ~= 0 then
		sim.partProperty(i, "tmp4", bit.band(tmp4, 0x30) * 0x4)
	end

	local a = sim.photons(x, y)
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

	local temp = sim.partProperty(i, "temp")

	if temp < 400 + 273.15 then
		sim.partProperty(i, "tmp3", 0)
	end

	if math.random(2) == 1 and simulation.pressure(x / 4, y / 4) > 80 then
		local tmp2 = sim.partProperty(i, "tmp2")
		tmp2 = tmp2 - 1
		if tmp2 <= 0 then
			sim.partChangeType(i, bgph)
			sim.partProperty(i, "life", brokenGraphBurnHealth)
			return
		else
			sim.partProperty(i, "tmp2", tmp2 - 1)
		end
	end

	if n > 0 then
		local burnHealth = sim.partProperty(i, "tmp3")
		if burnHealth > 0 then
			local fireNeighbors = sim.partNeighbours(x, y, 1, elem.DEFAULT_PT_FIRE)
			local plsmNeighbors = sim.partNeighbours(x, y, 1, elem.DEFAULT_PT_PLSM)
			if #fireNeighbors > 0 or #plsmNeighbors > 0 then
				burnHealth = graphiteExtinguishTime
			else
				burnHealth = burnHealth - 1
			end
			local fire = sim.partCreate(-1, x + math.random(3) - 2, y + math.random(3) - 2, elem.DEFAULT_PT_FIRE)
			if fire ~= -1 then
				sim.partProperty(i, "temp", temp + 10)
				sim.partProperty(fire, "temp", temp) -- Graphite burns hotter than most materials
			
				local tmp = sim.partProperty(i, "tmp")
				tmp = tmp - 1
				if tmp <= 0 then
					sim.partKill(i)
					return
				else
					sim.partProperty(i, "tmp", tmp)
				end
			end
			sim.partProperty(i, "tmp3", burnHealth)
		else
			local randomNeighbor = sim.pmap(x + math.random(3) - 2, y + math.random(3) - 2)
			if temp > 400 + 273.15 and randomNeighbor ~= nil and (graphiteIgniters[sim.partProperty(randomNeighbor, "type")] == true) then
				sim.partProperty(i, "tmp3", graphiteExtinguishTime)
			end
		end
	end
end)

local function graphiteGraphics(i, r, g, b)

	local tempC = sim.partProperty(i, "temp") - 273.15
	-- local vel = sim.velocityX(number x, number y)

	local pixel_mode = ren.PMODE_FLAT

	local colr = r
	local colg = g
	local colb = b

	if sim.partProperty(i, "type") == grph then
		local burn = graphiteBurnHealth - sim.partProperty(i, "tmp")
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
-- tmp4: Speed on the previous frame. Used to calculate if the particle has impacted a surface so that it can draw on it.

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

	local vdx = (sim.partProperty(i, "tmp4") - totalVel) / 100

	sim.partProperty(i, "tmp4", totalVel)
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

		if n == 8 then
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

	if ctype == flor then
		local rn
		if sim.partProperty(i, "temp") > 3000 + 273.15 then
			rn = sim.pmap(x + math.random(7) - 4, y + math.random(7) - 4)
		else
			rn = sim.pmap(x + math.random(7) - 4, y + math.random(3) - 3)
		end
		if rn ~= nil and sim.partProperty(rn, "type") == elem.DEFAULT_PT_LAVA then
			local x1, y1 = sim.partPosition(i)
			local x2, y2 = sim.partPosition(rn)
			sim.partPosition(i, x2, y2)
			sim.partPosition(rn, x1, y1)
		end
	end
end)
end -- Start of GRPH scope

do -- Start of MELT scope
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
	[trtw] = true,
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
elem.property(melt, "Description", "Melting powder. Rapidly boils water. When melted, constantly heats up and converts molten materials.")
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

		if s > 0 then
			local rx = x + math.random(3) - 2
			local ry = y + math.random(3) - 2
			
			if math.random(30) == 1 then
				local smoke = sim.partCreate(-1, rx, ry, elem.DEFAULT_PT_SMKE)
				sim.partProperty(smoke, "life", 240)
			end
		end
	else
		local tmp = sim.partProperty(i, "tmp")

		if n > 0 then
			local rx = x + math.random(3) - 2
			local ry = y + math.random(3) - 2
			local randomNeighbor = sim.pmap(rx, ry)
			if randomNeighbor ~= nil then
				local type = sim.partProperty(randomNeighbor, "type")
				local temp = sim.partProperty(randomNeighbor, "temp")
				if waters[type] then
					sim.partProperty(randomNeighbor, "temp", temp + 0.8 * (273.15 + 400 - temp))
				end

				if math.random(60) == 1 and type == elem.DEFAULT_PT_LAVA then
					tmp = tmp + 1
				end

				if temp > 273.15 and mLavaNeutralizers[type] then
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
		end

		local temp = sim.partProperty(i, "temp")
		if math.random(60) == 1 and temp < 273.15 - 40 and tmp < 100 then
			tmp = tmp + 1
		end

		sim.partProperty(i, "temp", temp + tmp / 4)

		if math.random() < tmp / 200 then
			sim.partChangeType(i, mlva)
		end

		sim.partProperty(i, "tmp", tmp)
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

local function neutralizeMlva(x, y)

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
		sim.partProperty(i, "tmp", tmp + 1)
	end

	if math.random(192) == 1 then
		sim.partChangeType(i, melt)
		sim.partProperty(i, "temp", temp + 200)
		return
	else
		sim.partProperty(i, "temp", temp + tmp / 4 + 10)
	end

	
	if n > 0 then
		local rx = x + math.random(3) - 2
		local ry = y + math.random(3) - 2
		local randomNeighbor = sim.pmap(rx, ry)
		if randomNeighbor ~= nil then
			local type = sim.partProperty(randomNeighbor, "type")
			if math.random(50) == 1 then
				if type == elem.DEFAULT_PT_LAVA then
					sim.partProperty(randomNeighbor, "type", mlva)
				end
			end

			if mLavaNeutralizers[type] then
				if mLavaNeutralizersCtype[type] then
					local ctype = sim.partProperty(randomNeighbor, "ctype")
					if mLavaNeutralizers[ctype] then
						sim.partChangeType(i, melt)
						sim.partProperty(i, "tmp2", 1)
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
	end
end)

elem.property(mlva, "Graphics", function (i, r, g, b)
	local x,y = sim.partPosition(i)
	local colr = math.sin(globalTimer * 0.02 + y * 0.1 + math.sin(x * 0.1 + math.sin(globalTimer * 0.01) * 5) * 0.3 + math.sin(x * 0.04 + globalTimer * 0.03) * 0.4) * 100 + 140
	local colg = colr * 0.3 - 50
	local colb = 0

	local firer = colr * 0.8
	local fireg = colr * 0.6
	local fireb = 0

	local firea = 20
	
	local pixel_mode = ren.PMODE_FLAT + ren.FIRE_ADD + ren.PMODE_BLUR

	return 0,pixel_mode,255,colr,colg,colb,firea,firer,fireg,fireb;
end)
end -- End of MELT scope

do -- Start of MEND scope
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
	local returning = sim.partProperty(i, "tmp3")

	if sim.partProperty(i, "life") > 0 then
		sim.pressure(x / sim.CELL, y / sim.CELL, sim.pressure(x / sim.CELL, y / sim.CELL) * 0.97)
	else
		sim.pressure(x / sim.CELL, y / sim.CELL, sim.pressure(x / sim.CELL, y / sim.CELL) * 0.8)
	end
	-- if (!parts[i].life && sim->pv[y/CELL][x/CELL]>1.0f)
	-- 	parts[i].life = RNG::Ref().between(300, 379);

	local vx = sim.partProperty(i, "vx")
	local vy = sim.partProperty(i, "vy")
	if math.sqrt(velx ^ 2 + vely ^ 2) > 0.1 then
		vx = vx + 0.1 * velx
		vy = vy + 0.1 * vely
	end
	local desx = sim.partProperty(i, "tmp")
	local desy = sim.partProperty(i, "tmp2")

	if round(x) - desx == 0 and round(y) - desy == 0 then
		sim.partProperty(i, "tmp3", math.max(returning - 1, 0))
	elseif temp > 273.15 + 60 then
		sim.partProperty(i, "temp", temp + 0.002 * (-temp))
		sim.partProperty(i, "tmp3", math.min(returning + 1, 30))
		sim.partProperty(i, "life", 30)
	else
		sim.partProperty(i, "tmp3", math.max(returning - 1, 0))
		sim.partProperty(i, "life", 30)
	end

	-- Permanently deform at very high temperatures
	if temp > 273.15 + 1700 then
		sim.partProperty(i, "tmp", x)
		sim.partProperty(i, "tmp2", y)
	end
	
	local overheat = 1 - math.max(temp - 273.15 - 1000, 0) / 800
	local seek = returning / 300 * overheat
	sim.partProperty(i, "vx", vx + seek * (desx - x + (math.random() - 0.5) * 0.1))
	sim.partProperty(i, "vy", vy + seek * (desy - y + (math.random() - 0.5) * 0.1))

	if returning > 0 then sim.partProperty(i, "life", 30) end
end)

elem.property(mmry, "Graphics", function (i, r, g, b)

	local glow = sim.partProperty(i, "tmp3") / 30
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
end -- Start of MELT scope


do -- Start of HALO scope
-- -# means special interaction
local halogenReactions = {
	[elem.DEFAULT_PT_RBDM] = elem.DEFAULT_PT_SALT,
	[elem.DEFAULT_PT_LRBD] = elem.DEFAULT_PT_SALT,
	[elem.DEFAULT_PT_LITH] = elem.DEFAULT_PT_SALT,
	[elem.DEFAULT_PT_WATR] = trtw,
	[elem.DEFAULT_PT_DSTW] = trtw,
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
	[elem.DEFAULT_PT_OIL] = plst, -- polyvinyl chloride (PVC)
}

local dontProduceHeat = {
	[elem.DEFAULT_PT_SPRK] = true,
	[elem.DEFAULT_PT_WATR] = true,
	[elem.DEFAULT_PT_DSTW] = true,
}

local noFire = {
	[elem.DEFAULT_PT_TUNG] = true,
	[trtw] = true,
	[lhal] = true,
	[halo] = true,
	[fhal] = true,
	[elem.DEFAULT_PT_DMND] = true,
	[elem.DEFAULT_PT_GLAS] = true,
	[elem.DEFAULT_PT_TTAN] = true,
	[elem.DEFAULT_PT_QRTZ] = true,
	[flor] = true,
	[pflr] = true,
	[elem.DEFAULT_PT_ACID] = true,
	[elem.DEFAULT_PT_CLST] = true,
	[plst] = true,
	[mpls] = true,
	[elem.DEFAULT_PT_GAS] = true,
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
	[elem.DEFAULT_PT_SPRK] = true,
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
elem.property(halo, "Description", "Halogens. Very reactive. Turns alkali metals into SALT and chlorinates water.")
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
		if n > 0 then
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
		sim.partProperty(i, "tmp", tmp - 1)
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

local trtwKill = {
	[elem.DEFAULT_PT_PLNT] = true,
	[elem.DEFAULT_PT_YEST] = true,
	[fngs] = true,
	[spor] = true,
}

local trtwDissolve = {
	[elem.DEFAULT_PT_ROCK] = true,
	[elem.DEFAULT_PT_BRCK] = true,
	[elem.DEFAULT_PT_STNE] = true,
	[elem.DEFAULT_PT_CNCT] = true,
}

local trtwSpread = {
	[elem.DEFAULT_PT_WATR] = true,
	[elem.DEFAULT_PT_DSTW] = true,
	[elem.DEFAULT_PT_SLTW] = true,
	[elem.DEFAULT_PT_FRZW] = true,
}

elem.element(trtw, elem.element(elem.DEFAULT_PT_DSTW))
elem.property(trtw, "Name", "TRTW")
elem.property(trtw, "Description", "Chemically treated water. Kills PLNT and slowly dissolves rocky materials. Not conductive.")
elem.property(trtw, "Colour", 0x0851E5)
elem.property(trtw, "Weight", 31)
elem.property(trtw, "Properties", elem.TYPE_LIQUID)
elem.property(trtw, "Update", function(i, x, y, s, n)

	local r = sim.pmap(x + math.random(-2, 2), y + math.random(-2, 2))
	if r ~= nil then
		local type = sim.partProperty(r, "type")
		if math.random(200) == 1 and trtwDissolve[type] then
			sim.partKill(r)
			if math.random(10) == 1 then
				sim.partKill(i)
			end
		end

		if math.random(250) == 1 and trtwSpread[type] then
			sim.partChangeType(r, trtw)
		end

		if trtwKill[type] then
			sim.partKill(r)
		end
	end
end)

elem.element(flor, elem.element(elem.DEFAULT_PT_QRTZ))
elem.property(flor, "Name", "FLOR")
elem.property(flor, "Description", "Fluorite. Can be refined into HALO. Fluoresces in blue light. Good for your chakras.")
elem.property(flor, "Colour", 0xBE6FB2)

elem.property(flor, "Create", function(i, x, y, t, v)
	sim.partProperty(i, "tmp", math.random(10) - 1)
end)

elem.property(elem.DEFAULT_PT_LAVA, "ChangeType", function(i, x, y, t1, t2)
	if t2 == flor then
		local pres = sim.pressure(x / sim.CELL, y / sim.CELL)
		sim.partProperty(i, "tmp3", pres * 10)
	end
	if t2 == mmry then
		sim.partProperty(i, "tmp", x)
		sim.partProperty(i, "tmp2", y)
	end
end)

local fluorineExciteMask = 0x000001FF
local fluorineWlMultiplier =  0x00200000
local fluorineTransmitMask = 0x000001FF * fluorineWlMultiplier

local function florUpdate(i, x, y, s, n)

	local emitWl = sim.partProperty(i, "ctype")
	if emitWl ~= 0 and math.random(4) == 1 then
		local np = sim.partCreate(-1, x, y, elem.DEFAULT_PT_PHOT)
		sim.partProperty(np, "ctype", emitWl)
		sim.partProperty(np, "temp", sim.partProperty(i, "temp"))
		local angle = math.random() * math.pi * 2
		sim.partProperty(np, "vx", math.cos(angle) * 3)
		sim.partProperty(np, "vy", math.sin(angle) * 3)
		sim.partProperty(i, "ctype", 0)
	end


	local photon = sim.photons(x, y)
	if photon and sim.partProperty(photon, "type") == elem.DEFAULT_PT_PHOT then
		local wl = sim.partProperty(photon, "ctype")
		local excited = bit.band(wl, fluorineExciteMask)
		if excited ~= 0 then
			sim.partProperty(i, "ctype", excited * fluorineWlMultiplier)
			sim.partProperty(photon, "ctype", 0)
		else
			local masked = bit.band(wl, fluorineTransmitMask)
			sim.partProperty(photon, "ctype", masked)
		end
	end

	if sim.partProperty(i, "type") == flor then
		local pres = sim.pressure(x / sim.CELL, y / sim.CELL)
		local tmp3 = sim.partProperty(i, "tmp3") / 10
		if pres > tmp3 + 1 then
			sim.partChangeType(i, pflr)
			sim.partProperty(i, "ctype", fluorineTransmitMask)
		end
		sim.partProperty(i, "tmp3", pres * 10)
	end

	if n > 0 then
		local r = sim.pmap(x + math.random(-2, 2), y + math.random(-2, 2))
		if r ~= nil then
			local type = sim.partProperty(r, "type")
			if type == elem.DEFAULT_PT_ACID or type == elem.DEFAULT_PT_CAUS then
				sim.partChangeType(i, elem.DEFAULT_PT_CLST)
				sim.partChangeType(r, halo)
				sim.partProperty(r, "life", 0)
			end
	
			if math.random(300) == 1 and trtwSpread[type] then
				sim.partChangeType(r, trtw)
				sim.partKill(i)
			end
		end
	end
end

local function florGraphics(i, r, g, b)
	local bright = (sim.partProperty(i, "tmp") - 4) * 10
	local colr = r + bright * 2
	local colg = g + bright * 1.7
	local colb = b + bright * 0.8
	
	local pixel_mode = ren.PMODE_FLAT

	if sim.partProperty(i, "ctype") > 0 then
		pixel_mode = ren.PMODE_FLAT + ren.PMODE_GLOW
	end

	return 0,pixel_mode,255,colr,colg,colb,120,colr,colg,colb;
end


elem.property(flor, "Update", florUpdate)
elem.property(flor, "Graphics", florGraphics)

elem.element(pflr, elem.element(elem.DEFAULT_PT_PQRT))
elem.property(pflr, "Name", "PFLR")
elem.property(pflr, "Description", "Powdered fluorite.")
elem.property(pflr, "Colour", 0xC67BC0)
elem.property(pflr, "HighTemperatureTransition", flor)
elem.property(pflr, "Create", function(i, x, y, t, v)
	sim.partProperty(i, "tmp", math.random(10) - 1)
end)

elem.property(pflr, "Update", florUpdate)
elem.property(pflr, "Graphics", florGraphics)

sim.can_move(elem.DEFAULT_PT_PHOT, flor, 2)
sim.can_move(elem.DEFAULT_PT_PHOT, pflr, 2)
end -- Start of HALO scope

do -- Start of NO32 scope
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

nobiliBrushState = 1
nobiliEasyWires = MANAGER.getsetting("FanElementsMod", "nobiliEasyWires") == "true"
nobiliLastWire = -1
nobiliNextLastWire = -1
nobiliJustPlaced = {}

-- Because multiple NO32 particles can be placed by the user in a single frame and there is no guarantee their IDs will line up
-- with the path they were drawn, iterate through all relevant particles placed by the user in the previous frame to make sure
-- that easy wires functions correctly in most realistic use cases.
event.register(event.tick, function()
	if #nobiliJustPlaced > 0 and nobiliLastWire >= 0 and sim.partExists(nobiliLastWire) and sim.partProperty(nobiliLastWire, "type") == no32 then
		local nobiliPmap = {}
		for i,j in pairs(nobiliJustPlaced) do
			local x, y = sim.partPosition(j)
			if not nobiliPmap[x] then nobiliPmap[x] = {} end
			nobiliPmap[x][y] = j
		end
		local x, y = sim.partPosition(nobiliLastWire)

		local iteration = 1000
		-- Navigate through the recently placed particles to order them properly
		-- This works well when drawing straight lines as long as you place a single pixel to start
		repeat
			iteration = iteration - 1
			for d = 1, 4 do
				local x1, y1 = x + vonNeumannNeighbors[d][1], y + vonNeumannNeighbors[d][2]
				if nobiliPmap[x1] ~= nil and nobiliPmap[x1][y1] ~= nil then
					x, y = x1, y1
					local iState = sim.partProperty(nobiliLastWire, "life")
					local iStateInfo = stateInfo[iState + 1]
					-- This should always be a transmission state (wire) but we check to make sure (it could've been deleted by an antiwire, for example)
					if iStateInfo[1] == 2 then
						local iStateDir = iStateInfo[2]
						local newState = iState - iStateDir + d
						sim.partProperty(nobiliLastWire, "life", newState)
					end
					nobiliLastWire = nobiliPmap[x][y]
					nobiliPmap[x][y] = nil
					goto continue
				end
			end
			do
				-- For some reason, Lua does not like this when it isn't inside a do-end block.
				break
			end
			::continue::
		until (iteration <= 0)
	end
	if #nobiliJustPlaced == 1 then
		nobiliLastWire = nobiliNextLastWire
	end
	nobiliJustPlaced = {}
end)

event.register(event.mousedown, function(x, y, button)
	if button == 2 then
		local ax, ay = sim.adjustCoords(x, y)
		local mp = sim.pmap(ax, ay)
		if mp and sim.partProperty(mp, "type") == no32 then
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

		local stateToDraw = nobiliBrushState
		if nobiliEasyWires then
			if stateInfo[stateToDraw + 1][1] == 2 then
				table.insert(nobiliJustPlaced, i)
				nobiliNextLastWire = i
			end
		end

		sim.partProperty(i, "life", stateToDraw)
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
		state = 0
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
	local partX, partY = sim.partPosition(i)
	local zoomX, zoomY, zoomPixels = ren.zoomScope()
	local zWinX, zWinY, zWinPxSize, zWinSize = ren.zoomWindow()
	
	local drawSize = zWinPxSize
	if drawSize % 2 == 1 then
		drawSize = drawSize + 1 -- Prevent odd numbers making the shapes look lopsided
	end
	if drawSize >= 8 and ren.zoomEnabled() and 
		partX >= zoomX and 
		partY >= zoomY and
		partX < zoomX + zoomPixels and
		partY < zoomY + zoomPixels then
		return 0,ren.PMODE_NONE,0,0,0,0,0,0,0,0;
	end

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
					local partX, partY = sim.partPosition(part);
					gfx.drawRect(partX, partY, 1, 1, colr,colg,colb, 256);
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
	local colr, colg, colb = graphics.getColors(nobiliStateColorMap[state + 1])
	table.insert(stateScreenShapes, {state, wx + x, wy + y, colr, colg, colb, 255})
end

stateScreenHelpText = {
	[[
Sensitized states are created when wires/antiwires try to charge an empty space.
They will evolve into the next state depending on whether they recieve a signal on each step.

You can read the tree in the state select menu to find the sequence of charges to create any state.
The pattern of charges is exactly the same regardless of direction or wire/anti-wire.]],
	[[
Wires transmit a current to the wire or connector they are directly facing.
You cannot split a signal using wires - use connectors to do that!
Place two wires facing each other to make a void that absorbs charges.]],
	[[
Anti-wires act like normal wires with a few different properties.
Anti-wires and wires are opposites. If one tries to conduct to the other, the other will be destroyed.
Additionally, anti-wires destroy connectors instead of charging them.
In all other ways, anti-wires are identical to normal wires.]],
	[[
Connectors accept signals from wires and then transmit to adjacent wires that do not face it directly.

If a connector is faced by multiple wires, it only conducts a signal if all of the wires are charged at once.
This can be used to create a simple AND gate.

Additionally, connectors with no outputs store their charge until an output is created.
Connectors can output to both wires and anti-wires.]],
	[[
When a connector is placed at the intersection of two wires, it acts as a crossroad.]],
}

stateScreenAnimationTimers = {
	0,
	0,
	0,
	0,
	0,
}

-- Animations are formatted as such:
-- [1] - X position
-- [2] - Y position
-- [3] - Ticks per frame
-- [4] - Final frame pause (ticks)
-- [5] - Frames (a table of tables of NO32 states indexed by y, then x)
stateScreenHelpAnimations = {
	{
		{
			500, 50, 60, 60,
			{
				{
					{ 0,	0,	0,	0,	0,	0,	0,	0,	0},
					{ 14,	14,	14,	14,	14,	14,	14,	14,	14},
					{ 10,	14,	10,	14,	10,	14,	10,	14,	10},
					{ 10,	10,	14,	14,	10,	10,	14,	14,	10},
					{ 10,	10,	10,	10,	14,	14,	14,	14,	10},
					{ 10,	10,	10,	10,	10,	10,	10,	10,	14}, },
				{
					{ 1,	1,	1,	1,	1,	1,	1,	1,	1},
					{ 10,	14,	10,	14,	10,	14,	10,	14,	10},
					{ 10,	10,	14,	14,	10,	10,	14,	14,	10},
					{ 10,	10,	10,	10,	14,	14,	14,	14,	10},
					{ 10,	10,	10,	10,	10,	10,	10,	10,	14},
					{ 10,	10,	10,	10,	10,	10,	10,	10,	10}, },
				{
					{ 2,	3,	2,	3,	2,	3,	2,	3,	2},
					{ 10,	10,	14,	14,	10,	10,	14,	14,	10},
					{ 10,	10,	10,	10,	14,	14,	14,	14,	10},
					{ 10,	10,	10,	10,	10,	10,	10,	10,	14},
					{ 10,	10,	10,	10,	10,	10,	10,	10,	10},
					{ 10,	10,	10,	10,	10,	10,	10,	10,	10}, },
				{
					{ 4,	6,	5,	7,	4,	6,	5,	7,	4},
					{ 10,	10,	10,	10,	14,	14,	14,	14,	10},
					{ 10,	10,	10,	10,	10,	10,	10,	10,	14},
					{ 10,	10,	10,	10,	10,	10,	10,	10,	10},
					{ 10,	10,	10,	10,	10,	10,	10,	10,	10},
					{ 10,	10,	10,	10,	10,	10,	10,	10,	10}, },
				{
					{ 8,	18,	12,	20,	11,	19,	17,	25,	8},
					{ 10,	10,	10,	10,	10,	10,	10,	10,	14},
					{ 10,	10,	10,	10,	10,	10,	10,	10,	10},
					{ 10,	10,	10,	10,	10,	10,	10,	10,	10},
					{ 10,	10,	10,	10,	10,	10,	10,	10,	10},
					{ 10,	10,	10,	10,	10,	10,	10,	10,	10}, },
				{
					{ 9,	18,	12,	20,	11,	19,	17,	25,	10},
					{ 10,	10,	10,	10,	10,	10,	10,	10,	10},
					{ 10,	10,	10,	10,	10,	10,	10,	10,	10},
					{ 10,	10,	10,	10,	10,	10,	10,	10,	10},
					{ 10,	10,	10,	10,	10,	10,	10,	10,	10},
					{ 10,	10,	10,	10,	10,	10,	10,	10,	10},
				},
			}
		},
		{
			30, 110, 30, 60,
			{
				{
					{ 13,	13,	9,	13,	0 },
					{ 0,	0,	0,	0,	0 },
					{ 21,	21,	17,	21,	0 }, },
				{
					{ 9,	13,	13,	9,	1 },
					{ 0,	 0,	0,	0,	0 },
					{ 17,	21,	21,	17,	1 }, },
				{
					{ 9,	9,	13,	13,	2 },
					{ 0,	 0,	0,	0,	0 },
					{ 17,	17,	21,	21,	2 }, },
				{
					{ 9,	9,	9,	13,	5 },
					{ 0,	 0,	0,	0,	0 },
					{ 17,	17,	17,	21,	5 }, },
				{
					{ 9,	9,	9,	9,	17 },
					{ 0,	 0,	0,	0,	0 },
					{ 17,	17,	17,	17,	17 }, },
			}
		},
		{
			130, 100, 30, 60,
			{
				{
					{ 0,	0,	16,	0,	0 },
					{ 0,	0,	0,	0,	0 },
					{ 13,	0,	0,	0,	15 },
					{ 0,	0,	0,	0,	0 },
					{ 0,	0,	14,	0,	0 }, },
				{
					{ 0,	0,	12,	0,	0 },
					{ 0,	0,	1,	0,	0 },
					{ 9,	1,	0,	1,	11 },
					{ 0,	0,	1,	0,	0 },
					{ 0,	0,	10,	0,	0 }, },
				{
					{ 0,	0,	12,	0,	0 },
					{ 0,	0,	2,	0,	0 },
					{ 9,	2,	0,	2,	11 },
					{ 0,	0,	2,	0,	0 },
					{ 0,	0,	10,	0,	0 }, },
				{
					{ 0,	0,	12,	0,	0 },
					{ 0,	0,	4,	0,	0 },
					{ 9,	4,	0,	4,	11 },
					{ 0,	0,	4,	0,	0 },
					{ 0,	0,	10,	0,	0 }, },
				{
					{ 0,	0,	12,	0,	0 },
					{ 0,	0,	8,	0,	0 },
					{ 9,	8,	0,	8,	11 },
					{ 0,	0,	8,	0,	0 },
					{ 0,	0,	10,	0,	0 }, },
				{
					{ 0,	0,	12,	0,	0 },
					{ 0,	0,	9,	0,	0 },
					{ 9,	9,	0,	9,	11 },
					{ 0,	0,	9,	0,	0 },
					{ 0,	0,	10,	0,	0 }, },
			}
		}
	},
	{
		{
			400, 10, 20, 0,
			{
				{
					{ 13,	9,	9,	9,	9,	9 }, },
				{
					{ 9,	13,	9,	9,	9,	9 }, },
				{
					{ 9,	9,	13,	9,	9,	9 }, },
				{
					{ 9,	9,	9,	13,	9,	9 }, },
				{
					{ 9,	9,	9,	9,	13,	9 }, },
				{
					{ 9,	9,	9,	9,	9,	13 }, },
			}
		},
		{
			30, 60, 20, 30,
			{
				{
					{ 0,	0,	0,	10,	0,	0,	0,	0,	0,	10 },
					{ 13,	9,	9,	9,	0,	0,	13,	9,	9,	10 }, },
				{
					{ 0,	0,	0,	10,	0,	0,	0,	0,	0,	10 },
					{ 9,	13,	9,	9,	0,	0,	9,	13,	9,	10 }, },
				{
					{ 0,	0,	0,	10,	0,	0,	0,	0,	0,	10 },
					{ 9,	9,	13,	9,	0,	0,	9,	9,	13,	10 }, },
				{
					{ 0,	0,	0,	10,	0,	0,	0,	0,	0,	10 },
					{ 9,	9,	9,	13,	0,	0,	9,	9,	9,	14 }, },
				{
					{ 0,	0,	0,	10,	0,	0,	0,	0,	0,	14 },
					{ 9,	9,	9,	9,	1,	0,	9,	9,	9,	10 }, },
			}
		},
		{
			200, 60, 40, 60,
			{
				{
					{ 13,	9,	9,	11 },
					{ 13,	9,	9,	0 }, },
				{
					{ 9,	13,	9,	11 },
					{ 9,	13,	9,	0 }, },
				{
					{ 9,	9,	13,	11 },
					{ 9,	9,	13,	0 }, },
				{
					{ 9,	9,	9,	11 },
					{ 9,	9,	9,	1 }, },
			}
		},
		{
			300, 60, 40, 60,
			{
				{
					{ 0,	0,	10,	0,	0,	10,	0,	0 },
					{ 13,	9,	25,	0,	0,	11,	11,	15 },
					{ 0,	0,	12,	0,	0,	12,	0,	0 }, },
				{
					{ 0,	0,	10,	0,	0,	10,	0,	0 },
					{ 9,	13,	25,	0,	0,	11,	15,	11 },
					{ 0,	0,	12,	0,	0,	12,	0,	0 }, },
				{
					{ 0,	0,	10,	0,	0,	10,	0,	0 },
					{ 9,	9,	26,	0,	0,	15,	11,	11 },
					{ 0,	0,	12,	0,	0,	12,	0,	0 }, },
				{
					{ 0,	0,	10,	0,	0,	10,	0,	0 },
					{ 9,	9,	27,	0,	1,	11,	11,	11 },
					{ 0,	0,	12,	0,	0,	12,	0,	0 }, },
				{
					{ 0,	0,	14,	0,	0,	10,	0,	0 },
					{ 9,	9,	25,	0,	2,	11,	11,	11 },
					{ 0,	0,	16,	0,	0,	12,	0,	0 }, },
			}
		},
	},
	{
		{
			30, 80, 20, 0,
			{
				{
					{ 21,	17,	17,	17,	17,	17 }, },
				{
					{ 17,	21,	17,	17,	17,	17 }, },
				{
					{ 17,	17,	21,	17,	17,	17 }, },
				{
					{ 17,	17,	17,	21,	17,	17 }, },
				{
					{ 17,	17,	17,	17,	21,	17 }, },
				{
					{ 17,	17,	17,	17,	17,	21 }, },
			}
		},
		{
			500, 50, 20, 60,
			{
				{
					{ 0,	12,	11,	11,	15 },
					{ 0,	12,	0,	18,	0 },
					{ 21,	17,	17,	18,	0 }, },
				{
					{ 0,	12,	11,	15,	11 },
					{ 0,	12,	0,	18,	0 },
					{ 17,	21,	17,	18,	0 }, },
				{
					{ 0,	12,	15,	11,	11 },
					{ 0,	12,	0,	18,	0 },
					{ 17,	17,	21,	18,	0 }, },
				{
					{ 0,	16,	11,	11,	11 },
					{ 0,	12,	0,	18,	0 },
					{ 17,	17,	17,	18,	0 }, },
				{
					{ 0,	12,	11,	11,	11 },
					{ 0,	16,	0,	22,	0 },
					{ 17,	17,	17,	18,	0 }, },
				{
					{ 0,	12,	11,	0,	11 },
					{ 0,	12,	0,	18,	0 },
					{ 17,	0,	17,	18,	0 }, },
			}
		},
		{
			350, 50, 20, 40,
			{
				{
					{ 0,	0,	12,	0,	0 },
					{ 0,	0,	10,	0,	0 },
					{ 13,	9,	25,	19,	19 }, },
				{
					{ 0,	0,	12,	0,	0 },
					{ 0,	0,	10,	0,	0 },
					{ 9,	13,	25,	19,	19 }, },
				{
					{ 0,	0,	12,	0,	0 },
					{ 0,	0,	10,	0,	0 },
					{ 9,	9,	26,	19,	19 }, },
				{
					{ 0,	0,	12,	0,	0 },
					{ 0,	0,	10,	0,	0 },
					{ 9,	9,	27,	19,	19 }, },
				{
					{ 0,	0,	12,	0,	0 },
					{ 0,	0,	14,	0,	0 },
					{ 9,	9,	25,	19,	19 }, },
				{
					{ 0,	0,	12,	0,	0 },
					{ 0,	0,	10,	0,	0 },
					{ 9,	9,	25,	19,	19 }, },
				{
					{ 0,	0,	12,	0,	0 },
					{ 0,	0,	10,	0,	0 },
					{ 9,	9,	25,	19,	23 }, },
				{
					{ 0,	0,	12,	0,	0 },
					{ 0,	0,	10,	0,	0 },
					{ 9,	9,	25,	23,	19 }, },
				{
					{ 0,	0,	12,	0,	0 },
					{ 0,	0,	10,	0,	0 },
					{ 9,	9,	0,	19,	19 }, },
			}
		},
	},
	{ -- Connector (confluent) state
		{
			550, 40, 20, 60,
			{
				{
					{ 0,	16,	0 },
					{ 0,	12,	0 },
					{ 11,	25,	9 },
					{ 0,	12,	0 }, },
				{
					{ 0,	12,	0 },
					{ 0,	16,	0 },
					{ 11,	25,	9 },
					{ 0,	12,	0 }, },
				{
					{ 0,	12,	0 },
					{ 0,	12,	0 },
					{ 11,	26,	9 },
					{ 0,	12,	0 }, },
				{
					{ 0,	12,	0 },
					{ 0,	12,	0 },
					{ 11,	27,	9 },
					{ 0,	12,	0 }, },
				{
					{ 0,	12,	0 },
					{ 0,	12,	0 },
					{ 15,	25,	13 },
					{ 0,	16,	0 }, },
			}
		},
		{
			450, 50, 20, 60,
			{
				{
					{ 0,	12,	15 },
					{ 11,	25,	0 },
					{ 0,	10,	11 }, },
				{
					{ 0,	16,	11 },
					{ 11,	25,	0 },
					{ 0,	10,	11 }, },
				{
					{ 0,	12,	11 },
					{ 11,	25,	0 },
					{ 0,	10,	11 }, },
				{
					{ 0,	12,	11 },
					{ 11,	25,	0 },
					{ 0,	10,	15 }, },
				{
					{ 0,	12,	11 },
					{ 11,	25,	0 },
					{ 0,	14,	11 }, },
				{
					{ 0,	12,	11 },
					{ 11,	25,	0 },
					{ 0,	10,	11 }, },
				{
					{ 0,	12,	15 },
					{ 11,	25,	0 },
					{ 0,	10,	15 }, },
				{
					{ 0,	16,	11 },
					{ 11,	25,	0 },
					{ 0,	14,	11 }, },
				{
					{ 0,	12,	11 },
					{ 11,	26,	0 },
					{ 0,	10,	11 }, },
				{
					{ 0,	12,	11 },
					{ 11,	27,	0 },
					{ 0,	10,	11 }, },
				{
					{ 0,	12,	11 },
					{ 15,	25,	0 },
					{ 0,	10,	11 }, },
			}
		},
		{
			30, 100, 20, 60,
			{
				{
					{ 0,	0,	0,	12,	0 },
					{ 13,	13,	25,	0,	9 }, },
				{
					{ 0,	0,	0,	12,	0 },
					{ 9,	13,	26,	0,	9 }, },
				{
					{ 0,	0,	0,	12,	0 },
					{ 9,	9,	28,	0,	9 }, },
				{
					{ 0,	0,	0,	16,	0 },
					{ 9,	9,	28,	0,	9 }, },
				{
					{ 0,	0,	0,	12,	0 },
					{ 9,	9,	28,	1,	9 }, },
				{
					{ 0,	0,	0,	12,	0 },
					{ 9,	9,	28,	2,	9 }, },
				{
					{ 0,	0,	0,	12,	0 },
					{ 9,	9,	28,	4,	9 }, },
				{
					{ 0,	0,	0,	12,	0 },
					{ 9,	9,	28,	8,	9 }, },
				{
					{ 0,	0,	0,	12,	0 },
					{ 9,	9,	28,	9,	9 }, },
				{
					{ 0,	0,	0,	12,	0 },
					{ 9,	9,	27,	13,	9 }, },
				{
					{ 0,	0,	0,	12,	0 },
					{ 9,	9,	25,	13,	13 }, },
			}
		},
		{
			130, 100, 30, 60,
			{
				{
					{ 19,	19,	25,	9,	9 },
					{ 0,	0,	14,	0,	0 }, },
				{
					{ 19,	19,	26,	9,	9 },
					{ 0,	0,	10,	0,	0 }, },
				{
					{ 19,	19,	27,	9,	9 },
					{ 0,	0,	10,	0,	0 }, },
				{
					{ 19,	23,	25,	13,	9 },
					{ 0,	0,	10,	0,	0 }, },
				{
					{ 23,	19,	25,	9,	13 },
					{ 0,	0,	10,	0,	0 }, },
			}
		},
	},
	{
		{
			30, 30, 20, 60,
			{
				{
					{ 0,	0,	12,	0,	0 },
					{ 0,	0,	10,	0,	0 },
					{ 13,	9,	25,	9,	11 },
					{ 0,	0,	10,	0,	0 },
					{ 0,	0,	10,	0,	0 }, },
				{
					{ 0,	0,	12,	0,	0 },
					{ 0,	0,	10,	0,	0 },
					{ 9,	13,	25,	9,	11 },
					{ 0,	0,	10,	0,	0 },
					{ 0,	0,	10,	0,	0 }, },
				{
					{ 0,	0,	12,	0,	0 },
					{ 0,	0,	10,	0,	0 },
					{ 9,	9,	29,	9,	11 },
					{ 0,	0,	10,	0,	0 },
					{ 0,	0,	10,	0,	0 }, },
				{
					{ 0,	0,	12,	0,	0 },
					{ 0,	0,	10,	0,	0 },
					{ 9,	9,	25,	13,	11 },
					{ 0,	0,	10,	0,	0 },
					{ 0,	0,	10,	0,	0 }, },
				{
					{ 0,	0,	12,	0,	0 },
					{ 0,	0,	10,	0,	0 },
					{ 9,	9,	25,	9,	11 },
					{ 0,	0,	10,	0,	0 },
					{ 0,	0,	14,	0,	0 }, },
				{
					{ 0,	0,	12,	0,	0 },
					{ 0,	0,	10,	0,	0 },
					{ 9,	9,	25,	9,	11 },
					{ 0,	0,	14,	0,	0 },
					{ 0,	0,	10,	0,	0 }, },
				{
					{ 0,	0,	12,	0,	0 },
					{ 0,	0,	10,	0,	0 },
					{ 9,	9,	30,	9,	11 },
					{ 0,	0,	10,	0,	0 },
					{ 0,	0,	10,	0,	0 }, },
				{
					{ 0,	0,	12,	0,	0 },
					{ 0,	0,	14,	0,	0 },
					{ 9,	9,	25,	9,	11 },
					{ 0,	0,	10,	0,	0 },
					{ 0,	0,	10,	0,	0 }, },
				{
					{ 0,	0,	12,	0,	0 },
					{ 0,	0,	10,	0,	0 },
					{ 13,	9,	25,	9,	11 },
					{ 0,	0,	10,	0,	0 },
					{ 0,	0,	14,	0,	0 }, },
				{
					{ 0,	0,	12,	0,	0 },
					{ 0,	0,	10,	0,	0 },
					{ 9,	13,	25,	9,	11 },
					{ 0,	0,	14,	0,	0 },
					{ 0,	0,	10,	0,	0 }, },
				{
					{ 0,	0,	12,	0,	0 },
					{ 0,	0,	10,	0,	0 },
					{ 9,	9,	31,	9,	11 },
					{ 0,	0,	10,	0,	0 },
					{ 0,	0,	10,	0,	0 }, },
				{
					{ 0,	0,	12,	0,	0 },
					{ 0,	0,	14,	0,	0 },
					{ 9,	9,	25,	13,	11 },
					{ 0,	0,	10,	0,	0 },
					{ 0,	0,	10,	0,	0 }, },
				{
					{ 0,	0,	12,	0,	0 },
					{ 0,	0,	10,	0,	0 },
					{ 9,	9,	25,	9,	11 },
					{ 0,	0,	10,	0,	0 },
					{ 0,	0,	10,	0,	0 }, },
			}
		},
	},
}

stateScreenStateMap = {
	[0] = {},

	[1] = {1},
	[2] = {1},
	[3] = {1},
	[4] = {1},
	[5] = {1},
	[6] = {1},
	[7] = {1},
	[8] = {1},
	
	[9] = {2},
	[10] = {2},
	[11] = {2},
	[12] = {2},
	[13] = {2},
	[14] = {2},
	[15] = {2},
	[16] = {2},
	
	[17] = {3},
	[18] = {3},
	[19] = {3},
	[20] = {3},
	[21] = {3},
	[22] = {3},
	[23] = {3},
	[24] = {3},
	
	[25] = {4},
	[26] = {4},
	[27] = {4},
	[28] = {4},

	[29] = {5},
	[30] = {5},
	[31] = {5},
}

event.register(event.keypress, function(key, scan, rep, shift, ctrl, alt)
	if ctrl and tpt.selectedl == "FANMOD_PT_NO32" and key == 115 then -- S 
		local stateSelectWindow = Window:new(-1, -1, 200, 220)

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
		
		local lastHoveredState = -1

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

			if lastHoveredState ~= -1 then
				graphics.drawText(10, 10, stateScreenHelpText[stateScreenStateMap[lastHoveredState][1]])

				for k,l in pairs(stateScreenHelpAnimations[stateScreenStateMap[lastHoveredState][1]]) do

					local x, y = l[1], l[2]
					local frames = l[5]
					local tpf = l[3] -- Ticks per frame
					local lfp = l[4] -- Last frame pause
					local animTimer = stateScreenAnimationTimers[k]
					local framenum = math.min(math.floor(animTimer / tpf) + 1, #frames)
					if animTimer > #frames * tpf + lfp then
						stateScreenAnimationTimers[k] = 0
					else
						stateScreenAnimationTimers[k] = animTimer + 1
					end

					local framedata = frames[framenum]
					for m,n in pairs(framedata) do
						for o,p in pairs(n) do
							local colr, colg, colb = graphics.getColors(nobiliStateColorMap[p + 1])
							nobiliStateDrawFunctions[p + 1](x + (o - 1) * 10, y + (m - 1) * 10, 8, colr, colg, colb, 255)
						end
					end

				end
			end
		end)
	
		stateSelectWindow:onMouseDown(function(x, y, button)
			for i,j in pairs(stateScreenShapes) do
				local bx = j[2]
				local by = j[3]
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
				local bx = j[2]
				local by = j[3]
				local bw, bh = buttonSize, buttonSize
				if x >= bx and y >= by and x <= bx + bw and y <= by + bh then
					titleLabel:text(simpleStateNames[j[1] + 1])
					lastHoveredState = j[1]
					break
				end
				-- lastHoveredState = -1
				titleLabel:text("Nobili32 State Select")
			end
		
		end)

		local autoWireButton = Button:new(20, 195, 160, 16)
		autoWireButton:action(
			function(sender)
				nobiliEasyWires = not nobiliEasyWires
				if nobiliEasyWires then
					autoWireButton:text("Easy Wires ON")
				else
					autoWireButton:text("Easy Wires OFF")
				end
				MANAGER.savesetting("FanElementsMod", "nobiliEasyWires", nobiliEasyWires)
			end)
		autoWireButton:text(nobiliEasyWires and "Easy Wires ON" or "Easy Wires OFF")
		stateSelectWindow:addComponent(autoWireButton)


		interface.showWindow(stateSelectWindow)
		stateSelectWindow:onTryExit(function()
			interface.closeWindow(stateSelectWindow)
		end)
		return false
	end
end)  
end -- End of NO32 scope

do -- Start of LNCR scope
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
						
						local lct = sim.partProperty(i, "tmp3")
						if lct > 0 then
							sim.partProperty(launched, "ctype", lct)
						end
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
		if not sim.partExists(launcherConfigID) then
			launcherConfigActive = false
			launcherConfigID = -1
			return
		end

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
end -- End of LNCR scope

-- This is accessed by other elements
local bulletTypeFunctions

do -- Start of AMMO scope
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
	-- Basic types
	[elem.DEFAULT_PT_EMBR] = {true, nil, nil, 50, 0, 0, 2},
	[elem.DEFAULT_PT_FIRE] = {false, nil, nil, nil, nil, nil, 3},
	[elem.DEFAULT_PT_CFLM] = {false, -1, nil, nil, nil, nil, 3},
	[elem.DEFAULT_PT_PLSM] = {true, nil, 0, 60, nil, nil, 3}, -- Makes sure this isn't the same as FIRE
	[elem.DEFAULT_PT_LAVA] = {false, nil, nil, nil, nil, nil, 3},
	[elem.DEFAULT_PT_BOYL] = {true, nil, nil, nil, nil, nil, 3},

	-- Instant explode/activate types
	  -- Activated by temperature
	[elem.DEFAULT_PT_TNT] = {true, 1000, nil, nil, nil, nil, 5},
	[elem.DEFAULT_PT_PLEX] = {true, 1000, nil, nil, nil, nil, 5}, -- C-4, not this script's PLEX.
	[elem.DEFAULT_PT_C5] = {true, 0, nil, nil, nil, nil, 5},
	[stgm] = {true, 7000, -256, nil, 90, nil, 5},

	  -- Activated by contact
	[elem.DEFAULT_PT_THDR] = {true, nil, nil, nil, nil, nil, 1},
	[elem.DEFAULT_PT_BOMB] = {true, nil, nil, nil, nil, nil, 1},
	[elem.DEFAULT_PT_DEST] = {true, nil, -30, 30, nil, nil, 2},
	[elem.DEFAULT_PT_DMG] = {true, nil, nil, nil, nil, nil, 1},
	[elem.DEFAULT_PT_COAL] = {true, nil, nil, 99, nil, nil, 3},
	[elem.DEFAULT_PT_BCOL] = {true, nil, nil, 99, nil, nil, 3},
	[elem.DEFAULT_PT_LITH] = {true, nil, nil, 1016, nil, nil, 3},

	  -- Activated by modifying some property
	[elem.DEFAULT_PT_GBMB] = {true, nil, nil, 60, nil, nil, 2},
	[elem.DEFAULT_PT_VIBR] = {true, nil, nil, 2, 0, nil, 2},
	[elem.DEFAULT_PT_BVBR] = {true, nil, nil, 2, 0, nil, 2},
	[elem.DEFAULT_PT_SING] = {true, nil, nil, 0, 100, nil, 2},
	[elem.DEFAULT_PT_FWRK] = {true, nil, nil, 2, nil, nil, 2},
	[elem.DEFAULT_PT_FIRW] = {true, nil, nil, nil, 2, nil, 2},
	[elem.DEFAULT_PT_FUSE] = {false, nil, nil, 39, nil, nil, 5},
	[elem.DEFAULT_PT_FSEP] = {false, nil, nil, 39, nil, nil, 5},
	[elem.DEFAULT_PT_IGNC] = {false, -1, nil, 500, 1, nil, 3}, -- Classic flare brick material
	[fuel] = {false, nil, nil, 600, nil, nil, 5},
	[bgph] = {false, nil, nil, 59, 30, nil, 5},

	  -- Other activation methods
	[plex] = {true, nil, 0, nil, nil, nil, 8},
	[elem.DEFAULT_PT_HYGN] = {true, 10000, 256, nil, nil, nil, 10}, -- FUSION

	-- Growth/expansion types
	[elem.DEFAULT_PT_DEUT] = {false, nil, nil, 300, nil, nil, 2},
	[elem.DEFAULT_PT_MERC] = {false, nil, nil, nil, 300, nil, 2},
	[elem.DEFAULT_PT_SPNG] = {false, 295.15, nil, 100, nil, nil, 4},
	[elem.DEFAULT_PT_QRTZ] = {false, -1, 1, nil, 100, nil, 2},
	[elem.DEFAULT_PT_SHLD] = {false, -1, 0, nil, nil, nil, 2},
	[elem.DEFAULT_PT_YEST] = {false, 316.99, nil, nil, nil, nil, 10},
	
	-- Conversion types
	[elem.DEFAULT_PT_GOLD] = {true, 295.15, nil, nil, nil, nil, 4, true},
	[elem.DEFAULT_PT_AMTR] = {true, nil, nil, nil, nil, nil, 4, true},
	[elem.DEFAULT_PT_ICE] = {true, 0, -4, nil, nil, nil, 6, true},
	
	-- Radiation types
	[elem.DEFAULT_PT_PHOT] = {false, nil, nil, nil, nil, nil, 6},
	[elem.DEFAULT_PT_PROT] = {false, nil, nil, nil, nil, nil, 6},
	[elem.DEFAULT_PT_ELEC] = {false, nil, nil, nil, nil, nil, 6},
	[elem.DEFAULT_PT_GRVT] = {false, nil, nil, nil, nil, nil, 6},
	[elem.DEFAULT_PT_NEUT] = {false, nil, nil, nil, nil, nil, 6},

	-- Special types
	[elem.DEFAULT_PT_VOID] = {true, nil, -1000, nil, nil, nil, 15},
	[elem.DEFAULT_PT_DMND] = {true, nil, nil, nil, nil, nil, 3},
	
	-- Miscellaneous
	[elem.DEFAULT_PT_URAN] = {true, 10000, nil, nil, nil, nil, 2},
	[elem.DEFAULT_PT_PLUT] = {true, 10000, 1000, nil, nil, nil, 6},

	[elem.DEFAULT_PT_BHOL] = {true, nil, -1000, nil, nil, nil, 0},
	[elem.DEFAULT_PT_WHOL] = {true, nil, 1000, nil, nil, nil, 0},

	[elem.DEFAULT_PT_LIGH] = {false, -1, nil, 20, nil, nil, 3},

	[fngs] = {false, -1, nil, nil, nil, nil, 5},
}

bulletTypeFunctions = {
	[elem.DEFAULT_PT_DRAY] = function(i)
		if math.random() > 0.5 then -- DRAY bomb
			sim.partProperty(i, "type", elem.DEFAULT_PT_SPRK)
			sim.partProperty(i, "ctype", elem.DEFAULT_PT_METL)
			sim.partProperty(i, "life", 4)
		end
	end,
	[elem.DEFAULT_PT_EMP] = function(i)
		if math.random() > 0.5 then
			sim.partProperty(i, "type", elem.DEFAULT_PT_SPRK)
			sim.partProperty(i, "ctype", elem.DEFAULT_PT_METL)
			sim.partProperty(i, "life", 4)
		end
	end,
	[plex] = function(i)
		if math.random() > 0.9 then
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
	[elem.DEFAULT_PT_LIGH] = function(i)
		sim.partProperty(i, "tmp", math.random(0, 359))
	end,
	[elem.DEFAULT_PT_SHLD] = function(i)
		sim.partChangeType(i, elem.DEFAULT_PT_SHD3)
		sim.partProperty(i, "life", 100)
	end,
	[trit] = function(i)
		sim.partProperty(i, "tmp", math.random(20))
	end,
	[elem.DEFAULT_PT_WARP] = function(i)
		sim.partProperty(i, "tmp2", 10000)
	end,
	[elem.DEFAULT_PT_PLUT] = function(i)
		if math.random() > 0.5 then
			sim.partProperty(i, "type", elem.DEFAULT_PT_NEUT)
			sim.partProperty(i, "life", 60)
		end
	end,
	-- FNGS has a special function too, but it's defined later
}

local stkmAmmoFire
local stk2AmmoFire

local stkmAlive
local stk2Alive

local stkmAmmoMode
local stk2AmmoMode

event.register(event.beforesim, function()
	
	stkmAlive = false
	stk2Alive = false
end)

event.register(event.keypress, function(key, scan, rep, shift, ctrl, alt)
	if stkmAlive and stkmAmmoMode == shot and key == interface.SDLK_DOWN and not rep then
		stkmAmmoFire = true
		return false
	end
	if stk2Alive and stk2AmmoMode == shot and key == interface.SDLK_s and not rep then
		stk2AmmoFire = true
		return false
	end
end)  

local stkmShotPower = 50

local function fireAmmoAtMouseFromParticle(i)
	local x, y = sim.partPosition(i)
	local mx, my = sim.adjustCoords(tpt.mousex, tpt.mousey)
	local dx, dy = mx - x, my - y
	local mag = math.sqrt(dx ^ 2 + dy ^ 2)
	local nx, ny = dx / mag, dy / mag
	local bullet = sim.partCreate(-1, x, y, shot)

	sim.partProperty(bullet, "vx", nx * stkmShotPower)
	sim.partProperty(bullet, "vy", ny * stkmShotPower)
end

elem.property(elem.DEFAULT_PT_STKM, "Update", function(i, x, y, s, n)
	stkmAlive = true
	local ammoMode = sim.partProperty(i, "ctype")
	if stkmAmmoMode == shot and ammoMode == elem.DEFAULT_PT_EMBR then
		sim.partProperty(i, "ctype", shot)
	else
		stkmAmmoMode = ammoMode
	end

	if stkmAmmoFire then
		fireAmmoAtMouseFromParticle(i)
		stkmAmmoFire = false
	end
end)

elem.property(elem.DEFAULT_PT_STK2, "Update", function(i, x, y, s, n)
	stk2Alive = true
	local ammoMode = sim.partProperty(i, "ctype")
	if stk2AmmoMode == shot and ammoMode == elem.DEFAULT_PT_EMBR then
		sim.partProperty(i, "ctype", shot)
	else
		stk2AmmoMode = ammoMode
	end

	if stk2AmmoFire then
		fireAmmoAtMouseFromParticle(i)
		stk2AmmoFire = false
	end
end)

elem.element(shot, elem.element(elem.DEFAULT_PT_CNCT))
elem.property(shot, "Name", "AMMO")
elem.property(shot, "Description", "Bullet. Damages materials when accelerated to high speeds.")
elem.property(shot, "Colour", 0xFDC43F)
elem.property(shot, "Collision", 0)
elem.property(shot, "Loss", 0.99)
elem.property(shot, "Gravity", 0.7)
elem.property(shot, "HighTemperatureTransition", -1)
elem.property(shot, "MenuSection", elem.SC_EXPLOSIVE)

elem.property(shot, "Create", function(i, x, y, t, v)
	if v == 0 and elem[tpt.selectedr] then -- Use right click element as ctype
		sim.partProperty(i, "ctype", elem[tpt.selectedr])
	end
end)
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
end -- End of AMMO scope

do -- Start of RSET scope
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
local function resetParticle(i, x, y, ntype, nctype, ctype, modeVel, modeTemp, modeCtype)
	if not unresettable[ntype] and (ctype == 0 or ntype == ctype) then
		if modeVel then
			resetVx = sim.partProperty(i, "vx")
			resetVy = sim.partProperty(i, "vy")
		end

		if modeTemp then
			resetTemp = sim.partProperty(i, "temp")
		end

		if modeCtype then
			resetCtype = sim.partProperty(i, "ctype")
			sim.partCreate(i, x, y, ntype)
			sim.partProperty(i, "ctype", resetCtype)
		else
			sim.partCreate(i, x, y, resetByCtype[ntype] and nctype ~= 0 and nctype or ntype)
		end

		if modeVel then
			sim.partProperty(i, "vx", resetVx)
			sim.partProperty(i, "vy", resetVy)
		end
		if modeTemp then
			sim.partProperty(i, "temp", resetTemp)
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
elem.property(rset, "Description", "Resetter. Resets particle properties to default on contact. Shift-click to configure.")
elem.property(rset, "Colour", 0xFE31AF)
elem.property(rset, "MenuSection", elem.SC_SPECIAL)
elem.property(rset, "Update", function(i, x, y, s, n)
	if s ~= n then -- Extremely sexy optimization
		local ctype = sim.partProperty(i, "ctype")
		local life = sim.partProperty(i, "life")
		modeVel, modeTemp, modeCtype = bit.band(life, 0x1) ~= 0, bit.band(life, 0x2) ~= 0, bit.band(life, 0x4) ~= 0
		-- print(modeVel, modeTemp, modeCtype)
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
									resetParticle(k, rx, ry, stype, sctype, ctype, modeVel, modeTemp, modeCtype)
								else

								end
							end
						end
					end

					resetParticle(id, x + cx, y + cy, ntype, nctype, ctype, modeVel, modeTemp, modeCtype)
				end
			end
		end
	end
end)

elem.property(rset, "CtypeDraw", function(i, t)
	if bit.band(elem.property(t, "Properties"), elem.PROP_NOCTYPEDRAW) == 0 then
		sim.partProperty(i, "ctype", t)
	end
end)


-- RSET configuration interface
event.register(event.mousedown, function(x, y, button)
	local underMouse = sim.pmap(sim.adjustCoords(x, y))
	if shiftHeld and underMouse and sim.partProperty(underMouse, "type") == rset then
		shiftHeld = false

		local tmp = sim.partProperty(underMouse, "life")
		
		local vel = bit.band(tmp, 0x1)
		local temp = bit.band(tmp, 0x2) / 0x2
		local ctype = bit.band(tmp, 0x4) / 0x4

		local rsetConfigWindow = Window:new(-1, -1, 150, 66)

		local velCheckbox = Checkbox:new(10, 10, 180, 16, "Keep old velocity")
		velCheckbox:action(
			function(sender, checked)
				vel = checked and 1 or 0
			end)
			velCheckbox:checked(vel == 1)
		rsetConfigWindow:addComponent(velCheckbox)

		local tempCheckbox = Checkbox:new(10, 25, 180, 16, "Keep old temperature")
		tempCheckbox:action(
			function(sender, checked)
				temp = checked and 1 or 0
			end)
			tempCheckbox:checked(temp == 1)
		rsetConfigWindow:addComponent(tempCheckbox)

		local ctypeCheckbox = Checkbox:new(10, 40, 180, 16, "Keep old ctype")
		ctypeCheckbox:action(
			function(sender, checked)
				ctype = checked and 1 or 0
			end)
			ctypeCheckbox:checked(ctype == 1)
		rsetConfigWindow:addComponent(ctypeCheckbox)

		rsetConfigWindow:onTryExit(function()
			sim.takeSnapshot()
			sim.partProperty(underMouse, "life", vel * 0x1 + temp * 0x2 + ctype * 0x4)
			interface.closeWindow(rsetConfigWindow)
		end)
		interface.showWindow(rsetConfigWindow)
		return false
	end
end) 
end -- End of RSET scope

do -- Start of FUEL scope
local partCheckProportion = 0.04

event.register(event.aftersim, function()
	-- Are any of the reactants actually present in the simulation?
	if sim.elementCount(elem.DEFAULT_PT_DESL) > 0 and sim.elementCount(elem.DEFAULT_PT_FSEP) > 0 then
		for i=0,10000 do
	
			local id = math.random(0, 235007)
			if sim.partExists(id) and sim.partProperty(id, "type") == elem.DEFAULT_PT_DESL then
				local x, y = sim.partPosition(id)
				local cx, cy = x + math.random(3) - 2, y + math.random(3) - 2
				local r = sim.pmap(cx, cy)
				if r and sim.partProperty(r, "type") == elem.DEFAULT_PT_FSEP then
					sim.partKill(r)
					sim.partChangeType(id, fuel)
				end
			end
		end

	end
end)

local fuelNonstick = {
	[fuel] = true,
	[elem.DEFAULT_PT_DMND] = true,
	[elem.DEFAULT_PT_CLNE] = true,
	[lncr] = true,
	[elem.DEFAULT_PT_VOID] = true,
	[elem.DEFAULT_PT_CONV] = true,
	[elem.DEFAULT_PT_VACU] = true,
	[elem.DEFAULT_PT_VENT] = true,
	[elem.DEFAULT_PT_NBHL] = true,
	[elem.DEFAULT_PT_NWHL] = true,
	[elem.DEFAULT_PT_PRTI] = true,
	[elem.DEFAULT_PT_PRTO] = true,
	[elem.DEFAULT_PT_VIBR] = true,
	[elem.DEFAULT_PT_PIPE] = true,
	[elem.DEFAULT_PT_PPIP] = true,
	[elem.DEFAULT_PT_SAWD] = true,
	[elem.DEFAULT_PT_GOLD] = true,
	[elem.DEFAULT_PT_PTNM] = true,
	[copp] = true,
	[elem.DEFAULT_PT_DESL] = true,
	[elem.DEFAULT_PT_FSEP] = true,
}

elem.property(elem.DEFAULT_PT_DESL, "Weight", 20)
elem.property(elem.DEFAULT_PT_SOAP, "Weight", 18)

elem.element(fuel, elem.element(elem.DEFAULT_PT_GEL))
elem.property(fuel, "Name", "FUEL")
elem.property(fuel, "Description", "Rocket fuel. Burns with high pressure and heat. Hard to ignite.")
elem.property(fuel, "Colour", 0x650B00)
elem.property(fuel, "MenuSection", elem.SC_EXPLOSIVE)
elem.property(fuel, "Advection", 0.01)
elem.property(fuel, "Weight", 19)
elem.property(fuel, "HotAir", -0.0002)
elem.property(fuel, "Properties", elem.TYPE_LIQUID + elem.PROP_LIFE_DEC)
elem.property(fuel, "Update", function(i, x, y, s, n)

	local life = sim.partProperty(i, "life")

	if life > 0 then
		sim.partProperty(i, "vx", 0) 
		sim.partProperty(i, "vy", 0)
		local fire = sim.partCreate(-1, x + math.random(3) - 2, y + math.random(3) - 2, elem.DEFAULT_PT_PLSM)
		if fire ~= -1 then
			sim.partProperty(fire, "temp", 4000)
			sim.partProperty(fire, "life", 40)
		end
		sim.pressure(x / sim.CELL, y / sim.CELL, sim.pressure(x / sim.CELL, y / sim.CELL) + 0.2)
		if life == 1 then
			sim.partKill(i)
		end
	else
		if s ~= n then
			local sticky = false
			for o,p in pairs(sim.partNeighbours(x, y, 1)) do
				local ptype = sim.partProperty(p, "type")
				if ptype == elem.DEFAULT_PT_SOAP then
					sticky = false
					break
				elseif not fuelNonstick[ptype] then
					sticky = true
				end
			end
			if sticky then
				sim.partProperty(i, "vx", 0) 
				sim.partProperty(i, "vy", 0)
			end
		end

		if s > 0 then
			if sim.partProperty(i, "temp") > 1500 then
				sim.partProperty(i, "life", 600)
			else
				local nearPlsm = sim.partNeighbours(x, y, 2, elem.DEFAULT_PT_PLSM)
				local nearSprk = sim.partNeighbours(x, y, 2, elem.DEFAULT_PT_SPRK)
			
				if #nearPlsm + #nearSprk > 0 then
					sim.partProperty(i, "life", 600)
				end
			end
		end

		if n > 0 then
			local cx, cy = x + math.random(3) - 2, y + math.random(3) - 2
			local r = sim.photons(cx, cy)
			if r and sim.partProperty(r, "temp") > 1000 then
				sim.partProperty(i, "life", 600)
			end
		end
	end
end)
end -- End of FUEL scope

do -- Start of COPP scope
local copperOxidizationLimit = 20
local copperSuperconductTemp = 35 -- Superconductance temperature of LBCO, a superconductor partly made of copper

local function copperInstAbleID(p)
	if p and sim.partProperty(p, "type") == copp and sim.partProperty(p, "temp") < copperSuperconductTemp and sim.partProperty(p, "life") == 0 then
		return true
	end
	return false
end

local function copperInstAble(x, y)
	local p = sim.pmap(x, y)
	return copperInstAbleID(p)
end

local jacob1SprkInhibitor = false



-- Biostatic (stops living elements from growing)
elem.property(elem.DEFAULT_PT_YEST, "Create", function(i, x, y, t, v)
	local copper = sim.partNeighbours(x, y, 2, copp)
	if #copper > 0 then
		sim.partProperty(i, "type", elem.DEFAULT_PT_DYST)
	end
end)
elem.property(elem.DEFAULT_PT_PLNT, "CreateAllowed", function(p, x, y, t)
	if (p == -1 or p >= 0) and #sim.partNeighbours(x, y, 2, copp) > 0 then
		return false
	end
	return true
end)
elem.property(elem.DEFAULT_PT_LIFE, "CreateAllowed", function(p, x, y, t)
	if p == -1 and #sim.partNeighbours(x, y, 2, copp) > 0 then
		return false
	end
	return true
end)

local virsImmune = {
	[elem.DEFAULT_PT_SPRK] = function(p) return sim.partProperty(p, "ctype") == copp end,
	[copp] = function(p) return true end,
	[plst] = function(p) return true end,
	[mpls] = function(p) return true end,
}

elem.property(elem.DEFAULT_PT_VIRS, "CreateAllowed", function(p, x, y, t)
	local t = sim.partProperty(p, "type")
	return p < 0 or (not virsImmune[t] or not virsImmune[t](p))
end)

elem.property(elem.DEFAULT_PT_VRSG, "CreateAllowed", function(p, x, y, t)
	local t = sim.partProperty(p, "type")
	return p < 0 or (not virsImmune[t] or not virsImmune[t](p))
end)

elem.property(elem.DEFAULT_PT_VRSS, "CreateAllowed", function(p, x, y, t)
	local t = sim.partProperty(p, "type")
	return p < 0 or (not virsImmune[t] or not virsImmune[t](p))
end)

elem.element(copp, elem.element(elem.DEFAULT_PT_METL))
elem.property(copp, "Name", "COPP")
elem.property(copp, "Description", "Copper. Superconducts at low temperatures.")
elem.property(copp, "Colour", 0xD45232)
elem.property(copp, "Hardness", 0) -- Corrosion resistant
elem.property(copp, "MenuSection", elem.SC_ELEC)
elem.property(copp, "HighTemperature", 1084.62 + 273.15)
-- elem.property(copp, "Properties", elem.TYPE_LIQUID + elem.PROP_LIFE_DEC)
elem.property(copp, "Update", function(i, x, y, s, n)
	if math.random(10) == 1 then
		local oxy = sim.partNeighbours(x, y, 2, elem.DEFAULT_PT_OXYG)
		if #oxy > 0 then
			sim.partProperty(i, "tmp", math.min(sim.partProperty(i, "tmp") + 1, copperOxidizationLimit))
		end
	end
end)
local viruses = {
	[elem.DEFAULT_PT_VIRS] = true,
	[elem.DEFAULT_PT_VRSG] = true,
	[elem.DEFAULT_PT_VRSS] = true,
}

-- This mod handles SPRK a bit differently
if tpt.version.jacob1s_mod then
	elem.property(elem.DEFAULT_PT_SPRK, "ChangeType", function(i, x, y, t1, t2)
		if jacob1SprkInhibitor then jacob1SprkInhibitor = false return end
		if t1 == copp then
			-- Superconductance
			if sim.partProperty(i, "temp") < copperSuperconductTemp then
				floodFill(x, y, 
					copperInstAble, 
					function(x, y)
						jacob1SprkInhibitor = true
						sim.partCreate(-1, x, y, elem.DEFAULT_PT_SPRK)
					end)
			end
			local acid = sim.partNeighbours(x, y, 2, elem.DEFAULT_PT_ACID)
			for j,k in pairs(acid) do
				sim.partChangeType(k, cuso)
				sim.partProperty(k, "life", 0)
				sim.partProperty(k, "tmp", 1) -- Hydrate
			end
			local cuso = sim.partNeighbours(x, y, 1, cuso)
			for j,k in pairs(cuso) do
				sim.partProperty(k, "life", 30) -- Growify
			end
		elseif t2 == elem.DEFAULT_PT_LAVA then
			sim.partProperty(i, "tmp", 0) -- Remove oxidization when melted
		end
	end)
else
	elem.property(copp, "ChangeType", function(i, x, y, t1, t2)
		-- print(i, x, y, t1, t2)
		if t2 == elem.DEFAULT_PT_SPRK then
			-- Superconductance
			if sim.partProperty(i, "temp") < copperSuperconductTemp then
				floodFill(x, y, 
					copperInstAble, 
					function(x, y)
						jacob1SprkInhibitor = true
						sim.partCreate(-1, x, y, elem.DEFAULT_PT_SPRK)
					end)
			end
			local acid = sim.partNeighbours(x, y, 2, elem.DEFAULT_PT_ACID)
			for j,k in pairs(acid) do
				sim.partChangeType(k, cuso)
				sim.partProperty(k, "life", 0)
				sim.partProperty(k, "tmp", 1) -- Hydrate
			end
			local cuso = sim.partNeighbours(x, y, 1, cuso)
			for j,k in pairs(cuso) do
				sim.partProperty(k, "life", 30) -- Growify
			end
		elseif t2 == elem.DEFAULT_PT_LAVA then
			sim.partProperty(i, "tmp", 0) -- Remove oxidization when melted
		end
	end)
end

elem.property(copp, "Graphics", function (i, r, g, b)
	pr, pg, pb = 87, 178, 90 -- Patina RGB
	local oxidization = sim.partProperty(i, "tmp") / copperOxidizationLimit
	
	local pixel_mode = ren.PMODE_FLAT
	local firea = 0
	if sim.partProperty(i, "temp") < copperSuperconductTemp then
		pixel_mode = ren.PMODE_FLAT + ren.FIRE_ADD
		firea = 63
		b = b + 60
	end
	return 0,pixel_mode,255,
	r * (1 - oxidization) + pr * oxidization,
	g * (1 - oxidization) + pg * oxidization,
	b * (1 - oxidization) + pb * oxidization,
	firea,0,0,255;
end)

local cusoAbsorbable = {
	[elem.DEFAULT_PT_WATR] = true,
	[elem.DEFAULT_PT_DSTW] = true,
	[elem.DEFAULT_PT_SLTW] = true,
}

local cusoBrittleness = {
	0.02, -- Dehydrated
	1.5, -- Hydrated
}

local isCuso = {
	[cuso] = true,
	[brcs] = true,
}

elem.element(cuso, elem.element(elem.DEFAULT_PT_GLAS))
elem.property(cuso, "Name", "CUSO")
elem.property(cuso, "Description", "Copper(II) sulfate. Toxic crystal, formed when COPP electrolyzes ACID.")
elem.property(cuso, "Colour", 0x005BF9)
elem.property(cuso, "Hardness", 0)
elem.property(cuso, "Properties", elem.TYPE_SOLID + elem.PROP_LIFE_DEC + elem.PROP_DEADLY)
elem.property(cuso, "MenuSection", elem.SC_SOLIDS)
elem.property(cuso, "HighTemperature", 590)
elem.property(cuso, "HighTemperatureTransition", sim.NT)
elem.property(cuso, "Create", function(i, x, y, t, v)
	sim.partProperty(i, "tmp", 1) -- Hydrated (can be dehydrated through heat)
end)

elem.element(brcs, elem.element(elem.DEFAULT_PT_SAND))
elem.property(brcs, "Name", "BRCS")
elem.property(brcs, "Description", "Broken copper(II) sulfate.")
elem.property(brcs, "Colour", 0x2589FC)
elem.property(brcs, "Hardness", 0)
elem.property(brcs, "Properties", elem.TYPE_PART + elem.PROP_LIFE_DEC + elem.PROP_DEADLY)
elem.property(brcs, "MenuSection", elem.SC_POWDERS)
elem.property(brcs, "HighTemperature", 590)
elem.property(brcs, "HighTemperatureTransition", sim.NT)
elem.property(brcs, "Create", function(i, x, y, t, v)
	sim.partProperty(i, "tmp", 1) -- Hydrated (can be dehydrated through heat)
end)

local function cusoUpdate(i, x, y, s, n)
	local hydrated = sim.partProperty(i, "tmp")
	local growy = sim.partProperty(i, "life")
	if growy > 0 then
		local nx, ny = x + math.random(-1, 1), y + math.random(-1, 1)
		local n = sim.pmap(nx, ny)
		if n then
			if sim.partProperty(n, "type") == elem.DEFAULT_PT_ACID then
				sim.partCreate(n, nx, ny, cuso)
				sim.partProperty(n, "life", 0)
			elseif isCuso[sim.partProperty(n, "type")] and sim.partProperty(n, "life") == 0 then
				sim.partProperty(n, "life", growy)
				sim.partProperty(i, "life", 0)
			end
		end
	end

	if hydrated == 1 then
		if s > 0 and sim.partProperty(i, "temp") > 110 + 273.15 then
			local nx, ny = x + math.random(-1, 1), y + math.random(-1, 1)
			local np = sim.partCreate(-1, nx, ny, elem.DEFAULT_PT_WTRV)
			if np >= 0 then
				sim.partProperty(i, "tmp", 0)
			end
		end

		if s ~= n and math.random(50) == 1 then
			local nx, ny = x + math.random(-1, 1), y + math.random(-1, 1)
			local n = sim.pmap(nx, ny)
			if n then
				if cusoAbsorbable[sim.partProperty(n, "type")] then
					sim.partChangeType(i, trtw)
					sim.partKill(n)
				end
			end
		end
	else
		if sim.partProperty(i, "temp") > 590 + 273.15 then
			sim.partProperty(i, "type", elem.DEFAULT_PT_LAVA)
			sim.partProperty(i, "ctype", cuso)
		else
			local nx, ny = x + math.random(-1, 1), y + math.random(-1, 1)
			local n = sim.pmap(nx, ny)
			if n then
				if isCuso[sim.partProperty(n, "type")] and sim.partProperty(n, "tmp") == 1 then
					sim.partProperty(i, "tmp", 1)
					sim.partProperty(n, "tmp", 0)
				elseif cusoAbsorbable[sim.partProperty(n, "type")] then
					sim.partProperty(i, "tmp", 1)
					sim.partKill(n)
				end
			end
		end
	end
	local pres = sim.pressure(x / sim.CELL, y / sim.CELL)
	local tmp3 = sim.partProperty(i, "tmp3") / 256
	if sim.partProperty(i, "type") == cuso and math.abs(pres - tmp3) > cusoBrittleness[hydrated + 1] then
		sim.partChangeType(i, brcs)
	end
	sim.partProperty(i, "tmp3", pres * 256)
end
elem.property(cuso, "Update", cusoUpdate) 
elem.property(brcs, "Update", cusoUpdate) 

local cusoDehydrateSat = 0.8
local cusoDehydrateVal = 0.8
local function cusoGraphics(i, r, g, b)
	local hydrated = sim.partProperty(i, "tmp")

	local colr = r
	local colg = g
	local colb = b

	if hydrated == 0 then
		colr = (colr + (255 - colr) * cusoDehydrateSat) * cusoDehydrateVal
		colg = (colg + (255 - colg) * cusoDehydrateSat) * cusoDehydrateVal
		colb = (colb + (255 - colb) * cusoDehydrateSat) * cusoDehydrateVal
	end
	
	local pixel_mode = ren.PMODE_FLAT
	return 0,pixel_mode,255,colr,colg,colb,firea,0,0,255;
end
elem.property(cuso, "Graphics", cusoGraphics)
elem.property(brcs, "Graphics", cusoGraphics)
end -- End of COPP scope

do -- Start of STGM scope
local stgmImmune = {
	[stgm] = true,
	[elem.DEFAULT_PT_DMND] = true,
	[elem.DEFAULT_PT_CLNE] = true,
	[elem.DEFAULT_PT_WARP] = true,
}

local stgmMaxStability = 100
local stgmSplitMass = 50


-- life: Energy. Expended to produce heat. Expends faster as mass increases.
-- ctype: Mass. Dozens of normal particles can be compressed into a single STGM particle.
-- tmp: Stability: Slowly falls as temperature rises. Maintained by adding fuel.

elem.element(stgm, elem.element(elem.DEFAULT_PT_SING))
elem.property(stgm, "Name", "STGM")
elem.property(stgm, "Description", "Strange matter. When heated, converts matter and produces energy, but destabilizes if over-fueled.")
elem.property(stgm, "Colour", 0xFF5D00)
elem.property(stgm, "HotAir", -0.01)
elem.property(stgm, "Advection", 0.01)
elem.property(stgm, "AirDrag", 0)
elem.property(stgm, "Loss", 0.99)
elem.property(stgm, "Gravity", 0.01)
elem.property(stgm, "Falldown", 2)
elem.property(stgm, "Properties", elem.TYPE_LIQUID + elem.PROP_NEUTPASS)
elem.property(stgm, "Weight", 99)
elem.property(stgm, "Create", function(i, x, y, t, v)
	sim.partProperty(i, "tmp", stgmMaxStability)
end)

elem.property(stgm, "Update", function(i, x, y, s, n)
	local temp = sim.partProperty(i, "temp")
	local fuel = sim.partProperty(i, "life")
	local mass = sim.partProperty(i, "ctype")
	local stability = sim.partProperty(i, "tmp")
	if s ~= n then
		local px, py = x + math.random(-1, 1), y + math.random(-1, 1)
		local p = sim.pmap(px, py)
		-- if p and not sim.partProperty(p, "temp") then
		-- 	tpt.set_pause(1)
		-- 	print(i, p, px, py, x, y)
		-- 	print(elem.property(allPartsTypes[p], "Name"), elem.property(allPartsCtypes[p], "Name"))
		-- 	-- print(tpt.get_property("temp", px, py))
		-- end
		if p then
			-- Note: This is temporary because of a bug in TPT that causes pmap to return bad IDs under weird circumstances
			-- This can be removed when the bug is fixed
			local ptemp = sim.partProperty(p, "temp")
			if p and ptemp and sim.partProperty(p, "temp") > 1500 then
				local ptype = sim.partProperty(p, "type")
				if not stgmImmune[ptype] and elem.property(ptype, "HeatConduct") > 0 then
					fuel = fuel + 300
					mass = mass + 1
					stability = stability + 1
					sim.partKill(p)
					if fuel > 3000 then
						stability = stability - 10
					end
				end
			end
		end
	end

	if stability < stgmMaxStability or temp > 4000 then
		if temp < 3500 + mass * 40 then -- As the STGM accumulates more mass, it must be kept at a higher temp to keep stable
			stability = stability - math.random(0, 2)
		end
		if temp > 3000 then
			local instability = (temp / 10000) ^ 15
			if math.random() < instability then
				stability = stability - 1
			end

			local p = sim.pmap(x + math.random(-1, 1), y + math.random(-1, 1))
			if p and sim.partProperty(p, "type") == stgm then
				local pStability = sim.partProperty(p, "tmp")
				local stabilityDiff = math.floor((stability - pStability) / 2)
				stability = stability - stabilityDiff
				sim.partProperty(p, "tmp", pStability + stabilityDiff)
			end
		end
	end

	if everlastingStgm then
		stability = stgmMaxStability
	end

	if stability <= 0 then
		sim.partKill(i)
		sim.partProperty(sim.partCreate(-3, x, y, elem.DEFAULT_PT_WARP), "temp", mass * 200)
		sim.partProperty(sim.partCreate(-3, x, y, elem.DEFAULT_PT_ELEC), "temp", mass * 200)
		return
	else
		if fuel > 0 then
			temp = temp + 50
			fuel = math.max(fuel - 1, 0)
		end
	end

	stability = math.min(stability, stgmMaxStability)

	if mass > stgmSplitMass then
		local child = sim.partCreate(-1, x + math.random(-1, 1), y + math.random(-1, 1), stgm)
		if child >= 0 then
			mass = 0
			sim.partProperty(child, "temp", temp)
			sim.partProperty(child, "tmp", stability)
		end
	end

	sim.partProperty(i, "temp", temp)
	sim.partProperty(i, "life", fuel)
	sim.partProperty(i, "ctype", mass)
	sim.partProperty(i, "tmp", stability)
end)

elem.property(stgm, "Graphics", function (i, r, g, b)
	local colr, colg, colb = r, g, b
	
	local pixel_mode = ren.PMODE_FLAT
	local firea = 0
	local stability = sim.partProperty(i, "tmp")
	if sim.partProperty(i, "life") > 0 then
		pixel_mode = ren.PMODE_FLAT + ren.PMODE_GLOW
		firea = 255
	elseif stability < stgmMaxStability then
		colr, colg, colb = 13 + (1 - stability / stgmMaxStability) * 200, 41, 49 -- Neutral RGB
		pixel_mode = ren.PMODE_FLAT + ren.PMODE_GLOW + ren.FIRE_ADD
		firea = (1 - stability / stgmMaxStability) * 80
	else
		colr, colg, colb = 13, 41, 49 -- Neutral RGB
	end
	return 0,pixel_mode,255,colr,colg,colb,firea,colr,colg,colb;
end)

sim.can_move(stgm, stgm, 1)

elem.property(elem.DEFAULT_PT_PROT, "Update", function(i, x, y, s, n)
	if math.random(15) == 1 and sim.pressure(x / sim.CELL, y / sim.CELL) > 50 then
		local index = sim.photons(x, y)
		if index and index ~= i and sim.partProperty(index, "type") == elem.DEFAULT_PT_PROT then
			local velocity = math.sqrt((sim.partProperty(i, "vx") - sim.partProperty(index, "vx")) ^ 2 + (sim.partProperty(i, "vy") - sim.partProperty(index, "vy")) ^ 2)
			if velocity > 20 then
				sim.partChangeType(i, stgm)
				sim.partProperty(i, "life", 0)
				sim.partProperty(i, "ctype", 0)
				sim.partProperty(i, "tmp", stgmMaxStability)
			end
		end
	end
end)
end -- End of STGM scope

do -- Start of FNGS scope

local primInhibitModes = {
	[0x1] = true,
	[0x2] = true,
	[0x3] = true,
}

local stateLifeSharing = {
	[0x0] = { [0x0] = true, [0x4] = true, },
	[0x2] = { [0x2] = true, [0x3] = true, },
	[0x3] = { [0x2] = true, [0x3] = true, },
}

-- Even numbers: positive X, odd numbers: negative X. Zero is a special case.
-- Convert signed value to unsigned
local function weaveFungusRadius(num)
	if num < 0 then
		return num * -2 - 1
	else
		return num * 2
	end
end
-- Convert unsigned value to signed
local function unweaveFungusRadius(num)
	if num % 2 == 0 then
		return num / 2
	else
		return (num + 1) / -2
	end
end

local function sign(num)
	return num > 0 and 1 or (num == 0 and 0 or -1)
end

local shroomCurveDerivativeSolutions = {
	function(a, b, c)
		return math.sqrt((-(math.sqrt(b ^ 2 - 3 * a * c) + b) / a) / 3)
	end,
	function(a, b, c)
		return math.sqrt(((math.sqrt(b ^ 2 - 3 * a * c) - b) / a) / 3)
	end
}

local function shroomAlgoParamsToCoefficients(f, t, w)
	return 
		f + 0.2, 
		(1 - f) * math.cos(t), 
		(1 - f) * math.sin(t) * 3, 
		w - f / 2 + ((1 - f) * math.sqrt(math.abs(t - 0.5))) / 5
end

local function shroomCapCurve(x, a, b, c)
	return -(a * (x ^ 6) + b * (x ^ 4) + c * (x ^ 2))
end

local function nanCheck(num)
	if num ~= num then 
		return -math.huge
	else 
		return num 
	end
end

local function shroomCapCurveMaximum(a, b, c)
	return math.max(
		nanCheck(shroomCapCurve(shroomCurveDerivativeSolutions[1](a, b, c), a, b, c)), 
		nanCheck(shroomCapCurve(shroomCurveDerivativeSolutions[2](a, b, c), a, b, c)), 
		shroomCapCurve(0, a, b, c))
end

local function shroomCapCurveScaled(x, a, b, c, d)
	return (shroomCapCurve(x * d, a, b, c) - shroomCapCurve(d, a, b, c)) / 
		(shroomCapCurveMaximum(a, b, c) - shroomCapCurve(d, a, b, c))
end

local function unpackFungusGenome(genome)
	return {
		extractBits(genome, 0x00000008, 0x00000001), -- Stem height
		extractBits(genome, 0x00000080, 0x00000010), -- Cap radius
		extractBits(genome, 0x00000800, 0x00000100), -- Cap height
		extractBits(genome, 0x00004000, 0x00001000), -- Prim inhibition range

		extractBits(genome, 0x00010000, 0x00008000), -- Cap bottom shape
		extractBits(genome, 0x00200000, 0x00020000), -- Cap algo flatness
		extractBits(genome, 0x04000000, 0x00400000), -- Cap algo theta
		extractBits(genome, 0x40000000, 0x08000000), -- Cap algo width
	}
end

local function packFungusGenome(genes)
	return 
		bit.band(round(genes[1]) * 0x00000001, 0x0000000F) + -- Stem height
		bit.band(round(genes[2]) * 0x00000010, 0x000000F0) + -- Cap radius
		bit.band(round(genes[3]) * 0x00000100, 0x00000F00) + -- Cap height
		bit.band(round(genes[4]) * 0x00001000, 0x00007000) + -- Prim inhibition range

		bit.band(round(genes[5]) * 0x00008000, 0x00018000) + -- Cap bottom shape
		bit.band(round(genes[6]) * 0x00020000, 0x003E0000) + -- Cap algo flatness
		bit.band(round(genes[7]) * 0x00400000, 0x07C00000) + -- Cap algo theta
		bit.band(round(genes[8]) * 0x08000000, 0x78000000)   -- Cap algo width
end

local genomeMaxValues = {
	15,
	15,
	15,
	7,
	3,
	31,
	31,
	15
}

local function unpackFungusVisualGenome(genome)
	return {
		extractBits(genome, 0x00000008, 0x00000001), -- Cap hue
		extractBits(genome, 0x00000040, 0x00000010), -- Cap hue 2 offset
		extractBits(genome, 0x00000200, 0x00000080), -- Cap sat/val 1
		extractBits(genome, 0x00001000, 0x00000400), -- Cap sat/val 2
		extractBits(genome, 0x00004000, 0x00002000), -- Bioluminescence
		extractBits(genome, 0x00008000, 0x00008000), -- Spots
		extractBits(genome, 0x00020000, 0x00010000), -- Ridge height
		extractBits(genome, 0x00080000, 0x00040000), -- Stem width
		extractBits(genome, 0x00200000, 0x00100000), -- Stem color
		extractBits(genome, 0x01000000, 0x00400000), -- Stem sat/val
		extractBits(genome, 0x08000000, 0x02000000), -- Gradient level
		extractBits(genome, 0x20000000, 0x10000000), -- Gradient size
		extractBits(genome, 0x40000000, 0x40000000), -- Gradient curve
	}
end

local function packFungusVisualGenome(genes)
	return 
		bit.band(round(genes[1]) * 0x00000001, 0x0000000F) + -- Cap hue
		bit.band(round(genes[2]) * 0x00000010, 0x00000070) + -- Cap hue 2 offs
		bit.band(round(genes[3]) * 0x00000080, 0x00000380) + -- Cap sat/val 1
		bit.band(round(genes[4]) * 0x00000400, 0x00001C00) + -- Cap sat/val 2

		bit.band(round(genes[5]) * 0x00002000, 0x00006000) + -- Bioluminescence
		bit.band(round(genes[6]) * 0x00008000, 0x00008000) + -- Spots
		bit.band(round(genes[7]) * 0x00010000, 0x00030000) + -- Ridge height

		bit.band(round(genes[8]) * 0x00040000, 0x000C0000) + -- Stem width
		bit.band(round(genes[9]) * 0x00100000, 0x00300000) + -- Stem color
		bit.band(round(genes[10]) * 0x00400000, 0x01C00000) + -- Stem sat/val

		bit.band(round(genes[11]) * 0x02000000, 0x0E000000) + -- Gradient level
		bit.band(round(genes[12]) * 0x10000000, 0x30000000) + -- Gradient size
		bit.band(round(genes[13]) * 0x40000000, 0x40000000)   -- Gradient curve
end

local visualGenomeMaxValues = {
	15,
	7,
	7,
	7,

	3,
	1,
	3,

	3,
	3,
	7,

	7,
	3,
	1,
}

local function mutateFungusGenes(genes, maxValues)
	local index = math.random(1, 8)
	genes[index] = math.min(math.max(genes[index] + math.random(2) * 2 - 3, 0), maxValues[index])
end

local function getGenomeValues(genes)
	return {
		genes[1] * 2, -- Stem height
		genes[2] + 1, -- Cap radius
		genes[3] + 1, -- Cap height
		genes[4], -- Prim inhibition range
		
		genes[5], -- Cap bottom shape
		genes[6] / 31, -- Cap algo flatness
		genes[7] / 31 * 3.4 - 0.6, -- Cap algo theta
		genes[8] / 15 / 2 + 1, -- Cap algo width
	}
end

local function unGetGenomeValues(vals)
	return {
		round(vals[1] / 2), -- Stem height
		round(vals[2] - 1), -- Cap radius
		round(vals[3] - 1), -- Cap height
		round(vals[4]), -- Prim inhibition range

		round(vals[5]), -- Cap bottom shape
		round(vals[6] * 31), -- Cap algo flatness
		round((vals[7] + 0.6) * 31 / 3.4), -- Cap algo theta
		round((vals[8] - 1) * 15 * 2), -- Cap algo width
	}
end

local function genomeValuesToGenome(vals)
	return packFungusGenome(unGetGenomeValues(vals))
end

function spawnShroom(vals, vvals)
	local s = sim.partCreate(-1, 306, 192, fngs)
	sim.partProperty(s, "ctype", packFungusGenome(vals))
	sim.partProperty(s, "tmp4", packFungusVisualGenome(vvals))

	sim.partProperty(s, "tmp", 0x8 + 0x2)
	sim.partProperty(s, "tmp3", 1800)
	sim.partProperty(s, "life", 65535)

end

function spawnMushroomGrid(w)
	for i = 0, 31 do
		for j = 0, 31 do
			local s = sim.partCreate(-1, i * 20 + 16, j * 12 + 16, fngs)
			sim.partProperty(s, "ctype", packFungusGenome({0, 8, 9, 5, i, j, w}))
			sim.partProperty(s, "tmp", 0x8 + 0x2)
			sim.partProperty(s, "tmp3", 1800)
		end
	end
end

function debugMushroomGeneVals()
	local underMouse = sim.pmap(sim.adjustCoords(tpt.mousex, tpt.mousey))
	local genome = sim.partProperty(underMouse, "ctype")
	local vals = getGenomeValues(unpackFungusGenome(genome))
	for i,j in pairs(vals) do
		print(j)
	end
end

local GENE_STEMHEIGHT = 1
local GENE_CAPRADIUS = 2
local GENE_CAPHEIGHT = 3
local GENE_PRIMINVESTMENT = 4
local GENE_CAPBOTTOMSHAPE = 5
local GENE_CAPALGO_FLATNESS = 6
local GENE_CAPALGO_THETA = 7
local GENE_CAPALGO_WIDTH = 8

local defaultGenomes = {
	-- "Fly agaric" (Amanita muscaria)
	{ {8, 12, 6, 4, 0, 20, 30, 0}, {0, 6, 0, 0, 0, 1, 1, 1, 0, 0, 1, 2, 0} },
	-- "Pink bonnet" (Marasmius haematocephalus)
	{ {10, 3, 6, 2, 0, 1, 30, 10}, {15, 4, 0, 1, 0, 0, 3, 0, 0, 5, 1, 1, 0} },
	-- "Werewere-Kokako" (Entoloma hochstetteri)
	{ {6, 6, 6, 3, 1, 0, 29, 4}, {9, 4, 1, 0, 0, 0, 2, 1, 3, 1, 5, 3, 1} },
	-- "Scarlet waxcap" (Hygrocybe coccinea)
	{ {4, 6, 6, 2, 0, 2, 25, 4}, {0, 7, 0, 0, 0, 0, 1, 2, 3, 0, 1, 2, 1} },
	-- "Golden-edge bonnet" (Mycena aurantiomarginata)
	{ {10, 3, 6, 2, 0, 0, 28, 4}, {1, 5, 6, 0, 0, 0, 2, 1, 2, 4, 1, 0, 0} },
	-- "Parrot waxcap" (Gliophorus psittacinus)
	{ {7, 5, 5, 2, 0, 3, 31, 8}, {5, 0, 7, 1, 0, 0, 1, 1, 2, 7, 2, 2, 1} },
	-- "Chicken of the woods" (Laetiporus sulphureus)
	{ {0, 14, 3, 3, 1, 17, 3, 5}, {1, 6, 0, 1, 0, 0, 0, 3, 3, 0, 2, 2, 1} },
	-- "Violet cort" (Cortinarius iodes)
	{ {5, 7, 5, 2, 0, 3, 31, 2}, {12, 4, 0, 1, 0, 1, 1, 1, 3, 2, 1, 2, 0} },
	-- Cookeina speciosa
	{ {5, 5, 7, 3, 3, 0, 20, 5}, {1, 3, 7, 1, 0, 0, 0, 1, 3, 4, 5, 2, 0} },
	-- "Pixie's parasol" (Mycena interrupta)
	{ {5, 4, 3, 1, 0, 24, 5, 5}, {9, 4, 7, 2, 0, 0, 3, 0, 0, 3, 3, 2, 0} },
	-- "Rosy bonnet" (Mycena rosea)
	{ {5, 8, 5, 3, 1, 12, 20, 5}, {15, 0, 4, 2, 0, 0, 3, 1, 3, 3, 3, 3, 0} },
	-- "Porcini mushroom" (Boletus edulis)
	{ {8, 14, 10, 5, 0, 27, 18, 6}, {1, 4, 7, 1, 0, 0, 0, 3, 1, 4, 0, 1, 1} },
	-- "Green Pepe" (Mycena chlorophos) 
	{ {5, 9, 4, 3, 1, 8, 26, 0}, {3, 4, 4, 2, 1, 0, 1, 1, 0, 4, 3, 2, 1} },
	-- "Bleeding fairy helmet" (Mycena haematopus)
	{ {9, 7, 5, 3, 0, 1, 30, 7}, {14, 4, 7, 2, 0, 0, 2, 1, 3, 3, 1, 0, 1} },
	-- "Portobello mushroom" (Agaricus bisporus)
	{ {5, 12, 7, 5, 1, 29, 9, 4}, {2, 4, 4, 2, 0, 1, 1, 2, 1, 2, 0, 1, 1} },
	-- "Shimeji mushroom" (Hypsizygus tessellatus)
	{ {10, 6, 6, 3, 0, 10, 31, 3}, {2, 3, 7, 1, 0, 0, 0, 3, 1, 2, 0, 0, 1} },
	-- "Oyster mushroom" (Pleurotus ostreatus)
	{ {2, 13, 3, 4, 1, 0, 20, 3}, {2, 3, 1, 2, 0, 0, 0, 3, 2, 2, 0, 0, 1} },
	-- "Death cap" (Amanita phalloides)
	{ {7, 8, 5, 3, 0, 14, 19, 10}, {2, 3, 7, 2, 0, 0, 1, 2, 2, 2, 0, 0, 1} },
	-- "Liberty cap" (Psilocybe semilanceata)
	{ {7, 3, 8, 2, 1, 0, 28, 0}, {1, 4, 1, 7, 0, 0, 2, 0, 2, 2, 3, 0, 1} },
	-- "Satan's bolete" (Rubroboletus satanas)
	{ {4, 14, 11, 7, 1, 6, 28, 7}, {0, 7, 2, 0, 0, 0, 0, 3, 3, 0, 0, 2, 0} },
}

-- There are two types of substrates.
-- "Moist" substrates include most biological materials. Mycelium spreading through these will gain life.
local moistSubstrate = {
	[elem.DEFAULT_PT_WOOD] = true,
	[elem.DEFAULT_PT_PLNT] = true,
	[elem.DEFAULT_PT_SPNG] = true,
	[elem.DEFAULT_PT_GEL] = true, -- Only liquid substrate
	[elem.DEFAULT_PT_GOO] = true,
	[elem.DEFAULT_PT_WAX] = true,
	[elem.DEFAULT_PT_CLST] = true,
}
-- "Dry" substrates include inorganic porous or natural materials. Mycelium can spread through these, but will gain less life.
local drySubstrate = {
	[elem.DEFAULT_PT_DUST] = true,
	[elem.DEFAULT_PT_SAND] = true,
	[elem.DEFAULT_PT_STNE] = true,
	[elem.DEFAULT_PT_CNCT] = true,
	[elem.DEFAULT_PT_BCOL] = true,
	[elem.DEFAULT_PT_SAWD] = true,
	[elem.DEFAULT_PT_BRCK] = true,
	[elem.DEFAULT_PT_ROCK] = true,
	[elem.DEFAULT_PT_COAL] = true,
	[elem.DEFAULT_PT_INSL] = true,

	-- https://www.ncbi.nlm.nih.gov/pmc/articles/PMC99030/
	-- The rest are just because they felt right.
	[elem.DEFAULT_PT_TNT] = true, 
	[elem.DEFAULT_PT_FUSE] = true,
	[elem.DEFAULT_PT_IGNC] = true,
}

-- Cannot be eaten when FNGS is set to "hungry" mode
local hungryInedible = {
	[elem.DEFAULT_PT_DMND] = true,
	[fngs] = true,
	[spor] = true,
}

-- Mushrooms can pierce certain elements if they're blocking their growth.
-- These cannot be penetrated
local shroomImpenetrable = {
	-- Special elements
	[elem.DEFAULT_PT_DMND] = true,
	[elem.DEFAULT_PT_CLNE] = true,
	[elem.DEFAULT_PT_VOID] = true,
	[elem.DEFAULT_PT_CONV] = true,
	[elem.DEFAULT_PT_VACU] = true,
	[elem.DEFAULT_PT_VENT] = true,
	[elem.DEFAULT_PT_NBHL] = true,
	[elem.DEFAULT_PT_NWHL] = true, -- Narwhals
	[elem.DEFAULT_PT_PRTI] = true,
	[elem.DEFAULT_PT_PRTO] = true,
	[elem.DEFAULT_PT_VIBR] = true,

	-- Makes sense or improves usability of the element
	[copp] = true,
	[grph] = true,
	[elem.DEFAULT_PT_TTAN] = true,
	[elem.DEFAULT_PT_QRTZ] = true,
	[elem.DEFAULT_PT_GOLD] = true,
	[elem.DEFAULT_PT_PTNM] = true,
	[elem.DEFAULT_PT_CRMC] = true,
	[elem.DEFAULT_PT_GLAS] = true, -- Even though glass is brittle, shrooms breaking GLAS is annoying.
	[elem.DEFAULT_PT_FILT] = true, -- Under the assumption that FILT is a glass-like material, which we don't know.
	[elem.DEFAULT_PT_IRON] = true,
	[elem.DEFAULT_PT_METL] = true,
	-- [fngs] = true,
}

function getRandomMushroomGenome()
	-- This was an oversight in an earlier version of FNGS that I've decided to reimplement as a "secret feature"
	if randomFngsGenomes then
		return math.random(0, 0x7FFFFFFF), math.random(0, 0x7FFFFFFF)
	else
		local species = defaultGenomes[math.random(#defaultGenomes)]
		return packFungusGenome(species[1]), packFungusVisualGenome(species[2])
	end
end

-- Yet another overly complicated Element. I seem to have a knack for making these

-- Property structure
-- ctype: Genome.
-- life: Water. Required to grow mushrooms. If water depletes, decays into dust.
-- tmp: Mode.
--  0x00: Mycelium
--  0x01: Primordium ("pre-mushroom")
--  0x02: Fruiting body (mushroom)
--  0x03: Hymenium (creates spores)
--  0x04: Surface mycelium
--  0x08: Growing (can be combined with any other mode)
--  0xF0: Growth timer. Used by mushroom caps.
-- tmp2: Reach. Used by mushrooms stipes and mycelia
-- tmp3: Angle or radius, depending on context.
elem.element(fngs, elem.element(elem.DEFAULT_PT_WOOD))
elem.property(fngs, "Name", "FNGS")
elem.property(fngs, "Description", "Fungus. Grows a mycelium network in organic elements, then grows mushrooms.")
elem.property(fngs, "Colour", 0xDAD2B4)
elem.property(fngs, "Properties", elem.TYPE_SOLID + elem.PROP_NEUTPASS)
elem.property(fngs, "Create", function(i, x, y, t, v)
	if v == 0 then -- When manually placed, create a clump of new mycelium
		local g, vg = getRandomMushroomGenome()
		sim.partProperty(i, "ctype", g)
		sim.partProperty(i, "tmp4", vg)

		sim.partProperty(i, "tmp", 0x8 + 0x0)
		sim.partProperty(i, "life", 50) -- Newly spawned FNGS gets extra life to create lots of mushrooms
	else
		-- Make no assumptions of your mycelial brethren
	end
end)

bulletTypeFunctions[fngs] = function(i)
	sim.partChangeType(i, spor)
	local species = defaultGenomes[math.random(#defaultGenomes)]
	sim.partProperty(i, "ctype", packFungusGenome(species[1]))
	sim.partProperty(i, "tmp4", packFungusVisualGenome(species[2]))
end

elem.property(fngs, "CreateAllowed", function(p, x, y, t)
	if (p == -1 or p >= 0) and #sim.partNeighbours(x, y, 2, copp) > 0 then
		return false
	end
	return true
end)

elem.property(elem.DEFAULT_PT_WATR, "Update", function(i, x, y, s, n)
	if s ~= n then
		local adjFungus = sim.partNeighbours(x, y, 1, fngs)
		for j,k in pairs(adjFungus) do
			local tmp = sim.partProperty(k, "tmp")
			local mode = tmp % 0x8
			if mode == 0 or mode == 4 then 
				local life = sim.partProperty(k, "life")
				if life < 30 then
					sim.partKill(i)
					sim.partProperty(k, "life", life + 1)
					break
				end
			end
		end
	end
end)

elem.element(spor, elem.element(elem.DEFAULT_PT_DUST))
elem.property(spor, "Name", "SPOR")
elem.property(spor, "Description", "Spores.")
elem.property(spor, "Colour", 0xDAD2B4)
elem.property(spor, "Gravity", 0.004)
elem.property(spor, "Diffusion", 0.2)
elem.property(spor, "AirDrag", 0.005)
elem.property(spor, "AirLoss", 0.96)
elem.property(spor, "Advection", 0.25)
elem.property(spor, "Loss", 0.92)
elem.property(spor, "HotAir", 0.0002)
elem.property(spor, "Weight", 80)
elem.property(spor, "MenuSection", -1)
elem.property(spor, "Create", function(i, x, y, t, v)
	if v == 0 then -- When manually placed, create a random genome
		local g, vg = getRandomMushroomGenome()
		sim.partProperty(i, "ctype", g)
		sim.partProperty(i, "tmp4", vg)
	else
		-- Make no assumptions of your fungal sprethren
	end
end)
elem.property(spor, "Update", function(i, x, y, s, n)
	if s ~= n then
		local px, py = x + math.random(-1, 1), y + math.random(-1, 1)
		local p = sim.pmap(px, py)
		if p then
			local ptype = sim.partProperty(p, "type")
			local pStopped = math.abs(sim.partProperty(p, "vx")) < 0.1 and math.abs(sim.partProperty(p, "vy")) < 0.1
			local moist = moistSubstrate[ptype]
			local dry = drySubstrate[ptype]

			if hungryFngs and not hungryInedible[ptype] then
				moist = true
			end

			if pStopped and (moist or dry) then
				local adjFungus = sim.partNeighbours(x, y, 1, fngs)
				if #adjFungus > 0 then
					if math.random(10) == 1 then -- Make shorter mushrooms more viable
						sim.partKill(i)
						return
					end
				else
					sim.partChangeType(p, fngs)
					sim.partProperty(p, "tmp", 0x8 + 0x0)
					sim.partProperty(p, "life", 6)
					sim.partProperty(p, "ctype", sim.partProperty(i, "ctype"))
					sim.partProperty(p, "tmp2", 0)
					sim.partProperty(p, "tmp4", sim.partProperty(i, "tmp4"))
					sim.partKill(i)
					return
				end
			end
		end
	end
	if n == 0 and math.random(20) == 1 then
		sim.partKill(i)
		return
	end
	if #sim.partNeighbours(x, y, 2, copp) > 0 then
		sim.partKill(i)
		return
	end
end)

elem.property(spor, "Graphics", function (i, r, g, b)
	local colr, colg, colb = r, g, b
	
	local pixel_mode = ren.FIRE_BLEND + ren.PMODE_BLEND
	local firea = 10
	return 0,pixel_mode,50,colr,colg,colb,firea,colr,colg,colb;
end)

elem.property(fngs, "Update", function(i, x, y, s, n)
	-- Fungus is slow and does not need to update every tick
	if math.random(10) == 1 then
		local water = sim.partProperty(i, "life")

		local tmp = sim.partProperty(i, "tmp")
		local mode = tmp % 0x8
		local growing = bitCheck(tmp, 0x8)
		local growTimer = extractBits(tmp, 0x80, 0x10)
		local spot = filterBits(tmp, 0x100, 0x100)
		if growTimer > 0 then
			growTimer = growTimer - 1
			sim.partProperty(i, "tmp", 
				bit.bor(
					bit.band(tmp, 0x10F),
					growTimer * 0x10
				))
		end

		local genome = sim.partProperty(i, "ctype")
		local genes = unpackFungusGenome(genome)
		local geneVals = getGenomeValues(genes)

		local visualGenome = sim.partProperty(i, "tmp4")

		if mode == 0 then -- Mycelium (spreads through substrate to gain resources)
			if growing and water > 5 then
				local reach = sim.partProperty(i, "tmp2")
				local growAttempts = sim.partProperty(i, "tmp3")
				if growAttempts > 10 then 
					sim.partProperty(i, "tmp", 0x0)
				else
					local px, py = x + math.random(-1, 1), y + math.random(-1, 1)
					local adjFungus = sim.partNeighbours(px, py, 1, fngs)
					local p = sim.pmap(px, py)
					local ptype
					if p then
						ptype = sim.partProperty(p, "type")
					end
	
					local moist = moistSubstrate[ptype]
					local dry = drySubstrate[ptype]

					if hungryFngs and not hungryInedible[ptype] then
						moist = true
					end
	
					-- Changing to < 1 prevents mycelia from merging together.
					-- This makes most species much less viable but also causes interesting shapes in the mycelial network.
					-- If you're reading this, try changing it and see what happens to mycelium growth.
					if #adjFungus < 2 and (not p or moist or dry) and reach < 25 then
						-- if p then sim.partKill(p) end
						local child = sim.partCreate(p or -1, px, py, fngs)
						if child >= 0 then
							if p then
								sim.partProperty(child, "tmp", 0x8 + 0x0)
								sim.partProperty(child, "tmp2", reach + 1)
							else
								sim.partProperty(child, "tmp", 0x8 + 0x4) -- "Surface" mycelium. Can grow shrooms
								local angle = math.atan2(px - x, py - y)
								sim.partProperty(child, "tmp3", (angle / math.pi * 1800 + (math.random() - 0.5) * 450) % 3600)
							end
							sim.partProperty(child, "ctype", genome)
							sim.partProperty(child, "life", 8 * (moist and 2 or 1))
							sim.partProperty(child, "tmp4", visualGenome)
							water = water - 3
						end
					elseif s == 0 then
						sim.partProperty(i, "tmp3", growAttempts + 1)
					end
				end
			elseif math.random(500) == 1 then
				-- Randomly revive in case ungrowable conditions are no longer the case
				sim.partProperty(i, "tmp", 0x8 + 0x0)
				sim.partProperty(i, "tmp3", 0)
			end
		elseif mode == 1 then -- Primordium (pre-mushroom, absorbs resources until ready to grow)
			-- Primordia die if all fungus supporting them dies
			if n == 8 then
				sim.partKill(i)
			elseif water > 4 * (geneVals[GENE_PRIMINVESTMENT] + 1) ^ 2 then
				sim.partProperty(i, "tmp", 0x8 + 0x2)
				water = water * 40 -- Water has a very different value inside a mushroom
			elseif s > 1 then -- Do not try to grow if it is pointless and stupid
				-- Thirsty little fungus
				local p = sim.pmap(x + math.random(-1, 1), y + math.random(-1, 1))
				if p and sim.partProperty(p, "type") == fngs and p ~= i then
					local pWater = sim.partProperty(p, "life")
					if pWater > 2 then
						sim.partProperty(p, "life", 3)
						water = pWater + water - 3
					end
				end
			end
		elseif mode == 2 then -- Mushroom (grows from the mycelium, develops gills when mature)
			if growing and water > 20 then
				local reach = sim.partProperty(i, "tmp2")

				if reach > geneVals[GENE_STEMHEIGHT] then
					-- Cap growth
					local capReach = reach - geneVals[GENE_STEMHEIGHT]
					local radius = unweaveFungusRadius(sim.partProperty(i, "tmp3"))
					local growUp = false
					local nx, ny = x, y
					if radius == 0 then
						local nbx1, nbx2 = sim.pmap(x + 1, ny), sim.pmap(x - 1, ny)
						local adj1, adj2 = nbx1 and sim.partProperty(nbx1, "type") == fngs, nbx2 and sim.partProperty(nbx2, "type") == fngs
						if adj1 and adj2 then
							growUp = true
						elseif adj1 and not adj2 then
							nx = x - 1
						elseif adj2 then
							nx = x + 1
						else
							nx = x + math.random(2) * 2 - 3
						end
						-- growUp = sim.pmap(x + 1, ny) and sim.pmap(x - 1, ny)
					else
						nx = x + sign(radius)
						local nby = sim.pmap(nx, ny)
						growUp = nby and sim.partProperty(nby, "type") == fngs
					end
					if growUp then
						nx = x
						ny = y - 1
					end

					-- Delete spores that would obstruct cap growth
					local capObstacle = sim.pmap(nx, ny)
					if capObstacle and sim.partProperty(capObstacle, "type") == spor then
						sim.partKill(capObstacle)
					end

					local newRadius = (math.abs(radius) + math.abs(nx - x)) / geneVals[GENE_CAPRADIUS]
					local newReach = capReach + math.abs(ny - y)

					local upCurve = newRadius ^ 2 * 2 * geneVals[GENE_CAPBOTTOMSHAPE]

					local a, b, c, d = shroomAlgoParamsToCoefficients(geneVals[GENE_CAPALGO_FLATNESS], geneVals[GENE_CAPALGO_THETA], geneVals[GENE_CAPALGO_WIDTH])
					local capCurve = shroomCapCurveScaled(newRadius, a, b, c, d)
					-- print(capCurve)
					local stopGrowing = false
					if 
						(newReach < geneVals[GENE_CAPHEIGHT] + upCurve) 
						and (math.abs(radius) + math.abs(nx - x) < geneVals[GENE_CAPRADIUS]) 
						and newReach < capCurve * geneVals[GENE_CAPHEIGHT] + upCurve
						and newReach > upCurve then
						-- Spots will always be calculated so that visual genome does not need to be decoded in update routine
						local newSpot = math.random(8) == 1 and 0x100 or 0x000
						if growUp then
							local child = sim.partCreate(-1, nx, ny, fngs)
							if child >= 0 then
								sim.partProperty(child, "ctype", genome)
								sim.partProperty(child, "tmp2", reach + 1)
								sim.partProperty(child, "tmp", newSpot + 0xF0 + 0x8 + 0x2)
								sim.partProperty(child, "life", water - 10)
								water = 10

								sim.partProperty(child, "tmp3", weaveFungusRadius(radius))
								sim.partProperty(child, "tmp4", visualGenome)
							end
							stopGrowing = true
						else
							local child = sim.partCreate(-1, nx, ny, fngs)
							if child >= 0 then
								sim.partProperty(child, "ctype", genome)
								sim.partProperty(child, "tmp2", reach)
								sim.partProperty(child, "tmp", newSpot + 0xF0 + 0x8 + 0x2)
								sim.partProperty(child, "life", water - 10)
								water = 10

								if radius == 0 then
									sim.partProperty(child, "tmp3", weaveFungusRadius(nx - x))
								else
									sim.partProperty(child, "tmp3", weaveFungusRadius(radius) + 2)
								end
								sim.partProperty(child, "tmp4", visualGenome)
							end
						end
					else
						-- Unable to keep growing because of size/shape constraints
						stopGrowing = true
					end

					if stopGrowing then 
						-- Small shrooms are purely spore-bearing and very delicate
						local tinyShroom = (geneVals[GENE_CAPHEIGHT] < 3) or geneVals[GENE_CAPRADIUS] < 2
						if tinyShroom or (capReach * 1.5 < capCurve * geneVals[GENE_CAPHEIGHT] + upCurve) then
							sim.partProperty(i, "tmp", spot + 0xF0 + 0x3) -- Hymenium
						else
							sim.partProperty(i, "tmp", spot + 0xF0 + 0x2) -- Flesh
						end
					end
				else
					-- Stipe (stem) growth
					::tryGrow::
					local px, py = sim.partPosition(i) -- Exact floating point coordinates
					local angle = sim.partProperty(i, "tmp3") * math.pi / 1800
					local dx, dy = math.sin(angle) + (math.random() - 0.5) * 0.01, math.cos(angle)
					local child = sim.partCreate(-1, px + dx + 0.5, py + dy + 0.5, fngs)
					if child >= 0 then
						sim.partProperty(child, "ctype", genome)
						sim.partPosition(child, px + dx, py + dy)
						local changle = math.atan2(dx, dy - 0.05)
						sim.partProperty(child, "tmp2", reach + 1)
						sim.partProperty(child, "tmp", 0xF0 + 0x8 + 0x2)

						sim.partProperty(child, "life", water - 15)
						water = 15

						sim.partProperty(i, "tmp", 0x2)
						if reach + 1 > geneVals[GENE_STEMHEIGHT] then
							sim.partProperty(child, "tmp3", 0)
						else
							sim.partProperty(child, "tmp3", (changle / math.pi * 1800) % 3600)
						end
						sim.partProperty(child, "tmp4", visualGenome)
					elseif water >= 100 then
						local obstacle = sim.pmap(px + dx + 0.5, py + dy + 0.5)
						
						-- Mushrooms grow with lots of force, some can even break through asphalt
						if obstacle and obstacle ~= i and not shroomImpenetrable[sim.partProperty(obstacle, "type")] and math.random(10) == 1 then
							sim.partKill(obstacle)
							water = water - 100
							-- If you don't try to grow again, a non-solid blocking you could fill back in.
							goto tryGrow
						elseif math.floor(px + dx + 0.5) == x and math.floor(py + dy + 0.5) == y then
							sim.partPosition(i, px + dx, py + dy)
						end
						--local tp = sim.pmap(px + dx, py + dy)
						--if not tp then
						
					end
				end
			end
			-- Mushrooms lose water faster than mycelium
			-- Don't punish "overinvestment" before resources have been distributed and the cap is fully built
			if (math.random(50) == 1 or math.random(water) > 30) and growTimer == 0 then
				water = water - 1
				-- Ruthlessly punish overinvestment of resources into small mushrooms
				if not growing and water > 20 then
					water = water * 0.5 - 10
				end
			end
		elseif mode == 3 then -- Hymenium (creates spores)
			if water > 0 and math.random(20) == 1 then
				local sx, sy = x, y
				local sp = sim.pmap(sx, sy)
				local stype
				if sp then
					stype = sim.partProperty(sp, "type")
				end
				local limit = 40 -- Prevent infinite loops
				while (sp and stype == fngs) do
					sx, sy = sx + (math.random() - 0.5) * 0.1, sy + 1
					sp = sim.pmap(sx, sy)
					if sp then
						stype = sim.partProperty(sp, "type")
					end
					limit = limit - 1
					if limit <= 0 then
						break
					end
				end
				if sp then
					-- Do nothing and Cry
				else
					local spore = sim.partCreate(-1, sx, sy, spor)
					if spore >= 0 then
						local visualGenes = unpackFungusVisualGenome(visualGenome)
						if math.random(6) == 1 then -- Random mutations
							if math.random(2) == 1 then
								mutateFungusGenes(genes, genomeMaxValues)
							else
								mutateFungusGenes(visualGenes, visualGenomeMaxValues)
							end
						end
						sim.partProperty(spore, "ctype", packFungusGenome(genes))
						sim.partProperty(spore, "tmp4", packFungusVisualGenome(visualGenes))
					end
					water = water - 7
				end
			end
		else -- Surface mycelium (may form mushrooms)
			if growing and math.random(500) == 1 and s > 1 then
				local canBecomePrim = true
				-- geneVals[local GENE_PRIMINVESTMENT] = 10 -- TEMP
				-- Fungi that invest more into each prim should create fewer prims
				local adjFungus = sim.partNeighbours(x, y, geneVals[GENE_PRIMINVESTMENT] * 2, fngs)
				for j,k in pairs(adjFungus) do
					local adjTmp = sim.partProperty(k, "tmp")
					local adjMode = bit.band(adjTmp, 0x7)
					-- local adjGrowing = bit.band(tmp, 0x8) ~= 0
					if primInhibitModes[adjMode] then
						canBecomePrim = false
						-- sim.partProperty(i, "tmp", 0x4) -- DIE.
						break
					end
				end
				if canBecomePrim then
					-- for i,j in pairs(geneVals) do print(j) end
					sim.partProperty(i, "tmp", 0x8 + 0x1)
				end
			end
		end

		-- local p = sim.pmap(x + math.random(-1, 1), y + math.random(-1, 1))

		local toShare = sim.partNeighbours(x, y, 1, fngs)
		for j,p in pairs(toShare) do
			local pMode = bit.band(sim.partProperty(p, "tmp"), 0x7)
			if stateLifeSharing[mode] and stateLifeSharing[mode][pMode] then
				local reach = sim.partProperty(i, "tmp2")
				if mode ~= 0x2 or reach > geneVals[GENE_STEMHEIGHT] then -- Stems shouldn't hog all the resources
					local pWater = sim.partProperty(p, "life")
					local waterDiff = math.floor((water - pWater) / 2)
					water = water - waterDiff
					sim.partProperty(p, "life", pWater + waterDiff)
				end 
			end
		end
		
		if mode == 0 then			
			for j,k in pairs(sim.partNeighbours(x, y, 1, elem.DEFAULT_PT_SPNG)) do
				local pWater = sim.partProperty(k, "life")
				local waterDiff = math.floor((water - pWater) / 2)
				water = water - waterDiff
				sim.partProperty(k, "life", pWater + waterDiff)
			end
			for j,k in pairs(sim.partNeighbours(x, y, 1, elem.DEFAULT_PT_GEL)) do
				local pWater = sim.partProperty(k, "tmp")
				local waterDiff = math.floor((water - pWater) / 2)
				water = water - waterDiff
				sim.partProperty(k, "tmp", pWater + waterDiff)
			end
		end


		-- Randomly dehydrate
		if math.random(100) == 1 then
			water = water - 1
		end

		sim.partProperty(i, "life", water)
		if water <= 0 then
			sim.partKill(i)
			if mode == 0x0 and math.random(10) ~= 1 then -- Dry substrate cannot be used forever
				sim.partCreate(-1, x, y, elem.DEFAULT_PT_DUST)
			end
			return
		end

		-- Radiation causes FNGS to mutate rapidly
		local radiation = sim.photons(x, y)
		if radiation then
			-- Technically, mutations from spores may carry over if a hymenium particle releases a spore and mutates at once
			-- But this is both improbable and inconsequential so I'm ignoring it
			local visualGenes = unpackFungusVisualGenome(visualGenome)
			mutateFungusGenes(genes, genomeMaxValues)
			mutateFungusGenes(visualGenes, visualGenomeMaxValues)
			sim.partProperty(i, "ctype", packFungusGenome(genes))
			sim.partProperty(i, "tmp4", packFungusVisualGenome(visualGenes))
		end
	end
end)

local VGENE_CAPHUE = 1
local VGENE_CAPHUE2 = 2
local VGENE_CAPSATVAL1 = 3
local VGENE_CAPSATVAL2 = 4
local VGENE_BIOLUMINESCENT = 5
local VGENE_SPOTS = 6
local VGENE_RIDGEHEIGHT = 7
local VGENE_STEMWIDTH = 8
local VGENE_STEMCOLOR = 9
local VGENE_STEMSATVAL = 10
local VGENE_GRADIENTLEVEL = 11
local VGENE_GRADIENTSIZE = 12
local VGENE_GRADIENTCURVE = 13

local fungusSatValTable = {
	{0.9, 0.9},
	{0.5, 0.9},
	{0.1, 0.9},
	{0.1, 0.5},
	{0.5, 0.5},
	{0.5, 0.1},
	{0.9, 0.1},
	{0.9, 0.5},
}

local ridgeHeightMultipliers = {
	-- This table will never be indexed by zero, so Lua's one-indexing can be used without adjusting the value from genome
	4,
	2,
	4 / 3,
}

local shroomGlowColors = {
	-- Ditto
	{0, 255, 12},
	{0, 255, 120},
	{0, 255, 255},
}

local stipeColors = {
	function(h, s, v)
		return hsvToRgb(0, 0, v)
	end,

	function(h, s, v)
		return hsvToRgb(43, s, v)
	end,

	function(h, s, v) 
		local r1, g1, b1 = hsvToRgb(h, s, v)
		local r2, g2, b2 = hsvToRgb(60, s, v)
		return (r1 + r2) / 2, (g1 + g2) / 2, (b1 + b2) / 2
	end,

	function(h, s, v)
		return hsvToRgb(h, s, v)
	end,
}


elem.property(fngs, "Graphics", function (i, r, g, b)
	-- local water = sim.partProperty(i, "life")

	local tmp = sim.partProperty(i, "tmp")
	local mode = tmp % 0x8

	local colr, colg, colb = r, g, b
	local pixel_mode = ren.FIRE_BLEND + ren.PMODE_FLAT
	local firea = 0
	local firer, fireg, fireb = 0, 0, 0

	if mode == 0x2 or mode == 0x3 then -- Flesh or hymenium
		local genome = sim.partProperty(i, "ctype")

		local genes = unpackFungusGenome(genome)
		local geneVals = getGenomeValues(genes) -- This step is only necessary for the normal genome

		local visualGenome = sim.partProperty(i, "tmp4")
		local visualGenes = unpackFungusVisualGenome(visualGenome)

		local reach = sim.partProperty(i, "tmp2")
		local capReach = reach - geneVals[GENE_STEMHEIGHT]
		local radius = math.abs(unweaveFungusRadius(sim.partProperty(i, "tmp3")))

		

		-- if  then
		-- 	colr, colg, colb = 255, 255, 255
		-- end

		local spot = bit.band(tmp, 0x100)
		if capReach > 0 and not (visualGenes[VGENE_SPOTS] == 1 and spot == 0x100) then
			local capReachScaled = capReach / geneVals[GENE_CAPHEIGHT]

			if visualGenes[VGENE_GRADIENTCURVE] == 1 then
				capReachScaled = capReachScaled - (radius / geneVals[GENE_CAPRADIUS]) ^ 2 * 2 * geneVals[GENE_CAPBOTTOMSHAPE] / geneVals[GENE_CAPHEIGHT]
			end

			local capGradientBlend = clamp((capReachScaled - (visualGenes[VGENE_GRADIENTLEVEL]) / 7) * ((visualGenes[VGENE_GRADIENTSIZE] + 1) / 1), 0, 1)
			local r1, g1, b1 = hsvToRgb(visualGenes[VGENE_CAPHUE] / 16 * 360, fungusSatValTable[visualGenes[VGENE_CAPSATVAL1] + 1][1], fungusSatValTable[visualGenes[VGENE_CAPSATVAL1] + 1][2])
			local r2, g2, b2 = hsvToRgb((visualGenes[VGENE_CAPHUE] + (visualGenes[VGENE_CAPHUE2] - 3.5) * 2 / 3) / 16 * 360, fungusSatValTable[visualGenes[VGENE_CAPSATVAL2] + 1][1], fungusSatValTable[visualGenes[VGENE_CAPSATVAL2] + 1][2])

			colr, colg, colb =
				r1 * capGradientBlend + r2 * (1 - capGradientBlend),
				g1 * capGradientBlend + g2 * (1 - capGradientBlend),
				b1 * capGradientBlend + b2 * (1 - capGradientBlend)

			if visualGenes[VGENE_RIDGEHEIGHT] > 0 and radius % 2 == 0 then
				local darken = math.min(capReachScaled * ridgeHeightMultipliers[visualGenes[VGENE_RIDGEHEIGHT]], 1) * 0.5 + 0.5
				colr, colg, colb = colr * darken, colg * darken, colb * darken
			end
			-- colr, colg, colb = radius / geneVals[GENE_CAPRADIUS] * 255, 0, capReach / geneVals[GENE_CAPHEIGHT] * 255
		else
			local stemWidth = geneVals[GENE_CAPRADIUS] * visualGenes[VGENE_STEMWIDTH] / 6 + 1
			-- print(visualGenes[VGENE_STEMCOLOR])
			colr, colg, colb = stipeColors[visualGenes[VGENE_STEMCOLOR] + 1](visualGenes[VGENE_CAPHUE] / 16 * 360, fungusSatValTable[visualGenes[VGENE_STEMSATVAL] + 1][1], fungusSatValTable[visualGenes[VGENE_STEMSATVAL] + 1][2])

			if capReach <= 0 then
				local x, y = sim.partPosition(i)
				graphics.fillRect(x - stemWidth / 2 + 1, y + 0.5, stemWidth, 2, colr, colg, colb)
			end
		end
	
		if visualGenes[VGENE_BIOLUMINESCENT] > 0 then
			local glowColor = shroomGlowColors[visualGenes[VGENE_BIOLUMINESCENT]]
			firer, fireg, fireb = glowColor[1], glowColor[2], glowColor[3]
			firea = 7
		end

		-- hsvToRgb(h, s, v)
	end

	if mode == 0x1 then -- Primordia appear as small white blobs
		local x, y = sim.partPosition(i)
		graphics.fillCircle(x, y, 1, 1, 255, 255, 255)
		colr, colg, colb = 255, 255, 255
	end

	return 0, pixel_mode, 255, colr, colg, colb, firea, firer, fireg, fireb;
end)
end -- End of FNGS scope

local deformLowTemp = 333
local deformTempRange = 40
local deformCoefficient = 0.1
local plexDeformCoefficient = 0.05
local meltLowTemp = 373
local meltTempRange = 100
local decompose = 623 -- 350C 
local function explodePlex(i, x, y, dx, dy)
	if math.random() > 0.5 then
		sim.partCreate(i, x, y, elem.DEFAULT_PT_PLSM)
	else
		sim.partCreate(i, x, y, elem.DEFAULT_PT_EMBR)
	end
	sim.partProperty(i, "temp", 5000)
	sim.partProperty(i, "vx", math.random() - 0.5)
	sim.partProperty(i, "vy", math.random() - 0.5)
	sim.pressure(x/4, y/4, sim.pressure(x/4, y/4) + 1.5)
	sim.velocityX(x/4, y/4, 1, 1, sim.velocityX(x/4, y/4) - dx * 2.0)
	sim.velocityY(x/4, y/4, 1, 1, sim.velocityY(x/4, y/4) - dy * 2.0)
end

do -- Start of PLST scope

-- PLST is specifically a blend of the properties of various types of plastic as well as petroleum products
-- Specifically, the three most common types of plastic: polyethylene (PE), polypropylene (PP), and polyvinyl chloride (PVC)
-- The decomposition is based on PVC, which degrades into hydrochloric acid (represented by CAUS and HALO) when burned

-- While it would be interesting if PLST functioned like INSL, I cannot replicate electrical insulation and, while thermal
-- insulation would be possible, it would conflict with PLST's melting behavior.

elem.element(plst, elem.element(elem.DEFAULT_PT_GOO))
elem.property(plst, "Name", "PLST")
elem.property(plst, "Description", "Plastic. Weakens with heat. Immune to VIRS and ACID.")
elem.property(plst, "Weight", 100)
elem.property(plst, "Colour", 0x15B535)
elem.property(plst, "Hardness", 0)
elem.property(plst, "Properties", elem.TYPE_SOLID + elem.PROP_NEUTPASS)
elem.property(plst, "HighTemperature", meltLowTemp)
elem.property(plst, "HighTemperatureTransition", mpls)
elem.property(plst, "HeatConduct", 20)
elem.property(plst, "Update", function(i, x, y, s, n)
	local temp = sim.partProperty(i, "temp")
	local deform = clamp((temp - deformLowTemp) / deformTempRange, 0, 1) 
	local velx = sim.velocityX(x / 4, y / 4)
	local vely = sim.velocityY(x / 4, y / 4)
	if math.sqrt(velx ^ 2 + vely ^ 2) > 0.1 then
		sim.partProperty(i, "vx", sim.partProperty(i, "vx") + deform * deformCoefficient * velx)
		sim.partProperty(i, "vy", sim.partProperty(i, "vy") + deform * deformCoefficient * vely)
	end

	local rad = sim.photons(x, y)
	if rad and sim.partProperty(rad, "type") == elem.DEFAULT_PT_NEUT then
		sim.partChangeType(i, plex)
	end
end)

elem.element(plex, elem.element(elem.DEFAULT_PT_GOO))
elem.property(plex, "Name", "PLEX")
elem.property(plex, "Description", "Plastic explosive. Detonated only with SPRK; insensitive to heat and pressure.")
elem.property(plex, "Weight", 100)
elem.property(plex, "Colour", 0xB3EF1C)
elem.property(plex, "Hardness", 0)
elem.property(plex, "Properties", elem.TYPE_SOLID + elem.PROP_NEUTPASS)
elem.property(plex, "HeatConduct", 20)
elem.property(plex, "MenuSection", elem.SC_EXPLOSIVE)
elem.property(plex, "Update", function(i, x, y, s, n)
	if n > 0 then
		local nearSprk = sim.partNeighbours(x, y, 2, elem.DEFAULT_PT_SPRK)
		-- #nearSprk seems to not work here 100% consistently. Unsure why
		for j, k in pairs(nearSprk) do 
			-- KABOOM!!!
			floodFill(x, y, 
				function(x1, y1)
					local part = sim.pmap(x1, y1)
					return part and sim.partProperty(part, "type") == plex
				end, 
				function(x1, y1)
					-- There will always be a part at the given position
					local part = sim.pmap(x1, y1)
					local distance = math.sqrt((x - x1) ^ 2 + (y - y1) ^ 2)
					local dx, dy = (x - x1) / distance, (y - y1) / distance
					explodePlex(part, x1, y1, dx, dy)
				end)
			break
		end
	end

	-- Plastic explosives can be molded
	local velx = sim.velocityX(x / 4, y / 4)
	local vely = sim.velocityY(x / 4, y / 4)
	if math.sqrt(velx ^ 2 + vely ^ 2) > 0.3 then
		sim.partProperty(i, "vx", sim.partProperty(i, "vx") + plexDeformCoefficient * velx)
		sim.partProperty(i, "vy", sim.partProperty(i, "vy") + plexDeformCoefficient * vely)
	end
end)

sim.can_move(elem.DEFAULT_PT_PHOT, plst, 2)
sim.can_move(elem.DEFAULT_PT_PHOT, mpls, 2)

elem.element(mpls, elem.element(elem.DEFAULT_PT_GEL))
elem.property(mpls, "Name", "MPLS")
elem.property(mpls, "Description", "Melted plastic. Viscosity changes with temperature.")
elem.property(mpls, "Falldown", 2)
elem.property(mpls, "Gravity", 0.2)
elem.property(mpls, "Weight", 100)
elem.property(mpls, "Colour", 0x81BE60)
elem.property(mpls, "Hardness", 0)
elem.property(mpls, "Properties", elem.TYPE_LIQUID)
elem.property(mpls, "Temperature", meltLowTemp + meltTempRange)
elem.property(mpls, "LowTemperature", meltLowTemp)
elem.property(mpls, "LowTemperatureTransition", plst)
-- elem.property(mpls, "HighTemperature", decompose)
-- elem.property(mpls, "HighTemperatureTransition", elem.DEFAULT_PT_GAS)
elem.property(mpls, "Update", function(i, x, y, s, n)
	local temp = sim.partProperty(i, "temp")
	-- You're very unlikely to need to move if you're surrounded on all sides
	if n > 0 then
		local meltiness = clamp((temp - meltLowTemp) / meltTempRange, 0, 1) 
		sim.partProperty(i, "vx", sim.partProperty(i, "vx") * meltiness) 
		sim.partProperty(i, "vy", sim.partProperty(i, "vy") * meltiness)
	end

	if temp > decompose then
		if math.random() > 0.5 then
			sim.partChangeType(i, halo)
		else
			sim.partChangeType(i, elem.DEFAULT_PT_CAUS)
			sim.partProperty(i, "life", 75)
		end
	end
end)


elem.property(mpls, "Graphics", function (i, r, g, b)
	local temp = sim.partProperty(i, "temp")
	local meltiness = clamp((temp - meltLowTemp) / meltTempRange, 0, 1) 
	local colr, colg, colb = graphics.getColors(0x15B535)
	colr, colg, colb = r * meltiness + colr * (1 - meltiness), g * meltiness + colg * (1 - meltiness), b * meltiness + colb * (1 - meltiness)
	-- local colr, colg, colb = r, g, b
	
	local pixel_mode = ren.PMODE_FLAT + ren.PMODE_BLUR
	return 0,pixel_mode,255,colr,colg,colb,255,colr,colg,colb;
end)

elem.property(mpls, "ChangeType", function(i, x, y, t1, t2)
	if t2 == plst then
		-- Prevent plastic from deforming instantly when solidified
		sim.partProperty(i, "vx", 0)
		sim.partProperty(i, "vy", 0)
	end
end)
end -- End of PLST scope

do -- Start of WICK scope
elem.property(elem.DEFAULT_PT_WAX, "HeatConduct", 12)

local wickAbsorbable = {
	[elem.DEFAULT_PT_OIL] = true,
	[elem.DEFAULT_PT_NITR] = true,
	[elem.DEFAULT_PT_LRBD] = true,
	[elem.DEFAULT_PT_ACID] = true,
	[elem.DEFAULT_PT_MWAX] = true,
	[elem.DEFAULT_PT_DESL] = true,
	[elem.DEFAULT_PT_LOXY] = true,
	[elem.DEFAULT_PT_BIZR] = true,
	[elem.DEFAULT_PT_SOAP] = true,
	[elem.DEFAULT_PT_DEUT] = true,
	[elem.DEFAULT_PT_ISOZ] = true,
	[elem.DEFAULT_PT_EXOT] = true,
	[fuel] = true,
}
local defaultIgniters = {
	[elem.DEFAULT_PT_FIRE] = true,
	[elem.DEFAULT_PT_LAVA] = true,
	[elem.DEFAULT_PT_PLSM] = true,
	[elem.DEFAULT_PT_LIGH] = true,
	[elem.DEFAULT_PT_SPRK] = true,
	[elem.DEFAULT_PT_PHOT] = true,
}
local wickMaxFuel = 20
local wickFuelPerPart = 5
local wickDryBurnTime = 120 -- Smoldering before decay
local defaultBurnCharacteristics = {
	burnTime = 20,
	flameCreate = function(x, y)
		local f = sim.partCreate(-1, x + math.random(3) - 2, y + math.random(3) - 2, elem.DEFAULT_PT_FIRE)
		if f then
			-- Actual candles burn hotter than this, but this makes building candles easier since the wax melts slower.
			sim.partProperty(f, "temp", 633)
			sim.partProperty(f, "life", 100)
		end
	end,
	burnOut = function(i) end,
	igniters = defaultIgniters,
	burnTemp = 573
}

local fuelCharacteristics = {
	-- While it would make sense for OIL to outgas GAS, this drastically reduces its efficiency
	[elem.DEFAULT_PT_OIL] = defaultBurnCharacteristics,
	[elem.DEFAULT_PT_NITR] = {
		burnTime = 1,
		flameCreate = function(x, y)
			-- local x, y = sim.partPosition(i)
			for i=-1,1 do for j=-1,1 do
				if math.random(1,8) == 1 then
					local p = sim.pmap(x + i, y + j)
					if p and sim.partProperty(p, "type") == wick then
						sim.partProperty(p, "tmp", 1)
					end
				end
				local fireType
				if math.random() > 0.6 then
					fireType = elem.DEFAULT_PT_FIRE
				elseif math.random() > 0.8 then
					fireType = elem.DEFAULT_PT_PLSM
				else
					fireType = elem.DEFAULT_PT_EMBR
				end
				local f = sim.partCreate(-1, x + i, y + j, fireType)
				if f then
					sim.partProperty(f, "temp", 1200)
				end
			end end
			sim.pressure(x/4, y/4, sim.pressure(x/4, y/4) + 0.1)
		end,
		burnOut = function(i)
			local x, y = sim.partPosition(i)
			sim.pressure(x/4, y/4, sim.pressure(x/4, y/4) + 2)
			sim.partKill(i)
		end,
		igniters = defaultIgniters
	},
	[elem.DEFAULT_PT_LRBD] = {
		burnTime = 5,
		flameCreate = function(x, y)
			local f = sim.partCreate(-1, x + math.random(3) - 2, y + math.random(3) - 2, elem.DEFAULT_PT_FIRE)
			if f then
				sim.partProperty(f, "temp", 1500)
			end
			sim.pressure(x/4, y/4, sim.pressure(x/4, y/4) + 0.1)
		end,
		burnOut = function(i)
			local x, y = sim.partPosition(i)
			sim.pressure(x/4, y/4, sim.pressure(x/4, y/4) + 2)
			sim.partKill(i)
		end,
		igniters = {
			-- Default igniters
			[elem.DEFAULT_PT_FIRE] = true,
			[elem.DEFAULT_PT_LAVA] = true,
			[elem.DEFAULT_PT_PLSM] = true,
			[elem.DEFAULT_PT_LIGH] = true,
			[elem.DEFAULT_PT_SPRK] = true,
			[elem.DEFAULT_PT_PHOT] = true,
			-- Waters
			[elem.DEFAULT_PT_WATR] = true,
			[elem.DEFAULT_PT_DSTW] = true,
			[elem.DEFAULT_PT_SLTW] = true,
			[elem.DEFAULT_PT_BUBW] = true,
			[elem.DEFAULT_PT_WTRV] = true,
			[elem.DEFAULT_PT_FRZW] = true,
			[trtw] = true,
		},
		burnTemp = 961,
	},
	[elem.DEFAULT_PT_ACID] = {
		burnTime = 20,
		flameCreate = function(x, y)
			if math.random() > 0.8 then
				sim.partCreate(-1, x + math.random(3) - 2, y + math.random(3) - 2, elem.DEFAULT_PT_CAUS)
			else
				local f = sim.partCreate(-1, x + math.random(3) - 2, y + math.random(3) - 2, elem.DEFAULT_PT_FIRE)
				if f then
					sim.partProperty(f, "life", 100)
				end
			end
		end,
		burnOut = function(i) end,
		igniters = defaultIgniters
	},
	[elem.DEFAULT_PT_MWAX] = defaultBurnCharacteristics,
	[elem.DEFAULT_PT_DESL] = {
		burnTime = 20,
		flameCreate = function(x, y)
			local f = sim.partCreate(-1, x + math.random(3) - 2, y + math.random(3) - 2, elem.DEFAULT_PT_FIRE)
			if f then
				sim.partProperty(f, "temp", 2200)
			end
			sim.pressure(x/4, y/4, sim.pressure(x/4, y/4) + 0.1)
		end,
		burnOut = function(i) end,
		igniters = defaultIgniters,
		burnTemp = 335
	},
	[elem.DEFAULT_PT_LOXY] = {
		burnTime = 40,
		flameCreate = function(x, y)
			local f = sim.partCreate(-1, x + math.random(3) - 2, y + math.random(3) - 2, elem.DEFAULT_PT_FIRE)
			if f then
				sim.partProperty(f, "temp", 2300 + math.random(1000))
			end
			sim.pressure(x/4, y/4, sim.pressure(x/4, y/4) + 0.2)
		end,
		burnOut = function(i) end,
		igniters = defaultIgniters,
		outgasTemp = 90.1,
		outgasType = elem.DEFAULT_PT_LOXY,
	},
	-- BIZR burns the opposite way most things burn. Truly bizarre...
	[elem.DEFAULT_PT_BIZR] = {
		burnTime = 20,
		flameCreate = function(x, y)
			local f = sim.partCreate(-1, x + math.random(3) - 2, y + math.random(3) - 2, elem.DEFAULT_PT_CFLM)
			if f then
				sim.partProperty(f, "life", 100)
			end
		end,
		burnOut = function(i) end,
		igniters = {
			[elem.DEFAULT_PT_CFLM] = true,
		}
	},
	[elem.DEFAULT_PT_SOAP] = {
		burnTime = 3,
		flameCreate = function(x, y)
			if math.random(1,60) == 1 then
				local soaps = {}
				local bubbleSize = math.random(3,6)
				local angle = math.random(0, math.pi * 2)
				local cx, cy = math.sin(angle) * (bubbleSize + 2), math.cos(angle) * (bubbleSize + 2)
				for i=0,bubbleSize do
					-- Create soap particles in a circular formation
					local dx, dy = math.sin(math.pi * i / bubbleSize * 2) * bubbleSize * 0.6, math.cos(math.pi * i / bubbleSize * 2) * bubbleSize * 0.6
					local p = sim.partCreate(-1, x + cx + dx, y + cy + dy, elem.DEFAULT_PT_SOAP)
					if p >= 0 then 
	
						-- Add velocity to push bubbles away
						local magnitude = math.sqrt(cx ^ 2 + cy ^ 2)
						local vx, vy = (cx + dx) / magnitude, (cy + dy) / magnitude
						sim.partProperty(p, "vx", vx * 4)
						sim.partProperty(p, "vy", vy * 4)

						table.insert(soaps, p)
					end
				end
				if #soaps >= 3 then
					-- Connect soap particles into a bubble
					for i=1,#soaps - 1 do
						local soap1 = soaps[i]
						local soap2 = soaps[i + 1]
						sim.partProperty(soap1, "tmp", soap2)
						sim.partProperty(soap2, "tmp2", soap1)
						sim.partProperty(soaps[i], "ctype", 7)
					end
					sim.partProperty(soaps[#soaps], "tmp", soaps[1])
					sim.partProperty(soaps[1], "tmp2", soaps[#soaps])
					sim.partProperty(soaps[#soaps], "ctype", 7)
				end
			end
			-- Pressure to push bubbles away
			sim.pressure(x/4, y/4, sim.pressure(x/4, y/4) + 0.2)
		end,
		burnOut = function(i) end,
		igniters = defaultIgniters
	},
	[elem.DEFAULT_PT_DEUT] = {
		burnTime = 10,
		flameCreate = function(x, y)
			local f = sim.partCreate(-1, x + math.random(3) - 2, y + math.random(3) - 2, elem.DEFAULT_PT_NEUT)
			if f then
				sim.partProperty(f, "temp", 1000)
			end
		end,
		burnOut = function(i) end,
		igniters = {
			[elem.DEFAULT_PT_NEUT] = true,
			[elem.DEFAULT_PT_LIGH] = true,
		}
	},
	[elem.DEFAULT_PT_ISOZ] = {
		burnTime = 30,
		flameCreate = function(x, y)
			local f = sim.partCreate(-1, x + math.random(3) - 2, y + math.random(3) - 2, elem.DEFAULT_PT_PHOT)
			if f then
				-- sim.partProperty(f, "temp", 1000)
			end
		end,
		burnOut = function(i) end,
		igniters = {
			[elem.DEFAULT_PT_PHOT] = true,
		}
	},
	[elem.DEFAULT_PT_EXOT] = {
		burnTime = 5,
		flameCreate = function(x, y)
			local f = sim.partCreate(-1, x + math.random(3) - 2, y + math.random(3) - 2, elem.DEFAULT_PT_ELEC)
			if f then
				sim.partProperty(f, "temp", 1000)
			end
			sim.gravMap(x / 4, y / 4, 1, 1, 0.2)
		end,
		burnOut = function(i) end,
		igniters = {
			[elem.DEFAULT_PT_ELEC] = true,
			[elem.DEFAULT_PT_LIGH] = true,
		}
	},
	[fuel] = {
		burnTime = 40,
		flameCreate = function(x, y)
			local f = sim.partCreate(-1, x + math.random(3) - 2, y + math.random(3) - 2, elem.DEFAULT_PT_PLSM)
			if f then
				sim.pressure(x/4, y/4, sim.pressure(x/4, y/4) + 1)
				sim.partProperty(f, "temp", 4000)
				sim.partProperty(f, "life", 40)
			end
		end,
		burnOut = function(i) end,
		igniters = {
			[elem.DEFAULT_PT_PLSM] = true,
			[elem.DEFAULT_PT_LIGH] = true,
		}
	},
}
fuelCharacteristics[0] = fuelCharacteristics[elem.DEFAULT_PT_OIL]

local wickFuelBurnTime = 20
local wickFuelPerBurnTime = 1

-- ctype: Element being wicked.
-- life: Amount absorbed
-- tmp: Fire counter
elem.element(wick, elem.element(elem.DEFAULT_PT_SPNG))
elem.property(wick, "Name", "WICK")
elem.property(wick, "Description", "Absorbs flammable liquids then slowly burns them when ignited.")
elem.property(wick, "Colour", 0xC59DAE)
elem.property(wick, "Hardness", 0)
elem.property(wick, "Flammable", 0)
elem.property(wick, "HeatConduct", 1)
elem.property(wick, "Properties", elem.TYPE_SOLID)
elem.property(wick, "Create", function(i, x, y, t, v)
	sim.partProperty(i, "tmp", 0)
end)
elem.property(wick, "Update", function(i, x, y, s, n)
	local ctype = sim.partProperty(i, "ctype")
	local life = sim.partProperty(i, "life")
	if s ~= n and life < wickMaxFuel then
		local rx, ry = x + math.random(-1, 1), y + math.random(-1, 1)
		local p = sim.pmap(rx, ry)
		if p then
			local ptype = sim.partProperty(p, "type")
			if ctype == ptype or (ctype == 0 and wickAbsorbable[ptype]) then
				sim.partKill(p)
				life = life + wickFuelPerPart
				if ctype == 0 then
					ctype = ptype
					sim.partProperty(i, "ctype", ctype)
				end
			end
		end
	end
	
	if life > 0 then
		local rx, ry = x + math.random(-2, 2), y + math.random(-2, 2)
		local p = sim.pmap(rx, ry)
		if p then
			local ptype = sim.partProperty(p, "type")
			if ptype == wick then
				local pctype = sim.partProperty(p, "ctype")
				if pctype == 0 then
					sim.partProperty(p, "ctype", ctype)
					pctype = ctype
				end
				if pctype == ctype then
					local plife = sim.partProperty(p, "life")
					local lifeDiff = math.ceil((life - plife) / 2)
					life = life - lifeDiff
					sim.partProperty(p, "life", plife + lifeDiff)
				end
			end
		end
	end

	if life == 0 then
		sim.partProperty(i, "ctype", 0)
	end

	local fuelData = fuelCharacteristics[ctype] or fuelCharacteristics[0]
	local tmp = sim.partProperty(i, "tmp")
	if tmp == 0 then
		if life >= 5 and s > 0 and (fuelData.outgasTemp or fuelData.burnTemp) then
			local temp = sim.partProperty(i, "temp")
			if fuelData.burnTemp and temp > fuelData.burnTemp then
				sim.partProperty(i, "tmp", 1)
			elseif fuelData.outgasTemp and temp > fuelData.outgasTemp then
				local f = sim.partCreate(-1, x + math.random(3) - 2, y + math.random(3) - 2, fuelData.outgasType)
				if f then
					life = life - 5
				end
			end
		end
		if n > 0 and math.random(1, 8) == 1 then
			local rx, ry = x + math.random(-1, 1), y + math.random(-1, 1)
			local randomNeighbor = sim.pmap(rx, ry) or sim.photons(rx, ry)
			if randomNeighbor ~= nil and (fuelData.igniters[sim.partProperty(randomNeighbor, "type")] == true) then
				sim.partProperty(i, "tmp", 1)
			end
		end
	else
		tmp = tmp + 1

		if life > 0 then
			fuelData.flameCreate(x, y)
			if tmp > fuelData.burnTime then
				life = life - wickFuelPerBurnTime
				tmp = 1
			end
		end
		-- Check again to ensure life has not dropped below zero
		if life <= 0 then
			if ctype ~= 0 then
				fuelData.burnOut(i)
			end
			if math.random(1,8) == 1 then
				local f = sim.partCreate(-1, x + math.random(3) - 2, y + math.random(3) - 2, elem.DEFAULT_PT_SMKE)
				if f then
					sim.partProperty(f, "temp", 373)
					sim.partProperty(f, "life", 50)
				end
			end
			if tmp > wickDryBurnTime then
				sim.partKill(i)
				local p = sim.partCreate(-3, x, y, elem.DEFAULT_PT_DUST)
				sim.partProperty(p, "dcolour", 0xFFCAC0B4)
				return
			end
			life = 0
		end
		sim.partProperty(i, "tmp", tmp)
	end
	sim.partProperty(i, "life", life)
end)

elem.property(wick, "Graphics", function (i, r, g, b)
	local x, y = sim.partPosition(i)
	local life = sim.partProperty(i, "life")
	if life > 0 then
		local ctype = sim.partProperty(i, "ctype")
		local saturation = clamp(life / wickMaxFuel, 0, 1) 
	
		local elemColor = elem.property(ctype, "Colour")
		local er, eg, eb = graphics.getColors(elemColor)
		local colr, colg, colb = er * saturation + r * (1 - saturation), eg * saturation + g * (1 - saturation), eb * saturation + b * (1 - saturation)
		
		if (x + y) % 2 >= 1 then
			colr, colg, colb = colr - 20, colg - 20, colb - 20
		end
		local pixel_mode = ren.PMODE_FLAT + ren.PMODE_BLUR
		return 0,pixel_mode,255,colr,colg,colb,saturation*255,er,eg,eb
	else
		if (x + y) % 2 >= 1 then
			r, g, b = r - 20, g - 20, b - 20
		end
		local pixel_mode = ren.PMODE_FLAT
		return 0,pixel_mode,255,r,g,b,0,r,g,b
	end
end)
end -- End of WICK scope

do -- Start of secrets scope
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

-- Super secret menu
randomFngsGenomes = false
hungryFngs = false
movingFfld = false
everlastingStgm = false
function _G.SuperSecretMenu()
	local superSecretWindow = Window:new(-1, -1, 200, 96)

	local randomFngsGenomesButton = Button:new(10, 10, 180, 16)
	randomFngsGenomesButton:action(
		function(sender)
			randomFngsGenomes = not randomFngsGenomes
			randomFngsGenomesButton:text("FNGS Randomizer: " .. tostring(randomFngsGenomes))
		end)
	randomFngsGenomesButton:text("FNGS Randomizer: " .. tostring(randomFngsGenomes))
	superSecretWindow:addComponent(randomFngsGenomesButton)

	local hungryFngsButton = Button:new(10, 30, 180, 16)
	hungryFngsButton:action(
		function(sender)
			hungryFngs = not hungryFngs
			hungryFngsButton:text("FNGS eats everything: " .. tostring(hungryFngs))
		end)
	hungryFngsButton:text("FNGS eats everything: " .. tostring(hungryFngs))
	superSecretWindow:addComponent(hungryFngsButton)

	local movingFfldButton = Button:new(10, 50, 180, 16)
	movingFfldButton:action(
		function(sender)
			movingFfld = not movingFfld
			movingFfldButton:text("Moving FFLD: " .. tostring(movingFfld))
			if movingFfld then
				elem.property(ffld, "Properties", elem.PROP_NOCTYPEDRAW + elem.PROP_NOAMBHEAT + elem.PROP_LIFE_DEC)
				elem.property(ffld, "Gravity", 0.05)
				elem.property(ffld, "Loss", 0.99)
				elem.property(ffld, "Falldown", 1)
				elem.property(ffld, "Advection", 0.05)
			else
				elem.property(ffld, "Properties", elem.TYPE_SOLID + elem.PROP_NOCTYPEDRAW + elem.PROP_NOAMBHEAT + elem.PROP_LIFE_DEC)
				elem.property(ffld, "Gravity", 0)
				elem.property(ffld, "Loss", 0)
				elem.property(ffld, "Falldown", 0)
				elem.property(ffld, "Advection", 0)
			end
		end)
	movingFfldButton:text("Moving FFLD: " .. tostring(movingFfld))
	superSecretWindow:addComponent(movingFfldButton)

	local everlastingStgmButton = Button:new(10, 70, 180, 16)
	everlastingStgmButton:action(
		function(sender)
			everlastingStgm = not everlastingStgm
			everlastingStgmButton:text("Everlasting STGM: " .. tostring(everlastingStgm))
		end)
		everlastingStgmButton:text("Everlasting STGM: " .. tostring(everlastingStgm))
	superSecretWindow:addComponent(everlastingStgmButton)

	superSecretWindow:onTryExit(function()
		interface.closeWindow(superSecretWindow)
	end)

	interface.showWindow(superSecretWindow)
end

end -- End of secrets scope

end
FanElements()