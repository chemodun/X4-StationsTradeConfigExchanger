local ffi = require("ffi")
local C = ffi.C

ffi.cdef [[
  typedef uint64_t UniverseID;
  typedef int32_t TradeRuleID;

  const char* GetComponentName(UniverseID componentid);
  const char* GetObjectIDCode(UniverseID objectid);

	uint32_t GetNumCargoTransportTypes(UniverseID containerid, bool merge);

  bool GetContainerWareIsBuyable(UniverseID containerid, const char* wareid);
  bool GetContainerWareIsSellable(UniverseID containerid, const char* wareid);

  int32_t GetContainerBuyLimit(UniverseID containerid, const char* wareid);
  int32_t GetContainerSellLimit(UniverseID containerid, const char* wareid);

  bool HasContainerBuyLimitOverride(UniverseID containerid, const char* wareid);
  bool HasContainerSellLimitOverride(UniverseID containerid, const char* wareid);
  bool HasContainerOwnTradeRule(UniverseID containerid, const char* ruletype, const char* wareid);

  void ClearContainerBuyLimitOverride(UniverseID containerid, const char* wareid);
  void ClearContainerSellLimitOverride(UniverseID containerid, const char* wareid);
  void ClearContainerWarePriceOverride(UniverseID containerid, const char* wareid, bool isbuy);

  void SetContainerBuyLimitOverride(UniverseID containerid, const char* wareid, int32_t amount);
  void SetContainerSellLimitOverride(UniverseID containerid, const char* wareid, int32_t amount);
  void SetContainerTradeRule(UniverseID containerid, TradeRuleID id, const char* ruletype, const char* wareid, bool value);
  void SetContainerWareIsBuyable(UniverseID containerid, const char* wareid, bool allowed);
  void SetContainerWareIsSellable(UniverseID containerid, const char* wareid, bool allowed);
  void SetContainerWarePriceOverride(UniverseID containerid, const char* wareid, bool isbuy, int32_t price);

  TradeRuleID GetContainerTradeRuleID(UniverseID containerid, const char* ruletype, const char* wareid);

  void AddTradeWare(UniverseID containerid, const char* wareid);
  void UpdateProductionTradeOffers(UniverseID containerid);
]]

local TradeConfigExchanger = {
  args = {},
  playerId = 0,
  mapMenu = {},
}

local labels = {
  title = ReadText(1972092405, 1001),
  stationOne = ReadText(1972092405, 1011),
  stationTwo = ReadText(1972092405, 1012),
  noMatchingStations = ReadText(1972092405, 1019),
  ware = ReadText(1972092405, 1101),
  storage = ReadText(1972092405, 1102),
  rule = ReadText(1972092405, 1103),
  price = ReadText(1972092405, 1104),
  amount = ReadText(1972092405, 1105),
  overrideTag = ReadText(1972092405, 1109),
  buyOfferSellOffer = ReadText(1972092405, 1111),
  selectStationOnePrompt = ReadText(1972092405, 1201),
  selectStationTwoPrompt = ReadText(1972092405, 1202),
  noWaresAvailable = ReadText(1972092405, 1203),
  buyOffer = ReadText(1001, 8309),
  sellOffer = ReadText(1001, 8308),
  auto = ReadText(1972092405, 1211),
  noBuyOffer = ReadText(1972092405, 1212),
  noSellOffer = ReadText(1972092405, 1213),
  confirmClone = ReadText(1972092405, 1301),
  cloneButton = ReadText(1972092405, 1311),
  cancelButton = ReadText(1972092405, 1319),
  resource = ReadText(1972092405, 1121),
  intermediate = ReadText(1972092405, 1122),
  product = ReadText(1972092405, 1123),
  trade = ReadText(1972092405, 1124),
}


local overrideIcons = {
}
overrideIcons[true] = "\27[menu_radio_button_on]\27X"
overrideIcons[false] = "\27[menu_radio_button_off]\27X"

local overrideIconsTextProperties = {
}
overrideIconsTextProperties[true] = { halign = "center" }
overrideIconsTextProperties[false] = { halign = "center", color = Color["text_inactive"] }

local dbg = nil

TradeConfigExchanger.labels = labels

local wareTypeSortOrder = {
  resource = 1,
  intermediate = 2,
  product = 3,
  trade = 4
}


local function copyAndEnrichTable(src, extraInfo)
  local dest = {}
  for k, v in pairs(src) do
    dest[k] = v
  end
  for k, v in pairs(extraInfo) do
    dest[k] = v
  end
  return dest
end

local tableHeadersTextProperties = copyAndEnrichTable(Helper.headerRowCenteredProperties, { fontsize = Helper.standardFontSize, height = Helper.standardTextHeight })
local wareNameTextProperties = copyAndEnrichTable(Helper.subHeaderTextProperties, { halign = "center", color = Color["table_row_highlight"] })
local cargoAmountTextProperties = copyAndEnrichTable(Helper.subHeaderTextProperties, { halign = "right", color = Color["table_row_highlight"] })
local textDelimiterTextProperties = { halign = "center", color = Color["text_notification_text_lowlight"], fontsize = 8, height = Helper.standardTextHeight / 2 }

local Lib = require("extensions.sn_mod_support_apis.ui.Library")

local function debugTrace(message)
  local text = "TradeConfigExchanger: " .. message
  if type(DebugError) == "function" then
    DebugError(text)
  end
end

local function getPlayerId()
  local current = C.GetPlayerID()
  if current == nil or current == 0 then
    return
  end

  local converted = ConvertStringTo64Bit(tostring(current))
  if converted ~= 0 and converted ~= TradeConfigExchanger.playerId then
    debugTrace("updating player_id to " .. tostring(converted))
    TradeConfigExchanger.playerId = converted
  end
end

local function toUniverseId(value)
  if value == nil then
    return 0
  end

  if type(value) == "number" then
    return value
  end

  local idStr = tostring(value)
  if idStr == "" or idStr == "0" then
    return 0
  end

  return ConvertStringTo64Bit(idStr)
end


local function getStationName(id)
  if id == 0 then
    return "Unknown"
  end
  local name = GetComponentData(ConvertStringToLuaID(tostring(id)), "name")
  local idCode = ffi.string(C.GetObjectIDCode(id))
  return string.format("%s (%s)", name, idCode)
end

local function centerFrameVertically(frame)
  frame.properties.height = frame:getUsedHeight() + Helper.borderSize
  if (frame.properties.height > Helper.viewHeight) then
    frame.properties.y = Helper.borderSize
    frame.properties.height = Helper.viewHeight - 2 * Helper.borderSize
  else
    frame.properties.y = (Helper.viewHeight - frame.properties.height) / 2
  end
end

-- function TradeConfigExchanger.alertMessage(options)
--   local menu = TradeConfigExchanger.mapMenu
--   if type(menu) ~= "table" or type(menu.closeContextMenu) ~= "function" then
--     debugTrace("alertMessage: Invalid menu instance")
--     return false, "Map menu instance is not available"
--   end
--   if type(Helper) ~= "table" then
--     debugTrace("alertMessage: Helper UI utilities are not available")
--     return false, "Helper UI utilities are not available"
--   end

--   if type(options) ~= "table" then
--     return false, "Options parameter is not a table"
--   end

--   if options.title == nil then
--     return false, "Title option is required"
--   end

--   if options.message == nil then
--     return false, "Message option is required"
--   end

--   local width = options.width or Helper.scaleX(400)
--   local xoffset = options.xoffset or (Helper.viewWidth - width) / 2
--   local yoffset = options.yoffset or Helper.viewHeight / 2
--   local okLabel = options.okLabel or ReadText(1001, 14)

--   local title = options.title
--   local message = options.message

--   menu.closeContextMenu()

--   menu.contextMenuMode = "tce_alert"
--   menu.contextMenuData = {
--     mode = "tce_alert",
--     width = width,
--     xoffset = xoffset,
--     yoffset = yoffset,
--   }

--   local contextLayer = menu.contextFrameLayer or 2

--   menu.contextFrame = Helper.createFrameHandle(menu, {
--     x = xoffset - 2 * Helper.borderSize,
--     y = yoffset,
--     width = width + 2 * Helper.borderSize,
--     layer = contextLayer,
--     standardButtons = { close = true },
--     closeOnUnhandledClick = true,
--   })
--   local frame = menu.contextFrame
--   frame:setBackground("solid", { color = Color["frame_background_semitransparent"] })

--   local ftable = frame:addTable(5, { tabOrder = 1, x = Helper.borderSize, y = Helper.borderSize, width = width, reserveScrollBar = false, highlightMode = "off" })

--   local headerRow = ftable:addRow(false, { fixed = true })
--   headerRow[1]:setColSpan(5):createText(title, copyAndEnrichTable(Helper.headerRowCenteredProperties, { color = Color["text_warning"] }))

--   ftable:addEmptyRow(Helper.standardTextHeight / 2)

--   local messageRow = ftable:addRow(false, { fixed = true })
--   messageRow[1]:setColSpan(5):createText(message, {
--     halign = "center",
--     wordwrap = true,
--     color = Color["text_normal"]
--   })

--   ftable:addEmptyRow(Helper.standardTextHeight / 2)

--   local buttonRow = ftable:addRow(true, { fixed = true })
--   buttonRow[3]:createButton():setText(okLabel, { halign = "center" })
--   buttonRow[3].handlers.onClick = function()
--     local shouldClose = true
--     if shouldClose then
--       menu.closeContextMenu("back")
--     end
--   end
--   ftable:setSelectedCol(3)

--   centerFrameVertically(frame)

--   frame:display()

--   return true
-- end

function TradeConfigExchanger.showTargetAlert()
  local options = {}
  options.title = ReadText(1972092408, 10310)
  options.message = ReadText(1972092408, 10311)
  TradeConfigExchanger.alertMessage(options)
end

local function collectWaresAndProductionSignature(entry)
  if entry.productionSignature then
    return
  end

  local products, rawWares, cargoWares = GetComponentData(entry.id, "products", "tradewares", "cargo")
  if type(products) ~= "table" then
    products = {}
  end
  if type(rawWares) ~= "table" then
    rawWares = {}
  end
  if type(cargoWares) ~= "table" then
    cargoWares = {}
  end
  table.sort(products)
  entry.products = products
  entry.productionSignature = table.concat(products, "|")
  local waresSet = {}
  local wares = {}
  for i = 1, #products do
    waresSet[products[i]] = true
    wares[#wares + 1] = products[i]
  end
  for i = 1, #rawWares do
    if (not waresSet[rawWares[i]]) then
      wares[#wares + 1] = rawWares[i]
      waresSet[rawWares[i]] = true
    end
  end
  for ware, amount in pairs(cargoWares) do
    if (not waresSet[ware]) then
      wares[#wares + 1] = ware
      waresSet[ware] = true
    end
  end
  table.sort(wares)
  entry.tradeData = {}
  entry.tradeData.wares = wares
  entry.tradeData.waresAmounts = cargoWares
  entry.tradeData.waresSet = waresSet
end

local function buildStationCache()
  local stations = {}
  local options = {}
  local list = GetContainedStationsByOwner("player", nil, true) or {}

  for i = 1, #list do
    local id = list[i]
    local id64 = toUniverseId(id)
    if id and id64 and (id64 ~= 0) then
      local entry = {
        id = id,
        id64 = id64,
      }
      debugTrace("Found station: " .. tostring(id) .. " / " .. tostring(id64))
      entry.displayName = getStationName(entry.id64)
      local numStorages = C.GetNumCargoTransportTypes(entry.id64, true)
      local isshipyard, iswharf = GetComponentData(entry.id64, "isshipyard", "iswharf")
      if isshipyard or iswharf then
        debugTrace("Skipping station that is a shipyard or wharf: " .. tostring(entry.displayName))
      elseif numStorages == 0 then
        debugTrace("Skipping station without cargo capacity: " .. tostring(entry.displayName))
      else
        collectWaresAndProductionSignature(entry)
        stations[id64] = entry
        options[#options + 1] = { id = id64, icon = "", text = entry.displayName, displayremoveoption = false }
      end
    end
  end

  table.sort(options, function(a, b)
    return a.text < b.text
  end)

  return stations, options
end

local function ensureTradeRuleNames()
  if TradeConfigExchanger.tradeRuleNames then
    return
  end
  if type(Helper) ~= "table" then
    return
  end
  if type(Helper.updateTradeRules) == "function" then
    Helper.updateTradeRules()
  end
  local mapping = {}
  if type(Helper.traderuleOptions) == "table" then
    for _, option in ipairs(Helper.traderuleOptions) do
      mapping[option.id] = option.text
    end
  end
  TradeConfigExchanger.tradeRuleNames = mapping
end

local function formatTradeRuleLabel(id, hasOwn)
  ensureTradeRuleNames()
  if id == 0 then
    id = -1
  end
  local label = TradeConfigExchanger.tradeRuleNames and TradeConfigExchanger.tradeRuleNames[id]
  if not label or label == "" then
    label = string.format("Rule %s", tostring(id))
  end
  return label
end

local function collectTradeData(entry, forceRefresh)
  if entry.tradeData and entry.tradeData.waresMap and not forceRefresh then
    return entry.tradeData
  end

  local container = entry.id64
  local wares = entry.tradeData and entry.tradeData.wares or {}
  local map = {}

  if #wares > 0 then
    for i = 1, #wares do
      local ware = wares[i]
      local name = GetWareData(ware, "name")
      local wareType = Helper.getContainerWareType(container, ware)
      local storageLimit = GetWareProductionLimit(container, ware)
      local storageLimitOverride = HasContainerStockLimitOverride(container, ware)
      local buyAllowed = C.GetContainerWareIsBuyable(container, ware)
      local buyLimit = C.GetContainerBuyLimit(container, ware)
      local buyOverride = C.HasContainerBuyLimitOverride(container, ware)
      local buyPrice = RoundTotalTradePrice(GetContainerWarePrice(container, ware, true))
      local buyPriceOverride = HasContainerWarePriceOverride(container, ware, true)
      local buyRuleId = C.GetContainerTradeRuleID(container, "buy", ware)
      local buyOwnRule = C.HasContainerOwnTradeRule(container, "buy", ware)

      local sellAllowed = C.GetContainerWareIsSellable(container, ware)
      local sellLimit = C.GetContainerSellLimit(container, ware)
      local sellOverride = C.HasContainerSellLimitOverride(container, ware)
      local sellPrice = RoundTotalTradePrice(GetContainerWarePrice(container, ware, false))
      local sellPriceOverride = HasContainerWarePriceOverride(container, ware, false)
      local sellRuleId = C.GetContainerTradeRuleID(container, "sell", ware)
      local sellOwnRule = C.HasContainerOwnTradeRule(container, "sell", ware)

      map[ware] = {
        ware = ware,
        name = name,
        type = wareType,
        amount = entry.tradeData.waresAmounts[ware] or 0,
        storageLimit = storageLimit,
        storageLimitOverride = storageLimitOverride,
        buy = {
          allowed = (wareType == "resource") or (wareType == "intermediate") or buyAllowed or buyOverride,
          limit = buyLimit,
          limitOverride = buyOverride,
          price = buyPrice,
          priceOverride = buyPriceOverride,
          rule = buyRuleId,
          ruleOverride = buyOwnRule,
        },
        sell = {
          allowed = (wareType == "product") or (wareType == "intermediate") or sellAllowed or sellOverride,
          limit = sellLimit,
          limitOverride = sellOverride,
          price = sellPrice,
          priceOverride = sellPriceOverride,
          rule = sellRuleId,
          ruleOverride = sellOwnRule,
        }
      }
    end
  end
  entry.tradeData.waresMap = map
  return entry.tradeData
end

local function formatLimit(value, override)
  if not override then
    return labels.auto
  end
  return ConvertIntegerString(value, true, 12, true)
end

local function formatPrice(value, override)
  if not override then
    return labels.auto
  end
  local amount = ConvertMoneyString(value, true, true, 2, true)
  return amount
end

local function optionsNumber(override)
  if override then
    return { halign = "right" }
  end
  return { halign = "center", color = Color["text_inactive"] }
end

local function optionsRule(override)
  if override then
    return { halign = "left" }
  end
  return { halign = "left", color = Color["text_inactive"] }
end


local function updateStationTwoOptions(data)
  local options = {}
  local total = 0
  local matches = 0
  if (data.selectedStationOne == nil) then
    data.stationTwoOptions = options
    data.stationTwoCounts = { matches = matches, total = total }
    return
  end
  local stationOneEntry = data.selectedStationOne and data.stations[data.selectedStationOne]
  local signature = stationOneEntry and stationOneEntry.productionSignature or nil

  for id, entry in pairs(data.stations) do
    if id ~= data.selectedStationOne then
      total = total + 1
      local qualifies = (not data.requireMatch) or (signature == nil) or (entry.productionSignature == signature)
      if qualifies then
        matches = matches + 1
        options[#options + 1] = { id = id, icon = "", text = entry.displayName, displayremoveoption = false }
      end
    end
  end

  table.sort(options, function(a, b)
    return a.text < b.text
  end)

  data.stationTwoOptions = options
  data.stationTwoCounts = { matches = matches, total = total }

  if data.selectedStationTwo then
    local present = false
    for _, option in ipairs(options) do
      if option.id == data.selectedStationTwo then
        present = true
        break
      end
    end
    if not present then
      data.selectedStationTwo = nil
      data.pendingResetSelections = true
    end
  end
end

local function sortWareList(a, b)
  local oa = wareTypeSortOrder[a.type]
  local ob = wareTypeSortOrder[b.type]
  if oa ~= ob then return oa < ob end
  return a.name < b.name
end

local function buildUnion(stationOneData, stationTwoData)
  local union = {}
  local list = {}
  if stationOneData then
    for ware, info in pairs(stationOneData.waresMap) do
      union[ware] = true
      list[#list + 1] = { ware = ware, name = info.name, type = info.type }
    end
  end
  if stationTwoData then
    for ware, info in pairs(stationTwoData.waresMap) do
      if not union[ware] then
        union[ware] = true
        list[#list + 1] = { ware = ware, name = info.name, type = info.type }
      end
    end
  end
  table.sort(list, sortWareList)
  return list
end

local function applyTradeRule(target, ware, stationOneSide)
  if stationOneSide.hasOwnRule then
    local id = stationOneSide.tradeRule
    if id == 0 then
      id = -1
    end
    C.SetContainerTradeRule(target, id, stationOneSide.isbuy and "buy" or "sell", ware, true)
  else
    C.SetContainerTradeRule(target, -1, stationOneSide.isbuy and "buy" or "sell", ware, false)
  end
end

local function cloneSide(target, ware, stationOneSide)
  if stationOneSide.allowed ~= nil then
    if stationOneSide.isbuy then
      C.SetContainerWareIsBuyable(target, ware, stationOneSide.allowed)
    else
      C.SetContainerWareIsSellable(target, ware, stationOneSide.allowed)
    end
  end

  if stationOneSide.limitOverride then
    if stationOneSide.isbuy then
      C.SetContainerBuyLimitOverride(target, ware, stationOneSide.limit)
    else
      C.SetContainerSellLimitOverride(target, ware, stationOneSide.limit)
    end
  else
    if stationOneSide.isbuy then
      C.ClearContainerBuyLimitOverride(target, ware)
    else
      C.ClearContainerSellLimitOverride(target, ware)
    end
  end

  if stationOneSide.priceOverride then
    C.SetContainerWarePriceOverride(target, ware, stationOneSide.isbuy, stationOneSide.price)
  else
    C.ClearContainerWarePriceOverride(target, ware, stationOneSide.isbuy)
  end

  applyTradeRule(target, ware, stationOneSide)
end

local function sideFromInfo(info, isbuy)
  if not info then
    return nil
  end
  local copy = {}
  for k, v in pairs(info) do
    copy[k] = v
  end
  copy.isbuy = isbuy
  return copy
end

local function applyClone(menu, leftToRight)
  local data = menu.contextMenuData
  if not data then
    return
  end
  local stationOneEntry = data.selectedStationOne and data.stations[data.selectedStationOne]
  local stationTwoEntry = data.selectedStationTwo and data.stations[data.selectedStationTwo]
  if not stationOneEntry or not stationTwoEntry then
    data.statusMessage = "Select Station One and Station Two first."
    data.statusColor = Color and Color["text_warning"] or nil
    TradeConfigExchanger.render()
    return
  end
  local sourceEntry = leftToRight and stationOneEntry or stationTwoEntry
  local targetEntry = leftToRight and stationTwoEntry or stationOneEntry

  local sourceData = collectTradeData(sourceEntry)
  local targetData = collectTradeData(targetEntry)
  local toClone = data.clone.wares
  if toClone == nil or data.clone.confirmed ~= true then
    data.statusMessage = "No wares selected to clone."
    data.statusColor = Color and Color["text_warning"] or nil
    TradeConfigExchanger.render()
    return
  end

  local skipped = {}
  for ware, parts in pairs(toClone) do
    local sourceWareData = sourceData.waresMap[ware]
    local targetWareData = targetData.waresMap[ware]
    if (sourceWareData or targetWareData) and (parts.storage or parts.buy or parts.sell) then
      if not sourceWareData and not (parts.storage and parts.buy and parts.sell) then
        debugTrace("Skipping ware " .. tostring(ware) .. " as it is not present in source station and not fully selected for removal")
        skipped[#skipped + 1] = targetWareData.name or ware
      elseif not sourceWareData and (parts.storage and parts.buy and parts.sell) then
        debugTrace("Removing ware " .. tostring(ware) .. " from target station as it is not present in source station")
        C.RemoveTradeWare(targetEntry.id64, ware)
      elseif sourceWareData and not targetWareData and not (parts.storage and parts.buy and parts.sell) then
        debugTrace("Skipping ware " .. tostring(ware) .. " as it is not present in target station and not fully selected for addition")
        skipped[#skipped + 1] = sourceWareData.name or ware
      else
        if sourceWareData and not targetWareData then
          debugTrace("Adding ware " .. tostring(ware) .. " to target station")
          C.AddTradeWare(targetEntry.id64, ware)
        end
        if parts.storage then
          if sourceWareData and not sourceWareData.storageLimitOverride and (targetWareData == nil or not targetWareData.storageLimitOverride) then
            debugTrace("Skipping storage limit clone for ware " .. tostring(ware) .. " as both source and target have no override")
          elseif sourceWareData and not sourceWareData.storageLimitOverride and targetWareData and targetWareData.storageLimitOverride then
            debugTrace("Clearing storage limit override for ware " .. tostring(ware) .. " on target station")
            ClearContainerStockLimitOverride(targetEntry.id64, ware)
          else
            local sourceLimit = sourceWareData and sourceWareData.storageLimit or 0
            local targetLimit = targetWareData and targetWareData.storageLimit or 0
            debugTrace("Setting storage limit override for ware " .. tostring(ware) .. " on target station to " .. tostring(sourceLimit) .. " (was " .. tostring(targetLimit) .. ")")
          end
          debugTrace("Cloning storage limit for ware " .. tostring(ware))
        end
        if parts.buy then
          debugTrace("Cloning buy offer for ware " .. tostring(ware))
        end
        if parts.sell then
          debugTrace("Cloning sell offer for ware " .. tostring(ware))
        end
      end
    end
  end

  collectTradeData(targetEntry, true)
  TradeConfigExchanger.reInitData(true)
  if #skipped > 0 then
    data.statusMessage = "Skipped wares: " .. table.concat(skipped, ", ")
    data.statusColor = Color and Color["text_warning"] or nil
  else
    data.statusMessage = "Clone operation completed successfully."
    data.statusColor = Color and Color["text_success"] or nil
  end
  TradeConfigExchanger.render()
end

local function renderStorage(row, entry, isStationOne)
  if (entry == nil) or (row == nil) then
    return
  end
  local idx = isStationOne and 5 or 11
  row[idx]:createText(formatLimit(entry.amount, true), cargoAmountTextProperties)
  row[idx + 1]:createText(overrideIcons[entry.storageLimitOverride], overrideIconsTextProperties[entry.storageLimitOverride])
  row[idx + 2]:createText(formatLimit(entry.storageLimit, entry.storageLimitOverride), optionsNumber(entry.storageLimitOverride))
end
local function renderOffer(row, offerData, isBuy, isStationOne)
  local idx = isStationOne and 2 or 8
  if (offerData == nil) or (not offerData.allowed) or (row == nil) then
    row[idx]:setColSpan(6):createText(isBuy and labels.noBuyOffer or labels.noSellOffer, { halign = "center" })
    return
  end
  row[idx]:createText(overrideIcons[offerData.priceOverride], overrideIconsTextProperties[offerData.priceOverride])
  row[idx + 1]:createText(formatPrice(offerData.price, offerData.priceOverride), optionsNumber(offerData.priceOverride))
  row[idx + 2]:createText(overrideIcons[offerData.limitOverride], overrideIconsTextProperties[offerData.limitOverride])
  row[idx + 3]:createText(formatLimit(offerData.limit, offerData.limitOverride), optionsNumber(offerData.limitOverride))
  row[idx + 4]:createText(overrideIcons[offerData.ruleOverride], overrideIconsTextProperties[offerData.ruleOverride])
  row[idx + 5]:createText(formatTradeRuleLabel(offerData.rule, offerData.ruleOverride), optionsRule(offerData.ruleOverride))
end

local function setMainTableColumnsWidth(tableHandle)
  local numberWidth = 100
  local textWidth = 130
  local overrideWidth = 54
  local width = Helper.standardTextHeight
  tableHandle:setColWidth(1, width, false)
  for i = 2, 13 do
    if i % 2 == 0 then
      width = width + overrideWidth
      tableHandle:setColWidth(i, overrideWidth, false)
    else
      local valueWidth = numberWidth
      if (i == 7) or (i == 13) then
        valueWidth = textWidth
      end
      width = width + valueWidth
      tableHandle:setColWidth(i, valueWidth, true)
    end
  end
  return width
end

function TradeConfigExchanger.reInitData(cloneOnly)
  local menu = TradeConfigExchanger.mapMenu
  if type(menu) ~= "table" then
    debugTrace("TradeConfigExchanger: reInitData: Invalid menu instance")
    return
  end
  if menu.contextMenuData == nil then
    menu.contextMenuData = {}
  end
  local data = menu.contextMenuData
  data.clone = {}
  data.clone.wares = {}
  data.clone.types = {}
  data.clone.confirmed = false
  if cloneOnly then
    return
  end
  data.content = {}
end

function TradeConfigExchanger.render()
  local menu = TradeConfigExchanger.mapMenu
  if type(menu) ~= "table" or type(Helper) ~= "table" then
    debugTrace("TradeConfigExchanger: Render: Invalid menu instance or Helper UI utilities are not available")
    return
  end
  local data = menu.contextMenuData or {}
  if data.mode ~= "trade_config_exchanger" then
    return
  end
  debugTrace("Rendering Trade Config Exchanger UI")

  Helper.removeAllWidgetScripts(menu, data.layer)

  local frame = Helper.createFrameHandle(menu, {
    x = data.xoffset,
    y = data.yoffset,
    width = data.width,
    layer = data.layer,
    standardButtons = { close = true },
    closeOnUnhandledClick = true,
  })
  frame:setBackground("solid", { color = Color and Color["frame_background_semitransparent"] or nil })

  local columns = 13
  local tableTop = frame:addTable(columns, { tabOrder = 1, reserveScrollBar = false, highlightMode = "off", x = Helper.borderSize, y = Helper.borderSize, })
  setMainTableColumnsWidth(tableTop)

  local row = tableTop:addRow(false, { fixed = true })
  row[1]:setColSpan(columns):createText(labels.title, Helper.headerRowCenteredProperties)


  row = tableTop:addRow(false, { fixed = true })
  row[2]:setColSpan(6):createText(labels.stationOne, Helper.headerRowCenteredProperties)
  row[8]:setColSpan(6):createText(labels.stationTwo, Helper.headerRowCenteredProperties)
  row = tableTop:addRow(true, { fixed = true })
  row[1]:createText("")
  debugTrace("Rendering station One DropDown with " .. tostring(#data.stationOneOptions) .. " options, selected: " .. tostring(data.selectedStationOne))
  row[2]:setColSpan(6):createDropDown(data.stationOneOptions, {
    startOption = data.selectedStationOne or -1,
    active = #data.stationOneOptions > 0,
    textOverride = (#data.stationOneOptions == 0) and "No player stations" or nil,
  })
  row[2].handlers.onDropDownConfirmed = function(_, id)
    data.selectedStationOne = tonumber(id)
    if data.selectedStationTwo == data.selectedStationOne then
      data.selectedStationTwo = nil
    end
    data.pendingResetSelections = true
    updateStationTwoOptions(data)
    data.statusMessage = nil
    TradeConfigExchanger.reInitData()
    TradeConfigExchanger.render()
  end

  row[8]:setColSpan(6):createDropDown(data.stationTwoOptions, {
    startOption = data.selectedStationTwo or -1,
    active = #data.stationTwoOptions > 0,
    textOverride = (#data.stationTwoOptions == 0) and labels.noMatchingStations or nil,
  })
  row[8].handlers.onDropDownConfirmed = function(_, id)
    data.selectedStationTwo = tonumber(id)
    data.pendingResetSelections = true
    data.statusMessage = nil
    TradeConfigExchanger.reInitData()
    TradeConfigExchanger.render()
  end


  row = tableTop:addRow(false, { fixed = true })
  row[2]:setColSpan(3):createText(labels.ware, tableHeadersTextProperties)
  row[5]:createText(labels.amount, tableHeadersTextProperties)
  row[6]:createText(labels.overrideTag, tableHeadersTextProperties)
  row[7]:createText(labels.storage, tableHeadersTextProperties)
  row[11]:createText(labels.amount, tableHeadersTextProperties)
  row[12]:createText(labels.overrideTag, tableHeadersTextProperties)
  row[13]:createText(labels.storage, tableHeadersTextProperties)
  row = tableTop:addRow(false, { fixed = true })
  row[2]:setColSpan(12):createText(labels.buyOfferSellOffer, tableHeadersTextProperties)
  row = tableTop:addRow(false, { fixed = true })
  row[2]:createText(labels.overrideTag, tableHeadersTextProperties)
  row[3]:createText(labels.price, tableHeadersTextProperties)
  row[4]:createText(labels.overrideTag, tableHeadersTextProperties)
  row[5]:createText(labels.amount, tableHeadersTextProperties)
  row[6]:createText(labels.overrideTag, tableHeadersTextProperties)
  row[7]:createText(labels.rule, tableHeadersTextProperties)
  row[8]:createText(labels.overrideTag, tableHeadersTextProperties)
  row[9]:createText(labels.price, tableHeadersTextProperties)
  row[10]:createText(labels.overrideTag, tableHeadersTextProperties)
  row[11]:createText(labels.amount, tableHeadersTextProperties)
  row[12]:createText(labels.overrideTag, tableHeadersTextProperties)
  row[13]:createText(labels.rule, tableHeadersTextProperties)

  tableTop:addEmptyRow(Helper.standardTextHeight / 2, { fixed = true })
  tableTop:setSelectedCol(2)

  local currentY = tableTop:getFullHeight() + Helper.borderSize * 2

  local tableContent = frame:addTable(columns, { tabOrder = 2, reserveScrollBar = true, highlightMode = "on", x = Helper.borderSize, y = currentY, })
  setMainTableColumnsWidth(tableContent)

  local stationOneEntry = data.selectedStationOne and data.stations[data.selectedStationOne]
  local stationTwoEntry = data.selectedStationTwo and data.stations[data.selectedStationTwo]
  local selectedCount = 0
  local activeContent = false
  if stationOneEntry == nil then
    debugTrace("No stations are selected")
    row = tableContent:addRow(false, { fixed = true })
    row[2]:setColSpan(columns - 1):createText(labels.selectStationOnePrompt,
      { color = Color and Color["text_warning"] or nil, halign = "center" })
  else
    debugTrace("Station One: " .. tostring(stationOneEntry.displayName) .. " (" .. tostring(stationOneEntry.id64) .. ")")
    local stationOneData = collectTradeData(stationOneEntry)
    local stationTwoData = stationTwoEntry and collectTradeData(stationTwoEntry) or nil
    local wareList = buildUnion(stationOneData, stationTwoData)
    local readyToSelectWares = stationOneEntry ~= nil and stationTwoEntry ~= nil and #wareList > 0
    debugTrace("Processing " .. tostring(#wareList) .. " wares for comparison")
    local wareType = nil
    if #wareList == 0 then
      row = tableContent:addRow(false, { fixed = true })
      row[2]:setColSpan(columns - 1):createText(labels.noWaresAvailable,
        { color = Color and Color["text_warning"] or nil, halign = "center" })
    else
      for i = 1, #wareList do
        local ware = wareList[i]
        local stationOneInfo = ware.ware and stationOneData.waresMap[ware.ware]
        local stationTwoInfo = ware.ware and stationTwoData and stationTwoData.waresMap[ware.ware] or nil

        local wareInfo = stationOneInfo or stationTwoInfo
        if wareInfo == nil then
          debugTrace("Skipping ware " .. tostring(ware.ware) .. " - no data on either station")
        else
          if wareType ~= wareInfo.type then
            wareType = wareInfo.type
            local typeRow = tableContent:addRow(true, { fixed = false, bgColor = Color and Color["row_background_unselectable"] or nil })
            if data.clone.types[wareType] == nil then
              data.clone.types[wareType] = false
            end
            if not activeContent then
              activeContent = true
            end
            typeRow[1]:createCheckBox(data.clone.types[wareType], { active = readyToSelectWares })
            local wType = wareType
            typeRow[1].handlers.onClick = function(_, checked)
              data.clone.types[wType] = checked
              debugTrace("Set clone for ware type " .. tostring(wType) .. " to " .. tostring(checked))
              for j = i, #wareList do
                local w = wareList[j]
                local info = w.ware and stationOneData.waresMap[w.ware] or stationTwoData and stationTwoData.waresMap[w.ware] or nil
                if info == nil or info.type ~= wType then
                  break
                end
                data.clone.wares[w.ware] = { storage = checked, buy = checked, sell = checked }
              end
              data.clone.confirmed = false
              data.statusMessage = nil
              TradeConfigExchanger.render()
            end
            typeRow[2]:setColSpan(columns - 1):createText(labels[wareType], { font = Helper.standardFontBold, halign = "center" })
            tableContent:addEmptyRow(Helper.standardTextHeight / 2, { fixed = false })
          end
          if data.clone.wares[ware.ware] == nil then
            data.clone.wares[ware.ware] = { storage = false, buy = false, sell = false }
          end
          local textDelimiter = tableContent:addRow(true, { fixed = false })
          textDelimiter[2]:setColSpan(columns - 1):createText(labels.ware, textDelimiterTextProperties)
          local row = tableContent:addRow(true, { fixed = false })
          if data.clone.wares[ware.ware].storage then
            selectedCount = selectedCount + 1
          end
          row[1]:createCheckBox(data.clone.wares[ware.ware].storage, { active = readyToSelectWares })
          row[1].handlers.onClick = function(_, checked)
            local propagate = data.clone.wares[ware.ware].storage == data.clone.wares[ware.ware].buy and data.clone.wares[ware.ware].storage == data.clone.wares[ware.ware].sell
            data.clone.wares[ware.ware].storage = checked
            if propagate then
              data.clone.wares[ware.ware].buy = checked
              data.clone.wares[ware.ware].sell = checked
            end
            if checked == false then
              if wareInfo and wareInfo.type then
                data.clone.types[wareInfo.type] = false
              end
            end
            debugTrace("Set clone for ware " .. tostring(ware.ware) .. " to " .. tostring(checked))
            data.clone.confirmed = false
            data.statusMessage = nil
            TradeConfigExchanger.render()
          end
          row[2]:setColSpan(3):createText(ware.name, wareNameTextProperties)
          if stationOneInfo then
            renderStorage(row, stationOneInfo, true)
          end
          if stationTwoInfo then
            renderStorage(row, stationTwoInfo, false)
          elseif stationTwoData == nil then
            if i == 1 then
              row[8]:setColSpan(6):createText(labels.selectStationTwoPrompt, { color = Color and Color["text_warning"] or nil, halign = "center" })
            end
          end
          textDelimiter = tableContent:addRow(true, { fixed = false })
          textDelimiter[2]:setColSpan(columns - 1):createText(labels.buyOffer, textDelimiterTextProperties)
          local row = tableContent:addRow(true, { fixed = false })
          if data.clone.wares[ware.ware].buy then
            selectedCount = selectedCount + 1
          end
          row[1]:createCheckBox(data.clone.wares[ware.ware].buy, { active = readyToSelectWares })
          row[1].handlers.onClick = function(_, checked)
            data.clone.wares[ware.ware].buy = checked
            debugTrace("Set clone for ware " .. tostring(ware.ware) .. " buy offer to " .. tostring(checked))
            if checked == false then
              if wareInfo and wareInfo.type then
                data.clone.types[wareInfo.type] = false
              end
            end
            data.clone.confirmed = false
            data.statusMessage = nil
            TradeConfigExchanger.render()
          end
          if stationOneInfo then
            renderOffer(row, stationOneInfo.buy, true, true)
          end
          if stationTwoInfo then
            renderOffer(row, stationTwoInfo.buy, true, false)
          end
          textDelimiter = tableContent:addRow(true, { fixed = false })
          textDelimiter[2]:setColSpan(columns - 1):createText(labels.sellOffer, textDelimiterTextProperties)
          local row = tableContent:addRow(true, { fixed = false })
          if data.clone.wares[ware.ware].sell then
            selectedCount = selectedCount + 1
          end
          row[1]:createCheckBox(data.clone.wares[ware.ware].sell, { active = readyToSelectWares })
          row[1].handlers.onClick = function(_, checked)
            data.clone.wares[ware.ware].sell = checked
            debugTrace("Set clone for ware " .. tostring(ware.ware) .. " sell offer to " .. tostring(checked))
            if checked == false then
              if wareInfo and wareInfo.type then
                data.clone.types[wareInfo.type] = false
              end
            end
            data.clone.confirmed = false
            data.statusMessage = nil
            TradeConfigExchanger.render()
          end
          if stationOneInfo then
            renderOffer(row, stationOneInfo.sell, false, true)
          end
          if stationTwoInfo then
            renderOffer(row, stationTwoInfo.sell, false, false)
          end
        end
        tableContent:addEmptyRow(Helper.standardTextHeight / 2, { fixed = false })
      end
    end
  end

  if activeContent then
    tableContent:setSelectedCol(1)
  end
  tableContent.properties.maxVisibleHeight = math.min(tableContent:getFullHeight(), data.contentHeight)
  if data.content and data.content.tableContentId then
    local topRow = GetTopRow(data.content.tableContentId)
    if topRow and topRow > 0 then
      tableContent:setTopRow(topRow)
    end
    local selectedRow = Helper.currentTableRow[data.content.tableContentId]
    if selectedRow ~= nil and selectedRow > 0 then
      tableContent:setSelectedRow(selectedRow)
    end
  end

  currentY = currentY + tableContent.properties.maxVisibleHeight + Helper.borderSize

  local tableConfirm = frame:addTable(9,
    { tabOrder = 3, reserveScrollBar = false, highlightMode = "off", x = Helper.borderSize, y = currentY })
  local cellWidth = math.floor((tableTop.properties.width - Helper.standardTextHeight) / 8) - 3
  for i = 1, 3 do
    tableConfirm:setColWidth(i, cellWidth, true)
  end
  tableConfirm:setColWidth(4, Helper.standardTextHeight, false)
  for i = 5, 9 do
    tableConfirm:setColWidth(i, cellWidth, true)
  end

  tableConfirm:addEmptyRow(Helper.standardTextHeight / 2)
  row = tableConfirm:addRow(true, { fixed = true })

  row[4]:createCheckBox(data.clone.confirmed, { active = selectedCount > 0 })
  row[4].handlers.onClick = function(_, checked)
    data.clone.confirmed = checked
    debugTrace("Set clone confirmed to " .. tostring(checked))
    data.statusMessage = nil
    TradeConfigExchanger.render()
  end
  row[5]:setColSpan(2):createText(labels.confirmClone, { halign = "left" })

  currentY = currentY + tableConfirm:getFullHeight() + Helper.borderSize


  local tableBottom = frame:addTable(8,
    { tabOrder = 4, reserveScrollBar = false, highlightMode = "off", x = Helper.borderSize, y = currentY })
  -- setTableColumnsWidth(tableBottom, false)

  tableBottom:setColWidth(1, Helper.standardTextHeight, false)
  local buttonWidth = math.floor((tableTop.properties.width - Helper.standardTextHeight) / 7) - 3
  for i = 2, 8 do
    tableBottom:setColWidth(i, buttonWidth, true)
  end

  row = tableBottom:addRow(true, { fixed = true })

  row[4]:createButton({ active = selectedCount > 0 and data.clone.confirmed }):setText(labels.cloneButton .. "  \27[widget_arrow_right_01]\27X",
    { halign = "center" })
  row[4].handlers.onClick = function()
    if selectedCount > 0 then
      applyClone(menu, true)
    end
  end
  row[6]:createButton({ active = selectedCount > 0 and data.clone.confirmed }):setText("\27[widget_arrow_left_01]\27X  " .. labels.cloneButton,
  { halign = "center" })
  row[6].handlers.onClick = function()
    if selectedCount > 0 then
      applyClone(menu, false)
    end
  end
  row[8]:createButton({}):setText(labels.cancelButton, { halign = "center" })
  row[8].handlers.onClick = function()
    menu.closeContextMenu()
  end

  if data.statusMessage then
    local statusRow = tableBottom:addRow(false, { fixed = true })
    statusRow[1]:setColSpan(8):createText(data.statusMessage, { wordwrap = true, color = data.statusColor })
  end
  tableBottom:setSelectedCol(8)

  frame.properties.width = tableTop.properties.width + Helper.borderSize * 2
  frame.properties.height = currentY + tableBottom:getFullHeight() + Helper.borderSize

  frame.properties.y = math.floor((Helper.viewHeight - frame.properties.height) / 2)
  frame.properties.x = math.floor((Helper.viewWidth - frame.properties.width) / 2)

  frame:display()
  data.content = {}
  data.content.tableTopId = tableTop.id
  data.content.tableContentId = tableContent.id
  data.content.tableConfirmId = tableConfirm.id
  data.content.tableBottomId = tableBottom.id
  data.frame = frame
  menu.contextFrame = frame
end

function TradeConfigExchanger.show()
  local menu = TradeConfigExchanger.mapMenu
  if type(menu) ~= "table" or type(Helper) ~= "table" then
    debugTrace("TradeConfigExchanger: Show: Invalid menu instance or Helper UI utilities are not available")
    return
  end


  if type(menu) ~= "table" or type(menu.closeContextMenu) ~= "function" then
    return false, "Menu instance is not available"
  end
  if type(Helper) ~= "table" then
    return false, "Helper UI utilities are not available"
  end

  menu.closeContextMenu()

  local data = {
    mode = "trade_config_exchanger",
    layer = menu.contextFrameLayer or 2,
    width = Helper.scaleX(1024),
    contentHeight = Helper.scaleY(480),
    xoffset = Helper.viewWidth / 2 - Helper.scaleX(450),
    yoffset = Helper.viewHeight / 6,
    requireMatch = true,
    cloneBuy = {},
    cloneSell = {},
    pendingResetSelections = true,
  }

  data.stations, data.stationOneOptions = buildStationCache()
  data.stationTwoOptions = {}

  data.selectedStationOne = nil
  data.selectedStationTwo = nil

  updateStationTwoOptions(data)

  menu.contextMenuMode = data.mode
  menu.contextMenuData = data

  TradeConfigExchanger.reInitData()
  TradeConfigExchanger.render()

  return true
end

function TradeConfigExchanger.ProcessRequest(_, _)
  return TradeConfigExchanger.show()
end

function TradeConfigExchanger.Init()
  getPlayerId()
  ---@diagnostic disable-next-line: undefined-global
  RegisterEvent("TradeConfigExchanger.Request", TradeConfigExchanger.ProcessRequest)
  AddUITriggeredEvent("TradeConfigExchanger", "Reloaded")
  TradeConfigExchanger.mapMenu = Lib.Get_Egosoft_Menu("MapMenu")
  debugTrace("MapMenu is " .. tostring(TradeConfigExchanger.mapMenu))
end

Register_Require_With_Init("extensions.stations_tce.ui.trade_config_exchanger", TradeConfigExchanger, TradeConfigExchanger.Init)

return TradeConfigExchanger
