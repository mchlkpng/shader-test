local lighting = {}

lighting.lights = {}

lighting.to_update = {}

function lighting.LIGHT_TYPE_DIRECTIONAL() return 0 end
function lighting.LIGHT_TYPE_POINT() return 1 end
function lighting.LIGHT_TYPE_SPOTLIGHT() return 2 end
--[[
LIGHT DATA TABLES:

color

Directional Light needs in table:
pointing_to (position)

Point light needs in table:
constant (number),
linear (number),
quad (number)

Spotlight needs in table:
pointing_to (position),
phi (number [inner cutoff])
gamma (number [outer cuttoff])

]]
function lighting.add_light(url, light_type, data_table)

	
	local w = go.get_world_position(url)
	if not w then
		error("url to light source must be a valid gameobject")
	end
	local constant = data_table.constant
	local linear = data_table.linear
	local quad = data_table.quad
	local pointing_to = data_table.pointing_to

	if light_type ~= 0 and light_type ~= 1 and light_type ~= 2 then
		error("Incorrect light type, light type must be constant lighting.LIGHT_TYPE_[light type]")
	end
	local light = {
		name = url, --must be url of object, NOT sprite
		position = go.get_world_position(url),
		color = data_table.color or go.get(url.."#sprite", "tint"),
		light_type = light_type,
		constant = constant or 0,
		linear = linear or 0,
		quad = quad or 0,
		direction = vmath.vector3(0),
		phi = data_table.phi or 0,
		gamma = data_table.gamma or 0
	}
	lighting.lights[url] = light
	if data_table.color then go.set(url.."#sprite", "tint", data_table.color) end
	if light_type == lighting.LIGHT_TYPE_DIRECTIONAL() or  light_type == lighting.LIGHT_TYPE_SPOTLIGHT() then
		if pointing_to then
			light.direction = light.position - pointing_to
		else
			light.direction = light.position - vmath.vector3(0)
		end
	end


	msg.post("@render:", "add_light", light)
end

function lighting.remove_light(url)
	lighting.cancel_animations(url)
	lighting.lights[url] = nil
	msg.post("@render:", "remove_light", {name = url})
end

function lighting.update_value(url, key, value, forAnim)
	if not lighting.lights[url] then error("Must provide valid object representing light") end
	local valid = {
		position = "userdata",
		light_type = "number",
		color = "userdata",
		constant = "number",
		linear = "number",
		quad = "number",
		pointing_to = "userdata",
		phi = "number",
		gamma = "number"
	}

	if not valid[key] then
		error(key.." is not a valid key type for lights")
	elseif valid[key] ~= type(value) then
		error("key '"..key.."' requires value type "..valid[key].." but had been provided a value of type "..type(value))
	end

	if key == "light_type" then
		if value - 2 < -2 or value -2 > 0 then
			error("key light_type accepts types of values provided by lights.LIGHT_TYPE_[light type]")
		end
	end

	if key == "position" or key == "pointing_to" then
		if not (value.x and value.y and value.z) or pcall(function() local a = value.w end)then
			error("Value of key '"..key.."' must be of type vector3")
		end
	end

	if key == "color" then
		if not (value.x and value.y and value.z) or not pcall(function() local a = value.w end) then
			error("Value of key '"..key.."' must be of type vector4")
		end
	end

	if not forAnim then
		if key == "color" then
			go.set(url.."#sprite", "tint", value)
		elseif key == "light_type" then
			go.set(url.."#sprite", "light_type", vmath.vector4(value))
		elseif key == "constant" then
			go.set(url.."#sprite", "attenuation.x", value)
		elseif key == "linear" then
			go.set(url.."#sprite", "attenuation.y", value)
		elseif key == "quad" then
			go.set(url.."#sprite", "attenuation.z", value)

		elseif key == "phi" then
			go.set(url.."#sprite", "spot_data.x", value)
		elseif key == "gamma" then
			go.set(url.."#sprite", "spot_data.y", value)
		elseif key == "position" then
			go.set(url, "position", value)
		elseif key == "pointing_to" then
			local pt = go.get(url.."#sprite", "pointing_to")
			print(pt)
			go.set(url.."#sprite", key, vmath.vector4(value.x, value.y, value.z, 0))
		end
	end
	lighting.lights[url][key] = value


	local k, v= key, nil 
	if key == "pointing_to" then
		k = "direction"
		v = lighting.lights[url].position-value
	end


	msg.post("@render:", "update_light_value", {url=url, key=k, value=v or value})
end

function lighting.animate_value(url, key, playback, value, easing, duration, delay, callback)
	if not lighting.lights[url] then error("Must provide valid object representing light") end
	local valid = {
		position = "userdata",
		light_type = "number",
		color = "userdata",
		constant = "number",
		linear = "number",
		quad = "number",
		pointing_to = "userdata",
		phi = "number",
		gamma = "number"
	}

	if not valid[key] then
		error(key.." is not a valid key type for lights")
	elseif valid[key] ~= type(value) then
		error("key '"..key.."' requires value type "..valid[key].." but had been provided a value of type "..type(value))
	end

	if key == "light_type" then
		if value - 2 < -2 or value -2 > 0 then
			error("key light_type accepts types of values provided by lights.LIGHT_TYPE_[light type]")
		end
	end

	if key == "position" or key == "pointing_to" then
		if not (value.x and value.y and value.z) or pcall(function() local a = value.w end)then
			error("Value of key '"..key.."' must be of type vector3")
		end
	end

	if key == "color" then
		if not (value.x and value.y and value.z) or not pcall(function() local a = value.w end) then
			error("Value of key '"..key.."' must be of type vector4")
		end
	end

	if delay == nil then delay = 0 end
	local spriteurl = url .. "#sprite"
	if key == "color" then
		go.animate(spriteurl, "tint", playback, value, easing, duration)
	elseif key == "light_type" then
		error("Don't even think of animating 'light_type'. Are you high?")
		return
	elseif key == "constant" then
		go.animate(spriteurl, "attenuation.x", playback, value, easing, duration, delay, callback)
	elseif key == "linear" then
		go.animate(spriteurl, "attenuation.y", playback, value, easing, duration, delay, callback)
	elseif key == "quad" then
		go.animate(spriteurl, "attenuation.z", playback, value, easing, duration, delay, callback)

	elseif key == "phi" then
		go.animate(spriteurl, "spot_data.x", playback, value, easing, duration, delay, callback)
	elseif key == "gamma" then
		go.animate(spriteurl, "spot_data.y", playback, value, easing, duration, delay, callback)
	elseif key == "position" then
		go.animate(url, key, playback, value, easing, duration, delay, callback)
	elseif key == "pointing_to" then
		print(go.get(spriteurl, "light_type"))
		go.animate(spriteurl, key, playback, vmath.vector4(value.x, value.y, value.z, 0), easing, duration, delay, callback)
	end

	lighting.to_update[url..key] = {url = url, key = key}
end

function lighting.cancel_animations(url, optionalkey)
	if not optionalkey then
		for k, v in pairs(lighting.to_update) do
			if k:sub(1, #url) == url then
				lighting.to_update[k] = nil
			end
		end
	else
		lighting.to_update[url..optionalkey] = nil
	end
end

function lighting.update_view_position(position)
	msg.post("@render:", "view_pos", {pos = position})
end

return lighting