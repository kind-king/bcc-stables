local Core = exports.vorp_core:GetCore()
local BccUtils = exports['bcc-utils'].initiate()
local CooldownData = {}

if Config.discord.active == true then
    Discord = BccUtils.Discord.setup(Config.discord.webhookURL, Config.discord.title, Config.discord.avatar)
end

function LogToDiscord(name, description, embeds)
    if Config.discord.active == true then
        Discord:sendMessage(name, description, embeds)
    end
end

Core.Callback.Register('bcc-stables:BuyHorse', function(source, cb, data)
    local src = source
    local user = Core.getUser(src)
    if not user then
        print('User not found for source:', src)
        return cb(false)
    end
    local character = user.getUsedCharacter
    local charid = character.charIdentifier

    local maxHorses = tonumber(Config.maxPlayerHorses)
    if data.isTrainer then
        maxHorses = tonumber(Config.maxTrainerHorses)
    end

    local horses = MySQL.query.await('SELECT * FROM `player_horses` WHERE `charid` = ? AND `dead` = ?', { charid, 0 })
    if #horses >= maxHorses then
        Core.NotifyRightTip(src, _U('horseLimit') .. maxHorses .. _U('horses'), 4000)
        cb(false)
        return
    end

    local model = data.ModelH
    for _, horseCfg in pairs(Horses) do
        for color, colorCfg in pairs(horseCfg.colors) do
            if color == model then
                if data.IsCash then
                    if character.money >= colorCfg.cashPrice then
                        cb(true)
                    else
                        Core.NotifyRightTip(src, _U('shortCash'), 4000)
                        cb(false)
                    end
                else
                    if character.gold >= colorCfg.goldPrice then
                        cb(true)
                    else
                        Core.NotifyRightTip(src, _U('shortGold'), 4000)
                        cb(false)
                    end
                end
            end
        end
    end
end)

Core.Callback.Register('bcc-stables:RegisterHorse', function(source, cb, data)
    local src = source
    local user = Core.getUser(src)
    if not user then
        print('User not found for source:', src)
        return cb(false)
    end
    local character = user.getUsedCharacter
    local charid = character.charIdentifier

    local maxHorses = tonumber(Config.maxPlayerHorses)
    if data.isTrainer then
        maxHorses = tonumber(Config.maxTrainerHorses)
    end

    local horses = MySQL.query.await('SELECT * FROM `player_horses` WHERE `charid` = ? AND `dead` = ?', { charid, 0 })
    if #horses >= maxHorses then
        Core.NotifyRightTip(src, _U('horseLimit') .. maxHorses .. _U('horses'), 4000)
        cb(false)
        return
    end

    if data.IsCash and data.origin == 'tameHorse' then
        if character.money >= Config.regCost then
            cb(true)
        else
            Core.NotifyRightTip(src, _U('shortCash'), 4000)
            cb(false)
        end
    end
end)

RegisterNetEvent('bcc-stables:BuyTack', function(data)
    local src = source
    local user = Core.getUser(src)
    if not user then
        print('User not found for source:', src)
        return
    end
    local character = user.getUsedCharacter

    if tonumber(data.cashPrice) > 0 and tonumber(data.goldPrice) > 0 then
        if tonumber(data.currencyType) == 0 then
            if character.money >= data.cashPrice then
                character.removeCurrency(0, data.cashPrice)
            else
                Core.NotifyRightTip(src, _U('shortCash'), 4000)
                return
            end
        else
            if character.gold >= data.goldPrice then
                character.removeCurrency(1, data.goldPrice)
            else
                Core.NotifyRightTip(src, _U('shortGold'), 4000)
                return
            end
        end
        Core.NotifyRightTip(src, _U('purchaseSuccessful'), 4000)
    end
    TriggerClientEvent('bcc-stables:SaveComps', src)
end)

Core.Callback.Register('bcc-stables:SaveNewHorse', function(source, cb, data)
    local src = source
    local user = Core.getUser(src)
    if not user then
        print('User not found for source:', src)
        return cb(false)
    end
    local character = user.getUsedCharacter
    local identifier = character.identifier
    local charid = character.charIdentifier
    local model = data.ModelH

    for _, horseCfg in pairs(Horses) do
        for color, colorCfg in pairs(horseCfg.colors) do
            if color == model then
                if (data.IsCash) and (character.money >= colorCfg.cashPrice) then
                    character.removeCurrency(0, colorCfg.cashPrice)
                elseif (not data.IsCash) and (character.gold >= colorCfg.goldPrice) then
                    character.removeCurrency(1, colorCfg.goldPrice)
                else
                    if data.IsCash then
                        Core.NotifyRightTip(src, _U('shortCash'), 4000)
                    elseif not data.IsCash then
                        Core.NotifyRightTip(src, _U('shortGold'), 4000)
                    end
                    return cb(true)
                end
                MySQL.query.await('INSERT INTO `player_horses` (identifier, charid, name, model, gender, captured) VALUES (?, ?, ?, ?, ?, ?)',
                { identifier, charid, tostring(data.name), data.ModelH, data.gender,  data.captured })

                LogToDiscord(charid, _U('discordHorsePurchased'))
                break
            end
        end
    end
    cb(true)
end)

Core.Callback.Register('bcc-stables:SaveTamedHorse', function(source, cb, data)
    local src = source
    local user = Core.getUser(src)
    if not user then
        print('User not found for source:', src)
        return cb(false)
    end
    local character = user.getUsedCharacter
    local identifier = character.identifier
    local charid = character.charIdentifier

    if data.IsCash and data.origin == 'tameHorse' then
        if character.money >= Config.regCost then
            character.removeCurrency(0, Config.regCost)
        else
            Core.NotifyRightTip(src, _U('shortCash'), 4000)
            return cb(false)
        end
    end
    MySQL.query.await('INSERT INTO `player_horses` (identifier, charid, name, model, gender, captured) VALUES (?, ?, ?, ?, ?, ?)',
    { identifier, charid, tostring(data.name), data.ModelH, data.gender,  data.captured })

    LogToDiscord(charid, _U('discordTamedPurchased'))
    cb(true)
end)

Core.Callback.Register('bcc-stables:UpdateHorseName', function(source, cb, data)
    local src = source
    local user = Core.getUser(src)
    if not user then
        print('User not found for source:', src)
        return cb(false)
    end
    local character = user.getUsedCharacter
    local identifier = character.identifier
    local charid = character.charIdentifier

    MySQL.query.await('UPDATE `player_horses` SET `name` = ? WHERE `id` = ? AND `identifier` = ? AND `charid` = ?',
    { data.name, data.horseId, identifier, charid })
    cb(true)
end)

RegisterServerEvent('bcc-stables:UpdateHorseXp', function(Xp, horseId)
    local src = source
    local user = Core.getUser(src)
    if not user then
        print('User not found for source:', src)
        return
    end
    local character = user.getUsedCharacter
    local identifier = character.identifier
    local charid = character.charIdentifier

    MySQL.query.await('UPDATE `player_horses` SET `xp` = ? WHERE `id` = ? AND `identifier` = ? AND `charid` = ?',
    { Xp, horseId, identifier, charid })

    LogToDiscord(charid, _U('discordHorseXPGain'))
end)

RegisterServerEvent('bcc-stables:SaveHorseStatsToDb', function(data, horseId)
    local src = source
    local user = Core.getUser(src)
    if not user then
        print('User not found for source:', src)
        return
    end
    local character = user.getUsedCharacter
    local identifier = character.identifier
    local charid = character.charIdentifier

    MySQL.query.await('UPDATE `player_horses` SET `health` = ?, `stamina` = ? WHERE id = ? AND `identifier` = ? AND `charid` = ?',
    { data.health, data.stamina, horseId, identifier, charid })
end)

RegisterServerEvent('bcc-stables:SelectHorse', function(data)
    local src = source
    local user = Core.getUser(src)
    if not user then
        print('User not found for source:', src)
        return
    end
    local character = user.getUsedCharacter
    local identifier = character.identifier
    local charid = character.charIdentifier
    local id = tonumber(data.horseId)

    local horses = MySQL.query.await('SELECT * FROM `player_horses` WHERE `charid` = ? AND `identifier` = ? AND `dead` = ?',
    { charid, identifier, 0 })
    for i = 1, #horses do
        local horseId = horses[i].id
        MySQL.query.await('UPDATE `player_horses` SET `selected` = ? WHERE `charid` = ? AND `identifier` = ? AND `id` = ?',
        { 0, charid, identifier, horseId })
        if horses[i].id == id then
            MySQL.query.await('UPDATE `player_horses` SET `selected` = ? WHERE `charid` = ? AND `identifier` = ? AND `id` = ?',
            { 1, charid, identifier, id })
        end
    end
end)

Core.Callback.Register('bcc-stables:DeselectHorse', function(source, cb, horseId)
    local src = source
    local user = Core.getUser(src)
    if not user then
        print('User not found for source:', src)
        return
    end
    local character = user.getUsedCharacter
    local identifier = character.identifier
    local charid = character.charIdentifier

    MySQL.query.await('UPDATE `player_horses` SET `selected` = ? WHERE `id` = ? AND `identifier` = ? AND `charid` = ?',
    { 0, horseId, identifier, charid })
    cb(true)
end)

Core.Callback.Register('bcc-stables:SetHorseDead', function(source, cb, horseId)
    local src = source
    local user = Core.getUser(src)
    if not user then
        print('User not found for source:', src)
        return
    end
    local character = user.getUsedCharacter
    local identifier = character.identifier
    local charid = character.charIdentifier

    MySQL.query.await('UPDATE `player_horses` SET `selected` = ?, `dead` = ? WHERE `id` = ? AND `identifier` = ? AND `charid` = ?',
    { 0, 1, horseId, identifier, charid })
    cb(true)
end)

Core.Callback.Register('bcc-stables:GetHorseData', function(source, cb)
    local src = source
    local user = Core.getUser(src)
    if not user then
        print('User not found for source:', src)
        return cb(false)
    end
    local character = user.getUsedCharacter

    local horses = MySQL.query.await('SELECT * FROM `player_horses` WHERE `charid` = ? AND `identifier` = ? AND `dead` = ? AND `selected` = ?',
    { character.charIdentifier, character.identifier, 0, 1 })

    if #horses > 0 then
        local horse = horses[1]
        local horseData = {
            model = horse.model,
            name = horse.name,
            components = horse.components,
            id = horse.id,
            gender = horse.gender,
            xp = horse.xp,
            captured = horse.captured,
            health = horse.health,
            stamina = horse.stamina
        }
        return cb(horseData)
    else
        local noHorsesMessage = #horses == 0 and _U('noHorses') or _U('noSelectedHorse')
        Core.NotifyRightTip(source, noHorsesMessage, 4000)
        return cb(false)
    end
end)

RegisterNetEvent('bcc-stables:GetMyHorses', function()
    local src = source
    local user = Core.getUser(src)
    if not user then
        print('User not found for source:', src)
        return
    end
    local character = user.getUsedCharacter
    local identifier = character.identifier
    local charid = character.charIdentifier

    local horses = MySQL.query.await('SELECT * FROM `player_horses` WHERE `charid` = ? AND `identifier` = ? AND `dead` = ?',
    { charid, identifier, 0 })
    TriggerClientEvent('bcc-stables:ReceiveHorsesData', src, horses)
end)

RegisterNetEvent('bcc-stables:UpdateComponents', function(encodedComponents, horseId, MyHorse_entity)
    local src = source
    local user = Core.getUser(src)
    if not user then
        print('User not found for source:', src)
        return
    end
    local character = user.getUsedCharacter
    local identifier = character.identifier
    local charid = character.charIdentifier

    MySQL.query.await('UPDATE `player_horses` SET `components` = ? WHERE `id` = ? AND `charid` = ? AND `identifier` = ?',
    { encodedComponents, horseId, charid, identifier })
    TriggerClientEvent('bcc-stables:SetComponents', src, MyHorse_entity, encodedComponents)
end)

Core.Callback.Register('bcc-stables:SellMyHorse', function(source, cb, data)
    local src = source
    local user = Core.getUser(src)
    if not user then
        print('User not found for source:', src)
        return cb(false)
    end
    local character = user.getUsedCharacter
    local identifier = character.identifier
    local charid = character.charIdentifier
    local model = nil
    local id = tonumber(data.horseId)
    local captured = data.captured

    local horses = MySQL.query.await('SELECT * FROM `player_horses` WHERE `charid` = ? AND `identifier` = ? AND `dead` = ?',
    { charid, identifier, 0 })
    for i = 1, #horses do
        if tonumber(horses[i].id) == id then
            model = horses[i].model
            MySQL.query.await('DELETE FROM `player_horses` WHERE `id` = ? AND `charid` = ? AND `identifier` = ?',
            { id, charid, identifier })
            LogToDiscord(charid, _U('discordHorseSold'))
            break
        end
    end
    for _, horseCfg in pairs(Horses) do
        for color, colorCfg in pairs(horseCfg.colors) do
            if color == model then
                local sellPrice = (Config.sellPrice * colorCfg.cashPrice)
                if captured then
                    sellPrice = (Config.tamedSellPrice * colorCfg.cashPrice)
                end
                character.addCurrency(0, sellPrice)
                Core.NotifyRightTip(src, _U('soldHorse') .. sellPrice, 4000)
                cb(true)
                break
            end
        end
    end
end)

local function SetPlayerCooldown(type, charid)
    CooldownData[type .. tostring(charid)] = os.time()
end

RegisterServerEvent('bcc-stables:SellTamedHorse', function(hash)
    local src = source
    local user = Core.getUser(src)
    if not user then
        print('User not found for source:', src)
        return
    end
    local character = user.getUsedCharacter
    local charid = character.charIdentifier

    for _, horseCfg in pairs(Horses) do
        for color, colorCfg in pairs(horseCfg.colors) do
            local colorHash = joaat(color)
            if colorHash == hash then
                local sellPrice = (Config.tamedSellPrice * colorCfg.cashPrice)
                character.addCurrency(0, math.floor(sellPrice))
                Core.NotifyRightTip(src, _U('soldHorse') .. sellPrice, 4000)
                SetPlayerCooldown('sellTame', charid)

                LogToDiscord(charid, _U('discordTamedSold'))
            end
        end
    end
end)

Core.Callback.Register('bcc-stables:CheckPlayerCooldown', function(source, cb, type)
    local src = source
    local user = Core.getUser(src)
    if not user then
        print('User not found for source:', src)
        return cb(false)
    end
    local character = user.getUsedCharacter
    local cooldown = Config.cooldown[type]
    local onList = false
    local typeId = type .. tostring(character.charIdentifier)

    for id, time in pairs(CooldownData) do
        if id == typeId then
            onList = true
            if os.difftime(os.time(), time) >= cooldown * 60 then
                cb(false) -- Not on Cooldown
                break
            else
                cb(true)
                break
            end
        end
    end
    if not onList then
        cb(false)
    end
end)

RegisterServerEvent('bcc-stables:SaveHorseTrade', function(serverId, horseId)
    -- Current Owner
    local src = source
    local curUser = Core.getUser(src)
    if not curUser then
        print('User not found for source:', src)
        return
    end
    local curOwner = curUser.getUsedCharacter
    local curOwnerId = curOwner.identifier
    local curOwnerCharId = curOwner.charIdentifier
    local curOwnerName = curOwner.firstname .. " " .. curOwner.lastname
    -- New Owner
    local newUser = Core.getUser(serverId)
    if not newUser then
        print('User not found for source:', serverId)
        return
    end
    local newOwner = newUser.getUsedCharacter
    local newOwnerId = newOwner.identifier
    local newOwnerCharId = newOwner.charIdentifier
    local newOwnerName = newOwner.firstname .. " " .. newOwner.lastname

    local horses = MySQL.query.await('SELECT * FROM `player_horses` WHERE `charid` = ? AND `identifier` = ? AND `dead` = ?',
    { curOwnerCharId, curOwnerId, 0 })
    for i = 1, #horses do
        if tonumber(horses[i].id) == horseId then
            MySQL.query.await('UPDATE `player_horses` SET `identifier` = ?, `charid` = ?, `selected` = ? WHERE `id` = ?',
            { newOwnerId, newOwnerCharId, 0, horseId })
            Core.NotifyRightTip(src, _U('youGave') .. newOwnerName .. _U('aHorse'), 4000)
            Core.NotifyRightTip(serverId, curOwnerName .._U('gaveHorse'), 4000)


            LogToDiscord(curOwnerName, _U('discordTraded') .. newOwnerName)
            break
        end
    end
end)

RegisterServerEvent('bcc-stables:RegisterInventory', function(id, model)
    local isRegistered = exports.vorp_inventory:isCustomInventoryRegistered('horse_' .. tostring(id))
    if isRegistered then return end

    for _, horseCfg in pairs(Horses) do
        for color, colorCfg in pairs(horseCfg.colors) do
            if color == model then
                local data = {
                    id = 'horse_' .. tostring(id),
                    name = _U('horseInv'),
                    limit = tonumber(colorCfg.invLimit),
                    acceptWeapons = Config.allowWeapons,
                    shared = Config.shareInventory,
                    ignoreItemStackLimit = true,
                    whitelistItems = false,
                    UsePermissions = false,
                    UseBlackList = false,
                    whitelistWeapons = false
                }
                exports.vorp_inventory:registerInventory(data)
                break
            end
        end
    end
end)

RegisterServerEvent('bcc-stables:OpenInventory', function(id)
    local src = source
    local user = Core.getUser(src)
    if not user then
        print('User not found for source:', src)
        return
    end
    exports.vorp_inventory:openInventory(src, 'horse_' .. tostring(id))
end)

-- Iterate over each item in the Config.horseFood array to register them as usable items
for _, item in ipairs(Config.horseFood) do
    exports.vorp_inventory:registerUsableItem(item, function(data)
        local src = data.source
        exports.vorp_inventory:closeInventory(src)
        TriggerClientEvent('bcc-stables:FeedHorse', src, item)
    end)
end

exports.vorp_inventory:registerUsableItem(Config.flameHooveItem, function(data)
    local src = data.source
    local user = Core.getUser(src)
    if not user then
        print('User not found for source:', src)
        return
    end

    local item = exports.vorp_inventory:getItem(src, Config.flameHooveItem)
    exports.vorp_inventory:closeInventory(src)

    -- Trigger the client-side event to activate flaming hooves
    TriggerClientEvent('bcc-stables:FlamedHoove', src)

    -- Check if durability system is enabled in the configuration
    if not Config.flameHooveDurability then return end

    local maxDurability = Config.flameHooveMaxDurability or 100
    local useDurability = Config.flameHooveDurabilityPerUse or 1

    -- Handle durability metadata
    if not next(item.metadata) then
        -- Initialize durability if none exists
        local newData = {
            description = _U('flameHooveDesc') .. '</br>' .. _U('durability') .. (maxDurability - useDurability) .. '%',
            durability = maxDurability - useDurability,
            id = item.id
        }
        exports.vorp_inventory:setItemMetadata(src, item.id, newData, 1)
    else
        -- Decrease durability and remove item if it breaks
        if item.metadata.durability <= useDurability then
            -- Remove item if durability is depleted
            exports.vorp_inventory:subItemID(src, item.id)
            Core.NotifyRightTip(src, _U('flameHooveBroken'), 4000)
        else
            -- Update durability metadata
            local newDurability = item.metadata.durability - useDurability
            local newData = {
                description = _U('flameHooveDesc') .. '</br>' .. _U('durability') .. newDurability .. '%',
                durability = newDurability,
                id = item.id
            }
            exports.vorp_inventory:setItemMetadata(src, item.id, newData, 1)
        end
    end
end)

RegisterServerEvent('bcc-stables:RemoveItem', function(item)
    local src = source
    local user = Core.getUser(src)
    if not user then
        print('User not found for source:', src)
        return
    end
    exports.vorp_inventory:subItem(src, item, 1)
end)

exports.vorp_inventory:registerUsableItem(Config.horsebrush, function(data)
    local src = data.source
    local user = Core.getUser(src)
    if not user then
        print('User not found for source:', src)
        return
    end

    local item = exports.vorp_inventory:getItem(src, Config.horsebrush)
    exports.vorp_inventory:closeInventory(src)
    TriggerClientEvent('bcc-stables:BrushHorse', src)

    if not Config.horsebrushDurability then return end

    if not next(item.metadata) then
        local newData = {
            description = _U('horsebrushDesc') .. '</br>' .. _U('durability') .. 100 - 1 .. '%',
            durability = 100 - 1,
            id = item.id
        }
        exports.vorp_inventory:setItemMetadata(src, item.id, newData, 1)
    else
        if item.metadata.durability < 1 then
            exports.vorp_inventory:subItemID(src, item.id)
        else
            local newData = {
                description = _U('horsebrushDesc') .. '</br>' .. _U('durability') .. item.metadata.durability - 1 .. '%',
                durability = item.metadata.durability - 1,
                id = item.id
            }
            exports.vorp_inventory:setItemMetadata(src, item.id, newData, 1)
        end
    end
end)

exports.vorp_inventory:registerUsableItem(Config.lantern, function(data)
    local src = data.source
    local user = Core.getUser(src)
    if not user then
        print('User not found for source:', src)
        return
    end

    local item = exports.vorp_inventory:getItem(src, Config.lantern)
    exports.vorp_inventory:closeInventory(src)
    TriggerClientEvent('bcc-stables:UseLantern', src)

    if not Config.lanternDurability then return end

    if not next(item.metadata) then
        local newData = {
            description = _U('durability') .. 100 - 1 .. '%',
            durability = 100 - 1,
            id = item.id
        }
        exports.vorp_inventory:setItemMetadata(src, item.id, newData, 1)
    else
        if item.metadata.durability < 1 then
            exports.vorp_inventory:subItemID(src, item.id)
        else
            local newData = {
                description = _U('durability') .. item.metadata.durability - 1 .. '%',
                durability = item.metadata.durability - 1,
                id = item.id
            }
            exports.vorp_inventory:setItemMetadata(src, item.id, newData, 1)
        end
    end
end)

Core.Callback.Register('bcc-stables:HorseReviveItem', function(source, cb)
    local src = source
    local user = Core.getUser(src)
    if not user then
        print('User not found for source:', src)
        return cb(false)
    end
    local reviveItem = Config.reviver

    local item = exports.vorp_inventory:getItem(src, reviveItem)
    if not item then
        cb(false)
        return
    end
    exports.vorp_inventory:subItem(src, reviveItem, 1)
    cb(true)
end)

Core.Callback.Register('bcc-stables:CheckJob', function(source, cb, trainer, site)
    local src = source
    local user = Core.getUser(src)
    if not user then
        print('User not found for source:', src)
        return cb(false)
    end
    local character = user.getUsedCharacter

    local jobConfig = trainer and Config.trainerJob or Stables[site].shop.jobs

    local hasJob = false
    for _, job in pairs(jobConfig) do
        if (character.job == job.name) and (tonumber(character.jobGrade) >= tonumber(job.grade)) then
            hasJob = true
            break
        end
    end

    cb({hasJob, character.job})
end)

RegisterNetEvent('vorp_core:instanceplayers', function(setRoom)
    local src = source
    local user = Core.getUser(src)
    if not user then
        print('User not found for source:', src)
        return
    end

    if setRoom == 0 then
        Wait(3000)
        TriggerClientEvent('bcc-stables:UpdateMyHorseEntity', src)
    end
end)

--- Check if properly downloaded
function file_exists(name)
    local f = LoadResourceFile(GetCurrentResourceName(), name)
    return f ~= nil
end

if not file_exists('./ui/index.html') then
    print('^1 INCORRECT DOWNLOAD!  ^0')
    print(
        '^4 Please Download: ^2(bcc-stables.zip) ^4from ^3<https://github.com/BryceCanyonCounty/bcc-stables/releases/latest>^0')
end

BccUtils.Versioner.checkFile(GetCurrentResourceName(), 'https://github.com/BryceCanyonCounty/bcc-stables')
