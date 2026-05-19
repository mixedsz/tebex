-- ============================================================
--  Flake Tebex — Server
--  Validates purchases against the Tebex Plugin API and
--  delivers configured in-game rewards.
--
--  Tebex Plugin API docs: https://docs.tebex.io/plugin/
--    GET /payments/{transaction_id}
--      Headers: X-Buycraft-Secret: <your secret>
--      200 → { status, player, packages:[{id, name}], ... }
--      404 → transaction not found
-- ============================================================

local RESOURCE  = GetCurrentResourceName()
local redeemed  = {}   -- txnId → { player, identifier, packages, timestamp }
local cooldowns = {}   -- source → unix timestamp of last attempt

-- ── Persistence ───────────────────────────────────────────────

local function LoadRedeemed()
    local raw = LoadResourceFile(RESOURCE, 'redeemed.json')
    if raw then redeemed = json.decode(raw) or {} end
    local n = 0
    for _ in pairs(redeemed) do n = n + 1 end
    print(('[Tebex] Loaded %d redeemed transactions.'):format(n))
end

local function SaveRedeemed()
    SaveResourceFile(RESOURCE, 'redeemed.json', json.encode(redeemed, { indent = true }), -1)
end

AddEventHandler('onResourceStart', function(name)
    if name == RESOURCE then LoadRedeemed() end
end)

-- ── Utilities ────────────────────────────────────────────────

local function Notify(src, msg, kind)
    TriggerClientEvent('flake-tebex:Notify', src, msg, kind)
end

local function RandomPlate()
    local pool = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local plate = ''
    for i = 1, 8 do
        local r = math.random(1, #pool)
        plate = plate .. pool:sub(r, r)
    end
    return plate
end

-- ── Reward delivery ───────────────────────────────────────────

local function DeliverRewards(src, rewards)
    local player = Framework.GetPlayer(src)
    if not player then return end

    for _, r in ipairs(rewards) do
        if r.type == 'money' then
            Framework.AddMoney(src, r.amount)
        elseif r.type == 'item' then
            Framework.AddItem(player, r.name, r.amount)
        elseif r.type == 'vehicle' then
            local plate = r.plate or RandomPlate()
            Framework.AddVehicle(player, r.model, plate, r.label or r.model, src)
        end
    end
end

-- ── Discord logging ───────────────────────────────────────────

local function DiscordLog(txnId, playerName, pkgNames)
    if not Config.DiscordWebhook or Config.DiscordWebhook == '' then return end

    local body = json.encode({
        username = Config.DiscordBotName or 'Tebex',
        embeds = {
            {
                title  = 'Tebex Redemption',
                color  = 3066993,
                fields = {
                    { name = 'Player',      value = playerName,                   inline = true  },
                    { name = 'Transaction', value = '`' .. txnId .. '`',          inline = true  },
                    { name = 'Packages',    value = table.concat(pkgNames, '\n'), inline = false },
                },
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            },
        },
    })

    PerformHttpRequest(Config.DiscordWebhook, function() end, 'POST', body,
        { ['Content-Type'] = 'application/json' })
end

-- ── Tebex Plugin API helper ───────────────────────────────────

local function TebexGet(endpoint, cb)
    PerformHttpRequest(
        Config.TebexApiUrl .. endpoint,
        function(status, body, _headers)
            if status == 200 then
                cb(json.decode(body), nil)
            else
                cb(nil, status)
            end
        end,
        'GET', '',
        {
            ['X-Buycraft-Secret'] = Config.TebexSecret,
            ['Accept']            = 'application/json',
        }
    )
end

-- ── Redemption net event ─────────────────────────────────────

RegisterNetEvent('flake-tebex:RedeemTransaction', function(rawCode)
    local src = source  -- capture before any async gap

    -- 15-second cooldown per player
    local now = os.time()
    if cooldowns[src] and (now - cooldowns[src]) < 15 then
        Notify(src, 'Please wait before trying again.', 'error')
        return
    end
    cooldowns[src] = now

    -- sanitise: keep only alphanumeric and hyphens, lowercase
    local txnId = rawCode:lower():gsub('[^%w%-]', '')

    if #txnId < 4 or #txnId > 64 then
        Notify(src, "That doesn't look like a valid transaction code.", 'error')
        return
    end

    -- prevent double redemption
    if redeemed[txnId] then
        Notify(src, 'This code has already been redeemed.', 'error')
        return
    end

    -- call the Tebex Plugin API
    TebexGet('/payments/' .. txnId, function(data, err)
        if not data then
            if err == 404 then
                Notify(src, 'Transaction not found. Double-check your code and try again.', 'error')
            else
                Notify(src, ('Could not reach Tebex right now, try again shortly. (HTTP %s)'):format(tostring(err)), 'error')
            end
            return
        end

        if data.status ~= 'Complete' then
            Notify(src, ('Your purchase is not yet complete (status: %s). Please wait and try again.'):format(tostring(data.status)), 'error')
            return
        end

        -- match packages to configured rewards
        local delivered    = {}
        local unconfigured = {}

        for _, pkg in ipairs(data.packages or {}) do
            local cfg = Config.Packages[pkg.id]
            if cfg then
                DeliverRewards(src, cfg.rewards)
                delivered[#delivered + 1] = cfg.name
            else
                unconfigured[#unconfigured + 1] = ('%d (%s)'):format(pkg.id, pkg.name or '?')
            end
        end

        if #unconfigured > 0 then
            print(('[Tebex] WARNING: unconfigured package IDs in txn %s: %s')
                :format(txnId, table.concat(unconfigured, ', ')))
        end

        if #delivered == 0 then
            Notify(src,
                'No rewards are configured for your package(s). Please contact an administrator.',
                'error')
            return
        end

        -- record redemption so it can never be used twice
        local player = Framework.GetPlayer(src)
        redeemed[txnId] = {
            player     = GetPlayerName(src),
            identifier = player and Framework.GetIdentifier(player) or 'unknown',
            packages   = delivered,
            timestamp  = now,
        }
        SaveRedeemed()

        local list = table.concat(delivered, ', ')
        Notify(src, ('Successfully redeemed: %s!'):format(list), 'success')
        DiscordLog(txnId, GetPlayerName(src), delivered)
        print(('[Tebex] %s redeemed txn %s → %s'):format(GetPlayerName(src), txnId, list))
    end)
end)

-- clean up cooldown entry when a player drops
AddEventHandler('playerDropped', function()
    cooldowns[source] = nil
end)
