if not minetest.global_exists("shared") then
	minetest.log("error", "mod 'shared_chest' depends on mod 'shared' (not found).")
	return
end

local F = minetest.formspec_escape

local rim = "^shared_rim.png"

minetest.register_node("shared_chest:shared_chest", {
	description = "Shared Chest",
	tiles = {"default_chest_top.png"..rim, "default_chest_top.png"..rim, "default_chest_side.png"..rim,
		"default_chest_side.png"..rim, "default_chest_side.png"..rim, "default_chest_lock.png^shared_lock.png"..rim},
	paramtype2 = "facedir",
	groups = {snappy=2, choppy=2, oddly_breakable_by_hand=2, tubedevice = 1, tubedevice_receiver = 1},
-- Pipeworks
	tube = {
		insert_object = function(pos, node, stack, direction)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			return inv:add_item("main", stack)
		end,
		can_insert = function(pos, node, stack, direction)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			return inv:room_for_item("main", stack)
		end,
		input_inventory = "main",
		connect_sides = {left = 1, right = 1, back = 1, front = 1, bottom = 1, top = 1}
	},
	legacy_facedir_simple = true,
	sounds = default.node_sound_wood_defaults(),
	on_construct = function(pos)

		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()

		meta:set_string("infotext", "Shared Chest")
		meta:set_string("name", "")
		inv:set_size("main", 8 * 4)
	end,

	after_place_node = function(pos, placer, itemstack, pointed_thing)
		local meta = minetest.get_meta(pos)

		meta:set_string("owner", placer:get_player_name())
	end,

	can_dig = function(pos,player)

		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()

		if inv:is_empty("main") then

			if shared.is_owner(pos, player:get_player_name()) then
				return true
			end
		end
	end,

	on_metadata_inventory_put = function(pos, listname, index, stack, player)

		minetest.log("action", player:get_player_name().." moves stuff to protected chest at "..minetest.pos_to_string(pos))
	end,

	on_metadata_inventory_take = function(pos, listname, index, stack, player)

		minetest.log("action", player:get_player_name().." takes stuff from protected chest at "..minetest.pos_to_string(pos))
	end,

	on_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)

		minetest.log("action", player:get_player_name().." moves stuff inside protected chest at "..minetest.pos_to_string(pos))
	end,

	allow_metadata_inventory_put = function(pos, listname, index, stack, player)

		if not shared.can_interact(pos, player:get_player_name()) then
			return 0
		end

		return stack:get_count()
	end,

	allow_metadata_inventory_take = function(pos, listname, index, stack, player)

		if not shared.can_interact(pos, player:get_player_name()) then
			return 0
		end

		return stack:get_count()
	end,

	allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)

		if not shared.can_interact(pos, player:get_player_name()) then
			return 0
		end

		return count
	end,

	on_rightclick = function(pos, node, clicker)

		if not shared.can_interact(pos, clicker:get_player_name()) then
			return
		end

		local meta = minetest.get_meta(pos)

		if not meta then
			return
		end

		local spos = pos.x .. "," .. pos.y .. "," ..pos.z
		local formspec = "size[8,9]"
			.. default.gui_bg
			.. default.gui_bg_img
			.. default.gui_slots
			.. "list[nodemeta:".. spos .. ";main;0,0.3;8,4;]"
			.. "button[0,4.5;2,0.25;toup;" .. F("To Chest") .. "]"
			.. "field[2.3,4.8;4,0.25;chestname;;"
			.. meta:get_string("name") .. "]"
			.. "button[6,4.5;2,0.25;todn;" .. F("To Inventory") .. "]"
			.. "list[current_player;main;0,5;8,1;]"
			.. "list[current_player;main;0,6.08;8,3;8]"
			.. "listring[nodemeta:" .. spos .. ";main]"
			.. "listring[current_player;main]"

			minetest.show_formspec(
				clicker:get_player_name(),
				"shared_chest:shared_chest_" .. minetest.pos_to_string(pos),
				formspec)
	end,

	on_blast = function() end,
})

-- Shared Chest recipes

minetest.register_craft({
	output = 'shared_chest:shared_chest',
	recipe = {
		{'group:wood', 'group:wood', 'group:wood'},
		{'group:wood', 'default:copper_ingot', 'group:wood'},
		{'group:wood', 'group:wood', 'group:wood'},
	}
})

minetest.register_craft({
	type = "shapeless",
	output = 'shared_chest:shared_chest',
	recipe = {'default:chest', 'default:copper_ingot'},
})

-- Shared Chest formspec buttons

minetest.register_on_player_receive_fields(function(player, formname, fields)

	if not formname:find("^shared_chest:shared_chest_") then
		return
	end

	local pos = minetest.string_to_pos(formname:gsub("^shared_chest:shared_chest_", ""))

	if minetest.is_protected(pos, player:get_player_name()) then
		return
	end

	local meta = minetest.get_meta(pos); if not meta then return end
	local chest_inv = meta:get_inventory() ; if not chest_inv then return end
	local player_inv = player:get_inventory()
	local leftover

	if fields.toup then

		-- copy contents of players inventory to chest
		for i, v in ipairs(player_inv:get_list("main") or {}) do

			if chest_inv:room_for_item("main", v) then

				leftover = chest_inv:add_item("main", v)

				player_inv:remove_item("main", v)

				if leftover
				and not leftover:is_empty() then
					player_inv:add_item("main", v)
				end
			end
		end

	elseif fields.todn then

		-- copy contents of chest to players inventory
		for i, v in ipairs(chest_inv:get_list("main") or {}) do

			if player_inv:room_for_item("main", v) then

				leftover = player_inv:add_item("main", v)

				chest_inv:remove_item("main", v)

				if leftover
				and not leftover:is_empty() then
					chest_inv:add_item("main", v)
				end
			end
		end

	elseif fields.chestname then

		-- change chest infotext to display name
		if fields.chestname ~= "" then

			meta:set_string("name", fields.chestname)
			meta:set_string("infotext",
				"Shared Chest ("..fields.chestname..")")
		else
			meta:set_string("infotext", "Shared Chest")
		end

	end
end)
