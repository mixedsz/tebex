local PlayersCodeRedeemCooldown = {}

-- Helper function to count table entries
local function countTableEntries(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

local ALPHABET = "abcdefghijklmnopqrstuvwxyz"
local RESOURCE_NAME = GetCurrentResourceName()
local CODES_AWAITING_REDEEM = json.decode(LoadResourceFile(RESOURCE_NAME, "codes.json")) or {}
print("[flake Tebex] Loaded " .. countTableEntries(CODES_AWAITING_REDEEM) .. " codes from codes.json")

-- Load framework compatibility layer
local Framework
local frameworkFile = LoadResourceFile(RESOURCE_NAME, "framework.lua")
if frameworkFile then
    local loadFramework, err = load(frameworkFile, 'framework.lua')
    if loadFramework then
        Framework = loadFramework()
    else
        print('[flake Tebex] ERROR: Failed to load framework.lua: ' .. tostring(err))
        Framework = {} -- Create empty framework to prevent errors
    end
else
    print('[flake Tebex] ERROR: framework.lua not found')
    Framework = {} -- Create empty framework to prevent errors
end

local encode = json.encode
local time = function() return os.time() end
local random = math.random

lib.addCommand('generateCode', {
    help = 'Generates a redeemable code',
    params = {
        {
            name = 'type',
            type = 'string',
            help = 'Type of reward (item or blackdiamond)',
        },
        {
            name = 'item',
            type = 'string',
            help = 'The redeemable reward (item name or "blackdiamond")',
        },
        {
            name = 'amount',
            type = 'number',
            help = 'Amount of the reward to give',
        },
        {
            name = 'amountOfCodes',
            type = 'number',
            help = 'Amount of codes to give',
            optional = true,
        },
    },
    restricted = 'group.admin'
}, function(source, args, raw)
    -- Check if type is valid
    if not args.type or (args.type ~= 'item' and args.type ~= 'blackdiamond') then
        TriggerClientEvent('ox_lib:notify', source, {
            description = 'Invalid reward type. Use "item" or "blackdiamond"',
            type = 'error'
        })
        return
    end

    -- For item type, validate the item exists
    if args.type == 'item' and not exports.ox_inventory:Items(args.item) then
        TriggerClientEvent('ox_lib:notify', source, {
            description = 'Invalid item name',
            type = 'error'
        })
        return
    end

    -- For blackdiamond type, set the item name to blackdiamond
    if args.type == 'blackdiamond' then
        args.item = 'blackdiamond'
    end

    if not args.amountOfCodes then
        args.amountOfCodes = 1
    end

    local codes = {}
    for i = 1, args.amountOfCodes do
        local redeem_type = args.type

        local code = generateRandomCombo()

        if not code then return end

        -- Code is already in uppercase format from generateRandomCombo
        CODES_AWAITING_REDEEM[code] = {
            type = redeem_type,
            name = args.item,
            amount = args.amount
        }

        codes[#codes + 1] = code
    end

    SaveResourceFile(RESOURCE_NAME, "codes.json", encode(CODES_AWAITING_REDEEM, {indent=true}), -1)
    print("[flake Tebex] Generated " .. #codes .. " codes. First code: " .. codes[1])
    print("[flake Tebex] Total codes in system: " .. countTableEntries(CODES_AWAITING_REDEEM))

    local clipboardVal = ''

    for k, v in ipairs(codes) do
        clipboardVal = clipboardVal .. v .. '\t\n'
    end

    local player = Framework.GetPlayer(source)
    local playerName = GetPlayerName(source)
    local identifier = Framework.GetIdentifier(player)
	local playerDetail = ("%s generated %s codes"):format(playerName, #codes)

	local time = os.date("%B %d, %Y at %H:%M %p")
	local description = ("**Name:** %s (%s)\n**Reward:** %s\n\n**Codes:** \n%s\n**Date & Time:** %s"):format(playerName, identifier, args.item .. ' - x'.. args.amount, clipboardVal, time)

	TriggerEvent('flake-logs:SendCustom', "redeem_code", "Codes Generated", playerDetail, description)

	-- Send to Discord webhook
	TriggerEvent('flake-discord:CodeGeneration', playerName, identifier, args.item, args.amount, codes)



    TriggerClientEvent('flake-tebex:CopyToClipboard', source, codes)
end)

lib.addCommand('redeemCode', {
    help = 'Redeem a code',
}, function(source, args, raw)
    TriggerClientEvent('flake-tebex:OpenCodeRedeem', source)
end)

RegisterNetEvent('flake-tebex:RedeemCode', function(code)
    local source = source

    if PlayersCodeRedeemCooldown[source] and time() - PlayersCodeRedeemCooldown[source] <= 2 then
        return
    end

    PlayersCodeRedeemCooldown[source] = time()

    if not code then
        return
    end

    local player = Framework.GetPlayer(source)
    if not player then return end

    local identifier = Framework.GetIdentifier(player)

    code = code:upper()
    if not code:find('TBX%-') then
        Framework.Notify(source, "The code format is invalid!", "error")
        return
    end

    if not CODES_AWAITING_REDEEM[code] then
        print("[flake Tebex] Code not found: " .. code)
        Framework.Notify(source, "That code might have already been used!", "error")
        return
    end

    local rewardData = CODES_AWAITING_REDEEM[code]
    local rewardType = rewardData.type or 'item' -- Default to item for backward compatibility
    local rewardName = rewardData.name
    local rewardAmount = rewardData.amount
    local rewardDescription = rewardName .. " - x" .. rewardAmount

    -- Handle different reward types
    if rewardType == 'blackdiamond' then
        -- Add BlackDiamond to player's account

        -- Check if player exists in flake_bdiamondshop database
        MySQL.Async.fetchAll('SELECT * FROM flake_bdiamondshop WHERE identifier = @identifier', {
            ['@identifier'] = identifier
        }, function(result)
            if result[1] then
                -- Player exists, update their BlackDiamond amount
                MySQL.Async.execute('UPDATE flake_bdiamondshop SET blackdiamond = blackdiamond + @amount WHERE identifier = @identifier', {
                    ['@identifier'] = identifier,
                    ['@amount'] = rewardAmount
                }, function(rowsChanged)
                    -- Notify player
                    Framework.Notify(source, "You have redeemed " .. rewardAmount .. " BlackDiamond!", "success")

                    -- Update UI if it's open
                    TriggerClientEvent('flake_bdiamondshop:updateBlackdiamond', source, result[1].blackdiamond + rewardAmount)

                    -- Log redemption
                    LogRedemption(source, player, code, rewardType, rewardName, rewardAmount, rewardDescription)

                    -- Remove code after use
                    CODES_AWAITING_REDEEM[code] = nil
                    SaveResourceFile(RESOURCE_NAME, "codes.json", encode(CODES_AWAITING_REDEEM, {indent=true}), -1)
                end)
            else
                -- Player doesn't exist in flake_bdiamondshop database, create entry
                local initialRewards = {
                    day = 1,
                    lastClaim = 0,
                    canClaim = true,
                    initialized = true
                }

                MySQL.Async.execute('INSERT INTO flake_bdiamondshop (identifier, blackdiamond, vip, rewards) VALUES (@identifier, @blackdiamond, @vip, @rewards)', {
                    ['@identifier'] = identifier,
                    ['@blackdiamond'] = rewardAmount,
                    ['@vip'] = 0,
                    ['@rewards'] = json.encode(initialRewards)
                }, function(rowsChanged)
                    -- Notify player
                    Framework.Notify(source, "You have redeemed " .. rewardAmount .. " BlackDiamond!", "success")

                    -- Log redemption
                    LogRedemption(source, player, code, rewardType, rewardName, rewardAmount, rewardDescription)

                    -- Remove code after use
                    CODES_AWAITING_REDEEM[code] = nil
                    SaveResourceFile(RESOURCE_NAME, "codes.json", encode(CODES_AWAITING_REDEEM, {indent=true}), -1)
                end)
            end
        end)
    else
        -- Handle regular item rewards
        Framework.AddItem(player, rewardName, rewardAmount)
        Framework.Notify(source, "You have redeemed your code!", "success")

        -- Log redemption
        LogRedemption(source, player, code, rewardType, rewardName, rewardAmount, rewardDescription)

        -- Remove code after use
        CODES_AWAITING_REDEEM[code] = nil
        SaveResourceFile(RESOURCE_NAME, "codes.json", encode(CODES_AWAITING_REDEEM, {indent=true}), -1)
    end
end)

-- Helper function to log code redemption
function LogRedemption(source, player, code, rewardType, rewardName, rewardAmount, rewardDescription)
    local playerName = GetPlayerName(source)
    local identifier = Framework.GetIdentifier(player)
    local playerDetail = ("%s redeemed %s"):format(playerName, code)

    local time = os.date("%B %d, %Y at %H:%M %p")
    local description = ("**Name:** %s (%s)\n**Code:** %s\n**Reward Type:** %s\n**Reward:** %s\n\n**Date & Time:** %s"):format(
        playerName,
        identifier,
        code,
        rewardType,
        rewardDescription,
        time
    )

    TriggerEvent('flake-logs:SendCustom', "redeem_code", "Code Redeemed", playerDetail, description)

    -- Send to Discord webhook
    TriggerEvent('flake-discord:CodeRedemption', playerName, identifier, code, rewardName, rewardAmount)
end

-- Event handler for code redemption from flake_bdiamondshop
RegisterNetEvent('flake-tebex:RedeemCodeFromShop')
AddEventHandler('flake-tebex:RedeemCodeFromShop', function(playerId, code)
    -- Validate parameters
    if not playerId or not code then return end

    -- Process the code redemption directly without opening UI
    local player = Framework.GetPlayer(playerId)
    if not player then return end

    local identifier = Framework.GetIdentifier(player)

    code = code:upper()
    if not code:find('TBX%-') then
        Framework.Notify(playerId, "The code format is invalid!", "error")
        return
    end

    if not CODES_AWAITING_REDEEM[code] then
        print("[flake Tebex] Code not found: " .. code)
        Framework.Notify(playerId, "That code might have already been used!", "error")
        return
    end

    local rewardData = CODES_AWAITING_REDEEM[code]
    local rewardType = rewardData.type or 'item' -- Default to item for backward compatibility
    local rewardName = rewardData.name
    local rewardAmount = rewardData.amount
    local rewardDescription = rewardName .. " - x" .. rewardAmount

    -- Handle different reward types
    if rewardType == 'blackdiamond' then
        -- Add BlackDiamond to player's account

        -- Check if player exists in flake_bdiamondshop database
        MySQL.Async.fetchAll('SELECT * FROM flake_bdiamondshop WHERE identifier = @identifier', {
            ['@identifier'] = identifier
        }, function(result)
            if result[1] then
                -- Player exists, update their BlackDiamond amount
                MySQL.Async.execute('UPDATE flake_bdiamondshop SET blackdiamond = blackdiamond + @amount WHERE identifier = @identifier', {
                    ['@identifier'] = identifier,
                    ['@amount'] = rewardAmount
                }, function(rowsChanged)
                    -- Notify player
                    Framework.Notify(playerId, "You have redeemed " .. rewardAmount .. " BlackDiamond!", "success")

                    -- Update UI if it's open
                    TriggerClientEvent('flake_bdiamondshop:updateBlackdiamond', playerId, result[1].blackdiamond + rewardAmount)

                    -- Log redemption
                    LogRedemption(playerId, player, code, rewardType, rewardName, rewardAmount, rewardDescription)

                    -- Remove code after use
                    CODES_AWAITING_REDEEM[code] = nil
                    SaveResourceFile(RESOURCE_NAME, "codes.json", encode(CODES_AWAITING_REDEEM, {indent=true}), -1)
                end)
            else
                -- Player doesn't exist in flake_bdiamondshop database, create entry
                local initialRewards = {
                    day = 1,
                    lastClaim = 0,
                    canClaim = true,
                    initialized = true
                }

                MySQL.Async.execute('INSERT INTO flake_bdiamondshop (identifier, blackdiamond, vip, rewards) VALUES (@identifier, @blackdiamond, @vip, @rewards)', {
                    ['@identifier'] = identifier,
                    ['@blackdiamond'] = rewardAmount,
                    ['@vip'] = 0,
                    ['@rewards'] = json.encode(initialRewards)
                }, function(rowsChanged)
                    -- Notify player
                    Framework.Notify(playerId, "You have redeemed " .. rewardAmount .. " BlackDiamond!", "success")

                    -- Log redemption
                    LogRedemption(playerId, player, code, rewardType, rewardName, rewardAmount, rewardDescription)

                    -- Remove code after use
                    CODES_AWAITING_REDEEM[code] = nil
                    SaveResourceFile(RESOURCE_NAME, "codes.json", encode(CODES_AWAITING_REDEEM, {indent=true}), -1)
                end)
            end
        end)
    else
        -- Handle regular item rewards
        Framework.AddItem(player, rewardName, rewardAmount)
        Framework.Notify(playerId, "You have redeemed your code!", "success")

        -- Log redemption
        LogRedemption(playerId, player, code, rewardType, rewardName, rewardAmount, rewardDescription)

        -- Remove code after use
        CODES_AWAITING_REDEEM[code] = nil
        SaveResourceFile(RESOURCE_NAME, "codes.json", encode(CODES_AWAITING_REDEEM, {indent=true}), -1)
    end
end)

function generateRandomCombo(attempts)
    if attempts and attempts == 0 then
        print("ERROR: COULDNT GENERATE CODE (possibly 11 million codes already exist...)")
        return
    end

    local combo = ""

    for i = 1, 5 do
        local randomIndex = random(1, #ALPHABET) -- Generate a random index within the range of the alphabet string
        combo = combo .. ALPHABET:sub(randomIndex, randomIndex) -- Append the randomly selected character to the combination
    end

    combo = combo:upper()
    local fullCode = 'TBX-' .. combo

    if CODES_AWAITING_REDEEM[fullCode] then
        if not attempts then
            attempts = 3
        end
        return generateRandomCombo(attempts - 1)
    end

    return fullCode
end
