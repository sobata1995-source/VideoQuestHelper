local _, addon = ...
local sleepingBag = "NBBJCumFkzA"

-- Icprodigy's Forever guide, with a chapter for each step.
local chapters = {
    ["... and that note you found"] = { sleepingBag, 35 },
    ["stepping stones"] = { sleepingBag, 103 },
    ["scramble"] = { sleepingBag, 140 },
    ["wet job"] = { sleepingBag, 181 },
    ["eagle's fist"] = { sleepingBag, 276 },
    ["this must be the place"] = { sleepingBag, 357 },
    -- SneakySeanTV, recorded in the September Forever beta.
    ["the horn of xelthos"] = { "l67y6gt7yNE", 0 },
}
local byID = {
    [79192] = chapters["stepping stones"],
    [79980] = chapters["scramble"],
    [78307] = chapters["the horn of xelthos"],
}
function addon.FindVideo(id, title)
    return byID[id] or (title and chapters[title:lower()])
end
