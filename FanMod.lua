


-- Element definitions

local smdb = elem.allocate("FanMod", "SMDB") -- Super mega death bomb
local srad = elem.allocate("FanMod", "SRAD") -- Hidden. Used by SDMB as part of its explosion

local trit = elem.allocate("FanMod", "TRIT") -- Tritium
local ltrt = elem.allocate("FanMod", "LTRT") -- Liquid Tritium

local ffld = elem.allocate("FanMod", "FFLD") -- Forcefield generator


local grph = elem.allocate("FanMod", "GRPH") -- Graphite
local bgph = elem.allocate("FanMod", "BGPH") -- Broken Graphite

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

local hasShownFfldWarning = false

event.register(event.tick, function()
	if not hasShownFfldWarning and mouseButtonType[1]() == "FANMOD_PT_FFLD" or mouseButtonType[2]() == "FANMOD_PT_FFLD" or mouseButtonType[3]() == "FANMOD_PT_FFLD" then
		-- print("Warning: Having FFLD selected may cause some issues with copy/paste or stamps.")
		hasShownFfldWarning = true
	end
end)  

local shiftTriangleHold = false
local shiftTriangleID = -1

-- local mouseDown = false
event.register(event.mousedown, function(x, y, button)
	if mouseButtonType[button]() == "FANMOD_PT_FFLD" and not zoomLensFree and not copyInterfaceActive then
		-- print("Gettin Printed")
		-- mouseDown = true
		local gx, gy = sim.adjustCoords(x, y)
		if (gx >= 4 and gx <= sim.XRES - 4) and (gy >= 4 and gy <= sim.YRES - 4) then
			-- print (gx, gy)
			local i = sim.partCreate(-1, gx, gy, ffld)

			if tpt.brushID == 0 then
				sim.partProperty(i, "tmp", 0x00001000);
			elseif tpt.brushID == 1 then
				sim.partProperty(i, "tmp", 0x00010000);
			elseif tpt.brushID == 2 then
				sim.partProperty(i, "tmp", 0x00100000);
				if shiftHeld then
					shiftTriangleHold = true
					shiftTriangleID = i
				end
			end
			 -- TODO: Make forcefield shape dependent on brush shape
			sim.partProperty(i, "temp", math.max(tpt.brushx, tpt.brushy) + 273.15 + 1);
			return false
		end
	end

	zoomLensFree = false
	copyInterfaceActive = false
end) 

event.register(event.mouseup, function(x, y, button, reason)
	if shiftTriangleHold then
		print("Gettin Printed")
		-- mouseDown = true
		local gx, gy = sim.adjustCoords(x, y)
		local px, py = sim.partPosition(shiftTriangleID)
		gx = gx - px
		gy = gy - py

		if gx > 0 and gx > math.abs(gy) then
			sim.partProperty(shiftTriangleID, "tmp", 0x00110000)
		elseif gx < 0 and -gx > math.abs(gy) then
			sim.partProperty(shiftTriangleID, "tmp", 0x00111000)
		elseif gy > 0 then
			sim.partProperty(shiftTriangleID, "tmp", 0x00101000)
		else
			sim.partProperty(shiftTriangleID, "tmp", 0x00100000)
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
			sim.partProperty(rad, "vx", (math.random() - 0.5) * 10)
			sim.partProperty(rad, "vy", (math.random() - 0.5) * 10)
		end
	end
	
	
end)

local useMapCoords = false -- Future-proofing in case simulation.createWallBox is changed to use map instead of part coordinates

function spawnSradJunk(x, y)
	-- print(x, y)
	sim.partKill(x, y)

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

elem.property(srad, "Update", function(i, x, y, s, n)

	local cx, cy = x + math.random(5) - 3, y + math.random(5) - 3

	local index = sim.partID(cx, cy)

	
	local type = tpt.get_property('type', cx, cy)
	if type ~= 0 and type ~= srad and type ~= smdb then
		spawnSradJunk(cx, cy)
	end

	-- Kill walls

	local wx, wy = math.floor(cx / 4), math.floor(cy / 4)
	if solidWalls[tpt.get_wallmap(wx, wy)] == true then
		if useMapCoords then
			sim.createWallBox(wx, wy, wx, wy, 0)
		else
			sim.createWallBox(cx, cy, cx, cy, 0)
		end
		for cx = 0, 3 do
			for cy = 0, 3 do
				spawnSradJunk(wx * 4 + cx, wy * 4 + cy)
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
				tpt.set_property("ctype", smdb, i)
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


local shieldPatternFunctions = {
	[0x00000000] = function(x, y, range, ctype) -- Get all parts matching ctype
		local nearbyCtype = sim.partNeighbours(x, y, range, ctype)
		return nearbyCtype
	end,
	[0x01000000] = function(x, y, range, ctype) -- Get all parts not matching ctype
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
	[0x10000000] = function(x, y, range, ctype) -- Get all parts if any match ctype
		local nearby = sim.partNeighbours(x, y, range)
		local nearbyCtype = sim.partNeighbours(x, y, range, ctype)
		if #nearbyCtype > 0 then
			return nearby
		end
		return {}
	end,
	[0x11000000] = function(x, y, range, ctype) -- Get all parts if none match ctype
		local nearby = sim.partNeighbours(x, y, range)
		local nearbyCtype = sim.partNeighbours(x, y, range, ctype)
		if #nearbyCtype == 0 then
			return nearby
		end
		return {}
	end,
}

local shieldFunctions = {
	[0x000000] = function(size, dx, dy) -- None
		return false 
	end,
	[0x001000] = function(size, dx, dy)  -- Circle
		local dist = math.sqrt(dx ^ 2 + dy ^ 2)
		return dist < size
	end,
	[0x010000] = function(size, dx, dy) -- Square
		return true 
	end,
	[0x011000] = function(size, dx, dy) -- Diamond
		local dist = math.abs(dx) + math.abs(dy)
		return dist < size
	end,
	[0x100000] = function(size, dx, dy) -- Triangle (up)
		local dist = math.abs(dx) - dy / 2 + size / 2
		return dist < size
	end,
	[0x101000] = function(size, dx, dy) -- Triangle (down)
		local dist = math.abs(dx) + dy / 2 + size / 2
		return dist < size
	end,
	[0x110000] = function(size, dx, dy) -- Triangle (right)
		local dist = math.abs(dy) + dx / 2 + size / 2
		return dist < size
	end,
	[0x111000] = function(size, dx, dy) -- Triangle (left)
		local dist = math.abs(dy) - dx / 2 + size / 2
		return dist < size
	end,
}

local shieldDrawFunctions = {
	[0x000000] = function(size, x, y, r, g, b, a) -- None

	end,
	[0x001000] = function(size, x, y, r, g, b, a)  -- Circle
		graphics.drawCircle(x, y, size + 1, size + 1, r, g, b, a) 
	end,
	[0x010000] = function(size, x, y, r, g, b, a) -- Square
		graphics.drawRect(x - size, y - size, size * 2 + 1, size * 2 + 1, r, g, b, a)
	end,
	[0x011000] = function(size, x, y, r, g, b, a) -- Diamond
		graphics.drawLine(x + size, y, x, y + size, r, g, b, a)
		graphics.drawLine(x, y + size, x - size, y, r, g, b, a)
		graphics.drawLine(x - size, y, x, y - size, r, g, b, a)
		graphics.drawLine(x, y - size, x + size, y, r, g, b, a)
		return nil
	end,
	[0x100000] = function(size, x, y, r, g, b, a) -- Triangle (up)
		graphics.drawLine(x + size, y + size, x, y - size, r, g, b, a)
		graphics.drawLine(x, y - size, x - size, y + size, r, g, b, a)
		graphics.drawLine(x - size, y + size, x + size, y + size, r, g, b, a)
	end,
	[0x101000] = function(size, x, y, r, g, b, a) -- Triangle (down)
		graphics.drawLine(x + size, y - size, x, y + size, r, g, b, a)
		graphics.drawLine(x, y + size, x - size, y - size, r, g, b, a)
		graphics.drawLine(x - size, y - size, x + size, y - size, r, g, b, a)
	end,
	[0x110000] = function(size, x, y, r, g, b, a) -- Triangle (right)
		graphics.drawLine(x - size, y + size, x + size, y, r, g, b, a)
		graphics.drawLine(x + size, y, x - size, y - size, r, g, b, a)
		graphics.drawLine(x - size, y - size, x - size, y + size, r, g, b, a)
	end,
	[0x111000] = function(size, x, y, r, g, b, a) -- Triangle (left)
		graphics.drawLine(x + size, y + size, x - size, y, r, g, b, a)
		graphics.drawLine(x - size, y, x + size, y - size, r, g, b, a)
		graphics.drawLine(x + size, y - size, x + size, y + size, r, g, b, a)
	end,
}

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
	[0x010] = function(d, x, y) -- Suspend
		sim.partProperty(d, "vx", -sim.partProperty(d, "vx"))
		sim.partProperty(d, "vy", -sim.partProperty(d, "vy"))
		return true
	end,
	[0x011] = function(d, x, y) -- Detect
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
	[0x100] = function(d, x, y) -- Superheat
		if elem.property(sim.partProperty(d, "type"), "HeatConduct") ~= 0 then
			sim.partProperty(d, "temp", 10000)
		end
		return true
	end,
	[0x101] = function(d, x, y) -- Supercool
		if elem.property(sim.partProperty(d, "type"), "HeatConduct") ~= 0 then
			sim.partProperty(d, "temp", 0)
		end
		return true
	end,
	[0x110] = function(d, x, y) -- Encase
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
	[0x111] = function(d, x, y) -- Annihilate
		sim.partChangeType(d, elem.DEFAULT_PT_SING)
		sim.partProperty(d, "tmp", 50000)
		sim.partProperty(d, "life", 0)
		return true
	end,
}

local ffldIgnore = {
	[elem.DEFAULT_PT_BRAY] = true,
	[elem.DEFAULT_PT_EMBR] = true,
	[ffld] = true,
}

function isInsideFieldShape(size, shape, dx, dy)
	return shieldFunctions[shape](size, dx, dy)

end

elem.element(ffld, elem.element(elem.DEFAULT_PT_CLNE))
elem.property(ffld, "Name", "FFLD")
elem.property(ffld, "Description", "Forcefield generator. Repels parts of its ctype. Temp sets range, TMP sets mode. Toggle with PSCN/NSCN or ARAY.")
elem.property(ffld, "Colour", 0x00de94)
elem.property(ffld, "HeatConduct", 0)
elem.property(ffld, "MenuSection", elem.SC_FORCE)

elem.property(ffld, "Properties", elem.TYPE_SOLID + elem.PROP_NOCTYPEDRAW + elem.PROP_NOAMBHEAT + elem.PROP_LIFE_DEC)

elements.property(ffld, "Create", function(i, x, y, t, v)

	-- if tpt.mousex == x and tpt.mousey == y and mouseDown then
	-- 	sim.partProperty(i, "tmp", 30); -- TODO:
	-- 	sim.partProperty(i, "temp", math.max( tpt.brushx, tpt.brushy) + 273.15);
	-- 	mouseDown = false
	-- else
	-- 	sim.partKill(i)
	-- end
	sim.partProperty(i, "tmp2", 1)
	sim.partProperty(i, "pavg0", 0)
end)

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

	if enabled == 1 then

		local ctype = sim.partProperty(i, "ctype")
		local range = math.floor(math.max(sim.partProperty(i, "temp") - 273.15, 0))
		local tmp = sim.partProperty(i, "tmp")

		local pattern = bit.band(tmp, 0x11000000)
		local shape = bit.band(tmp, 0x00111000)
		local mode = bit.band(tmp, 0x00000111)

		local nearby = shieldPatternFunctions[pattern](x, y, range, ctype)

		local any = false

		for k,d in pairs(nearby) do
			local px, py = sim.partPosition(d)
			if isInsideFieldShape(range, shape, px - x, py - y) and ffldIgnore[sim.partProperty(d, "type")] ~= true then
				shieldActionFunctions[mode](d, x, y)
				any = true
			end
		end

		if sim.partProperty(i, "pavg0") == 0 and any then
			sim.partProperty(i, "pavg0", 1)
			sim.partProperty(i, "life", 20)
		end

		if sim.partProperty(i, "pavg0") == 1 and not any then
			sim.partProperty(i, "pavg0", 0)
			sim.partProperty(i, "life", 20)
		end
	end

end)

elem.property(ffld, "Graphics", function (i, r, g, b)

	local anyParts = sim.partProperty(i, "pavg0")

	local enabled = sim.partProperty(i, "tmp2")
	local flash = sim.partProperty(i, "life")

	local colr = r
	local colg = g
	local colb = b

	local firea = 0
	
	local pixel_mode = ren.PMODE_FLAT

	local ctype = sim.partProperty(i, "ctype")
	local range = math.floor(math.max(sim.partProperty(i, "temp") - 273.15, 0))
	local tmp = sim.partProperty(i, "tmp")

	local pattern = bit.band(tmp, 0x11000000)
	local shape = bit.band(tmp, 0x00111000)
	local mode = bit.band(tmp, 0x00000111)

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
	if bit.band( elem.property(t, "Properties"), elem.PROP_NOCTYPEDRAW) == 0 then
		sim.partProperty(i, "ctype", t)
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

elem.element(grph, elem.element(elem.DEFAULT_PT_DMND))
elem.property(grph, "Name", "GRPH")
elem.property(grph, "Description", "Graphite. Strong solid. Can withstand extreme conditions and slows radiation.")
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

-- event.register(event.keypress, function(key, scan, rep, shift, ctrl, alt)
-- 	if not rep then
-- 		print (key)
-- 		if key == 102 then -- F
-- 			graphiteCycle = nextGraphiteCycle
-- 			nextGraphiteCycle = (graphiteCycle + 1) % 4
-- 		end
-- 	end
-- end)  

function sparkGraphite(i, pavg)
	if i ~= nil and (sim.partProperty(i, "type") == grph or (sim.partProperty(i, "type") == elem.DEFAULT_PT_SPRK and sim.partProperty(i, "ctype") == grph)) then
		local dir = sim.partProperty(i, "pavg1")
		if bit.band(dir, oppositeDirections[pavg] + pavg) == 0 and bit.band(dir, 0x30) == 0x0 then 
		
			sim.partChangeType(i, elem.DEFAULT_PT_SPRK)
			sim.partProperty(i, "ctype", grph)
			if sim.partProperty(i, "life") <= 3 then
				sim.partProperty(i, "pavg1", pavg)
			else
				sim.partProperty(i, "pavg1", bit.bor(sim.partProperty(i, "pavg1"), pavg))
			end
			sim.partProperty(i, "life", 4)
			sim.partProperty(i, "pavg0", nextGraphiteCycle)
			return true
		end
	end
	return false
end

function graphiteSparkNormal(i)
	if i ~= nil then
		local type = sim.partProperty(i, "type")
		if bit.band(elements.property(type, "Properties"), elements.PROP_CONDUCTS) ~= 0 then
			local px, py = sim.partPosition(i)
			sim.partCreate(-1, px, py, elem.DEFAULT_PT_SPRK)
			-- sim.partChangeType(i, elem.DEFAULT_PT_SPRK)
			-- sim.partProperty(i, "life", 4)
			-- sim.partProperty(i, "ctype", type)
		end
	end
end

elem.property(elem.DEFAULT_PT_SPRK, "Update", function(i, x, y, s, n)
	
	updateGraphiteCycle = true
	local ctype = sim.partProperty(i, "ctype")
	local life = sim.partProperty(i, "life")
	local timer = sim.partProperty(i, "pavg0")
	if ctype == grph then
		if timer == graphiteCycle then
			for d = 1, 4 do
				local pavg = 2 ^ (d  - 1)
				local dir = bit.band(sim.partProperty(i, "pavg1"), pavg)
				if dir == pavg then
					for p = 1, 4 do
						local part = sim.pmap(x + initialDetectionOffsets[d][1] * p, y + initialDetectionOffsets[d][2] * p)
						if not sparkGraphite(part, dir) then
							graphiteSparkNormal(part)
							break
						end
					end
				end
			end
		end

		if life == 1 then
			sim.partProperty(i, "pavg1", 0x10)
		end
	else
		for d = 1, 4 do
			-- print(initialDetectionOffsets[d])
			local pavg = 2 ^ (d  - 1)
			local nearbyParts = nearbyPartsTable[pavg](x, y)
			for p = 1, 4 do
				local part = sim.pmap(x + initialDetectionOffsets[d][1] * p, y + initialDetectionOffsets[d][2] * p)
				if not sparkGraphite(part, pavg) then
					break
				end
			end
		end
	end
end, 3)

elem.property(grph, "Update", function(i, x, y, s, n)

	if sim.partProperty(i, "pavg1") == 0x10 then
		sim.partProperty(i, "pavg1", 0x20)
	elseif sim.partProperty(i, "pavg1") == 0x20 then
		sim.partProperty(i, "pavg1", 0)
	end

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
		if math.random(100) == 1 then
			sim.partKill(a)
		end
	end

	local tempC = sim.partProperty(i, "temp") - 273.15

	if tempC < 400 then
		sim.partProperty(i, "pavg0", 0)
	end

	local burnHealth = sim.partProperty(i, "pavg0")

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
			sim.partProperty(i, "pavg0", graphiteExtinguishTime)
		else
			sim.partProperty(i, "pavg0", sim.partProperty(i, "pavg0") - 1)
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
			sim.partProperty(i, "pavg0", graphiteExtinguishTime)
		end
	end

end)



function graphiteGraphics(i, r, g, b)

	local tempC = sim.partProperty(i, "temp") - 273.15
	-- local vel = sim.velocityX(number x, number y)

	local pixel_mode = ren.PMODE_FLAT

	local colr = r
	local colg = g
	local colb = b

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



	if sim.partProperty(i, "life") >= brokenGraphBurnHealth then
		local randomNeighbor = sim.pmap(x + math.random(3) - 2, y + math.random(3) - 2)
		if tempC > 1000 or randomNeighbor ~= nil and (graphiteIgniters[sim.partProperty(randomNeighbor, "type")] == true) then
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


	if tempC < 400 then
		sim.partProperty(i, "pavg0", 0)
	end

	local burnHealth = sim.partProperty(i, "pavg0")

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
			local randomNeighbor = sim.pmap(x + math.random(5) - 3, y + math.random(5) - 4)
			if randomNeighbor ~= nil and sim.partProperty(randomNeighbor, "type") == grph then
				sim.partProperty(i, "ctype", elem.DEFAULT_PT_METL)
				sim.partChangeType(randomNeighbor, elem.DEFAULT_PT_BCOL)
			end
		end
	end
end)

