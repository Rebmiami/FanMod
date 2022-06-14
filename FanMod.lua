-- Element definitions

local smdb = elem.allocate("FanMod", "SMDB") -- Super mega death bomb
local srad = elem.allocate("FanMod", "SRAD") -- Hidden. Used by SDMB as part of its explosion

local trit = elem.allocate("FanMod", "TRIT") -- Tritium



elem.element(smdb, elem.element(elem.DEFAULT_PT_DEST))
elem.property(smdb, "Name", "SDMB")
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
			if tpt.get_wallmap(wx, wy) ~= 0 then
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
		sim.partProperty(part, "life", 5000)
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
	if tpt.get_wallmap(wx, wy) ~= 0 then
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
-- Translation: The only element that SMDB is weak against is CONV, so modify CONV so that it can be 
-- overtaken more easily.
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