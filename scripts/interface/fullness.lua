add_printer("/charpane.php", function()
	if setting_enabled("use custom kolproxy charpane") then return end

	if tonumber(api_flag_config().compactchar) == 1 then
		text = text:gsub([[(<hr width=50%%>.-)(</table><hr width=50%%><table align=center cellpadding=1 cellspacing=1>)]], function (a, b)
			local spleentext = ""
			local spleen = spleen_display_string()
			if tostring(spleen) ~= "0" then
				spleentext = [[<tr><td align=right>Spleen:</td><td align=left><b>]] .. spleen .. [[</b></td></tr>]]
			end
			if a:match(">Drunk:<") then
				return a:gsub([[(.-)(<tr><td align=right>Drunk:</td><td align=left><b>[0-9,]-</b></td></tr>)]], function (x, y)
					return x .. y .. spleentext
				end) .. b
			else
				return a .. spleentext .. b
			end
		end)
	else
		text = text:gsub([[^(.-)(<table cellpadding=3 align=center>)]], function (a, b)
			local spleentext = ""
			local spleen = spleen_display_string()
			if tostring(spleen) ~= "0" then
				local spleen_description = random_choice { "Spleen", "Melancholy", "Moroseness" }
				spleentext = [[<tr><td align=right>]] .. spleen_description .. [[:</td><td><b>]] .. spleen .. [[</b></td></tr>]]
			end
			if a:match("<tr><td align=right>[^<]-</td><td><b>[0-9,]-</b></td></tr>") then
				return a:gsub([[(.-)(<tr><td align=right>[^<]-</td><td><b>[0-9,]-</b></td></tr>)]], function (x, y)
					return x .. y .. spleentext
				end) .. b
			else
				return a:gsub("</table>$", function() return spleentext .. "</table>" .. b end)
			end
			return a .. b
		end)
	end
end)

local function get_item_field(itemid, field)
	local item = get_item_data_by_id(itemid)
	if item then
		return item[field]
	else
		return nil
	end
end

-- TODO: warn when using frosty mug, divine champagne flute etc. Are all those actually OK since they use inv_booze?

-- TODO: warn when drinking from cafes
--   /cafe.php [("cafeid","1"),("pwd","..."),("action","CONSUME!"),("whichitem","1257")]

add_always_warning("/inv_booze.php", function()
	for _, x in ipairs { "steel margarita", "shot of flower schnapps", "used beer", "slap and slap again", "beery blood" } do
		if tonumber(params.whichitem) == get_itemid(x) then
			return
		end
	end
	if ascensionstatus() == "Aftercore" or have_skill("The Ode to Booze") then
		if not buff("Ode to Booze") then
			return "You do not have Ode to Booze active.", "drinking without ode"
		end
		local drunk = tonumber(get_item_field(tonumber(params.whichitem), "drunkenness"))
		if not drunk then
			return "This booze is unknown and could potentially be larger than your remaining turns of Ode to Booze.", "drinking unknown booze", "OK, disable the warning."
		else
			local need_turns = (tonumber(params.quantity) or 1) * drunk
			if buffturns("Ode to Booze") < need_turns then
				return "You do not have enough turns of Ode to Booze active (need " .. need_turns .. " turns).", "drinking without enough turns of ode to booze"
			end
		end
	end
end)

add_always_warning("/inv_booze.php", function()
	local safe = false
	local unknown = true
	local whichitem = tonumber(params.whichitem)
	if whichitem then
		local drunk = tonumber(get_item_field(whichitem, "drunkenness"))
		if drunk then
			unknown = false
			if drunkenness() + drunk * (tonumber(params.quantity) or 1) <= maxsafedrunkenness() then
				safe = true
			elseif whichitem == get_itemid("steel margarita") then
				safe = true
			end
		end
	end
	
	if not unknown and not safe and drunkenness() < maxsafedrunkenness() then
		return "You have not drunk to full liver before nightcapping.", "not drunk before nightcapping"
	end
end)

add_extra_always_warning("/inv_booze.php", function()
	local safe = false
	local unknown = true
	local whichitem = tonumber(params.whichitem)
	if whichitem then
		local drunk = tonumber(get_item_field(whichitem, "drunkenness"))
		if drunk then
			unknown = false
			if drunkenness() + drunk * (tonumber(params.quantity) or 1) <= maxsafedrunkenness() then
				safe = true
			elseif whichitem == get_itemid("steel margarita") then
				safe = true
			end
		end
	end
	
	if unknown then
		return "This booze is unknown and could potentially make you fallen-down drunk.", "overdrinking unknown booze", "OK, disable the warning and do it."
	elseif not safe then
		return "This booze will make you fallen-down drunk.", "overdrinking", "OK, I'm done for today, disable the warning and do it."
	end
end)

local function check_eating_warning(itemid, quantity, whicheffect)
	for _, x in ipairs { "steel lasagna", "flower petal pie", "nailswurst", "fettucini &eacute;pines Inconnu", "gunpowder burrito" } do
		if tonumber(params.whichitem) == get_itemid(x) then
			return
		end
	end
	whicheffect = whicheffect or "Got Milk"
	if not buff(whicheffect) then
		return "You do not have " .. whicheffect .. " active.", "eating without " .. whicheffect
	end
	local full = tonumber(get_item_field(itemid, "fullness"))
	if not full then
		return "This food is unknown and could potentially be larger than your remaining turns of " .. whicheffect .. ".", "eating unknown food", "OK, disable the warning."
	else
		local need_turns = quantity * full
		if buffturns(whicheffect) < need_turns then
			return "You do not have enough turns of " .. whicheffect .. " active (need " .. need_turns .. " turns).", "eating without enough turns of " .. whicheffect
		end
	end
end

add_aftercore_warning("/inv_eat.php", function()
	return check_eating_warning(tonumber(params.whichitem), (tonumber(params.quantity) or 1))
end)

add_aftercore_warning("/inv_eat.php", function()
	if buff("Gar-ish") then return end
	for _, x in ipairs { "fishy fish lasagna", "gnat lasagna", "long pork lasagna" } do
		if tonumber(params.whichitem) == get_itemid(x) then
			return "You do not have Gar-ish active while eating lasagna.", "eating lasagna without Gar-ish"
		end
	end
end)

add_extra_ascension_warning("/inv_eat.php", function()
	if have_buff("Got Milk") or have("milk of magnesium") or (have("glass of goat's milk") and (classid() == 4 or have_skill("Advanced Saucecrafting"))) then
		return check_eating_warning(tonumber(params.whichitem), (tonumber(params.quantity) or 1))
	end
end)

add_always_warning("/inv_eat.php", function()
	if ascensionpathid() == 8 then
		return check_eating_warning(tonumber(params.whichitem), (tonumber(params.quantity) or 1), "Song of the Glorious Lunch")
	end
end)
