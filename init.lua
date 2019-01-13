local nodes = {
	floor = {"default:cobble", "default:stone", "default:obsidian"},
	wall = {"default:wood", "default:brick", "default:tree"},
	doorway = "air",
}
local height_min = 3
local width_min = 5
local width_extra = 8

local phash = minetest.hash_node_position
local punhash = minetest.get_position_from_hash

local function can_change(pos)
	local node = minetest.get_node_or_nil(pos)
	if not node then
		minetest.load_area(pos)
		node = minetest.get_node(pos)
	end
	return node.name == "air"
end

local function make_wall(pos1, pos2, data)
	local wall_node = nodes.wall[math.random(#nodes.wall)]
	for z = pos1.z, pos2.z do
		for y = pos1.y, pos2.y do
			for x = pos1.x, pos2.x do
				data[phash{x=x,y=y,z=z}] = wall_node
			end
		end
	end
	local p_door = {x=math.random(pos1.x, pos2.x), y=pos1.y,
		z=math.random(pos1.z, pos2.z)}
	data[phash(p_door)] = nodes.doorway
	p_door.y = p_door.y + 1
	data[phash(p_door)] = nodes.doorway
end

local function make_floor(pos1, pos2, data)
	local floor_node = nodes.floor[math.random(#nodes.floor)]
	for z = pos1.z, pos2.z do
		for y = pos1.y, pos2.y do
			for x = pos1.x, pos2.x do
				data[phash{x=x,y=y,z=z}] = floor_node
			end
		end
	end
	local p_door = {x=math.random(pos1.x, pos2.x), y=pos1.y,
		z=math.random(pos1.z, pos2.z)}
	data[phash(p_door)] = nodes.doorway
end

local function subdivide_room(pos1, pos2, data)
	-- TODO: do not put walls next to doorways
	local divisions = {}
	-- Choose a bigger width limit randomly
	local xwidth = math.random(width_min, width_min + width_extra)
	local zwidth = math.random(width_min, width_min + width_extra)
	if pos2.x > pos1.x + xwidth * 2 - 1 then
		divisions[#divisions+1] = "x"
	end
	if pos2.z > pos1.z + zwidth * 2 - 1 then
		divisions[#divisions+1] = "z"
	end
	if pos2.y > pos1.y + height_min * 2 - 1 then
		divisions[#divisions+1] = "y"
	end
	if #divisions == 0 then
		-- Room is small enough, nothing to do
		return
	end
	local division = divisions[math.random(#divisions)]
	if division == "x" then
		local x_mid = math.random(pos1.x + width_min, pos2.x - width_min)
		local wall_p1 = {x=x_mid, y=pos1.y, z=pos1.z}
		local wall_p2 = {x=x_mid, y=pos2.y, z=pos2.z}
		make_wall(wall_p1, wall_p2, data)
		wall_p2.x = wall_p2.x-1
		wall_p1.x = wall_p1.x+1
		subdivide_room(pos1, wall_p2, data)
		subdivide_room(wall_p1, pos2, data)
		return
	end
	if division == "z" then
		local z_mid = math.random(pos1.z + width_min, pos2.z - width_min)
		local wall_p1 = {x=pos1.x, y=pos1.y, z=z_mid}
		local wall_p2 = {x=pos2.x, y=pos2.y, z=z_mid}
		make_wall(wall_p1, wall_p2, data)
		wall_p2.z = wall_p2.z-1
		wall_p1.z = wall_p1.z+1
		subdivide_room(pos1, wall_p2, data)
		subdivide_room(wall_p1, pos2, data)
		return
	end
	assert(division == "y")
	local y_mid = math.random(pos1.y + height_min, pos2.y - height_min)
	local floor_p1 = {x=pos1.x, y=y_mid, z=pos1.z}
	local floor_p2 = {x=pos2.x, y=y_mid, z=pos2.z}
	make_floor(floor_p1, floor_p2, data)
	floor_p2.y = floor_p2.y-1
	floor_p1.y = floor_p1.y+1
	subdivide_room(pos1, floor_p2, data)
	subdivide_room(floor_p1, pos2, data)
end

local function create_rooms(pos1, pos2)
	local data = {}

	-- Add surrounding walls and floors
	make_floor(pos1, {x=pos2.x, y=pos1.y, z=pos2.z}, data)
	make_floor({x=pos1.x, y=pos2.y, z=pos1.z}, pos2, data)
	make_wall(pos1, {x=pos2.x, y=pos2.y, z=pos1.z}, data)
	make_wall({x=pos1.x, y=pos1.y, z=pos2.z}, pos2, data)
	make_wall(pos1, {x=pos1.x, y=pos2.y, z=pos2.z}, data)
	make_wall({x=pos2.x, y=pos1.y, z=pos1.z}, pos2, data)

	-- Do recursive subdivision
	pos1 = vector.add(pos1, 1)
	pos2 = vector.add(pos2, -1)
	subdivide_room(pos1, pos2, data)

	-- Put the nodes
	for vi,nodename in pairs(data) do
		local pos = punhash(vi)
		if can_change(pos) then
			minetest.set_node(pos, {name=nodename})
		end
	end
end



-- Testing

minetest.override_item("default:wood", {
	after_place_node = function(pos)
		local pos2 = vector.add(pos, 50)
		create_rooms(pos, pos2)
	end
})
