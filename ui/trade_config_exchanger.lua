local ffi = require("ffi")
---@cast ffi ffi

local C = ffi.C
---@cast C C

local menu = {
    name = "STCE_Menu",
    title = ReadText(1972092405, 1001)
}

local debug0 = true         -- to see the input and output of core functions of the menu
local debug1 = true         -- for init (lua loading time)
local debug2 = true         -- for detailed logging inside menu functions
local debugW = false         -- for debugging values we want to see during table rows and widget events
local debugWProps = false    -- to see x, y, width, and height properties of tables
local debugCheat = false     -- to add a cheat window

local debugSettings = false  -- for logging variables coming from md
local debugColorMod = false  -- for background coloring of frame tables in option mode

local debugGetData = false   -- for logging the status check of Player.entity.$md_RFM_DataChanged
local debugData = false      -- for logging variables like Player.entity.$RM_Fleets, $FleetRecords, $RebuildCues

-- init menu and register witdh Helper
local function Init()
    Menus = Menus or {}

    local founded = false
    for _, imenu in ipairs(Menus) do -- note that i is simply a placeholder for an ignored variable
        if imenu.name == menu.name then
            founded = true
            break
        end
    end
    if not founded then
        table.insert(Menus, menu)
        local xdebug = debug1 and DebugError("Inserted " .. menu.name .. " in Menus")
        if Helper then
            Helper.registerMenu(menu)
            local xdebug = debug1 and DebugError("Registered " .. menu.name .. " in Menus")
        end
    else
        local xdebug = debug1 and DebugError("" .. menu.name .. " founded in Menus, Passed Insert and Register Proccess")
    end
    DebugError (menu.name .. " .lua file Init OK...")
end

function menu.cleanup()
    local xdebug = debug0 and DebugError("cleanup")
	menu.currentStationObject = 0
end

function menu.onShowMenu()
    local xdebug = debug0 and DebugError("onShowMenu")
    menu.cleanup()
	if menu.param[3] then
        menu.currentStationObject = ConvertStringTo64Bit(tostring(menu.param[3]))
	end
	local xdebug = debug0 and DebugError("Current Station: " .. menu.currentStationObject)
	if menu.currentStationObject ~= 0 then
        local width = 800;
        local columnWidthCheckBox = 5
        local columnWidthWare = 30
        local columnWidthOneStation = 100
        local columnWidthBuyPrice= math.floor(width * 12 / 100)
        local columnWidthBuyAmount = math.floor(width * 12 / 100)
        local columnWidthBuyRule = math.floor(width * 12 / 100)
        local columnWidthSellPrice = math.floor(width * 12 / 100)
        local columnWidthSellAmount = math.floor(width * 12 / 100)
        local columnWidthSellRule = math.floor(width * 12 / 100)
		menu.currentStation = menu.getStationData(menu.currentStationObject)
        menu.stationsList = menu.getStationsTable()
	end

    Helper.closeInteractMenu()
end

local function tableCount(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

function menu.getStationsTable()
    local xdebug = debug2 and DebugError("getStationsTable")
	local numOwnedStations = C.GetNumAllFactionStations("player")
	local allOwnedStations = ffi.new("UniverseID[?]", numOwnedStations)
    local stationsResult = {}
	numOwnedStations = C.GetAllFactionStations(allOwnedStations, numOwnedStations, "player")
	for i = 0, numOwnedStations - 1 do
		local station = ConvertStringTo64Bit(tostring(allOwnedStations[i]))
		local stationName, manager, shiptrader = GetComponentData(station, "name", "tradenpc", "shiptrader")
        local stationIdCode = ffi.string(C.GetObjectIDCode(station))
		stationName = stationName .. " (" .. stationIdCode .. ")"
        local isWharf, isShipyard, isDefenceStation, isTradeStation = GetComponentData(station, "iswharf", "isshipyard", "isdefencestation", "istradestation")
        local xdebug = debug2 and DebugError(string.format("Processing station: Name: %s, isWharf: %s, isShipyard: %s, isDefenceStation: %s, isTradeStation: %s",
            stationName, tostring(isWharf), tostring(isShipyard), tostring(isDefenceStation), tostring(isTradeStation)))
		if manager and not shiptrader and not isShipyard and not isWharf then
            local products, tradeWares = GetComponentData(station, "products", "tradewares")
            local productsCount = tableCount(products)
            local tradeWaresCount = tableCount(tradeWares)
            local containersTypesCount = C.GetNumCargoTransportTypes(station, true)
            xdebug = debug2 and DebugError(string.format("Station: %s, Products Count: %s, tradeWares Count: %s, Container Types Count: %s", stationName, productsCount, tradeWaresCount, containersTypesCount))
            if productsCount == 0  and containersTypesCount > 0 then
                xdebug = debug2 and DebugError(string.format("Station: %s is Added", stationName))
                table.insert(stationsResult, { object = station, name = stationName, idCode = stationIdCode, tradeWares = tradeWares })
            end
		end
	end
    return stationsResult
end

function menu.getStationData(stationObject)
	local station = {}

	station.object = stationObject
	station.id = ffi.string(C.GetObjectIDCode(stationObject))
	station.name = ffi.string(C.GetComponentName(stationObject))
	station.class = ffi.string(C.GetComponentClass(stationObject))
	local xdebug = debug2 and DebugError(string.format("Station Id: %s, Name: %s, Class: %s", station.id, station.name, station.class))
    station.macro, station.faction, station.sectorId = GetComponentData(stationObject, "macro", "owner", "sectorid" )
    -- station.factionColor = GetFactionData(station.faction, "color")
    -- station.sectorOwner = GetComponentData(station.sectorId, "owner")
    -- station.sectorOwnerColor = GetFactionData(station.sectorOwner, "color")
    -- station.isplayerowned, station.icon, station.isEnemy, station.isHostile, station.uiRelation = GetComponentData(stationObject, "isplayerowned", "icon", "isenemy", "ishostile", "uirelation")
    station.isShipyard, station.isWharf = GetComponentData(station.object64, "isshipyard", "iswharf")
	xdebug = debug2 and DebugError(string.format("Station Macro: %s, isShipyard: %s, isWharf: %s", station.macro, station.isShipyard, station.isWharf))
    station.macroName = GetMacroData(station.macro, "name")
	local rawTradeWares = GetComponentData(stationObject, "tradewares")
    local tradeWares = {}
    local storageInfoAmounts  = C.IsInfoUnlockedForPlayer(stationObject, "storage_amounts")
	local storageInfoWareList = C.IsInfoUnlockedForPlayer(stationObject, "storage_warelist")
	local storageInfoCapacity = C.IsInfoUnlockedForPlayer(stationObject, "storage_capacity")
    for _, ware in ipairs(rawTradeWares) do
        local name, transportType = GetWareData(ware, "name", "transport")
        local cargo, isPlayerOwned = GetComponentData(stationObject, "cargo", "isplayerowned")
        local productionLimit = GetWareProductionLimit(stationObject, ware)
        local shownAmount = storageInfoAmounts and cargo[ware] or 0
        local shownMax = storageInfoCapacity and math.max(shownAmount, productionLimit) or shownAmount
        local buyLimit, sellLimit
        if isPlayerOwned then
            if C.HasContainerBuyLimitOverride(stationObject, ware) then
                buyLimit = math.max(0, math.min(shownMax, C.GetContainerBuyLimit(stationObject, ware)))
            end
            if C.HasContainerSellLimitOverride(stationObject, ware) then
                sellLimit = math.max(buyLimit or 0, math.min(shownMax, C.GetContainerSellLimit(stationObject, ware)))
            end
        end
        local item = {}
        item.ware = ware
        item.amount = shownAmount
        item.name = name
        item.transportType = transportType
        item.buyLimit = buyLimit
        item.sellLimit = sellLimit
		xdebug = debug2 and DebugError(string.format("Ware: %s, Amount: %s, Name: %s, TransportType: %s, BuyLimit: %s, SellLimit: %s", item.ware, item.amount, item.name, item.transportType, item.buyLimit, item.sellLimit))
        table.insert(tradeWares, item)
    end
    station.tradewares = tradeWares
	return station
end

-- function menu.createTradeContext(frame)
-- 	menu.skipTradeRowChange = true

-- 	local convertedTradeOfferContainer = ConvertStringTo64Bit(tostring(menu.contextMenuData.component))
-- 	local isplayertradeoffercontainer = GetComponentData(convertedTradeOfferContainer, "isplayerowned")

-- 	AddUITriggeredEvent(menu.name, "trade_context", ConvertStringToLuaID(convertedTradeOfferContainer))

-- 	menu.updateTradeCost()
-- 	local convertedCurrentShip = ConvertStringTo64Bit(tostring(menu.contextMenuData.currentShip))

-- 	-- menu setup
-- 	local width = menu.contextMenuData.width
-- 	local amountcolumnwidth = 100
-- 	local pricecolumnwidth = 100

-- 	local columnwidth_ware   -- calculated below
-- 	local columnwidth_price			= =
-- 	local columnwidth_shipstorage	= math.floor(width * 12 / 100)
-- 	local columnwidth_sliderleft	= math.floor(width * 15 / 100)
-- 	local columnwidth_sliderright	= math.floor(width * 15 / 100)
-- 	local columnwidth_selloffer		= math.floor(width * 12 / 100)
-- 	local columnwidth_buyoffer		= math.floor(width * 12 / 100)
-- 	local columnwidth_reservation	= Helper.scaleY(config.mapRowHeight)
-- 	if menu.contextMenuData.wareexchange then
-- 		-- nearly symmetrical menu layout in ware exchange case:
-- 		--   price column = only a dummy in this case, always included in colspan.
-- 		--   selloffer column = other ship storage
-- 		--   buyoffer column = unused (almost same width as ware column)
-- 		columnwidth_price = 1
-- 		local remainingwidth = width - 6 * Helper.borderSize
-- 			- columnwidth_price
-- 			- columnwidth_shipstorage
-- 			- columnwidth_sliderleft
-- 			- columnwidth_sliderright
-- 			- columnwidth_selloffer
-- 		-- nearly symmetrical menu layout:
-- 		columnwidth_ware = math.ceil(remainingwidth / 2)
-- 		columnwidth_buyoffer = remainingwidth - columnwidth_ware
-- 	else
-- 		-- regular trade case
-- 		columnwidth_ware = width - 6 * Helper.borderSize
-- 			- columnwidth_price
-- 			- columnwidth_shipstorage
-- 			- columnwidth_sliderleft
-- 			- columnwidth_sliderright
-- 			- columnwidth_selloffer
-- 			- columnwidth_buyoffer
-- 	end

-- 	-- ship
-- 	local shiptable = frame:addTable(9, { tabOrder = 2, maxVisibleHeight = menu.tradeContext.shipheight, x = Helper.borderSize, y = Helper.borderSize, width = menu.contextMenuData.width, reserveScrollBar = false })
-- 	shiptable:setColWidth(1, columnwidth_ware, false)
-- 	shiptable:setColWidth(2, columnwidth_price, false)
-- 	shiptable:setColWidth(3, columnwidth_shipstorage, false)
-- 	shiptable:setColWidth(4, columnwidth_sliderleft, false)
-- 	shiptable:setColWidth(5, columnwidth_sliderright, false)
-- 	shiptable:setColWidth(6, columnwidth_reservation, false)
-- 	shiptable:setColWidth(7, columnwidth_selloffer - columnwidth_reservation - Helper.borderSize, false)
-- 	shiptable:setColWidth(8, columnwidth_reservation, false)
-- 	shiptable:setColWidth(9, columnwidth_buyoffer - columnwidth_reservation - Helper.borderSize, false)
-- 	shiptable:setDefaultBackgroundColSpan(1, 9)

-- 	local shipOptions = {}
-- 	local curShipOption = tostring(convertedCurrentShip)

-- 	local sortedShips = {}
-- 	local found = false
-- 	for _, ship in ipairs(menu.contextMenuData.ships) do
-- 		local shipid = ConvertIDTo64Bit(ship.shipid)
-- 		if shipid == convertedCurrentShip then
-- 			found = true
-- 		end

-- 		local class = ffi.string(C.GetComponentClass(ConvertStringTo64Bit(tostring(ship.shipid))))
-- 		local icon, primarypurpose = GetComponentData(ship.shipid, "icon", "primarypurpose")
-- 		local i = menu.findEntryByShipIcon(sortedShips, icon)
-- 		if i then
-- 			table.insert(sortedShips[i].ships, { shipid = shipid, name = ship.name })
-- 		else
-- 			table.insert(sortedShips, { icon = icon, class = class, purpose = primarypurpose, ships = { { shipid = shipid, name = ship.name } } })
-- 		end
-- 	end
-- 	if (not found) and (menu.contextMenuData.currentShip ~= 0) then
-- 		local ship = { shipid = convertedCurrentShip, name = ffi.string(C.GetComponentName(menu.contextMenuData.currentShip)) }

-- 		local class = ffi.string(C.GetComponentClass(menu.contextMenuData.currentShip))
-- 		local icon, primarypurpose = GetComponentData(ship.shipid, "icon", "primarypurpose")
-- 		local i = menu.findEntryByShipIcon(sortedShips, icon)
-- 		if i then
-- 			table.insert(sortedShips[i].ships, ship)
-- 		else
-- 			table.insert(sortedShips, { icon = icon, class = class, purpose = primarypurpose, ships = { ship } })
-- 		end
-- 	end
-- 	table.sort(sortedShips, menu.sortShipsByClassAndPurposeReverse)

-- 	local dropdownwidth = columnwidth_ware + columnwidth_price + columnwidth_shipstorage + columnwidth_sliderleft + 3 * Helper.borderSize - Helper.scaleY(Helper.headerRow1Height) - 4 * 2 - Helper.standardTextOffsetx
-- 	for _, data in ipairs(sortedShips) do
-- 		table.sort(data.ships, Helper.sortName)
-- 		for _, ship in ipairs(data.ships) do
-- 			local name = "\27[" .. data.icon .. "] " .. ship.name
-- 			local idcode = " (" .. ffi.string(C.GetObjectIDCode(ship.shipid)) .. ")"
-- 			local sectorname = GetComponentData(ship.shipid, "sector")

-- 			local fontsize = Helper.scaleFont(Helper.headerRow1Font, Helper.headerRow1FontSize)
-- 			local namewidth = math.ceil(C.GetTextWidth(name, Helper.headerRow1Font, fontsize))
-- 			local idcodewidth = math.ceil(C.GetTextWidth(idcode, Helper.headerRow1Font, fontsize))
-- 			local sectornamewidth = math.ceil(C.GetTextWidth("  " .. sectorname, Helper.standardFont, Helper.scaleFont(Helper.standardFont, Helper.headerRow1FontSize)))
-- 			if namewidth + idcodewidth + sectornamewidth > dropdownwidth then
-- 				name = TruncateText(name, Helper.headerRow1Font, fontsize, dropdownwidth - sectornamewidth - idcodewidth)
-- 			end

-- 			table.insert(shipOptions, { id = tostring(ship.shipid), text = name .. idcode, text2 = sectorname, icon = "", displayremoveoption = false })
-- 		end
-- 	end

-- 	local iscapship = IsComponentClass(convertedCurrentShip, "ship_l") or IsComponentClass(convertedCurrentShip, "ship_xl")
-- 	local ispartnersmallship = IsComponentClass(convertedTradeOfferContainer, "ship_m") or IsComponentClass(convertedTradeOfferContainer, "ship_s")
-- 	local missingdrones = true
-- 	if iscapship and (not ispartnersmallship) then
-- 		local shipunits = GetUnitStorageData(convertedCurrentShip, "transport")
-- 		local stationunits = GetUnitStorageData(convertedTradeOfferContainer, "transport")
-- 		for _, unit in ipairs(shipunits) do
-- 			if unit.amount > 0 then
-- 				missingdrones = false
-- 				break
-- 			end
-- 		end
-- 		if missingdrones then
-- 			for _, unit in ipairs(stationunits) do
-- 				if unit.amount > 0 then
-- 					missingdrones = false
-- 					break
-- 				end
-- 			end
-- 		end
-- 	else
-- 		missingdrones = false
-- 	end
-- 	local candock = true
-- 	if convertedCurrentShip and (convertedCurrentShip ~= 0) then
-- 		if (not menu.contextMenuData.wareexchange) or IsComponentClass(convertedTradeOfferContainer, "station") then
-- 			candock = IsDockingPossible(convertedCurrentShip, convertedTradeOfferContainer, nil, true)
-- 		end
-- 	end
-- 	local isplayertraderestricted = isplayertradeoffercontainer and C.IsContainerTradingWithFactionRescricted(menu.contextMenuData.component, "player")

-- 	local shipsectorname, blacklistgroup, name = "", "civilian", ""
-- 	if convertedCurrentShip and (convertedCurrentShip ~= 0) then
-- 		local loc_shipsectorname, loc_blacklistgroup, loc_name, loc_icon = GetComponentData(convertedCurrentShip, "sector", "blacklistgroup", "name", "icon")
-- 		shipsectorname = loc_shipsectorname
-- 		blacklistgroup = loc_blacklistgroup
-- 		name = "\27[" .. loc_icon .. "] " .. loc_name .. " (" .. ffi.string(C.GetObjectIDCode(convertedCurrentShip)) .. ")"
-- 	end
-- 	local stationsector = ConvertIDTo64Bit(GetComponentData(convertedTradeOfferContainer, "sectorid"))

-- 	-- title
-- 	local row = shiptable:addRow(true, { fixed = true, bgColor = Color["row_title_background"] })
-- 	row[1]:setBackgroundColSpan(4):setColSpan(4):createDropDown(shipOptions, { startOption = curShipOption, height = Helper.headerRow1Height, textOverride = name, text2Override = " ", helpOverlayID = "trade_context_shipOptions", helpOverlayText = " ", helpOverlayHighlightOnly = true })
-- 	row[1]:setTextProperties({ halign = "left", font = Helper.headerRow1Font, fontsize = Helper.headerRow1FontSize, color = Color["text_player"] })
-- 	row[1]:setText2Properties({ halign = "right", fontsize = Helper.headerRow1FontSize, x = Helper.standardTextOffsetx })
-- 	row[1].handlers.onDropDownConfirmed = menu.dropdownShip

-- 	local othername = Helper.unlockInfo(IsInfoUnlockedForPlayer(convertedTradeOfferContainer, "name"), ffi.string(C.GetComponentName(menu.contextMenuData.component)) .. " (" .. ffi.string(C.GetObjectIDCode(menu.contextMenuData.component)) .. ")")
-- 	local color = Color["text_normal"]
-- 	if isplayertradeoffercontainer then
-- 		color = Color["text_player"]
-- 	end
-- 	local mouseovertext
-- 	if C.IsComponentBlacklisted(convertedTradeOfferContainer, "objectactivity", blacklistgroup, convertedCurrentShip) then
-- 		color = Color["text_warning"]
-- 		if convertedCurrentShip and (convertedCurrentShip ~= 0) then
-- 			mouseovertext = ColorText["text_warning"] .. ReadText(1026, 3257)
-- 		else
-- 			mouseovertext = ColorText["text_warning"] .. ReadText(1026, 3256)
-- 		end
-- 	end
-- 	if mouseovertext then
-- 		if convertedCurrentShip and (convertedCurrentShip ~= 0) then
-- 			mouseovertext = mouseovertext .. "\27X\n" .. ReadText(1026, 3258)
-- 		end
-- 	end
-- 	row[5]:setColSpan(5)
-- 	othername = TruncateText(othername, Helper.headerRow1Font, Helper.scaleFont(Helper.headerRow1Font, Helper.headerRow1FontSize), row[5]:getWidth() - 2 * Helper.scaleX(Helper.standardButtonWidth))
-- 	row[5]:createText(othername, { halign = "center", color = color, font = Helper.headerRow1Font, fontsize = Helper.headerRow1FontSize, x = 0, y = Helper.headerRow1Offsety, cellBGColor = Color["row_background"], titleColor = Color["row_title"], mouseOverText = mouseovertext })

-- 	-- locations
-- 	local row = shiptable:addRow(true, { fixed = true })
-- 	row[1]:setBackgroundColSpan(4):setColSpan(4):createText(ReadText(1001, 11039) .. ReadText(1001, 120) .. " " .. shipsectorname, { color = Color["text_inactive"] })

-- 	local color = Color["text_inactive"]
-- 	local mouseovertext
-- 	if C.IsComponentBlacklisted(stationsector, "sectortravel", blacklistgroup, convertedCurrentShip) then
-- 		color = Color["text_warning"]
-- 		if convertedCurrentShip and (convertedCurrentShip ~= 0) then
-- 			mouseovertext = ColorText["text_warning"] .. ReadText(1026, 3253)
-- 		else
-- 			mouseovertext = ColorText["text_warning"] .. ReadText(1026, 3252)
-- 		end
-- 	end
-- 	if C.IsComponentBlacklisted(stationsector, "sectoractivity", blacklistgroup, convertedCurrentShip) then
-- 		color = Color["text_warning"]
-- 		if mouseovertext then
-- 			mouseovertext = mouseovertext .. "\n"
-- 		else
-- 			mouseovertext = ""
-- 		end
-- 		if convertedCurrentShip and (convertedCurrentShip ~= 0) then
-- 			mouseovertext = mouseovertext .. ColorText["text_warning"] .. ReadText(1026, 3255)
-- 		else
-- 			mouseovertext = mouseovertext .. ColorText["text_warning"] .. ReadText(1026, 3254)
-- 		end
-- 	end
-- 	if mouseovertext then
-- 		if convertedCurrentShip and (convertedCurrentShip ~= 0) then
-- 			mouseovertext = mouseovertext .. "\27X\n" .. ReadText(1026, 3258)
-- 		end
-- 	end
-- 	row[5]:setColSpan(5):createText(ffi.string(C.GetComponentName(stationsector)), { halign = "center", color = color, mouseOverText = mouseovertext })

-- 	-- table header
-- 	local hasshiptargetamounts = false
-- 	local hasothershipttargetamounts = false
-- 	for i, waredata in ipairs(menu.contextMenuData.waredatalist) do
-- 		local shiptargetamount = 0
-- 		if menu.contextMenuData.currentShip ~= 0 then
-- 			shiptargetamount = GetWareProductionLimit(menu.contextMenuData.currentShip, waredata.ware)
-- 		end
-- 		if shiptargetamount > 0 then
-- 			hasshiptargetamounts = true
-- 			if hasothershipttargetamounts then
-- 				break
-- 			end
-- 		end
-- 		local othershiptargetamount = GetWareProductionLimit(ConvertStringTo64Bit(tostring(menu.contextMenuData.component)), waredata.ware)
-- 		if othershiptargetamount > 0 then
-- 			hasothershipttargetamounts = true
-- 			if hasshiptargetamounts then
-- 				break
-- 			end
-- 		end
-- 	end

-- 	local headerproperties = { font = Helper.standardFontBold, cellBGColor = Color["row_background"], titleColor = Color["row_title"] }
-- 	local row = shiptable:addRow(nil, { fixed = true })
-- 	if menu.contextMenuData.wareexchange then
-- 		row[1]:setColSpan(2):setBackgroundColSpan(1):createText(ReadText(1001, 45), headerproperties)
-- 		row[3]:createText(ReadText(1001, 5) .. (hasshiptargetamounts and (" (" .. ReadText(1001, 2903) .. ")") or ""), headerproperties)
-- 		row[4]:setColSpan(2):createText(" ", headerproperties)
-- 		row[6]:setColSpan(2):createText(((C.IsComponentClass(menu.contextMenuData.component, "ship") and ReadText(1001, 5)) or (C.IsComponentClass(menu.contextMenuData.component, "station") and ReadText(1001, 3)) or ReadText(1001, 9426)) .. (hasothershipttargetamounts and (" (" .. ReadText(1001, 2903) .. ")") or ""), headerproperties)
-- 		row[8]:setColSpan(2):createText(" ", headerproperties)
-- 	else
-- 		row[1]:setBackgroundColSpan(1):createText(ReadText(1001, 45), headerproperties)
-- 		row[2]:createText(ReadText(1001, 2808), headerproperties)
-- 		row[3]:createText(ReadText(1001, 5) .. (hasshiptargetamounts and (" (" .. ReadText(1001, 2903) .. ")") or ""), headerproperties)
-- 		row[4]:setColSpan(2):createText(" ", headerproperties)
-- 		row[6]:setColSpan(2):createText(ReadText(1001, 8308), headerproperties)
-- 		row[8]:setColSpan(2):createText(ReadText(1001, 8309), headerproperties)
-- 	end

-- 	-- line
-- 	local row = shiptable:addRow(nil, { fixed = true, bgColor = Color["row_separator"] })
-- 	row[1]:setColSpan(9):createText("", { fontsize = 1, height = 1 })

-- 	-- ware list
-- 	local warningcontent = {}
-- 	local pricemodifiers = {}
-- 	local warningcolor = Color["text_error"]

-- 	local maxVisibleHeight

-- 	if #menu.contextMenuData.waredatalist == 0 then
-- 		menu.selectedTradeWare = nil
-- 		local row = shiptable:addRow(nil, {  })
-- 		row[1]:setColSpan(9):createText(menu.contextMenuData.wareexchange and ReadText(1001, 8310) or ReadText(1001, 8311))
-- 	else
-- 		-- check selectedTradeWare
-- 		local tradewarefound = false
-- 		if menu.selectedTradeWare then
-- 			for i, waredata in ipairs(menu.contextMenuData.waredatalist) do
-- 				if (waredata.ware == menu.selectedTradeWare.ware) and (waredata.mission == menu.selectedTradeWare.mission) then
-- 					tradewarefound = true
-- 					break
-- 				end
-- 			end
-- 			if not tradewarefound then
-- 				menu.selectedTradeWare = nil
-- 			end
-- 		end

-- 		local reservations, missionreservations = {}, {}
-- 		local n = C.GetNumContainerWareReservations2(menu.contextMenuData.component, true, true, true)
-- 		local buf = ffi.new("WareReservationInfo2[?]", n)
-- 		n = C.GetContainerWareReservations2(buf, n, menu.contextMenuData.component, true, true, true)
-- 		for i = 0, n - 1 do
-- 			if (buf[i].missionid ~= 0) or (not buf[i].isvirtual) then
-- 				local ware = ffi.string(buf[i].ware)
-- 				local buyflag = buf[i].isbuyreservation and "selloffer" or "buyoffer" -- sic! Reservation to buy -> container is selling
-- 				local invbuyflag = buf[i].isbuyreservation and "buyoffer" or "selloffer"
-- 				local reservationref = (buf[i].missionid ~= 0) and missionreservations or reservations
-- 				if reservationref[ware] then
-- 					table.insert(reservationref[ware][buyflag], { reserver = buf[i].reserverid, amount = buf[i].amount, eta = buf[i].eta, mission = buf[i].missionid })
-- 				else
-- 					reservationref[ware] = { [buyflag] = { { reserver = buf[i].reserverid, amount = buf[i].amount, eta = buf[i].eta, mission = buf[i].missionid } }, [invbuyflag] = {} }
-- 				end
-- 			end
-- 		end
-- 		for _, data in pairs(reservations) do
-- 			table.sort(data.buyoffer, menu.etaSorter)
-- 			table.sort(data.selloffer, menu.etaSorter)
-- 		end
-- 		for _, data in pairs(missionreservations) do
-- 			table.sort(data.buyoffer, menu.etaSorter)
-- 			table.sort(data.selloffer, menu.etaSorter)
-- 		end

-- 		for i, waredata in ipairs(menu.contextMenuData.waredatalist) do
-- 			local content = menu.getTradeContextRowContent(waredata)

-- 			local row = shiptable:addRow({ ware = waredata.ware, mission = waredata.mission, issupply = waredata.issupply }, {  })
-- 			local callback = menu.getAmmoTypeNameByWare(waredata.ware) and menu.slidercellShipAmmo or menu.slidercellShipCargo
-- 			if menu.contextMenuData.wareexchange then
-- 				row[1]:setColSpan(2):createText(content[1].text, { color = content[1].color })
-- 				row[3]:createText(content[3].text, { color = content[3].color, halign = "right" })
-- 				row[4]:setColSpan(2):createSliderCell({ start = content[4].scale.start, min = content[4].scale.min, minSelect = content[4].scale.minselect, max = content[4].scale.max, maxSelect = content[4].scale.maxselect, step = content[4].scale.step, suffix = content[4].scale.suffix, fromCenter = content[4].scale.fromcenter, rightToLeft = content[4].scale.righttoleft, height = Helper.standardTextHeight })
-- 				row[4].handlers.onSliderCellChanged = function (_, value) return callback(waredata.sell and waredata.sell.id, waredata.buy and waredata.buy.id, waredata.ware, 0, value) end
-- 				row[4].handlers.onSliderCellConfirm = function () return menu.slidercellTradeConfirmed(waredata.ware) end
-- 				waredata.sellcol = 6
-- 				row[6]:setColSpan(2):createText(content[6].text, { color = content[6].color, halign = "right", mouseOverText = content[6].mouseover })
-- 			else
-- 				row[1]:createText(content[1].text, { color = content[1].color, mouseOverText = content[1].mouseover })
-- 				row[2]:createText(content[2].text, { color = content[2].color, halign = "right", mouseOverText = content[2].mouseover })
-- 				row[3]:createText(content[3].text, { color = content[3].color, halign = "right" })
-- 				row[4]:setColSpan(2):createSliderCell({ start = content[4].scale.start, min = content[4].scale.min, minSelect = content[4].scale.minselect, max = content[4].scale.max, maxSelect = content[4].scale.maxselect, step = content[4].scale.step, suffix = content[4].scale.suffix, fromCenter = content[4].scale.fromcenter, rightToLeft = content[4].scale.righttoleft, height = Helper.standardTextHeight })
-- 				row[4].handlers.onSliderCellChanged = function (_, value) return callback(waredata.sell and waredata.sell.id, waredata.buy and waredata.buy.id, waredata.ware, 0, value) end
-- 				row[4].handlers.onSliderCellConfirm = function () return menu.slidercellTradeConfirmed(waredata.ware) end

-- 				local reservationref = waredata.mission and missionreservations or reservations
-- 				local colspan = 2
-- 				if reservationref[waredata.ware] and (#reservationref[waredata.ware].selloffer > 0) then
-- 					local mouseovertext = ""
-- 					for i, reservation in ipairs(reservationref[waredata.ware].selloffer) do
-- 						if (not waredata.mission) or (waredata.mission == reservation.mission) then
-- 							local isplayerowned = GetComponentData(ConvertStringTo64Bit(tostring(reservation.reserver)), "isplayerowned")
-- 							if isplayerowned or isplayertradeoffercontainer then
-- 								if mouseovertext ~= "" then
-- 									mouseovertext = mouseovertext .. "\n"
-- 								end
-- 								local name = (isplayerowned and ColorText["text_player"] or "") .. ffi.string(C.GetComponentName(reservation.reserver)) .. " (" .. ffi.string(C.GetObjectIDCode(reservation.reserver)) .. ")\27X"
-- 								mouseovertext = mouseovertext .. name .. " - " .. (waredata.mission and ColorText["text_mission"] or "") .. ReadText(1001, 1202) .. ReadText(1001, 120) .. " " .. ConvertIntegerString(reservation.amount, true, 0, true) .. "\27X"
-- 							end
-- 						end
-- 					end
-- 					if mouseovertext ~= "" then
-- 						colspan = 1
-- 						mouseovertext = ReadText(1001, 7946) .. ReadText(1001, 120) .. "\n" .. mouseovertext
-- 						row[6]:createIcon("menu_hourglass", { color = waredata.mission and Color["text_mission"] or nil, height = config.mapRowHeight, mouseOverText = mouseovertext })
-- 					end
-- 				end
-- 				waredata.sellcol = 8 - colspan
-- 				row[8 - colspan]:setColSpan(colspan):createText(content[6].text, { color = content[6].color, halign = "right", mouseOverText = content[6].mouseover })
-- 				colspan = 2
-- 				if reservationref[waredata.ware] and (#reservationref[waredata.ware].buyoffer > 0) then
-- 					local mouseovertext = ""
-- 					for i, reservation in ipairs(reservationref[waredata.ware].buyoffer) do
-- 						if (not waredata.mission) or (waredata.mission == reservation.mission) then
-- 							local isplayerowned = GetComponentData(ConvertStringTo64Bit(tostring(reservation.reserver)), "isplayerowned")
-- 							if isplayerowned or isplayertradeoffercontainer then
-- 								if mouseovertext ~= "" then
-- 									mouseovertext = mouseovertext .. "\n"
-- 								end
-- 								local name = (isplayerowned and ColorText["text_player"] or "") .. ffi.string(C.GetComponentName(reservation.reserver)) .. " (" .. ffi.string(C.GetObjectIDCode(reservation.reserver)) .. ")\27X"
-- 								mouseovertext = mouseovertext .. name .. " - " .. (waredata.mission and ColorText["text_mission"] or "") .. ReadText(1001, 1202) .. ReadText(1001, 120) .. " " .. ConvertIntegerString(reservation.amount, true, 0, true) .. "\27X"
-- 							end
-- 						end
-- 					end
-- 					if mouseovertext ~= "" then
-- 						colspan = 1
-- 						mouseovertext = ReadText(1001, 7946) .. ReadText(1001, 120) .. "\n" .. mouseovertext
-- 						row[8]:createIcon("menu_hourglass", { color = waredata.mission and Color["text_mission"] or nil, height = config.mapRowHeight, mouseOverText = mouseovertext })
-- 					end
-- 				end
-- 				waredata.buycol = 10 - colspan
-- 				row[10 - colspan]:setColSpan(colspan):createText(content[7].text, { color = content[7].color, halign = "right" })
-- 			end

-- 			if not menu.selectedRows.contextshiptable then
-- 				if (waredata.sell and IsSameTrade(waredata.sell.id, menu.contextMenuData.tradeid)) or (waredata.buy and IsSameTrade(waredata.buy.id, menu.contextMenuData.tradeid)) then
-- 					menu.selectedTradeWare = { ware = waredata.ware, mission = waredata.mission, issupply = waredata.issupply }
-- 					menu.topRows.contextshiptable = math.min(4 + i, 4 + #menu.contextMenuData.waredatalist - (menu.tradeContext.warescrollwindowsize - 1))
-- 					shiptable:setSelectedRow(row.index)
-- 				end
-- 			end
-- 			if not menu.selectedTradeWare then
-- 				menu.selectedTradeWare = { ware = waredata.ware, mission = waredata.mission, issupply = waredata.issupply }
-- 			end
-- 			if (waredata.ware == menu.selectedTradeWare.ware) and (waredata.mission == menu.selectedTradeWare.mission) and (waredata.issupply == menu.selectedTradeWare.issupply) then
-- 				warningcontent = content[8]
-- 				if waredata.ware == menu.showOptionalWarningWare then
-- 					if (content[4].scale.start ~= 0) and (content[4].scale.start == content[4].scale.maxselect) then
-- 						warningcontent = content[9]
-- 						warningcolor = Color["text_warning"]
-- 					elseif (content[4].scale.start ~= 0) and (content[4].scale.start == content[4].scale.minselect) then
-- 						warningcontent = content[10]
-- 						warningcolor = Color["text_warning"]
-- 					else
-- 						menu.showOptionalWarningWare = nil
-- 					end
-- 				end

-- 				pricemodifiers = content[11]
-- 			end

-- 			if i == menu.tradeContext.warescrollwindowsize then
-- 				maxVisibleHeight = shiptable:getFullHeight()
-- 			end
-- 		end
-- 	end

-- 	shiptable.properties.maxVisibleHeight = maxVisibleHeight or shiptable:getFullHeight()

-- 	shiptable:setTopRow(menu.topRows.contextshiptable)
-- 	if menu.selectedRows.contextshiptable then
-- 		shiptable:setSelectedRow(menu.selectedRows.contextshiptable)
-- 	end
-- 	menu.topRows.contextshiptable = nil
-- 	menu.selectedRows.contextshiptable = nil

-- 	-- info and buttons
-- 	-- the button table is split into left and right side below the "zero" position of the sliders
-- 	local columnwidth_bottomleft		= columnwidth_ware + columnwidth_price + columnwidth_shipstorage + columnwidth_sliderleft + 3 * Helper.borderSize
-- 	local columnwidth_bottomright		= columnwidth_sliderright + columnwidth_selloffer + columnwidth_buyoffer + 2 * Helper.borderSize
-- 	-- trade menu case:
-- 	-- split bottom right twice: Once into 2/3 + 1/3 for money output, and 1/2 + 1/2 for the buttons
-- 	-- A-----------------------------------------B------------C----D--------E
-- 	-- | Ship storage details  (bottomleft)      | Profits:        | 100 Cr |
-- 	-- +-----------------------------------------+------------+----+--------+
-- 	-- |                                         | LeftButton | RightButton |
-- 	-- +-----------------------------------------+------------+----+--------+
-- 	local columnwidth_br_leftoutput		= math.floor((columnwidth_bottomright - Helper.borderSize) * 2 / 3)			-- BD
-- 	local columnwidth_br_rightoutput	= columnwidth_bottomright - columnwidth_br_leftoutput - Helper.borderSize	-- DE
-- 	local columnwidth_br_leftbutton		= math.floor((columnwidth_bottomright - Helper.borderSize) / 2)				-- BC
-- 	local columnwidth_br_rightbutton	= columnwidth_bottomright - columnwidth_br_leftbutton - Helper.borderSize	-- CE
-- 	local columnwidth_br_bottomoverlap	= columnwidth_bottomright - columnwidth_br_leftbutton - columnwidth_br_rightoutput - 2 * Helper.borderSize			-- CD
-- 	-- ware exchange menu case:
-- 	-- "zero" position is in the center. Split bottom right twice, so that each button occupies ca. 20% of the width (40% together)
-- 	-- A-----------------------------------B-----C------------D-------------E
-- 	-- | Ship storage details (bottomleft) | Other ship storage details     |
-- 	-- +-----------------------------------+-----+------------+-------------+
-- 	-- |                                         | LeftButton | RightButton |
-- 	-- +-----------------------------------+-----+------------+-------------+
-- 	local columnwidth_wx_br_leftbutton	= math.floor((columnwidth_bottomright - 2 * Helper.borderSize) * 2 / 5)		-- CD
-- 	local columnwidth_wx_br_rightbutton	= columnwidth_wx_br_leftbutton												-- DE
-- 	local columnwidth_wx_br_leftspacing	= columnwidth_bottomright - columnwidth_wx_br_leftbutton - columnwidth_wx_br_rightbutton - 2 * Helper.borderSize	-- BC

-- 	local showdiscountinfo = (not menu.contextMenuData.wareexchange) and (not isplayertradeoffercontainer)
-- 	local numcols = showdiscountinfo and 6 or 4
-- 	local coloffset = showdiscountinfo and 2 or 0
-- 	menu.tradeContext.coloffset = coloffset
-- 	local buttontable = frame:addTable(numcols, { tabOrder = 3, x = Helper.borderSize, y = shiptable.properties.y + shiptable:getVisibleHeight() + Helper.borderSize, width = menu.contextMenuData.width, reserveScrollBar = false })
-- 	if showdiscountinfo then
-- 		buttontable:setColWidth(1, 2 * math.floor(columnwidth_bottomleft / 3), false)
-- 		buttontable:setColWidth(2, math.floor(0.6 * columnwidth_bottomleft / 3) - 2 * Helper.borderSize, false)
-- 		buttontable:setColWidth(3, math.floor(0.4 * columnwidth_bottomleft / 3), false)
-- 		buttontable:setColWidth(4, columnwidth_br_leftbutton,     false)
-- 		buttontable:setColWidth(5, columnwidth_br_bottomoverlap,  false)
-- 		buttontable:setColWidth(6, columnwidth_br_rightoutput,    false)
-- 		buttontable:setDefaultBackgroundColSpan(2, 2)
-- 		buttontable:setDefaultBackgroundColSpan(4, 3)
-- 	elseif menu.contextMenuData.wareexchange then
-- 		buttontable:setColWidth(1, columnwidth_bottomleft, false)
-- 		buttontable:setColWidth(2, columnwidth_wx_br_leftspacing, false)
-- 		buttontable:setColWidth(3, columnwidth_wx_br_leftbutton,  false)
-- 		buttontable:setColWidth(4, columnwidth_wx_br_rightbutton, false)
-- 		buttontable:setDefaultBackgroundColSpan(2, 3)
-- 	else
-- 		buttontable:setColWidth(1, columnwidth_bottomleft, false)
-- 		buttontable:setColWidth(2, columnwidth_br_leftbutton,     false)
-- 		buttontable:setColWidth(3, columnwidth_br_bottomoverlap,  false)
-- 		buttontable:setColWidth(4, columnwidth_br_rightoutput,    false)
-- 		buttontable:setDefaultBackgroundColSpan(2, 3)
-- 	end

-- 	-- line
-- 	local row = buttontable:addRow(nil, { fixed = true, bgColor = Color["row_separator"] })
-- 	row[1]:setColSpan(numcols):createText("", { fontsize = 1, height = 1 })

-- 	-- rows
-- 	local headerrow = buttontable:addRow(nil, { fixed = true, bgColor = Color["row_background_unselectable"] })
-- 	local inforows = {}
-- 	local warningrows = {}
-- 	for i = 1, menu.tradeContext.numinforows do
-- 		inforows[i] = buttontable:addRow(nil, { fixed = true })
-- 	end
-- 	local headerrow2 = buttontable:addRow(nil, { fixed = true })
-- 	for i = 1, menu.tradeContext.numwarningrows do
-- 		warningrows[i] = buttontable:addRow(i == menu.tradeContext.numwarningrows, { fixed = true })
-- 	end

-- 	-- storage details
-- 	local storagecontent = menu.getTradeContextShipStorageContent()
-- 	local storageheader = #storagecontent > 0 and ReadText(1001, 11654) or ReadText(1001, 11655)
-- 	for i, content in ipairs(storagecontent) do
-- 		if i <= menu.tradeContext.numinforows then
-- 			inforows[i][1]:createSliderCell({ min = content.scale.min, max = content.scale.max, start = content.scale.start, step = content.scale.step, suffix = content.scale.suffix, readOnly = content.scale.readonly, height = Helper.standardTextHeight }):setText(content.name, { color = content.color })
-- 		end
-- 	end

-- 	-- warnings
-- 	local i = 0
-- 	if not candock then
-- 		i = i + 1
-- 		if i <= menu.tradeContext.numwarningrows then
-- 			warningrows[i][1]:createText(ReadText(1001, 6211), { color = Color["text_error"] })
-- 		end
-- 	end
-- 	if missingdrones then
-- 		i = i + 1
-- 		if i <= menu.tradeContext.numwarningrows then
-- 			warningrows[i][1]:createText(ReadText(1001, 2978), { color = Color["text_error"] })
-- 		end
-- 	end

-- 	for _, content in pairs(warningcontent) do
-- 		i = i + 1
-- 		if i <= menu.tradeContext.numwarningrows then
-- 			warningrows[i][1]:createText(content, { color = warningcolor, wordwrap = true })
-- 		end
-- 	end

-- 	if isplayertraderestricted then
-- 		i = i + 1
-- 		if i <= menu.tradeContext.numwarningrows then
-- 			warningrows[i][1]:createText(ReadText(1001, 6212), { color = Color["text_warning"] })
-- 		end
-- 	end

-- 	local confirmbuttonactive = false
-- 	if candock and (not missingdrones) then
-- 		for _, amount in pairs(menu.contextMenuData.orders) do
-- 			if amount ~= 0 then
-- 				confirmbuttonactive = true
-- 				break
-- 			end
-- 		end
-- 	end

-- 	local header2properties = { halign = "center", font = Helper.standardFontBold, cellBGColor = Color["row_background"], titleColor = Color["row_title"] }
-- 	if menu.contextMenuData.wareexchange then
-- 		local otherstoragecontent = menu.getTradeContextShipStorageContent(true)
-- 		local otherstorageheader = #otherstoragecontent > 0 and
-- 			(
-- 				(C.IsComponentClass(menu.contextMenuData.component, "ship") and ReadText(1001, 11654))
-- 				or (C.IsComponentClass(menu.contextMenuData.component, "station") and ReadText(1001, 11656))
-- 				or ReadText(1001, 11658)
-- 			)
-- 			or (
-- 				(C.IsComponentClass(menu.contextMenuData.component, "ship") and ReadText(1001, 11655))
-- 				or (C.IsComponentClass(menu.contextMenuData.component, "station") and ReadText(1001, 11657))
-- 				or ReadText(1001, 11659)
-- 			)

-- 		-- header
-- 		headerrow[1]:createText(storageheader, header2properties)
-- 		headerrow[2]:setColSpan(3):createText(otherstorageheader, header2properties)

-- 		-- other ship info
-- 		for i = 1, menu.tradeContext.numinforows do
-- 			local content = otherstoragecontent[i]
-- 			if content then
-- 				inforows[i][2]:setColSpan(3):createSliderCell({ min = content.scale.min, max = content.scale.max, start = content.scale.start, step = content.scale.step, suffix = content.scale.suffix, readOnly = content.scale.readonly, height = Helper.standardTextHeight }):setText(content.name, { color = content.color })
-- 			end
-- 		end

-- 		-- warning header
-- 		headerrow2[1]:createText(next(warningcontent) and ReadText(1001, 8342) or "", header2properties)

-- 		-- buttons
-- 		warningrows[menu.tradeContext.numwarningrows][3]:createButton({ active = confirmbuttonactive, height = Helper.standardTextHeight }):setText(ReadText(1001, 2821), { halign = "center" })
-- 		warningrows[menu.tradeContext.numwarningrows][3].handlers.onClick = menu.buttonConfirmTrade
-- 		warningrows[menu.tradeContext.numwarningrows][3].properties.uiTriggerID = "confirmtrade"
-- 		warningrows[menu.tradeContext.numwarningrows][4]:createButton({ height = Helper.standardTextHeight }):setText(ReadText(1001, 64), { halign = "center" })
-- 		warningrows[menu.tradeContext.numwarningrows][4].handlers.onClick = menu.buttonCancelTrade
-- 		warningrows[menu.tradeContext.numwarningrows][4].properties.uiTriggerID = "canceltrade"
-- 	else
-- 		-- profits from sales
-- 		local profit = menu.contextMenuData.referenceprofit
-- 		local profitcolor = Color["text_normal"]
-- 		if profit < 0 then
-- 			profitcolor = Color["text_negative"]
-- 		elseif profit > 0 then
-- 			profitcolor = Color["text_positive"]
-- 		end
-- 		inforows[menu.tradeContext.numinforows - 1][2 + coloffset]:createText(ReadText(1001, 8305) .. ReadText(1001, 120))
-- 		inforows[menu.tradeContext.numinforows - 1][3 + coloffset]:setColSpan(2):createText(ConvertMoneyString(profit, false, true, nil, true) .. " " .. ReadText(1001, 101), { halign = "right", color = profitcolor })

-- 		-- transaction value
-- 		local total = menu.contextMenuData.totalbuyprofit - menu.contextMenuData.totalsellcost
-- 		local transactioncolor = Color["text_normal"]
-- 		if total < 0 then
-- 			transactioncolor = Color["text_negative"]
-- 		elseif total > 0 then
-- 			transactioncolor = Color["text_positive"]
-- 		end
-- 		inforows[menu.tradeContext.numinforows][2 + coloffset]:createText(ReadText(1001, 2005) .. ReadText(1001, 120)) -- Transaction value, :
-- 		inforows[menu.tradeContext.numinforows][3 + coloffset]:setColSpan(2):createText(ConvertMoneyString(total, false, true, nil, true) .. " " .. ReadText(1001, 101), { halign = "right", color = transactioncolor })

-- 		-- pricing details
-- 		if showdiscountinfo and (#pricemodifiers > 0) then
-- 			for i, entry in ipairs(pricemodifiers) do
-- 				if i < #pricemodifiers then
-- 					local row
-- 					if i <= menu.tradeContext.numinforows then
-- 						row = inforows[i]
-- 					elseif i == menu.tradeContext.numinforows + 1 then
-- 						row = headerrow2
-- 					elseif i <= menu.tradeContext.numinforows + 1 + menu.tradeContext.numwarningrows - 1 then
-- 						row = warningrows[i - menu.tradeContext.numinforows - 1]
-- 					end
-- 					if row then
-- 						row[2]:createText(entry.text, { x = config.tradeContextMenuInfoBorder })
-- 						row[3]:createText(entry.amount, { x = config.tradeContextMenuInfoBorder, halign = "right" })
-- 					end
-- 				end
-- 			end
-- 			local y = math.max(0, warningrows[menu.tradeContext.numwarningrows]:getHeight() - Helper.scaleY(Helper.standardTextHeight))
-- 			warningrows[menu.tradeContext.numwarningrows][2]:createText(pricemodifiers[#pricemodifiers].text, { scaling = false, fontsize = Helper.scaleFont(Helper.standardFont, Helper.standardFontSize), x = Helper.scaleX(config.tradeContextMenuInfoBorder), y = y })
-- 			warningrows[menu.tradeContext.numwarningrows][3]:createText(pricemodifiers[#pricemodifiers].amount, { scaling = false, fontsize = Helper.scaleFont(Helper.standardFont, Helper.standardFontSize), x = Helper.scaleX(config.tradeContextMenuInfoBorder), y = y, halign = "right" })
-- 		end

-- 		-- header
-- 		headerrow[1]:createText(storageheader, header2properties)
-- 		if showdiscountinfo then
-- 			headerrow[2]:setColSpan(2):createText(ReadText(1001, 11653), header2properties)
-- 		end
-- 		headerrow[2 + coloffset]:setColSpan(3):createText(ReadText(1001, 2006), header2properties)

-- 		-- warning header
-- 		headerrow2[1]:createText(next(warningcontent) and ReadText(1001, 8342) or "", header2properties)

-- 		-- buttons
-- 		local y = math.max(0, warningrows[menu.tradeContext.numwarningrows]:getHeight() - Helper.scaleY(Helper.standardTextHeight))
-- 		if (not GetComponentData(menu.contextMenuData.component, "tradesubscription")) and (#menu.contextMenuData.missionoffers == 0) then
-- 			warningrows[menu.tradeContext.numwarningrows][2 + coloffset]:createButton({ active = (menu.contextMenuData.currentShip ~= 0) and C.IsOrderSelectableFor("Player_DockToTrade", menu.contextMenuData.currentShip), scaling = false, height = Helper.scaleY(Helper.standardTextHeight), y = y }):setText(ReadText(1001, 7858), { scaling = true, halign = "center" })
-- 			warningrows[menu.tradeContext.numwarningrows][2 + coloffset].handlers.onClick = menu.buttonDockToTrade
-- 		else
-- 			warningrows[menu.tradeContext.numwarningrows][2 + coloffset]:createButton({ active = confirmbuttonactive, helpOverlayID = "map_confirmtrade", helpOverlayText = " ", helpOverlayHighlightOnly = true, scaling = false, height = Helper.scaleY(Helper.standardTextHeight), y = y }):setText(ReadText(1001, 2821), { scaling = true, halign = "center" })
-- 			warningrows[menu.tradeContext.numwarningrows][2 + coloffset].handlers.onClick = menu.buttonConfirmTrade
-- 			warningrows[menu.tradeContext.numwarningrows][2 + coloffset].properties.uiTriggerID = "confirmtrade"
-- 		end
-- 		warningrows[menu.tradeContext.numwarningrows][3 + coloffset]:setColSpan(2):createButton({ scaling = false, height = Helper.scaleY(Helper.standardTextHeight), y = y }):setText(ReadText(1001, 64), { scaling = true, halign = "center" })
-- 		warningrows[menu.tradeContext.numwarningrows][3 + coloffset].handlers.onClick = menu.buttonCancelTrade
-- 		warningrows[menu.tradeContext.numwarningrows][3 + coloffset].properties.uiTriggerID = "canceltrade"
-- 	end

-- 	if buttontable.properties.y + buttontable:getFullHeight() > Helper.viewHeight - frame.properties.y then
-- 		frame.properties.y = Helper.viewHeight - buttontable.properties.y - buttontable:getFullHeight() - Helper.frameBorder
-- 	end

-- 	shiptable.properties.nextTable = buttontable.index
-- 	buttontable.properties.prevTable = shiptable.index
-- end

Init()

return
