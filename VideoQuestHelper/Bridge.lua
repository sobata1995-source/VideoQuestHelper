local _, addon = ...
local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local frame, timer
local rows = {}
local sequence = 0
local payloadSize = 91
local cellWidth, rowHeight

local function addBits(bits, value, width)
    for shift = width - 1, 0, -1 do
        bits[#bits + 1] = math.floor(value / 2^shift) % 2
    end
end

local function drawRow(rowIndex, video, seconds)
    local bits, checksum = {}, sequence + seconds
    for index = 1, #video do
        local value = alphabet:find(video:sub(index, index), 1, true) - 1
        addBits(bits, value, 6)
        checksum = checksum + index * value
    end
    addBits(bits, seconds, 9)
    addBits(bits, sequence, 8)
    addBits(bits, checksum % 256, 8)

    local cells = rows[rowIndex]
    if not cells then
        cells = {}
        rows[rowIndex] = cells
        for index = 0, payloadSize + 1 do
            local cell = frame:CreateTexture(nil, "OVERLAY")
            cell:SetSize(cellWidth, rowHeight)
            cell:SetPoint("LEFT", frame, "LEFT", index * cellWidth, -rowHeight * (rowIndex - 1))
            cells[index] = cell
        end
        cells[0]:SetColorTexture(1, 0, 1)
        cells[payloadSize + 1]:SetColorTexture(0, 1, 1)
    end
    for index, bit in ipairs(bits) do
        cells[index]:SetColorTexture(bit, bit, bit)
    end
    for _, cell in pairs(cells) do cell:Show() end
end

local function beginSignal()
    sequence = (sequence + 1) % 256
    if not frame then
        local _, screenHeight = GetPhysicalScreenSize()
        cellWidth = screenHeight > 0 and 2.25 * UIParent:GetHeight() / screenHeight or 3.5
        rowHeight = 2 * cellWidth
        frame = CreateFrame("Frame", nil, UIParent)
        frame:SetPoint("CENTER")
        frame:SetSize((payloadSize + 2) * cellWidth, rowHeight)
        frame:SetFrameStrata("TOOLTIP")
    end
    for _, row in ipairs(rows) do
        for _, cell in pairs(row) do cell:Hide() end
    end
end

local function showSignal()
    if timer then timer:Cancel() end
    frame:Show()
    timer = C_Timer.NewTimer(0.25, function() frame:Hide() end)
end

function addon.SignalVideo(video, seconds)
    beginSignal()
    drawRow(1, video, seconds)
    showSignal()
end

function addon.SignalSearch(query)
    query = query:sub(1, 150)
    beginSignal()
    drawRow(1, string.format("%011d", #query), 511)
    for offset = 1, #query, 5 do
        local chunk = query:sub(offset, offset + 4):gsub(".", function(char)
            return string.format("%02X", char:byte())
        end)
        local index = math.floor((offset - 1) / 5) + 1
        drawRow(index + 1, (chunk .. "00000000000"):sub(1, 11), index)
    end
    showSignal()
end
