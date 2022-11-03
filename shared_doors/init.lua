if not minetest.global_exists("shared") then
	minetest.log("error", "mod 'shared_chest' depends on mod 'shared' (not found).")
	return
end

local function replace_old_owner_information(pos)
	local meta = minetest.get_meta(pos)
	local owner = meta:get_string("doors_owner")
	if owner and owner ~= "" then
		meta:set_string("owner", owner)
		meta:set_string("doors_owner", "")
	end
end

--[[ Doors ]]--

-- table used to aid door opening/closing
local transform = {
	{
		{v = "_a", param2 = 3},
		{v = "_a", param2 = 0},
		{v = "_a", param2 = 1},
		{v = "_a", param2 = 2},
	},
	{
		{v = "_b", param2 = 1},
		{v = "_b", param2 = 2},
		{v = "_b", param2 = 3},
		{v = "_b", param2 = 0},
	},
	{
		{v = "_b", param2 = 1},
		{v = "_b", param2 = 2},
		{v = "_b", param2 = 3},
		{v = "_b", param2 = 0},
	},
	{
		{v = "_a", param2 = 3},
		{v = "_a", param2 = 0},
		{v = "_a", param2 = 1},
		{v = "_a", param2 = 2},
	},
}

local function can_dig_door(pos, digger)
	replace_old_owner_information(pos)
	if default.can_interact_with_node(digger, pos) or shared.can_interact(pos, digger) then
		return true
	else
		minetest.record_protection_violation(pos, digger:get_player_name())
		return false
	end
end

local function door_toggle(pos, node, clicker)
	local meta = minetest.get_meta(pos)
	node = node or minetest.get_node(pos)
	local def = minetest.registered_nodes[node.name]
	local name = def.door.name

	local state = meta:get_string("state")
	if state == "" then
		-- fix up lvm-placed right-hinged doors, default closed
		if node.name:sub(-2) == "_b" then
			state = 2
		else
			state = 0
		end
	else
		state = tonumber(state)
	end

	replace_old_owner_information(pos)

	-- until Lua-5.2 we have no bitwise operators :(
	if state % 2 == 1 then
		state = state - 1
	else
		state = state + 1
	end

	local dir = node.param2
	if state % 2 == 0 then
		minetest.sound_play(def.door.sounds[1],
			{pos = pos, gain = 0.3, max_hear_distance = 10})
	else
		minetest.sound_play(def.door.sounds[2],
			{pos = pos, gain = 0.3, max_hear_distance = 10})
	end

	minetest.swap_node(pos, {
		name = name .. transform[state + 1][dir+1].v,
		param2 = transform[state + 1][dir+1].param2
	})
	meta:set_int("state", state)

	return true
end

local function register_shared_door(name, def)
	if not def.protected then
		def.protected = false
	end

	doors.register("shared_doors:door_shared_"..name, {
			tiles = {{name = "doors_door_"..name..".png^shared_door_lock.png"}},
			description = "Shared "..name:gsub("^%l", string.upper).." Door",
			inventory_image = "doors_item_"..name..".png^shared_lock.png",
			protected = def.protected,
			groups = def.groups,
			sounds = def.sounds,
			sound_open = "doors_"..def.toggle_sound.."_open",
			sound_close = "doors_"..def.toggle_sound.."_close",
	})

	minetest.override_item("shared_doors:door_shared_"..name.."_a", {
		on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
			if shared.can_interact(pos, clicker:get_player_name()) then
				door_toggle(pos, node, clicker)
				return itemstack
			end
		end,

		can_dig = can_dig_door
	})

	minetest.override_item("shared_doors:door_shared_"..name.."_b", {
		on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
			if shared.can_interact(pos, clicker:get_player_name()) then
				door_toggle(pos, node, clicker)
				return itemstack
			end
		end,

		can_dig = can_dig_door
	})

	minetest.register_craft({
		type = "shapeless",
		output = "shared_doors:door_shared_"..name,
		recipe = {"doors:door_"..name, "default:copper_ingot"},
	})

	local item = def.craft_item

	minetest.register_craft({
		output = "shared_doors:door_shared_"..name,
		recipe = {
			{item, item},
			{item, "default:copper_ingot"},
			{item, item}
		}
	})
end

register_shared_door("wood", {
	groups = {choppy = 2, oddly_breakable_by_hand = 2, flammable = 2},
	sounds = default.node_sound_wood_defaults(),
	toggle_sound = "door",
	craft_item = "group:wood",
})

register_shared_door("steel", {
	protected = true,
	groups = {cracky = 1, level = 2},
	sounds = default.node_sound_metal_defaults(),
	toggle_sound = "steel_door",
	craft_item = "default:steel_ingot",
})

register_shared_door("glass", {
	groups = {cracky=3, oddly_breakable_by_hand=3},
	sounds = default.node_sound_glass_defaults(),
	toggle_sound = "glass_door",
	craft_item = "default:glass",
})

register_shared_door("obsidian_glass", {
	groups = {cracky=3},
	sounds = default.node_sound_glass_defaults(),
	toggle_sound = "glass_door",
	craft_item = "default:obsidian_glass",
})

--[[ Trap Doors ]]--

local function trapdoor_toggle(pos, node, clicker)
	node = node or minetest.get_node(pos)

	replace_old_owner_information(pos)

	local def = minetest.registered_nodes[node.name]

	if string.sub(node.name, -5) == "_open" then
		minetest.sound_play(def.sound_close,
			{pos = pos, gain = 0.3, max_hear_distance = 10})
		minetest.swap_node(pos, {name = string.sub(node.name, 1,
			string.len(node.name) - 5), param1 = node.param1, param2 = node.param2})
	else
		minetest.sound_play(def.sound_open,
			{pos = pos, gain = 0.3, max_hear_distance = 10})
		minetest.swap_node(pos, {name = node.name .. "_open",
			param1 = node.param1, param2 = node.param2})
	end
end

local function register_shared_trapdoor(name, def)
	if not def.protected then
		def.protected = false
	end

	if not def.texture then
		def.texture = "doors_trapdoor_"..name
	end

	doors.register_trapdoor("shared_doors:trapdoor_shared_"..name, {
		description = name:gsub("^%l", string.upper).." Trapdoor",
		inventory_image = def.texture..".png^shared_lock.png",
		wield_image = def.texture..".png^shared_lock.png",
		tile_front = def.texture..".png^shared_lock.png",
		tile_side = def.texture.."_side.png",
		protected = def.protected,
		sounds = def.sounds,
		sound_open = "doors_"..def.toggle_sound.."_open",
		sound_close = "doors_"..def.toggle_sound.."_close",
		groups = def.groups
	})

	minetest.override_item("shared_doors:trapdoor_shared_"..name, {
		on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
			if shared.can_interact(pos, clicker:get_player_name()) then
				trapdoor_toggle(pos, node, clicker)
				return itemstack
			end
		end,

		can_dig = can_dig_door
	})

	minetest.override_item("shared_doors:trapdoor_shared_"..name.."_open", {
		on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
			if shared.can_interact(pos, clicker:get_player_name()) then
				trapdoor_toggle(pos, node, clicker)
				return itemstack
			end
		end,

		can_dig = can_dig_door
	})

	if not def.amount then
		def.amount = ""
	end

	minetest.register_craft({
		output = "shared_doors:trapdoor_shared_"..name.." "..tostring(def.amount),
		recipe = def.recipe
	})

	if def.recipe_shapless then
		minetest.register_craft({
			type = "shapeless",
			output = "shared_doors:trapdoor_shared_"..name,
			recipe = def.recipe_shapless,
		})
	end
end

register_shared_trapdoor("wood", {
	groups = {choppy = 2, oddly_breakable_by_hand = 2, flammable = 2, door = 1},
	sounds = default.node_sound_wood_defaults(),
	toggle_sound = "door",
	texture = "doors_trapdoor",
	recipe = {
		{"group:wood", "default:copper_ingot", "group:wood"},
		{"group:wood", "group:wood", "group:wood"},
	},
	recipe_shapless = {"doors:trapdoor", "default:copper_ingot"},
	amount = 2,
})

register_shared_trapdoor("steel", {
	protected = true,
	groups = {cracky = 1, level = 2, door = 1},
	sounds = default.node_sound_metal_defaults(),
	toggle_sound = "steel_door",
	recipe = {
		{"default:steel_ingot", "default:copper_ingot"},
		{"default:steel_ingot", "default:steel_ingot"},
	},
	recipe_shapless = {"doors:trapdoor_steel", "default:copper_ingot"},
})
