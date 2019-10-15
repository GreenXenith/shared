shared = {}

function shared.is_owner(pos, name)
	if minetest.check_player_privs(name, areas.adminPrivs) then
		return true
	end
	if minetest.get_meta(pos):get_string("owner") == name then
		return true
	end
	return false
end

function shared.can_interact(pos, name)
	if shared.is_owner(pos, name) then
		return true
	end
	local owners = areas:getNodeOwners(pos)
	for _, owner in pairs(owners) do
		if owner == name then
			return true
		end
	end
	return false
end