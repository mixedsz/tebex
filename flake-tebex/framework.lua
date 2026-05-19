-- Flake Tebex Framework Compatibility Layer
-- This file provides compatibility between ESX and QBCore frameworks

-- Framework detection
local QBCore = nil
local ESX = nil
local Framework = {}

-- Detect which framework is being used
local function DetectFramework()
    if GetResourceState('qb-core') == 'started' then
        QBCore = exports['qb-core']:GetCoreObject()
        return 'qbcore'
    elseif GetResourceState('es_extended') == 'started' then
        ESX = exports['es_extended']:getSharedObject()
        return 'esx'
    else
        print('[flake Tebex] ERROR: No supported framework detected (ESX or QBCore)')
        return nil
    end
end

-- Initialize the framework
local frameworkName = DetectFramework()
Framework.name = frameworkName
print('[flake Tebex] Detected framework: ' .. (frameworkName or 'NONE'))

-- Get player from source
function Framework.GetPlayer(source)
    if frameworkName == 'qbcore' then
        return QBCore.Functions.GetPlayer(source)
    elseif frameworkName == 'esx' then
        return ESX.GetPlayerFromId(source)
    end
    return nil
end

-- Get player identifier
function Framework.GetIdentifier(player)
    if frameworkName == 'qbcore' then
        return player.PlayerData.citizenid
    elseif frameworkName == 'esx' then
        return player.identifier
    end
    return nil
end

-- Add cash money to player
function Framework.AddMoney(source, amount)
    if frameworkName == 'qbcore' then
        local player = QBCore.Functions.GetPlayer(source)
        if player then player.Functions.AddMoney('cash', amount) end
    elseif frameworkName == 'esx' then
        local player = ESX.GetPlayerFromId(source)
        if player then player.addMoney(amount) end
    end
end

-- Add item to player inventory
function Framework.AddItem(player, item, amount)
    if frameworkName == 'qbcore' then
        return player.Functions.AddItem(item, amount)
    elseif frameworkName == 'esx' then
        return player.addInventoryItem(item, amount)
    end
    return false
end

-- Show notification to player
function Framework.Notify(source, message, type)
    if frameworkName == 'qbcore' then
        TriggerClientEvent('QBCore:Notify', source, message, type)
    elseif frameworkName == 'esx' then
        if type == 'success' then
            TriggerClientEvent('esx:showNotification', source, message)
        elseif type == 'error' then
            TriggerClientEvent('esx:showNotification', source, message)
        else
            TriggerClientEvent('esx:showNotification', source, message)
        end
    end
end

-- Check if player has admin permissions
function Framework.IsAdmin(player)
    if frameworkName == 'qbcore' then
        local group = player.PlayerData.permission
        return group == 'admin' or group == 'god'
    elseif frameworkName == 'esx' then
        local group = player.getGroup()
        return group == 'admin' or group == 'superadmin'
    end
    return false
end

-- Get player name
function Framework.GetPlayerName(player)
    if frameworkName == 'qbcore' then
        return player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
    elseif frameworkName == 'esx' then
        return player.getName()
    end
    return GetPlayerName(player.source)
end

-- Add vehicle to player
function Framework.AddVehicle(player, model, plate, vehicleName, source)
    if frameworkName == 'qbcore' then
        -- QBCore vehicle insertion
        local vehicleData = {
            citizenid = player.PlayerData.citizenid,
            plate = plate,
            model = model,
            mods = '{}',
            state = 1, -- Stored in garage
            garage = 'pillboxgarage', -- Default garage
            fuel = 100,
            engine = 1000,
            body = 1000
        }
        
        exports.oxmysql:execute('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, state, garage) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
            player.PlayerData.license,
            player.PlayerData.citizenid,
            model,
            GetHashKey(model),
            '{}',
            plate,
            1,
            'pillboxgarage'
        }, function()
            lib.notify(source, {
                title = 'Vehicle Added',
                description = 'You received a ' .. vehicleName .. ' (Plate: ' .. plate .. ')',
                type = 'success'
            })
        end)
    elseif frameworkName == 'esx' then
        -- ESX vehicle insertion
        local vehicleJson = json.encode({model = model, plate = plate})
        
        local query = "INSERT INTO `owned_vehicles` (`owner`, `plate`, `vehicle`, `type`, `job`, `stored`) VALUES ('" ..
            player.identifier .. "', '" ..
            plate .. "', '" ..
            vehicleJson:gsub("'", "''") .. "', 'car', 'civ', 1)"
            
        exports.oxmysql:execute(query, function()
            lib.notify(source, {
                title = 'Vehicle Added',
                description = 'You received a ' .. vehicleName .. ' (Plate: ' .. plate .. ')',
                type = 'success'
            })
        end)
    end
end

-- Return the framework object
return Framework
