local function spawnRashid()
	local rashidSpawns = {
		['Monday'] = Position(32349, 32231, 6),
		['Tuesday'] = Position(32306, 32835, 7),
		['Wednesday'] = Position(32579, 32754, 7),
		['Thursday'] = Position(33065, 32879, 6),
		['Friday'] = Position(33233, 32484, 7),
		['Saturday'] = Position(33168, 31810, 6),
		['Sunday'] = Position(32328, 31782, 6),
	}
	
	local position = rashidSpawns[os.date("%A")]
	local rashid = Game.createNpc("rashid", position)
	if rashid ~= nil then
		rashid:setMasterPos(position)
		position:sendMagicEffect(CONST_ME_MAGIC_RED)
	end
end

local function setBloomingGriffinclaw()
	local position = {x = 32024, y = 32830, z = 4}
    if Game.isItemThere(position,5687) then
		Game.removeItemOnMap(position, 5687)
		Game.createItem(5658, 1, position)
		Game.sendMagicEffect(position, 15)
	end
end

function onStartup()
	math.randomseed(os.mtime())
	
	db.query("TRUNCATE TABLE `players_online`")
	db.asyncQuery("DELETE FROM `guild_wars` WHERE `status` = 0")
	db.asyncQuery("DELETE FROM `players` WHERE `deletion` != 0 AND `deletion` < " .. os.time())
	db.asyncQuery("DELETE FROM `ip_bans` WHERE `expires_at` != 0 AND `expires_at` <= " .. os.time())

	-- Move expired bans to ban history
	local resultId = db.storeQuery("SELECT * FROM `account_bans` WHERE `expires_at` != 0 AND `expires_at` <= " .. os.time())
	if resultId ~= false then
		repeat
			local accountId = result.getDataInt(resultId, "account_id")
			db.asyncQuery("INSERT INTO `account_ban_history` (`account_id`, `reason`, `banned_at`, `expired_at`, `banned_by`) VALUES (" .. accountId .. ", " .. db.escapeString(result.getDataString(resultId, "reason")) .. ", " .. result.getDataLong(resultId, "banned_at") .. ", " .. result.getDataLong(resultId, "expires_at") .. ", " .. result.getDataInt(resultId, "banned_by") .. ")")
			db.asyncQuery("DELETE FROM `account_bans` WHERE `account_id` = " .. accountId)
		until not result.next(resultId)
		result.free(resultId)
	end

	-- Check house auctions
	local resultId = db.storeQuery("SELECT `id`, `highest_bidder`, `last_bid`, (SELECT `balance` FROM `players` WHERE `players`.`id` = `highest_bidder`) AS `balance` FROM `houses` WHERE `owner` = 0 AND `bid_end` != 0 AND `bid_end` < " .. os.time())
	if resultId ~= false then
		repeat
			local house = House(result.getDataInt(resultId, "id"))
			if house ~= nil then
				local highestBidder = result.getDataInt(resultId, "highest_bidder")
				local balance = result.getDataLong(resultId, "balance")
				local lastBid = result.getDataInt(resultId, "last_bid")
				if balance >= lastBid then
					db.query("UPDATE `players` SET `balance` = " .. (balance - lastBid) .. " WHERE `id` = " .. highestBidder)
					house:setOwnerGuid(highestBidder)
				end
				db.asyncQuery("UPDATE `houses` SET `last_bid` = 0, `bid_end` = 0, `highest_bidder` = 0, `bid` = 0 WHERE `id` = " .. house:getId())
			end
		until not result.next(resultId)
		result.free(resultId)
	end
	
	-- Remove murders that are more than 60 days old
	local resultId = db.storeQuery("SELECT * FROM `player_murders` WHERE `date` <= " .. os.time() - 60 * 24 * 60 * 60)
	if resultId ~= false then
		repeat
			local playerId = result.getDataInt(resultId, "player_id")
			local id = result.getDataLong(resultId, "id")
			
			db.asyncQuery("DELETE FROM `player_murders` WHERE `player_id` = " .. playerId .. " AND `id` = " .. id)
		until not result.next(resultId)
		result.free(resultId)
	end
	
	-- blooming griffinclaw
	local dayNow = tonumber(os.date("%d", os.time()))
	if (dayNow == 1) then
		setGlobalStorageValue(1, 0)
	end
	
	if getGlobalStorageValue(1) == 0 then
		local randomDay = math.random(dayNow, 28)
		if (randomDay == 28) then
			setGlobalStorageValue(1, 1)
			addEvent(setBloomingGriffinclaw, 10000)
		end
	end
	
	spawnRashid()
	setGlobalStorageValue(17657, 0) -- reset POI levers
end
