Config = {}

-- ============================================================
--  TEBEX PLUGIN API
--  Secret key: Tebex Dashboard → Game Servers → [your server] → Secret Key
-- ============================================================
Config.TebexSecret  = "YOUR_TEBEX_SECRET_KEY"
Config.TebexApiUrl  = "https://plugin.tebex.io"   -- do not change

-- ============================================================
--  DISCORD WEBHOOK  (optional — leave blank to disable)
-- ============================================================
Config.DiscordWebhook = ""
Config.DiscordBotName = "Tebex Redemptions"

-- ============================================================
--  PACKAGE REWARDS
--
--  Map every Tebex package ID (number) to the in-game rewards
--  you want delivered when a player redeems that package.
--
--  How to find your package IDs:
--    Tebex Dashboard → Packages → click a package →
--    look at the URL: /packages/<ID>  or the package settings page.
--
--  Reward types:
--    { type = 'money',   amount = 1000000 }
--    { type = 'item',    name = 'item_name', amount = 1 }
--    { type = 'vehicle', model = 'adder', label = 'Adder', plate = 'TEBEX01' }
--      (plate is optional — a random 8-char plate is generated if omitted)
-- ============================================================
Config.Packages = {

    [12345] = {  -- ← replace with your real Tebex package ID
        name = "Diamond Package",
        rewards = {
            { type = 'money', amount = 1000000 },
            { type = 'item',  name = 'xmasbundle',   amount = 3 },
            { type = 'vehicle', model = 'a1hellcat',  label = 'Hellcat' },
        },
    },

    [12346] = {  -- ← replace with your real Tebex package ID
        name = "Gold Package",
        rewards = {
            { type = 'money', amount = 500000 },
            { type = 'item',  name = 'ultimate_drop', amount = 2 },
        },
    },

    [12347] = {  -- ← replace with your real Tebex package ID
        name = "Silver Package",
        rewards = {
            { type = 'money', amount = 250000 },
            { type = 'item',  name = 'ultimate_drop', amount = 1 },
        },
    },

    [12348] = {  -- ← replace with your real Tebex package ID
        name = "Bronze Package",
        rewards = {
            { type = 'money', amount = 100000 },
        },
    },

}
