local ffi = require("ffi")
local C = ffi.C

ffi.cdef[[
  typedef uint64_t UniverseID;
  typedef int32_t TradeRuleID;

  const char* GetComponentName(UniverseID componentid);
  const char* GetObjectIDCode(UniverseID objectid);

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
  autoLimit = "Auto",
  overrideTag = "Override",
  cloneButton = "Clone",
  cancelButton = "Cancel",
  globalRule = "Global rule",
}


TradeConfigExchanger.labels = labels


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


local function getStationName(shipId)
  if shipId == 0 then
    return "Unknown"
  end
  local name = GetComponentData(ConvertStringToLuaID(tostring(shipId)), "name")
  local idCode = ffi.string(C.GetObjectIDCode(shipId))
  return string.format("%s (%s)", name, idCode)
end

local function centerFrameVertically(frame)
  frame.properties.height = frame:getUsedHeight() + Helper.borderSize
  if (frame.properties.height > Helper.viewHeight ) then
    frame.properties.y = Helper.borderSize
    frame.properties.height = Helper.viewHeight - 2 * Helper.borderSize
  else
    frame.properties.y = (Helper.viewHeight - frame.properties.height) / 2
  end
end

function TradeConfigExchanger.alertMessage(options)
  local menu = TradeConfigExchanger.mapMenu
  if type(menu) ~= "table" or type(menu.closeContextMenu) ~= "function" then
    debugTrace("alertMessage: Invalid menu instance")
    return false, "Map menu instance is not available"
  end
  if type(Helper) ~= "table" then
    debugTrace("alertMessage: Helper UI utilities are not available")
    return false, "Helper UI utilities are not available"
  end

  if type(options) ~= "table" then
    return false, "Options parameter is not a table"
  end

  if options.title == nil then
    return false, "Title option is required"
  end

  if options.message == nil then
    return false, "Message option is required"
  end

  local width = options.width or Helper.scaleX(400)
  local xoffset = options.xoffset or (Helper.viewWidth - width) / 2
  local yoffset = options.yoffset or Helper.viewHeight / 2
  local okLabel = options.okLabel or ReadText(1001, 14)

  local title = options.title
  local message = options.message

  menu.closeContextMenu()

  menu.contextMenuMode = "tce_alert"
  menu.contextMenuData = {
    mode = "tce_alert",
    width = width,
    xoffset = xoffset,
    yoffset = yoffset,
  }

  local contextLayer = menu.contextFrameLayer or 2

  menu.contextFrame = Helper.createFrameHandle(menu, {
    x = xoffset - 2 * Helper.borderSize,
    y = yoffset,
    width = width + 2 * Helper.borderSize,
    layer = contextLayer,
    standardButtons = { close = true },
    closeOnUnhandledClick = true,
  })
  local frame = menu.contextFrame
  frame:setBackground("solid", { color = Color["frame_background_semitransparent"] })

  local ftable = frame:addTable(5, { tabOrder = 1, x = Helper.borderSize, y = Helper.borderSize, width = width, reserveScrollBar = false, highlightMode = "off" })

  local headerRow = ftable:addRow(false, { fixed = true })
  headerRow[1]:setColSpan(5):createText(title, copyAndEnrichTable(Helper.headerRowCenteredProperties, { color = Color["text_warning"] }))

  ftable:addEmptyRow(Helper.standardTextHeight / 2)

  local messageRow = ftable:addRow(false, { fixed = true })
  messageRow[1]:setColSpan(5):createText(message, {
    halign = "center",
    wordwrap = true,
    color = Color["text_normal"]
  })

  ftable:addEmptyRow(Helper.standardTextHeight / 2)

  local buttonRow = ftable:addRow(true, { fixed = true })
  buttonRow[3]:createButton():setText(okLabel, { halign = "center" })
  buttonRow[3].handlers.onClick = function ()
    local shouldClose = true
    if shouldClose then
      menu.closeContextMenu("back")
    end
  end
  ftable:setSelectedCol(3)

  centerFrameVertically(frame)

  frame:display()

  return true
end

function TradeConfigExchanger.showTargetAlert()
  local options = {}
  options.title = ReadText(1972092408, 10310)
  options.message = ReadText(1972092408, 10311)
  TradeConfigExchanger.alertMessage(options)
end


function TradeConfigExchanger.cloneOrdersConfirm()
  local menu = TradeConfigExchanger.mapMenu
  if type(menu) ~= "table" or type(menu.closeContextMenu) ~= "function" then
    debugTrace("alertMessage: Invalid menu instance")
    return false, "Map menu instance is not available"
  end
  if type(Helper) ~= "table" then
    debugTrace("alertMessage: Helper UI utilities are not available")
    return false, "Helper UI utilities are not available"
  end

  local sourceId = TradeConfigExchanger.sourceId
  local targetIds = TradeConfigExchanger.targetIds

  local sourceName = getStationName(sourceId)
  local title = ReadText(1972092408, 10320)
  local targetsTitle = ReadText(1972092408, 10322)

  local width = Helper.scaleX(910)
  local xoffset = (Helper.viewWidth - width) / 2
  local yoffset = Helper.viewHeight / 2

  menu.closeContextMenu()

  menu.contextMenuMode = "tce_clone_confirm"
  menu.contextMenuData = {
    mode = "tce_clone_confirm",
    width = width,
    xoffset = xoffset,
    yoffset = yoffset,
  }

  local contextLayer = menu.contextFrameLayer or 2

  menu.contextFrame = Helper.createFrameHandle(menu, {
    x = xoffset - 2 * Helper.borderSize,
    y = yoffset,
    width = width + 2 * Helper.borderSize,
    layer = contextLayer,
    standardButtons = { close = true },
    closeOnUnhandledClick = true,
  })
  local frame = menu.contextFrame
  frame:setBackground("solid", { color = Color["frame_background_semitransparent"] })

  local ftable = frame:addTable(13, { tabOrder = 1, x = Helper.borderSize, y = Helper.borderSize, width = width, reserveScrollBar = false, highlightMode = "off" })

  local headerRow = ftable:addRow(false, { fixed = true })
  headerRow[1]:setColSpan(13):createText(title, Helper.titleTextProperties)
  ftable:addEmptyRow(Helper.standardTextHeight / 2)
  local headerRow = ftable:addRow(false, { fixed = true })
  headerRow[1]:createText(ReadText(1972092408, 10321), Helper.headerRow1Properties)
  local sourceNameProperties = copyAndEnrichTable(Helper.headerRowCenteredProperties, {color = Color["text_player_current"]})
  headerRow[2]:setColSpan(7):createText(sourceName, sourceNameProperties)
  headerRow[9]:setColSpan(5):createText(targetsTitle, Helper.headerRowCenteredProperties)
  ftable:addEmptyRow(Helper.standardTextHeight / 2)


  local headerRow = ftable:addRow(false, { fixed = true })
  headerRow[1]:setColSpan(8):createText(ReadText(1001, 3225), Helper.headerRowCenteredProperties) -- Order Queue

  local tableHeaderRow = ftable:addRow(false, { fixed = true })
  tableHeaderRow[1]:createText(ReadText(1001, 7802), Helper.headerRow1Properties) -- Orders
  tableHeaderRow[2]:setColSpan(2):createText(ReadText(1001, 45), Helper.headerRow1Properties) -- Ware
  tableHeaderRow[4]:createText(ReadText(1001, 1202), Helper.headerRow1Properties) -- Amount
  tableHeaderRow[5]:createText(ReadText(1001, 2808), Helper.headerRow1Properties) -- Price
  tableHeaderRow[6]:setColSpan(3):createText(ReadText(1041, 10049), Helper.headerRow1Properties) -- Location
  tableHeaderRow[9]:setColSpan(5):createText(ReadText(1001, 2809), Helper.headerRow1Properties) -- Name

  ftable:addEmptyRow(Helper.standardTextHeight / 2)

  local orders = TradeConfigExchanger.getStandingOrders(sourceId)
  local cargoCapacity = TradeConfigExchanger.getCargoCapacity(sourceId)
  local lineCount = math.max(#orders, #targetIds)
  local instance = "left"
  menu.infoTableData[instance] = {}
  menu.infoTableData[instance].orders = {}
  for i = 1, lineCount do
    local row = ftable:addRow(false)
    if i <= #orders then
      local order = orders[i]
      menu.infoTableData[instance].orders[i] = {}
      local orderparams = GetOrderParams(sourceId, order.idx)
      menu.infoTableData[instance].orders[i].params = orderparams
      row[1]:createText(TradeConfigExchanger.validOrders[order.order], {halign = "left"})
      row[2]:setColSpan(2):createText(GetWareData(orderparams[1].value, "name"), {halign = "left"})
      local amount = orderparams[5].value
      if order.order == "SingleSell" then
        amount = cargoCapacity - amount
      end
      local percentage = (cargoCapacity > 0) and (amount * 100 / cargoCapacity ) or 0
      row[4]:createText(string.format("%.2f%%", percentage), {halign = "right"})
      row[5]:createText(orderparams[7].value, {halign = "right"})
      local locations = orderparams[4].value
      if type(locations) == "table" and #locations >= 1 then
        local locId = toUniverseId(locations[1])
        local locName = GetComponentData(ConvertStringToLuaID(tostring(locId)), "name")
        if (#locations > 1) then
          locName = locName .. ", ..."
        end
        row[6]:setColSpan(3):createText(locName )
      else
        row[6]:setColSpan(3):createText("-", {halign = "center"})
      end
    else
      row[1]:setColSpan(8):createText("", {halign = "left"})
    end
    if i <= #targetIds then
      local targetName = getStationName(targetIds[i])
      row[9]:setColSpan(5):createText(tostring(targetName), {halign = "left", color = Color["text_player_current"]})
    else
      row[9]:setColSpan(5):createText("", {halign = "center"})
    end
  end

  ftable:addEmptyRow(Helper.standardTextHeight / 2)

  local buttonRow = ftable:addRow(true, { fixed = true })
  buttonRow[10]:setColSpan(2):createButton():setText(ReadText(1001, 2821), { halign = "center" })
  buttonRow[10].handlers.onClick = function ()
    TradeConfigExchanger.cloneOrdersExecute()
    menu.closeContextMenu("back")
  end
  buttonRow[12]:setColSpan(2):createButton():setText(ReadText(1001, 64), { halign = "center" })
  buttonRow[12].handlers.onClick = function ()
    TradeConfigExchanger.cloneOrdersCancel()
    menu.closeContextMenu("back")
  end
  buttonRow[1]:setColSpan(2):createButton():setText(ReadText(1972092408, 10201), { halign = "center" })
  buttonRow[1].handlers.onClick = function ()
    TradeConfigExchanger.clearSource()
    menu.closeContextMenu("back")
  end

  buttonRow[4]:setColSpan(2):createButton():setText('Add Location', { halign = "center" })
  buttonRow[4].handlers.onClick = function ()
    return TradeConfigExchanger.SetOrderParam(1, 4, 1, nil, instance)
  end
  ftable:setSelectedCol(12)

  centerFrameVertically(frame)

  frame:display()
end


local function computeProductionDetails(entry)
  if entry.productionSignature then
    return
  end

  local macros = {}
  local modules = GetProductionModules(entry.id64) or {}
  for _, module in ipairs(modules) do
    local macro = GetComponentData(module, "macro")
    if type(macro) == "string" and macro ~= "" then
      table.insert(macros, macro)
    end
  end
  table.sort(macros)
  entry.productionMacros = macros
  entry.productionSignature = table.concat(macros, "|")

  local products = GetComponentData(entry.id, "products") or {}
  table.sort(products)
  entry.productionProducts = products
  entry.productionProductNames = {}
  for _, ware in ipairs(products) do
    local name = GetWareData(ware, "name")
    table.insert(entry.productionProductNames, name)
  end
end

local function buildStationCache()
  local stations = {}
  local options = {}
  local list = GetContainedStationsByOwner("player", nil, true) or {}

  for _, station in ipairs(list) do
    local id = toIdString(station)
    local id64 = toUniverseId(station)
    if id and id64 and (id64 ~= 0) then
      local entry = {
        id = id,
        id64 = id64,
      }
      entry.displayName = getStationName(entry)
      computeProductionDetails(entry)
      stations[id] = entry
      table.insert(options, { id = id, text = entry.displayName })
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
  local tradewares = GetComponentData(entry.id, "tradewares") or {}
  local map = {}
  local set = {}

  for _, ware in ipairs(tradewares) do
    set[ware] = true
    local name = GetWareData(ware, "name")

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
      buy = {
        allowed = buyAllowed,
        limit = buyLimit,
        limitOverride = buyOverride,
        price = buyPrice,
        priceOverride = buyPriceOverride,
        tradeRule = buyRuleId,
        hasOwnRule = buyOwnRule,
      },
      sell = {
        allowed = sellAllowed,
        limit = sellLimit,
        limitOverride = sellOverride,
        price = sellPrice,
        priceOverride = sellPriceOverride,
        tradeRule = sellRuleId,
        hasOwnRule = sellOwnRule,
      }
    }
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
    return labels.autoLimit
  end
  return string.format("%s (%s)", ConvertIntegerString(value, true, 3, true, true), labels.overrideTag)
end

local function formatPrice(value, override)
  local amount = ConvertMoneyString(value, true, true, 2, true)
  if override then
    return string.format("%s (%s)", amount, labels.overrideTag)
  end
  return amount
end

local function formatSide(info)
  if not info then
    return "-"
  end
  local parts = {}
  parts[#parts+1] = info.allowed and labels.enabled or labels.disabled
  parts[#parts+1] = string.format(labels.limit, formatLimit(info.limit, info.limitOverride))
  parts[#parts+1] = string.format(labels.price, formatPrice(info.price, info.priceOverride))
  parts[#parts+1] = string.format(labels.rule, formatTradeRuleLabel(info.tradeRule, info.hasOwnRule))
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
  local sourceEntry = data.selectedSource and data.stations[data.selectedSource]
  local signature = sourceEntry and sourceEntry.productionSignature or nil

  for id, entry in pairs(data.stations) do
    if id ~= data.selectedSource then
      total = total + 1
      local qualifies = (not data.requireMatch) or (signature == nil) or (entry.productionSignature == signature)
      if qualifies then
        matches = matches + 1
        options[#options+1] = { id = id, text = entry.displayName }
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

local function buildUnion(sourceData, targetData)
  local union = {}
  local list = {}
  if sourceData then
    for ware, info in pairs(sourceData.map) do
      union[ware] = true
      list[#list+1] = { ware = ware, name = info.name }
    end
  end
  if targetData then
    for ware, info in pairs(targetData.map) do
      if not union[ware] then
        union[ware] = true
        list[#list+1] = { ware = ware, name = info.name }
      end
    end
  end
  table.sort(list, function(a, b)
    return a.name < b.name
  end)
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

function TradeConfigExchanger.render()
  local menu = TradeConfigExchanger.mapMenu
  if type(menu) ~= "table" or type(Helper) ~= "table" then
    debugTrace("TradeConfigExchanger: Render: Invalid menu instance or Helper UI utilities are not available")
    return
  end
  local data = menu.contextMenuData
  if not data or data.mode ~= "trade_clone_exchanger" then
    return
  end

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

  local columns = 7
  local tableHandle = frame:addTable(columns, { tabOrder = 1, reserveScrollBar = true, highlightMode = "off" })
  tableHandle:setColWidthPercent(1, 18)
  tableHandle:setColWidthPercent(2, 17)
  tableHandle:setColWidthPercent(3, 17)
  tableHandle:setColWidthPercent(4, 7)
  tableHandle:setColWidthPercent(5, 17)
  tableHandle:setColWidthPercent(6, 17)
  tableHandle:setColWidthPercent(7, 7)

  local row = tableHandle:addRow(false, { fixed = true })
  row[1]:setColSpan(columns):createText(data.title or "Clone Station Trade Settings", Helper.headerRowCenteredProperties)

  if data.statusMessage then
    local statusRow = tableHandle:addRow(false, { fixed = true })
    statusRow[1]:setColSpan(columns):createText(data.statusMessage, { wordwrap = true, color = data.statusColor })
  end

  row = tableHandle:addRow(false, { fixed = true })
  row[1]:setColSpan(2):createText("Source station")
  row[3]:setColSpan(4):createDropDown(data.sourceOptions, {
    startOption = data.selectedSource,
    active = #data.sourceOptions > 0,
    textOverride = (#data.sourceOptions == 0) and "No player stations" or nil,
  })
  row[3].handlers.onDropDownConfirmed = function(_, id)
    data.selectedSource = id
    data.pendingResetSelections = true
    updateTargetOptions(data)
    data.statusMessage = nil
    TradeConfigExchanger.render()
  end

  row = tableHandle:addRow(true, { fixed = true })
  row[1]:setColSpan(2):createText("Match production modules")
  row[3]:createCheckBox(data.requireMatch ~= false, { height = Helper.standardButtonHeight, active = data.selectedSource ~= nil })
  row[3].handlers.onClick = function(_, checked)
    data.requireMatch = checked
    updateTargetOptions(data)
    data.pendingResetSelections = true
    TradeConfigExchanger.render()
  end

  row = tableHandle:addRow(false, { fixed = true })
  row[1]:setColSpan(2):createText("Target station")
  row[3]:setColSpan(4):createDropDown(data.targetOptions, {
    startOption = data.selectedTarget,
    active = #data.targetOptions > 0,
    textOverride = (#data.targetOptions == 0) and "No matching stations" or nil,
  })
  row[3].handlers.onDropDownConfirmed = function(_, id)
    data.selectedTarget = id
    data.pendingResetSelections = true
    data.statusMessage = nil
    TradeConfigExchanger.render()
  end

  if data.targetCounts then
    local infoRow = tableHandle:addRow(false, { fixed = true })
    local text
    if data.targetCounts.total == 0 then
      text = "No other player stations available."
    else
      text = string.format("%d matching station(s) out of %d.", data.targetCounts.matches, data.targetCounts.total)
    end
    infoRow[1]:setColSpan(columns):createText(text, { color = (data.targetCounts.matches > 0) and nil or (Color and Color["text_warning"]) })
  end

  local sourceEntry = data.selectedSource and data.stations[data.selectedSource]
  local targetEntry = data.selectedTarget and data.stations[data.selectedTarget]
  if sourceEntry then
    local sourceRow = tableHandle:addRow(false, { fixed = true })
    local summary = #sourceEntry.productionProductNames > 0 and table.concat(sourceEntry.productionProductNames, ", ") or "No production modules"
    sourceRow[1]:setColSpan(columns):createText(string.format("Source produces: %s", summary), { wordwrap = true })
  end
  if targetEntry then
    local targetRow = tableHandle:addRow(false, { fixed = true })
    local summary = #targetEntry.productionProductNames > 0 and table.concat(targetEntry.productionProductNames, ", ") or "No production modules"
    targetRow[1]:setColSpan(columns):createText(string.format("Target produces: %s", summary), { wordwrap = true })
  end

  tableHandle:addEmptyRow(Helper.standardTextHeight / 2)

  row = tableHandle:addRow(false, { fixed = true, bgColor = Color and Color["row_background_blue"] or nil })
  row[1]:createText("Ware", Helper.headerRowCenteredProperties)
  row[2]:createText("Source Buy", Helper.headerRowCenteredProperties)
  row[3]:createText("Target Buy", Helper.headerRowCenteredProperties)
  row[4]:createText("Copy", Helper.headerRowCenteredProperties)
  row[5]:createText("Source Sell", Helper.headerRowCenteredProperties)
  row[6]:createText("Target Sell", Helper.headerRowCenteredProperties)
  row[7]:createText("Copy", Helper.headerRowCenteredProperties)

  local diffs = {}
  local wareList = {}

  if sourceEntry and targetEntry then
    local sourceData = collectTradeData(sourceEntry)
    local targetData = collectTradeData(targetEntry)
    wareList = buildUnion(sourceData, targetData)

    for _, ware in ipairs(wareList) do
      local sourceInfo = sourceData.map[ware]
      local targetInfo = targetData.map[ware]
      local diffBuy = not compareSide(sourceInfo and sourceInfo.buy, targetInfo and targetInfo.buy)
      local diffSell = not compareSide(sourceInfo and sourceInfo.sell, targetInfo and targetInfo.sell)
      diffs[ware] = { buy = diffBuy, sell = diffSell }

      local rowData = tableHandle:addRow(true, { rowData = ware })
      rowData[1]:createText(sourceInfo and sourceInfo.name or (targetInfo and targetInfo.name) or ware)
      rowData[2]:createText(formatSide(sourceInfo and sourceInfo.buy), { wordwrap = true, color = diffBuy and (Color and Color["text_warning"]) or nil })
      rowData[3]:createText(formatSide(targetInfo and targetInfo.buy), { wordwrap = true, color = diffBuy and (Color and Color["text_warning"]) or nil })
      rowData[4]:createCheckBox(data.cloneBuy[ware], { active = sourceInfo ~= nil })
      rowData[4].handlers.onClick = function(_, checked)
        data.cloneBuy[ware] = checked or nil
      end
      rowData[5]:createText(formatSide(sourceInfo and sourceInfo.sell), { wordwrap = true, color = diffSell and (Color and Color["text_warning"]) or nil })
      rowData[6]:createText(formatSide(targetInfo and targetInfo.sell), { wordwrap = true, color = diffSell and (Color and Color["text_warning"]) or nil })
      rowData[7]:createCheckBox(data.cloneSell[ware], { active = sourceInfo ~= nil })
      rowData[7].handlers.onClick = function(_, checked)
        data.cloneSell[ware] = checked or nil
      end
    end
  else
    local infoRow = tableHandle:addRow(false, { fixed = true })
    infoRow[1]:setColSpan(columns):createText("Select source and target stations to view trade settings.", { wordwrap = true, color = Color and Color["text_warning"] or nil })
  end

  resetSelections(data, wareList, diffs)

  tableHandle:addEmptyRow(Helper.standardTextHeight / 2)

  row = tableHandle:addRow(true, { fixed = true })
  row[3]:setColSpan(2):createButton({ active = function()
    return hasSelection(data) and data.selectedSource ~= nil and data.selectedTarget ~= nil
  end }):setText(labels.cloneButton, { halign = "center" })
  row[3].handlers.onClick = function()
    if hasSelection(data) then
      applyClone(menu)
    end
  end
  row[5]:setColSpan(2):createButton({  }):setText(labels.cancelButton, { halign = "center" })
  row[5].handlers.onClick = function()
    menu.closeContextMenu()
  end
  tableHandle:setSelectedCol(5)

  frame.properties.height = math.min(Helper.viewHeight - frame.properties.y, frame:getUsedHeight() + Helper.borderSize)
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
    width = Helper.scaleX(900),
    xoffset = Helper.viewWidth / 2 - Helper.scaleX(450),
    yoffset = Helper.viewHeight / 6,
    requireMatch = true,
    cloneBuy = {},
    cloneSell = {},
    pendingResetSelections = true,
  }

  data.stations, data.sourceOptions = buildStationCache()

  data.selectedSource =  nil
  data.selectedTarget = nil

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
