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
  validOrders = {
    SingleBuy  = "",
    SingleSell = "",
  },
  sourceId = 0,
  targetIds = {},
}

local labels = {
  enabled = "Enabled",
  disabled = "Disabled",
  limit = "Limit: %s",
  price = "Price: %s",
  rule = "Rule: %s",
  auto = "Auto",
  overrideTag = "Override",
  cloneButton = "Clone",
  cancelButton = "Cancel",
  globalRule = "Global rule",
}


local overrideIcons = {
}
overrideIcons[true] = "\27[menu_radio_button_on]\27X"
overrideIcons[false] = "\27[menu_radio_button_off]\27X"

local overrideIconsOptions = {
}
overrideIconsOptions[true] = { halign = "center" }
overrideIconsOptions[false] = { halign = "center", color = Color["text_inactive"] }

local dbg = nil

TradeConfigExchanger.labels = labels

local wareTypeSortOrder = {
  resource = 1,
  intermediate = 2,
  product = 3,
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

local wareNameProperties = copyAndEnrichTable(Helper.subHeaderTextProperties, { halign = "center" })

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


local function computeProductionSignature(entry)
  if entry.productionSignature then
    return
  end

  local products = GetComponentData(entry.id, "products") or {}
  table.sort(products)
  entry.products = products
  entry.productionSignature = table.concat(products, "|")
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
      if numStorages == 0 then
        debugTrace("Skipping station without cargo capacity: " .. tostring(entry.displayName))
      else
        computeProductionSignature(entry)
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
  if not hasOwn then
    return labels.globalRule
  end
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
  if entry.tradeData and not forceRefresh then
    return entry.tradeData
  end

  local container = entry.id64
  local wares = entry.products or {}
  local map = {}
  local set = {}

  if #wares > 0 then
    for i = 1, #wares do
      local ware = wares[i]
      set[ware] = true
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
  entry.tradeData = {
    map = map,
    set = set,
  }
  return entry.tradeData
end

local function compareSide(source, target)
  if not source and not target then
    return true
  end
  if not source or not target then
    return false
  end
  if source.allowed ~= target.allowed then
    return false
  end
  if source.limitOverride ~= target.limitOverride then
    return false
  end
  if source.limitOverride and (source.limit ~= target.limit) then
    return false
  end
  if source.priceOverride ~= target.priceOverride then
    return false
  end
  if source.priceOverride and (source.price ~= target.price) then
    return false
  end
  if source.hasOwnRule ~= target.hasOwnRule then
    return false
  end
  if source.hasOwnRule and (source.tradeRule ~= target.tradeRule) then
    return false
  end
  return true
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


local function formatSide(info)
  if not info then
    return "-"
  end
  local parts = {}
  parts[#parts + 1] = info.allowed and labels.enabled or labels.disabled
  parts[#parts + 1] = string.format(labels.limit, formatLimit(info.limit, info.limitOverride))
  parts[#parts + 1] = string.format(labels.price, formatPrice(info.price, info.priceOverride))
  parts[#parts + 1] = string.format(labels.rule, formatTradeRuleLabel(info.tradeRule, info.hasOwnRule))
  return table.concat(parts, "\n")
end

local function hasSelection(data)
  for _, value in pairs(data.cloneBuy or {}) do
    if value then
      return true
    end
  end
  for _, value in pairs(data.cloneSell or {}) do
    if value then
      return true
    end
  end
  return false
end

local function updateTargetOptions(data)
  local options = {}
  local total = 0
  local matches = 0
  if (data.selectedSource == nil) then
    data.targetOptions = options
    data.targetCounts = { matches = matches, total = total }
    return
  end
  local sourceEntry = data.selectedSource and data.stations[data.selectedSource]
  local signature = sourceEntry and sourceEntry.productionSignature or nil

  for id, entry in pairs(data.stations) do
    if id ~= data.selectedSource then
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

  data.targetOptions = options
  data.targetCounts = { matches = matches, total = total }

  if data.selectedTarget then
    local present = false
    for _, option in ipairs(options) do
      if option.id == data.selectedTarget then
        present = true
        break
      end
    end
    if not present then
      data.selectedTarget = nil
      data.pendingResetSelections = true
    end
  end
end

local function resetSelections(data, wareList, diffs)
  if not data.pendingResetSelections then
    return
  end
  data.cloneBuy = {}
  data.cloneSell = {}
  for _, ware in ipairs(wareList) do
    local diff = diffs[ware]
    if diff then
      data.cloneBuy[ware] = diff.buy
      data.cloneSell[ware] = diff.sell
    else
      data.cloneBuy[ware] = false
      data.cloneSell[ware] = false
    end
  end
  data.pendingResetSelections = false
end
local function sortWareList(a, b)
  local oa = wareTypeSortOrder[a.type] or 4
  local ob = wareTypeSortOrder[b.type] or 4
  if oa ~= ob then return oa < ob end
  return a.name < b.name
end

local function buildUnion(sourceData, targetData)
  local union = {}
  local list = {}
  if sourceData then
    for ware, info in pairs(sourceData.map) do
      union[ware] = true
      list[#list + 1] = { ware = ware, name = info.name, type = info.type }
    end
  end
  if targetData then
    for ware, info in pairs(targetData.map) do
      if not union[ware] then
        union[ware] = true
        list[#list + 1] = { ware = ware, name = info.name, type = info.type }
      end
    end
  end
  table.sort(list, sortWareList)
  return list
end

local function applyTradeRule(target, ware, sourceSide)
  if sourceSide.hasOwnRule then
    local id = sourceSide.tradeRule
    if id == 0 then
      id = -1
    end
    C.SetContainerTradeRule(target, id, sourceSide.isbuy and "buy" or "sell", ware, true)
  else
    C.SetContainerTradeRule(target, -1, sourceSide.isbuy and "buy" or "sell", ware, false)
  end
end

local function cloneSide(target, ware, sourceSide)
  if sourceSide.allowed ~= nil then
    if sourceSide.isbuy then
      C.SetContainerWareIsBuyable(target, ware, sourceSide.allowed)
    else
      C.SetContainerWareIsSellable(target, ware, sourceSide.allowed)
    end
  end

  if sourceSide.limitOverride then
    if sourceSide.isbuy then
      C.SetContainerBuyLimitOverride(target, ware, sourceSide.limit)
    else
      C.SetContainerSellLimitOverride(target, ware, sourceSide.limit)
    end
  else
    if sourceSide.isbuy then
      C.ClearContainerBuyLimitOverride(target, ware)
    else
      C.ClearContainerSellLimitOverride(target, ware)
    end
  end

  if sourceSide.priceOverride then
    C.SetContainerWarePriceOverride(target, ware, sourceSide.isbuy, sourceSide.price)
  else
    C.ClearContainerWarePriceOverride(target, ware, sourceSide.isbuy)
  end

  applyTradeRule(target, ware, sourceSide)
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

local function applyClone(menu)
  local data = menu.contextMenuData
  if not data then
    return
  end
  local sourceEntry = data.selectedSource and data.stations[data.selectedSource]
  local targetEntry = data.selectedTarget and data.stations[data.selectedTarget]
  if not sourceEntry or not targetEntry then
    data.statusMessage = "Select source and target stations first."
    data.statusColor = Color and Color["text_warning"] or nil
    TradeConfigExchanger.render()
    return
  end

  local sourceData = collectTradeData(sourceEntry)
  local targetData = collectTradeData(targetEntry)
  local wareList = buildUnion(sourceData, targetData)

  local changes = 0
  for _, ware in ipairs(wareList) do
    local cloneBuy = data.cloneBuy and data.cloneBuy[ware]
    local cloneSell = data.cloneSell and data.cloneSell[ware]
    if cloneBuy or cloneSell then
      local sourceInfo = sourceData.map[ware]
      if sourceInfo then
        if not targetData.set[ware] then
          C.AddTradeWare(targetEntry.id64, ware)
          targetData.set[ware] = true
        end
        if cloneBuy then
          cloneSide(targetEntry.id64, ware, sideFromInfo(sourceInfo.buy, true))
          changes = changes + 1
        end
        if cloneSell then
          cloneSide(targetEntry.id64, ware, sideFromInfo(sourceInfo.sell, false))
          changes = changes + 1
        end
      end
    end
  end

  if changes > 0 then
    C.UpdateProductionTradeOffers(targetEntry.id64)
    collectTradeData(targetEntry, true)
    collectTradeData(sourceEntry, true)
    data.statusMessage = string.format("Applied %d setting(s).", changes)
    data.statusColor = Color and Color["text_normal"] or nil
    data.pendingResetSelections = true
  else
    data.statusMessage = "No settings selected to clone."
    data.statusColor = Color and Color["text_warning"] or nil
  end

  TradeConfigExchanger.render()
end

local function renderStorage(row, entry, isSource)
  if (entry == nil) or (row == nil) then
    return
  end
  local idx = isSource and 6 or 12
  row[idx]:createText(overrideIcons[entry.storageLimitOverride], overrideIconsOptions[entry.storageLimitOverride])
  row[idx + 1]:createText(formatLimit(entry.storageLimit, entry.storageLimitOverride), optionsNumber(entry.storageLimitOverride))
end
local function renderOffer(row, offerData, isSource)
  if (offerData == nil) or (not offerData.allowed) or (row == nil) then
    return
  end
  local idx = isSource and 2 or 8
  row[idx]:createText(overrideIcons[offerData.ruleOverride], overrideIconsOptions[offerData.ruleOverride])
  row[idx + 1]:createText(formatTradeRuleLabel(offerData.rule, offerData.ruleOverride), optionsRule(offerData.ruleOverride))
  row[idx + 2]:createText(overrideIcons[offerData.priceOverride], overrideIconsOptions[offerData.priceOverride])
  row[idx + 3]:createText(formatPrice(offerData.price, offerData.priceOverride), optionsNumber(offerData.priceOverride))
  row[idx + 4]:createText(overrideIcons[offerData.limitOverride], overrideIconsOptions[offerData.limitOverride])
  row[idx + 5]:createText(formatLimit(offerData.limit, offerData.limitOverride), optionsNumber(offerData.limitOverride))
end

local function setTableColumnsWidth(tableHandle, main)
  local valueWidth = 120
  local overrideWidth = 30
  local width = Helper.standardTextHeight
  tableHandle:setColWidth(1, width, false)
  for i = 2, 13 do
    if main and i % 2 == 0 or not main and (i <= 7 and i % 2 == 1 or i > 7 and i % 2 == 0) then
      width = width + overrideWidth
      tableHandle:setColWidth(i, overrideWidth, false)
    else
      width = width + valueWidth
      tableHandle:setColWidth(i, valueWidth, true)
    end
  end
  return width
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

  -- each ware will use three rows
  -- first - only ware related
  -- second - purchase order
  -- third - sell order
  -- column 1, thin: only for check boxes, which will contain checkbox for copiyng data

  -- columns 2 - 7: related to left station, except ware name, it's equal for both

  -- column 2: thin
  -- line 1: ware name started column
  -- line 2 and 3:
  --  respective read-only checkbox for use station settings for rule
  -- column 3:
  -- line 1 - continue ware name
  -- line 2 and 3 - appropriate rule name
  -- column 4, thin :
  -- line 1 - continue ware name
  -- line 2 and 3 respective read-only checkbox for automatic pricing
  -- column 5:
  -- line 1 - continue ware name
  -- line 2 and 3 - appropriate price value

  -- column 6 - thin: read-only checkbox
  -- on line 1 - for automatic storage allocation for ware
  -- on line 2 and 3 -
  -- for automatic buy or sell amount
  -- column 7:
  -- line 1 - storage allocation value
  -- line 2 and 3
  -- for value of amount, per line, respectivelly

  -- columns  8 - 13 : related to right station
  -- column 8: thin
  -- line 1:  empty
  -- line 2 and 3:
  --  respective read-only checkbox for use station settings for rule
  -- column 9:
  -- line 1 - empty
  -- line 2 and 3 - appropriate rule name
  -- column 10, thin :
  -- line 1 - empty
  -- line 2 and 3 respective read-only checkbox for automatic pricing
  -- column 11:
  -- line 1 - empty
  -- line 2 and 3 - appropriate price value

  -- column 12 - thin: read-only checkbox
  -- on line 1 - empty
  -- on line 2 and 3 -
  -- for automatic buy or sell amount
  -- column 13:
  -- line 1 - empty
  -- line 2 and 3
  -- for value of amount, per line, respectivelly


  -- header rows are multiplied too
  -- 1 row
  -- 1 column: empty
  -- column 2-7: "Left station"
  -- column 8-13: "Right station"
  -- 2 row
  -- 1 column - empty
  -- column 2 - 5 - "Ware"
  -- column 6 : "Auto"
  -- column 7: "Storage"
  -- column 12: "Auto"
  -- column 13: "Storage"
  -- 3 row:
  -- 1 column - empty
  -- 2-13 : "Buy / Sell Offer"
  -- 4 row:
  -- 1 column - empty
  -- column 2: "Station"
  -- column 3: "Rule"
  -- column 4: "Auto"
  -- column 5: "Price"
  -- column 6: "Auto"
  -- column 7: "Amount"
  -- column 8: "Station"
  -- column 9: "Rule"
  -- column 10: "Auto"
  -- column 11: "Price"
  -- column 12: "Auto"
  -- column 13: "Amount"


  local columns = 13
  local tableMain = frame:addTable(columns, { tabOrder = 1, reserveScrollBar = true, highlightMode = "on", x = Helper.borderSize, y = Helper.borderSize, })
  setTableColumnsWidth(tableMain, true)

  local row = tableMain:addRow(false, { fixed = true })
  row[1]:setColSpan(columns):createText(data.title or "Clone Station Trade Settings", Helper.headerRowCenteredProperties)

  if data.statusMessage then
    local statusRow = tableMain:addRow(false, { fixed = true })
    statusRow[1]:setColSpan(columns):createText(data.statusMessage, { wordwrap = true, color = data.statusColor })
  end


  row = tableMain:addRow(false, { fixed = true })
  row[2]:setColSpan(6):createText("Station One", Helper.headerRowCenteredProperties)
  row[8]:setColSpan(6):createText("Station Two", Helper.headerRowCenteredProperties)
  row = tableMain:addRow(true, { fixed = true })
  row[1]:createText("")
  debugTrace("Rendering source dropdown with " .. tostring(#data.sourceOptions) .. " options, selected: " .. tostring(data.selectedSource))
  row[2]:setColSpan(6):createDropDown(data.sourceOptions, {
    startOption = data.selectedSource or -1,
    active = #data.sourceOptions > 0,
    textOverride = (#data.sourceOptions == 0) and "No player stations" or nil,
  })
  debugTrace("Rendered source dropdown with " .. tostring(#data.sourceOptions) .. " options, selected: " .. tostring(data.selectedSource))
  row[2].handlers.onDropDownConfirmed = function(_, id)
    data.selectedSource = tonumber(id)
    if data.selectedTarget == data.selectedSource then
      data.selectedTarget = nil
    end
    data.pendingResetSelections = true
    updateTargetOptions(data)
    data.statusMessage = nil
    data.clone = {}
    TradeConfigExchanger.render()
  end

  row[8]:setColSpan(6):createDropDown(data.targetOptions, {
    startOption = data.selectedTarget or -1,
    active = #data.targetOptions > 0,
    textOverride = (#data.targetOptions == 0) and "No matching stations" or nil,
  })
  row[8].handlers.onDropDownConfirmed = function(_, id)
    data.selectedTarget = tonumber(id)
    data.pendingResetSelections = true
    data.statusMessage = nil
    data.clone = {}
    TradeConfigExchanger.render()
  end


  row = tableMain:addRow(false, { fixed = true })
  row[2]:setColSpan(4):createText("Ware", Helper.headerRowCenteredProperties)
  row[6]:createText("Ovr", Helper.headerRowCenteredProperties)
  row[7]:createText("Storage allocation", Helper.headerRowCenteredProperties)
  row[12]:createText("Ovr", Helper.headerRowCenteredProperties)
  row[13]:createText("Storage allocation", Helper.headerRowCenteredProperties)
  row = tableMain:addRow(false, { fixed = true })
  row[2]:setColSpan(12):createText("Buy Offer / Sell Offer", Helper.headerRowCenteredProperties)
  row = tableMain:addRow(false, { fixed = true })
  row[2]:createText("Ovr", Helper.headerRowCenteredProperties)
  row[3]:createText("Rule", Helper.headerRowCenteredProperties)
  row[4]:createText("Ovr", Helper.headerRowCenteredProperties)
  row[5]:createText("Price", Helper.headerRowCenteredProperties)
  row[6]:createText("Ovr", Helper.headerRowCenteredProperties)
  row[7]:createText("Amount", Helper.headerRowCenteredProperties)
  row[8]:createText("Ovr", Helper.headerRowCenteredProperties)
  row[9]:createText("Rule", Helper.headerRowCenteredProperties)
  row[10]:createText("Ovr", Helper.headerRowCenteredProperties)
  row[11]:createText("Price", Helper.headerRowCenteredProperties)
  row[12]:createText("Ovr", Helper.headerRowCenteredProperties)
  row[13]:createText("Amount", Helper.headerRowCenteredProperties)

  tableMain:addEmptyRow(Helper.standardTextHeight / 2)

  local sourceEntry = data.selectedSource and data.stations[data.selectedSource]
  local targetEntry = data.selectedTarget and data.stations[data.selectedTarget]
  if sourceEntry == nil then
    debugTrace("No source station selected")
    row = tableMain:addRow(false, { fixed = true })
    row[2]:setColSpan(columns - 1):createText("No source station selected.",
      { color = Color and Color["text_warning"] or nil, halign = "center" })
  else
    debugTrace("Source station: " .. tostring(sourceEntry.displayName) .. " (" .. tostring(sourceEntry.id64) .. ")")
    local sourceData = collectTradeData(sourceEntry)
    local targetData = targetEntry and collectTradeData(targetEntry) or nil
    local wareList = buildUnion(sourceData, targetData)
    debugTrace("Processing " .. tostring(#wareList) .. " wares for comparison")
    local wareType = nil
    if #wareList == 0 then
      row = tableMain:addRow(false, { fixed = true })
      row[2]:setColSpan(columns - 1):createText("No wares available for trade configuration.",
        { color = Color and Color["text_warning"] or nil, halign = "center" })
    else
      for i = 1, #wareList do
        local ware = wareList[i]
        local sourceInfo = ware.ware and sourceData.map[ware.ware]
        local targetInfo = ware.ware and targetData and targetData.map[ware.ware] or nil
        if (sourceInfo or targetInfo) == nil then
          debugTrace("Skipping ware " .. tostring(ware.ware) .. " - no data on either station")
        else
          if wareType ~= sourceInfo.type then
            wareType = sourceInfo.type
            local typeRow = tableMain:addRow(false, { fixed = false, bgColor = Color and Color["row_background_unselectable"] or nil })
            typeRow[2]:setColSpan(columns - 1):createText(string.upper(wareType), { font = Helper.standardFontBold, halign = "center" })
            tableMain:addEmptyRow(Helper.standardTextHeight / 2, { fixed = false })
          end
          if data.clone[ware.ware] == nil then
            data.clone[ware.ware] = { storage = false, buy = false, sell = false }
          end
          local row = tableMain:addRow(true, { fixed = false })
          row[1]:createCheckBox(data.clone[ware.ware].storage, {
            active = sourceInfo ~= nil and targetInfo ~= nil,
          })
          row[1].handlers.onClick = function(_, checked)
            local propagate = data.clone[ware.ware].storage == data.clone[ware.ware].buy and data.clone[ware.ware].storage == data.clone[ware.ware].sell
            data.clone[ware.ware].storage = checked
            if propagate then
              data.clone[ware.ware].buy = checked
              data.clone[ware.ware].sell = checked
            end
            debugTrace("Set clone for ware " .. tostring(ware.ware) .. " to " .. tostring(checked))
            data.statusMessage = nil
            TradeConfigExchanger.render()
          end
          row[2]:setColSpan(4):createText(ware.name, wareNameProperties)
          renderStorage(row, sourceInfo, true)
          if targetInfo then
            renderStorage(row, targetInfo, false)
          end
          local row = tableMain:addRow(true, { fixed = false })
          row[1]:createCheckBox(data.clone[ware.ware].buy, {
            active = sourceInfo ~= nil and targetInfo ~= nil,
          })
          row[1].handlers.onClick = function(_, checked)
            data.clone[ware.ware].buy = checked
            debugTrace("Set clone for ware " .. tostring(ware.ware) .. " buy offer to " .. tostring(checked))
            data.statusMessage = nil
            TradeConfigExchanger.render()
          end
          if sourceInfo.buy and sourceInfo.buy.allowed then
            renderOffer(row, sourceInfo.buy, true)
          else
            row[2]:setColSpan(6):createText("No buy offer", { halign = "center" })
          end
          if targetInfo then
            if targetInfo.buy and targetInfo.buy.allowed then
              renderOffer(row, targetInfo.buy, false)
            else
              row[8]:setColSpan(6):createText("No buy offer", { halign = "center" })
            end
          end
          local row = tableMain:addRow(true, { fixed = false })
          row[1]:createCheckBox(data.clone[ware.ware].sell, {
            active = sourceInfo ~= nil and targetInfo ~= nil,
          })
          row[1].handlers.onClick = function(_, checked)
            data.clone[ware.ware].sell = checked
            debugTrace("Set clone for ware " .. tostring(ware.ware) .. " sell offer to " .. tostring(checked))
            data.statusMessage = nil
            TradeConfigExchanger.render()
          end
          if sourceInfo.sell and sourceInfo.sell.allowed then
            renderOffer(row, sourceInfo.sell, true)
          else
            row[2]:setColSpan(6):createText("No sell offer", { halign = "center" })
          end
          if targetInfo then
            if targetInfo.sell and targetInfo.sell.allowed then
              renderOffer(row, targetInfo.sell, false)
            else
              row[8]:setColSpan(6):createText("No sell offer", { halign = "center" })
            end
          end
        end
        tableMain:addEmptyRow(Helper.standardTextHeight / 2, { fixed = false })
      end
    end
  end

  tableMain:setSelectedCol(2)
  tableMain.properties.maxVisibleHeight = math.min(tableMain:getFullHeight(), data.height - Helper.borderSize * 2)
  local tableButtons = frame:addTable(columns,
    { tabOrder = 2, reserveScrollBar = false, highlightMode = "off", x = Helper.borderSize, y = tableMain.properties.maxVisibleHeight + Helper.borderSize * 2 })
  setTableColumnsWidth(tableButtons, false)
  row = tableButtons:addRow(true, { fixed = true })
  row[5]:setColSpan(2):createButton({
    active = function()
      return hasSelection(data) and data.selectedSource ~= nil and data.selectedTarget ~= nil
    end
  }):setText(labels.cloneButton .. "  \27[widget_arrow_right_01]\27X", { halign = "center" })
  row[5].handlers.onClick = function()
    if hasSelection(data) then
      applyClone(menu)
    end
  end
  row[9]:setColSpan(2):createButton({
    active = function()
      return hasSelection(data) and data.selectedSource ~= nil and data.selectedTarget ~= nil
    end
  }):setText("\27[widget_arrow_left_01]\27X  " .. labels.cloneButton, { halign = "center" })
  row[9].handlers.onClick = function()
    if hasSelection(data) then
      applyClone(menu)
    end
  end
  row[12]:setColSpan(2):createButton({}):setText(labels.cancelButton, { halign = "center" })
  row[12].handlers.onClick = function()
    menu.closeContextMenu()
  end
  tableButtons:setSelectedCol(12)

  frame.properties.width = tableMain.properties.width + Helper.borderSize * 2
  frame.properties.height = tableMain.properties.maxVisibleHeight + tableButtons:getFullHeight() + Helper.borderSize * 3

  frame.properties.y = math.floor((Helper.viewHeight - frame.properties.height) / 2)
  frame.properties.x = math.floor((Helper.viewWidth - frame.properties.width) / 2)

  frame:display()
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
    height = Helper.scaleY(600),
    xoffset = Helper.viewWidth / 2 - Helper.scaleX(450),
    yoffset = Helper.viewHeight / 6,
    requireMatch = true,
    cloneBuy = {},
    cloneSell = {},
    pendingResetSelections = true,
  }

  data.stations, data.sourceOptions = buildStationCache()
  data.targetOptions = {}

  data.selectedSource = nil
  data.selectedTarget = nil

  -- dbg.waitIDE()
  -- debugTrace("BreakPoint")
  -- dbg.breakHere()
  -- debugTrace("BreakPoint")

  updateTargetOptions(data)

  menu.contextMenuMode = data.mode
  menu.contextMenuData = data

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
